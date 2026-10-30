import Foundation

/// Savings computed from this week's flyer deals, not from a budget percentage.
nonisolated struct FlyerWeekSavings: Equatable, Sendable {
    var weekly: Double
    var dealCount: Int
    var ends: Date?
}

/// What the onboarding answers produce, shown on the plan summary and paywall.
nonisolated struct PlanPreview: Sendable {
    let matches: [ScoredRecipe]
    let excludedCount: Int
    let dealCount: Int
    let storeNames: [String]
    let averagePerServing: Double
    /// Savings on the 3 best-value matched dinners, computed from sample flyer data.
    let sampleWeeklySavings: Double
}
