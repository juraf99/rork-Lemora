#!/usr/bin/env python3
"""Lemora launch fixes: Canada-wide Instacart deals, USD normalisation, no sample deals,
store prices outside Quebec, tester bypass limited to TestFlight. Fails loudly if an anchor is missing."""
import re, sys
from pathlib import Path

ROOT = Path(sys.argv[1] if len(sys.argv) > 1 else "ios-bitewise/Lemora")

def edit(rel, fn):
    p = ROOT / rel
    s = p.read_text()
    out = fn(s)
    if out == s:
        print("already up to date", rel)
        return
    p.write_text(out)
    print("edited", rel)

def sub1(s, old, new, label):
    # Idempotent: an edit already applied by an earlier workflow is skipped.
    if (new and new in s) or (not new and old not in s):
        return s
    if s.count(old) != 1:
        sys.exit(f"anchor '{label}' found {s.count(old)} times")
    return s.replace(old, new)

# ---------- SupabaseService ----------
ENSURE = '''    private static func ensureFlyerZone(_ postal: String) async {
        let cleaned = postal.uppercased().filter { $0.isLetter || $0.isNumber }
        guard let first = cleaned.first else { return }
        // Australia: Woolworths and Coles specials are national and loaded every Wednesday on the server.
        if cleaned.count == 4, cleaned.allSatisfy(\\.isNumber) { return }
        // Quebec uses the weekly flyers. US ZIP codes and the rest of Canada use Instacart store prices
        // (the first visit of an area takes about 1 minute, then it is cached for 3 days).
        let instacart = first.isNumber || !"GHJ".contains(first)
        let name = instacart ? "instacart-us" : "flipp-direct-ingest"
        guard let url = URL(string: "\\(LemoraBackend.projectURL.absoluteString)/functions/v1/\\(name)") else { return }
        var request = URLRequest(url: url, timeoutInterval: instacart ? 100 : 8)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(LemoraBackend.publishableKey, forHTTPHeaderField: "apikey")
        let body: [String: String] = instacart ? (first.isNumber ? ["zip": String(cleaned.prefix(5))] : ["postal": cleaned]) : ["ensurePostal": postal]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        _ = try? await URLSession.shared.data(for: request)
    }
'''

def supabase(s):
    m = re.search(r"    private static func ensureFlyerZone\(_ postal: String\) async \{\n.*?\n    \}\n", s, re.S)
    if not m:
        sys.exit("ensureFlyerZone not found")
    s = s[:m.start()] + ENSURE + s[m.end():]
    if "RetailerCatalog.learn(" not in s:
      s = sub1(s, "        return Deal(\n            id: id,\n            ingredientId: ingredientId,\n            retailerId: Self.normalizedRetailerId(retailerId),",
             "        // Prices are kept in CAD inside the app (converted for display). US store prices arrive in USD.\n"
             "        let toCAD = currencyCode.uppercased() == \"USD\" ? 1 / AppCurrency.usd.perCAD : 1\n"
             "        RetailerCatalog.learn(Self.normalizedRetailerId(retailerId), retailerName)\n"
             "        return Deal(\n            id: id,\n            ingredientId: ingredientId,\n            retailerId: Self.normalizedRetailerId(retailerId),", "deal init")
    s = sub1(s, "            salePrice: salePrice,\n            regularPrice: regularPrice,\n            unitLabel: unitLabel,",
             "            salePrice: salePrice * toCAD,\n            regularPrice: regularPrice.map { $0 * toCAD },\n            unitLabel: unitLabel,", "prices")
    s = sub1(s, "            sourcePostalCode: sourcePostalCode,\n            currencyCode: currencyCode,",
             "            sourcePostalCode: sourcePostalCode,\n            currencyCode: \"CAD\",", "currency")
    return s

edit("Services/SupabaseService.swift", supabase)

# ---------- GroceryCatalog: names of stores outside the Quebec registry ----------
def catalog(s):
    s = sub1(s, "        return byId[id]?.name ?? id\n    }\n}",
             "        return byId[id]?.name ?? learnedNames.get(id) ?? id\n    }\n\n"
             "    /// Store names seen in live deals (US and Canada outside Quebec), so ids never show raw.\n"
             "    private static let learnedNames = LearnedNames()\n"
             "    static func learn(_ id: String, _ name: String) {\n"
             "        guard byId[id] == nil, !name.isEmpty else { return }\n"
             "        learnedNames.set(id, name)\n    }\n}\n\n"
             "private final class LearnedNames: @unchecked Sendable {\n"
             "    private let lock = NSLock()\n    private var names: [String: String] = [:]\n"
             "    func get(_ id: String) -> String? { lock.lock(); defer { lock.unlock() }; return names[id] }\n"
             "    func set(_ id: String, _ name: String) { lock.lock(); names[id] = name; lock.unlock() }\n}", "catalog name")
    return s

edit("Data/GroceryCatalog.swift", catalog)


LOAD = """    /// Loads this week's food deals for the user's area. A new US / Canada area is fetched once (~40 s):
    /// the app stays usable and the Deals tab shows a "checking deals near you" banner meanwhile.
    /// A newer load (location changed) always wins over an older one.
    func loadLiveDeals() async {
        dealLoadID += 1
        let loadID = dealLoadID
        let slow = Task {
            try? await Task.sleep(for: .seconds(2))
            if !Task.isCancelled, loadID == dealLoadID { checkingNewArea = true }
        }
        defer {
            slow.cancel()
            if loadID == dealLoadID { checkingNewArea = false }
        }
        do {
            let fetched = try await SupabaseService.shared.fetchActiveDeals(location: data.profile.location)
            guard loadID == dealLoadID else { return }
            availableDeals = fetched
            liveDealsLoaded = true
            dealLoadError = nil
            refreshDeals()
        } catch {
            guard loadID == dealLoadID else { return }
            dealLoadError = error.localizedDescription
            // Never show sample prices to real users: keep the last live deals, or none.
            if !liveDealsLoaded {
                availableDeals = []
                refreshDeals()
            }
            analytics.track("live_deals_load_failed", ["error": error.localizedDescription])
        }
    }
"""

BANNER = """
    // MARK: New area

    @ViewBuilder private var checkingBanner: some View {
        if store.checkingNewArea {
            HStack(spacing: 12) {
                ProgressView().tint(BW.ink)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Checking deals near you…").font(.bw(.subheadline, weight: .bold)).foregroundStyle(BW.ink)
                    Text("New area: this takes about 40 seconds. You can keep using Lemora.")
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
"""

