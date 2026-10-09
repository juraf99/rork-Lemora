import SwiftUI

/// A user-made folder of saved meals ("Weeknight dinners", "Meal prep"…).
nonisolated struct RecipeCollection: Codable, Identifiable, Hashable, Sendable {
    var id: UUID = UUID()
    var name: String
    var emoji: String
    var recipeIds: [String] = []
    var createdAt: Date = .now
}

enum CollectionSuggestions {
    static let all: [(emoji: String, name: String)] = [
        ("🌙", String(localized: "Weeknight dinners")),
        ("🥗", String(localized: "Healthy")),
        ("🍱", String(localized: "Meal prep")),
        ("💪", String(localized: "High protein")),
        ("🎉", String(localized: "Weekend")),
        ("👨‍👩‍👧", String(localized: "Family")),
    ]
    static let emojis = ["🍝", "🌙", "🥗", "🍱", "💪", "🎉", "👨‍👩‍👧", "🍲", "🌮", "🍣", "🥞", "🍰", "🔥", "❤️", "⭐️", "📁"]
}

extension AppStore {
    var collections: [RecipeCollection] { data.collections ?? [] }

    func collection(_ id: UUID) -> RecipeCollection? {
        collections.first { $0.id == id }
    }

    func collections(containing recipeId: String) -> [RecipeCollection] {
        collections.filter { $0.recipeIds.contains(recipeId) }
    }

    @discardableResult
    func createCollection(name: String, emoji: String) -> RecipeCollection {
        let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let collection = RecipeCollection(name: clean.isEmpty ? String(localized: "My meals") : clean, emoji: emoji)
        mutate { d in
            var list = d.collections ?? []
            list.append(collection)
            d.collections = list
        }
        track("collection_created")
        return collection
    }

    func updateCollection(_ id: UUID, name: String, emoji: String) {
        let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
        mutate { d in
            guard var list = d.collections, let i = list.firstIndex(where: { $0.id == id }) else { return }
            if !clean.isEmpty { list[i].name = clean }
            list[i].emoji = emoji
            d.collections = list
        }
    }

    func deleteCollection(_ id: UUID) {
        mutate { d in d.collections?.removeAll { $0.id == id } }
    }

    func toggleRecipe(_ recipeId: String, in id: UUID) {
        mutate { d in
            guard var list = d.collections, let i = list.firstIndex(where: { $0.id == id }) else { return }
            if let j = list[i].recipeIds.firstIndex(of: recipeId) {
                list[i].recipeIds.remove(at: j)
            } else {
                list[i].recipeIds.insert(recipeId, at: 0)
            }
            d.collections = list
        }
    }
}

/// Sheet: tick the collections a saved meal belongs to.
struct CollectionPickerSheet: View {
    let recipeId: String
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var showNew: Bool = false
    @State private var tapped: Int = 0

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    if let recipe = store.recipes.first(where: { $0.id == recipeId }) {
                        Text(recipe.title)
                            .font(.bw(.subheadline, weight: .semibold))
                            .foregroundStyle(BW.inkSecondary)
                            .padding(.bottom, 4)
                    }

                    if store.collections.isEmpty {
                        Text("Start with one of these")
                            .font(.bw(.headline)).foregroundStyle(BW.ink)
                        ChipFlow(items: CollectionSuggestions.all.map(\.name)) { name in
                            let emoji = CollectionSuggestions.all.first { $0.name == name }?.emoji ?? "📁"
                            Button {
                                let c = store.createCollection(name: name, emoji: emoji)
                                store.toggleRecipe(recipeId, in: c.id)
                                tapped += 1
                            } label: {
                                Text("\(emoji) \(name)")
                                    .font(.bw(.subheadline, weight: .bold))
                                    .foregroundStyle(BW.ink)
                                    .padding(.horizontal, 14).padding(.vertical, 10)
                                    .background(BW.lemonSoft, in: .capsule)
                            }
                            .buttonStyle(BWPressableStyle())
                        }
                    }

