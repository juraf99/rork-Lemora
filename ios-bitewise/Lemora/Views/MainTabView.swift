import SwiftUI

enum AppTab: Hashable {
    case discover, deals, liked, ask, profile
}

/// Destinations pushed onto any tab's navigation stack.
enum Route: Hashable {
    case recipe(String)
    case deal(String)
    case streaks
    case worthItAll
    case stealsAll
}

struct MainTabView: View {
    @Environment(AppStore.self) private var store
    @State private var tab: AppTab = .discover

    var body: some View {
        TabView(selection: $tab) {
            DealsView().tag(AppTab.deals)
            SavedView().tag(AppTab.liked)
            DiscoverView().tag(AppTab.discover)
            AskView().tag(AppTab.ask)
            ProfileView().tag(AppTab.profile)
        }
        .toolbar(.hidden, for: .tabBar)
        .tint(BW.ink)
        .sensoryFeedback(.impact(weight: .medium), trigger: tab)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            LemoraTabBar(selection: $tab)
        }
        .overlay(alignment: .bottom) {
            if tab != .deals { NewAreaToast().padding(.bottom, 78) }
        }
        .animation(.snappy, value: store.checkingNewArea)
        .sensoryFeedback(.success, trigger: store.checkingNewArea) { old, new in old && !new }
    }
}

/// v10 tab bar: outline icons, Discover as a raised yellow circle in the middle.
struct LemoraTabBar: View {
    @Binding var selection: AppTab

    var body: some View {
        HStack(alignment: .bottom, spacing: 0) {
            item(.deals, title: String(localized: "Deals"), symbol: "tag")
            item(.liked, title: String(localized: "Saved"), symbol: "bookmark.fill")
            discover
            item(.ask, title: String(localized: "Ask"), symbol: "bubble.left.and.text.bubble.right")
            item(.profile, title: String(localized: "Profile"), symbol: "person")
        }
        .padding(.horizontal, 6)
        .padding(.top, 6)
        .padding(.bottom, 4)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) { Divider() }
    }

    private func item(_ tab: AppTab, title: String, symbol: String) -> some View {
        let on = selection == tab
        return Button { selection = tab } label: {
            VStack(spacing: 3) {
                Image(systemName: symbol)
                    .font(.system(size: 18, weight: .semibold))
                Text(title)
                    .font(.system(size: 10, weight: .heavy))
            }
            .foregroundStyle(on ? BW.ink : Color(hex: 0x9A968E))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 7)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(title))
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    private var discover: some View {
        let on = selection == .discover
        return Button { selection = .discover } label: {
            VStack(spacing: 3) {
                ZStack {
                    Circle()
                        .fill(Color(hex: 0xEFD35A))
                        .frame(width: 58, height: 58)
                        .shadow(color: Color(hex: 0xEFD35A).opacity(0.55), radius: 10, y: 5)
                    // Same card mark as the attached mock; stroke weight matches the other tab symbols.
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .strokeBorder(Color(hex: 0x1D3A2F), lineWidth: 2.4)
                        .frame(width: 18, height: 23)
                }
                .overlay {
                    Circle().strokeBorder(Color(hex: 0x1D3A2F), lineWidth: on ? 3 : 0)
                }
                .offset(y: -12)
                Text("Discover")
                    .font(.system(size: 10, weight: .heavy))
                    .foregroundStyle(on ? BW.ink : Color(hex: 0x9A968E))
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 4)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("Discover"))
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}

/// Shown on every tab while deals for a new postal code load (first visit of an area: about 1 minute).
struct NewAreaToast: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        if store.checkingNewArea {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                let elapsed = max(0, context.date.timeIntervalSince(store.checkingStartedAt))
                let left = max(5, Int(60 - elapsed))
                HStack(spacing: 12) {
                    ProgressView().tint(BW.ink)
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Loading deals for your area…").font(.bw(.subheadline, weight: .bold)).foregroundStyle(BW.ink)
                        Text(elapsed < 60 ? "About \(left) s left · you can keep using Lemora" : "Almost done…")
                            .font(.bw(.caption, weight: .medium)).foregroundStyle(BW.inkSecondary)
                        ProgressView(value: min(elapsed / 60, 0.95)).tint(BW.amber)
                    }
                }
                .padding(14)
                .background(.regularMaterial, in: .rect(cornerRadius: 18))
                .shadow(color: .black.opacity(0.12), radius: 12, y: 4)
                .padding(.horizontal, 16)
            }
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }
}

extension View {
    /// Shared destination mapping so every tab can open recipes, deals and streaks.
    func bitewiseDestinations() -> some View {
        navigationDestination(for: Route.self) { route in
            switch route {
            case .recipe(let id):
                RecipeDestinationView(recipeId: id)
            case .deal(let id): DealDetailView(dealId: id)
            case .streaks: StreaksView()
            case .worthItAll: WorthItListView()
            case .stealsAll: StealsListView()
            }
        }
    }
}

private struct RecipeDestinationView: View {
    let recipeId: String
    @Environment(AppStore.self) private var store

    var body: some View {
        if let recipe = store.recipes.first(where: { $0.id == recipeId }) {
            RecipeDetailView(recipe: recipe)
        } else {
            ContentUnavailableView("Recipe unavailable", systemImage: "fork.knife")
        }
    }
}
