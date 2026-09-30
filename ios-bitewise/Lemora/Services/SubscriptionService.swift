import Foundation
import StoreKit
import OSLog

/// StoreKit 2 subscription handling. Product IDs must match App Store Connect.
@Observable
final class SubscriptionService {
    static let annualId = "app.lemora.premium.annual"
    static let monthlyId = "app.lemora.premium.monthly"

    private(set) var products: [Product] = []
    private(set) var hasActiveSubscription = false
    private(set) var hasCheckedEntitlements = false
    private(set) var isLoading = false
    /// StoreKit's answer to whether this Apple ID can still redeem the introductory offer.
    private(set) var isEligibleForTrial = false
    private var updatesTask: Task<Void, Never>?
    private let logger = Logger(subsystem: "app.bitewise", category: "subscriptions")

    var annual: Product? { products.first { $0.id == Self.annualId } }
    var monthly: Product? { products.first { $0.id == Self.monthlyId } }
    var productsAvailable: Bool { !products.isEmpty }

    func start() async {
        if updatesTask == nil {
            updatesTask = Task { [weak self] in
                for await update in Transaction.updates {
                    if case .verified(let transaction) = update {
                        await transaction.finish()
                    }
                    await self?.refreshEntitlements()
                }
            }
        }

        async let products: Void = loadProducts()
        async let entitlements: Void = refreshEntitlements()
        _ = await (products, entitlements)
    }

    func loadProducts() async {
        isLoading = true
        defer { isLoading = false }
        do {
            products = try await Product.products(for: [Self.annualId, Self.monthlyId])
            await refreshTrialEligibility()
        } catch {
            logger.error("Could not load products")
        }
    }

    func refreshEntitlements() async {
        defer { hasCheckedEntitlements = true }
        var active = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let t) = result, t.revocationDate == nil,
               t.productID == Self.annualId || t.productID == Self.monthlyId {
                active = true
            }
        }
        hasActiveSubscription = active
    }

    private func refreshTrialEligibility() async {
        guard let info = annual?.subscription,
              let offer = info.introductoryOffer,
              offer.paymentMode == .freeTrial,
              (offer.period.unit == .week && offer.period.value == 1 ||
               offer.period.unit == .day && offer.period.value == 7) else {
            isEligibleForTrial = false
            return
        }
        isEligibleForTrial = await info.isEligibleForIntroOffer
    }

    /// Returns true when the purchase completed and was verified.
    func purchase(_ product: Product) async throws -> Bool {
        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            guard case .verified(let transaction) = verification else { return false }
            await transaction.finish()
            await refreshEntitlements()
            return true
        case .userCancelled, .pending:
            return false
        @unknown default:
            return false
        }
    }

    /// Free-trial length in days, read from the product's configured introductory offer.
    static func trialDays(of product: Product) -> Int? {
        guard let offer = product.subscription?.introductoryOffer, offer.paymentMode == .freeTrial else { return nil }
        let value = offer.period.value
        switch offer.period.unit {
        case .day: return value
        case .week: return value * 7
        case .month: return value * 30
        case .year: return value * 365
        @unknown default: return nil
        }
    }

    static func amount(_ product: Product) -> Double {
        NSDecimalNumber(decimal: product.price).doubleValue
    }

    func restore() async {
        try? await StoreKit.AppStore.sync()
        await refreshEntitlements()
    }
}
