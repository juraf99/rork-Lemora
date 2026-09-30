import Foundation

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
