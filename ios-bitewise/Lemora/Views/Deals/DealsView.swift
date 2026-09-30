import SwiftUI

struct DealsView: View {
    @Environment(AppStore.self) private var store
    @State private var path: NavigationPath = NavigationPath()
    @State private var myStoresOnly: Bool = true

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header
                    storeToggle
                    worthIt
                    steals
                    SamplePricesNote().padding(.horizontal, 20)
                }
                .padding(.bottom, 24)
            }
            .background(BW.canvas)
            .toolbar(.hidden, for: .navigationBar)
            .bitewiseDestinations()
            .onAppear { store.track("deals_opened") }
        }
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Fresh deals for you")
                    .font(.bw(.title, weight: .heavy))
                    .foregroundStyle(BW.ink)
                Text("Updated this week").font(.bw(.subheadline, weight: .regular)).foregroundStyle(BW.inkSecondary)
            }
            Spacer()
            MascotView(name: BWImage.mascotWave, size: 76, bob: true)
        }
        .padding(.horizontal, 20)
        .padding(.top, 4)
    }

    private var storeToggle: some View {
        HStack(spacing: 4) {
            toggleButton(String(localized: "My Stores"), selected: myStoresOnly) { myStoresOnly = true }
            toggleButton(String(localized: "All Stores"), selected: !myStoresOnly) {
                myStoresOnly = false
                store.track("all_stores_enabled")
            }
        }
        .padding(4)
        .background(BW.beige, in: .capsule)
        .padding(.horizontal, 20)
        .sensoryFeedback(.selection, trigger: myStoresOnly)
    }

    private func toggleButton(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button {
            withAnimation(.snappy) { action() }
        } label: {
            Text(title)
                .font(.bw(.subheadline, weight: .bold))
                .foregroundStyle(BW.ink)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(selected ? BW.lemon : .clear, in: .capsule)
        }
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    // MARK: Worth It

    private var worthItItems: [ScoredRecipe] { store.worthIt }

    private var worthIt: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: String(localized: "Worth It This Week"), subtitle: String(localized: "Meals you'll love, cheaper right now")) {
                path.append(Route.worthItAll)
            }
            .padding(.horizontal, 20)

            if worthItItems.isEmpty {
                Text("No deal-powered meals match your profile this week yet.")
                    .font(.bw(.subheadline, weight: .regular)).foregroundStyle(BW.inkSecondary)
                    .padding(.horizontal, 20)
            } else {
                ScrollView(.horizontal) {
                    LazyHStack(spacing: 14) {
                        ForEach(worthItItems) { item in
                            NavigationLink(value: Route.recipe(item.id)) {
                                WorthItCard(item: item)
                            }
                            .buttonStyle(BWPressableStyle())
                        }
                    }
                    .scrollTargetLayout()
                }
                .contentMargins(.horizontal, 20)
                .scrollTargetBehavior(.viewAligned)
                .scrollIndicators(.hidden)
            }
        }
    }

    // MARK: Steals

    private var stealItems: [Deal] { store.steals(myStoresOnly: myStoresOnly) }

    private var steals: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: String(localized: "Steals of the Week"), subtitle: myStoresOnly ? String(localized: "At your stores") : String(localized: "At stores near you")) {
                path.append(Route.stealsAll)
            }

            if stealItems.isEmpty {
                Text("No active deals at your stores right now. Try All Stores.")
                    .font(.bw(.subheadline, weight: .regular)).foregroundStyle(BW.inkSecondary)
            } else {
                let visible = stealItems
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)], spacing: 14) {
                    ForEach(visible) { deal in
                        NavigationLink(value: Route.deal(deal.id)) {
                            StealCard(deal: deal)
                        }
                        .buttonStyle(BWPressableStyle())
                    }
                }
            }
        }
        .padding(.horizontal, 20)
    }
}

