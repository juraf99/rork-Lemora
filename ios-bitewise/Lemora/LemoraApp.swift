import SwiftUI
import ClerkKit
import RevenueCat

@main
struct LemoraApp: App {
    @State private var store: AppStore = AppStore()
    @State private var auth: AuthManager = AuthManager()

    init() {
        AppLanguage.bootstrap()
        LemoraFont.registerAll()
        Clerk.configure(publishableKey: "pk_live_Y2xlcmsubGVtb3JhYXBwLmNvbSQ")
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
                // In-app language: the whole UI is rebuilt when it changes.
                .environment(\.locale, LanguageState.shared.current.locale)
                .id(LanguageState.shared.current)
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
