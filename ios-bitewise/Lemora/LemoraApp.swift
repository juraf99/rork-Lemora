import SwiftUI
import ClerkKit

@main
struct LemoraApp: App {
    @State private var store: AppStore = AppStore()
    @State private var auth: AuthManager = AuthManager()

    init() {
        LemoraFont.registerAll()
        Clerk.configure(publishableKey: "pk_test_cHJvbW90ZWQtZmVycmV0LTU2OTUuY2xlcmsuYWNjb3VudHMuZGV2JA")
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
