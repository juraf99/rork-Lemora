import SwiftUI

enum AppTab: Hashable {
    case discover, deals, saved, ask, profile
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
            Tab("Discover", systemImage: "magnifyingglass", value: .discover) { DiscoverView() }
            Tab("Deals", systemImage: "tag", value: .deals) { DealsView() }
            Tab("Saved", systemImage: "bookmark", value: .saved) { SavedView() }
            Tab("Ask", systemImage: "bubble.left.and.text.bubble.right", value: .ask) { AskView() }
            Tab("Profile", systemImage: "person", value: .profile) { ProfileView() }
        }
        .tint(BW.amber)
        .sensoryFeedback(.impact(weight: .medium), trigger: tab)
        .overlay(alignment: .bottom) {
            // The Deals tab has its own banner.
            if tab != .deals { NewAreaToast().padding(.bottom, 62) }
        }
        .animation(.snappy, value: store.checkingNewArea)
        .sensoryFeedback(.success, trigger: store.checkingNewArea) { old, new in old && !new }
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
