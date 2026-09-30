import SwiftUI
import AuthenticationServices

/// Sign-in sheet for returning users (from the landing screen).
struct AuthView: View {
    enum Mode: String, Identifiable {
        case signUp, signIn
        var id: String { rawValue }
    }

    let mode: Mode
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    ZestView(pose: .wave, size: 110)
                        .padding(.top, 8)
                    VStack(spacing: 6) {
                        Text(mode == .signUp ? "Create your account" : "Welcome back")
                            .font(.bw(.title, weight: .heavy)).foregroundStyle(BW.ink)
                        Text("Your plan, saves and grocery lists stay with your account.")
                            .font(.bw(.subheadline, weight: .regular)).foregroundStyle(BW.inkSecondary)
                            .multilineTextAlignment(.center)
                    }
                    AccountOptions(mode: mode) { name, email in
                        store.signIn(name: name, email: email)
                        dismiss()
                    }
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
}

/// Onboarding step: save the plan to an account right after the plan summary.
struct AccountStep: View {
    let onComplete: (String, String) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Create your account")
                        .font(.bw(.title, weight: .heavy))
                        .foregroundStyle(BW.ink)
                    Text("Your plan, saves and grocery lists stay with you on every device.")
                        .font(.bw(.subheadline, weight: .regular))
                        .foregroundStyle(BW.inkSecondary)
                }
                AccountOptions(mode: .signUp, onComplete: onComplete)
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
            .padding(.bottom, 24)
        }
        .scrollDismissesKeyboard(.interactively)
    }
}

/// Continue with Apple / Google / Email.
struct AccountOptions: View {
    let mode: AuthView.Mode
    let onComplete: (String, String) -> Void

    @Environment(AuthManager.self) private var auth
    @State private var showEmail: Bool = false
    @State private var name: String = ""
    @State private var email: String = ""
    @State private var errorMessage: String? = nil
    @FocusState private var focused: Bool

    private var emailValid: Bool {
        let parts = email.split(separator: "@")
        return parts.count == 2 && parts[1].contains(".") && email.count >= 5
    }

    var body: some View {
        VStack(spacing: 12) {
            SignInWithAppleButton(mode == .signUp ? .continue : .signIn) { request in
                request.requestedScopes = [.fullName, .email]
            } onCompletion: { result in
                handleApple(result)
            }
            .signInWithAppleButtonStyle(.black)
            .frame(height: 56)
            .clipShape(.capsule)

            Button {
                Task { await google() }
            } label: {
                HStack(spacing: 10) {
                    if auth.isSigningIn {
                        ProgressView().tint(BW.ink)
                    } else {
                        Text(verbatim: "G")
                            .font(.system(size: 19, weight: .heavy))
                            .foregroundStyle(Color(hex: 0x4285F4))
                    }
                    Text("Continue with Google")
                }
            }
            .buttonStyle(BWSecondaryButtonStyle())
            .disabled(auth.isSigningIn)

            if showEmail {
                VStack(spacing: 12) {
                    if mode == .signUp {
                        field("First name", text: $name, content: .givenName)
                    }
                    field("Email", text: $email, content: .emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .submitLabel(.continue)
                        .onSubmit(submitEmail)
                    Button(mode == .signUp ? "Continue" : "Sign In", action: submitEmail)
                        .buttonStyle(BWPrimaryButtonStyle())
                        .disabled(email.isEmpty)
                        .opacity(email.isEmpty ? 0.5 : 1)
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            } else {
                Button {
                    withAnimation(.snappy) { showEmail = true }
                    focused = true
                } label: {
                    Label("Continue with Email", systemImage: "envelope.fill")
                }
                .buttonStyle(BWSecondaryButtonStyle())
            }

            if let message = errorMessage ?? auth.errorMessage {
                Text(message)
                    .font(.bw(.footnote, weight: .medium))
                    .foregroundStyle(BW.danger)
                    .multilineTextAlignment(.center)
            }

            Text("By continuing you agree to the Terms and Privacy Policy. Lemora is not medical advice.")
                .font(.bw(.caption2, weight: .regular))
                .foregroundStyle(BW.inkSecondary)
                .multilineTextAlignment(.center)
                .padding(.top, 6)
        }
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

    private func submitEmail() {
        guard emailValid else {
            errorMessage = String(localized: "Please enter a valid email.")
            return
        }
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        onComplete(trimmed.isEmpty ? String(email.split(separator: "@").first ?? "") : trimmed, email)
    }

    private func google() async {
        errorMessage = nil
        guard let user = await auth.signIn(provider: "google") else { return }
        let fallback = String(user.email.split(separator: "@").first ?? "")
        onComplete(user.name ?? fallback, user.email)
    }

    private func handleApple(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            let credential = authorization.credential as? ASAuthorizationAppleIDCredential
            let given = credential?.fullName?.givenName ?? ""
            onComplete(given.isEmpty ? String(localized: "Friend") : given, credential?.email ?? "")
        case .failure(let error):
            if (error as? ASAuthorizationError)?.code == .canceled { return }
            errorMessage = String(localized: "Sign in with Apple isn't available right now. Try another option.")
        }
    }
}
