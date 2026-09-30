import SwiftUI
import AuthenticationServices
import ClerkKit

/// Account sign-in through Clerk (hosted authentication: Google, email, etc.).
@Observable
final class AuthManager {
    nonisolated struct User: Codable, Sendable {
        let id: String
        let email: String
        let name: String?
        let picture: String?
    }

    private(set) var isSigningIn = false
    var errorMessage: String? = nil

    /// Opens Clerk's hosted sign-in / sign-up page and returns the signed-in user, or nil if cancelled/failed.
    /// The provider argument is kept for call-site compatibility; the provider is chosen on the Clerk page.
    func signIn(provider: String = "google", signUp: Bool = false) async -> User? {
        isSigningIn = true
        errorMessage = nil
        defer { isSigningIn = false }
        do {
            if Clerk.shared.user != nil {
                try? await Clerk.shared.auth.signOut()
            }
            try await Clerk.shared.auth.startHostedAuth(mode: signUp ? .signUp : .signIn)
            guard let user = Clerk.shared.user else { return nil }
            let email = user.primaryEmailAddress?.emailAddress ?? ""
            let full = [user.firstName, user.lastName]
                .compactMap { $0 }
                .filter { !$0.isEmpty }
                .joined(separator: " ")
            return User(id: user.id, email: email, name: full.isEmpty ? nil : full, picture: user.imageUrl)
        } catch {
            if (error as? ASWebAuthenticationSessionError)?.code == .canceledLogin { return nil }
            errorMessage = String(localized: "Sign in isn't available right now. Please try again.")
            return nil
        }
    }

    func signOut() async {
        try? await Clerk.shared.auth.signOut()
    }
}
