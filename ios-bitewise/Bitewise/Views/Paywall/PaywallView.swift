import SwiftUI
import StoreKit

/// Lemora Premium paywall. Layout follows the approved reference: sunny Zest hero, premium pill,
/// "Unlock Your Full Plan Today", trial timeline card, yearly/monthly cards and a shining CTA.
struct PaywallView: View {
    enum Context { case onboarding, upgrade }

    let context: Context
    let onClose: () -> Void

    @Environment(AppStore.self) private var store
    @State private var annualSelected: Bool = true
    @State private var isPurchasing: Bool = false
    @State private var message: String? = nil
    @State private var appeared: Bool = false
    @State private var zestTalking: Bool = false
    @State private var showPrivacy: Bool = false
    @State private var purchaseSuccess: Int = 0

    private var sub: SubscriptionService { store.subscription }
    private var terms: PaywallTerms { .make(sub: sub, config: store.config, annualSelected: annualSelected) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                hero
                VStack(alignment: .leading, spacing: 18) {
                    premiumPill
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Unlock Your Full Plan Today")
                            .font(.bw(size: 34, weight: .heavy))
                            .tracking(-0.6)
                            .foregroundStyle(BW.ink)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(subtitle)
                            .font(.bw(.body, weight: .regular))
                            .foregroundStyle(BW.inkSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    timelineCard
                    planCards.padding(.top, 16)
                    if let message {
                        Text(message)
                            .font(.bw(.footnote, weight: .medium))
                            .foregroundStyle(BW.inkSecondary)
                            .frame(maxWidth: .infinity)
                            .multilineTextAlignment(.center)
                    }
                    bottomLinks
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 16)
            }
        }
        .scrollIndicators(.hidden)
        .background {
            ZStack(alignment: .top) {
                BW.canvas
                LinearGradient(colors: [BW.sun, BW.canvas], startPoint: .top, endPoint: .bottom)
                    .frame(height: 460)
            }
            .ignoresSafeArea()
        }
        .overlay(alignment: .topTrailing) { closeButton }
        .safeAreaInset(edge: .bottom, spacing: 0) { ctaBar }
        .sensoryFeedback(.success, trigger: purchaseSuccess)
        .sheet(isPresented: $showPrivacy) { NavigationStack { PrivacyView() } }
        .onAppear {
            store.track("paywall_viewed", ["context": context == .onboarding ? "onboarding" : "upgrade"])
            appeared = true
        }
    }

    // MARK: Hero

    private var hero: some View {
        VStack(spacing: 0) {
            ZestBubble(text: String(localized: "Your plan is ready!"), isTalking: $zestTalking)
                .offset(x: 64)
                .padding(.bottom, -6)
            ZStack(alignment: .bottom) {
                Ellipse()
                    .fill(BW.ink.opacity(0.10))
                    .frame(width: 104, height: 14)
                    .blur(radius: 5)
                    .offset(y: 4)
                ZestView(pose: .wave, size: 168, hopEvery: 4.5, talking: zestTalking)
            }
        }
        .padding(.top, 34)
        .padding(.bottom, 26)
        .frame(maxWidth: .infinity)
        .background {
            ZStack {
                SunburstView().frame(width: 600, height: 600)
                FloatingDots()
            }
        }
        .clipped()
    }

    private var closeButton: some View {
        Button(action: onClose) {
            Image(systemName: "xmark")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(BW.ink)
                .frame(width: 40, height: 40)
                .background(.white.opacity(0.9), in: .circle)
                .shadow(color: BW.ink.opacity(0.08), radius: 6, x: 0, y: 2)
                .frame(width: 44, height: 44)
        }
        .padding(.trailing, 14)
        .padding(.top, 4)
        .accessibilityLabel(context == .onboarding ? Text("Continue with Free") : Text("Close"))
    }

    private var premiumPill: some View {
        HStack(spacing: 7) {
            Image(systemName: "sparkle")
            Text("LEMORA PREMIUM").tracking(1.1)
        }
        .font(.bw(.subheadline, weight: .heavy))
        .foregroundStyle(BW.lemon)
        .padding(.horizontal, 16)
        .padding(.vertical, 9)
        .background(BW.ink, in: .capsule)
    }

    private var subtitle: String {
        let count = store.myStoreIds.count
        switch count {
        case 0: return String(localized: "Tailored to your goal, your diet and your budget.")
        case 1: return String(localized: "Tailored to your goal, your diet and 1 store near you.")
        default: return String(localized: "Tailored to your goal, your diet and \(count) stores near you.")
        }
    }

    // MARK: Timeline

    private var timelineSteps: [PaywallTimelineStep] {
        let t = terms
        let unlocks = [String(localized: "Unlimited swipes"), String(localized: "Every weekly deal"), String(localized: "Saves that never expire")]
        if let days = t.trialDays, let reminder = t.reminderDay {
            return [
                PaywallTimelineStep(id: "today", icon: "lock.open.fill", highlighted: true, title: String(localized: "Today"),
                                    detail: String(localized: "Your full personalized Lemora plan unlocks."), checks: unlocks),
                PaywallTimelineStep(id: "reminder", icon: "bell.fill", highlighted: false, title: String(localized: "Day \(reminder)"),
                                    detail: String(localized: "We'll remind you that your free trial is ending soon."), checks: []),
                PaywallTimelineStep(id: "billing", icon: "star.fill", highlighted: false, title: String(localized: "Day \(days)"),
                                    detail: String(localized: "\(t.annualPrice)/year starts. Cancel anytime before."), checks: []),
            ]
        }
        let price = annualSelected ? "\(t.annualPrice)/\(String(localized: "year"))" : "\(t.monthlyPrice)/\(String(localized: "month"))"
        return [
            PaywallTimelineStep(id: "today", icon: "lock.open.fill", highlighted: true, title: String(localized: "Today"),
                                detail: String(localized: "Your full plan unlocks right away. \(price) starts today."), checks: unlocks),
            PaywallTimelineStep(id: "renew", icon: "arrow.triangle.2.circlepath", highlighted: false,
                                title: annualSelected ? String(localized: "Every year") : String(localized: "Every month"),
                                detail: String(localized: "Renews automatically. Cancel anytime in Settings."), checks: []),
        ]
    }

    private var timelineCard: some View {
        let steps = timelineSteps
        return VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(steps.enumerated()), id: \.element.id) { index, step in
                PaywallTimelineRow(step: step, index: index, isLast: index == steps.count - 1, appeared: appeared)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .bwCard(radius: 26)
        .animation(.snappy, value: annualSelected)
    }

    // MARK: Plans

    private var planCards: some View {
        let t = terms
        return HStack(alignment: .top, spacing: 12) {
            PaywallPlanCard(
                title: String(localized: "YEARLY"), price: t.annualPrice,
                detail: String(localized: "\(t.annualPerMonth) / month"),
                note: t.annualTrialDays.map { String(localized: "\($0) days free") } ?? String(localized: "Billed yearly"),
                badge: t.savingsPercent.map { String(localized: "BEST VALUE · -\($0)%") },
                selected: annualSelected) { annualSelected = true }
            PaywallPlanCard(
                title: String(localized: "MONTHLY"), price: t.monthlyPrice,
                detail: String(localized: "per month"), note: String(localized: "No trial"),
                badge: nil, selected: !annualSelected) { annualSelected = false }
        }
        .sensoryFeedback(.selection, trigger: annualSelected)
    }

    private var ctaBar: some View {
        VStack(spacing: 10) {
            Button {
                Task { await purchase() }
            } label: {
                ZStack {
                    Text(terms.ctaTitle).opacity(isPurchasing ? 0 : 1)
                    if isPurchasing { ProgressView().tint(BW.ink) }
                }
                .contentTransition(.opacity)
            }
            .buttonStyle(ShineButtonStyle())
            .disabled(isPurchasing)
            .animation(.snappy, value: annualSelected)

            Text(terms.footnote)
                .font(.bw(.footnote, weight: .medium))
                .foregroundStyle(BW.inkSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 22)
        .padding(.top, 14)
        .padding(.bottom, 6)
        .background {
            LinearGradient(stops: [.init(color: BW.canvas.opacity(0), location: 0), .init(color: BW.canvas, location: 0.3)],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
        }
    }

    private var bottomLinks: some View {
        VStack(spacing: 12) {
            if context == .onboarding {
                Button("Continue with Free", action: onClose)
                    .font(.bw(.subheadline, weight: .bold))
                    .foregroundStyle(BW.ink)
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            HStack(spacing: 18) {
                Button("Restore") {
                    Task {
                        await sub.restore()
                        if store.isPremium { onClose() } else { message = String(localized: "No active subscription found for this Apple ID.") }
                    }
                }
                if let terms = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/") {
                    Link("Terms", destination: terms)
                }
                Button("Privacy") { showPrivacy = true }
            }
            .font(.bw(.footnote, weight: .semibold))
            .foregroundStyle(BW.inkSecondary)
            .frame(maxWidth: .infinity, minHeight: 44)

            Text("Subscriptions renew automatically unless cancelled at least 24 hours before the end of the period. Manage or cancel anytime in your App Store settings.")
                .font(.bw(.caption2, weight: .regular))
                .foregroundStyle(BW.inkSecondary.opacity(0.8))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
        }
        .padding(.top, 4)
    }

    private func purchase() async {
        guard let product = annualSelected ? sub.annual : sub.monthly else {
            message = String(localized: "Subscriptions aren't live in this build yet. You can preview Premium from Profile.")
            return
        }
        let current = terms
        isPurchasing = true
        defer { isPurchasing = false }
        do {
            if try await sub.purchase(product) {
                if let days = current.trialDays {
                    store.recordTrialStart(days: days, priceText: current.annualPrice)
                }
                store.track("subscription_started", ["plan": product.id])
                purchaseSuccess += 1
                onClose()
            }
        } catch {
            message = String(localized: "The purchase didn't go through. Please try again.")
        }
    }
}

struct PaywallTimelineStep: Identifiable {
    let id: String
    let icon: String
    let highlighted: Bool
    let title: String
    let detail: String
    let checks: [String]
}

private struct PaywallTimelineRow: View {
    let step: PaywallTimelineStep
    let index: Int
    let isLast: Bool
    let appeared: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: step.icon)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(step.highlighted ? BW.ink : BW.amber)
                .frame(width: 44, height: 44)
                .background(step.highlighted ? BW.lemon : BW.beigeSoft, in: .circle)
                .scaleEffect(appeared ? 1 : 0.4)

            VStack(alignment: .leading, spacing: 4) {
                Text(step.title).font(.bw(.title3, weight: .heavy)).foregroundStyle(BW.ink)
                Text(step.detail)
                    .font(.bw(.subheadline, weight: .regular))
                    .foregroundStyle(BW.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                if !step.checks.isEmpty {
                    VStack(alignment: .leading, spacing: 7) {
                        ForEach(Array(step.checks.enumerated()), id: \.offset) { j, check in
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 10, weight: .heavy))
                                    .foregroundStyle(.white)
                                    .frame(width: 20, height: 20)
                                    .background(BW.leaf, in: .circle)
                                    .scaleEffect(appeared ? 1 : 0.01)
                                    .animation(.spring(response: 0.42, dampingFraction: 0.55).delay(0.6 + Double(j) * 0.16), value: appeared)
                                Text(check).font(.bw(.subheadline, weight: .semibold)).foregroundStyle(BW.ink)
                            }
                        }
                    }
                    .padding(.top, 6)
                }
            }
            .padding(.top, 2)
            .padding(.bottom, isLast ? 0 : 20)
            Spacer(minLength: 0)
        }
        .background(alignment: .topLeading) {
            if !isLast {
                Capsule()
                    .fill(step.highlighted ? BW.lemon : BW.beige)
                    .frame(width: 3)
                    .padding(.top, 50)
                    .padding(.bottom, 6)
                    .padding(.leading, 20.5)
            }
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 14)
        .animation(.spring(response: 0.55, dampingFraction: 0.82).delay(0.15 + Double(index) * 0.14), value: appeared)
        .accessibilityElement(children: .combine)
    }
}

