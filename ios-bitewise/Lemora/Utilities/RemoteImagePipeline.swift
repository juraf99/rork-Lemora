import SwiftUI
import UIKit
import ImageIO

/// Fast, cached loading for recipe photos hosted in Supabase Storage.
/// - Memory cache of decoded, downsampled images (no re-decode when a card comes back).
/// - Disk cache through URLCache (photos survive app restarts).
/// - One download per URL even when several views ask at the same time.
/// - Decoding happens off the main thread, so swiping stays smooth.
nonisolated final class RemoteImagePipeline: @unchecked Sendable {
    static let shared = RemoteImagePipeline()

    private let cache = NSCache<NSURL, UIImage>()
    private let session: URLSession
    private let lock = NSLock()
    private var inFlight: [URL: Task<UIImage?, Never>] = [:]

    private init() {
        cache.countLimit = 120
        cache.totalCostLimit = 180 * 1024 * 1024
        let config = URLSessionConfiguration.default
        config.urlCache = URLCache(memoryCapacity: 16 * 1024 * 1024, diskCapacity: 400 * 1024 * 1024)
        config.requestCachePolicy = .returnCacheDataElseLoad
        config.httpMaximumConnectionsPerHost = 6
        session = URLSession(configuration: config)
    }

    func cached(_ url: URL) -> UIImage? {
        cache.object(forKey: url as NSURL)
    }

    func image(for url: URL) async -> UIImage? {
        if let hit = cached(url) { return hit }
        let task: Task<UIImage?, Never> = lock.withLock {
            if let existing = inFlight[url] { return existing }
            let session = self.session
            let created = Task.detached(priority: .userInitiated) { () -> UIImage? in
                guard let (data, response) = try? await session.data(from: url),
                      (response as? HTTPURLResponse).map({ (200..<300).contains($0.statusCode) }) ?? true
                else { return nil }
                return RemoteImagePipeline.downsample(data, maxPixel: 1080)
            }
            inFlight[url] = created
            return created
        }
        let image = await task.value
        lock.withLock { inFlight[url] = nil }
        if let image {
            let cost = Int(image.size.width * image.size.height * image.scale * image.scale * 4)
            cache.setObject(image, forKey: url as NSURL, cost: cost)
        }
        return image
    }

    /// Warms the cache for the next cards so they appear instantly when swiped in.
    func prefetch(_ urls: [URL]) {
        for url in urls where cached(url) == nil {
            Task.detached(priority: .utility) { _ = await RemoteImagePipeline.shared.image(for: url) }
        }
    }

    private static func downsample(_ data: Data, maxPixel: CGFloat) -> UIImage? {
        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithData(data as CFData, sourceOptions) else { return nil }
        let options = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel,
        ] as CFDictionary
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}

/// Remote recipe photo. Shows the cached image immediately when available and never shows
/// a previous recipe's photo: each URL gets its own view identity (see `FoodImage`).
struct RemoteFoodImage: View {
    let url: URL
    @State private var image: UIImage?
    @State private var failed = false

    init(url: URL) {
        self.url = url
        _image = State(initialValue: RemoteImagePipeline.shared.cached(url))
    }

    var body: some View {
        ZStack {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .transition(.opacity)
            } else if failed {
                Image(systemName: "fork.knife").font(.largeTitle).foregroundStyle(BW.inkSecondary)
            } else {
                ProgressView().tint(BW.leaf)
            }
        }
        .task(id: url) {
            guard image == nil else { return }
            let loaded = await RemoteImagePipeline.shared.image(for: url)
            withAnimation(.easeOut(duration: 0.18)) {
                image = loaded
                failed = loaded == nil
            }
        }
    }
}
