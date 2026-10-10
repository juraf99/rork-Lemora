import SwiftUI
import UIKit
import ImageIO

/// Recipe photos that never show a spinner while swiping.
/// 1. Photos of the permanent catalogue ship inside the app (Resources/RecipePhotos, ~860 px WebP):
///    they open instantly, even offline.
/// 2. Decoded images stay in memory, so a card that comes back is immediate.
/// 3. Photos not in the app (new recipes) are downloaded once, kept on disk, and prefetched ahead.
/// Decoding happens off the main thread whenever possible.
nonisolated final class RemoteImagePipeline: @unchecked Sendable {
    static let shared = RemoteImagePipeline()

    private let cache = NSCache<NSURL, UIImage>()
    private let session: URLSession
    private let lock = NSLock()
    private var inFlight: [URL: Task<UIImage?, Never>] = [:]

    private init() {
        cache.countLimit = 160
        cache.totalCostLimit = 220 * 1024 * 1024
        let config = URLSessionConfiguration.default
        config.urlCache = URLCache(memoryCapacity: 16 * 1024 * 1024, diskCapacity: 400 * 1024 * 1024)
        config.requestCachePolicy = .returnCacheDataElseLoad
        config.httpMaximumConnectionsPerHost = 6
        session = URLSession(configuration: config)
    }

    // MARK: Lookup

    func cached(_ url: URL) -> UIImage? {
        cache.object(forKey: url as NSURL)
    }

    /// Bundled copy of a catalogue photo: ".../catalogue/<id>.webp" -> "recipe-<id>.webp" in the app.
    static func bundledFile(for url: URL) -> URL? {
        let id = url.deletingPathExtension().lastPathComponent
        guard !id.isEmpty else { return nil }
        return Bundle.main.url(forResource: "recipe-\(id)", withExtension: "webp")
    }

    /// Memory cache, else the photo shipped in the app (decoded right away). Never touches the network.
    func immediate(_ url: URL) -> UIImage? {
        if let hit = cached(url) { return hit }
        guard let file = Self.bundledFile(for: url),
              let data = try? Data(contentsOf: file),
              let image = Self.decode(data) else { return nil }
        store(image, for: url)
        return image
    }

    func image(for url: URL) async -> UIImage? {
        if let hit = cached(url) { return hit }
        let task: Task<UIImage?, Never> = lock.withLock {
            if let existing = inFlight[url] { return existing }
            let session = self.session
            let created = Task.detached(priority: .userInitiated) { () -> UIImage? in
                if let file = RemoteImagePipeline.bundledFile(for: url), let data = try? Data(contentsOf: file) {
                    return RemoteImagePipeline.decode(data)
                }
                guard let (data, response) = try? await session.data(from: url),
                      (response as? HTTPURLResponse).map({ (200..<300).contains($0.statusCode) }) ?? true
                else { return nil }
                return RemoteImagePipeline.decode(data)
            }
            inFlight[url] = created
            return created
        }
        let image = await task.value
        lock.withLock { inFlight[url] = nil }
        if let image { store(image, for: url) }
        return image
    }

    // MARK: Warm-up

    /// Warms the cache for the next cards so they appear instantly when swiped in.
    func prefetch(_ urls: [URL]) {
        for url in urls where cached(url) == nil {
            Task.detached(priority: .utility) { _ = await RemoteImagePipeline.shared.image(for: url) }
        }
    }

    /// Used during the launch screen: waits until these photos are ready (or the timeout passes).
    func preload(_ urls: [URL], timeout: Duration) async {
        let missing = urls.filter { cached($0) == nil }
        guard !missing.isEmpty else { return }
        for url in missing {
            Task.detached(priority: .userInitiated) { _ = await RemoteImagePipeline.shared.image(for: url) }
        }
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: timeout)
        while clock.now < deadline {
            if missing.allSatisfy({ cached($0) != nil }) { return }
            try? await Task.sleep(for: .milliseconds(40))
        }
    }

    // MARK: Private

    private func store(_ image: UIImage, for url: URL) {
        let cost = Int(image.size.width * image.size.height * image.scale * image.scale * 4)
        cache.setObject(image, forKey: url as NSURL, cost: cost)
    }

    private static func decode(_ data: Data, maxPixel: CGFloat = 1080) -> UIImage? {
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

/// Recipe photo. Shows the in-app or cached image on the very first frame; each URL gets its own
/// view identity (see `FoodImage`), so a previous recipe's photo can never appear.
struct RemoteFoodImage: View {
    let url: URL
    @State private var image: UIImage?
    @State private var failed = false

    init(url: URL) {
        self.url = url
        _image = State(initialValue: RemoteImagePipeline.shared.immediate(url))
    }

    var body: some View {
        ZStack {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else if failed {
                Image(systemName: "fork.knife").font(.largeTitle).foregroundStyle(BW.inkSecondary)
            } else {
                // Soft placeholder instead of a spinner (only for brand-new recipes not shipped in the app).
                LinearGradient(colors: [BW.beige, BW.beigeSoft], startPoint: .topLeading, endPoint: .bottomTrailing)
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
