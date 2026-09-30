import SwiftUI
import StoreKit

struct PaywallView: View {
    enum Context { case onboarding, upgrade }

    let context: Context
    let onClose: () -> Void

    @Environment(AppStore.self) private var store
    @State private var annualSelected: Bool = true
    @State private var isPurchasing: Bool = false
    @State private var message: String? = nil

    private var sub: SubscriptionService { store.subscription }

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                HStack {
                    Spacer()
                    Button(context == .onboarding ? String(localized: "Continue free") : String(localized: "Not now"), action: onClose)
                        .font(.bw(.subheadline, weight: .semibold))
                        .foregroundStyle(BW.inkSecondary)
                        .frame(minHeight: 44)
                }

                ZStack(alignment: .bottom) {
                    FoodImage(name: "teriyaki_chicken_rice_bowl", height: 200, radius: BW.heroRadius)
                    MascotView(name: BWImage.mascotCheer, size: 100, bob: true)
                        .offset(y: 50)
                }
                .padding(.bottom, 40)

                VStack(spacing: 6) {
                    Text("Bitewise Premium").font(.system(.largeTitle, design: .rounded, weight: .heavy)).foregroundStyle(BW.ink)
                    Text("Eat what you love. Pay less, every week.")
                        .font(.bw(.body, weight: .regular)).foregroundStyle(BW.inkSecondary)
                }
                .multilineTextAlignment(.center)

                VStack(alignment: .leading, spacing: 14) {
                    benefit("infinity", String(localized: "Unlimited discovery"), String(localized: "Swipe as many meals as you want."))
                    benefit("bookmark.fill", String(localized: "Permanent saves"), String(localized: "Keep every recipe you love, forever."))
                    benefit("tag.fill", String(localized: "Full weekly deals"), String(localized: "All of Worth It and Steals of the Week."))
                    benefit("cart.fill", String(localized: "Smart grocery lists"), String(localized: "Merged, grouped and optimized by store."))
                    benefit("bubble.left.and.text.bubble.right.fill", String(localized: "Advanced Ask"), String(localized: "Unlimited meal questions."))
                }
                .padding(20)
                .bwCard()

                VStack(spacing: 10) {
                    planRow(title: String(localized: "Annual"), price: sub.annual?.displayPrice ?? store.config.annualPriceFallback,
                            period: String(localized: "/year"), badge: store.config.trialEnabled ? String(localized: "7 days free") : nil,
                            selected: annualSelected) { annualSelected = true }
                    planRow(title: String(localized: "Monthly"), price: sub.monthly?.displayPrice ?? store.config.monthlyPriceFallback,
                            period: String(localized: "/month"), badge: nil, selected: !annualSelected) { annualSelected = false }
                }

                Button {
                    Task { await purchase() }
                } label: {
                    if isPurchasing { ProgressView().tint(BW.ink) }
                    else { Text(annualSelected && store.config.trialEnabled ? "Start 7-day free trial" : "Continue") }
                }
                .buttonStyle(BWPrimaryButtonStyle())
                .disabled(isPurchasing)

                if let message {
                    Text(message).font(.bw(.footnote, weight: .medium)).foregroundStyle(BW.inkSecondary).multilineTextAlignment(.center)
                }

                VStack(spacing: 8) {
                    Button("Restore purchases") { Task { await sub.restore(); if store.isPremium { onClose() } } }
                        .font(.bw(.footnote, weight: .semibold)).foregroundStyle(BW.ink)
                    Text("Subscriptions renew automatically unless cancelled at least 24 hours before the end of the period. Manage in your App Store settings.")
                        .font(.bw(.caption2, weight: .regular)).foregroundStyle(BW.inkSecondary).multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .background(BW.canvas)
        .onAppear { store.track("paywall_viewed") }
    }

    private func purchase() async {
        guard let product = annualSelected ? sub.annual : sub.monthly else {
            message = String(localized: "Subscriptions aren't available in this build yet. You can preview Premium from Profile.")
            return
        }
        isPurchasing = true
        defer { isPurchasing = false }
        do {
            if try await sub.purchase(product) {
                store.track("subscription_started", ["plan": product.id])
                onClose()
            }
        } catch {
            message = String(localized: "The purchase didn't go through. Please try again.")
        }
    }

    private func benefit(_ symbol: String, _ title: String, _ subtitle: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: symbol)
                .font(.headline).foregroundStyle(BW.ink)
                .frame(width: 40, height: 40)
                .background(BW.lemon, in: .circle)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.bw(.subheadline, weight: .bold)).foregroundStyle(BW.ink)
                Text(subtitle).font(.bw(.footnote, weight: .regular)).foregroundStyle(BW.inkSecondary)
            }
        }
    }

    private func planRow(title: String, price: String, period: String, badge: String?, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.title3).foregroundStyle(selected ? BW.ink : BW.outline)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.bw(.headline)).foregroundStyle(BW.ink)
                    if let badge { Text(badge).font(.bw(.caption, weight: .bold)).foregroundStyle(BW.leafDeep) }
                }
                Spacer()
                Text(price).font(.bw(.title3, weight: .heavy)).foregroundStyle(BW.ink)
                Text(period).font(.bw(.footnote, weight: .medium)).foregroundStyle(BW.inkSecondary)
            }
            .padding(.horizontal, 18)
            .frame(minHeight: 70)
            .background(selected ? BW.lemonSoft : BW.card, in: .rect(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(selected ? BW.lemon : BW.hairline, lineWidth: selected ? 2 : 1))
        }
        .buttonStyle(BWPressableStyle())
    }
}