struct WorthItCard: View {
    let item: ScoredRecipe

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            FoodImage(name: item.recipe.imageName, height: 180, radius: 0)
            VStack(alignment: .leading, spacing: 8) {
                Text(item.recipe.title)
                    .font(.bw(.headline)).foregroundStyle(BW.ink).lineLimit(1)
                HStack(spacing: 8) {
                    MatchBadge(percent: item.matchPercent, compact: true)
                    Text("\(Money.format(item.price.perServing))/serving")
                        .font(.bw(.subheadline, weight: .medium)).monospacedDigit().foregroundStyle(BW.inkSecondary)
                }
                if let headline = item.price.headlineDeal, let deal = headline.deal {
                    Text("\(IngredientCatalog.name(headline.ingredientId)) on sale at \(deal.retailerDisplayName)")
                        .font(.bw(.caption, weight: .semibold)).foregroundStyle(BW.leafDeep).lineLimit(1)
                }
            }
            .padding(14)
        }
        .frame(width: 280)
        .background(BW.card)
        .clipShape(.rect(cornerRadius: BW.cardRadius))
        .shadow(color: BW.ink.opacity(0.07), radius: 14, y: 6)
        .padding(.vertical, 8)
    }
}

struct StealCard: View {
    let deal: Deal

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .topLeading) {
                DealArtwork(deal: deal, height: 130, radius: 0)
                if let label = deal.label {
                    DealTag(text: label.title).padding(10)
                }
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(IngredientCatalog.name(deal.ingredientId))
                    .font(.bw(.subheadline, weight: .bold)).foregroundStyle(BW.ink).lineLimit(1)
                Text(deal.priceText)
                    .font(.bw(.title3, weight: .heavy)).monospacedDigit().foregroundStyle(BW.ink)
                    .lineLimit(1).minimumScaleFactor(0.8)
                HStack(spacing: 4) {
                    Text(deal.retailerDisplayName)
                    if let pct = deal.discountPercent {
                        Text("·")
                        Text("-\(pct)%").foregroundStyle(BW.leafDeep)
                    }
                }
                .font(.bw(.caption, weight: .semibold))
                .foregroundStyle(BW.inkSecondary)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(BW.card)
        .clipShape(.rect(cornerRadius: BW.cardRadius))
        .shadow(color: BW.ink.opacity(0.06), radius: 12, y: 5)
    }
}

private struct DealArtwork: View {
    let deal: Deal
    let height: CGFloat
    let radius: CGFloat

    var body: some View {
        Group {
            if let image = deal.imageName {
                FoodImage(name: image, height: height, radius: radius)
            } else if let url = deal.imageURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    default:
                        placeholder
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: height)
                .clipped()
                .clipShape(.rect(cornerRadius: radius))
            } else {
                placeholder
                    .frame(height: height)
                    .clipShape(.rect(cornerRadius: radius))
            }
        }
    }

    private var placeholder: some View {
        BW.beigeSoft
            .overlay {
                Text(IngredientCatalog.emoji(deal.ingredientId))
                    .font(.system(size: min(90, height * 0.45)))
            }
    }
}

struct DealDetailView: View {
    let dealId: String
    @Environment(AppStore.self) private var store
    @State private var added: Int = 0

    private var deal: Deal? { store.dealById(dealId) }

    var body: some View {
        ScrollView {
            if let deal {
                VStack(alignment: .leading, spacing: 20) {
                    ZStack(alignment: .topLeading) {
                        DealArtwork(deal: deal, height: 240, radius: BW.heroRadius)
                        if let label = deal.label { DealTag(text: label.title).padding(14) }
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text(deal.productName).font(.bw(.title2, weight: .heavy)).foregroundStyle(BW.ink)
                        HStack(alignment: .firstTextBaseline, spacing: 10) {
                            Text(deal.priceText).font(.bw(size: 38, weight: .heavy)).monospacedDigit().foregroundStyle(BW.ink)
                            if let regular = deal.regularPrice {
                                Text("reg. \(Money.format(regular))\(deal.multiBuyQuantity == nil ? deal.unitLabel : " ea")")
                                    .font(.bw(.subheadline, weight: .medium)).strikethrough().foregroundStyle(BW.inkSecondary)
                            }
                        }
                        if let q = deal.multiBuyQuantity, q > 1 {
                            Text("That's \(Money.format(deal.effectivePrice)) each").font(.bw(.subheadline, weight: .semibold)).foregroundStyle(BW.leafDeep)
                        }
                        Text("At \(deal.retailerDisplayName) · until \(deal.validUntil.formatted(.dateTime.weekday(.wide).month().day()))")
                            .font(.bw(.subheadline, weight: .medium)).foregroundStyle(BW.inkSecondary)
                        Text(deal.confidence.note).font(.bw(.caption, weight: .medium)).foregroundStyle(BW.inkSecondary)
                    }

                    if deal.category == .protein && (deal.discountPercent ?? 0) >= 30 {
                        MascotTip(text: String(localized: "Great price! Consider freezing extra portions for later."), mascot: BWImage.mascotCheer)
                    }

                    Button {
                        store.addDealToGrocery(deal)
                        added += 1
                    } label: {
                        Label(added > 0 ? String(localized: "Added to grocery list") : String(localized: "Add to grocery list"),
                              systemImage: added > 0 ? "checkmark" : "cart.badge.plus")
                    }
                    .buttonStyle(BWPrimaryButtonStyle())
                    .sensoryFeedback(.success, trigger: added)

                    let meals = store.recipesUsing(ingredientId: deal.ingredientId)
                    if !meals.isEmpty {
                        Text("Meals to make with it").font(.bw(.title3)).foregroundStyle(BW.ink)
                        VStack(spacing: 12) {
                            ForEach(meals) { item in
                                NavigationLink(value: Route.recipe(item.id)) { RecipeRow(item: item) }
                                    .buttonStyle(BWPressableStyle())
                            }
                        }
                    }
                    if deal.isSampleData { SamplePricesNote() }
                }
                .padding(20)
            } else {
                EmptyStateView(mascot: BWImage.mascotPeek, title: String(localized: "This deal has ended"),
                               message: String(localized: "We only show promotions that are still valid."))
            }
        }
        .background(BW.canvas)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .onAppear { store.track("deal_opened", ["deal": dealId]) }
    }
}

