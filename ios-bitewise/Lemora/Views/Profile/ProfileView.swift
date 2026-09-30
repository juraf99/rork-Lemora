import SwiftUI

struct ProfileView: View {
    @Environment(AppStore.self) private var store
    @State private var path: NavigationPath = NavigationPath()
    @State private var showPaywall: Bool = false
    @State private var confirmDelete: Bool = false

    private var profile: UserProfile { store.data.profile }

    var body: some View {
        NavigationStack(path: $path) {
            List {
                Section {
                    header
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                }

                Section {
                    Button { path.append(Route.streaks) } label: { streakRow }
                        .listRowBackground(BW.lemonSoft)
                }

                Section("Subscription") {
                    if store.isPremium {
                        Label("Lemora Premium is active", systemImage: "checkmark.seal.fill").foregroundStyle(BW.leafDeep)
                    } else {
                        Button { showPaywall = true } label: {
                            Label("Upgrade to Premium", systemImage: "sparkles").foregroundStyle(BW.ink).fontWeight(.semibold)
                        }
                    }
                    Button("Restore purchases") { Task { await store.subscription.restore() } }
                    Toggle("Preview Premium (testing)", isOn: Binding(get: { store.data.premiumPreview }, set: { store.setPremiumPreview($0) }))
                        .tint(BW.leaf)
                }

                Section("My Lemora") {
                    NavigationLink { GoalEditView() } label: { row("target", String(localized: "My Goal"), profile.goal.title) }
                    NavigationLink { DietEditView() } label: { row("leaf", String(localized: "Diet"), profile.diets.map(\.title).sorted().joined(separator: ", ")) }
                    NavigationLink { AllergyEditView() } label: { row("allergens", String(localized: "Allergies"), allergyText) }
                    NavigationLink { DislikeEditView() } label: { row("hand.thumbsdown", String(localized: "Foods I Dislike"), profile.dislikes.isEmpty ? String(localized: "None") : profile.dislikes.joined(separator: ", ")) }
                    NavigationLink { CuisineEditView() } label: { row("globe.americas", String(localized: "Cuisines"), profile.cuisines.isEmpty ? String(localized: "Any") : "\(profile.cuisines.count)") }
                    NavigationLink { BudgetEditView() } label: { row("dollarsign.circle", String(localized: "Budget"), profile.weeklyBudget.map { "\(Money.format($0))/wk" } ?? String(localized: "Flexible")) }
                }

                Section("Shopping") {
                    NavigationLink { StoresEditView() } label: { row("storefront", String(localized: "My Stores"), "\(store.myStoreIds.count)") }
                    NavigationLink { StrategyEditView() } label: { row("scalemass", String(localized: "Shopping Strategy"), profile.strategy.title) }
                    NavigationLink { LocationEditView() } label: { row("location", String(localized: "Location"), profile.postalCode.isEmpty ? String(localized: "Not set") : profile.postalCode) }
                }

                Section("App") {
                    Toggle(isOn: Binding(get: { profile.usesMetric }, set: { v in store.updateProfile { $0.usesMetric = v } })) {
                        Label("Metric units", systemImage: "ruler")
                    }
                    .tint(BW.leaf)
                    Button {
                        if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                    } label: {
                        row("character.bubble", String(localized: "Language"), Locale.current.localizedString(forLanguageCode: Locale.current.language.languageCode?.identifier ?? "en") ?? "English")
                    }
                    NavigationLink { NotificationsEditView() } label: { Label("Notifications", systemImage: "bell") }
                    NavigationLink { PrivacyView() } label: { Label("Privacy", systemImage: "hand.raised") }
                }

                Section {
                    Button("Sign Out") { store.signOut() }
                    Button("Delete Account", role: .destructive) { confirmDelete = true }
                }
            }
            .scrollContentBackground(.hidden)
            .background(BW.canvas)
            .foregroundStyle(BW.ink)
            .navigationTitle("Profile")
            .bitewiseDestinations()
            .sheet(isPresented: $showPaywall) { PaywallView(context: .upgrade) { showPaywall = false } }
            .confirmationDialog("Delete your account?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Delete everything", role: .destructive) { store.deleteAccount() }
            } message: {
                Text("This removes your profile, swipes, saves and grocery lists.")
            }
        }
    }

    private var allergyText: String {
        let items = profile.allergies.map(\.title).sorted() + profile.customAllergies
        return items.isEmpty ? String(localized: "None") : items.joined(separator: ", ")
    }

    private var header: some View {
        HStack(spacing: 14) {
            MascotView(name: BWImage.mascotWave, size: 70, bob: true)
            VStack(alignment: .leading, spacing: 3) {
                Text(store.data.account?.name ?? "").font(.bw(.title2)).foregroundStyle(BW.ink)
                if let email = store.data.account?.email, !email.isEmpty {
                    Text(email).font(.bw(.subheadline, weight: .regular)).foregroundStyle(BW.inkSecondary)
                }
                Text("Saved \(Money.format(store.totalSaved)) with Lemora")
                    .font(.bw(.subheadline, weight: .bold)).foregroundStyle(BW.leafDeep)
            }
            Spacer()
        }
        .padding(.vertical, 6)
    }

    private var streakRow: some View {
        HStack(spacing: 14) {
            Image(GrowthStage.forWeeks(store.savingsStreakWeeks).imageName)
                .resizable().scaledToFit().frame(width: 52, height: 52)
            VStack(alignment: .leading, spacing: 2) {
                Text("Streaks").font(.bw(.headline)).foregroundStyle(BW.ink)
                Text("Savings \(store.savingsStreakWeeks) wk · Wise \(store.wiseStreakDays) d")
                    .font(.bw(.subheadline, weight: .medium)).foregroundStyle(BW.inkSecondary)
            }
            Spacer()
            Image(systemName: "chevron.right").font(.subheadline.weight(.bold)).foregroundStyle(BW.outline)
        }
    }

    private func row(_ symbol: String, _ title: String, _ value: String) -> some View {
        HStack {
            Label(title, systemImage: symbol)
            Spacer(minLength: 12)
            Text(value).foregroundStyle(BW.inkSecondary).lineLimit(1)
        }
    }
}

