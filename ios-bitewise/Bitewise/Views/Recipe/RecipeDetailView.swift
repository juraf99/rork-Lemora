import SwiftUI

struct RecipeDetailView: View {
    let recipe: Recipe
    @Environment(AppStore.self) private var store
    @State private var servings: Int
    @State private var cookedLog: CookLog? = nil
    @State private var addedToList: Int = 0
    @State private var showAddedToast: Bool = false
    @State private var showPaywall: Bool = false

    init(recipe: Recipe) {
        self.recipe = recipe
        _servings = State(initialValue: recipe.servings)
    }

    private var price: RecipePrice { store.price(for: recipe, servings: servings) }
    private var scored: ScoredRecipe { store.scored(recipe) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                hero
                VStack(alignment: .leading, spacing: 20) {
                    titleBlock
                    macros
                    if let exclusion = store.exclusionReason(for: recipe) {
                        warning(exclusion)
                    }
                    if let headline = price.headlineDeal, let deal = headline.deal {
                        MascotTip(text: String(localized: "\(IngredientCatalog.name(headline.ingredientId)) is on sale at \(RetailerCatalog.name(deal.retailerId)). Great time to cook this!"))
                    }
                    servingsStepper
                    ingredients
                    steps
                    compatibility
                    sourceNote
                }
                .padding(.horizontal, 20)
            }
            .padding(.bottom, 120)
        }
        .background(BW.canvas)
        .ignoresSafeArea(edges: .top)
        .toolbar(.hidden, for: .tabBar)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                ShareLink(item: "\(recipe.title) on Lemora") {
                    Image(systemName: "square.and.arrow.up")
                }
            }
        }
        .safeAreaInset(edge: .bottom) { actionBar }
        .sheet(item: $cookedLog) { log in
            CookedView(recipe: recipe, logId: log.id)
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView(context: .upgrade) { showPaywall = false }
        }
        .overlay(alignment: .top) {
            if showAddedToast {
                Label("Added to your grocery list", systemImage: "checkmark.circle.fill")
                    .font(.bw(.subheadline, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18).padding(.vertical, 12)
                    .background(BW.leafDeep, in: .capsule)
                    .padding(.top, 60)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .onAppear { store.track("recipe_opened", ["recipe": recipe.id]) }
    }

    private var hero: some View {
        FoodImage(name: recipe.imageName, height: 340, radius: 0)
            .overlay(alignment: .bottomLeading) {
                HStack(spacing: 8) {
                    MatchBadge(percent: scored.matchPercent, compact: true)
                    ForEach(Array(recipe.tags.sorted { $0.rawValue < $1.rawValue }.prefix(2)), id: \.self) { tag in
                        SoftChip(text: tag.title, fill: .white.opacity(0.94))
                    }
                }
                .padding(16)
            }
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(recipe.title).font(.bw(.title, weight: .heavy)).foregroundStyle(BW.ink)
            Text(recipe.summary).font(.bw(.body, weight: .regular)).foregroundStyle(BW.inkSecondary)
            HStack(spacing: 14) {
                Label("\(recipe.totalMinutes) min", systemImage: "clock")
                Label("Serves \(servings)", systemImage: "person.2")
                Spacer()
                VStack(alignment: .trailing, spacing: 0) {
                    Text("\(Money.format(price.perServing))")
                        .font(.bw(.title2, weight: .heavy)).monospacedDigit().foregroundStyle(BW.ink)
                        .contentTransition(.numericText())
                    Text("per serving").font(.bw(.caption, weight: .medium)).foregroundStyle(BW.inkSecondary)
                }
            }
            .font(.bw(.subheadline, weight: .medium))
            .foregroundStyle(BW.inkSecondary)
            .padding(.top, 4)
        }
    }

    private var macros: some View {
        let n = recipe.nutrition
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                macro("\(n.protein)g", String(localized: "protein"), highlight: true)
                macro("\(n.carbs)g", String(localized: "carbs"))
                macro("\(n.fat)g", String(localized: "fat"))
                macro("\(n.calories)", String(localized: "kcal"))
            }
            if n.status != .verified {
                Text("Nutrition is estimated per serving.").font(.bw(.caption2, weight: .medium)).foregroundStyle(BW.inkSecondary)
            }
        }
    }

    private func macro(_ value: String, _ label: String, highlight: Bool = false) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.bw(.headline, weight: .heavy)).monospacedDigit().foregroundStyle(BW.ink)
            Text(label).font(.bw(.caption, weight: .medium)).foregroundStyle(BW.inkSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(highlight ? BW.lemon.opacity(0.6) : BW.card, in: .rect(cornerRadius: 16))
    }

    private func warning(_ text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(BW.danger)
            Text("Not a match for your profile: \(text)").font(.bw(.subheadline, weight: .semibold)).foregroundStyle(BW.ink)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(BW.danger.opacity(0.1), in: .rect(cornerRadius: 16))
    }

    private var servingsStepper: some View {
        HStack {
            Text("Servings").font(.bw(.headline)).foregroundStyle(BW.ink)
            Spacer()
            Button { if servings > 1 { servings -= 1 } } label: {
                Image(systemName: "minus").frame(width: 44, height: 44).background(BW.card, in: .circle)
            }
            .accessibilityLabel("Fewer servings")
            Text("\(servings)").font(.bw(.title3, weight: .heavy)).monospacedDigit().frame(minWidth: 36)
                .contentTransition(.numericText())
            Button { if servings < 12 { servings += 1 } } label: {
                Image(systemName: "plus").frame(width: 44, height: 44).background(BW.card, in: .circle)
            }
            .accessibilityLabel("More servings")
        }
        .foregroundStyle(BW.ink)
        .animation(.snappy, value: servings)
        .sensoryFeedback(.selection, trigger: servings)
    }

    private var ingredients: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Ingredients").font(.bw(.title3)).foregroundStyle(BW.ink)
                Spacer()
                Text("~\(Money.format(price.total)) total").font(.bw(.subheadline, weight: .semibold)).monospacedDigit().foregroundStyle(BW.inkSecondary)
            }
            VStack(spacing: 0) {
                ForEach(Array(price.lines.enumerated()), id: \.element.id) { idx, line in
                    HStack(spacing: 12) {
                        Text(IngredientCatalog.emoji(line.ingredientId)).font(.title3).frame(width: 32)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(IngredientCatalog.name(line.ingredientId)).font(.bw(.body, weight: .semibold)).foregroundStyle(BW.ink)
                            Text(line.unit.format(line.quantity)).font(.bw(.footnote, weight: .regular)).foregroundStyle(BW.inkSecondary)
                        }
                        Spacer()
                        if let deal = line.deal, line.savings > 0.01 {
                            VStack(alignment: .trailing, spacing: 3) {
                                DealTag(text: String(localized: "On sale at \(RetailerCatalog.name(deal.retailerId))"), symbol: "tag.fill")
                                Text(Money.format(line.cost)).font(.bw(.caption, weight: .bold)).monospacedDigit().foregroundStyle(BW.leafDeep)
                            }
                        } else {
                            Text(Money.format(line.cost)).font(.bw(.subheadline, weight: .medium)).monospacedDigit().foregroundStyle(BW.inkSecondary)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    if idx < price.lines.count - 1 { Divider().overlay(BW.hairline).padding(.leading, 60) }
                }
            }
            .bwCard()
            if price.usesSampleData { SamplePricesNote() }
        }
    }

    private var steps: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Instructions").font(.bw(.title3)).foregroundStyle(BW.ink)
            ForEach(Array(recipe.steps.enumerated()), id: \.offset) { idx, step in
                HStack(alignment: .top, spacing: 14) {
                    Text("\(idx + 1)")
                        .font(.bw(.subheadline, weight: .heavy)).foregroundStyle(BW.ink)
                        .frame(width: 30, height: 30).background(BW.lemon, in: .circle)
                    Text(step).font(.bw(.body, weight: .regular)).foregroundStyle(BW.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var compatibility: some View {
        let allergens = store.allergens(of: recipe)
        return VStack(alignment: .leading, spacing: 10) {
            Text("Diet & allergens").font(.bw(.title3)).foregroundStyle(BW.ink)
            ChipFlow(items: store.compatibility(of: recipe).map(\.0)) { diet in
                let state = store.compatibility(of: recipe).first { $0.0 == diet }?.1 ?? .uncertain
                TriStateBadge(title: diet.title, state: state)
            }
            if !allergens.contains.isEmpty {
                Text("Contains: \(allergens.contains.map(\.title).joined(separator: ", "))")
                    .font(.bw(.subheadline, weight: .semibold)).foregroundStyle(BW.ink)
            }
            if !allergens.mayContain.isEmpty {
                Text("May contain: \(allergens.mayContain.map(\.title).joined(separator: ", ")). Always check product labels.")
                    .font(.bw(.footnote, weight: .medium)).foregroundStyle(BW.amber)
            }
        }
    }

    private var sourceNote: some View {
        Text("Source: \(recipe.source.title)")
            .font(.bw(.caption, weight: .medium)).foregroundStyle(BW.inkSecondary)
    }

    private var actionBar: some View {
        VStack(spacing: 8) {
            if let entry = store.savedEntry(recipe), let expiry = entry.expiresAt {
                Button { showPaywall = true } label: {
                    Text("Saved for \(expiry, format: .relative(presentation: .named)) · Save forever with Premium")
                        .font(.bw(.caption, weight: .semibold)).foregroundStyle(BW.inkSecondary)
                }
            }
            HStack(spacing: 10) {
                Button {
                    if store.isSaved(recipe) { store.unsave(recipe) } else { store.save(recipe) }
                } label: {
                    Image(systemName: store.isSaved(recipe) ? "bookmark.fill" : "bookmark")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(BW.ink)
                        .frame(width: 56, height: 56)
                        .background(BW.card, in: .circle)
                        .overlay(Circle().strokeBorder(BW.hairline))
                }
                .accessibilityLabel(store.isSaved(recipe) ? "Remove from saved" : "Save")
                .sensoryFeedback(.impact(weight: .light), trigger: store.isSaved(recipe))

                Button {
                    cookedLog = store.cook(recipe)
                } label: {
                    Image(systemName: "frying.pan")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(BW.ink)
                        .frame(width: 56, height: 56)
                        .background(BW.card, in: .circle)
                        .overlay(Circle().strokeBorder(BW.hairline))
                }
                .accessibilityLabel("I cooked this")

                Button {
                    store.addToGrocery(recipe, servings: servings)
                    addedToList += 1
                    withAnimation(.spring) { showAddedToast = true }
                    Task {
                        try? await Task.sleep(for: .seconds(1.8))
                        withAnimation { showAddedToast = false }
                    }
                } label: {
                    Label("Add to Grocery List", systemImage: "cart.badge.plus")
                }
                .buttonStyle(BWPrimaryButtonStyle())
                .sensoryFeedback(.success, trigger: addedToList)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background(BW.canvas.opacity(0.97))
    }
}
