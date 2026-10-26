import SwiftUI

enum OnboardingStep: Hashable {
    case goal, birthDate, body, diet, allergies, dislikes, location, stores, budget, strategy
    case building, summary, account
}

/// Conversational onboarding guided by Zesty: one question per screen, then Build My Plan,
/// a personalized plan summary and account creation.
struct OnboardingFlowView: View {
    @Environment(AppStore.self) private var store
    @State private var profile: UserProfile = UserProfile()
    @State private var index: Int = 0
    @State private var forward: Bool = true
    @State private var preview: PlanPreview? = nil
    @State private var didTrackStart = false

    private var steps: [OnboardingStep] {
        var s: [OnboardingStep] = [.goal]
        if profile.goal.needsBodyMetrics { s += [.birthDate, .body] }
        s += [.diet, .allergies, .dislikes, .location, .stores, .budget, .strategy, .building, .summary]
        if !store.isSignedIn { s.append(.account) }
        return s
    }

    private var step: OnboardingStep { steps[min(index, steps.count - 1)] }
    private var questionCount: Int { steps.firstIndex(of: .building) ?? steps.count }
    private var progress: Double { min(1, Double(index + 1) / Double(questionCount)) }
    private var isQuestion: Bool { index < questionCount }

    var body: some View {
        VStack(spacing: 0) {
            header
            ZStack {
                VStack(spacing: 0) {
                    if let line = zestLine {
                        ZestGuide(text: line, size: 60)
                            .padding(.horizontal, 20)
                            .padding(.top, 10)
                    }
                    content
                }
                .id(step)
                .transition(.asymmetric(
                    insertion: .move(edge: forward ? .trailing : .leading).combined(with: .opacity),
                    removal: .move(edge: forward ? .leading : .trailing).combined(with: .opacity)))
            }
            .frame(maxHeight: .infinity)
            if isQuestion || step == .summary { footer }
        }
        .background(BW.canvas)
        .onAppear {
            guard !didTrackStart else { return }
            didTrackStart = true
            Analytics.track(.onboardingStarted)
        }
    }

