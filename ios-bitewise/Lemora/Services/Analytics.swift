import Foundation
import OSLog
import PostHog

/// Public PostHog client settings. The project token is an ingestion key and is safe to ship in the app.
enum PostHogSettings {
    static let apiKey = "phc_CEMRpUvXyQK9CytuMeKuBE742cNZn67Ny8BXAq2u43Wh"
    static let host = "https://us.i.posthog.com"
    /// PostHog project 684936 (US cloud).
    static let projectId = "684936"
}

/// Product analytics. Views keep calling `AppStore.track`; this is the PostHog side of that sink.
enum Analytics {
    private static let logger = Logger(subsystem: "app.lemora", category: "analytics")
    private static var started = false
    /// Clerk user id currently identified in PostHog. posthog-ios ignores `identify(B)` while still identified as A.
    private(set) static var identifiedUserId: String?

    private static let booleanKeys: Set<String> = ["is_sandbox", "is_trial", "restored"]
    private static let droppedKeys: Set<String> = ["error", "email", "postal", "postal_code"]

    /// Call once from the app entry point, before any screen is shown.
    static func start() {
        guard !started else { return }
        let config = PostHogConfig(projectToken: PostHogSettings.apiKey, host: PostHogSettings.host)
        // Lifecycle events stay on (SDK default). Screen names are not swizzled.
        config.captureScreenViews = false
        config.sessionReplay = false
        config.surveys = false
        config.disableGeoIp = true
        PostHogSDK.shared.setup(config)
        started = true
        registerSuperProperties()
    }

    /// Links this device's events to the signed-in user. Pass the Clerk user id.
    /// Never pass an email address. Call `reset()` first when the user changes; this does that when needed.
    static func identify(userId: String) {
        let id = userId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !id.isEmpty else { return }
        if let current = identifiedUserId, current != id {
            reset()
        }
        guard identifiedUserId != id else { return }
        guard started else { return }
        PostHogSDK.shared.identify(id)
        identifiedUserId = id
    }

    /// Clears the current person. Super properties are wiped too, so the debug flag is registered again.
    static func reset() {
        identifiedUserId = nil
        guard started else { return }
        PostHogSDK.shared.reset()
        registerSuperProperties()
    }

    static func capture(_ event: String, _ properties: [String: String] = [:]) {
        let converted = convert(properties)
        guard started else {
            logger.debug("event=\(event, privacy: .public) skipped (PostHog not started)")
            return
        }
        if converted.isEmpty {
            PostHogSDK.shared.capture(event)
        } else {
            PostHogSDK.shared.capture(event, properties: converted)
        }
        logger.debug("event=\(event, privacy: .public)")
    }

    /// `reset()` drops registered properties, so this runs after setup and after every reset.
    private static func registerSuperProperties() {
        #if DEBUG
        let isDebugBuild = true
        #else
        let isDebugBuild = false
        #endif
        PostHogSDK.shared.register(["is_debug_build": isDebugBuild])
    }

    private static func convert(_ properties: [String: String]) -> [String: Any] {
        var out: [String: Any] = [:]
        for (key, value) in properties {
            if droppedKeys.contains(key) { continue }
            if booleanKeys.contains(key) {
                if value == "true" { out[key] = true }
                else if value == "false" { out[key] = false }
                else if !value.isEmpty { out[key] = value }
            } else if !value.isEmpty {
                out[key] = value
            }
        }
        return out
    }
}
