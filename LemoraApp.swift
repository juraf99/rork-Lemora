import SwiftUI
import ClerkKit
import RevenueCat

@main
struct LemoraApp: App {
    @State private var store: AppStore = AppStore()
    @State private var auth: AuthManager = AuthManager()

    init() {
        LemoraFont.registerAll()
        Clerk.configure(publishableKey: "pk_test_cHJvbW90ZWQtZmVycmV0LTU2OTUuY2xlcmsuYWNjb3VudHMuZGV2JA")
        // RevenueCat handles purchases, restores and the `lemora_pro` entitlement.
        Purchases.configure(
            with: Configuration.Builder(withAPIKey: "appl_YFWfbULaxOsXSygRqTzkYwezqIk")
                .with(storeKitVersion: .storeKit2)
                .build()
        )
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(store)
                .environment(auth)
                .environment(Clerk.shared)
                .preferredColorScheme(.light)
                .tint(BW.ink)
                .task {
                    await SupabaseService.shared.verifyConnection()
                }
        }
    }
}
