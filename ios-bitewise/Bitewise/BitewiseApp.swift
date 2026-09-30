import SwiftUI

@main
struct BitewiseApp: App {
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
