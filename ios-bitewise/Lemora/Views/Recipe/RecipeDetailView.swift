import SwiftUI

struct RecipeDetailView: View {
    let recipe: Recipe
    @Environment(AppStore.self) private var store
    @State private var servings: Int
    @State private var cookedLog: CookLog? = nil
    @State private var addedToList: Int = 0
    @State private var showAddedToast: Bool = false
    @State private var toastText: String = ""
    @State private var showPaywall: Bool = false
    @State private var showGrocery: Bool = false
    @State private var tonightSet: Bool = false
    @State private var trackedRecipeId: String?
    @State private var trackedSwapRecipeId: String?

    init(recipe: Recipe) {
        self.recipe = recipe
        _servings = State(initialValue: recipe.servings)
    }

    private var price: RecipePrice { store.price(for: recipe, servings: servings) }
    private var scored: ScoredRecipe { store.scored(recipe) }
    private var hasSavings: Bool { price.savings > 0.01 && !price.dealLines.isEmpty }
    private var dealEnd: Date? { price.dealLines.compactMap { $0.deal?.validUntil }.min() }
    private var regularPerServing: Double? { price.regularTotal.map { $0 / Double(max(price.servings, 1)) } }

    /// Unique stores that have a deal in this recipe, in order of appearance.
    private var dealStores: [(id: String, name: String)] {
        var seen = Set<String>()
        var out: [(id: String, name: String)] = []
        for line in price.dealLines {
            if let deal = line.deal, !seen.contains(deal.retailerId) {
                seen.insert(deal.retailerId)
                out.append((id: deal.retailerId, name: deal.retailerDisplayName))
            }
        }
        return out
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                hero
                VStack(alignment: .leading, spacing: 20) {
                    titleBlock
                    statTiles
                    if hasSavings { savingsCard }
                    if !smartSwaps.isEmpty { zestySwapCard }
                    if !recipe.storePricesPerServing.isEmpty { StorePricesCard(prices: recipe.storePricesPerServing, recipe: recipe) }
                    if let exclusion = store.exclusionReason(for: recipe) {
                        warning(exclusion)
                    }
                    servingsStepper
                    ingredients
                    macros
                    steps
                    compatibility
                    sourceNote
                }
                .padding(.horizontal, 20)
            }
            .padding(.bottom, 160)
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
        .sheet(isPresented: $showGrocery) { GroceryListView() }
        .overlay(alignment: .top) {
            if showAddedToast {
                Label(toastText, systemImage: "checkmark.circle.fill")
                    .font(.bw(.subheadline, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18).padding(.vertical, 12)
                    .background(BW.leafDeep, in: .capsule)
                    .padding(.top, 60)
                    .padding(.horizontal, 20)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .analyticsScreen("Recipe")
        .onAppear {
            guard trackedRecipeId != recipe.id else { return }
            trackedRecipeId = recipe.id
            Analytics.track(.recipeViewed(recipeId: recipe.id))
        }
    }

    // MARK: Hero

    private var hero: some View {
        FoodImage(name: recipe.imageName, height: 340, radius: 0)
            .overlay(alignment: .bottomLeading) {
                VStack(alignment: .leading, spacing: 8) {
                    if tonightSet {
                        Label("Tonight's dinner is set", systemImage: "checkmark.circle.fill")
                            .font(.bw(.subheadline, weight: .heavy))
                            .foregroundStyle(BW.ink)
                            .padding(.horizontal, 12).padding(.vertical, 7)
                            .background(BW.lemon, in: .capsule)
                            .transition(.scale.combined(with: .opacity))
                    }
                    HStack(spacing: 8) {
                        MatchBadge(percent: scored.matchPercent, compact: true)
                        ForEach(Array(recipe.tags.sorted { $0.rawValue < $1.rawValue }.prefix(2)), id: \.self) { tag in
                            SoftChip(text: tag.title, fill: .white.opacity(0.94))
                        }
                    }
                }
                .padding(16)
            }
            .overlay(alignment: .bottomTrailing) {
                Button {
                    if store.isSaved(recipe) { store.unsave(recipe) } else { store.save(recipe) }
                } label: {
                    Image(systemName: store.isSaved(recipe) ? "heart.fill" : "heart")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(store.isSaved(recipe) ? BW.danger : BW.ink)
                        .frame(width: 48, height: 48)
                        .background(.white, in: .circle)
                        .shadow(color: .black.opacity(0.12), radius: 8, y: 3)
                }
                .buttonStyle(BWPressableStyle())
                .accessibilityLabel(store.isSaved(recipe) ? "Remove from saved" : "Save")
                .sensoryFeedback(.impact(weight: .light), trigger: store.isSaved(recipe))
                .padding(16)
            }
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(recipe.title).font(.bw(.title, weight: .heavy)).foregroundStyle(BW.ink)
            Text(recipe.summary).font(.bw(.body, weight: .regular)).foregroundStyle(BW.inkSecondary)
        }
    }

    // MARK: Stat tiles (protein · per serving · minutes)

    private var statTiles: some View {
        HStack(spacing: 10) {
            statTile(value: recipe.nutrition.protein.map { "\($0)g" } ?? "—", label: String(localized: "protein"),
                     fill: BW.card, valueColor: BW.ink)
            VStack(spacing: 2) {
                Text(Money.format(price.perServing))
                    .font(.bw(size: 26, weight: .heavy)).monospacedDigit()
                    .foregroundStyle(BW.leafDeep)
                    .contentTransition(.numericText())
                    .minimumScaleFactor(0.7).lineLimit(1)
                if hasSavings {
                    Text(Money.format(regularPerServing))
                        .font(.bw(.caption, weight: .semibold)).monospacedDigit()
                        .strikethrough().foregroundStyle(BW.inkSecondary)
                }
                Text("per serving").font(.bw(.caption, weight: .semibold)).foregroundStyle(BW.leafDeep)
            }
            .frame(maxWidth: .infinity, minHeight: 92)
            .background(BW.leafSoft, in: .rect(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(BW.leafDeep.opacity(0.25), lineWidth: 1.5))
            statTile(value: "\(recipe.totalMinutes)", label: String(localized: "minutes"),
                     fill: BW.card, valueColor: BW.ink)
        }
        .animation(.snappy, value: servings)
    }

    private func statTile(value: String, label: String, fill: Color, valueColor: Color) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.bw(size: 26, weight: .heavy)).monospacedDigit().foregroundStyle(valueColor)
                .minimumScaleFactor(0.7).lineLimit(1)
            Text(label).font(.bw(.caption, weight: .semibold)).foregroundStyle(BW.inkSecondary)
        }
        .frame(maxWidth: .infinity, minHeight: 92)
        .background(fill, in: .rect(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(BW.hairline))
    }