    private var header: some View {
        HStack(spacing: 14) {
            Button {
                go(-1)
            } label: {
                Image(systemName: "chevron.left")
                    .font(.headline)
                    .foregroundStyle(BW.ink)
                    .frame(width: 44, height: 44)
            }
            .opacity(canGoBack ? 1 : 0)
            .disabled(!canGoBack)
            .accessibilityLabel("Back")

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(BW.beige)
                    Capsule().fill(BW.lemon).frame(width: geo.size.width * progress)
                }
            }
            .frame(height: 8)
            .opacity(isQuestion ? 1 : 0)
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: progress)

            Color.clear.frame(width: 44, height: 44)
        }
        .padding(.horizontal, 12)
    }

    private var canGoBack: Bool { index > 0 && step != .building }

    private var zestLine: String? {
        switch step {
        case .goal: String(localized: "Hi, I'm Zesty! Let's build your plan together.")
        case .birthDate: String(localized: "Just so my suggestions make sense for you.")
        case .body: String(localized: "Only used to match meals to your goal.")
        case .diet: String(localized: "How do you eat? I'll only show what fits.")
        case .allergies: String(localized: "Safety first. No allergies? Just tap Continue.")
        case .dislikes: String(localized: "Anything you never want to see? I'll hide it.")
        case .location: String(localized: "Let's find the grocery stores near you.")
        case .stores: String(localized: "Where do you usually shop?")
        case .budget: String(localized: "Roughly what do you spend each week?")
        case .strategy: String(localized: "Last one! How do you like to shop?")
        case .account: String(localized: "Save your plan so it's always with you.")
        case .building, .summary: nil
        }
    }

    @ViewBuilder
    private var content: some View {
        switch step {
        case .goal: GoalStep(profile: $profile)
        case .birthDate: BirthDateStep(profile: $profile)
        case .body: BodyStep(profile: $profile)
        case .diet: DietStep(profile: $profile)
        case .allergies: AllergyStep(profile: $profile)
        case .dislikes: DislikeStep(profile: $profile)
        case .location: LocationStep(profile: $profile)
        case .stores: StoresStep(profile: $profile)
        case .budget: BudgetStep(profile: $profile)
        case .strategy: StrategyStep(profile: $profile)
        case .building:
            BuildingPlanView(profile: profile, preview: preview ?? store.planPreview(for: profile)) { go(1) }
        case .summary:
            PlanSummaryStep(profile: profile, preview: preview ?? store.planPreview(for: profile))
        case .account:
            AccountStep { name, email in
                store.signIn(name: name, email: email)
                store.completeOnboarding(with: profile)
            }
        }
    }

    private var canContinue: Bool {
        switch step {
        case .diet: !profile.diets.isEmpty
        case .stores: profile.storePreferences.values.contains { $0 != .doNotRecommend }
        default: true
        }
    }

    private var footerTitle: String {
        switch step {
        case .strategy: String(localized: "Build My Plan")
        case .summary: store.isSignedIn ? String(localized: "Continue") : String(localized: "Save My Plan")
        default: String(localized: "Continue")
        }
    }

    private var footer: some View {
        VStack(spacing: 8) {
            Button {
                if step == .strategy {
                    preview = store.planPreview(for: profile)
                    Analytics.track(.planBuildStarted)
                }
                if step == .summary && store.isSignedIn {
                    store.completeOnboarding(with: profile)
                } else {
                    go(1)
                }
            } label: {
                HStack(spacing: 8) {
                    if step == .strategy { Image(systemName: "sparkles") }
                    Text(footerTitle)
                }
            }
            .buttonStyle(BWPrimaryButtonStyle())
            .disabled(!canContinue)
            .opacity(canContinue ? 1 : 0.45)
            .sensoryFeedback(.selection, trigger: index)

            if step == .stores && !canContinue {
                Text("Pick at least one store you shop at.")
                    .font(.bw(.caption, weight: .medium)).foregroundStyle(BW.inkSecondary)
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 12)
        .padding(.top, 8)
    }

    private func go(_ delta: Int) {
        forward = delta > 0
        var target = max(0, min(steps.count - 1, index + delta))
        if delta < 0 && steps[target] == .building { target = max(0, target - 1) }
        withAnimation(.spring(response: 0.45, dampingFraction: 0.88)) {
            index = target
        }
    }
}

// MARK: - Shared step scaffolding

struct StepScaffold<Content: View>: View {
    let title: String
    var subtitle: String? = nil
    @ViewBuilder let content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(title)
                        .font(.bw(.title, weight: .heavy))
                        .foregroundStyle(BW.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    if let subtitle {
                        Text(subtitle).font(.bw(.subheadline, weight: .regular)).foregroundStyle(BW.inkSecondary)
                    }
                }
                content
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
            .padding(.bottom, 24)
        }
        .scrollDismissesKeyboard(.interactively)
    }
}

struct OptionRow: View {
    let title: String
    var subtitle: String? = nil
    var symbol: String? = nil
    let selected: Bool
    var multi: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                if let symbol {
                    Image(systemName: symbol)
                        .font(.title3)
                        .foregroundStyle(BW.ink)
                        .frame(width: 44, height: 44)
                        .background(selected ? BW.card : BW.beigeSoft, in: .circle)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.bw(.body, weight: .semibold)).foregroundStyle(BW.ink)
                    if let subtitle {
                        Text(subtitle).font(.bw(.footnote, weight: .regular)).foregroundStyle(BW.inkSecondary)
                    }
                }
                .multilineTextAlignment(.leading)
                Spacer(minLength: 8)
                Image(systemName: selected ? (multi ? "checkmark.square.fill" : "checkmark.circle.fill") : (multi ? "square" : "circle"))
                    .font(.title3)
                    .foregroundStyle(selected ? BW.ink : BW.outline)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(minHeight: 64)
            .background(selected ? BW.lemon.opacity(0.55) : BW.card, in: .rect(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(selected ? BW.lemon : BW.hairline, lineWidth: selected ? 2 : 1))
        }
        .buttonStyle(BWPressableStyle())
        .sensoryFeedback(.selection, trigger: selected)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