def dealsview(s):
    s = sub1(s, "                    header\n                    storeToggle\n",
             "                    header\n                    checkingBanner\n                    storeToggle\n", "banner slot")
    if "// MARK: New area" not in s:
        s = sub1(s, "    // MARK: Header\n", BANNER.lstrip("\n") + "\n    // MARK: Header\n", "banner def")
    s = sub1(s, "            .onChange(of: store.deals) { _, _ in ensureVisibleDeals() }\n",
             "            .onChange(of: store.deals) { _, _ in ensureVisibleDeals() }\n"
             "            .animation(.snappy, value: store.checkingNewArea)\n", "banner anim")
    return s

# ---------- AppStore ----------
def appstore(s):
    s = sub1(s, "        let source = availableDeals.isEmpty ? SampleDealProvider.deals(now: now) : availableDeals\n",
             "        let source = availableDeals\n", "preview sample")
    s = sub1(s, "        if availableDeals.isEmpty && !liveDealsLoaded {\n            availableDeals = SampleDealProvider.deals(now: now)\n        }\n",
             "", "refresh sample")
    if "dealLoadID += 1" not in s:
        m = re.search(r"((?:    ///[^\n]*\n)*)    func loadLiveDeals\(\) async \{\n.*?\n    \}\n", s, re.S)
        if not m:
            sys.exit("loadLiveDeals not found")
        s = s[:m.start()] + LOAD + s[m.end():]
    if "var checkingNewArea" not in s:
      s = sub1(s, "    private(set) var liveDealsLoaded = false\n",
             "    private(set) var liveDealsLoaded = false\n"
             "    /// True while deals for a new area are being fetched (first visit of an area: ~40 s).\n"
             "    private(set) var checkingNewArea = false\n"
             "    private var dealLoadID = 0\n", "checking flag")
    s = sub1(s, "    func enableTesterBypass() {\n        testerBypass = true\n",
             "    func enableTesterBypass() {\n        guard SubscriptionService.isTestFlight else { return }\n        testerBypass = true\n", "bypass")
    s = sub1(s, "    var isPremium: Bool { subscription.hasActiveSubscription || testerBypass }",
             "    var isPremium: Bool { subscription.hasActiveSubscription || (testerBypass && SubscriptionService.isTestFlight) }", "premium")
    return s

edit("ViewModels/AppStore.swift", appstore)

# ---------- StorePricesCard ----------
def card(s):
    if "if !allRows.isEmpty {" in s:
        return s
    s = sub1(s, "    private var rows: [Row] {\n        let servings = Double(max(recipe.servings, 1))\n        let now = Date()\n        return prices.map { storeId, regular -> Row in",
             "    /// Store shelf prices exist for Quebec. Elsewhere, rows are the nearby stores with deals this week.\n"
             "    private var inQuebec: Bool {\n"
             "        let location = store.data.profile.location\n"
             "        guard location.isSet else { return true }\n"
             "        return location.countryCode == \"CA\" && \"GHJ\".contains(location.postalCode.uppercased().first ?? \" \")\n"
             "    }\n\n"
             "    private var rows: [Row] {\n        let servings = Double(max(recipe.servings, 1))\n        let now = Date()\n"
             "        let quebec = inQuebec\n"
             "        var base = prices\n"
             "        if !quebec {\n"
             "            let sorted = prices.values.sorted()\n"
             "            let estimate = sorted.isEmpty ? 0 : sorted[sorted.count / 2]\n"
             "            let local = Set(store.deals.filter { $0.validUntil >= now }.map { $0.retailerId.lowercased() })\n"
             "            base = Dictionary(uniqueKeysWithValues: local.map { ($0, estimate) })\n"
             "        }\n"
             "        return base.map { storeId, regular -> Row in", "rows head")
    s = sub1(s, "            return Row(id: storeId, regular: regular, price: max(0, regular - savings / servings), deals: found)\n        }\n        .sorted { $0.price < $1.price }",
             "            return Row(id: storeId, regular: regular, price: max(0, regular - savings / servings), deals: found)\n        }\n"
             "        .filter { quebec || !$0.deals.isEmpty }\n        .sorted { $0.price < $1.price }", "rows tail")
    s = sub1(s, "        let allRows = self.rows\n        VStack(alignment: .leading, spacing: 12) {",
             "        let allRows = self.rows\n        if !allRows.isEmpty {\n        VStack(alignment: .leading, spacing: 12) {", "body head")
    i = s.index("        if !allRows.isEmpty {\n")
    j = s.index("            .bwCard()\n        }\n    }\n}", i)
    s = s[:j] + "            .bwCard()\n        }\n        }\n    }\n}" + s[j + len("            .bwCard()\n        }\n    }\n}"):]
    return s

edit("Data/CatalogIngredientInfo.swift", card)
edit("Views/Deals/DealsView.swift", dealsview)

def appstore2(s):
    s = sub1(s, "        await loadLiveDeals()\n        await loadCurrentPrices()\n        analytics.track(\"app_opened\", [:])",
             "        // Deals load in the background. The launch screen waits at most 3 s for them, never for a new area (~40 s).\n"
             "        let dealsTask = Task { await loadLiveDeals(); await loadCurrentPrices() }\n"
             "        await withTaskGroup(of: Void.self) { group in\n"
             "            group.addTask { await dealsTask.value }\n"
             "            group.addTask { try? await Task.sleep(for: .seconds(3)) }\n"
             "            _ = await group.next()\n"
             "            group.cancelAll()\n"
             "        }\n"
             "        analytics.track(\"app_opened\", [:])", "bootstrap")
    s = sub1(s, "            liveDealsLoaded = true\n            dealLoadError = nil\n",
             "            liveDealsLoaded = true\n            lastDealsLoadAt = .now\n            dealLoadError = nil\n", "last load")
    s = sub1(s, "    private var dealLoadID = 0\n",
             "    private var dealLoadID = 0\n    private var lastDealsLoadAt: Date = .distantPast\n", "last load var")
    s = sub1(s, "    func loadCurrentPrices() async {",
             "    /// Weekly flyers change on different days (Tuesday, Thursday, two-week flyers...). Coming back to the app\n"
             "    /// after an hour reloads deals and prices, so only this week's real offers are ever shown.\n"
             "    func refreshDealsIfStale() async {\n"
             "        guard Date.now.timeIntervalSince(lastDealsLoadAt) > 3600 else { refreshDeals(); return }\n"
             "        await loadLiveDeals()\n"
             "        await loadCurrentPrices()\n"
             "    }\n\n"
             "    func loadCurrentPrices() async {", "refresh if stale")
    return s

