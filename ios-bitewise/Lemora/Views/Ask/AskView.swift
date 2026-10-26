import SwiftUI

struct AskMessage: Identifiable {
    let id = UUID()
    let isUser: Bool
    let text: String
    var recommendations: [ZestyRecommendation] = []
    var followUps: [String] = []
}

struct AskView: View {
    @Environment(AppStore.self) private var store
    @State private var path: NavigationPath = NavigationPath()
    @State private var messages: [AskMessage] = []
    @State private var input: String = ""
    @State private var isThinking: Bool = false
    @State private var allowance: ZestyAllowance?
    /// Why Ask is unavailable for this account (no subscription, signed out...), shown under the intro.
    @State private var accessNote: String?
    @AppStorage("zestyConversationID") private var conversationID: String = ""
    @FocusState private var focused: Bool

    private let suggestions: [String] = [
        "Chicken dinner under $5 with 40g protein",
        "Something spicy using Maxi deals",
        "I have rice, eggs and chicken",
        "How do I change my stores and diet?",
    ]

    var body: some View {
        NavigationStack(path: $path) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 16) {
                        intro
                        ForEach(messages) { message in
                            bubble(message).id(message.id)
                        }
                        if isThinking {
                            HStack(spacing: 8) {
                                ZestyMascot(mood: .thinking, size: 36, seedKey: "ask-thinking")
                                ProgressView().tint(BW.inkSecondary)
                            }
                            .id("thinking")
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                }
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: messages.count) { _, _ in
                    withAnimation { proxy.scrollTo(messages.last?.id, anchor: .top) }
                }
            }
            .background(BW.canvas)
            .navigationTitle("Ask")
            .safeAreaInset(edge: .bottom) { composer }
            .bitewiseDestinations()
            .analyticsScreen("Ask")
            .task {
                do { allowance = try await store.zestyAllowance(); accessNote = nil }
                catch { accessNote = error.localizedDescription }
            }
        }
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 12) {
                ZestyMascot(mood: .talking, size: 70, seedKey: "ask-intro")
                VStack(alignment: .leading, spacing: 4) {
                    Text("Ask Zesty about food & Lemora").font(.bw(.title2)).foregroundStyle(BW.ink)
                    Text("Recipes, deals, nutrition, food and fitness, or how the app works.")
                        .font(.bw(.subheadline, weight: .regular)).foregroundStyle(BW.inkSecondary)
                    Text("Zesty AI · build \(appBuildNumber)")
                        .font(.bw(.caption2, weight: .semibold))
                        .foregroundStyle(BW.inkSecondary)
                }
            }
            // The message allowance is enforced by the server and never shown as a number.
            if let allowance, allowance.remaining <= 0 {
                Text("You've reached your Zesty Ask limit for now. It comes back soon.")
                    .font(.bw(.caption, weight: .semibold))
                    .foregroundStyle(BW.inkSecondary)
            }
            if let accessNote {
                Text(accessNote)
                    .font(.bw(.caption, weight: .semibold))
                    .foregroundStyle(BW.inkSecondary)
            }
            if messages.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(suggestions, id: \.self) { s in
                        Button { send(s) } label: {
                            HStack {
                                Text(s).font(.bw(.subheadline, weight: .semibold)).multilineTextAlignment(.leading)
                                Spacer()
                                Image(systemName: "arrow.up.right").font(.caption.weight(.bold))
                            }
                            .foregroundStyle(BW.ink)
                            .padding(.horizontal, 16)
                            .frame(minHeight: 50)
                            .background(BW.card, in: .rect(cornerRadius: 16))
                            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(BW.hairline))
                        }
                        .buttonStyle(BWPressableStyle())
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func bubble(_ message: AskMessage) -> some View {
        if message.isUser {
            HStack {
                Spacer(minLength: 50)
                Text(message.text)
                    .font(.bw(.body, weight: .medium))
                    .foregroundStyle(BW.ink)
                    .padding(.horizontal, 16).padding(.vertical, 12)
                    .background(BW.lemon, in: .rect(cornerRadius: 20))
            }
        } else {
            VStack(alignment: .leading, spacing: 10) {
                Text(message.text)
                    .font(.bw(.body, weight: .regular))
                    .foregroundStyle(BW.ink)
                    .padding(.horizontal, 16).padding(.vertical, 12)
                    .background(BW.card, in: .rect(cornerRadius: 20))
                ForEach(message.recommendations) { item in
                    recommendationCard(item)
                }
                if !message.followUps.isEmpty {
                    ScrollView(.horizontal) {
                        HStack(spacing: 8) {
                            ForEach(message.followUps, id: \.self) { suggestion in
                                Button { send(suggestion) } label: {
                                    Text(suggestion)
                                        .font(.bw(.caption, weight: .semibold))
                                        .foregroundStyle(BW.ink)
                                        .padding(.horizontal, 13)
                                        .padding(.vertical, 9)
                                        .background(BW.beigeSoft, in: .capsule)
                                }
                                .buttonStyle(BWPressableStyle())
                                .disabled(isThinking)
                            }
                        }
                    }
                    .scrollIndicators(.hidden)
                }
            }
        }
    }

    @ViewBuilder
    private func recommendationCard(_ item: ZestyRecommendation) -> some View {
        if let id = item.recipeId, store.recipes.contains(where: { $0.id == id }) {
            NavigationLink(value: Route.recipe(id)) {
                recommendationContent(item)
            }
            .buttonStyle(.plain)
            .accessibilityHint(Text("Open recipe"))
        } else {
            recommendationContent(item)
        }
    }

    private func recommendationContent(_ item: ZestyRecommendation) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            // Recipes from the Lemora catalogue show their photo; recipes Zesty creates have none.
            if let id = item.recipeId, let recipe = store.recipes.first(where: { $0.id == id }) {
                FoodImage(name: recipe.imageName, height: 150, radius: 14)
                    .padding(.bottom, 2)
            }
            HStack(alignment: .firstTextBaseline) {
                Text(item.title)
                    .font(.bw(.headline, weight: .bold))
                    .foregroundStyle(BW.ink)
                Spacer(minLength: 8)
                if let cost = item.estimatedCost {
                    Text(cost)
                        .font(.bw(.caption, weight: .bold))
                        .foregroundStyle(BW.leafDeep)
                }
            }
            if let subtitle = item.subtitle {
                Text(subtitle).font(.bw(.subheadline, weight: .regular)).foregroundStyle(BW.inkSecondary)
            }
            if let nutrition = item.nutrition {
                nutritionSummary(nutrition)
            }
            HStack(spacing: 8) {
                if let retailer = item.retailer, !retailer.isEmpty {
                    Label(retailer, systemImage: "cart")
                }
                if let reason = item.reason, !reason.isEmpty {
                    Label(reason, systemImage: "sparkles")
                }
            }
            .font(.bw(.caption, weight: .semibold))
            .foregroundStyle(BW.inkSecondary)
        }
        .padding(14)
        .background(BW.card, in: .rect(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(BW.hairline))
    }

    private func nutritionSummary(_ nutrition: ZestyNutrition) -> some View {
        let values: [(String, Double?, String)] = [
            (String(localized: "Calories"), nutrition.calories, "kcal"),
            (String(localized: "Protein"), nutrition.proteinG, "g"),
            (String(localized: "Carbs"), nutrition.carbsG, "g"),
            (String(localized: "Fibre"), nutrition.fiberG, "g"),
            (String(localized: "Sugars"), nutrition.sugarsG, "g"),
            (String(localized: "Fat"), nutrition.fatG, "g"),
            (String(localized: "Sat. fat"), nutrition.saturatedFatG, "g"),
            (String(localized: "Sodium"), nutrition.sodiumMg, "mg"),
        ]
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 5) {
                Text(String(localized: "Nutrition per serving"))
                    .font(.bw(.caption, weight: .bold))
                Text("· \(nutrition.status.capitalized)")
                    .font(.bw(.caption, weight: .semibold))
                    .foregroundStyle(BW.inkSecondary)
            }
            Text(values.map { label, value, unit in
                "\(label) \(value.map { formattedNutrition($0) + unit } ?? "—")"
            }.joined(separator: "  ·  "))
                .font(.bw(.caption, weight: .regular))
                .foregroundStyle(BW.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
            if let source = nutrition.source, !source.isEmpty {
                Text(source)
                    .font(.bw(.caption2, weight: .regular))
                    .foregroundStyle(BW.inkSecondary)
            }
        }
        .padding(10)
        .background(BW.beigeSoft, in: .rect(cornerRadius: 12))
    }

    private func formattedNutrition(_ value: Double) -> String {
        value.rounded() == value ? String(Int(value)) : String(format: "%.1f", value)
    }

    private var composer: some View {
        VStack(spacing: 6) {
            HStack(spacing: 10) {
                TextField("Ask Zesty about food or Lemora…", text: $input, axis: .vertical)
                    .lineLimit(1...4)
                    .focused($focused)
                    .font(.bw(.body, weight: .medium))
                    .padding(.horizontal, 16).padding(.vertical, 12)
                    .background(BW.card, in: .rect(cornerRadius: 24))
                    .overlay(RoundedRectangle(cornerRadius: 24).strokeBorder(BW.hairline))
                    .submitLabel(.send)
                    .onSubmit { send(input) }
                Button { send(input) } label: {
                    Image(systemName: "arrow.up")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(BW.ink)
                        .frame(width: 48, height: 48)
                        .background(canSend ? BW.lemon : BW.beige, in: .circle)
                }
                .disabled(!canSend)
                .accessibilityLabel("Send")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(BW.canvas)
    }

    private var canSend: Bool {
        !input.trimmingCharacters(in: .whitespaces).isEmpty && !isThinking && (allowance?.remaining ?? 1) > 0
    }

    private var appBuildNumber: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"
    }

    private func send(_ text: String) {
        let query = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty, !isThinking else { return }
        guard (allowance?.remaining ?? 1) > 0 else { return }
        input = ""
        focused = false
        let userMessage = AskMessage(isUser: true, text: query)
        messages.append(userMessage)
        isThinking = true
        Task {
            do {
                // Zesty always answers or fails within 75 s: never an endless spinner.
                let previousID = conversationID.isEmpty ? nil : conversationID
                let response = try await withThrowingTaskGroup(of: ZestyAskResponse.self) { group in
                    group.addTask { try await store.ask(query, conversationId: previousID) }
                    group.addTask {
                        try await Task.sleep(for: .seconds(75))
                        throw ZestyServiceError.server(message: String(localized: "Zesty took too long. Please try again."))
                    }
                    guard let first = try await group.next() else { throw ZestyServiceError.invalidResponse }
                    group.cancelAll()
                    return first
                }
                conversationID = response.conversationId
                if let remaining = response.remaining,
                   let total = response.allowanceTotal,
                   let phase = response.accessPhase {
                    allowance = ZestyAllowance(phase: phase, remaining: remaining, total: total)
                }
                withAnimation(.spring(response: 0.4)) {
                    messages.append(AskMessage(
                        isUser: false,
                        text: response.message,
                        recommendations: response.recommendations,
                        followUps: response.followUpSuggestions
                    ))
                    isThinking = false
                }
            } catch {
                allowance = try? await store.zestyAllowance()
                withAnimation(.spring(response: 0.4)) {
                    messages.removeAll { $0.id == userMessage.id }
                    input = query
                    messages.append(AskMessage(
                        isUser: false,
                        text: error.localizedDescription
                    ))
                    isThinking = false
                }
            }
        }
    }
}
