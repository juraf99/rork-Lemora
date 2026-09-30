import SwiftUI

@main
struct LemoraApp: App {
    @State private var store: AppStore = AppStore()
    @State private var auth: AuthManager = AuthManager()

    init() {
        LemoraFont.registerAll()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(store)
                .environment(auth)
                .preferredColorScheme(.light)
                .tint(BW.ink)
        }
    }
}
