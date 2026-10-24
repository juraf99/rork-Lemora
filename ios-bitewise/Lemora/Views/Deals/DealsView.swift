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
                    checkingBanner
                    storeToggle
                    storesThisWeek
                    seeAllBanner
                    lowestPrices
                    worthIt
                    if stealItems.contains(where: \.isSampleData) {
                        SamplePricesNote().padding(.horizontal, 20)
                    }
                }
                .padding(.bottom, 24)
            }
            .background(BW.canvas)
            .toolbar(.hidden, for: .navigationBar)
            .bitewiseDestinations()
            .analyticsScreen("Deals")
            .onAppear {
                store.track("deals_opened")
                ensureVisibleDeals()
            }
            .onChange(of: store.deals) { _, _ in ensureVisibleDeals() }
            .animation(.snappy, value: store.checkingNewArea)
        }
    }

    // MARK: New area

    @ViewBuilder private var checkingBanner: some View {
        if store.checkingNewArea {
            HStack(spacing: 12) {
                ProgressView().tint(BW.ink)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Checking deals near you…").font(.bw(.subheadline, weight: .bold)).foregroundStyle(BW.ink)
                    Text("New area: this takes about 1 minute. Deals appear by themselves.")
                        .font(.bw(.caption, weight: .medium)).foregroundStyle(BW.inkSecondary)
                }
                Spacer(minLength: 0)
            }
            .padding(14)
            .background(BW.lemon.opacity(0.35), in: .rect(cornerRadius: 16))
            .padding(.horizontal, 20)
            .transition(.opacity)
        }
    }

    // MARK: Header

    private var storeCount: Int { Set(stealItems.map(\.retailerId)).count }

    private var headerSubtitle: String {
        if myStoresOnly && storeCount > 0 {
            return storeCount == 1 ? String(localized: "Fresh deals from this week’s sales at your store")
                                   : String(localized: "Fresh deals from this week’s sales at your \(storeCount) stores")
        }
        return String(localized: "Fresh deals from this week’s sales near you")
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 3) {
                LemoraWordmark(size: 44, color: BW.ink)
                Text(headerSubtitle).font(.bw(.subheadline, weight: .regular)).foregroundStyle(BW.inkSecondary)
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

    // MARK: Stores this week

    private var stealItems: [Deal] { store.steals(myStoresOnly: myStoresOnly) }

    /// A stale or unsupported store selection must not make the whole page look empty.
    /// Switch the visible scope to All Stores while keeping the user's preferences intact.
    private func ensureVisibleDeals() {
        guard myStoresOnly,
              store.steals(myStoresOnly: true).isEmpty,
              !store.steals(myStoresOnly: false).isEmpty else { return }
        myStoresOnly = false
    }

    private var storeGroups: [StoreDeals] {
        let grouped = Dictionary(grouping: stealItems, by: \.retailerId)
        return grouped.map { entry in
            StoreDeals(id: entry.key,
                       name: entry.value.first?.retailerDisplayName ?? RetailerCatalog.name(entry.key),
                       deals: entry.value.sorted { a, b in (a.discountPercent ?? 0) > (b.discountPercent ?? 0) })
        }
        .sorted { a, b in a.deals.count > b.deals.count }
    }

    private var storesThisWeek: some View {
        VStack(alignment: .leading, spacing: 4) {
            SectionHeader(title: myStoresOnly ? String(localized: "Your stores this week") : String(localized: "Stores near you this week")) {
                path.append(Route.stealsAll)
            }
            .padding(.horizontal, 20)

            if storeGroups.isEmpty {
                Text("No active deals at your stores right now. Try All Stores.")
                    .font(.bw(.subheadline, weight: .regular)).foregroundStyle(BW.inkSecondary)
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
            } else {
                ScrollView(.horizontal) {
                    LazyHStack(alignment: .top, spacing: 14) {
                        ForEach(storeGroups) { group in
                            StoreDealsCard(group: group)
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

    private var seeAllBanner: some View {
        Button { path.append(Route.stealsAll) } label: {
            HStack(spacing: 14) {
                Image(systemName: "tag.fill")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(BW.ink)
                    .frame(width: 50, height: 50)
                    .background(BW.lemon, in: .circle)
                VStack(alignment: .leading, spacing: 3) {
                    Text("See all foods on sale this week")
                        .font(.bw(.headline)).foregroundStyle(.white)
                        .lineLimit(1).minimumScaleFactor(0.8)
                    Text(myStoresOnly ? String(localized: "\(stealItems.count) deals at your stores")
                                      : String(localized: "\(stealItems.count) deals near you"))
                        .font(.bw(.subheadline, weight: .medium)).foregroundStyle(.white.opacity(0.75))
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right").font(.headline.weight(.heavy)).foregroundStyle(BW.lemon)
            }
            .padding(16)
            .background(BW.ink, in: .rect(cornerRadius: BW.cardRadius))
        }
        .buttonStyle(BWPressableStyle())
        .padding(.horizontal, 20)
    }

    // MARK: Current prices

    private var priceItems: [StorePrice] {
        let scoped = store.storePrices(myStoresOnly: myStoresOnly)
        var cheapest: [String: StorePrice] = [:]
        for price in scoped {
            if cheapest[price.ingredientId].map({ price.currentPrice < $0.currentPrice }) ?? true {
                cheapest[price.ingredientId] = price
            }
        }
        return Array(cheapest.values)
            .sorted { lhs, rhs in
                if lhs.isDiscounted != rhs.isDiscounted { return lhs.isDiscounted }
                return lhs.currentPrice < rhs.currentPrice
            }
    }

    @ViewBuilder
    private var lowestPrices: some View {
        if !priceItems.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(
                    title: String(localized: "Lowest current prices"),
                    subtitle: String(localized: "Fresh shelf prices available for your Quebec market")
                )
                .padding(.horizontal, 20)

                ScrollView(.horizontal) {
                    LazyHStack(spacing: 12) {
                        ForEach(priceItems.prefix(12)) { price in
                            CurrentPriceCard(price: price)
                        }
                    }
                }
                .contentMargins(.horizontal, 20)
                .scrollIndicators(.hidden)

                Text("Prices from epiceries.ca · Updated weekly · Verify in store")
                    .font(.bw(.caption2, weight: .medium))
                    .foregroundStyle(BW.inkSecondary)
                    .padding(.horizontal, 20)
            }
        }
    }

    // MARK: Worth It

    private var worthItItems: [ScoredRecipe] { store.worthIt }

    private var worthIt: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: String(localized: "Worth It This Week"), subtitle: String(localized: "Meals you'll love, built from these deals")) {
                path.append(Route.worthItAll)
            }
            .padding(.horizontal, 20)

            if worthItItems.isEmpty {
                Text("No deal-powered meals match your profile this week yet.")
                    .font(.bw(.subheadline, weight: .regular)).foregroundStyle(BW.inkSecondary)
                    .padding(.horizontal, 20)
            } else {
                VStack(spacing: 16) {
                    ForEach(Array(worthItItems.prefix(3))) { item in
                        NavigationLink(value: Route.recipe(item.id)) {
                            WorthItCard(item: item)
                        }
                        .buttonStyle(BWPressableStyle())
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }
}

private struct CurrentPriceCard: View {
    let price: StorePrice

    var body: some View {
        Group {
            if let sourceURL = price.sourceURL {
                Link(destination: sourceURL) { content }
            } else {
                content
            }
        }
        .buttonStyle(BWPressableStyle())
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 8) {
            ProductPhoto(url: price.imageURL, category: price.category, ingredientId: price.ingredientId)
                .frame(height: 96)
                .clipShape(.rect(cornerRadius: 12))
            Text(price.retailerProductName ?? price.productName)
                .font(.bw(.subheadline, weight: .bold))
                .foregroundStyle(BW.ink)
                .lineLimit(2)
            Text(price.priceText)
                .font(.bw(.title3, weight: .heavy))
                .foregroundStyle(BW.ink)
            Text(price.retailerName)
                .font(.bw(.caption, weight: .semibold))
                .foregroundStyle(BW.inkSecondary)
            if let size = price.sizeText, !size.isEmpty {
                Text(size)
                    .font(.bw(.caption2, weight: .regular))
                    .foregroundStyle(BW.inkSecondary)
                    .lineLimit(1)
            }
        }
        .padding(14)
        .frame(width: 180)
        .frame(minHeight: 168, alignment: .topLeading)
        .background(BW.card, in: .rect(cornerRadius: BW.cardRadius))
    }
}

// MARK: - Store styling

/// Store colors for chips and store cards. Unknown stores use the app's lemon palette.
enum StoreStyle {
    static func colors(_ id: String) -> (bg: Color, fg: Color) {
        switch id {
        case "maxi": return (Color(hex: 0xFCE44D), Color(hex: 0x1D4F91))
        case "iga": return (Color(hex: 0xD7323A), .white)
        case "metro": return (Color(hex: 0xC8102E), .white)
        case "superc": return (Color(hex: 0xFFCB05), Color(hex: 0xC8102E))
        case "provigo": return (Color(hex: 0xEE7623), .white)
        case "walmart": return (Color(hex: 0x0071CE), Color(hex: 0xFFC220))
        case "costco": return (Color(hex: 0x005DAA), .white)
        case "adonis": return (Color(hex: 0x1E5B3A), .white)
        default: return (BW.lemonSoft, BW.ink)
        }
    }
}

struct StoreChip: View {
    let retailerId: String
    let name: String

    var body: some View {
        let c = StoreStyle.colors(retailerId)
        Text(name)
            .font(.bw(.caption, weight: .heavy))
            .foregroundStyle(c.fg)
            .lineLimit(1)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(c.bg, in: .capsule)
    }
}

enum DealTiming {
    /// "Deal ends Sunday" this week, otherwise "Deal ends Oct 12".
    static func endText(_ date: Date, plural: Bool = false) -> String {
        let days = Calendar.current.dateComponents([.day], from: .now, to: date).day ?? 0
        if days < 1 {
            return plural ? String(localized: "Deals end today") : String(localized: "Deal ends today")
        }
        let when = days < 7 ? date.formatted(.dateTime.weekday(.wide)) : date.formatted(.dateTime.month(.abbreviated).day())
        return plural ? String(localized: "Deals end \(when)") : String(localized: "Deal ends \(when)")
    }
}

struct StoreDeals: Identifiable {
    let id: String
    let name: String
    let deals: [Deal]
}

/// One store's best deals this week, and meals you can make with them.
struct StoreDealsCard: View {
    @Environment(AppStore.self) private var store
    let group: StoreDeals

    private var top: [Deal] { Array(group.deals.prefix(3)) }

    private var meals: [ScoredRecipe] {
        var seen = Set<ScoredRecipe.ID>()
        var out: [ScoredRecipe] = []
        for deal in top {
            for item in store.recipesUsing(ingredientId: deal.ingredientId) where !seen.contains(item.id) {
                seen.insert(item.id)
                out.append(item)
            }
        }
        return Array(out.sorted { a, b in a.price.savings > b.price.savings }.prefix(3))
    }

    var body: some View {
        let c = StoreStyle.colors(group.id)
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(group.name)
                        .font(.bw(size: 30, weight: .heavy))
                        .foregroundStyle(c.fg)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    if let end = group.deals.map(\.validUntil).min() {
                        Label(DealTiming.endText(end, plural: true), systemImage: "timer")
                            .font(.bw(.subheadline, weight: .bold))
                            .foregroundStyle(c.fg.opacity(0.85))
                    }
                }
                Spacer(minLength: 8)
                Text(group.deals.count == 1 ? String(localized: "1 deal") : String(localized: "\(group.deals.count) deals"))
                    .font(.bw(.caption, weight: .heavy))
                    .foregroundStyle(BW.ink)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(.white.opacity(0.92), in: .capsule)
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(c.bg)

            VStack(spacing: 0) {
                ForEach(Array(top.enumerated()), id: \.element.id) { i, deal in
                    NavigationLink(value: Route.deal(deal.id)) { dealRow(deal) }
                        .buttonStyle(BWPressableStyle())
                    if i < top.count - 1 {
                        Rectangle().fill(BW.hairline).frame(height: 1)
                    }
                }
            }
            .padding(.horizontal, 16)

            if meals.isEmpty {
                Color.clear.frame(height: 8)
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    Text("With these, you can make")
                        .font(.bw(.subheadline, weight: .bold))
                        .foregroundStyle(BW.ink)
                    HStack(alignment: .top, spacing: 8) {
                        ForEach(meals) { item in
                            NavigationLink(value: Route.recipe(item.id)) { mealTile(item) }
                                .buttonStyle(BWPressableStyle())
                        }
                    }
                }
                .padding(16)
            }
        }
        .frame(width: 300)
        .background(BW.card)
        .clipShape(.rect(cornerRadius: BW.cardRadius))
        .shadow(color: BW.ink.opacity(0.07), radius: 14, y: 6)
        .padding(.vertical, 8)
    }

    private func dealRow(_ deal: Deal) -> some View {
        HStack(spacing: 12) {
            DealArtwork(deal: deal, height: 56, radius: 14)
                .frame(width: 56)
            VStack(alignment: .leading, spacing: 2) {
                Text(deal.productName)
                    .font(.bw(.subheadline, weight: .bold))
                    .foregroundStyle(BW.ink)
                    .lineLimit(2)
                if let size = deal.sizeText, !size.isEmpty {
                    Text(size)
                        .font(.bw(.caption2, weight: .medium))
                        .foregroundStyle(BW.inkSecondary)
                        .lineLimit(1)
                }
                if let regular = deal.regularPrice {
                    Text(Money.format(regular))
                        .font(.bw(.caption, weight: .medium))
                        .strikethrough()
                        .foregroundStyle(BW.inkSecondary)
                }
            }
            Spacer(minLength: 6)
            VStack(alignment: .trailing, spacing: 4) {
                Text(deal.priceText)
                    .font(.bw(.headline, weight: .heavy))
                    .monospacedDigit()
                    .foregroundStyle(BW.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                if let pct = deal.discountPercent {
                    Text("-\(pct)%")
                        .font(.bw(.caption, weight: .heavy))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(BW.leafDeep, in: .capsule)
                }
            }
        }
        .padding(.vertical, 12)
        .contentShape(.rect)
    }

    private func mealTile(_ item: ScoredRecipe) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            FoodImage(name: item.recipe.imageName, height: 64, radius: 0)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.recipe.title)
                    .font(.bw(.caption, weight: .bold))
                    .foregroundStyle(BW.ink)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                if item.price.savings > 0.01 {
                    Text("Save \(Money.format(item.price.savings))")
                        .font(.bw(.caption, weight: .heavy))
                        .foregroundStyle(BW.leafDeep)
                }
            }
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity)
        .background(BW.beigeSoft)
        .clipShape(.rect(cornerRadius: 14))
    }
}

