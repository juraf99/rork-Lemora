import Foundation
import StoreKit
import RevenueCat
import OSLog
import UIKit

/// Subscriptions through RevenueCat (entitlement `lemora_pro`). StoreKit `Product`s are exposed
/// for prices and the introductory offer; purchases, restores and entitlements go through RevenueCat.
@Observable
final class SubscriptionService {
    static let annualId = "app.lemora.premium.annual"
    static let monthlyId = "app.lemora.premium.monthly"
    static let entitlementId = "lemora_pro"
    /// TestFlight / sandbox build: purchases are free tests.
    static var isTestFlight: Bool { Bundle.main.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt" }

    private(set) var products: [Product] = []
    private(set) var hasActiveSubscription = false
    private(set) var hasCheckedEntitlements = false
    private(set) var isLoading = false
    /// StoreKit's answer to whether this Apple ID can still redeem the introductory offer.
    private(set) var isEligibleForTrial = false
    /// Current plan (from RevenueCat): product id, end of the paid period or trial, auto-renew, trial.
    private(set) var activeProductId: String?
    private(set) var expirationDate: Date?
    private(set) var willRenew = true
    private(set) var isInTrial = false
    @ObservationIgnored private var storeProducts: [String: StoreProduct] = [:]
    @ObservationIgnored private var updatesTask: Task<Void, Never>?
    private let logger = Logger(subsystem: "app.lemora", category: "subscriptions")

    var annual: Product? { products.first { $0.id == Self.annualId } }
    var monthly: Product? { products.first { $0.id == Self.monthlyId } }
    var productsAvailable: Bool { !products.isEmpty }

    func start() async {
        if updatesTask == nil {
            updatesTask = Task { [weak self] in
                for await info in Purchases.shared.customerInfoStream {
                    self?.apply(info)
                }
            }
        }
        async let products: Void = loadProducts()
        async let entitlements: Void = refreshEntitlements()
        _ = await (products, entitlements)
    }

    /// Ties purchases to the signed-in Clerk user so the subscription follows the account.
    func logIn(userId: String) async {
        do {
            let result = try await Purchases.shared.logIn(userId)
            apply(result.customerInfo)
        } catch {
            logger.error("RevenueCat logIn failed")
        }
    }

    func logOut() async {
        _ = try? await Purchases.shared.logOut()
        await refreshEntitlements()
    }

    func loadProducts() async {
        isLoading = true
        defer { isLoading = false }
        let fetched = await Purchases.shared.products([Self.annualId, Self.monthlyId])
        storeProducts = Dictionary(fetched.map { ($0.productIdentifier, $0) }, uniquingKeysWith: { a, _ in a })
        var sk2 = fetched.compactMap(\.sk2Product)
        if sk2.isEmpty {
            sk2 = (try? await Product.products(for: [Self.annualId, Self.monthlyId])) ?? []
        }
        products = sk2
        await refreshTrialEligibility()
        if products.isEmpty { logger.error("Could not load subscription products") }
    }

    func refreshEntitlements() async {
        defer { hasCheckedEntitlements = true }
        if let info = try? await Purchases.shared.customerInfo() {
            apply(info)
            return
        }
        // Offline fallback: StoreKit's own record of active subscriptions.
        var active = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let t) = result, t.revocationDate == nil,
               t.productID == Self.annualId || t.productID == Self.monthlyId {
                active = true
            }
        }
        hasActiveSubscription = active
    }

    private func apply(_ info: CustomerInfo) {
        let ent = info.entitlements[Self.entitlementId]
        hasActiveSubscription = ent?.isActive == true
            || !info.activeSubscriptions.isDisjoint(with: [Self.annualId, Self.monthlyId])
        if let ent, ent.isActive {
            activeProductId = ent.productIdentifier
            expirationDate = ent.expirationDate
            willRenew = ent.willRenew
            isInTrial = ent.periodType == .trial
        } else {
            activeProductId = info.activeSubscriptions.first { [Self.annualId, Self.monthlyId].contains($0) }
            expirationDate = activeProductId.flatMap { info.expirationDate(forProductIdentifier: $0) }
            willRenew = true
            isInTrial = false
        }
        hasCheckedEntitlements = true
    }

    /// Apple's own subscription sheet: cancel (access stays until the end of the period) or change plan.
    func showManageSubscriptions() async {
        do {
            try await Purchases.shared.showManageSubscriptions()
        } catch {
            if let url = URL(string: "https://apps.apple.com/account/subscriptions") { await UIApplication.shared.open(url) }
        }
        await refreshEntitlements()
    }

    private func refreshTrialEligibility() async {
        guard let info = annual?.subscription,
              let offer = info.introductoryOffer,
              offer.paymentMode == .freeTrial else {
            isEligibleForTrial = false
            return
        }
        isEligibleForTrial = await info.isEligibleForIntroOffer
    }

    /// Returns true when the purchase completed and the entitlement is active.
    func purchase(_ product: Product) async throws -> Bool {
        var storeProduct = storeProducts[product.id]
        if storeProduct == nil {
            storeProduct = await Purchases.shared.products([product.id]).first
        }
        guard let storeProduct else { return false }
        let result = try await Purchases.shared.purchase(product: storeProduct)
        if result.userCancelled { return false }
        apply(result.customerInfo)
        if hasActiveSubscription {
            let productId = activeProductId ?? product.id
            Analytics.track(.subscriptionPurchased(productId: productId, isTrial: isInTrial))
            if isInTrial {
                Analytics.track(.trialStarted(productId: productId, isTrial: true))
            }
        }
        return hasActiveSubscription
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
        if let info = try? await Purchases.shared.restorePurchases() {
            apply(info)
            if hasActiveSubscription {
                Analytics.track(.restorePurchases(productId: activeProductId, isTrial: isInTrial))
            }
        } else {
            await refreshEntitlements()
        }
    }
}