def content(s):
    s = sub1(s, "    @Environment(AppStore.self) private var store\n    @State private var showSplash: Bool = true\n",
             "    @Environment(AppStore.self) private var store\n    @Environment(\\.scenePhase) private var scenePhase\n    @State private var showSplash: Bool = true\n", "scene env")
    s = sub1(s, "        .onChange(of: store.subscription.hasActiveSubscription) { _, _ in\n            store.onSubscriptionChanged()\n        }\n",
             "        .onChange(of: store.subscription.hasActiveSubscription) { _, _ in\n            store.onSubscriptionChanged()\n        }\n"
             "        .onChange(of: scenePhase) { _, phase in\n"
             "            if phase == .active, !showSplash { Task { await store.refreshDealsIfStale() } }\n"
             "        }\n", "scene change")
    return s

edit("ViewModels/AppStore.swift", appstore2)
edit("ContentView.swift", content)

# ---------- Where do you shop: manual field only on demand, real city name ----------
def obmodel(s):
    if "import CoreLocation\n" not in s:
        s = sub1(s, "import SwiftUI\nimport ClerkKit\n", "import SwiftUI\nimport ClerkKit\nimport CoreLocation\n", "corelocation")
    if "var cityByPostal" not in s:
      s = sub1(s, "    func allowLocation() {\n",
             "    /// \"Falmouth, KY\" for the code, so people can check they are placed at the right spot.\n"
             "    var cityByPostal: [String: String] = [:]\n"
             "    func placeName(_ loc: ResolvedLocation) -> String { cityByPostal[loc.postal] ?? loc.name }\n"
             "    func lookupCity() async {\n"
             "        guard let loc = currentLocation, cityByPostal[loc.postal] == nil else { return }\n"
             "        let query = \"\\(loc.postal), \\(a.country == \"CA\" ? \"Canada\" : \"United States\")\"\n"
             "        guard let mark = try? await CLGeocoder().geocodeAddressString(query).first else { return }\n"
             "        let parts = [mark.locality ?? mark.subAdministrativeArea, mark.administrativeArea].compactMap { $0 }\n"
             "        if !parts.isEmpty { cityByPostal[loc.postal] = parts.joined(separator: \", \") }\n"
             "    }\n\n"
             "    func allowLocation() {\n", "city lookup")
    return s

def obsteps(s):
    s = sub1(s, "struct OBLocationStep: View {\n    @Environment(OnboardingModel.self) private var m\n",
             "struct OBLocationStep: View {\n    @Environment(OnboardingModel.self) private var m\n"
             "    /// The postal code field only opens after \"Enter manually\" (or when location fails).\n"
             "    @State private var showManual = false\n", "show state")
    s = sub1(s, "                    Text(\"\\(loc.postal) · \\(loc.name)\").font(OB.font(14, 700))",
             "                    Text(\"\\(loc.postal) · \\(m.placeName(loc))\").font(OB.font(14, 700))", "check name")
    s = sub1(s, "            Button { m.allowLocation() } label: {",
             "            Button { showManual = false; m.allowLocation() } label: {", "allow")
    s = sub1(s, "            Button { m.a.locMode = \"manual\" } label: {",
             "            Button { m.a.locMode = \"manual\"; withAnimation(.snappy) { showManual = true } } label: {", "manual btn")
    s = sub1(s, "            if m.a.locMode == \"manual\" {\n                VStack(spacing: 9) {",
             "            if showManual {\n                VStack(spacing: 9) {", "manual panel")
    s = sub1(s, "                    Text(loc.map { \"✓ \" + $0.name } ??",
             "                    Text(loc.map { \"✓ \" + m.placeName($0) } ??", "field name")
    s = sub1(s, "    private var cartChip: some View {\n        Text(\"🛒\")",
             "    private var cartChip: some View {\n        Text(\"🛒\")", "noop")
    # Lifecycle: city lookup, and open the field when location fails.
    s = sub1(s, "                .obIn(duration: 0.3)\n            }\n        }\n    }\n\n    private var cartChip: some View {",
             "                .obIn(duration: 0.3)\n            }\n        }\n"
             "        .task(id: loc?.postal) { await m.lookupCity() }\n"
             "        .onChange(of: m.a.locMode) { _, mode in\n"
             "            if mode == \"manual\" { withAnimation(.snappy) { showManual = true } }\n"
             "        }\n    }\n\n    private var cartChip: some View {", "lifecycle")
    s = sub1(s, "                Text(loc.map { \"\\($0.postal) · \\($0.name)\" } ?? \"No location yet\")",
             "                Text(loc.map { \"\\($0.postal) · \\(m.placeName($0))\" } ?? \"No location yet\")", "stores name")
    return s

edit("Views/Onboarding/OnboardingModel.swift", obmodel)
edit("Views/Onboarding/OnboardingSteps.swift", obsteps)

# ---------- Ask (Zesty): small, fast requests ----------
def zesty(s):
    s = sub1(s, "            appRecipes: recipes.map(ZestyAppRecipeSnapshot.init),",
             "            // The server reads the full recipe catalogue itself: no need to upload every recipe.\n            appRecipes: [],", "no recipe upload")
    s = sub1(s, "        request.httpMethod = \"POST\"\n        request.timeoutInterval = 90\n",
             "        request.httpMethod = \"POST\"\n        request.timeoutInterval = 70\n", "ask timeout")
    return s

edit("Services/ZestyService.swift", zesty)

# ---------- Ask: never spin forever, say why Ask is locked ----------
def askview(s):
    s = sub1(s, "    @State private var allowance: ZestyAllowance?\n",
             "    @State private var allowance: ZestyAllowance?\n    /// Why Ask is unavailable for this account (no subscription, signed out...), shown under the intro.\n    @State private var accessNote: String?\n", "access state")
    s = sub1(s, "            .task { allowance = try? await store.zestyAllowance() }\n",
             "            .task {\n                do { allowance = try await store.zestyAllowance(); accessNote = nil }\n                catch { accessNote = error.localizedDescription }\n            }\n", "allowance task")
    s = sub1(s, "            if messages.isEmpty {\n                VStack(alignment: .leading, spacing: 8) {\n                    ForEach(suggestions",
             "            if let accessNote {\n                Text(accessNote)\n                    .font(.bw(.caption, weight: .semibold))\n                    .foregroundStyle(BW.inkSecondary)\n            }\n"
             "            if messages.isEmpty {\n                VStack(alignment: .leading, spacing: 8) {\n                    ForEach(suggestions", "access note")
    s = sub1(s, "                let response = try await store.ask(query, conversationId: conversationID.isEmpty ? nil : conversationID)\n",
             "                // Zesty always answers or fails within 75 s: never an endless spinner.\n"
             "                let previousID = conversationID.isEmpty ? nil : conversationID\n"
             "                let response = try await withThrowingTaskGroup(of: ZestyAskResponse.self) { group in\n"
             "                    group.addTask { try await store.ask(query, conversationId: previousID) }\n"
             "                    group.addTask {\n"
             "                        try await Task.sleep(for: .seconds(75))\n"
             "                        throw ZestyServiceError.server(message: String(localized: \"Zesty took too long. Please try again.\"))\n"
             "                    }\n"
             "                    guard let first = try await group.next() else { throw ZestyServiceError.invalidResponse }\n"
             "                    group.cancelAll()\n"
             "                    return first\n"
             "                }\n", "ask timeout race")
    return s

