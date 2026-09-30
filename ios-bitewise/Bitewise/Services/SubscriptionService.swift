import Foundation
import StoreKit
import OSLog

/// StoreKit 2 subscription handling. Product IDs must match App Store Connect.
@Observable
final class SubscriptionService {
    static let annualId = "app.bitewise.premium.annual"
    static let monthlyId = "app.bitewise.premium.monthly"

    private(set) var products: [Product] = []
    private(set) var hasActiveSubscription = false
    private(set) var isLoading = false
    private var updatesTask: Task<Void, Never>?
    private let logger = Logger(subsystem: "app.bitewise", category: "subscriptions")

    var annual: Product? { products.first { $0.id == Self.annualId } }
    var monthly: Product? { products.first { $0.id == Self.monthlyId } }
    var productsAvailable: Bool { !products.isEmpty }

    func start() {
        guard updatesTask == nil else { return }
        updatesTask = Task { [weak self] in
            for await update in Transaction.updates {
                if case .verified(let transaction) = update {
                    await transaction.finish()
                }
                await self?.refreshEntitlements()
            }
        }
        Task {
            await loadProducts()
            await refreshEntitlements()
        }
    }

    func loadProducts() async {
        isLoading = true
        defer { isLoading = false }
        do {
            products = try await Product.products(for: [Self.annualId, Self.monthlyId])
        } catch {
            logger.error("Could not load products")
        }
    }

    func refreshEntitlements() async {
        var active = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let t) = result, t.revocationDate == nil,
               t.productID == Self.annualId || t.productID == Self.monthlyId {
                active = true
            }
        }
        hasActiveSubscription = active
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

    func restore() async {
        try? await StoreKit.AppStore.sync()
        await refreshEntitlements()
    }
}