struct ChoiceChip: View {
    let title: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.bw(.subheadline, weight: .semibold))
                .foregroundStyle(BW.ink)
                .padding(.horizontal, 16)
                .frame(minHeight: 44)
                .background(selected ? BW.lemon : BW.card, in: .capsule)
                .overlay(Capsule().strokeBorder(selected ? BW.lemon : BW.hairline))
        }
        .buttonStyle(BWPressableStyle())
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

struct ChipFlow<Item: Hashable, Chip: View>: View {
    let items: [Item]
    @ViewBuilder let chip: (Item) -> Chip

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 130), spacing: 10, alignment: .leading)], alignment: .leading, spacing: 10) {
            ForEach(items, id: \.self) { chip($0) }
        }
    }
}

// MARK: - Steps

struct GoalStep: View {
    @Binding var profile: UserProfile

    var body: some View {
        StepScaffold(title: String(localized: "What's your main goal?"), subtitle: String(localized: "We'll tune every recommendation around it.")) {
            VStack(spacing: 10) {
                ForEach(Goal.allCases) { goal in
                    OptionRow(title: goal.title, symbol: goal.symbol, selected: profile.goal == goal) {
                        profile.goal = goal
                        if goal == .buildMuscle { profile.diets.insert(.highProtein) }
                    }
                }
            }
        }
    }
}

struct HeardFromStep: View {
    @Binding var profile: UserProfile

    var body: some View {
        StepScaffold(title: String(localized: "How did you hear about us?")) {
            ChipFlow(items: ReferralSource.onboardingCases) { source in
                ChoiceChip(title: source.title, selected: profile.referralSource == source) { profile.referralSource = source }
            }
        }
    }
}

struct BirthDateStep: View {
    @Binding var profile: UserProfile
    @State private var date: Date = Calendar.current.date(byAdding: .year, value: -28, to: .now) ?? .now

    var body: some View {
        StepScaffold(title: String(localized: "When were you born?"), subtitle: String(localized: "Used only to keep suggestions sensible for you.")) {
            DatePicker("Birth date", selection: $date, in: ...Date.now, displayedComponents: .date)
                .datePickerStyle(.wheel)
                .labelsHidden()
                .frame(maxWidth: .infinity)
                .bwCard()
                .onChange(of: date) { _, new in profile.birthDate = new }
                .onAppear {
                    if let existing = profile.birthDate { date = existing } else { profile.birthDate = date }
                }
        }
    }
}

struct BodyStep: View {
    @Binding var profile: UserProfile
    @State private var height: Double = 170
    @State private var weight: Double = 70
    @State private var goalWeight: Double = 70

    var body: some View {
        StepScaffold(title: String(localized: "A few quick numbers"), subtitle: String(localized: "Lemora is not medical advice. We only use this to suggest meals that fit your goal.")) {
            Picker("Units", selection: $profile.usesMetric) {
                Text("Metric").tag(true)
                Text("Imperial").tag(false)
            }
            .pickerStyle(.segmented)

            VStack(spacing: 14) {
                metricRow(String(localized: "Height"), value: $height, range: 130...220, format: heightText)
                metricRow(String(localized: "Current weight"), value: $weight, range: 40...200, format: weightText)
                metricRow(String(localized: "Goal weight"), value: $goalWeight, range: 40...200, format: weightText)
            }
        }
        .onAppear {
            height = profile.heightCm ?? 170
            weight = profile.weightKg ?? 70
            goalWeight = profile.goalWeightKg ?? (profile.goal == .loseWeight ? 65 : 75)
            save()
        }
        .onChange(of: height) { _, _ in save() }
        .onChange(of: weight) { _, _ in save() }
        .onChange(of: goalWeight) { _, _ in save() }
    }

    private func save() {
        profile.heightCm = height
        profile.weightKg = weight
        profile.goalWeightKg = goalWeight
    }

    private func heightText(_ cm: Double) -> String {
        if profile.usesMetric { return "\(Int(cm)) cm" }
        let inches = Int((cm / 2.54).rounded())
        return "\(inches / 12)′ \(inches % 12)″"
    }