/// Worth It card: savings and stores on the photo, then every deal ingredient with its store and price.
struct WorthItCard: View {
    let item: ScoredRecipe

    private struct StoreRef: Hashable { let id: String; let name: String }

    private var lines: [PriceLine] {
        Array(item.price.dealLines.sorted { a, b in a.savings > b.savings }.prefix(3))
    }

    private var stores: [StoreRef] {
        var seen = Set<String>()
        var out: [StoreRef] = []
        for line in item.price.dealLines {
            if let deal = line.deal, !seen.contains(deal.retailerId) {
                seen.insert(deal.retailerId)
                out.append(StoreRef(id: deal.retailerId, name: deal.retailerDisplayName))
            }
        }
        return out
    }

    private var endDate: Date? { item.price.dealLines.compactMap { $0.deal?.validUntil }.min() }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            FoodImage(name: item.recipe.imageName, height: 190, radius: 0)
                .overlay(alignment: .topLeading) {
                    if item.price.savings > 0.01 {
                        Text("Save \(Money.format(item.price.savings)) total")
                            .font(.bw(.subheadline, weight: .heavy))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(BW.leafDeep, in: .capsule)
                            .padding(12)
                    }
                }
                .overlay(alignment: .topTrailing) {
                    HStack(spacing: 4) {
                        ForEach(Array(stores.prefix(3)), id: \.self) { s in
                            StoreChip(retailerId: s.id, name: s.name)
                        }
                    }
                    .padding(12)
                }

