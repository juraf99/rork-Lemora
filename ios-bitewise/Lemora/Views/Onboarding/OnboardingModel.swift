import SwiftUI
import ClerkKit
import CoreLocation
import UserNotifications

/// Answers collected by the v2 onboarding. Codable so a guest can resume, and stored as-is in Supabase.
nonisolated struct OnboardingAnswers: Codable, Hashable, Sendable {
    struct Dislike: Codable, Hashable, Sendable { var id: String; var name: String }

    var referral: String? = nil
    var goal: String = "save_money"
    /// Every goal picked (multi-select); `goal` stays the first one. nil on older saves.
    var goals: [String]? = nil
    var household: Int = 2
    var current: Int = 182
    var target: Int = 168
    var unit: String = "lb"
    var cuisines: [String] = ["all"]
    var diets: [String] = ["none"]
    var allergies: [String] = []
    var noAllergy: Bool = false
    var dislikes: [Dislike] = []
    /// Recipe types wanted (breakfast, lunch, dinner, snack, dessert). nil or empty = all of them.
    var meals: [String]? = nil
    var locMode: String? = nil
    var country: String = "CA"
    var postal: String = ""
    var stores: [String] = []
    var budget: Int = 120
    var budgetTouched: Bool = false
    var noBudget: Bool = false
    var strategy: String = "balanced"
    var notif: String? = nil
    var plan: String = "annual"
    var completed: Bool = false
    /// True once the user has seen their personalized plan (all questions answered).
    var reachedPlan: Bool? = nil
}

/// Savings estimate, same placeholder formula as the design (conservative_budget_v1).
nonisolated struct SavingsEstimate: Codable, Hashable, Sendable {
    var currency: String
    var baselineBudget: Int
    var baselineSource: String
    var rate: Double
    var weekly: Int
    var monthly: Int
    var annual: Int
    var method = "conservative_budget_v1"
    var availableDealData = false
    var confidence = "low"
}

@Observable
final class OnboardingModel {
    enum Screen: String, Codable, CaseIterable {
        case landing, signin, hear, goal, branch, people, diet, allergies, dislikes, meals, location, stores, budget, strategy
        case thanks, notif, ready, generating, savings, reminder, plan, account, email, verify, paywall, done
    }

    enum AuthContext { case new, existing, merge }
    enum EmailMode { case create, signin }

    static let steps: [Screen] = [.hear, .goal, .branch, .people, .diet, .allergies, .dislikes, .meals, .location, .stores, .budget, .strategy]
    private static let storageKey = "lemora-onboarding-v2"
    private static let screenKey = "lemora-onboarding-v2-screen"

    // Persisted answers.
    var a: OnboardingAnswers { didSet { persist() } }
    var screen: Screen { didSet { UserDefaults.standard.set(screen.rawValue, forKey: Self.screenKey) } }

    // Session state.
    var authCtx: AuthContext = .new
    var emailMode: EmailMode = .create
    var reacted = false
    var bump = 0
    var nudgeUntil: Date = .distantPast
    var sadUntil: Date = .distantPast
    var dietNote = ""
    var aQuery = ""
    var iQuery = ""
    var moreOpen = false
    var email = ""
    var password = ""
    var code = ""
    var resetSent = false
    var busy = false
    var errorText: String? = nil
    var showMerge = false
    var doneMode = "new"
    var pct = 0
    var countProgress: Double = 0
    var remoteAnswers: OnboardingAnswers? = nil
    var locating = false

    @ObservationIgnored var pendingSignUpStore: SignUp?
    /// True when the flow only shows the paywall (profile already complete).
    var paywallOnly = false
    @ObservationIgnored private var genTask: Task<Void, Never>?
    @ObservationIgnored let location = LocationService()