    private func weightText(_ kg: Double) -> String {
        profile.usesMetric ? "\(Int(kg)) kg" : "\(Int((kg * 2.20462).rounded())) lb"
    }

    private func metricRow(_ title: String, value: Binding<Double>, range: ClosedRange<Double>, format: @escaping (Double) -> String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title).font(.bw(.subheadline, weight: .semibold)).foregroundStyle(BW.inkSecondary)
                Spacer()
                Text(format(value.wrappedValue)).font(.bw(.title3, weight: .heavy)).monospacedDigit().foregroundStyle(BW.ink)
            }
            Slider(value: value, in: range, step: 1).tint(BW.amber)
        }
        .padding(16)
        .bwCard()
    }
}

struct ValueStep: View {
    let mascot: String
    let image: String
    let title: String
    let message: String
    @State private var appear: Bool = false

    var body: some View {
        VStack(spacing: 22) {
            ZStack(alignment: .topTrailing) {
                FoodImage(name: image, height: 300, radius: BW.heroRadius)
                MascotView(name: mascot, size: 96, bob: true)
                    .offset(x: 6, y: -44)
            }
            .padding(.top, 48)
            .scaleEffect(appear ? 1 : 0.94)
            .opacity(appear ? 1 : 0)
            Text(title)
                .font(.bw(.title, weight: .heavy))
                .foregroundStyle(BW.ink)
                .multilineTextAlignment(.center)
            Text(message)
                .font(.bw(.body, weight: .regular))
                .foregroundStyle(BW.inkSecondary)
                .multilineTextAlignment(.center)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 24)
        .onAppear { withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) { appear = true } }
    }
}

struct DietStep: View {
    @Binding var profile: UserProfile

    var body: some View {
        StepScaffold(title: String(localized: "How do you eat?"), subtitle: String(localized: "Pick all that apply.")) {
            VStack(spacing: 10) {
                ForEach(DietPreference.allCases) { diet in
                    OptionRow(title: diet.title, selected: profile.diets.contains(diet), multi: true) { toggle(diet) }
                }
            }
        }
    }

    private func toggle(_ diet: DietPreference) {
        if diet == .everything {
            profile.diets = profile.diets.contains(.everything) ? [] : [.everything]
            return
        }
        profile.diets.remove(.everything)
        if profile.diets.contains(diet) { profile.diets.remove(diet) } else { profile.diets.insert(diet) }
        if profile.diets.isEmpty { profile.diets = [.everything] }
    }
}

struct AllergyStep: View {
    @Binding var profile: UserProfile
    @State private var custom: String = ""

    var body: some View {
        StepScaffold(title: String(localized: "Any allergies?"), subtitle: String(localized: "These are strict. Recipes that contain or may contain them are never recommended.")) {
            ChipFlow(items: Allergen.allCases) { allergen in
                ChoiceChip(title: allergen.title, selected: profile.allergies.contains(allergen)) {
                    if profile.allergies.contains(allergen) { profile.allergies.remove(allergen) } else { profile.allergies.insert(allergen) }
                }
            }
            CustomEntryField(placeholder: String(localized: "Add another allergy"), text: $custom) {
                let value = custom.trimmingCharacters(in: .whitespaces)
                guard !value.isEmpty, !profile.allergyRefs.contains(where: { $0.name.localizedCaseInsensitiveCompare(value) == .orderedSame }) else { return }
                let id = value.lowercased().replacingOccurrences(of: " ", with: "_")
                profile.allergyRefs.append(AllergyRef(id: id, name: value, kind: .ingredient))
                profile.hasNoAllergies = false
                custom = ""
            }
            let customAllergies = profile.allergyRefs.filter { $0.kind == .ingredient }
            if !customAllergies.isEmpty {
                ChipFlow(items: customAllergies) { item in
                    ChoiceChip(title: "\(item.name)  ✕", selected: true) { profile.allergyRefs.removeAll { $0.id == item.id } }
                }
            }
        }
    }
}

struct DislikeStep: View {
    @Binding var profile: UserProfile
    @State private var custom: String = ""

    private let common = ["Mushrooms", "Olives", "Onions", "Cilantro", "Seafood", "Tomatoes", "Avocado", "Spicy food", "Eggs", "Tofu"]