            VStack(alignment: .leading, spacing: 10) {
                Text(item.recipe.title)
                    .font(.bw(.title3, weight: .heavy))
                    .foregroundStyle(BW.ink)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                HStack(spacing: 8) {
                    MatchBadge(percent: item.matchPercent, compact: true)
                    Text("based on your preferences + your deals")
                        .font(.bw(.caption, weight: .medium))
                        .foregroundStyle(BW.inkSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                if !lines.isEmpty {
                    VStack(spacing: 6) {
                        ForEach(lines) { line in
                            HStack(spacing: 8) {
                                if let deal = line.deal {
                                    StoreChip(retailerId: deal.retailerId, name: deal.retailerDisplayName)
                                }
                                Text(IngredientCatalog.name(line.ingredientId))
                                    .font(.bw(.subheadline, weight: .bold))
                                    .foregroundStyle(BW.ink)
                                    .lineLimit(1)
                                Spacer(minLength: 6)
                                Text(Money.format(line.regularCost))
                                    .font(.bw(.caption, weight: .medium))
                                    .strikethrough()
                                    .foregroundStyle(BW.inkSecondary)
                                Text(Money.format(line.cost))
                                    .font(.bw(.subheadline, weight: .heavy))
                                    .monospacedDigit()
                                    .foregroundStyle(BW.leafDeep)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 9)
                            .background(BW.leafSoft.opacity(0.6), in: .rect(cornerRadius: 12))
                        }
                    }
                }
                HStack {
                    Text("\(Money.format(item.price.perServing))/serving · \(item.recipe.totalMinutes) min")
                        .font(.bw(.subheadline, weight: .medium))
                        .monospacedDigit()
                        .foregroundStyle(BW.inkSecondary)
                    Spacer(minLength: 8)
                    if let endDate {
                        Label(DealTiming.endText(endDate), systemImage: "timer")
                            .font(.bw(.caption, weight: .bold))
                            .foregroundStyle(BW.amber)
                    }
                }
            }
            .padding(16)
        }
        .background(BW.card)
        .clipShape(.rect(cornerRadius: BW.cardRadius))
        .shadow(color: BW.ink.opacity(0.07), radius: 14, y: 6)
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
                Text(deal.productName)
                    .font(.bw(.subheadline, weight: .bold)).foregroundStyle(BW.ink)
                    .lineLimit(2, reservesSpace: true)
                Text(deal.sizeText?.isEmpty == false ? deal.sizeText! : " ")
                    .font(.bw(.caption2, weight: .medium)).foregroundStyle(BW.inkSecondary).lineLimit(1)
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
            } else {
                ProductPhoto(url: deal.imageURL, category: deal.category, ingredientId: deal.ingredientId)
                    .frame(maxWidth: .infinity)
                    .frame(height: height)
                    .clipShape(.rect(cornerRadius: radius))
            }
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
                        Text("At \(deal.retailerDisplayName) · valid \(deal.validFrom.formatted(.dateTime.month().day()))–\(deal.validUntil.formatted(.dateTime.month().day()))")
                            .font(.bw(.subheadline, weight: .medium)).foregroundStyle(BW.inkSecondary)
                        if let brand = deal.brand, !brand.isEmpty {
                            Text("Brand: \(brand)").font(.bw(.caption, weight: .medium)).foregroundStyle(BW.inkSecondary)
                        }
                        Text("Format: \(deal.sizeText?.isEmpty == false ? deal.sizeText! : "not specified in the flyer")")
                            .font(.bw(.caption, weight: .medium))
                            .foregroundStyle(BW.inkSecondary)
                        if deal.processingLevel == "processed" || deal.processingLevel == "ultra_processed" {
                            Text(deal.processingLevel == "ultra_processed" ? "Highly processed" : "Processed")
                                .font(.bw(.caption, weight: .bold))
                                .foregroundStyle(deal.processingLevel == "ultra_processed" ? BW.danger : BW.inkSecondary)
                        }
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
        .analyticsScreen("Deal")
        .onAppear { Analytics.track(.dealViewed(dealId: dealId)) }
    }
}

/// Compact recipe row used in lists (deal detail, Ask, Worth It list).
struct RecipeRow: View {
    let item: ScoredRecipe

    var body: some View {
        HStack(spacing: 14) {
            Color.clear
                .frame(width: 84, height: 84)
                .overlay { FoodImage(name: item.recipe.imageName, height: 84, radius: 16).allowsHitTesting(false) }
                .clipShape(.rect(cornerRadius: 16))
            VStack(alignment: .leading, spacing: 6) {
                Text(item.recipe.title).font(.bw(.headline)).foregroundStyle(BW.ink).lineLimit(2).multilineTextAlignment(.leading)
                HStack(spacing: 10) {
                    Text(item.recipe.nutrition.protein.map { "\($0)g protein" } ?? String(localized: "Nutrition unknown"))
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
