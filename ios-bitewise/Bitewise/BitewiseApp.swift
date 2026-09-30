import SwiftUI

@main
struct BitewiseApp: App {
    @State private var store: AppStore = AppStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(store)
                .preferredColorScheme(.light)
                .tint(BW.ink)
        }
    }
}
