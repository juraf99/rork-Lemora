import SwiftUI
import ClerkKit
import AuthenticationServices

/// Account creation / sign-in through Clerk, then saving answers to Supabase and the local profile.
extension OnboardingModel {
    // MARK: Social + email auth

    func authApple(_ store: AppStore) {
        runAuth(store, provider: .apple) { try await Clerk.shared.auth.signInWithApple() }
    }

    func authGoogle(_ store: AppStore) {
        runAuth(store, provider: .google) { try await Clerk.shared.auth.signInWithOAuth(provider: .google) }
    }

    private func runAuth(_ store: AppStore, provider: AuthProvider, _ op: @escaping () async throws -> TransferFlowResult) {
        guard !busy else { return }
        busy = true
        errorText = nil
        Task { @MainActor in
            do {
                if Clerk.shared.user != nil { try? await Clerk.shared.auth.signOut() }
                let result = try await op()
                var isNew = false
                switch result {
                case .signIn(let s): try await activate(s.createdSessionId)
                case .signUp(let s): isNew = true; try await activate(s.createdSessionId)
                }
                await didAuthenticate(store, provider: provider, isNew: isNew)
            } catch {
                if !Self.isCancel(error) {
                    errorText = "That didn’t work. Please try again."
                }
            }
            busy = false
        }
    }

    func emailSubmit(_ store: AppStore) {
        guard !busy else { return }
        let mail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard mail.contains("@"), mail.contains(".") else { errorText = "Enter a valid email."; return }
        if emailMode == .create && password.count < 8 { errorText = "Use at least 8 characters."; return }
        guard !password.isEmpty else { return }
        busy = true
        errorText = nil
        Task { @MainActor in
            do {
                if Clerk.shared.user != nil { try? await Clerk.shared.auth.signOut() }
                if emailMode == .create {
                    let signUp = try await Clerk.shared.auth.signUp(emailAddress: mail, password: password)
                    pendingSignUpStore = try await signUp.sendEmailCode()
                    code = ""
                    go(.verify)
                } else {
                    let signIn = try await Clerk.shared.auth.signInWithPassword(identifier: mail, password: password)
                    if case .complete = signIn.status {
                        try await activate(signIn.createdSessionId)
                        await didAuthenticate(store, provider: .email, isNew: false)
                    } else {
                        errorText = "This account needs another verification step. Try Google or Apple."
                    }
                }
            } catch {
                errorText = Self.message(for: error)
            }
            busy = false
        }
    }

    func verifyCode(_ store: AppStore) {
        guard !busy, let signUp = pendingSignUpStore, code.count >= 6 else { return }
        busy = true
        errorText = nil
        Task { @MainActor in
            do {
                let result = try await signUp.verifyEmailCode(code)
                if case .complete = result.status {
                    try await activate(result.createdSessionId)
                    await didAuthenticate(store, provider: .email, isNew: true)
                } else {
                    errorText = "Almost there. Please try again."
                }
            } catch {
                errorText = "That code didn’t work. Check your email and try again."
            }
            busy = false
        }
    }

    func resendCode() {
        guard let signUp = pendingSignUpStore else { return }
        Task { @MainActor in
            pendingSignUpStore = (try? await signUp.sendEmailCode()) ?? signUp
            resetSent = true
        }
    }

    /// Password reset runs in Clerk's secure hosted page.
    func forgotPassword(_ store: AppStore) {
        guard !busy else { return }
        busy = true
        Task { @MainActor in
            do {
                try await Clerk.shared.auth.startHostedAuth(mode: .signIn)
                if Clerk.shared.user != nil { await didAuthenticate(store, provider: .email, isNew: false) }
            } catch {
                if !Self.isCancel(error) { resetSent = true }
            }
            busy = false
        }
    }

    private func activate(_ sessionId: String?) async throws {
        if Clerk.shared.user == nil, let sessionId {
            try await Clerk.shared.auth.setActive(sessionId: sessionId)
        }
        guard Clerk.shared.user != nil else { throw CancellationError() }
    }

