import SwiftUI

struct SavedView: View {
    @Environment(AppStore.self) private var store
    @State private var path: NavigationPath = NavigationPath()
    @State private var showGrocery: Bool = false
    @State private var showPaywall: Bool = false
    @State private var mode: LibraryMode = .saved
    @State private var meal: MealType = .dinner
    @State private var organizing: OrganizeTarget? = nil

    enum LibraryMode: Hashable { case saved, weekPlan }

    struct OrganizeTarget: Identifiable {
        let id: String
    }

    private var groceryCount: Int { store.data.grocery.filter { !$0.isChecked }.count }

    private var likedRecipes: [Recipe] {
        store.likedIds.compactMap { id in store.recipes.first { $0.id == id } }
    }

    private func liked(_ type: MealType) -> [Recipe] {
        likedRecipes.filter { $0.mealType == type }
    }

    private var featured: [Recipe] {
        liked(meal)
            .map { recipe in
                (recipe, store.scored(recipe).matchPercent, store.price(for: recipe).perServing ?? .greatestFiniteMagnitude)
            }
            .sorted {
                if $0.1 != $1.1 { return $0.1 > $1.1 }
                return $0.2 < $1.2
            }
            .prefix(4)
            .map(\.0)
    }

    var body: some View {
        NavigationStack(path: $path) {
            VStack(spacing: 0) {
                libraryToggle
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 12)
                if mode == .weekPlan {
                    MealPlanView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    savedLibrary
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .background(BW.canvas)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showGrocery = true } label: { cartLabel }
                        .accessibilityLabel(Text("Grocery list, \(groceryCount) items"))
                }
            }
            .bitewiseDestinations()
            .sheet(isPresented: $showGrocery) { GroceryListView() }
            .sheet(isPresented: $showPaywall) { PaywallView(context: .upgrade) { showPaywall = false } }
            .sheet(item: $organizing) { target in CollectionPickerSheet(recipeId: target.id) }
        }
    }

    private var libraryToggle: some View {
        HStack(spacing: 8) {
            toggleSide(.saved) {
                HStack(spacing: 6) {
                    Image(systemName: "bookmark.fill")
                        .font(.system(size: 13, weight: .semibold))
                    Text(mode == .saved ? String(localized: "Saved · \(likedRecipes.count)") : String(localized: "Saved"))
                }
            }
            toggleSide(.weekPlan) {
                Text("Week plan")
            }
        }
        .padding(4)
        .background(BW.beigeSoft, in: Capsule())
    }

    private func toggleSide<Label: View>(_ value: LibraryMode, @ViewBuilder label: () -> Label) -> some View {
        let on = mode == value
        return Button {
            withAnimation(.snappy) { mode = value }
        } label: {
            label()
                .font(.bw(.subheadline, weight: .heavy))
                .foregroundStyle(on ? Color.white : BW.ink)
                .frame(maxWidth: .infinity)
                .frame(height: 40)
                .background(on ? BW.ink : Color.clear, in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    private var savedLibrary: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if !store.has(.permanentSaves) && !store.activeSaved.isEmpty {
                    Button { showPaywall = true } label: {
                        Text("Free saves last \(store.config.temporarySaveHours / 24) days. Keep forever with Premium.")
                            .font(.bw(.footnote, weight: .semibold))
                            .foregroundStyle(BW.ink)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(14)
                            .background(BW.lemonSoft, in: .rect(cornerRadius: 16))
                    }
                    .buttonStyle(.plain)
                }

                mealCards

                if likedRecipes.isEmpty {
                    EmptyStateView(mascot: BWImage.mascotPeek, title: String(localized: "Nothing saved yet"),
                                   message: String(localized: "Swipe right to like meals. Then save the ones you want to cook this week."))
                } else if liked(meal).isEmpty {
                    Text("Nothing here right now")
                        .font(.bw(.headline))
                        .foregroundStyle(BW.inkSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                } else {
                    topFour
                    photoGrid
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 28)
        }
    }

    private var mealCards: some View {
        HStack(spacing: 10) {
            ForEach([MealType.breakfast, .lunch, .dinner]) { type in
                let on = meal == type
                Button {
                    withAnimation(.snappy) { meal = type }
                } label: {
                    VStack(spacing: 4) {
                        Text(type.emoji).font(.system(size: 22))
                        Text(type.title)
                            .font(.bw(.subheadline, weight: .heavy))
                            .foregroundStyle(BW.ink)
                        Text(String(localized: "\(liked(type).count) saved"))
                            .font(.bw(.caption, weight: .medium))
                            .foregroundStyle(BW.inkSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(on ? Color(hex: 0xEFD35A) : BW.card, in: .rect(cornerRadius: 18))
                    .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(on ? Color.clear : BW.hairline))
                }
                .buttonStyle(BWPressableStyle())
            }
        }
    }

    private var topFour: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("Top 4 for this week")
                    .font(.bw(.title3))
                    .foregroundStyle(BW.ink)
                Spacer()
                Text("best match + best price")
                    .font(.bw(.caption, weight: .medium))
                    .foregroundStyle(BW.inkSecondary)
            }
            let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(featured) { recipe in
                    featuredCard(recipe)
                }
            }
        }
    }

    private func featuredCard(_ recipe: Recipe) -> some View {
        let price = store.price(for: recipe).perServing
        let planned = isPlanned(recipe)
        return VStack(alignment: .leading, spacing: 8) {
            Button { path.append(Route.recipe(recipe.id)) } label: {
                FoodImage(name: recipe.imageName, height: 112, radius: 14)
            }
            .buttonStyle(.plain)
            Text(recipe.title)
                .font(.bw(.subheadline, weight: .heavy))
                .foregroundStyle(BW.ink)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
            HStack {
                Text(Money.format(price))
                    .font(.bw(.subheadline, weight: .heavy))
                    .foregroundStyle(BW.leafDeep)
                    .monospacedDigit()
                Spacer(minLength: 4)
                if planned {
                    Label("Planned", systemImage: "checkmark")
                        .font(.bw(.caption, weight: .heavy))
                        .foregroundStyle(BW.leafDeep)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(BW.leafSoft, in: Capsule())
                } else {
                    Button { plan(recipe) } label: {
                        Text("Plan")
                            .font(.bw(.caption, weight: .heavy))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(BW.ink, in: Capsule())
                    }
                    .buttonStyle(BWPressableStyle())
                }
            }
        }
        .padding(8)
        .background(BW.card, in: .rect(cornerRadius: 18))
        .contextMenu {
            Button("Add to collection", systemImage: "folder.badge.plus") { organizing = OrganizeTarget(id: recipe.id) }
            Button("Add to grocery list", systemImage: "cart.badge.plus") {
                store.addToGrocery(recipe, servings: recipe.servings, includingPantry: false)
            }
        }
    }

    private var allLikedTitle: String {
        switch meal {
        case .breakfast: String(localized: "All breakfast you saved")
        case .lunch: String(localized: "All lunch you saved")
        case .dinner: String(localized: "All dinner you saved")
        default: String(localized: "All meals you saved")
        }
    }

    private var photoGrid: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(allLikedTitle)
                .font(.bw(.title3))
                .foregroundStyle(BW.ink)
            let columns = [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)]
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(liked(meal)) { recipe in
                    Button { path.append(Route.recipe(recipe.id)) } label: {
                        FoodImage(name: recipe.imageName, height: 104, radius: 14)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var weekDates: [Date] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let start = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)) ?? today
        return (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: start) }
    }

    private func isPlanned(_ recipe: Recipe) -> Bool {
        let cal = Calendar.current
        return store.data.mealPlan.contains { entry in
            entry.recipeId == recipe.id && weekDates.contains { cal.isDate($0, inSameDayAs: entry.date) }
        }
    }

    private func plan(_ recipe: Recipe) {
        let cal = Calendar.current
        let slot = MealSlot(rawValue: recipe.mealType.rawValue) ?? .dinner
        let today = cal.startOfDay(for: .now)
        let open = weekDates.filter { $0 >= today }
        let target = open.first { day in
            !store.data.mealPlan.contains { cal.isDate($0.date, inSameDayAs: day) && $0.mealType == slot }
        } ?? open.first ?? today
        store.addToMealPlan(recipeId: recipe.id, date: target, slot: slot)
    }

    private var cartLabel: some View {
        HStack(spacing: 6) {
            Image(systemName: "cart.fill")
                .font(.system(size: 16, weight: .semibold))
            if groceryCount > 0 {
                Text("\(groceryCount)")
                    .font(.bw(size: 14, weight: .heavy))
                    .monospacedDigit()
                    .foregroundStyle(BW.ink)
                    .padding(.horizontal, 7)
                    .frame(minWidth: 24, minHeight: 24)
                    .background(BW.lemon, in: .capsule)
                    .contentTransition(.numericText())
            }
        }
        .foregroundStyle(BW.ink)
        .fixedSize()
        .animation(.snappy, value: groceryCount)
    }
}
