import Foundation

/// Remotely tunable product configuration. Defaults ship with the app; a backend
/// `RemoteConfigProvider` can override any value without an app update.
nonisolated struct RemoteConfig: Codable, Sendable {
    var dailySwipeLimit: Int = 5
    /// Taste calibration swipes that don't count toward the daily limit.
    /// Kept low while the sample recipe library is small; spec target is 10–15.
    var calibrationSwipes: Int = 4
    var temporarySaveHours: Int = 72
    var freeAskPerDay: Int = 3
    var trialEnabled: Bool = true
    var annualPriceFallback: String = "$39.99"
    var monthlyPriceFallback: String = "$9.99"
    var weights = RecommendationWeights()
}

nonisolated struct RecommendationWeights: Codable, Sendable {
    var taste: Double = 0.30
    var goal: Double = 0.25
    var deal: Double = 0.20
    var budget: Double = 0.10
    var time: Double = 0.05
    var novelty: Double = 0.10
}

protocol RemoteConfigProvider {
    func fetch() async -> RemoteConfig
}

struct BundledRemoteConfigProvider: RemoteConfigProvider {
    func fetch() async -> RemoteConfig { RemoteConfig() }
}

/// Centralized premium entitlements. Views ask for a capability, never "is premium".
nonisolated enum Entitlement: String, Sendable {
    case unlimitedSwipes, permanentSaves, fullDeals, advancedGroceryOptimization, mealPrep, advancedAsk, advancedRecommendations
}