    private var items: [String] {
        common + profile.dislikeNames.filter { !common.contains($0) }
    }

    var body: some View {
        StepScaffold(title: String(localized: "Any foods you never want to see?")) {
            ChipFlow(items: items) { item in
                ChoiceChip(title: item, selected: profile.dislikeNames.contains(item)) {
                    if let index = profile.dislikedIngredients.firstIndex(where: { $0.name == item }) {
                        profile.dislikedIngredients.remove(at: index)
                    } else {
                        profile.dislikedIngredients.append(ingredientRef(item))
                    }
                }
            }
            CustomEntryField(placeholder: String(localized: "Search or add a food"), text: $custom) {
                let value = custom.trimmingCharacters(in: .whitespaces).capitalized
                guard !value.isEmpty, !profile.dislikeNames.contains(value) else { return }
                profile.dislikedIngredients.append(ingredientRef(value))
                custom = ""
            }
        }
    }

    private func ingredientRef(_ name: String) -> IngredientRef {
        let match = IngredientCatalog.all.values.first {
            $0.name.localizedCaseInsensitiveCompare(name) == .orderedSame
        }
        return IngredientRef(
            id: match?.id ?? name.lowercased().replacingOccurrences(of: " ", with: "_"),
            name: match?.name ?? name
        )
    }
}

struct CustomEntryField: View {
    let placeholder: String
    @Binding var text: String
    let onAdd: () -> Void

    var body: some View {
        HStack {
            TextField(placeholder, text: $text)
                .font(.bw(.body, weight: .medium))
                .submitLabel(.done)
                .onSubmit(onAdd)
            Button("Add", systemImage: "plus.circle.fill", action: onAdd)
                .labelStyle(.iconOnly)
                .font(.title2)
                .foregroundStyle(text.isEmpty ? BW.outline : BW.ink)
                .disabled(text.isEmpty)
        }
        .padding(.horizontal, 18)
        .frame(height: 54)
        .background(BW.card, in: .capsule)
        .overlay(Capsule().strokeBorder(BW.hairline))
    }
}

struct CuisineStep: View {
    @Binding var profile: UserProfile

    var body: some View {
        StepScaffold(title: String(localized: "Cuisines you love"), subtitle: String(localized: "Optional. We'll still surprise you with others.")) {
            ChipFlow(items: Cuisine.allCases) { cuisine in
                ChoiceChip(title: cuisine.title, selected: profile.cuisines.contains(cuisine)) {
                    if profile.cuisines.contains(cuisine) { profile.cuisines.remove(cuisine) } else { profile.cuisines.insert(cuisine) }
                }
            }
        }
    }
}

struct BudgetStep: View {
    @Binding var profile: UserProfile
    @State private var amount: Double = 100
    @State private var flexible: Bool = false

    var body: some View {
        StepScaffold(title: String(localized: "What's your approximate grocery budget?")) {
            VStack(spacing: 16) {
                Text(flexible ? String(localized: "Flexible") : "\(Money.format(amount)) / week")
                    .font(.bw(size: 44, weight: .heavy))
                    .monospacedDigit()
                    .foregroundStyle(BW.ink)
                    .contentTransition(.numericText())
                Slider(value: $amount, in: 30...400, step: 5).tint(BW.amber).disabled(flexible).opacity(flexible ? 0.4 : 1)
                Toggle("No strict budget", isOn: $flexible).font(.bw(.body, weight: .semibold)).tint(BW.leaf)
            }
            .padding(20)
            .bwCard()

            VStack(alignment: .leading, spacing: 10) {
                Text("People in your household").font(.bw(.headline)).foregroundStyle(BW.ink)
                Stepper(value: $profile.householdSize, in: 1...10) {
                    Text(profile.householdSize == 1 ? String(localized: "Just me") : String(localized: "\(profile.householdSize) people"))
                        .font(.bw(.body, weight: .semibold))
                }
            }
            .padding(20)
            .bwCard()
        }
        .onAppear {
            flexible = profile.weeklyBudget == nil
            amount = profile.weeklyBudget ?? 100
        }
        .onChange(of: amount) { _, v in if !flexible { profile.weeklyBudget = v } }
        .onChange(of: flexible) { _, f in profile.weeklyBudget = f ? nil : amount }
    }
}

