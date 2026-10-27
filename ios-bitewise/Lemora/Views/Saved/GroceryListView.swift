import SwiftUI

struct GroceryListView: View {
    enum Grouping: String, CaseIterable, Identifiable {
        case store, category, recipe
        var id: String { rawValue }
        var title: String {
            switch self {
            case .store: String(localized: "Store")
            case .category: String(localized: "Category")
            case .recipe: String(localized: "Recipe")
            }
        }
    }

    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var grouping: Grouping = .store
    @State private var showPantry = false

    private var items: [GroceryItem] { store.groceryToBuy }
    private var keptAtHome: Int { store.data.grocery.count - items.count }

    private var sections: [(title: String, items: [GroceryItem])] {
        let grouped: [String: [GroceryItem]]
        switch grouping {
        case .store:
            grouped = Dictionary(grouping: items) { RetailerCatalog.name($0.retailerId) }
        case .category:
            grouped = Dictionary(grouping: items) { (IngredientCatalog.ingredient($0.ingredientId)?.category ?? CatalogIngredientInfo.info[$0.ingredientId]?.category)?.title ?? String(localized: "Other") }
        case .recipe:
            grouped = Dictionary(grouping: items) { item in
                item.recipeIds.first.flatMap { id in store.recipes.first { $0.id == id }?.title } ?? String(localized: "Deals")
            }
        }
        return grouped.map { ($0.key, $0.value.sorted { !$0.isChecked && $1.isChecked }) }
            .sorted { lhs, rhs in
                let anyStore = RetailerCatalog.name(nil)
                if lhs.title == anyStore { return false }
                if rhs.title == anyStore { return true }
                return lhs.title < rhs.title
            }
    }

    private var dealsInList: Int { items.filter { $0.dealId != nil && !$0.isChecked }.count }
    private var estimatedTotal: Double? {
        let active = items.filter { !$0.isChecked }
        guard active.allSatisfy({ $0.estimatedCost != nil }) else { return nil }
        return active.compactMap(\.estimatedCost).reduce(0, +)
    }

    var body: some View {
        NavigationStack {
            Group {
                if items.isEmpty && keptAtHome == 0 {
                    VStack(spacing: 0) {
                        pantryButton
                            .frame(maxWidth: .infinity, alignment: .trailing)
                            .padding(.horizontal, 20)
                            .padding(.top, 8)
                        EmptyStateView(mascot: BWImage.mascotPeek, title: String(localized: "Your list is empty"),
                                       message: String(localized: "Open a recipe and tap Add to Grocery List. Matching ingredients merge automatically."))
                            .frame(maxHeight: .infinity)
                    }
                } else {
                    List {
                        Section {
                            if !items.isEmpty {
                                Picker("Group by", selection: $grouping) {
                                    ForEach(Grouping.allCases) { Text($0.title).tag($0) }
                                }
                                .pickerStyle(.segmented)
                                .listRowBackground(Color.clear)
                                .listRowInsets(EdgeInsets())
                            }
                            pantryButton
                                .frame(maxWidth: .infinity, alignment: .trailing)
                                .listRowBackground(Color.clear)
                                .listRowInsets(EdgeInsets(top: 8, leading: 4, bottom: 0, trailing: 4))
                            if keptAtHome > 0 {
                                Text(String(localized: "\(keptAtHome) items skipped. You already have them at home."))
                                    .font(.bw(.footnote, weight: .semibold))
                                    .foregroundStyle(BW.leafDeep)
                                    .listRowBackground(Color.clear)
                            }
                        }

                        ForEach(sections, id: \.title) { section in
                            Section {
                                ForEach(section.items) { item in
                                    GroceryRow(item: item, deal: store.dealById(item.dealId)) { store.toggleGrocery(item.id) }
                                        .swipeActions {
                                            Button("Delete", systemImage: "trash", role: .destructive) { store.removeGrocery(item.id) }
                                        }
                                }
                            } header: {
                                Text(section.title).font(.bw(.headline)).foregroundStyle(BW.ink).textCase(nil)
                            }
                        }

                        if !items.isEmpty {
                        Section {
                            HStack(spacing: 12) {
                                MascotView(name: BWImage.mascotCheer, size: 60, bob: true)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(dealsInList > 0 ? String(localized: "Nice picks! You're saving with \(dealsInList) deals.") : String(localized: "Happy shopping!"))
                                        .font(.bw(.subheadline, weight: .bold)).foregroundStyle(BW.ink)
                                    Text(estimatedTotal.map { "Estimated total ~\(Money.format($0))" } ?? String(localized: "Estimated total unavailable"))
                                        .font(.bw(.footnote, weight: .medium)).monospacedDigit().foregroundStyle(BW.inkSecondary)
                                }
                            }
                            .listRowBackground(BW.lemonSoft)
                        }
                        }
                    }
                    .scrollContentBackground(.hidden)
                }
            }
            .background(BW.canvas)
            .navigationTitle("Grocery List")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if items.contains(where: \.isChecked) {
                        Button("Clear checked") { withAnimation { store.clearCheckedGrocery() } }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }.fontWeight(.bold)
                }
            }
            .navigationDestination(isPresented: $showPantry) { PantryView() }
        }
        .presentationDragIndicator(.visible)
    }

    private var pantryButton: some View {
        Button { showPantry = true } label: {
            Label("Pantry", systemImage: "cabinet")
                .font(.bw(.subheadline, weight: .semibold))
                .foregroundStyle(BW.inkSecondary)
        }
        .buttonStyle(.plain)
    }
}

struct GroceryRow: View {
    let item: GroceryItem
    let deal: Deal?
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 12) {
                Image(systemName: item.isChecked ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(item.isChecked ? BW.leaf : BW.outline)
                    .contentTransition(.symbolEffect(.replace))
                IngredientThumb(ingredientId: item.ingredientId, size: 30)
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: PantryStock.displayName(item.ingredientId))
                        .font(.bw(.body, weight: .semibold))
                        .foregroundStyle(item.isChecked ? BW.inkSecondary : BW.ink)
                        .strikethrough(item.isChecked)
                    Text("~\(item.unit.format(item.quantity))")
                        .font(.bw(.footnote, weight: .regular)).foregroundStyle(BW.inkSecondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 3) {
                    if deal != nil {
                        Text("On sale").font(.bw(.caption2, weight: .bold)).foregroundStyle(.white)
                            .padding(.horizontal, 8).padding(.vertical, 3).background(BW.leaf, in: .capsule)
                    }
                    Text(item.estimatedCost.map(Money.format) ?? "—").font(.bw(.footnote, weight: .semibold)).monospacedDigit().foregroundStyle(BW.inkSecondary)
                }
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: item.isChecked)
        .accessibilityAddTraits(item.isChecked ? .isSelected : [])
    }
}