edit("Views/Ask/AskView.swift", askview)

# ---------- Haptics (Cal AI style: a light tick on every choice, a firmer tap on big buttons) ----------
def hap_model(s):
    s = sub1(s, "    /// \"Falmouth, KY\" for the code, so people can check they are placed at the right spot.\n",
             "    /// Changes whenever the person picks or unpicks an option (not while typing or dragging a slider):\n"
             "    /// drives the light selection haptic in onboarding and in the Profile editors.\n"
             "    var hapticKey: Int {\n"
             "        var h = Hasher()\n"
             "        h.combine(a.referral); h.combine(a.goal); h.combine(a.goals); h.combine(a.household); h.combine(a.unit)\n"
             "        h.combine(a.cuisines); h.combine(a.diets); h.combine(a.allergies); h.combine(a.noAllergy); h.combine(a.dislikes)\n"
             "        h.combine(a.meals); h.combine(a.locMode); h.combine(a.country); h.combine(a.stores); h.combine(a.noBudget)\n"
             "        h.combine(a.strategy); h.combine(a.notif); h.combine(a.plan)\n"
             "        return h.finalize()\n"
             "    }\n\n"
             "    /// \"Falmouth, KY\" for the code, so people can check they are placed at the right spot.\n", "haptic key")
    return s

def hap_onboarding(s):
    s = sub1(s, "        .animation(.easeOut(duration: 0.25), value: model.showMerge)\n        .environment(model)\n",
             "        .animation(.easeOut(duration: 0.25), value: model.showMerge)\n"
             "        .sensoryFeedback(.selection, trigger: model.hapticKey)\n"
             "        .sensoryFeedback(.impact(weight: .light), trigger: model.screen)\n"
             "        .environment(model)\n", "onboarding haptics")
    return s

def hap_profile(s):
    s = sub1(s, "        .toolbar(.hidden, for: .tabBar)\n        .onChange(of: model?.location.state) { _, state in\n",
             "        .toolbar(.hidden, for: .tabBar)\n        .sensoryFeedback(.selection, trigger: model?.hapticKey)\n        .onChange(of: model?.location.state) { _, state in\n", "editor haptics")
    return s

def hap_tabs(s):
    if ".sensoryFeedback(.impact(weight: .medium), trigger: tab)" in s:
        return s
    s = sub1(s, "        .tint(BW.amber)\n    }\n}",
             "        .tint(BW.amber)\n        .sensoryFeedback(.impact(weight: .medium), trigger: tab)\n    }\n}", "tab haptics")
    return s

def hap_press(s):
    s = sub1(s, "            .scaleEffect(configuration.isPressed ? 0.95 : 1)\n            .animation(.spring(response: 0.25, dampingFraction: 0.65), value: configuration.isPressed)\n",
             "            .scaleEffect(configuration.isPressed ? 0.95 : 1)\n            .animation(.spring(response: 0.25, dampingFraction: 0.65), value: configuration.isPressed)\n"
             "            .sensoryFeedback(.impact(flexibility: .soft, intensity: 0.55), trigger: configuration.isPressed) { old, new in !old && new }\n", "press haptic")
    return s

def hap_obpress(s):
    s = sub1(s, "            .scaleEffect(configuration.isPressed ? 0.97 : 1)\n            .animation(.spring(response: 0.22, dampingFraction: 0.7), value: configuration.isPressed)\n",
             "            .scaleEffect(configuration.isPressed ? 0.97 : 1)\n            .animation(.spring(response: 0.22, dampingFraction: 0.7), value: configuration.isPressed)\n"
             "            .sensoryFeedback(.impact(flexibility: .soft, intensity: 0.5), trigger: configuration.isPressed) { old, new in !old && new }\n", "ob press haptic")
    return s

edit("Views/Onboarding/OnboardingModel.swift", hap_model)
edit("Views/Onboarding/LemoraOnboardingView.swift", hap_onboarding)
edit("Views/Profile/ProfileView.swift", hap_profile)
edit("Views/MainTabView.swift", hap_tabs)
edit("Utilities/Theme.swift", hap_press)

# ---------- Apple sign-in fallback, real error text, permission prompts ----------
def auth(s):
    s = sub1(s, "        runAuth(store, provider: .apple) { try await Clerk.shared.auth.signInWithApple() }\n",
             "        runAuth(store, provider: .apple) {\n"
             "            do { return try await Clerk.shared.auth.signInWithApple() }\n"
             "            catch {\n"
             "                if Self.isCancel(error) { throw error }\n"
             "                // Native Sign in with Apple fails when Clerk has no native iOS app set up: use Clerk's web flow instead.\n"
             "                return try await Clerk.shared.auth.signInWithOAuth(provider: .apple)\n"
             "            }\n"
             "        }\n", "apple fallback")
    s = sub1(s, "                if !Self.isCancel(error) {\n                    errorText = \"That didn’t work. Please try again.\"\n                }\n",
             "                if !Self.isCancel(error) {\n                    errorText = \"That didn’t work: \\(Self.message(for: error))\"\n                }\n", "auth error text")
    return s

def loc(s):
    if "import UIKit\n" not in s:
        s = sub1(s, "import Foundation\nimport CoreLocation\n", "import Foundation\nimport CoreLocation\nimport UIKit\n", "uikit")
    s = sub1(s, "        case .denied, .restricted:\n            state = .denied\n        default:\n            manager.requestLocation()\n",
             "        case .denied, .restricted:\n            // iOS only asks once: after a refusal, the button opens Lemora's Settings to turn location on.\n"
             "            state = .denied\n"
             "            if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }\n"
             "        default:\n            manager.requestLocation()\n", "location settings")
    return s