struct StoresStep: View {
    @Binding var profile: UserProfile
    @State private var query: String = ""
    @State private var showMore: Bool = false
    @State private var showSpecialty: Bool = false

    var body: some View {
        StepScaffold(title: String(localized: "Where do you shop?"), subtitle: String(localized: "Pick as many as you like. Long-press to mark a store as preferred or one to avoid.")) {
            SearchField(text: $query, placeholder: String(localized: "Search grocery stores"))

            if query.isEmpty {
                group(String(localized: "Popular near you"), tier: .featured)
                if showMore { group(String(localized: "More grocery stores"), tier: .more) }
                else { revealButton(String(localized: "See more grocery stores")) { showMore = true } }
                if showSpecialty { group(String(localized: "Specialty & local markets"), tier: .specialty) }
                else { revealButton(String(localized: "Specialty & local markets")) { showSpecialty = true } }
            } else {
                grid(RetailerCatalog.all.filter { $0.name.localizedStandardContains(query) })
            }

            if profile.storePreferences["costco"].map({ $0 != .doNotRecommend }) == true {
                Toggle("I have a Costco membership", isOn: $profile.shopsAtCostco)
                    .font(.bw(.subheadline, weight: .semibold)).tint(BW.leaf)
                    .padding(16).bwCard()
            }
        }
    }

    private func group(_ title: String, tier: RetailerTier) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.bw(.headline)).foregroundStyle(BW.ink)
            grid(RetailerCatalog.all.filter { $0.tier == tier })
        }
    }

    private func grid(_ retailers: [Retailer]) -> some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
            ForEach(retailers) { retailer in
                StoreTile(retailer: retailer, preference: profile.storePreferences[retailer.id]) { pref in
                    profile.storePreferences[retailer.id] = pref
                    if retailer.id == "costco" { profile.shopsAtCostco = pref != nil && pref != .doNotRecommend }
                }
            }
        }
    }

    private func revealButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button {
            withAnimation(.snappy) { action() }
        } label: {
            HStack {
                Text(title).font(.bw(.subheadline, weight: .semibold))
                Spacer()
                Image(systemName: "chevron.down")
            }
            .foregroundStyle(BW.ink)
            .padding(.horizontal, 16)
            .frame(minHeight: 50)
            .background(BW.beigeSoft, in: .rect(cornerRadius: 16))
        }
    }
}

struct StoreTile: View {
    let retailer: Retailer
    let preference: StorePreference?
    let onChange: (StorePreference?) -> Void

    var body: some View {
        Button {
            onChange(preference == nil ? .acceptable : nil)
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(retailer.name)
                        .font(.bw(.subheadline, weight: .bold))
                        .foregroundStyle(preference == .doNotRecommend ? BW.inkSecondary : BW.ink)
                        .strikethrough(preference == .doNotRecommend)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    Spacer(minLength: 4)
                    Image(systemName: icon).foregroundStyle(iconColor)
                }
                Text(caption).font(.bw(.caption2, weight: .medium)).foregroundStyle(BW.inkSecondary)
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
            .background(fill, in: .rect(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(preference == nil ? BW.hairline : .clear))
        }
        .buttonStyle(BWPressableStyle())
        .contextMenu {
            Button("Preferred", systemImage: "star.fill") { onChange(.preferred) }
            Button("Acceptable", systemImage: "checkmark") { onChange(.acceptable) }
            Button("Don't recommend", systemImage: "hand.raised") { onChange(.doNotRecommend) }
            Button("Clear", systemImage: "xmark") { onChange(nil) }
        }
        .accessibilityValue(Text(preference?.title ?? String(localized: "Not selected")))
    }

    private var caption: String {
        var parts: [String] = []
        if let preference { parts.append(preference.title) }
        if retailer.membershipRequired { parts.append(String(localized: "Membership")) }
        return parts.isEmpty ? " " : parts.joined(separator: " · ")
    }

