import SwiftUI
import AuthenticationServices

/// Account creation. Sign in with Apple provides the identity; the backend account service
/// (to be connected) becomes the source of truth for cross-device sync.
struct AuthView: View {
    enum Mode: String, Identifiable {
        case signUp, signIn
        var id: String { rawValue }
    }

    let mode: Mode
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var name: String = ""
    @State private var email: String = ""
    @State private var errorMessage: String? = nil
    @FocusState private var focused: Bool

    private var emailValid: Bool {
        email.contains("@") && email.contains(".") && email.count >= 5
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    MascotView(name: BWImage.mascotWave, size: 96, bob: true)
                        .padding(.top, 8)
                    VStack(spacing: 6) {
                        Text(mode == .signUp ? "Create your account" : "Welcome back")
                            .font(.bw(.title)).foregroundStyle(BW.ink)
                        Text("Your taste profile, saves and grocery lists stay with your account.")
                            .font(.bw(.subheadline, weight: .regular)).foregroundStyle(BW.inkSecondary)
                            .multilineTextAlignment(.center)
                    }

                    SignInWithAppleButton(mode == .signUp ? .signUp : .signIn) { request in
                        request.requestedScopes = [.fullName, .email]
                    } onCompletion: { result in
                        handleApple(result)
                    }
                    .signInWithAppleButtonStyle(.black)
                    .frame(height: 54)
                    .clipShape(.capsule)

                    HStack {
                        Rectangle().fill(BW.hairline).frame(height: 1)
                        Text("or with email").font(.bw(.caption, weight: .medium)).foregroundStyle(BW.inkSecondary)
                        Rectangle().fill(BW.hairline).frame(height: 1)
                    }

                    VStack(spacing: 12) {
                        if mode == .signUp {
                            field("First name", text: $name, content: .givenName)
                        }
                        field("Email", text: $email, content: .emailAddress)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                    }

                    if let errorMessage {
                        Text(errorMessage).font(.bw(.footnote, weight: .medium)).foregroundStyle(BW.danger)
                    }

                    Button(mode == .signUp ? "Continue" : "Sign In") {
                        guard emailValid else {
                            errorMessage = String(localized: "Please enter a valid email.")
                            return
                        }
                        complete(name: name.isEmpty ? String(email.split(separator: "@").first ?? "") : name, email: email)
                    }
                    .buttonStyle(BWPrimaryButtonStyle())
                    .disabled(email.isEmpty)
                    .opacity(email.isEmpty ? 0.5 : 1)

                    Text("By continuing you agree to the Terms and Privacy Policy. Bitewise is not medical advice.")
                        .font(.bw(.caption2, weight: .regular)).foregroundStyle(BW.inkSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(24)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(BW.canvas)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close", systemImage: "xmark") { dismiss() }
                }
            }
        }
        .presentationDragIndicator(.visible)
    }

    private func field(_ title: LocalizedStringKey, text: Binding<String>, content: UITextContentType) -> some View {
        TextField(title, text: text)
            .textContentType(content)
            .focused($focused)
            .font(.bw(.body, weight: .medium))
            .padding(.horizontal, 18)
            .frame(height: 54)
            .background(BW.card, in: .capsule)
            .overlay(Capsule().strokeBorder(BW.hairline))
    }

    private func handleApple(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let auth):
            let credential = auth.credential as? ASAuthorizationAppleIDCredential
            let given = credential?.fullName?.givenName ?? ""
            let mail = credential?.email ?? ""
            complete(name: given.isEmpty ? String(localized: "Friend") : given, email: mail)
        case .failure(let error):
            if (error as? ASAuthorizationError)?.code == .canceled { return }
            errorMessage = String(localized: "Sign in with Apple isn't available right now. Try email instead.")
        }
    }

    private func complete(name: String, email: String) {
        store.signIn(name: name, email: email)
        dismiss()
    }
}
