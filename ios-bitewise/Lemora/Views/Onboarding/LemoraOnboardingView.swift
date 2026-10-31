import SwiftUI

/// Lemora onboarding v2: landing → questions → savings → loading → hard paywall → account → you're in.
/// Answers are kept on device while the user is a guest and saved to Supabase once signed in.
struct LemoraOnboardingView: View {
    @Environment(AppStore.self) private var store
    @State private var model: OnboardingModel

    init(entry: OnboardingModel.Entry = .signedOut) {
        _model = State(initialValue: OnboardingModel(entry: entry))
    }

    var body: some View {
        ZStack {
            OB.cream.ignoresSafeArea()
            screen
                .id(OnboardingModel.steps.contains(model.screen) ? "steps" : model.screen.rawValue)
                .transition(.opacity)
            if model.showMerge {
                OBMergeSheet()
                    .zIndex(2)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: model.screen)
        .animation(.easeOut(duration: 0.25), value: model.showMerge)
        .sensoryFeedback(.selection, trigger: model.hapticKey)
        .sensoryFeedback(.impact(weight: .light), trigger: model.screen)
        .environment(model)
        .preferredColorScheme(.light)
        .onChange(of: model.location.state) { _, state in
            switch state {
            case .resolved(let code): model.applyDevicePostal(code)
            case .denied, .failed: model.locationFailed()
            default: break
            }
        }
        .onAppear {
            ZestyGaze.shared.start()
            store.track("onboarding_v2_viewed", ["screen": model.screen.rawValue])
            store.track("onboarding_screen_viewed", ["screen": model.screen.rawValue])
        }
        .onChange(of: model.screen) { _, screen in
            store.track("onboarding_screen_viewed", ["screen": screen.rawValue])
        }
        .task { await model.restoreRemoteAnswersIfNeeded() }
    }

    @ViewBuilder private var screen: some View {
        switch model.screen {
        case .landing: OBLandingScreen()
        case .signin: OBSignInScreen()
        case .hear, .goal, .weightAsk, .branch, .people, .diet, .allergies, .dislikes, .meals, .location, .stores, .budget, .strategy: OBStepScreen()
        case .thanks: OBThanksScreen()
        case .notif: OBNotifScreen()
        case .ready: OBReadyScreen()
        case .generating: OBGeneratingScreen()
        case .savings: OBSavingsScreen()
        case .reminder: OBReminderScreen()
        case .plan: OBPlanScreen()
        case .account: OBAccountScreen()
        case .email: OBEmailScreen()
        case .verify: OBVerifyScreen()
        case .paywall: OBPaywallScreen()
        case .done: OBDoneScreen()
        }
    }
}
