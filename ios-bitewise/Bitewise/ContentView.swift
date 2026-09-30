import SwiftUI

/// Routes between launch, auth, onboarding, paywall and the main app.
struct ContentView: View {
    @Environment(AppStore.self) private var store
    @State private var showSplash: Bool = true
    @State private var authMode: AuthView.Mode? = nil

    var body: some View {
        ZStack {
            BW.canvas.ignoresSafeArea()

            Group {
                if !store.isSignedIn {
                    LandingView(onStart: { authMode = .signUp }, onSignIn: { authMode = .signIn })
                } else if !store.data.onboardingComplete {
                    OnboardingFlowView()
                } else if !store.data.paywallSeen {
                    PaywallView(context: .onboarding) { store.finishPaywall() }
                } else {
                    MainTabView()
                }
            }
            .transition(.opacity)

            if showSplash {
                SplashView()
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .animation(.easeInOut(duration: 0.35), value: store.isSignedIn)
        .animation(.easeInOut(duration: 0.35), value: store.data.onboardingComplete)
        .animation(.easeInOut(duration: 0.35), value: store.data.paywallSeen)
        .sheet(item: $authMode) { mode in
            AuthView(mode: mode)
        }
        .task {
            await store.bootstrap()
            try? await Task.sleep(for: .milliseconds(900))
            withAnimation(.easeOut(duration: 0.4)) { showSplash = false }
        }
        .onChange(of: store.subscription.hasActiveSubscription) { _, _ in
            store.onSubscriptionChanged()
        }
    }
}

struct SplashView: View {
    @State private var appear: Bool = false

    var body: some View {
        ZStack {
            BW.canvas.ignoresSafeArea()
            VStack(spacing: 14) {
                MascotView(name: BWImage.mascotWave, size: 120)
                    .scaleEffect(appear ? 1 : 0.8)
                Text("Bitewise")
                    .font(.system(size: 40, weight: .heavy, design: .rounded))
                    .foregroundStyle(BW.ink)
            }
            .opacity(appear ? 1 : 0)
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) { appear = true }
        }
    }
}
