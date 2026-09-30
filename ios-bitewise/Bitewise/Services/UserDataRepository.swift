import Foundation
import OSLog

/// Persistence boundary for user data. The local implementation caches on device;
/// a backend implementation (source of truth for multi-device sync) conforms to the same protocol.
protocol UserDataRepository {
    func load() -> AppData?
    func save(_ data: AppData)
    func wipe()
}

struct LocalUserDataRepository: UserDataRepository {
    private let logger = Logger(subsystem: "app.bitewise", category: "persistence")

    private var url: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("bitewise-user.json")
    }

    func load() -> AppData? {
        guard let raw = try? Data(contentsOf: url) else { return nil }
        do {
            return try JSONDecoder().decode(AppData.self, from: raw)
        } catch {
            logger.error("Failed to decode user data")
            return nil
        }
    }

    func save(_ data: AppData) {
        do {
            let raw = try JSONEncoder().encode(data)
            try raw.write(to: url, options: [.atomic, .completeFileProtection])
        } catch {
            logger.error("Failed to save user data")
        }
    }

    func wipe() {
        try? FileManager.default.removeItem(at: url)
    }
}

/// Product analytics sink. Swap for a real provider without touching views.
protocol AnalyticsTracking {
    func track(_ event: String, _ properties: [String: String])
}

struct LogAnalytics: AnalyticsTracking {
    private let logger = Logger(subsystem: "app.bitewise", category: "analytics")

    func track(_ event: String, _ properties: [String: String]) {
        logger.debug("event=\(event, privacy: .public) props=\(properties.count)")
    }
}