    // MARK: Savings card

    private var savingsCard: some View {
        let count = price.dealLines.count
        let storeNames = dealStores.map(\.name).joined(separator: ", ")
        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 0) {
                    Text("You save").font(.bw(.subheadline, weight: .semibold)).foregroundStyle(.white.opacity(0.7))
                    Text(Money.format(price.savings))
                        .font(.bw(size: 46, weight: .heavy)).monospacedDigit()
                        .foregroundStyle(.white)
                        .contentTransition(.numericText())
                }
                Spacer(minLength: 8)
                if let end = dealEnd {
                    Label(DealTiming.endText(end), systemImage: "timer")
                        .font(.bw(.caption, weight: .heavy))
                        .foregroundStyle(BW.lemon)
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(.white.opacity(0.1), in: .capsule)
                }
            }

            Text(count == 1
                 ? String(localized: "1 ingredient in this meal is on sale at \(storeNames)")
                 : String(localized: "\(count) ingredients in this meal are on sale at \(storeNames)"))
                .font(.bw(.subheadline, weight: .semibold))
                .foregroundStyle(.white.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 8) {
                ForEach(price.dealLines) { line in
                    if let deal = line.deal {
                        HStack(spacing: 10) {
                            StoreChip(retailerId: deal.retailerId, name: deal.retailerDisplayName)
                            Text(deal.productName)
                                .font(.bw(.subheadline, weight: .semibold))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                            Spacer(minLength: 6)
                            Text(Money.format(line.regularCost))
                                .font(.bw(.footnote, weight: .medium)).monospacedDigit()
                                .strikethrough().foregroundStyle(.white.opacity(0.5))
                            Text(Money.format(line.cost))
                                .font(.bw(.title3, weight: .heavy)).monospacedDigit()
                                .foregroundStyle(BW.lemon)
                        }
                        .padding(.horizontal, 12).padding(.vertical, 10)
                        .background(.white.opacity(0.08), in: .rect(cornerRadius: 14))
                    }
                }
            }

            HStack(spacing: 6) {
                Image(systemName: "fork.knife")
                Text("\(Money.format(price.perServing)) per serving instead of \(Money.format(regularPerServing))")
                    .monospacedDigit()
            }
            .font(.bw(.caption, weight: .semibold))
            .foregroundStyle(.white.opacity(0.7))
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(BW.ink, in: .rect(cornerRadius: BW.cardRadius))
        .animation(.snappy, value: servings)
    }

    private var macros: some View {
        let n = recipe.nutrition
        return VStack(alignment: .leading, spacing: 8) {
            Text("Nutrition").font(.bw(.title3)).foregroundStyle(BW.ink)
            HStack(spacing: 8) {
                macro(n.protein.map { "\($0)g" } ?? "—", String(localized: "protein"), highlight: true)
                macro(n.carbs.map { "\($0)g" } ?? "—", String(localized: "carbs"))
                macro(n.fat.map { "\($0)g" } ?? "—", String(localized: "fat"))
                macro(n.calories.map(String.init) ?? "—", String(localized: "kcal"))
            }
            if n.status != .verified {
                Text(n.status == .unknown ? "Nutrition is not yet verified." : "Nutrition is estimated per serving.").font(.bw(.caption2, weight: .medium)).foregroundStyle(BW.inkSecondary)
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

    // MARK: Ingredients with store + sale price

    private var ingredients: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("Ingredients").font(.bw(.title3)).foregroundStyle(BW.ink)
                Spacer()
                if hasSavings {
                    Text(Money.format(price.regularTotal))
                        .font(.bw(.footnote, weight: .medium)).monospacedDigit()
                        .strikethrough().foregroundStyle(BW.inkSecondary)
                }
                Text(price.total.map { "~\(Money.format($0)) total" } ?? String(localized: "Price unknown"))
                    .font(.bw(.subheadline, weight: .heavy)).monospacedDigit()
                    .foregroundStyle(hasSavings ? BW.leafDeep : BW.inkSecondary)
            }
            VStack(spacing: 0) {
                ForEach(Array(price.lines.enumerated()), id: \.element.id) { idx, line in
                    ingredientRow(line)
                    if idx < price.lines.count - 1 { Divider().overlay(BW.hairline).padding(.leading, 60) }
                }
            }
            .bwCard()
            if price.usesSampleData { SamplePricesNote() }
        }
    }

    @ViewBuilder
    private func ingredientRow(_ line: PriceLine) -> some View {
        let onSale = line.deal != nil && line.savings > 0.01
        HStack(spacing: 12) {
            IngredientThumb(ingredientId: line.ingredientId, size: 34)
            VStack(alignment: .leading, spacing: 4) {
                Text(IngredientCatalog.name(line.ingredientId)).font(.bw(.body, weight: .semibold)).foregroundStyle(BW.ink)
                HStack(spacing: 6) {
                    Text(line.unit.format(line.quantity)).font(.bw(.footnote, weight: .regular)).foregroundStyle(BW.inkSecondary)
                    if onSale, let deal = line.deal {
                        StoreChip(retailerId: deal.retailerId, name: deal.retailerDisplayName)
                    }
                }
            }
            Spacer()
            if onSale {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(Money.format(line.regularCost))
                        .font(.bw(.caption, weight: .medium)).monospacedDigit()
                        .strikethrough().foregroundStyle(BW.inkSecondary)
                    Text(Money.format(line.cost))
                        .font(.bw(.headline, weight: .heavy)).monospacedDigit()
                        .foregroundStyle(BW.leafDeep)
                }
            } else {
                Text(Money.format(line.cost)).font(.bw(.subheadline, weight: .medium)).monospacedDigit().foregroundStyle(BW.inkSecondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(onSale ? BW.leafSoft : Color.clear)
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

    // MARK: Bottom actions

    // MARK: Zesty smart swaps

    /// Near-identical items on sale at the user's stores that make this recipe clearly cheaper.
    private var smartSwaps: [SmartSwap] {
        let mine = store.myStoreIds
        let deals = store.deals.filter { mine.isEmpty || mine.contains($0.retailerId) }
        let disliked = Set(store.data.profile.dislikedIngredients.map(\.id))
        return SmartSwaps.find(recipe: recipe, price: price, deals: deals, dislikedIds: disliked)
    }

    private var zestySwapCard: some View {
        let swaps = smartSwaps
        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 10) {
                MascotView(name: BWImage.mascotCheer, size: 52)
                VStack(alignment: .leading, spacing: 2) {
                    Text(swaps.count > 1 ? "Zesty found cheaper swaps" : "Zesty found a cheaper swap")
                        .font(.bw(.headline, weight: .heavy)).foregroundStyle(BW.ink)
                    Text("Almost identical, same result in this recipe.")
                        .font(.bw(.caption, weight: .medium)).foregroundStyle(BW.inkSecondary)
                }
                Spacer(minLength: 0)
            }
            ForEach(swaps) { swap in
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 12) {
                        ProductPhoto(url: swap.deal.imageURL, category: swap.deal.category, ingredientId: swap.deal.ingredientId)
                            .frame(width: 56, height: 56)
                            .clipShape(.rect(cornerRadius: 12))
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Instead of \(IngredientCatalog.name(swap.ingredientId).lowercased())")
                                .font(.bw(.caption, weight: .semibold)).foregroundStyle(BW.inkSecondary)
                            Text(swap.deal.productName).font(.bw(.subheadline, weight: .heavy)).foregroundStyle(BW.ink).lineLimit(2)
                            HStack(spacing: 6) {
                                Text(swap.deal.priceText).font(.bw(.caption, weight: .heavy)).foregroundStyle(BW.leafDeep)
                                if let size = swap.deal.sizeText, !size.isEmpty {
                                    Text(size).font(.bw(.caption, weight: .medium)).foregroundStyle(BW.inkSecondary)
                                }
                                Text("· \(swap.deal.retailerDisplayName)").font(.bw(.caption, weight: .semibold)).foregroundStyle(BW.ink)
                            }
                        }
                        Spacer(minLength: 4)
                        VStack(alignment: .trailing, spacing: 0) {
                            Text("Save").font(.bw(.caption2, weight: .bold)).foregroundStyle(BW.leafDeep)
                            Text(Money.format(swap.saving)).font(.bw(.headline, weight: .heavy)).monospacedDigit().foregroundStyle(BW.leafDeep)
                        }
                    }
                    Text(swap.note).font(.bw(.caption, weight: .medium)).foregroundStyle(BW.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Button {
                        store.addDealToGrocery(swap.deal)
                        toast(String(localized: "Swap added to your list"))
                    } label: {
                        Label("Add to my list", systemImage: "plus.circle.fill")
                            .font(.bw(.subheadline, weight: .heavy)).foregroundStyle(BW.ink)
                            .frame(maxWidth: .infinity).padding(.vertical, 10)
                            .background(BW.lemon, in: .capsule)
                    }
                    .buttonStyle(BWPressableStyle())
                }
                .padding(12)
                .background(.white, in: .rect(cornerRadius: 16))
            }
        }
        .padding(16)
        .background(BW.lemonSoft, in: .rect(cornerRadius: 22))
        .onAppear {
            guard trackedSwapRecipeId != recipe.id else { return }
            trackedSwapRecipeId = recipe.id
            Analytics.track(.smartSwapShown(recipeId: recipe.id, count: swaps.count))
        }
    }

    private func toast(_ text: String) {
        toastText = text
        withAnimation(.spring) { showAddedToast = true }
        Task {
            try? await Task.sleep(for: .seconds(1.8))
            withAnimation { showAddedToast = false }
        }
    }

    private var actionBar: some View {
        VStack(spacing: 10) {
            if let entry = store.savedEntry(recipe), let expiry = entry.expiresAt {
                Button { showPaywall = true } label: {
                    Text("Saved for \(expiry, format: .relative(presentation: .named)) · Save forever with Premium")
                        .font(.bw(.caption, weight: .semibold)).foregroundStyle(BW.inkSecondary)
                }
            }

            Button {
                store.addToGrocery(recipe, servings: servings)
                Analytics.track(.cookTonight(recipeId: recipe.id))
                addedToList += 1
                withAnimation(.spring) { tonightSet = true }
                toast(String(localized: "Tonight's dinner is set · added to your list"))
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: tonightSet ? "checkmark.circle.fill" : "fork.knife")
                    if hasSavings {
                        Text("Cook this tonight · save \(Money.format(price.savings))").monospacedDigit()
                    } else {
                        Text("Cook this tonight")
                    }
                }
                .lineLimit(1).minimumScaleFactor(0.8)
            }
            .buttonStyle(BWPrimaryButtonStyle())
            .sensoryFeedback(.success, trigger: addedToList)

            HStack(spacing: 10) {
                Button { showGrocery = true } label: {
                    Label("View grocery list", systemImage: "cart")
                }
                .buttonStyle(BWSecondaryButtonStyle())

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
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background(BW.canvas.opacity(0.97))
    }
}
