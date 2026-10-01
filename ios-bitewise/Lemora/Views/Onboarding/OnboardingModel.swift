import SwiftUI
import ClerkKit
import UserNotifications

/// Answers collected by the v2 onboarding. Codable so a guest can resume, and stored as-is in Supabase.
nonisolated struct OnboardingAnswers: Codable, Hashable, Sendable {
    struct Dislike: Codable, Hashable, Sendable { var id: String; var name: String }

    var referral: String? = nil
    var goal: String = "save_money"
    var household: Int = 2
    var current: Int = 182
    var target: Int = 168
    var unit: String = "lb"
    var cuisines: [String] = ["italian", "mexican"]
    var diets: [String] = ["none"]
    var allergies: [String] = []
    var noAllergy: Bool = false
    var dislikes: [Dislike] = []
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
        case landing, signin, hear, goal, branch, people, diet, allergies, dislikes, location, stores, budget, strategy
        case thanks, notif, ready, generating, savings, reminder, plan, account, email, verify, paywall, done
    }

    enum AuthContext { case new, existing, merge }
    enum EmailMode { case create, signin }

    static let steps: [Screen] = [.hear, .goal, .branch, .people, .diet, .allergies, .dislikes, .location, .stores, .budget, .strategy]
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

    init(startAt: Screen? = nil) {
        let saved = UserDefaults.standard.data(forKey: Self.storageKey)
            .flatMap { try? JSONDecoder().decode(OnboardingAnswers.self, from: $0) }
        a = saved ?? OnboardingAnswers()
        if let startAt {
            screen = startAt
            paywallOnly = startAt == .paywall
        } else if let raw = UserDefaults.standard.string(forKey: Self.screenKey), let s = Screen(rawValue: raw),
                  ![.generating, .done, .verify, .email, .signin].contains(s) {
            screen = s
        } else {
            screen = .landing
        }
        if screen == .savings { startCount() }
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
        go(i < Self.steps.count - 1 ? Self.steps[i + 1] : .thanks)
    }

    func back() {
        guard let i = stepIndex else { return }
        go(i > 0 ? Self.steps[i - 1] : .landing)
    }

    func skip() {
        guard let i = stepIndex else { return }
        go(i < Self.steps.count - 1 ? Self.steps[i + 1] : .thanks)
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
    func setGoal(_ id: String) { a.goal = id; react() }
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

    func addDislike(_ r: OBSearchResult) {
        if !a.dislikes.contains(where: { $0.id == r.id }) { a.dislikes.append(.init(id: r.id, name: r.en)) }
        iQuery = ""
        react()
    }

    func toggleStore(_ name: String) {
        if a.stores.contains(name) { a.stores.removeAll { $0 == name } } else { a.stores.append(name) }
        react()
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

    func allowLocation() {
        a.locMode = "auto"
        locating = true
        location.request()
    }

    /// Called when the one-shot location lookup resolves.
    func applyDevicePostal(_ code: String) {
        locating = false
        let cleaned = code.uppercased().filter { $0.isLetter || $0.isNumber }
        a.country = cleaned.first?.isLetter == true ? "CA" : "US"
        a.postal = cleaned
        a.stores = []
        react()
    }

    func locationFailed() {
        locating = false
        a.locMode = "manual"
    }

    func setCountry(_ c: String) { a.country = c; a.postal = ""; a.stores = [] }
    func setPostal(_ v: String) { a.postal = String(v.prefix(10)); a.stores = [] }

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
    var isBodyGoal: Bool { ["lose_weight", "build_muscle", "gain_weight", "maintain_weight"].contains(a.goal) }
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