def notif(s):
    s = sub1(s, "            let granted = (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])) ?? false\n",
             "            let center = UNUserNotificationCenter.current()\n"
             "            if await center.notificationSettings().authorizationStatus == .denied,\n"
             "               let url = URL(string: UIApplication.openSettingsURLString) {\n"
             "                // iOS only asks once: after an earlier refusal, open Settings so notifications can be turned on.\n"
             "                _ = await UIApplication.shared.open(url)\n"
             "            }\n"
             "            let granted = (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false\n", "notif settings")
    return s

edit("Views/Onboarding/OnboardingAuth.swift", auth)
edit("Services/LocationService.swift", loc)
edit("Views/Onboarding/OnboardingModel.swift", notif)
# ---------- New postal code: visible loading on every tab, ~1 min estimate, retry until deals arrive ----------
TOAST = """
/// Shown on every tab while deals for a new postal code load (first visit of an area: about 1 minute).
struct NewAreaToast: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        if store.checkingNewArea {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                let elapsed = max(0, context.date.timeIntervalSince(store.checkingStartedAt))
                let left = max(5, Int(60 - elapsed))
                HStack(spacing: 12) {
                    ProgressView().tint(BW.ink)
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Loading deals for your area…").font(.bw(.subheadline, weight: .bold)).foregroundStyle(BW.ink)
                        Text(elapsed < 60 ? "About \\(left) s left · you can keep using Lemora" : "Almost done…")
                            .font(.bw(.caption, weight: .medium)).foregroundStyle(BW.inkSecondary)
                        ProgressView(value: min(elapsed / 60, 0.95)).tint(BW.amber)
                    }
                }
                .padding(14)
                .background(.regularMaterial, in: .rect(cornerRadius: 18))
                .shadow(color: .black.opacity(0.12), radius: 12, y: 4)
                .padding(.horizontal, 16)
            }
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }
}
"""

def newarea_store(s):
    s = sub1(s, "    private(set) var checkingNewArea = false\n",
             "    private(set) var checkingNewArea = false\n"
             "    /// When the current area load started (drives the ~1 min progress shown to the user).\n"
             "    private(set) var checkingStartedAt = Date.now\n", "checking start var")
    s = sub1(s, "        dealLoadID += 1\n        let loadID = dealLoadID\n",
             "        dealLoadID += 1\n        let loadID = dealLoadID\n        checkingStartedAt = .now\n", "checking start set")
    s = sub1(s, "            let fetched = try await SupabaseService.shared.fetchActiveDeals(location: data.profile.location)\n            guard loadID == dealLoadID else { return }\n",
             "            var fetched = try await SupabaseService.shared.fetchActiveDeals(location: data.profile.location)\n"
             "            // A new area can still be loading on the server: check again every 10 s for up to 2 minutes,\n"
             "            // so deals appear by themselves without reopening the app.\n"
             "            var tries = 0\n"
             "            while fetched.isEmpty, data.profile.location.isSet, tries < 12, loadID == dealLoadID, !Task.isCancelled {\n"
             "                tries += 1\n"
             "                checkingNewArea = true\n"
             "                try? await Task.sleep(for: .seconds(10))\n"
             "                guard loadID == dealLoadID else { return }\n"
             "                fetched = (try? await SupabaseService.shared.fetchActiveDeals(location: data.profile.location)) ?? []\n"
             "            }\n"
             "            guard loadID == dealLoadID else { return }\n", "deal retry")
    return s

def newarea_tabs(s):
    s = sub1(s, "struct MainTabView: View {\n    @State private var tab: AppTab = .discover\n",
             "struct MainTabView: View {\n    @Environment(AppStore.self) private var store\n    @State private var tab: AppTab = .discover\n", "tab store")
    s = sub1(s, "        .sensoryFeedback(.impact(weight: .medium), trigger: tab)\n    }\n}",
             "        .sensoryFeedback(.impact(weight: .medium), trigger: tab)\n"
             "        .overlay(alignment: .bottom) {\n"
             "            // The Deals tab has its own banner.\n"
             "            if tab != .deals { NewAreaToast().padding(.bottom, 62) }\n"
             "        }\n"
             "        .animation(.snappy, value: store.checkingNewArea)\n"
             "        .sensoryFeedback(.success, trigger: store.checkingNewArea) { old, new in old && !new }\n"
             "    }\n}\n" + TOAST.rstrip("\n"), "tab toast")
    return s

def newarea_deals(s):
    s = sub1(s, "New area: this takes about 40 seconds. You can keep using Lemora.",
             "New area: this takes about 1 minute. Deals appear by themselves.", "banner text")
    return s

edit("ViewModels/AppStore.swift", newarea_store)
edit("Views/MainTabView.swift", newarea_tabs)
edit("Views/Deals/DealsView.swift", newarea_deals)
# ---------- Ask: never show the message count (limits stay on the server); photos on Lemora recipe cards ----------
def ask_private(s):
    s = sub1(s, """            if let allowance {
                Text(allowance.phase == "trial"
                     ? "\\(allowance.remaining) of \\(allowance.total) Zesty Ask messages remaining in your trial"
                     : "\\(allowance.remaining) of \\(allowance.total) Zesty Ask messages remaining")
                    .font(.bw(.caption, weight: .semibold))
                    .foregroundStyle(BW.inkSecondary)
            }
""", """            // The message allowance is enforced by the server and never shown as a number.
            if let allowance, allowance.remaining <= 0 {
                Text("You've reached your Zesty Ask limit for now. It comes back soon.")
                    .font(.bw(.caption, weight: .semibold))
                    .foregroundStyle(BW.inkSecondary)
            }
""", "hide ask count")
    s = sub1(s, """    private func recommendationContent(_ item: ZestyRecommendation) -> some View {
        VStack(alignment: .leading, spacing: 7) {
""", """    private func recommendationContent(_ item: ZestyRecommendation) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            // Recipes from the Lemora catalogue show their photo; recipes Zesty creates have none.
            if let id = item.recipeId, let recipe = store.recipes.first(where: { $0.id == id }) {
                FoodImage(name: recipe.imageName, height: 150, radius: 14)
                    .padding(.bottom, 2)
            }
""", "ask recipe photo")
    return s