    /// How the app was opened. Reopening the app always lands on one of two pages:
    /// - all questions answered (even if they quit on the account page or the paywall) -> "Your Lemora plan";
    /// - otherwise -> the very first page ("Get started" / "Log in"), with fresh answers.
    /// - lapsed: finished before but no active subscription -> plan, then paywall.
    enum Entry { case signedOut, signedIn, lapsed }

    @ObservationIgnored private var needsRemoteAnswers = false

    /// Screens that only come after the last question.
    private static let afterQuestions: Set<Screen> = [.thanks, .notif, .ready, .generating, .savings, .reminder,
                                                      .plan, .account, .email, .verify, .paywall, .done]

    init(entry: Entry = .signedOut) {
        let saved = UserDefaults.standard.data(forKey: Self.storageKey)
            .flatMap { try? JSONDecoder().decode(OnboardingAnswers.self, from: $0) }
        let lastScreen = UserDefaults.standard.string(forKey: Self.screenKey).flatMap { Screen(rawValue: $0) }
        let answeredAll = saved != nil && (saved?.reachedPlan == true || lastScreen.map { Self.afterQuestions.contains($0) } == true)

        if entry == .lapsed {
            a = saved ?? OnboardingAnswers()
            paywallOnly = true
            screen = .plan
            needsRemoteAnswers = !answeredAll
        } else if answeredAll, let saved {
            a = saved
            screen = .plan
        } else {
            // Fresh answers in memory; the old partial ones get overwritten as soon as they answer.
            a = OnboardingAnswers()
            screen = .landing
            // Signed in on a new phone: their answers may be saved online.
            needsRemoteAnswers = entry == .signedIn
        }
    }

    /// Answers not on this device: load them from Supabase and show the plan.
    func restoreRemoteAnswersIfNeeded() async {
        guard needsRemoteAnswers else { return }
        needsRemoteAnswers = false
        if let remote = await OnboardingSync.fetch(), remote.referral != nil {
            a = remote
            go(.plan)
        } else if paywallOnly {
            go(.paywall)
        }
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(a) { UserDefaults.standard.set(data, forKey: Self.storageKey) }
    }

    static func clearSaved() {
        UserDefaults.standard.removeObject(forKey: storageKey)
        UserDefaults.standard.removeObject(forKey: screenKey)
    }

    // MARK: Navigation

    var stepIndex: Int? { Self.steps.firstIndex(of: screen) }

    func go(_ s: Screen) {
        genTask?.cancel()
        if s == .budget && !a.budgetTouched {
            a.budget = min(1000, Int((Double(max(1, a.household)) * 65 / 5).rounded()) * 5)
        }
        withAnimation(.easeInOut(duration: 0.25)) {
            screen = s
        }
        reacted = false
        aQuery = ""
        iQuery = ""
        errorText = nil
        if s == .plan { a.reachedPlan = true }
        if s == .generating { startGen() }
        if s == .savings { startCount() }
    }

