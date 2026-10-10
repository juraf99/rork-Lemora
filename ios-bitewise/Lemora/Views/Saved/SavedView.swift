import SwiftUI

struct SavedView: View {
    @Environment(AppStore.self) private var store
    @State private var path: NavigationPath = NavigationPath()
    @State private var showGrocery: Bool = false
    @State private var showPaywall: Bool = false
    @State private var cooking: CookingTarget? = nil
    @State private var query: String = ""
    @State private var filter: SavedFilter = .all
    @State private var sort: SavedSort = .recent
    @State private var organizing: OrganizeTarget? = nil
    @State private var showNewCollection: Bool = false
    @State private var editingCollection: RecipeCollection? = nil
    @State private var deletingCollection: RecipeCollection? = nil

    struct CookingTarget: Identifiable {
        let id: UUID
        let recipe: Recipe
    }

    struct OrganizeTarget: Identifiable {
        let id: String
    }

    enum SavedFilter: Hashable {
        case all, onSale, quick
        case collection(UUID)
    }

    enum SavedSort: String, CaseIterable, Identifiable {
        case recent, cheapest, quickest, savings
        var id: String { rawValue }
        var title: String {
            switch self {
            case .recent: String(localized: "Recently saved")
            case .cheapest: String(localized: "Cheapest per serving")
            case .quickest: String(localized: "Quickest")
            case .savings: String(localized: "Biggest savings")
            }
        }
    }

    struct SavedItem: Identifiable {
        var id: String { recipe.id }
        let entry: SavedRecipe
        let recipe: Recipe
        let price: RecipePrice
    }

    private var groceryCount: Int { store.data.grocery.filter { !$0.isChecked }.count }

    private var allItems: [SavedItem] {
        store.activeSaved.compactMap { entry in
            guard let recipe = store.recipes.first(where: { $0.id == entry.recipeId }) else { return nil }
            return SavedItem(entry: entry, recipe: recipe, price: store.price(for: recipe))
        }
    }

    private func matches(_ item: SavedItem, _ f: SavedFilter) -> Bool {
        switch f {
        case .all: return true
        case .onSale: return item.price.dealCount > 0
        case .quick: return item.recipe.totalMinutes <= 30
        case .collection(let id): return store.collection(id)?.recipeIds.contains(item.recipe.id) ?? false
        }
    }

