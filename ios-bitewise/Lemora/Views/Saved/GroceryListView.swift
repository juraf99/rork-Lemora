import SwiftUI

struct GroceryListView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    private var items: [GroceryItem] { store.data.grocery }

    private var buyItems: [GroceryItem] {
        items.filter { !store.isInPantry(ingredientId: $0.ingredientId) }
    }

    private var weekDates: [Date] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let start = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)) ?? today
        return (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: start) }
    }

    private var weekMeals: [MealPlanEntry] {
        let cal = Calendar.current
        return store.data.mealPlan.filter { entry in
            weekDates.contains { cal.isDate($0, inSameDayAs: entry.date) }
        }
    }

    /// Ingredients already at home, kept off the list.
    private var skipped: [(id: String, name: String, cost: Double)] {
        var seen = Set<String>()
        var out: [(id: String, name: String, cost: Double)] = []
        func add(_ id: String, _ cost: Double) {
            guard store.isInPantry(ingredientId: id), seen.insert(id).inserted else { return }
            out.append((id, IngredientCatalog.name(id), cost))
        }
        for entry in weekMeals {
            guard let recipe = store.recipe(id: entry.recipeId) else { continue }
            for line in store.price(for: recipe, servings: 1).lines {
                add(line.ingredientId, line.cost ?? 0)
            }
        }
        for item in items where store.isInPantry(ingredientId: item.ingredientId) {
            add(item.ingredientId, item.estimatedCost ?? 0)
        }
        return out
    }

    private var estimatedTotal: Double {
        buyItems.filter { !$0.isChecked }.compactMap(\.estimatedCost).reduce(0, +)
    }

    private var pantrySavings: Double { skipped.reduce(0) { $0 + $1.cost } }

    var body: some View {
        NavigationStack {
            Group {
                if buyItems.isEmpty && skipped.isEmpty {
                    EmptyStateView(mascot: BWImage.mascotPeek, title: String(localized: "Your list is empty"),
                                   message: String(localized: "Open a recipe and tap Add to Grocery List. Matching ingredients merge automatically."))
                        .frame(maxHeight: .infinity)
                } else {
                    list
                }
            }
            .background(BW.canvas)
            .navigationTitle("Grocery list")
            .navigationBarTitleDisplayMode(.large)
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
            .safeAreaInset(edge: .bottom) {
                if !buyItems.isEmpty || pantrySavings > 0 {
                    totals
                }
            }
        }
        .presentationDragIndicator(.visible)
    }

    private var list: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Text(String(localized: "From your week plan · \(weekMeals.count) meals"))
                        .font(.bw(.subheadline, weight: .medium))
                        .foregroundStyle(BW.inkSecondary)
                    if !skipped.isEmpty {
                        pantryBanner
                    }
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 8, trailing: 0))
            }

            Section {
                ForEach(buyItems) { item in
                    GroceryRow(item: item, deal: store.dealById(item.dealId), meals: mealNote(item)) { store.toggleGrocery(item.id) }
                        .swipeActions {
                            Button("Delete", systemImage: "trash", role: .destructive) { store.removeGrocery(item.id) }
                        }
                        .listRowBackground(BW.card)
                }
            }

            if !skipped.isEmpty {
                Section {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Already in your pantry · not added")
                            .font(.bw(.caption, weight: .heavy))
                            .foregroundStyle(BW.inkSecondary)
                            .textCase(.uppercase)
                        ChipFlow(items: skipped.map(\.id)) { id in
                            Text(IngredientCatalog.name(id))
                                .font(.bw(.subheadline, weight: .semibold))
                                .foregroundStyle(BW.ink)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(BW.beigeSoft, in: Capsule())
                        }
                    }
                    .listRowBackground(Color.clear)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .listStyle(.plain)
    }

    private var pantryBanner: some View {
        NavigationLink {
            PantryView()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "takeoutbag.and.cup.and.straw.fill")
                    .font(.title3)
                    .foregroundStyle(BW.leafDeep)
                Text(String(localized: "\(skipped.count) items skipped. You already have them at home."))
                    .font(.bw(.subheadline, weight: .semibold))
                    .foregroundStyle(BW.ink)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 8)
                Text("Pantry")
                    .font(.bw(.subheadline, weight: .heavy))
                    .foregroundStyle(BW.leafDeep)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(BW.leafDeep)
            }
            .padding(14)
            .background(BW.leafSoft, in: .rect(cornerRadius: 18))
        }
        .buttonStyle(.plain)
    }

    private func mealNote(_ item: GroceryItem) -> String {
        let titles = item.recipeIds.compactMap { id in store.recipes.first { $0.id == id }?.title }
        if titles.isEmpty { return item.unit.format(item.quantity) }
        let days = titles.prefix(2).joined(separator: ", ")
        return "\(item.unit.format(item.quantity)) · \(days)"
    }

    private var totals: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Estimated total")
                    .font(.bw(.caption, weight: .medium))
                    .foregroundStyle(.white.opacity(0.75))
                Text(Money.format(estimatedTotal))
                    .font(.bw(size: 28, weight: .heavy))
                    .foregroundStyle(.white)
                    .monospacedDigit()
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("Pantry saves you")
                    .font(.bw(.caption, weight: .medium))
                    .foregroundStyle(.white.opacity(0.75))
                Text(Money.format(pantrySavings))
                    .font(.bw(.title2))
                    .foregroundStyle(Color(hex: 0xEFD35A))
                    .monospacedDigit()
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(BW.ink)
    }
}

struct GroceryRow: View {
    let item: GroceryItem
    let deal: Deal?
    var meals: String = ""
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 12) {
                Text(IngredientCatalog.emoji(item.ingredientId))
                    .font(.title2)
                    .frame(width: 36)
                    .opacity(item.isChecked ? 0.4 : 1)
                VStack(alignment: .leading, spacing: 2) {
                    Text(IngredientCatalog.name(item.ingredientId))
                        .font(.bw(.body, weight: .heavy))
                        .foregroundStyle(item.isChecked ? BW.inkSecondary : BW.ink)
                        .strikethrough(item.isChecked)
                    Text(meals.isEmpty ? "~\(item.unit.format(item.quantity))" : meals)
                        .font(.bw(.footnote, weight: .medium))
                        .foregroundStyle(BW.inkSecondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                if let badge {
                    Text(badge)
                        .font(.bw(.caption2, weight: .heavy))
                        .foregroundStyle(badge.hasPrefix("-") ? BW.ink : BW.leafDeep)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(badge.hasPrefix("-") ? BW.beigeSoft : BW.leafSoft, in: Capsule())
                }
                Text(item.estimatedCost.map(Money.format) ?? "—")
                    .font(.bw(.subheadline, weight: .heavy))
                    .monospacedDigit()
                    .foregroundStyle(BW.ink)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: item.isChecked)
        .accessibilityAddTraits(item.isChecked ? .isSelected : [])
    }

    private var badge: String? {
        guard let deal, !item.isChecked else { return nil }
        if let percent = deal.sourceDiscountPercent, percent > 0 { return "-\(percent)%" }
        if let regular = deal.regularPrice, regular > deal.salePrice, regular > 0 {
            return "-\(Int(((regular - deal.salePrice) / regular) * 100))%"
        }
        return String(localized: "Deal")
    }
}
