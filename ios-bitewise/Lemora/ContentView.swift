import SwiftUI

/// Landing → onboarding (Zest) → Build My Plan → summary → account → paywall → You're in! → app.
struct ContentView: View {
    @Environment(AppStore.self) private var store
    @State private var showSplash: Bool = true
    @State private var authMode: AuthView.Mode? = nil
    @State private var startedOnboarding: Bool = false

    private var showsLanding: Bool {
        !store.isSignedIn && (!startedOnboarding || store.data.onboardingComplete)
    }

    var body: some View {
        ZStack {
            BW.canvas.ignoresSafeArea()

            Group {
                if showsLanding {
                    LandingView(onStart: {
                        if store.data.onboardingComplete { authMode = .signUp } else { startedOnboarding = true }
                    }, onSignIn: { authMode = .signIn })
                } else if !store.data.onboardingComplete {
                    OnboardingFlowView()
                } else if !store.subscription.hasCheckedEntitlements {
                    SubscriptionStatusView()
                } else if !store.isPremium {
                    PaywallView(context: .onboarding) { store.finishPaywall() }
                } else if store.needsWelcome {
                    WelcomeView()
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
        .animation(.easeInOut(duration: 0.35), value: showsLanding)
        .animation(.easeInOut(duration: 0.35), value: store.data.onboardingComplete)
        .animation(.easeInOut(duration: 0.35), value: store.subscription.hasCheckedEntitlements)
        .animation(.easeInOut(duration: 0.35), value: store.isPremium)
        .animation(.easeInOut(duration: 0.35), value: store.needsWelcome)
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

private struct SubscriptionStatusView: View {
    var body: some View {
        VStack(spacing: 16) {
            ProgressView().tint(BW.ink)
            Text("Checking your subscription…")
                .font(.bw(.subheadline, weight: .semibold))
                .foregroundStyle(BW.inkSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(BW.canvas)
        .accessibilityElement(children: .combine)
    }
}

struct SplashView: View {
    @State private var appear: Bool = false

    var body: some View {
        ZStack {
            BW.canvas.ignoresSafeArea()
            VStack(spacing: 12) {
                ZestView(pose: .wave, size: 130)
                    .scaleEffect(appear ? 1 : 0.8)
                LemoraWordmark(size: 46)
            }
            .opacity(appear ? 1 : 0)
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) { appear = true }
        }
    }
}