    private var visibleItems: [SavedItem] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let filtered = allItems.filter { item in
            guard matches(item, filter) else { return false }
            guard !q.isEmpty else { return true }
            if item.recipe.title.localizedCaseInsensitiveContains(q) { return true }
            if item.recipe.tags.contains(where: { $0.title.localizedCaseInsensitiveContains(q) }) { return true }
            return store.collections(containing: item.recipe.id).contains { $0.name.localizedCaseInsensitiveContains(q) }
        }
        switch sort {
        case .recent: return filtered
        case .cheapest: return filtered.sorted { ($0.price.perServing ?? .greatestFiniteMagnitude) < ($1.price.perServing ?? .greatestFiniteMagnitude) }
        case .quickest: return filtered.sorted { $0.recipe.totalMinutes < $1.recipe.totalMinutes }
        case .savings: return filtered.sorted { $0.price.savings > $1.price.savings }
        }
    }

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
                        collectionsBar
                        listHeader
                        let items = visibleItems
                        if items.isEmpty {
                            emptyFilter
                        } else {
                            LazyVStack(spacing: 14) {
                                ForEach(items) { item in
                                    row(item)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
            .scrollDismissesKeyboard(.immediately)
            .background(BW.canvas)
            .navigationTitle("Saved")
            .searchable(text: $query, prompt: Text("Search your saved meals"))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showGrocery = true } label: { cartLabel }
                        .accessibilityLabel("Grocery list, \(groceryCount) items")
                }
            }
            .bitewiseDestinations()
            .sheet(isPresented: $showGrocery) { GroceryListView() }
            .sheet(isPresented: $showPaywall) { PaywallView(context: .upgrade) { showPaywall = false } }
            .sheet(item: $cooking) { target in CookedView(recipe: target.recipe, logId: target.id) }
            .sheet(item: $organizing) { target in CollectionPickerSheet(recipeId: target.id) }
            .sheet(isPresented: $showNewCollection) {
                CollectionEditorSheet(existing: nil) { name, emoji in
                    let created = store.createCollection(name: name, emoji: emoji)
                    withAnimation(.snappy) { filter = .collection(created.id) }
                }
            }
            .sheet(item: $editingCollection) { collection in
                CollectionEditorSheet(existing: collection) { name, emoji in
                    store.updateCollection(collection.id, name: name, emoji: emoji)
                }
            }
            .alert(Text("Delete this collection?"),
                   isPresented: Binding(get: { deletingCollection != nil }, set: { if !$0 { deletingCollection = nil } }),
                   presenting: deletingCollection) { collection in
                Button("Delete", role: .destructive) {
                    if filter == .collection(collection.id) { filter = .all }
                    store.deleteCollection(collection.id)
                }
                Button("Cancel", role: .cancel) {}
            } message: { _ in
                Text("Your meals stay saved. Only the collection is removed.")
            }
        }
    }

    // MARK: Cart

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

    // MARK: Collections bar

    private var collectionsBar: some View {
        let items = allItems
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                filterChip(.all, emoji: nil, title: String(localized: "All"), count: items.count)
                let onSale = items.filter { matches($0, .onSale) }.count
                if onSale > 0 {
                    filterChip(.onSale, emoji: nil, title: String(localized: "On sale"), count: onSale)
                }
                let quick = items.filter { matches($0, .quick) }.count
                if quick > 0 {
                    filterChip(.quick, emoji: nil, title: String(localized: "Under 30 min"), count: quick)
                }
                ForEach(store.collections) { collection in
                    filterChip(.collection(collection.id), emoji: collection.emoji, title: collection.name,
                               count: items.filter { collection.recipeIds.contains($0.recipe.id) }.count)
                        .contextMenu {
                            Button("Edit", systemImage: "pencil") { editingCollection = collection }
                            Button("Delete", systemImage: "trash", role: .destructive) { deletingCollection = collection }
                        }
                }
                Button { showNewCollection = true } label: {
                    Label("New collection", systemImage: "plus")
                        .font(.bw(.subheadline, weight: .bold))
                        .foregroundStyle(BW.ink)
                        .padding(.horizontal, 14)
                        .frame(minHeight: 40)
                        .overlay(Capsule().strokeBorder(BW.outline, style: StrokeStyle(lineWidth: 1.5, dash: [5, 4])))
                }
                .buttonStyle(BWPressableStyle())
            }
            .padding(.vertical, 2)
        }
        .scrollClipDisabled()
    }

    private func filterChip(_ f: SavedFilter, emoji: String?, title: String, count: Int) -> some View {
        let selected = filter == f
        return Button {
            withAnimation(.snappy) { filter = f }
        } label: {
            HStack(spacing: 6) {
                if let emoji { Text(emoji) }
                Text(title).lineLimit(1)
                Text("\(count)")
                    .font(.bw(.caption, weight: .heavy)).monospacedDigit()
                    .padding(.horizontal, 7).padding(.vertical, 2)
                    .background(selected ? BW.lemon : BW.beigeSoft, in: .capsule)
                    .foregroundStyle(BW.ink)
            }
            .font(.bw(.subheadline, weight: .bold))
            .foregroundStyle(selected ? Color.white : BW.ink)
            .padding(.leading, 14).padding(.trailing, 8)
            .frame(minHeight: 40)
            .background(selected ? BW.ink : BW.card, in: .capsule)
            .overlay(Capsule().strokeBorder(selected ? Color.clear : BW.hairline))
        }
        .buttonStyle(BWPressableStyle())
        .sensoryFeedback(.selection, trigger: selected)
    }

    private var listHeader: some View {
        HStack {
            Text(visibleItems.count == 1 ? String(localized: "1 meal") : String(localized: "\(visibleItems.count) meals"))
                .font(.bw(.subheadline, weight: .semibold)).foregroundStyle(BW.inkSecondary)
            Spacer()
            Menu {
                Picker("Sort by", selection: $sort) {
                    ForEach(SavedSort.allCases) { Text($0.title).tag($0) }
                }
            } label: {
                Label(sort.title, systemImage: "arrow.up.arrow.down")
                    .font(.bw(.subheadline, weight: .bold))
                    .foregroundStyle(BW.ink)
            }
        }
    }

    @ViewBuilder
    private var emptyFilter: some View {
        VStack(spacing: 10) {
            Image(systemName: query.isEmpty ? "folder" : "magnifyingglass")
                .font(.system(size: 30, weight: .semibold)).foregroundStyle(BW.amber)
            if !query.isEmpty {
                Text("No saved meal matches \"\(query)\"").font(.bw(.headline)).foregroundStyle(BW.ink)
            } else if case .collection = filter {
                Text("No meals in this collection yet").font(.bw(.headline)).foregroundStyle(BW.ink)
                Text("Tap the folder button on any saved meal to add it here.")
                    .font(.bw(.subheadline, weight: .regular)).foregroundStyle(BW.inkSecondary)
            } else {
                Text("Nothing here right now").font(.bw(.headline)).foregroundStyle(BW.ink)
            }
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .padding(24)
        .bwCard()
    }

    private func row(_ item: SavedItem) -> some View {
        let recipe = item.recipe
        return SavedRow(recipe: recipe, entry: item.entry, timesCooked: store.timesCooked(recipe),
                        price: item.price,
                        collections: store.collections(containing: recipe.id),
                        onOpen: { path.append(Route.recipe(recipe.id)) },
                        onCook: { cooking = CookingTarget(id: store.cook(recipe).id, recipe: recipe) },
                        onOrganize: { organizing = OrganizeTarget(id: recipe.id) })
            .contextMenu {
                Button("Add to collection", systemImage: "folder.badge.plus") { organizing = OrganizeTarget(id: recipe.id) }
                Button("Add to grocery list", systemImage: "cart.badge.plus") {
                    store.addToGrocery(recipe, servings: recipe.servings)
                }
                Button("Remove", systemImage: "trash", role: .destructive) { store.unsave(recipe) }
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
    var collections: [RecipeCollection] = []
    let onOpen: () -> Void
    let onCook: () -> Void
    var onOrganize: () -> Void = {}

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

            VStack(alignment: .leading, spacing: 10) {
                if !collections.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(collections) { c in
                                Text("\(c.emoji) \(c.name)")
                                    .font(.bw(.caption, weight: .bold))
                                    .foregroundStyle(BW.ink)
                                    .padding(.horizontal, 10).padding(.vertical, 5)
                                    .background(BW.lemonSoft, in: .capsule)
                            }
                        }
                    }
                }
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(Money.format(price.perServing)) / serving · \(recipe.totalMinutes) min")
                            .font(.bw(.subheadline, weight: .semibold)).monospacedDigit().foregroundStyle(BW.ink)
                            .lineLimit(1).minimumScaleFactor(0.8)
                        if let expiry = entry.expiresAt {
                            Text("Saved for \(expiry, format: .relative(presentation: .named))")
                                .font(.bw(.caption, weight: .medium)).foregroundStyle(BW.amber)
                        }
                    }
                    Spacer(minLength: 4)
                    Button(action: onOrganize) {
                        Image(systemName: collections.isEmpty ? "folder.badge.plus" : "folder.fill")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(BW.ink)
                            .frame(width: 44, height: 44)
                            .background(BW.beigeSoft, in: .circle)
                    }
                    .buttonStyle(BWPressableStyle())
                    .accessibilityLabel("Add to collection")
                    Button(action: onCook) {
                        Label("I cooked this", systemImage: "frying.pan.fill")
                            .font(.bw(.subheadline, weight: .bold))
                            .foregroundStyle(BW.ink)
                            .lineLimit(1)
                            .padding(.horizontal, 14)
                            .frame(minHeight: 44)
                            .background(BW.lemon, in: .capsule)
                    }
                    .buttonStyle(BWPressableStyle())
                }
            }
            .padding(14)
        }
        .background(BW.card)
        .clipShape(.rect(cornerRadius: BW.cardRadius))
        .shadow(color: BW.ink.opacity(0.06), radius: 12, y: 5)
    }
}
