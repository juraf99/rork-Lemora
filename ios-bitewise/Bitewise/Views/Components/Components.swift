import SwiftUI

/// The Bitewise lemon mascot. Decorative, so hidden from VoiceOver by default.
struct MascotView: View {
    let name: String
    var size: CGFloat = 64
    var bob: Bool = false
    @State private var isUp: Bool = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Image(name)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .offset(y: bob && isUp ? -4 : 0)
            .accessibilityHidden(true)
            .onAppear {
                guard bob, !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) { isUp = true }
            }
    }
}

/// Food photo that fills its frame without breaking layout.
struct FoodImage: View {
    let name: String
    var height: CGFloat? = nil
    var radius: CGFloat = BW.cardRadius

    var body: some View {
        BW.beige
            .frame(height: height)
            .frame(maxWidth: .infinity)
            .overlay {
                Image(name)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .allowsHitTesting(false)
            }
            .clipShape(.rect(cornerRadius: radius))
            .accessibilityHidden(true)
    }
}

struct MatchBadge: View {
    let percent: Int
    var compact: Bool = false

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: "sparkle")
                .font(.system(size: compact ? 10 : 13, weight: .bold))
            Text("\(percent)% match")
                .font(compact ? .bw(.caption, weight: .bold) : .bw(.subheadline, weight: .bold))
                .monospacedDigit()
        }
        .foregroundStyle(BW.ink)
        .padding(.horizontal, compact ? 10 : 14)
        .padding(.vertical, compact ? 6 : 9)
        .background(BW.lemon, in: .capsule)
        .accessibilityElement(children: .combine)
    }
}

struct DealTag: View {
    let text: String
    var symbol: String = "leaf.fill"

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: symbol).font(.system(size: 10, weight: .bold))
            Text(text).font(.bw(.caption, weight: .bold))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(BW.leaf, in: .capsule)
    }
}

struct SoftChip: View {
    let text: String
    var symbol: String? = nil
    var fill: Color = BW.beigeSoft
    var foreground: Color = BW.ink

    var body: some View {
        HStack(spacing: 5) {
            if let symbol { Image(systemName: symbol).font(.caption.weight(.semibold)) }
            Text(text).font(.bw(.caption, weight: .semibold))
        }
        .foregroundStyle(foreground)
        .padding(.horizontal, 11)
        .padding(.vertical, 7)
        .background(fill, in: .capsule)
    }
}

struct SectionHeader: View {
    let title: String
    var subtitle: String? = nil
    var action: (() -> Void)? = nil
    var actionTitle: String = String(localized: "See All")

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.bw(.title2)).foregroundStyle(BW.ink)
                if let subtitle {
                    Text(subtitle).font(.bw(.subheadline, weight: .regular)).foregroundStyle(BW.inkSecondary)
                }
            }
            Spacer()
            if let action {
                Button(action: action) {
                    HStack(spacing: 2) {
                        Text(actionTitle)
                        Image(systemName: "chevron.right").font(.caption.weight(.bold))
                    }
                    .font(.bw(.subheadline, weight: .semibold))
                    .foregroundStyle(BW.inkSecondary)
                }
            }
        }
    }
}

/// Honest labelling: shown wherever development sample prices appear.
struct SamplePricesNote: View {
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "info.circle")
            Text("Sample prices while live flyer data is being connected.")
        }
        .font(.bw(.caption2, weight: .medium))
        .foregroundStyle(BW.inkSecondary)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Growth stage illustration for streaks: sprout -> plant -> full lemon.
enum GrowthStage {
    case sprout, plant, lemon

    static func forDays(_ days: Int) -> GrowthStage {
        days >= 30 ? .lemon : (days >= 7 ? .plant : .sprout)
    }

    static func forWeeks(_ weeks: Int) -> GrowthStage {
        weeks >= 4 ? .lemon : (weeks >= 2 ? .plant : .sprout)
    }

    var imageName: String {
        switch self {
        case .sprout: BWImage.stageSprout
        case .plant: BWImage.stagePlant
        case .lemon: BWImage.stageLemon
        }
    }
}

struct StreakPill: View {
    let days: Int

    var body: some View {
        HStack(spacing: 6) {
            Image(GrowthStage.forDays(days).imageName)
                .resizable().scaledToFit().frame(width: 22, height: 22)
            Text(days == 1 ? String(localized: "1 day") : String(localized: "\(days) days"))
                .font(.bw(.subheadline, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(BW.ink)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(BW.leafSoft, in: .capsule)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("Wise Streak: \(days) days"))
    }
}

struct EmptyStateView: View {
    let mascot: String
    let title: String
    let message: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 14) {
            MascotView(name: mascot, size: 110, bob: true)
            Text(title).font(.bw(.title3)).foregroundStyle(BW.ink).multilineTextAlignment(.center)
            Text(message).font(.bw(.subheadline, weight: .regular)).foregroundStyle(BW.inkSecondary)
                .multilineTextAlignment(.center)
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(BWPrimaryButtonStyle())
                    .padding(.top, 6)
                    .frame(maxWidth: 280)
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity)
    }
}

/// Speech-bubble tip from the mascot.
struct MascotTip: View {
    let text: String
    var mascot: String = BWImage.mascotWave

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            MascotView(name: mascot, size: 52)
            Text(text)
                .font(.bw(.subheadline, weight: .medium))
                .foregroundStyle(BW.ink)
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(BW.lemonSoft, in: .rect(cornerRadius: 16))
        }
        .accessibilityElement(children: .combine)
    }
}

struct TriStateBadge: View {
    let title: String
    let state: TriState

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: symbol)
            Text(title)
        }
        .font(.bw(.caption, weight: .semibold))
        .foregroundStyle(color)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(color.opacity(0.12), in: .capsule)
    }

    private var symbol: String {
        switch state {
        case .yes: "checkmark"
        case .no: "xmark"
        case .uncertain: "questionmark"
        }
    }

    private var color: Color {
        switch state {
        case .yes: BW.leafDeep
        case .no: BW.inkSecondary
        case .uncertain: BW.amber
        }
    }
}
