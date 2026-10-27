import SwiftUI

/// Check what is already at home. Checked items leave the grocery list.
struct PantryView: View {
    @Environment(AppStore.self) private var store
    @State private var draft = ""
    @State private var notFound: String?
    @FocusState private var focused: Bool

    /// Catalogue ingredients matching what is typed. Only these can be added.
    private var suggestions: [String] {
        PantryStock.search(draft)
    }

    private struct Row: Identifiable {
        let id: String
        let ingredientId: String?
        let pantryId: UUID?
        let title: String
        let owned: Bool
    }

    private var rows: [Row] {
        var result: [Row] = []
        var seen = Set<String>()
        for item in store.data.grocery {
            let key = "ing:\(item.ingredientId)"
            guard seen.insert(key).inserted else { continue }
            result.append(Row(
                id: key,
                ingredientId: item.ingredientId,
                pantryId: nil,
                title: PantryStock.displayName(item.ingredientId),
                owned: PantryStock.covers(item.ingredientId, stocks: store.pantryItems)
            ))
        }
        for stock in store.pantryItems {
            if let ingredientId = stock.ingredientId {
                let key = "ing:\(ingredientId)"
                guard seen.insert(key).inserted else { continue }
                result.append(Row(
                    id: key,
                    ingredientId: ingredientId,
                    pantryId: stock.id,
                    title: PantryStock.displayName(ingredientId),
                    owned: true
                ))
            } else {
                result.append(Row(
                    id: stock.id.uuidString,
                    ingredientId: nil,
                    pantryId: stock.id,
                    title: stock.name,
                    owned: true
                ))
            }
        }
        return result
    }

    var body: some View {
        List {
            Section {
                Text("Check what you already have at home. Those items leave the list and won’t be added again.")
                    .font(.bw(.subheadline, weight: .regular))
                    .foregroundStyle(BW.inkSecondary)
                    .listRowBackground(Color.clear)
                HStack(spacing: 8) {
                    TextField("Add an item", text: $draft)
                        .font(.bw(.body, weight: .medium))
                        .focused($focused)
                        .autocorrectionDisabled()
                        .submitLabel(.done)
                        .onSubmit(add)
                        .onChange(of: draft) { _, _ in notFound = nil }
                    Button(action: add) {
                        Text("Add")
                            .font(.bw(.subheadline, weight: .bold))
                            .foregroundStyle(BW.canvas)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(BW.ink, in: .capsule)
                    }
                    .buttonStyle(.plain)
                    .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .listRowBackground(BW.beige.opacity(0.55))

                if let notFound {
                    Text("“\(notFound)” isn’t in our ingredient list. Pick one of the suggestions.")
                        .font(.bw(.footnote, weight: .semibold))
                        .foregroundStyle(.red)
                        .listRowBackground(Color.clear)
                } else if draft.trimmingCharacters(in: .whitespacesAndNewlines).count >= 2 && suggestions.isEmpty {
                    Text("No ingredient found. Try another spelling.")
                        .font(.bw(.footnote, weight: .semibold))
                        .foregroundStyle(BW.inkSecondary)
                        .listRowBackground(Color.clear)
                }

                ForEach(suggestions, id: \.self) { id in
                    Button { pick(id) } label: {
                        HStack(spacing: 12) {
                            IngredientThumb(ingredientId: id, size: 30)
                            Text(verbatim: PantryStock.displayName(id))
                                .font(.bw(.body, weight: .semibold))
                                .foregroundStyle(BW.ink)
                            Spacer()
                            Image(systemName: PantryStock.covers(id, stocks: store.pantryItems) ? "checkmark.circle.fill" : "plus.circle.fill")
                                .font(.title3)
                                .foregroundStyle(BW.leaf)
                        }
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(BW.card)
                }
            }

            Section {
                ForEach(rows) { row in
                    Button { toggle(row) } label: { rowLabel(row) }
                        .buttonStyle(.plain)
                        .sensoryFeedback(.selection, trigger: row.owned)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(BW.canvas)
        .navigationTitle("Pantry")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
    }

    private func rowLabel(_ row: Row) -> some View {
        HStack(spacing: 12) {
            Image(systemName: row.owned ? "checkmark.circle.fill" : "circle")
                .font(.title2)
                .foregroundStyle(row.owned ? BW.leaf : BW.outline)
                .contentTransition(.symbolEffect(.replace))
            if let ingredientId = row.ingredientId {
                IngredientThumb(ingredientId: ingredientId, size: 30)
            } else {
                Image(systemName: "basket")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(BW.leafDeep)
                    .frame(width: 30, height: 30)
                    .background(Color.white, in: .circle)
            }
            Text(verbatim: row.title)
                .font(.bw(.body, weight: .semibold))
                .foregroundStyle(BW.ink)
            Spacer()
        }
        .contentShape(.rect)
    }

    private func toggle(_ row: Row) {
        if row.owned {
            if let ingredientId = row.ingredientId {
                store.removeFromPantry(ingredientId: ingredientId)
            } else if let pantryId = row.pantryId {
                store.removeFromPantry(id: pantryId)
            }
        } else if let ingredientId = row.ingredientId {
            store.addToPantry(ingredientId: ingredientId)
        }
    }

    private func add() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        if store.addToPantry(named: text) {
            draft = ""
            notFound = nil
            focused = false
        } else {
            notFound = text
        }
    }

    private func pick(_ ingredientId: String) {
        store.addToPantry(ingredientId: ingredientId)
        draft = ""
        notFound = nil
        focused = false
    }
}
