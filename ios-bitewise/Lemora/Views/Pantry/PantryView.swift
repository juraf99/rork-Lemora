import SwiftUI

// MARK: - PantryView

struct PantryView: View {
    @Environment(AppStore.self) private var store
    @State private var showingAddItem = false
    @State private var search = ""
    @State private var selectedCategory: PantryCategory?

    private var filteredItems: [PantryItem] {
        var items = store.data.pantry
        if let cat = selectedCategory {
            items = items.filter { $0.category == cat }
        }
        if !search.isEmpty {
            items = items.filter { $0.name.localizedCaseInsensitiveContains(search) }
        }
        return items.sorted { $0.category.rawValue < $1.category.rawValue }
    }

    private var groupedItems: [(PantryCategory, [PantryItem])] {
        Dictionary(grouping: filteredItems, by: { $0.category })
            .sorted { $0.key.rawValue < $1.key.rawValue }
            .map { ($0.key, $0.value) }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                categoryFilter
                if groupedItems.isEmpty {
                    emptyState
                } else {
                    ForEach(groupedItems, id: \.0) { category, items in
                        categorySection(category: category, items: items)
                    }
                }
            }
            .padding()
        }
        .searchable(text: $search, prompt: "Search pantry")
        .navigationTitle("My Pantry")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showingAddItem = true } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(BW.leafDeep)
                }
            }
        }
        .sheet(isPresented: $showingAddItem) {
            AddPantryItemSheet()
                .environment(store)
        }
    }

    // MARK: - Category Filter

    private var categoryFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                filterChip(label: "All", icon: "tray.full.fill", selected: selectedCategory == nil) {
                    selectedCategory = nil
                }
                ForEach(PantryCategory.allCases, id: \.self) { cat in
                    filterChip(label: cat.label, icon: cat.icon, selected: selectedCategory == cat) {
                        selectedCategory = cat
                    }
                }
            }
        }
    }

    private func filterChip(label: String, icon: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption2)
                Text(label)
                    .font(.bw(.caption, weight: .bold))
            }
            .foregroundStyle(selected ? .white : BW.ink)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(selected ? BW.leafDeep : BW.card, in: Capsule())
        }
    }

    // MARK: - Category Section

    private func categorySection(category: PantryCategory, items: [PantryItem]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: category.icon)
                    .font(.caption)
                    .foregroundStyle(BW.leafDeep)
                Text(category.label)
                    .font(.bw(.subheadline, weight: .bold))
                    .foregroundStyle(BW.ink)
                Text("\(items.count)")
                    .font(.bw(.caption2, weight: .bold))
                    .foregroundStyle(BW.inkSecondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(BW.inkSecondary.opacity(0.1), in: Capsule())
            }

            ForEach(items) { item in
                pantryItemRow(item)
            }
        }
        .padding(14)
        .background(BW.card, in: .rect(cornerRadius: 14))
    }

    private func pantryItemRow(_ item: PantryItem) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.bw(.body, weight: .medium))
                    .foregroundStyle(BW.ink)
                if let qty = item.quantity, let unit = item.unit {
                    Text("\(String(format: "%.0f", qty)) \(unit.rawValue)")
                        .font(.bw(.caption, weight: .regular))
                        .foregroundStyle(BW.inkSecondary)
                }
            }
            Spacer()
            if let exp = item.expiresAt {
                expiryBadge(exp)
            }
            Button {
                store.removePantryItem(item.id)
            } label: {
                Image(systemName: "trash")
                    .font(.caption)
                    .foregroundStyle(BW.inkSecondary)
            }
        }
        .padding(.vertical, 4)
    }

    private func expiryBadge(_ date: Date) -> some View {
        let days = Calendar.current.dateComponents([.day], from: Date(), to: date).day ?? 0
        let color: Color = days < 0 ? .red : days <= 3 ? .orange : BW.inkSecondary
        let label = days < 0 ? "Expired" : days == 0 ? "Today" : "\(days)d left"

        return Text(label)
            .font(.bw(.caption2, weight: .bold))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.1), in: Capsule())
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "refrigerator")
                .font(.system(size: 48))
                .foregroundStyle(BW.inkSecondary.opacity(0.4))
            Text("Your pantry is empty")
                .font(.bw(.headline, weight: .bold))
                .foregroundStyle(BW.ink)
            Text("Add items you already have at home to get\nbetter recipe suggestions")
                .font(.bw(.subheadline, weight: .regular))
                .foregroundStyle(BW.inkSecondary)
                .multilineTextAlignment(.center)
            Button { showingAddItem = true } label: {
                Label("Add First Item", systemImage: "plus")
                    .font(.bw(.body, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(BW.leafDeep, in: Capsule())
            }
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
}
// MARK: - Add Pantry Item Sheet

struct AddPantryItemSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var quantity = ""
    @State private var selectedUnit: IngredientUnit = .unit
    @State private var selectedCategory: PantryCategory = .other
    @State private var hasExpiry = false
    @State private var expiryDate = Date().addingTimeInterval(7 * 86400)

    var body: some View {
        NavigationStack {
            Form {
                Section("Item Details") {
                    TextField("Item name", text: $name)
                        .font(.bw(.body, weight: .medium))
                    HStack {
                        TextField("Quantity", text: $quantity)
                            .font(.bw(.body, weight: .medium))
                            .keyboardType(.decimalPad)
                            .frame(width: 80)
                        Picker("Unit", selection: $selectedUnit) {
                            ForEach(IngredientUnit.allCases, id: \.self) { unit in
                                Text(unit.rawValue).tag(unit)
                            }
                        }
                    }
                }

                Section("Category") {
                    Picker("Category", selection: $selectedCategory) {
                        ForEach(PantryCategory.allCases, id: \.self) { cat in
                            Label(cat.label, systemImage: cat.icon).tag(cat)
                        }
                    }
                }

                Section("Expiry") {
                    Toggle("Has expiry date", isOn: $hasExpiry)
                    if hasExpiry {
                        DatePicker("Expires", selection: $expiryDate, displayedComponents: .date)
                    }
                }
            }
            .navigationTitle("Add Pantry Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        let item = PantryItem(
                            name: name,
                            quantity: Double(quantity),
                            unit: selectedUnit,
                            category: selectedCategory,
                            expiresAt: hasExpiry ? expiryDate : nil
                        )
                        store.addPantryItem(item)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                    .font(.bw(.body, weight: .bold))
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        PantryView()
            .environment(AppStore())
    }
}