edit("Views/Ask/AskView.swift", ask_private)
# ---------- In-app language: English, Français, Español (onboarding first page + Profile), without iOS Settings ----------
LANG_SWIFT = '''import SwiftUI
import ObjectiveC

/// In-app language, independent of the iPhone language. Changing it rebuilds the app UI right away.
enum AppLanguage: String, CaseIterable, Identifiable, Sendable {
    case en, fr, es

    var id: String { rawValue }
    var nativeName: String {
        switch self {
        case .en: "English"
        case .fr: "Français"
        case .es: "Español"
        }
    }
    var flag: String {
        switch self {
        case .en: "🇺🇸"
        case .fr: "🇨🇦"
        case .es: "🇲🇽"
        }
    }
    var locale: Locale {
        let region = Locale.current.region?.identifier ?? "CA"
        return Locale(identifier: "\\(rawValue)_\\(region)")
    }

    private static let key = "lemoraAppLanguage"

    nonisolated static var current: AppLanguage {
        if let saved = UserDefaults.standard.string(forKey: key), let language = AppLanguage(rawValue: saved) { return language }
        let system = String((Locale.preferredLanguages.first ?? "en").prefix(2))
        return AppLanguage(rawValue: system) ?? .en
    }

    static func set(_ language: AppLanguage) {
        UserDefaults.standard.set(language.rawValue, forKey: key)
        // Also used by iOS on the next launch (system texts, date formats).
        UserDefaults.standard.set([language.rawValue], forKey: "AppleLanguages")
        LanguageBundle.install(language)
        LanguageState.shared.current = language
    }

    static func bootstrap() { LanguageBundle.install(current) }
}

@Observable final class LanguageState {
    static let shared = LanguageState()
    var current: AppLanguage = AppLanguage.current
}

/// Looks up app texts in the chosen language's table instead of the iPhone language.
nonisolated final class LanguageBundle: Bundle {
    nonisolated(unsafe) private static var target: Bundle?
    nonisolated(unsafe) private static var english = false
    private static let swap: Void = { _ = object_setClass(Bundle.main, LanguageBundle.self) }()

    static func install(_ language: AppLanguage) {
        _ = swap
        english = language == .en
        target = Bundle.main.path(forResource: language.rawValue, ofType: "lproj").flatMap { Bundle(path: $0) }
    }

    override func localizedString(forKey key: String, value: String?, table tableName: String?) -> String {
        if tableName == nil || tableName == "Localizable" {
            if let target = Self.target { return target.localizedString(forKey: key, value: value, table: tableName) }
            if Self.english { return (value?.isEmpty == false ? value! : key) }
        }
        return super.localizedString(forKey: key, value: value, table: tableName)
    }
}

/// A plain text shown in the UI, in the in-app language when a translation exists.
nonisolated func lemoraLocalized(_ text: String) -> String {
    Bundle.main.localizedString(forKey: text, value: text, table: nil)
}

/// Compact language menu (onboarding first page).
struct LanguageMenu: View {
    var body: some View {
        Menu {
            ForEach(AppLanguage.allCases) { language in
                Button {
                    AppLanguage.set(language)
                } label: {
                    if language == LanguageState.shared.current {
                        Label(language.nativeName, systemImage: "checkmark")
                    } else {
                        Text(verbatim: language.nativeName)
                    }
                }
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "globe")
                Text(verbatim: LanguageState.shared.current.rawValue.uppercased())
            }
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(.black.opacity(0.75))
            .padding(.horizontal, 11)
            .padding(.vertical, 7)
            .background(.white.opacity(0.85), in: Capsule())
        }
        .accessibilityLabel(Text(verbatim: "Language / Langue / Idioma"))
    }
}
'''

TR_B64 = "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"

def write_language_files():
    import gzip, base64, json
    p = ROOT / "Utilities/AppLanguage.swift"
    if not p.exists() or p.read_text() != LANG_SWIFT:
        p.write_text(LANG_SWIFT); print("wrote Utilities/AppLanguage.swift")
    m = json.loads(gzip.decompress(base64.b64decode(TR_B64)).decode())
    cat = {"sourceLanguage": "en", "version": "1.0", "strings": {
        k: {"extractionState": "manual", "localizations": {
            "fr": {"stringUnit": {"state": "translated", "value": v[0]}},
            "es": {"stringUnit": {"state": "translated", "value": v[1]}}}} for k, v in sorted(m.items())}}
    out = json.dumps(cat, ensure_ascii=False, indent=2) + "\n"
    c = ROOT / "Localizable.xcstrings"
    if not c.exists() or c.read_text() != out:
        c.write_text(out); print("wrote Localizable.xcstrings", len(m))

write_language_files()

def lang_project(s):
    return sub1(s, "\t\t\tknownRegions = (\n\t\t\t\ten,\n\t\t\t\tBase,\n\t\t\t);\n",
                "\t\t\tknownRegions = (\n\t\t\t\ten,\n\t\t\t\tBase,\n\t\t\t\tfr,\n\t\t\t\tes,\n\t\t\t);\n", "regions")

def lang_app(s):
    s = sub1(s, "    init() {\n        LemoraFont.registerAll()\n",
             "    init() {\n        AppLanguage.bootstrap()\n        LemoraFont.registerAll()\n", "lang bootstrap")
    s = sub1(s, "            ContentView()\n                .environment(store)\n",
             "            ContentView()\n"
             "                // In-app language: the whole UI is rebuilt when it changes.\n"
             "                .environment(\\.locale, LanguageState.shared.current.locale)\n"
             "                .id(LanguageState.shared.current)\n"
             "                .environment(store)\n", "lang root")
    return s

def lang_landing(s):
    return sub1(s, "        VStack(spacing: 0) {\n            LemoraWordmark(size: 26, color: OB.ink)\n            Spacer(minLength: 0)\n",
                "        VStack(spacing: 0) {\n"
                "            LemoraWordmark(size: 26, color: OB.ink)\n"
                "                .frame(maxWidth: .infinity)\n"
                "                .overlay(alignment: .trailing) { LanguageMenu() }\n"
                "            Spacer(minLength: 0)\n", "landing language")

def lang_profile(s):
    return sub1(s, "                    Button {\n                        if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }\n                    } label: {\n                        row(\"character.bubble\", String(localized: \"Language\"), Locale.current.localizedString(forLanguageCode: Locale.current.language.languageCode?.identifier ?? \"en\") ?? \"English\")\n                    }\n",
                "                    // Changes the app language directly (not the iPhone settings).\n"
                "                    Picker(selection: Binding(get: { LanguageState.shared.current }, set: { AppLanguage.set($0) })) {\n"
                "                        ForEach(AppLanguage.allCases) { language in\n"
                "                            Text(verbatim: \"\\(language.flag) \\(language.nativeName)\").tag(language)\n"
                "                        }\n"
                "                    } label: {\n"
                "                        Label(\"Language\", systemImage: \"character.bubble\")\n"
                "                    }\n"
                "                    .tint(BW.inkSecondary)\n", "profile language")

def lang_recipes(s):
    return sub1(s, "        let useFrench = Locale.current.identifier.lowercased().hasPrefix(\"fr\")\n",
                "        let useFrench = AppLanguage.current == .fr\n", "recipe language")

