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
    }
}

extension View {
    /// Shared destination mapping so every tab can open recipes, deals and streaks.
    func bitewiseDestinations() -> some View {
        navigationDestination(for: Route.self) { route in
            switch route {
            case .recipe(let id):
                if let recipe = RecipeCatalog.byId[id] { RecipeDetailView(recipe: recipe) }
            case .deal(let id): DealDetailView(dealId: id)
            case .streaks: StreaksView()
            case .worthItAll: WorthItListView()
            case .stealsAll: StealsListView()
            }
        }
    }
}