                    ForEach(store.collections) { c in
                        let isIn = c.recipeIds.contains(recipeId)
                        Button {
                            store.toggleRecipe(recipeId, in: c.id)
                            tapped += 1
                        } label: {
                            HStack(spacing: 12) {
                                Text(c.emoji).font(.title2)
                                    .frame(width: 46, height: 46)
                                    .background(BW.lemonSoft, in: .circle)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(c.name).font(.bw(.headline)).foregroundStyle(BW.ink)
                                    Text(c.recipeIds.count == 1 ? String(localized: "1 meal") : String(localized: "\(c.recipeIds.count) meals"))
                                        .font(.bw(.caption, weight: .medium)).foregroundStyle(BW.inkSecondary)
                                }
                                Spacer()
                                Image(systemName: isIn ? "checkmark.circle.fill" : "circle")
                                    .font(.title2)
                                    .foregroundStyle(isIn ? BW.leafDeep : BW.outline)
                            }
                            .padding(14)
                            .background(isIn ? BW.leafSoft : BW.card, in: .rect(cornerRadius: 18))
                            .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(isIn ? BW.leafDeep.opacity(0.3) : BW.hairline))
                        }
                        .buttonStyle(BWPressableStyle())
                    }

                    Button { showNew = true } label: {
                        Label("New collection", systemImage: "plus")
                    }
                    .buttonStyle(BWSecondaryButtonStyle())
                    .padding(.top, 6)
                }
                .padding(20)
            }
            .background(BW.canvas)
            .navigationTitle("Add to collection")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }.fontWeight(.bold)
                }
            }
            .sensoryFeedback(.selection, trigger: tapped)
            .sheet(isPresented: $showNew) {
                CollectionEditorSheet(existing: nil) { name, emoji in
                    let c = store.createCollection(name: name, emoji: emoji)
                    store.toggleRecipe(recipeId, in: c.id)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

/// Sheet: create or rename a collection.
struct CollectionEditorSheet: View {
    let existing: RecipeCollection?
    let onSave: (String, String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var emoji: String
    @FocusState private var focused: Bool

    init(existing: RecipeCollection?, onSave: @escaping (String, String) -> Void) {
        self.existing = existing
        self.onSave = onSave
        _name = State(initialValue: existing?.name ?? "")
        _emoji = State(initialValue: existing?.emoji ?? "🍝")
    }

    private var canSave: Bool { !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(spacing: 12) {
                        Text(emoji).font(.system(size: 30))
                            .frame(width: 56, height: 56)
                            .background(BW.lemon, in: .circle)
                        TextField("Collection name", text: $name)
                            .font(.bw(.title3, weight: .bold))
                            .foregroundStyle(BW.ink)
                            .focused($focused)
                            .submitLabel(.done)
                            .onSubmit { save() }
                            .padding(.horizontal, 16)
                            .frame(minHeight: 56)
                            .background(BW.card, in: .rect(cornerRadius: 16))
                            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(BW.hairline))
                    }

                    Text("Icon").font(.bw(.headline)).foregroundStyle(BW.ink)
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 8), spacing: 8) {
                        ForEach(CollectionSuggestions.emojis, id: \.self) { e in
                            Button { emoji = e } label: {
                                Text(e).font(.title3)
                                    .frame(width: 38, height: 38)
                                    .background(emoji == e ? BW.lemon : BW.card, in: .circle)
                                    .overlay(Circle().strokeBorder(emoji == e ? BW.amber : BW.hairline, lineWidth: emoji == e ? 2 : 1))
                            }
                            .buttonStyle(BWPressableStyle())
                        }
                    }

                    if existing == nil {
                        Text("Ideas").font(.bw(.headline)).foregroundStyle(BW.ink)
                        ChipFlow(items: CollectionSuggestions.all.map(\.name)) { idea in
                            let e = CollectionSuggestions.all.first { $0.name == idea }?.emoji ?? "📁"
                            Button {
                                name = idea
                                emoji = e
                            } label: {
                                Text("\(e) \(idea)")
                                    .font(.bw(.subheadline, weight: .semibold))
                                    .foregroundStyle(BW.ink)
                                    .padding(.horizontal, 12).padding(.vertical, 8)
                                    .background(BW.lemonSoft, in: .capsule)
                            }
                            .buttonStyle(BWPressableStyle())
                        }
                    }

                    Button(existing == nil ? String(localized: "Create collection") : String(localized: "Save changes")) { save() }
                        .buttonStyle(BWPrimaryButtonStyle())
                        .disabled(!canSave)
                        .opacity(canSave ? 1 : 0.5)
                        .padding(.top, 4)
                }
                .padding(20)
            }
            .background(BW.canvas)
            .navigationTitle(existing == nil ? String(localized: "New collection") : String(localized: "Edit collection"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear { if existing == nil { focused = true } }
        }
        .presentationDetents([.large])
    }

    private func save() {
        guard canSave else { return }
        onSave(name, emoji)
        dismiss()
    }
}
