import Foundation
import StoreKit
import RevenueCat
import OSLog
import UIKit

/// Subscriptions through RevenueCat (entitlement `lemora_pro`).
/// The paywall buys the current offering's `$rc_annual` and `$rc_monthly` packages, so Offerings
/// and Experiments decide the products. StoreKit prices and the introductory offer are what the UI shows.
@Observable
final class SubscriptionService {
    /// Historical App Store product ids. Purchases do not use these; they only recognize an
    /// already-active subscription when the current offering has not loaded yet.
    static let annualId = "app.lemora.premium.annual"
    static let monthlyId = "app.lemora.premium.monthly"
    static let annualPackageIdentifier = "$rc_annual"
    static let monthlyPackageIdentifier = "$rc_monthly"
    static let entitlementId = "lemora_pro"
    /// TestFlight / sandbox build: purchases are free tests.
    static var isTestFlight: Bool { Bundle.main.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt" }
    /// Debug builds and TestFlight receipts are sandbox traffic. App Store release builds are not.
    static var isSandbox: Bool {
        #if DEBUG
        true
        #else
        isTestFlight
        #endif
    }

    enum Plan: String {
        case annual
        case monthly
    }

    private(set) var hasActiveSubscription = false
    private(set) var hasCheckedEntitlements = false
    private(set) var isLoading = false
    /// StoreKit's answer to whether this Apple ID can still redeem the yearly introductory offer.
    private(set) var isEligibleForTrial = false
    /// Current plan (from RevenueCat): product id, end of the paid period or trial, auto-renew, trial.
    private(set) var activeProductId: String?
    private(set) var expirationDate: Date?
    private(set) var willRenew = true
    private(set) var isInTrial = false
    private(set) var offeringIdentifier: String?
    private(set) var storefrontCountry: String?
    private(set) var annualPackage: Package?
    private(set) var monthlyPackage: Package?
    @ObservationIgnored private var updatesTask: Task<Void, Never>?
    @ObservationIgnored private var reminderChain: Task<Void, Never>?
    private let logger = Logger(subsystem: "app.lemora", category: "subscriptions")

    var annual: Product? { annualPackage?.storeProduct.sk2Product }
    var monthly: Product? { monthlyPackage?.storeProduct.sk2Product }
    var pricesLoaded: Bool { annualPriceText != nil && monthlyPriceText != nil }
    var productsAvailable: Bool { pricesLoaded }
    var annualPriceText: String? { priceText(for: .annual) }
    var monthlyPriceText: String? { priceText(for: .monthly) }
    var annualAmount: Double? { amount(for: .annual) }
    var monthlyAmount: Double? { amount(for: .monthly) }

    var currencyCode: String? {
        if let code = annual?.priceFormatStyle.currencyCode ?? monthly?.priceFormatStyle.currencyCode, !code.isEmpty {
            return code
        }
        return annualPackage?.storeProduct.currencyCode ?? monthlyPackage?.storeProduct.currencyCode
    }

    var activePlanIsAnnual: Bool {
        guard let id = activeProductId else { return false }
        if let packageId = annualPackage?.storeProduct.productIdentifier, id == packageId { return true }
        return id == Self.annualId
    }

    var activePlanIsMonthly: Bool {
        guard let id = activeProductId else { return false }
        if let packageId = monthlyPackage?.storeProduct.productIdentifier, id == packageId { return true }
        return id == Self.monthlyId
    }

    func package(for plan: Plan) -> Package? {
        switch plan {
        case .annual: annualPackage
        case .monthly: monthlyPackage
        }
    }

    /// Free-trial length on the yearly package only. Monthly never advertises a trial.
    func introductoryTrialDays(for plan: Plan) -> Int? {
        guard plan == .annual, let package = annualPackage else { return nil }
        if let product = package.storeProduct.sk2Product {
            return Self.trialDays(of: product)
        }
        guard let discount = package.storeProduct.introductoryDiscount else { return nil }
        return Self.trialDays(of: discount)
    }

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

    /// Ties purchases to the signed-in Clerk user, then identifies PostHog with that same id.
    func logIn(userId: String) async {
        let id = userId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !id.isEmpty else { return }
        do {
            let result = try await Purchases.shared.logIn(id)
            apply(result.customerInfo)
            // Set after logIn so the attribute lands on this Clerk user, not whoever was current before.
            setPostHogUserId(id)
            Analytics.identify(userId: id)
        } catch {
            logger.error("RevenueCat logIn failed")
        }
    }

    func logOut() async {
        do {
            _ = try await Purchases.shared.logOut()
            // logOut succeeded, so this clears the new anonymous user. A failed logOut leaves the
            // identified customer alone, including `$posthogUserId`.
            setPostHogUserId(nil)
        } catch {
            logger.error("RevenueCat logOut failed")
        }
        await refreshEntitlements()
    }

    /// Sets RevenueCat's `$posthogUserId` subscriber attribute to the Clerk user id.
    /// `setPostHogUserID` is not on purchases-ios 5.0.0 (this target's minimum); `setAttributes` is,
    /// and an empty string deletes the attribute.
    func setPostHogUserId(_ userId: String?) {
        guard Purchases.isConfigured else { return }
        let value = userId?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        Purchases.shared.attribution.setAttributes(["$posthogUserId": value])
    }

    func loadProducts() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let offerings = try await Purchases.shared.offerings()
            let current = offerings.current
            offeringIdentifier = current?.identifier
            annualPackage = current?.package(identifier: Self.annualPackageIdentifier) ?? current?.annual
            monthlyPackage = current?.package(identifier: Self.monthlyPackageIdentifier) ?? current?.monthly
        } catch {
            logger.error("Could not load RevenueCat offerings")
        }
        if storefrontCountry == nil {
            storefrontCountry = await Storefront.current?.countryCode
        }
        await refreshTrialEligibility()
        if annualPackage == nil || monthlyPackage == nil {
            logger.error("Current offering is missing the annual or monthly package")
        }
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
            if case .verified(let transaction) = result, transaction.revocationDate == nil,
               knownProductIds.contains(transaction.productID) {
                active = true
            }
        }
        hasActiveSubscription = active
    }

    private func apply(_ info: CustomerInfo) {
        let ent = info.entitlements[Self.entitlementId]
        let known = knownProductIds
        hasActiveSubscription = ent?.isActive == true || !info.activeSubscriptions.isDisjoint(with: known)
        if let ent, ent.isActive {
            activeProductId = ent.productIdentifier
            expirationDate = ent.expirationDate
            willRenew = ent.willRenew
            isInTrial = ent.periodType == .trial
        } else {
            activeProductId = info.activeSubscriptions.first { known.contains($0) }
            expirationDate = activeProductId.flatMap { info.expirationDate(forProductIdentifier: $0) }
            willRenew = true
            isInTrial = false
        }
        hasCheckedEntitlements = true
        syncTrialReminder()
    }

    /// Offer shown before Apple's cancel sheet. A promotional offer comes from the current RevenueCat
    /// package when Apple has one for this subscriber. Otherwise a monthly subscriber is offered the yearly price.
    enum RetentionOffer: Equatable {
        case promotional(title: String, detail: String)
        case yearly
        case stay
    }

    @ObservationIgnored private var pendingPromoPackage: Package?
    @ObservationIgnored private var pendingPromoOffer: PromotionalOffer?

    func prepareRetentionOffer() async -> RetentionOffer {
        pendingPromoPackage = nil
        pendingPromoOffer = nil
        var packages: [Package] = []
        if let current = package(for: activePlanIsMonthly ? .monthly : .annual) { packages.append(current) }
        if let annualPackage, !packages.contains(where: { $0.identifier == annualPackage.identifier }) {
            packages.append(annualPackage)
        }
        for package in packages {
            let offers = await Purchases.shared.eligiblePromotionalOffers(forProduct: package.storeProduct)
            guard let offer = offers.first else { continue }
            pendingPromoPackage = package
            pendingPromoOffer = offer
            let discount = offer.discount
            if discount.paymentMode == .freeTrial {
                return .promotional(
                    title: String(localized: "A free period is on your plan"),
                    detail: String(localized: "Take it before you cancel. Apple applies it to this subscription."))
            }
            let price = discount.localizedPriceString
            return .promotional(
                title: String(localized: "A lower price is on your plan"),
                detail: price.isEmpty
                    ? String(localized: "Take it before you cancel. Apple applies it to this subscription.")
                    : String(localized: "\(price) for the next period, instead of the regular price."))
        }
        if activePlanIsMonthly, annualPriceText != nil { return .yearly }
        return .stay
    }

    /// Buys the prepared promotional offer, or switches a monthly plan to yearly. Returns false when the person backs out.
    func acceptRetentionOffer(_ offer: RetentionOffer) async throws -> Bool {
        switch offer {
        case .promotional:
            guard let package = pendingPromoPackage, let promo = pendingPromoOffer else { return false }
            let result = try await Purchases.shared.purchase(package: package, promotionalOffer: promo)
            if result.userCancelled { return false }
            apply(result.customerInfo)
            return hasActiveSubscription
        case .yearly:
            return try await purchase(plan: .annual, paywallVariant: "retention")
        case .stay:
            return true
        }
    }

    enum RefundRequestResult { case success, cancelled, unavailable, failed }

    /// Opens Apple's refund request sheet for the latest Lemora subscription transaction.
    func requestRefund() async -> RefundRequestResult {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        guard let scene = scenes.first(where: { $0.activationState == .foregroundActive }) ?? scenes.first else {
            return .failed
        }
        var ids: [String] = []
        if let activeProductId { ids.append(activeProductId) }
        if let id = annualPackage?.storeProduct.productIdentifier { ids.append(id) }
        if let id = monthlyPackage?.storeProduct.productIdentifier { ids.append(id) }
        ids.append(contentsOf: [Self.annualId, Self.monthlyId])
        var seen = Set<String>()
        for id in ids where seen.insert(id).inserted {
            guard let result = await Transaction.latest(for: id), case .verified(let transaction) = result,
                  transaction.revocationDate == nil else { continue }
            do {
                Analytics.capture("refund_requested", ["product_id": id])
                let status = try await transaction.beginRefundRequest(in: scene)
                switch status {
                case .success: return .success
                case .userCancelled: return .cancelled
                @unknown default: return .failed
                }
            } catch {
                logger.error("Refund request failed")
                return .failed
            }
        }
        return .unavailable
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
        guard let package = annualPackage else {
            isEligibleForTrial = false
            return
        }
        if let info = package.storeProduct.sk2Product?.subscription,
           let offer = info.introductoryOffer, offer.paymentMode == .freeTrial {
            isEligibleForTrial = await info.isEligibleForIntroOffer
            return
        }
        guard package.storeProduct.introductoryDiscount?.paymentMode == .freeTrial else {
            isEligibleForTrial = false
            return
        }
        let eligibility = await Purchases.shared.checkTrialOrIntroDiscountEligibility(product: package.storeProduct)
        isEligibleForTrial = eligibility == .eligible
    }

    /// Returns true when the purchase completed and the entitlement is active.
    /// A successful purchase emits exactly one of `trial_started` or `subscription_started`.
    /// Cancelling emits `purchase_cancelled` and nothing else. An already-active plan emits neither.
    func purchase(plan: Plan, paywallVariant: String) async throws -> Bool {
        let props = analyticsProperties(plan: plan.rawValue, paywallVariant: paywallVariant, includeSandbox: true)
        Analytics.capture("purchase_started", props)
        guard let package = package(for: plan) else {
            Analytics.capture("purchase_failed", props.merging(["reason": "product_unavailable"]) { _, new in new })
            throw SubscriptionPurchaseError.unavailable
        }
        let wasActive = hasActiveSubscription
        do {
            let result = try await Purchases.shared.purchase(package: package)
            if result.userCancelled {
                Analytics.capture("purchase_cancelled", props)
                return false
            }
            apply(result.customerInfo)
            guard hasActiveSubscription else {
                Analytics.capture("purchase_failed", props.merging(["reason": "entitlement_inactive"]) { _, new in new })
                throw SubscriptionPurchaseError.notEntitled
            }
            if !wasActive {
                var outcome = analyticsProperties(plan: plan.rawValue, paywallVariant: paywallVariant, includeSandbox: true)
                outcome["product_id"] = result.transaction?.productIdentifier ?? package.storeProduct.productIdentifier
                if isInTrial {
                    outcome["is_trial"] = "true"
                    if let days = introductoryTrialDays(for: .annual) { outcome["days"] = "\(days)" }
                    Analytics.capture("trial_started", outcome)
                } else {
                    outcome["is_trial"] = "false"
                    Analytics.capture("subscription_started", outcome)
                }
            }
            return true
        } catch let error as ErrorCode where error == .purchaseCancelledError {
            Analytics.capture("purchase_cancelled", props)
            return false
        } catch is CancellationError {
            Analytics.capture("purchase_cancelled", props)
            return false
        } catch let error as SubscriptionPurchaseError {
            throw error
        } catch {
            Analytics.capture("purchase_failed", props.merging(["reason": "store_error"]) { _, new in new })
            throw error
        }
    }

    /// Returns false when the restore call itself fails. An empty restore (no entitlement) returns true
    /// and does not emit `restore_succeeded`.
    @discardableResult
    func restore(paywallVariant: String) async -> Bool {
        var props = analyticsProperties(
            plan: activePlanIsMonthly ? Plan.monthly.rawValue : Plan.annual.rawValue,
            paywallVariant: paywallVariant,
            includeSandbox: true)
        if !activePlanIsAnnual && !activePlanIsMonthly {
            props.removeValue(forKey: "plan")
            props.removeValue(forKey: "price")
            props.removeValue(forKey: "product_id")
        }
        Analytics.capture("restore_started", props)
        do {
            let info = try await Purchases.shared.restorePurchases()
            apply(info)
            guard hasActiveSubscription else { return true }
            var outcome = analyticsProperties(
                plan: activePlanIsMonthly ? Plan.monthly.rawValue : Plan.annual.rawValue,
                paywallVariant: paywallVariant,
                includeSandbox: true)
            outcome["is_trial"] = isInTrial ? "true" : "false"
            outcome["restored"] = "true"
            if let activeProductId { outcome["product_id"] = activeProductId }
            Analytics.capture("restore_succeeded", outcome)
            return true
        } catch {
            Analytics.capture("restore_failed", props.merging(["reason": "store_error"]) { _, new in new })
            return false
        }
    }

    func analyticsProperties(plan: String, paywallVariant: String, includeSandbox: Bool = false) -> [String: String] {
        let selected: Plan = plan == Plan.monthly.rawValue ? .monthly : .annual
        let package = package(for: selected)
        var props: [String: String] = [
            "plan": selected.rawValue,
            "paywall_variant": paywallVariant,
        ]
        if let offeringIdentifier { props["offering_id"] = offeringIdentifier }
        if let storefrontCountry { props["country"] = storefrontCountry }
        if let price = priceText(for: selected) { props["price"] = price }
        if let code = currencyCode { props["currency"] = code }
        if let productId = package?.storeProduct.productIdentifier { props["product_id"] = productId }
        if includeSandbox { props["is_sandbox"] = Self.isSandbox ? "true" : "false" }
        return props
    }

    /// Free-trial length in days, read from the product's configured introductory offer.
    static func trialDays(of product: Product) -> Int? {
        guard let offer = product.subscription?.introductoryOffer, offer.paymentMode == .freeTrial else { return nil }
        return days(value: offer.period.value, unit: offer.period.unit)
    }

    static func trialDays(of discount: StoreProductDiscount) -> Int? {
        guard discount.paymentMode == .freeTrial else { return nil }
        let periods = max(discount.numberOfPeriods, 1)
        return days(period: discount.subscriptionPeriod, multiplier: periods)
    }

    static func amount(_ product: Product) -> Double {
        NSDecimalNumber(decimal: product.price).doubleValue
    }

    private func priceText(for plan: Plan) -> String? {
        guard let package = package(for: plan) else { return nil }
        if let product = package.storeProduct.sk2Product { return product.displayPrice }
        let text = package.storeProduct.localizedPriceString
        return text.isEmpty ? nil : text
    }

    private func amount(for plan: Plan) -> Double? {
        guard let package = package(for: plan) else { return nil }
        let decimal = package.storeProduct.sk2Product?.price ?? package.storeProduct.price
        return NSDecimalNumber(decimal: decimal).doubleValue
    }

    private var knownProductIds: Set<String> {
        var ids: Set<String> = [Self.annualId, Self.monthlyId]
        if let id = annualPackage?.storeProduct.productIdentifier { ids.insert(id) }
        if let id = monthlyPackage?.storeProduct.productIdentifier { ids.insert(id) }
        return ids
    }

    private static func days(value: Int, unit: Product.SubscriptionPeriod.Unit) -> Int? {
        switch unit {
        case .day: return value
        case .week: return value * 7
        case .month: return value * 30
        case .year: return value * 365
        @unknown default: return nil
        }
    }

    private static func days(period: RevenueCat.SubscriptionPeriod, multiplier: Int) -> Int? {
        let value = period.value * multiplier
        switch period.unit {
        case .day: return value
        case .week: return value * 7
        case .month: return value * 30
        case .year: return value * 365
        @unknown default: return nil
        }
    }

    private func syncTrialReminder() {
        let snapshot = TrialReminderService.Snapshot(
            inTrial: isInTrial,
            willRenew: willRenew,
            expiration: expirationDate,
            trialDays: introductoryTrialDays(for: .annual),
            priceText: annualPriceText ?? "")
        let props = analyticsProperties(plan: Plan.annual.rawValue, paywallVariant: "trial_reminder", includeSandbox: true)
        let previous = reminderChain
        reminderChain = Task {
            await previous?.value
            let outcome = await TrialReminderService.reconcile(snapshot)
            if outcome == .scheduled {
                Analytics.capture("trial_reminder_scheduled", props)
            }
        }
    }
}

enum SubscriptionPurchaseError: Error {
    case unavailable
    case notEntitled
}