    func next() {
        guard let i = stepIndex else { return }
        if !canContinue {
            let t = Date().addingTimeInterval(2)
            nudgeUntil = t
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(2050))
                if self.nudgeUntil == t { self.nudgeUntil = .distantPast }
            }
            return
        }
        go(i < Self.steps.count - 1 ? Self.steps[i + 1] : (a.reachedPlan == true ? .plan : .thanks))
    }

    func back() {
        guard let i = stepIndex else { return }
        go(i > 0 ? Self.steps[i - 1] : .landing)
    }

    func skip() {
        guard let i = stepIndex else { return }
        go(i < Self.steps.count - 1 ? Self.steps[i + 1] : (a.reachedPlan == true ? .plan : .thanks))
    }

    var canContinue: Bool {
        switch screen {
        case .location: currentLocation != nil
        case .stores: !a.stores.isEmpty
        case .hear: a.referral != nil
        case .allergies: a.noAllergy || !a.allergies.isEmpty
        default: true
        }
    }

    /// Zesty reacts every time an answer changes on the current screen.
    func react() {
        reacted = true
        bump += 1
    }

    // MARK: Answers

    func setReferral(_ id: String) { a.referral = id; react() }
    /// Goals are multi-select; at least one always stays picked.
    func setGoal(_ id: String) {
        var picked = a.goals ?? [a.goal]
        if picked.contains(id) {
            if picked.count > 1 { picked.removeAll { $0 == id } }
        } else {
            picked.append(id)
        }
        a.goals = picked
        a.goal = picked.first ?? id
        react()
    }

    var selectedGoals: [String] { a.goals ?? [a.goal] }

    var goalLabels: String {
        selectedGoals.compactMap { id in OBCatalog.goals.first { $0.id == id }?.label }.joined(separator: ", ")
    }
    func setHousehold(_ n: Int) { a.household = n; react() }

    func toggleCuisine(_ id: String) {
        var c = a.cuisines.filter { $0 != "all" }
        if c.contains(id) { c.removeAll { $0 == id } } else { c.append(id) }
        a.cuisines = c
        react()
    }

    func toggleAllCuisines() {
        a.cuisines = a.cuisines.contains("all") ? [] : ["all"]
        react()
    }

    func pickDiet(_ id: String) {
        if id == "none" {
            a.diets = ["none"]; dietNote = ""; react(); return
        }
        var d = a.diets.filter { $0 != "none" }
        if d.contains(id) {
            d.removeAll { $0 == id }
            a.diets = d.isEmpty ? ["none"] : d
            dietNote = ""
            react()
            return
        }
        var note = ""
        for c in OBCatalog.conflicts {
            let other: String? = id == c.a ? c.b : (id == c.b ? c.a : nil)
            if let other, d.contains(other) {
                d.removeAll { $0 == other }
                note = c.message + ". Kept " + (OBCatalog.dietLabel[id] ?? id) + "."
            }
        }
        a.diets = d + [id]
        dietNote = note
        react()
    }

    func toggleNoAllergy() {
        a.noAllergy.toggle()
        a.allergies = []
        react()
    }

    func toggleAllergy(_ id: String) {
        if a.allergies.contains(id) { a.allergies.removeAll { $0 == id } } else { a.allergies.append(id) }
        a.noAllergy = false
        react()
    }

    func addAllergy(_ id: String) {
        if !a.allergies.contains(id) { a.allergies.append(id) }
        a.noAllergy = false
        aQuery = ""
        react()
    }

    func toggleDislike(id: String, name: String) {
        if a.dislikes.contains(where: { $0.id == id }) {
            a.dislikes.removeAll { $0.id == id }
        } else {
            a.dislikes.append(.init(id: id, name: name))
        }
        react()
    }

    func toggleMeal(_ id: String) {
        var picked = a.meals ?? []
        if picked.contains(id) { picked.removeAll { $0 == id } } else { picked.append(id) }
        a.meals = picked
        react()
    }

    func allMeals() {
        a.meals = []
        react()
    }

    var mealList: [String] {
        let picked = a.meals ?? []
        return picked.isEmpty ? ["All meals"] : OBCatalog.meals.filter { picked.contains($0.id) }.map(\.label)
    }

    func addDislike(_ r: OBSearchResult) {
        if !a.dislikes.contains(where: { $0.id == r.id }) { a.dislikes.append(.init(id: r.id, name: r.en)) }
        iQuery = ""
        react()
    }

    func toggleStore(_ name: String) {
        let id = Self.storeId(name)
        if isStorePicked(name) { a.stores.removeAll { Self.storeId($0) == id } } else { a.stores.append(name) }
        react()
    }

    /// Stores are compared by id, so "IGA" picked in onboarding matches "iga" saved in the profile.
    func isStorePicked(_ name: String) -> Bool {
        let id = Self.storeId(name)
        return a.stores.contains { Self.storeId($0) == id }
    }

    // MARK: Nearby stores (from the flyers distributed at the user's postal code or ZIP)

    nonisolated struct NearbyStore: Decodable, Hashable, Sendable {
        let id: String
        let name: String
        let logo: String?
        let covered: Bool
    }

    var nearbyStores: [NearbyStore] = []
    var nearbyPostal = ""
    var nearbyLoading = false

    func loadNearbyStores() async {
        guard let loc = currentLocation else { nearbyStores = []; nearbyPostal = ""; return }
        let code = loc.postal.filter { !$0.isWhitespace }
        guard code != nearbyPostal else { return }
        nearbyLoading = true
        defer { nearbyLoading = false }
        guard let url = URL(string: "\(LemoraBackend.projectURL.absoluteString)/functions/v1/stores-near") else { return }
        var request = URLRequest(url: url, timeoutInterval: 10)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(LemoraBackend.publishableKey, forHTTPHeaderField: "apikey")
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["postal": code])
        struct Response: Decodable { let ok: Bool; let stores: [NearbyStore]? }
        guard let data = try? await URLSession.shared.data(for: request).0,
              let decoded = try? JSONDecoder().decode(Response.self, from: data), decoded.ok,
              let stores = decoded.stores, !stores.isEmpty else { return }
        // The user may have kept typing while the request was in flight.
        guard currentLocation?.postal.filter({ !$0.isWhitespace }) == code else { return }
        nearbyStores = stores
        nearbyPostal = code
    }

    func setBudget(_ v: Int) {
        a.budget = min(1000, max(30, v))
        a.noBudget = false
        a.budgetTouched = true
    }

    func toggleNoBudget() { a.noBudget.toggle(); react() }
    func setStrategy(_ id: String) { a.strategy = id; react() }

    // MARK: Location

    struct ResolvedLocation { let key: String; let name: String; let postal: String; let chains: [String] }

    var currentLocation: ResolvedLocation? {
        let pc = a.postal.uppercased().filter { !$0.isWhitespace }
        let ok: Bool
        if a.country == "CA" {
            ok = pc.count == 6 && pc.enumerated().allSatisfy { i, c in i % 2 == 0 ? c.isLetter && c.isASCII : c.isNumber }
        } else {
            ok = pc.count == 5 && pc.allSatisfy(\.isNumber)
        }
        guard ok else { return nil }
        let region = OBData.regionOf(country: a.country, code: pc)
        let postal = a.country == "CA" ? String(pc.prefix(3)) + " " + String(pc.suffix(3)) : pc
        return ResolvedLocation(key: region.key, name: region.name, postal: postal,
                                chains: OBData.stores[a.country]?[region.key] ?? [])
    }

    /// "Falmouth, KY" for the code, so people can check they are placed at the right spot.
    var cityByPostal: [String: String] = [:]
    func placeName(_ loc: ResolvedLocation) -> String { cityByPostal[loc.postal] ?? loc.name }
    func lookupCity() async {
        guard let loc = currentLocation, cityByPostal[loc.postal] == nil else { return }
        let query = "\(loc.postal), \(a.country == "CA" ? "Canada" : "United States")"
        guard let mark = try? await CLGeocoder().geocodeAddressString(query).first else { return }
        let parts = [mark.locality ?? mark.subAdministrativeArea, mark.administrativeArea].compactMap { $0 }
        if !parts.isEmpty { cityByPostal[loc.postal] = parts.joined(separator: ", ") }
    }

    func allowLocation() {
        a.locMode = "auto"
        locating = true
        location.request()
    }

    /// Called when the one-shot location lookup resolves.
    func applyDevicePostal(_ code: String) {
        locating = false
        var cleaned = code.uppercased().filter { $0.isLetter || $0.isNumber }
        // Apple sometimes returns only the first half of a Canadian postal code ("H2T").
        // Flyer zones are chosen by that first half, so a neutral second half keeps it usable.
        if cleaned.count == 3, cleaned.first?.isLetter == true { cleaned += "0A0" }
        let country = cleaned.first?.isLetter == true ? "CA" : "US"
        if country != a.country { a.stores = [] }
        a.country = country
        a.postal = cleaned
        react()
    }

    func locationFailed() {
        locating = false
        a.locMode = "manual"
    }

    func setCountry(_ c: String) {
        guard c != a.country else { return }
        a.country = c; a.postal = ""; a.stores = []
    }

    /// Typing a ZIP switches to the US, typing a postal code switches to Canada.
    func setPostal(_ v: String) {
        let cleaned = String(v.uppercased().filter { $0.isLetter || $0.isNumber || $0 == " " }.prefix(7))
        if let first = cleaned.first(where: { !$0.isWhitespace }) {
            let country = first.isNumber ? "US" : "CA"
            if country != a.country { a.country = country; a.stores = [] }
        }
        a.locMode = "manual"
        a.postal = cleaned
    }

    // MARK: Derived

    var currency: String { a.country == "US" ? "USD" : "CAD" }

    var estimate: SavingsEstimate {
        let hh = max(1, a.household)
        let base = a.noBudget ? 60 * hh : a.budget
        let rates = ["one": 0.05, "balanced": 0.08, "max": 0.11]
        let rate = (rates[a.strategy] ?? 0.08) + Double(min(max(a.stores.count - 1, 0), 2)) * 0.01
        let w = Int((Double(base) * rate).rounded())
        return SavingsEstimate(currency: currency, baselineBudget: base,
                               baselineSource: a.noBudget ? "household_baseline" : "weekly_budget",
                               rate: rate, weekly: w, monthly: Int((Double(w) * 52 / 12).rounded()), annual: w * 52)
    }

    static func money(_ n: Double) -> String {
        "$" + Int(n.rounded()).formatted(.number.grouping(.automatic).locale(Locale(identifier: "en_US")))
    }

    var goalInfo: OBCatalog.Goal { OBCatalog.goals.first { $0.id == a.goal } ?? OBCatalog.goals[0] }
    var isBodyGoal: Bool { selectedGoals.contains { ["lose_weight", "build_muscle", "gain_weight", "maintain_weight"].contains($0) } }
    var strategyTitle: String {
        (OBCatalog.strategies.first { $0.id == a.strategy } ?? OBCatalog.strategies[1]).label.lowercased().capitalizedFirst
    }
    var dietList: [String] {
        a.diets.contains("none") ? ["No Specific Diet"] : a.diets.map { OBCatalog.dietLabel[$0] ?? $0 }
    }
    func allergenName(_ id: String) -> String { OBData.allergens.first { $0.id == id }?.en ?? id }

    // MARK: Generating + savings animations

    func startGen() {
        pct = 0
        genTask?.cancel()
        let start = Date()
        genTask = Task { @MainActor in
            while !Task.isCancelled {
                let k = min(1, Date().timeIntervalSince(start) / 4.2)
                let e = 1 - pow(1 - k, 1.6)
                let p = max(1, Int(e * 100))
                if p != self.pct { self.pct = p }
                if k >= 1 { break }
                try? await Task.sleep(for: .milliseconds(16))
            }
        }
    }

    func startCount() {
        countProgress = 0
        let start = Date()
        Task { @MainActor in
            while true {
                let k = min(1, Date().timeIntervalSince(start) / 1.3)
                self.countProgress = 1 - pow(1 - k, 3)
                if k >= 1 { break }
                try? await Task.sleep(for: .milliseconds(16))
            }
        }
    }

    // MARK: Notifications

    func notifDeny() {
        sadUntil = Date().addingTimeInterval(1.4)
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(1400))
            self.a.notif = "declined_primer"
            self.go(.ready)
        }
    }

    func notifAllow() {
        Task { @MainActor in
            let granted = (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])) ?? false
            self.a.notif = granted ? "allowed" : "denied_system"
            self.go(.ready)
        }
    }
}

extension String {
    var capitalizedFirst: String { prefix(1).uppercased() + dropFirst() }
}
