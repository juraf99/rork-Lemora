import SwiftUI

struct SavedView: View {
    @Environment(AppStore.self) private var store
    @State private var path: NavigationPath = NavigationPath()
    @State private var showGrocery: Bool = false
    @State private var showPaywall: Bool = false
    @State private var cooking: CookingTarget? = nil

    struct CookingTarget: Identifiable {
        let id: UUID
        let recipe: Recipe
    }

    private var groceryCount: Int { store.data.grocery.filter { !$0.isChecked }.count }

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    groceryBanner
                    if !store.has(.permanentSaves) && !store.activeSaved.isEmpty {
                        Button { showPaywall = true } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "clock")
                                Text("Free saves last \(store.config.temporarySaveHours / 24) days. Save forever with Premium.")
                                    .multilineTextAlignment(.leading)
                                Spacer(minLength: 0)
                                Image(systemName: "chevron.right").font(.caption.weight(.bold))
                            }
                            .font(.bw(.footnote, weight: .semibold))
                            .foregroundStyle(BW.ink)
                            .padding(14)
                            .background(BW.lemonSoft, in: .rect(cornerRadius: 16))
                        }
                    }

                    if store.activeSaved.isEmpty {
                        EmptyStateView(mascot: BWImage.mascotPeek, title: String(localized: "No saved meals yet"),
                                       message: String(localized: "Swipe right on meals you love in Discover and they'll land here."))
                    } else {
                        LazyVStack(spacing: 14) {
                            ForEach(store.activeSaved) { entry in
                                if let recipe = RecipeCatalog.byId[entry.recipeId] {
                                    SavedRow(recipe: recipe, entry: entry, timesCooked: store.timesCooked(recipe),
                                             price: store.price(for: recipe),
                                             onOpen: { path.append(Route.recipe(recipe.id)) },
                                             onCook: { cooking = CookingTarget(id: store.cook(recipe).id, recipe: recipe) })
                                    .contextMenu {
                                        Button("Add to grocery list", systemImage: "cart.badge.plus") {
                                            store.addToGrocery(recipe, servings: recipe.servings)
                                        }
                                        Button("Remove", systemImage: "trash", role: .destructive) { store.unsave(recipe) }
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
            .background(BW.canvas)
            .navigationTitle("Saved")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showGrocery = true } label: {
                        Image(systemName: "cart")
                            .overlay(alignment: .topTrailing) {
                                if groceryCount > 0 {
                                    Text("\(groceryCount)").font(.caption2.bold()).foregroundStyle(BW.ink)
                                        .padding(4).background(BW.lemon, in: .circle).offset(x: 10, y: -10)
                                }
                            }
                    }
                    .accessibilityLabel("Grocery list, \(groceryCount) items")
                }
            }
            .bitewiseDestinations()
            .sheet(isPresented: $showGrocery) { GroceryListView() }
            .sheet(isPresented: $showPaywall) { PaywallView(context: .upgrade) { showPaywall = false } }
            .sheet(item: $cooking) { target in CookedView(recipe: target.recipe, logId: target.id) }
        }
    }

    private var groceryBanner: some View {
        Button { showGrocery = true } label: {
            HStack(spacing: 14) {
                Image(systemName: "cart.fill")
                    .font(.title3).foregroundStyle(BW.ink)
                    .frame(width: 48, height: 48).background(BW.lemon, in: .circle)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Grocery list").font(.bw(.headline)).foregroundStyle(BW.ink)
                    Text(groceryCount == 0 ? String(localized: "Add ingredients from any recipe") : String(localized: "\(groceryCount) items to buy"))
                        .font(.bw(.subheadline, weight: .regular)).foregroundStyle(BW.inkSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.subheadline.weight(.bold)).foregroundStyle(BW.outline)
            }
            .padding(14)
            .bwCard()
        }
        .buttonStyle(BWPressableStyle())
    }
}

struct SavedRow: View {
    let recipe: Recipe
    let entry: SavedRecipe
    let timesCooked: Int
    let price: RecipePrice
    let onOpen: () -> Void
    let onCook: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: onOpen) {
                ZStack(alignment: .bottomLeading) {
                    FoodImage(name: recipe.imageName, height: 170, radius: 0)
                    LinearGradient(colors: [.clear, .black.opacity(0.6)], startPoint: .center, endPoint: .bottom)
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            if timesCooked > 0 {
                                Label("Cooked \(timesCooked)×", systemImage: "checkmark.circle.fill")
                                    .font(.bw(.caption, weight: .bold)).foregroundStyle(.white)
                                    .padding(.horizontal, 10).padding(.vertical, 5).background(BW.leaf, in: .capsule)
                            }
                            if price.dealCount > 0 {
                                SoftChip(text: String(localized: "Save \(Money.format(price.savings))"), symbol: "tag.fill", fill: .white.opacity(0.94))
                            }
                        }
                        Text(recipe.title).font(.bw(.title3, weight: .heavy)).foregroundStyle(.white).multilineTextAlignment(.leading)
                    }
                    .padding(14)
                }
            }
            .buttonStyle(.plain)

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(Money.format(price.perServing)) / serving · \(recipe.totalMinutes) min")
                        .font(.bw(.subheadline, weight: .semibold)).monospacedDigit().foregroundStyle(BW.ink)
                    if let expiry = entry.expiresAt {
                        Text("Saved for \(expiry, format: .relative(presentation: .named))")
                            .font(.bw(.caption, weight: .medium)).foregroundStyle(BW.amber)
                    }
                }
                Spacer()
                Button(action: onCook) {
                    Label("I cooked this", systemImage: "frying.pan.fill")
                        .font(.bw(.subheadline, weight: .bold))
                        .foregroundStyle(BW.ink)
                        .padding(.horizontal, 14)
                        .frame(minHeight: 44)
                        .background(BW.lemon, in: .capsule)
                }
                .buttonStyle(BWPressableStyle())
            }
            .padding(14)
        }
        .background(BW.card)
        .clipShape(.rect(cornerRadius: BW.cardRadius))
        .shadow(color: BW.ink.opacity(0.06), radius: 12, y: 5)
    }
}