private struct PaywallPlanCard: View {
    let title: String
    let price: String
    let detail: String
    let note: String
    let badge: String?
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.bw(.subheadline, weight: .bold))
                    .tracking(1.2)
                    .foregroundStyle(selected ? .white.opacity(0.72) : BW.inkSecondary)
                Text(price)
                    .font(.bw(size: 32, weight: .heavy, relativeTo: .title))
                    .monospacedDigit()
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                    .foregroundStyle(selected ? .white : BW.ink)
                    .padding(.top, 4)
                Text(detail)
                    .font(.bw(.subheadline, weight: .medium))
                    .foregroundStyle(selected ? .white.opacity(0.78) : BW.inkSecondary)
                Text(note)
                    .font(.bw(.subheadline, weight: .heavy))
                    .foregroundStyle(selected ? BW.lemon : BW.leafDeep)
                    .padding(.top, 8)
            }
            .padding(.horizontal, 18)
            .padding(.top, badge == nil ? 18 : 26)
            .padding(.bottom, 18)
            .frame(maxWidth: .infinity, minHeight: 156, alignment: .topLeading)
            .background(selected ? BW.ink : BW.card, in: .rect(cornerRadius: 26))
            .overlay {
                RoundedRectangle(cornerRadius: 26)
                    .strokeBorder(selected ? .clear : BW.hairline, lineWidth: 1.5)
            }
            .shadow(color: BW.ink.opacity(selected ? 0.22 : 0.05), radius: selected ? 16 : 10, x: 0, y: selected ? 10 : 4)
            .overlay(alignment: .topLeading) {
                if let badge {
                    Text(badge)
                        .font(.bw(.caption, weight: .heavy))
                        .tracking(0.6)
                        .foregroundStyle(BW.ink)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(BW.lemon, in: .capsule)
                        .offset(x: 16, y: -14)
                }
            }
        }
        .buttonStyle(BWPressableStyle())
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: selected)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