def lang_zesty(s):
    return sub1(s, "            locale: Locale.current.language.languageCode?.identifier ?? \"en\",\n",
                "            locale: AppLanguage.current.rawValue,\n", "ask language")

p = ROOT.parent / "Lemora.xcodeproj/project.pbxproj"
_s = p.read_text(); _o = lang_project(_s)
if _o != _s: p.write_text(_o); print("edited project.pbxproj")
edit("LemoraApp.swift", lang_app)
edit("Views/Onboarding/OnboardingSteps.swift", lang_landing)
edit("Views/Profile/ProfileView.swift", lang_profile)
edit("Services/SupabaseService.swift", lang_recipes)
edit("Services/ZestyService.swift", lang_zesty)

def lang_obtext(s):
    return sub1(s, "    var body: some View {\n        Text(text)\n            .font(OB.font(size, weight))\n",
                "    var body: some View {\n"
                "        // Onboarding titles arrive as plain Strings, so they are looked up in the chosen language here.\n"
                "        Text(verbatim: lemoraLocalized(text))\n"
                "            .font(OB.font(size, weight))\n", "ob text language")

edit("Views/Onboarding/OnboardingStyle.swift", lang_obtext)

# ---------- Australia: country in onboarding and Profile, 4-digit postcodes, AUD, Woolworths + Coles ----------
def au_location(s):
    s = sub1(s, "    case canada = \"CA\"\n    case unitedStates = \"US\"\n",
             "    case canada = \"CA\"\n    case unitedStates = \"US\"\n    case australia = \"AU\"\n", "au case")
    s = sub1(s, "        case .unitedStates: String(localized: \"United States\")\n        }\n",
             "        case .unitedStates: String(localized: \"United States\")\n        case .australia: String(localized: \"Australia\")\n        }\n", "au title")
    s = sub1(s, "        case .unitedStates: \"🇺🇸\"\n        }\n",
             "        case .unitedStates: \"🇺🇸\"\n        case .australia: \"🇦🇺\"\n        }\n", "au flag")
    s = sub1(s, "        case .unitedStates: \"USD\"\n        }\n",
             "        case .unitedStates: \"USD\"\n        case .australia: \"AUD\"\n        }\n", "au currency")
    s = sub1(s, "        case .unitedStates: String(localized: \"ZIP Code\")\n        }\n",
             "        case .unitedStates: String(localized: \"ZIP Code\")\n        case .australia: String(localized: \"Postcode\")\n        }\n", "au label")
    s = sub1(s, "        case .unitedStates: \"10001\"\n        }\n",
             "        case .unitedStates: \"10001\"\n        case .australia: \"2000\"\n        }\n", "au placeholder")
    s = sub1(s, "            guard digits.count == 5, digits.allSatisfy(\\.isNumber) else { return nil }\n            return String(digits)\n        }\n",
             "            guard digits.count == 5, digits.allSatisfy(\\.isNumber) else { return nil }\n            return String(digits)\n"
             "        case .australia:\n"
             "            guard cleaned.count == 4, cleaned.allSatisfy(\\.isNumber) else { return nil }\n"
             "            return cleaned\n        }\n", "au normalize")
    s = sub1(s, "            return Self.usStateRanges.first { $0.range.contains(prefix) }?.state\n        }\n",
             "            return Self.usStateRanges.first { $0.range.contains(prefix) }?.state\n"
             "        case .australia:\n"
             "            // First digit of an Australian postcode -> state (ACT postcodes are 26xx / 29xx).\n"
             "            if postal.hasPrefix(\"26\") || postal.hasPrefix(\"29\") { return \"ACT\" }\n"
             "            switch postal.first {\n"
             "            case \"0\": return \"NT\"\n            case \"1\", \"2\": return \"NSW\"\n            case \"3\", \"8\": return \"VIC\"\n"
             "            case \"4\", \"9\": return \"QLD\"\n            case \"5\": return \"SA\"\n            case \"6\": return \"WA\"\n            case \"7\": return \"TAS\"\n"
             "            default: return nil\n            }\n        }\n", "au region")
    return s

def au_profile(s):
    return sub1(s, "            self.country = country == .unitedStates ? \"US\" : \"CA\"\n",
                "            self.country = country.code\n", "au profile country")

def au_auth(s):
    return sub1(s, "            var loc = UserLocation.manual(country: a.country == \"US\" ? .unitedStates : .canada, postalCode: a.postal)\n",
                "            var loc = UserLocation.manual(country: SupportedCountry(rawValue: a.country) ?? .canada, postalCode: a.postal)\n", "au auth country")

def au_model(s):
    s = sub1(s, "        if a.country == \"CA\" {\n            ok = pc.count == 6 && pc.enumerated().allSatisfy { i, c in i % 2 == 0 ? c.isLetter && c.isASCII : c.isNumber }\n        } else {\n",
             "        if a.country == \"CA\" {\n            ok = pc.count == 6 && pc.enumerated().allSatisfy { i, c in i % 2 == 0 ? c.isLetter && c.isASCII : c.isNumber }\n"
             "        } else if a.country == \"AU\" {\n            ok = pc.count == 4 && pc.allSatisfy(\\.isNumber)\n        } else {\n", "au postal check")
    s = sub1(s, "        let query = \"\\(loc.postal), \\(a.country == \"CA\" ? \"Canada\" : \"United States\")\"\n",
             "        let query = \"\\(loc.postal), \\(a.country == \"CA\" ? \"Canada\" : a.country == \"AU\" ? \"Australia\" : \"United States\")\"\n", "au geocode")
    s = sub1(s, "        let country = cleaned.first?.isLetter == true ? \"CA\" : \"US\"\n        if country != a.country { a.stores = [] }\n",
             "        let country = cleaned.first?.isLetter == true ? \"CA\" : (cleaned.count == 4 ? \"AU\" : \"US\")\n        if country != a.country { a.stores = [] }\n", "au device postal")
    s = sub1(s, "            let country = first.isNumber ? \"US\" : \"CA\"\n",
             "            // Letters = Canada. Digits keep Australia when it is picked, otherwise the US.\n"
             "            let country = first.isNumber ? (a.country == \"AU\" ? \"AU\" : \"US\") : \"CA\"\n", "au typing")
    s = sub1(s, "    var currency: String { a.country == \"US\" ? \"USD\" : \"CAD\" }\n",
             "    var currency: String { a.country == \"US\" ? \"USD\" : a.country == \"AU\" ? \"AUD\" : \"CAD\" }\n", "au ob currency")
    return s