/// Compact recipe row used in lists (deal detail, Ask, Worth It list).
struct RecipeRow: View {
    let item: ScoredRecipe

    var body: some View {
        HStack(spacing: 14) {
            Color.clear
                .frame(width: 84, height: 84)
                .overlay { Image(item.recipe.imageName).resizable().aspectRatio(contentMode: .fill).allowsHitTesting(false) }
                .clipShape(.rect(cornerRadius: 16))
            VStack(alignment: .leading, spacing: 6) {
                Text(item.recipe.title).font(.bw(.headline)).foregroundStyle(BW.ink).lineLimit(2).multilineTextAlignment(.leading)
                HStack(spacing: 10) {
                    Text("\(item.recipe.nutrition.protein)g protein")
                    Text("\(Money.format(item.price.perServing))/serving").monospacedDigit()
                }
                .font(.bw(.caption, weight: .medium)).foregroundStyle(BW.inkSecondary)
                HStack(spacing: 6) {
                    MatchBadge(percent: item.matchPercent, compact: true)
                    if item.price.dealCount > 0 {
                        SoftChip(text: item.price.dealCount == 1 ? String(localized: "1 deal") : String(localized: "\(item.price.dealCount) deals"), symbol: "tag.fill", fill: BW.leafSoft, foreground: BW.leafDeep)
                    }
                }
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right").font(.caption.weight(.bold)).foregroundStyle(BW.outline)
        }
        .padding(12)
        .bwCard()
    }
}

struct WorthItListView: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(store.worthIt) { item in
                    NavigationLink(value: Route.recipe(item.id)) { RecipeRow(item: item) }
                        .buttonStyle(BWPressableStyle())
                }
                SamplePricesNote().padding(.top, 8)
            }
            .padding(20)
        }
        .background(BW.canvas)
        .navigationTitle("Worth It This Week")
        .toolbar(.hidden, for: .tabBar)
        .onAppear { store.track("worth_it_opened") }
    }
}

struct StealsListView: View {
    @Environment(AppStore.self) private var store
    @State private var category: GroceryCategory? = nil

    private var items: [Deal] {
        store.steals(myStoresOnly: false).filter { category == nil || $0.category == category }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        ChoiceChip(title: String(localized: "All"), selected: category == nil) { category = nil }
                        ForEach(GroceryCategory.allCases, id: \.self) { c in
                            ChoiceChip(title: c.title, selected: category == c) { category = c }
                        }
                    }
                }
                .scrollIndicators(.hidden)

                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)], spacing: 14) {
                        ForEach(items) { deal in
                            NavigationLink(value: Route.deal(deal.id)) { StealCard(deal: deal) }
                                .buttonStyle(BWPressableStyle())
                        }
                    }
                SamplePricesNote()
            }
            .padding(20)
        }
        .background(BW.canvas)
        .navigationTitle("Steals of the Week")
        .toolbar(.hidden, for: .tabBar)
        .onAppear { store.track("steals_opened") }
    }
}