// MARK: - Editors (reuse onboarding steps so everything stays editable)

private struct ProfileEditor<Content: View>: View {
    @Environment(AppStore.self) private var store
    @State private var draft: UserProfile = UserProfile()
    @State private var loaded: Bool = false
    let content: (Binding<UserProfile>) -> Content

    var body: some View {
        content($draft)
            .background(BW.canvas)
            .toolbar(.hidden, for: .tabBar)
            .onAppear {
                if !loaded { draft = store.data.profile; loaded = true }
            }
            .onDisappear {
                store.updateProfile { $0 = draft }
            }
    }
}

struct GoalEditView: View { var body: some View { ProfileEditor { GoalStep(profile: $0) } } }
struct DietEditView: View { var body: some View { ProfileEditor { DietStep(profile: $0) } } }
struct AllergyEditView: View { var body: some View { ProfileEditor { AllergyStep(profile: $0) } } }
struct DislikeEditView: View { var body: some View { ProfileEditor { DislikeStep(profile: $0) } } }
struct CuisineEditView: View { var body: some View { ProfileEditor { CuisineStep(profile: $0) } } }
struct BudgetEditView: View { var body: some View { ProfileEditor { BudgetStep(profile: $0) } } }
struct StoresEditView: View { var body: some View { ProfileEditor { StoresStep(profile: $0) } } }
struct StrategyEditView: View { var body: some View { ProfileEditor { StrategyStep(profile: $0) } } }
struct LocationEditView: View { var body: some View { ProfileEditor { LocationStep(profile: $0) } } }

struct NotificationsEditView: View {
    @Environment(AppStore.self) private var store
    @State private var prefs: NotificationPrefs = NotificationPrefs()

    var body: some View {
        List {
            Section {
                Toggle("Deal alerts", isOn: $prefs.dealAlerts)
                Toggle("Recipe recommendations", isOn: $prefs.recommendations)
                Toggle("Saved recipe price drops", isOn: $prefs.priceDrops)
                Toggle("Weekly Lemora recap", isOn: $prefs.weeklyRecap)
            } footer: {
                Text("We only notify you when something is genuinely worth it. Never just because a flyer updated.")
            }
        }
        .tint(BW.leaf)
        .scrollContentBackground(.hidden)
        .background(BW.canvas)
        .navigationTitle("Notifications")
        .toolbar(.hidden, for: .tabBar)
        .onAppear { prefs = store.data.notifications }
        .onChange(of: prefs) { _, new in store.updateNotifications(new) }
    }
}

struct PrivacyView: View {
    var body: some View {
        List {
            Section("What we use") {
                Text("Location: only when you open the app, to find nearby stores. You can use a postal code instead.")
                Text("Profile & goals: to personalize recipes. Lemora is not medical advice and never promises health outcomes.")
                Text("Usage analytics: anonymous events that help us improve recommendations.")
            }
            Section("Your control") {
                Text("Everything from onboarding can be edited in Profile. Deleting your account removes your data.")
            }
        }
        .font(.bw(.subheadline, weight: .regular))
        .scrollContentBackground(.hidden)
        .background(BW.canvas)
        .navigationTitle("Privacy")
        .toolbar(.hidden, for: .tabBar)
    }
}