def au_steps(s):
    s = sub1(s, "                        ForEach([(\"CA\", \"🇨🇦 Canada\"), (\"US\", \"🇺🇸 United States\")], id: \\.0) { c in\n                            Button { m.setCountry(c.0) } label: {\n                                Text(c.1).font(OB.font(13, 700))\n",
             "                        ForEach([(\"CA\", \"🇨🇦 Canada\"), (\"US\", \"🇺🇸 USA\"), (\"AU\", \"🇦🇺 Australia\")], id: \\.0) { c in\n                            Button { m.setCountry(c.0) } label: {\n                                Text(c.1).font(OB.font(13, 700)).lineLimit(1).minimumScaleFactor(0.75)\n", "au pills")
    s = sub1(s, "prompt: Text(m.a.country == \"CA\" ? \"Postal code (e.g. H2T 1P5)\" : \"ZIP code (e.g. 78701)\")",
             "prompt: Text(m.a.country == \"CA\" ? \"Postal code (e.g. H2T 1P5)\" : m.a.country == \"AU\" ? \"Postcode (e.g. 2000)\" : \"ZIP code (e.g. 78701)\")", "au prompt")
    s = sub1(s, "(m.a.postal.isEmpty ? (m.a.country == \"CA\" ? \"Format: A1A 1A1\" : \"5-digit ZIP\")\n                        : m.a.postal.filter { !$0.isWhitespace }.count >= (m.a.country == \"CA\" ? 6 : 5)\n                            ? (m.a.country == \"CA\" ? \"Check the format: letter, number, letter, number, letter, number (A1A 1A1)\" : \"A ZIP code has 5 digits\")",
             "(m.a.postal.isEmpty ? (m.a.country == \"CA\" ? \"Format: A1A 1A1\" : m.a.country == \"AU\" ? \"4-digit postcode\" : \"5-digit ZIP\")\n                        : m.a.postal.filter { !$0.isWhitespace }.count >= (m.a.country == \"CA\" ? 6 : m.a.country == \"AU\" ? 4 : 5)\n                            ? (m.a.country == \"CA\" ? \"Check the format: letter, number, letter, number, letter, number (A1A 1A1)\" : m.a.country == \"AU\" ? \"A postcode has 4 digits\" : \"A ZIP code has 5 digits\")", "au helper")
    return s

def au_data(s):
    s = sub1(s, "            \"ANY\": [\"Walmart\", \"Target\", \"Costco\", \"Kroger\", \"Aldi\", \"Safeway\", \"Publix\", \"Trader Joe’s\", \"Whole Foods\"]\n        ]\n    ]\n",
             "            \"ANY\": [\"Walmart\", \"Target\", \"Costco\", \"Kroger\", \"Aldi\", \"Safeway\", \"Publix\", \"Trader Joe’s\", \"Whole Foods\"]\n        ],\n"
             "        \"AU\": [\n            \"ANY\": [\"Woolworths\", \"Coles\", \"Aldi\", \"IGA\", \"Costco\", \"Harris Farm\"]\n        ]\n    ]\n", "au stores")
    s = sub1(s, "            \"ANY\": [\"Sprouts\", \"Lidl\", \"Grocery Outlet\", \"WinCo\", \"H Mart\", \"99 Ranch\", \"Hy-Vee\", \"Market Basket\"]\n        ]\n    ]\n",
             "            \"ANY\": [\"Sprouts\", \"Lidl\", \"Grocery Outlet\", \"WinCo\", \"H Mart\", \"99 Ranch\", \"Hy-Vee\", \"Market Basket\"]\n        ],\n"
             "        \"AU\": [\n            \"ANY\": [\"FoodWorks\", \"Drakes\", \"Foodland\", \"Romeo’s\", \"Spar\", \"Friendly Grocer\"]\n        ]\n    ]\n", "au more stores")
    s = sub1(s, "        guard let first = c.first else { return country == \"CA\" ? (\"ANY\", \"Canada\") : (\"ANY\", \"United States\") }\n",
             "        guard let first = c.first else { return country == \"CA\" ? (\"ANY\", \"Canada\") : country == \"AU\" ? (\"ANY\", \"Australia\") : (\"ANY\", \"United States\") }\n"
             "        if country == \"AU\" {\n"
             "            let states: [Character: String] = [\"0\": \"Northern Territory\", \"1\": \"New South Wales\", \"2\": \"New South Wales\", \"3\": \"Victoria\", \"4\": \"Queensland\",\n"
             "                                               \"5\": \"South Australia\", \"6\": \"Western Australia\", \"7\": \"Tasmania\", \"8\": \"Victoria\", \"9\": \"Queensland\"]\n"
             "            if c.hasPrefix(\"26\") || c.hasPrefix(\"29\") { return (\"ANY\", \"Canberra\") }\n"
             "            return (\"ANY\", states[first] ?? \"Australia\")\n"
             "        }\n", "au region name")
    s = sub1(s, "        \"Aldi\": (0x00005F, 0xF9B200),\n",
             "        \"Aldi\": (0x00005F, 0xF9B200),\n        \"Woolworths\": (0x178841, 0xFFFFFF),\n        \"Coles\": (0xE01A22, 0xFFFFFF),\n        \"Harris Farm\": (0x1E5631, 0xFFFFFF),\n", "au brands")
    return s

def au_supabase(s):
    s = sub1(s, "        let toCAD = currencyCode.uppercased() == \"USD\" ? 1 / AppCurrency.usd.perCAD : 1\n",
             "        let toCAD = currencyCode.uppercased() == \"USD\" ? 1 / AppCurrency.usd.perCAD\n"
             "            : currencyCode.uppercased() == \"AUD\" ? 1 / AppCurrency.aud.perCAD : 1\n", "au to cad")
    s = sub1(s, "        case \"us\", \"usa\", \"united states\", \"united states of america\", \"états-unis\", \"etats-unis\": return \"US\"\n",
             "        case \"us\", \"usa\", \"united states\", \"united states of america\", \"états-unis\", \"etats-unis\": return \"US\"\n"
             "        case \"au\", \"aus\", \"australia\", \"australie\": return \"AU\"\n", "au country code")
    return s

edit("Models/UserLocation.swift", au_location)
edit("Views/Profile/ProfileView.swift", au_profile)
edit("Views/Onboarding/OnboardingAuth.swift", au_auth)
edit("Views/Onboarding/OnboardingModel.swift", au_model)
edit("Views/Onboarding/OnboardingSteps.swift", au_steps)
edit("Views/Onboarding/OnboardingData.swift", au_data)
edit("Services/SupabaseService.swift", au_supabase)

print("all edits applied")