    static func isCancel(_ error: Error) -> Bool {
        if error is CancellationError { return true }
        if let e = error as? ASAuthorizationError, e.code == .canceled { return true }
        if let e = error as? ASWebAuthenticationSessionError, e.code == .canceledLogin { return true }
        return error.localizedDescription.lowercased().contains("cancel")
    }

    static func message(for error: Error) -> String {
        let text = error.localizedDescription
        return text.isEmpty ? "Something went wrong. Please try again." : text
    }

    // MARK: After authentication

    private func didAuthenticate(_ store: AppStore, provider: AuthProvider, isNew: Bool) async {
        guard let user = Clerk.shared.user else { return }
        let full = [user.firstName, user.lastName].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " ")
        let mail = user.primaryEmailAddress?.emailAddress ?? email
        let fallback = String(mail.split(separator: "@").first ?? "")
        store.applyAccount(name: full.isEmpty ? fallback : full, email: mail, userId: user.id, provider: provider, isNewUser: isNew)
        await store.subscription.logIn(userId: user.id)
        let remote = await OnboardingSync.fetch()

        switch authCtx {
        case .existing:
            if let remote, remote.referral != nil {
                a = remote
                doneMode = "back"
                await upload(store, authState: "existing")
                go(store.isPremium ? .done : .plan)
            } else {
                authCtx = .new
                go(.hear)
            }
        case .new, .merge:
            if let remote, remote.referral != nil, !isNew {
                remoteAnswers = remote
                withAnimation(.easeOut(duration: 0.25)) { showMerge = true }
            } else {
                await upload(store, authState: isNew ? "new" : "existing")
                go(store.isPremium ? .done : .paywall)
            }
        }
    }

    func mergeUpdate(_ store: AppStore) {
        showMerge = false
        Task { @MainActor in
            await upload(store, authState: "existing")
            go(store.isPremium ? .done : .paywall)
        }
    }

    func mergeKeep(_ store: AppStore) {
        if let remote = remoteAnswers { a = remote }
        showMerge = false
        Task { @MainActor in
            await upload(store, authState: "existing")
            go(store.isPremium ? .done : .paywall)
        }
    }

    // MARK: Saving

    func upload(_ store: AppStore, authState: String) async {
        let loc = currentLocation
        let payload = OnboardingSync.Payload(
            email: store.data.account?.email,
            displayName: store.data.account?.name,
            authState: authState,
            answers: a,
            regionKey: loc?.key,
            regionName: loc?.name,
            currencyCode: currency,
            savingsEstimate: estimate,
            onboardingProgress: a.completed ? "completed" : screen.rawValue)
        await OnboardingSync.save(payload)
    }

    /// "Start exploring": saves everything and opens the app.
    func finish(_ store: AppStore) {
        if !paywallOnly || !store.data.onboardingComplete {
            a.completed = true
            store.applyOnboarding(profile: makeProfile(base: store.data.profile), notification: notificationPreference)
        }
        let snapshot = self
        Task { @MainActor in
            await snapshot.upload(store, authState: snapshot.doneMode == "back" ? "existing" : "new")
        }
        Self.clearSaved()
        store.finishPaywall()
    }

    var notificationPreference: NotificationPreference? {
        switch a.notif {
        case "allowed": .granted
        case "denied_system": .denied
        case "declined_primer": .declinedPrimer
        default: nil
        }
    }

    // MARK: Mapping to the app profile

    static let storeIds: [String: String] = [
        "Maxi": "maxi", "Metro": "metro", "Super C": "superc", "IGA": "iga", "Provigo": "provigo", "Walmart": "walmart",
        "Costco": "costco", "Adonis": "adonis", "Mayrand": "mayrand", "Intermarché": "intermarche",
        "Marchés Richelieu": "richelieu", "PA Supermarché": "pa", "Kim Phat": "kimphat", "Rachelle-Béry": "rachelle",
        "Avril": "avril", "Marché Tau": "tau", "Giant Tiger": "tigre", "T&T": "tnt",
    ]

    static func storeId(_ name: String) -> String {
        if let id = storeIds[name] { return id }
        return OBData.norm(name).filter { $0.isLetter || $0.isNumber }
    }

    func makeProfile(base: UserProfile) -> UserProfile {
        var p = base
        let goals: [String: Goal] = ["save_money": .saveMoney, "eat_healthier": .eatHealthier, "lose_weight": .loseWeight,
                                     "build_muscle": .buildMuscle, "gain_weight": .gainWeight, "maintain_weight": .maintain,
                                     "discover_meals": .discover, "meal_prep": .mealPrep]
        p.goal = goals[a.goal] ?? .saveMoney
        p.usesMetric = a.unit == "kg"
        if isBodyGoal {
            p.weightKg = Double(a.current) * 0.4536
            p.goalWeightKg = Double(a.target) * 0.4536
        }
        let cuisines: [String: Cuisine] = ["italian": .italian, "mexican": .mexican, "japanese": .japanese, "korean": .korean,
                                           "indian": .indian, "greek": .greek, "lebanese": .middleEastern, "french": .french,
                                           "thai": .thai, "vietnamese": .vietnamese, "caribbean": .caribbean, "comfort": .american]
        p.cuisines = a.cuisines.contains("all") ? Set(Cuisine.allCases) : Set(a.cuisines.compactMap { cuisines[$0] })
        let diets: [String: DietPreference] = ["none": .everything, "plant_based": .plantBased, "whole_food": .wholeFood,
                                               "mediterranean": .mediterranean, "flexitarian": .flexitarian, "pescatarian": .pescatarian,
                                               "vegetarian": .vegetarian, "vegan": .vegan, "low_carb": .lowCarb, "keto": .keto,
                                               "high_protein": .highProtein, "gluten_free": .glutenFree, "lactose_free": .lactoseFree,
                                               "halal": .halal, "kosher": .kosher]
        p.diets = Set(a.diets.compactMap { diets[$0] })
        p.hasNoAllergies = a.noAllergy
        p.allergyRefs = a.allergies.map { AllergyRef(id: $0 == "tree_nut" ? "tree_nuts" : $0, name: allergenName($0), kind: .allergen) }
        p.dislikedIngredients = a.dislikes.map { IngredientRef(id: $0.id, name: $0.name) }
        p.mealTypes = Set((a.meals ?? []).compactMap { MealType(rawValue: $0) })
        p.weeklyBudget = a.noBudget ? nil : Double(a.budget)
        p.householdSize = a.household
        switch a.strategy {
        case "one": p.strategy = .convenience; p.maxStores = 1
        case "max": p.strategy = .maximumSavings; p.maxStores = 3
        default: p.strategy = .balanced; p.maxStores = 2
        }
        if !a.postal.isEmpty {
            var loc = UserLocation.manual(country: a.country == "US" ? .unitedStates : .canada, postalCode: a.postal)
            if a.locMode == "auto" { loc.source = .device }
            p.location = loc
        }
        p.storePreferences = Dictionary(a.stores.map { (Self.storeId($0), StorePreference.preferred) }, uniquingKeysWith: { x, _ in x })
        p.shopsAtCostco = a.stores.contains("Costco")
        let refs: [String: ReferralSource] = ["tiktok": .tiktok, "instagram": .instagram, "youtube": .youtube, "facebook": .facebook,
                                              "google": .google, "app_store": .appStore, "friends_family": .friends, "other": .other]
        p.referralSource = a.referral.flatMap { refs[$0] }
        return p
    }
}

extension AppStore {
    func applyAccount(name: String, email: String, userId: String, provider: AuthProvider, isNewUser: Bool) {
        mutate {
            $0.account = Account(name: name, email: email, createdAt: $0.account?.createdAt ?? .now,
                                 userId: userId, provider: provider, isNewUser: isNewUser)
        }
        markActive()
        track(isNewUser ? "account_created" : "account_signed_in", ["provider": provider.rawValue])
    }

    func applyOnboarding(profile: UserProfile, notification: NotificationPreference?) {
        mutate {
            $0.profile = profile
            $0.onboardingComplete = true
            $0.welcomeSeen = true
            if let notification { $0.notificationPreference = notification }
        }
        Task { await loadLiveDeals() }
        track("onboarding_completed", ["goal": profile.goal.rawValue])
    }
}