    private var icon: String {
        switch preference {
        case .preferred: "star.fill"
        case .acceptable: "checkmark.circle.fill"
        case .doNotRecommend: "hand.raised.fill"
        case nil: "plus.circle"
        }
    }

    private var iconColor: Color {
        switch preference {
        case .preferred: BW.amber
        case .acceptable: BW.leafDeep
        case .doNotRecommend: BW.danger
        case nil: BW.outline
        }
    }

    private var fill: Color {
        switch preference {
        case .preferred, .acceptable: BW.lemon.opacity(0.45)
        case .doNotRecommend: BW.beige
        case nil: BW.card
        }
    }
}

struct SearchField: View {
    @Binding var text: String
    let placeholder: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass").foregroundStyle(BW.inkSecondary)
            TextField(placeholder, text: $text).font(.bw(.body, weight: .medium))
            if !text.isEmpty {
                Button("Clear", systemImage: "xmark.circle.fill") { text = "" }
                    .labelStyle(.iconOnly).foregroundStyle(BW.outline)
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 50)
        .background(BW.card, in: .capsule)
        .overlay(Capsule().strokeBorder(BW.hairline))
    }
}

struct StrategyStep: View {
    @Binding var profile: UserProfile

    var body: some View {
        StepScaffold(title: String(localized: "How do you prefer to shop?")) {
            VStack(spacing: 10) {
                ForEach(ShoppingStrategy.allCases) { s in
                    OptionRow(title: s.title, subtitle: s.subtitle, symbol: s.symbol, selected: profile.strategy == s) { profile.strategy = s }
                }
            }
            VStack(alignment: .leading, spacing: 10) {
                Text("Maximum stores per trip").font(.bw(.headline)).foregroundStyle(BW.ink)
                Picker("Maximum stores", selection: $profile.maxStores) {
                    Text("1").tag(1)
                    Text("2").tag(2)
                    Text("3").tag(3)
                    Text("4+").tag(4)
                    Text("Any").tag(0)
                }
                .pickerStyle(.segmented)
            }
            .padding(.top, 6)
        }
    }
}

struct LocationStep: View {
    @Binding var profile: UserProfile
    @State private var location: LocationService = LocationService()

    var body: some View {
        StepScaffold(title: String(localized: "Find deals near you")) {
            VStack(spacing: 18) {
                Image(systemName: "location.circle.fill")
                    .font(.system(size: 64))
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(BW.ink, BW.lemon)
                    .padding(.top, 8)
                Text("Use your location to find nearby stores and local deals. We only check it when you open the app, never in the background.")
                    .font(.bw(.body, weight: .regular))
                    .foregroundStyle(BW.inkSecondary)
                    .multilineTextAlignment(.center)

                Button {
                    location.request()
                } label: {
                    Label(buttonTitle, systemImage: "location.fill")
                }
                .buttonStyle(BWPrimaryButtonStyle())
                .disabled(location.state == .requesting)

                if location.state == .denied || location.state == .failed {
                    Text("No problem. Enter your postal code instead.")
                        .font(.bw(.footnote, weight: .medium)).foregroundStyle(BW.inkSecondary)
                }

                TextField("Postal code (e.g. H2X 1Y4)", text: Binding(
                    get: { profile.location.postalCode },
                    set: { code in
                        let country = profile.location.country ?? .canada
                        profile.location = .manual(country: country, postalCode: code)
                    }
                ))
                    .textInputAutocapitalization(.characters)
                    .font(.bw(.body, weight: .semibold))
                    .padding(.horizontal, 18)
                    .frame(height: 54)
                    .background(BW.card, in: .capsule)
                    .overlay(Capsule().strokeBorder(BW.hairline))
            }
        }
        .onChange(of: location.state) { _, state in
            if case .resolved(let code) = state {
                profile.location = .manual(country: profile.location.country ?? .canada, postalCode: code)
            }
        }
    }

    private var buttonTitle: String {
        switch location.state {
        case .requesting: String(localized: "Finding you…")
        case .resolved: String(localized: "Location found")
        default: String(localized: "Use my location")
        }
    }
}
