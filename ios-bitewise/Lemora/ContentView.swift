import SwiftUI

/// Onboarding v2 (landing → questions → plan → Clerk account → paywall → You're in!) → app.
struct ContentView: View {
    @Environment(AppStore.self) private var store
    @State private var showSplash: Bool = true

    private enum Route: Equatable { case onboarding, checking, paywall, app }

    private var route: Route {
        if !store.data.onboardingComplete || !store.isSignedIn { return .onboarding }
        if !store.subscription.hasCheckedEntitlements { return .checking }
        if !store.isPremium { return .paywall }
        return .app
    }

    var body: some View {
        ZStack {
            BW.canvas.ignoresSafeArea()

            Group {
                switch route {
                case .onboarding:
                    LemoraOnboardingView()
                        .id("onboarding")
                case .checking:
                    SubscriptionStatusView()
                case .paywall:
                    LemoraOnboardingView(startAt: .paywall)
                        .id("paywall")
                case .app:
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
        .animation(.easeInOut(duration: 0.35), value: route)
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
