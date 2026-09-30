import SwiftUI

struct AskMessage: Identifiable {
    let id = UUID()
    let isUser: Bool
    let text: String
    var results: [ScoredRecipe] = []
}

struct AskView: View {
    @Environment(AppStore.self) private var store
    @State private var path: NavigationPath = NavigationPath()
    @State private var messages: [AskMessage] = []
    @State private var input: String = ""
    @State private var isThinking: Bool = false
    @FocusState private var focused: Bool

    private let suggestions: [String] = [
        "Chicken dinner under $5 with 40g protein",
        "Something spicy using Maxi deals",
        "I have rice, eggs and chicken",
        "Vegetarian dinner under $5 per serving",
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
                                MascotView(name: BWImage.mascotPeek, size: 36)
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
        }
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 12) {
                MascotView(name: BWImage.mascotWave, size: 70, bob: true)
                VStack(alignment: .leading, spacing: 4) {
                    Text("What are you craving?").font(.bw(.title2)).foregroundStyle(BW.ink)
                    Text("I already know your goal, diet, allergies and stores.")
                        .font(.bw(.subheadline, weight: .regular)).foregroundStyle(BW.inkSecondary)
                }
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
                ForEach(message.results) { item in
                    NavigationLink(value: Route.recipe(item.id)) { RecipeRow(item: item) }
                        .buttonStyle(BWPressableStyle())
                }
            }
        }
    }

    private var composer: some View {
        VStack(spacing: 6) {
            if store.askLimitReached {
                Text("You've asked too many questions for today. Come back tomorrow!")
                    .font(.bw(.caption, weight: .semibold)).foregroundStyle(BW.inkSecondary)
                    .multilineTextAlignment(.center)
            }
            HStack(spacing: 10) {
                TextField("Ask for any meal…", text: $input, axis: .vertical)
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
        !input.trimmingCharacters(in: .whitespaces).isEmpty && !isThinking && !store.askLimitReached
    }

    private func send(_ text: String) {
        let query = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty, !isThinking else { return }
        guard !store.askLimitReached else { return }
        input = ""
        focused = false
        messages.append(AskMessage(isUser: true, text: query))
        isThinking = true
        Task {
            try? await Task.sleep(for: .milliseconds(650))
            let response = store.ask(query)
            withAnimation(.spring(response: 0.4)) {
                messages.append(AskMessage(isUser: false, text: response.message, results: response.results))
                isThinking = false
            }
        }
    }
}
