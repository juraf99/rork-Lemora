import SwiftUI
import AuthenticationServices
import CryptoKit
import OSLog

/// Rork Auth (OAuth) for "Continue with Google". Apple sign-in uses the native credential flow.
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

    private let authURL = Config.EXPO_PUBLIC_RORK_AUTH_URL
    private let appKey = Config.EXPO_PUBLIC_RORK_APP_KEY
    private let projectID = Config.EXPO_PUBLIC_PROJECT_ID
    private var codeVerifier: String?
    private var webAuthSession: ASWebAuthenticationSession?
    private let logger = Logger(subsystem: "app.lemora", category: "auth")

    private var developerHint: String? { UserDefaults.standard.string(forKey: "RORK_DEVELOPER_HINT") }

    private var authEnv: String {
        #if targetEnvironment(simulator)
        "simulator"
        #else
        "native"
        #endif
    }

    /// Runs the OAuth flow and returns the signed-in user, or nil if cancelled/failed.
    func signIn(provider: String) async -> User? {
        isSigningIn = true
        errorMessage = nil
        defer { isSigningIn = false }
        do {
            let verifier = Self.makeVerifier()
            codeVerifier = verifier
            guard let url = URL(string: "\(authURL)/oauth/initiate") else { throw AuthError.invalidURL }
            var body: [String: String] = [
                "app_key": appKey, "provider": provider, "code_challenge": Self.challenge(for: verifier),
                "target": "swift", "env": authEnv,
            ]
            if authEnv == "simulator", let hint = developerHint { body["developer_hint"] = hint }
            let data = try await post(url, body)
            let initiate = try JSONDecoder().decode(InitiateResponse.self, from: data)

            let code: String
            if initiate.flow == "popup" {
                do { code = try await pollForCode(state: initiate.state) }
                catch AuthError.cancelledByUser { code = try await runWebAuthSession(initiate.auth_url) }
            } else {
                code = try await runWebAuthSession(initiate.auth_url)
            }
            return try await exchange(code)
        } catch let error as ASWebAuthenticationSessionError where error.code == .canceledLogin {
            return nil
        } catch {
            logger.error("OAuth sign-in failed")
            errorMessage = String(localized: "Couldn't sign in with Google right now. Please try again or use another option.")
            return nil
        }
    }

    func signOut() {
        KeychainHelper.delete("access_token")
        KeychainHelper.delete("refresh_token")
        UserDefaults.standard.removeObject(forKey: "RORK_AUTH_REFRESH_TOKEN")
    }

    private func post(_ url: URL, _ body: [String: String]) async throws -> Data {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)
        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? -1
        guard status == 200 else { throw AuthError.serverError(statusCode: status) }
        return data
    }

    private func pollForCode(state: String) async throws -> String {
        guard let url = URL(string: "\(authURL)/oauth/poll-code") else { throw AuthError.invalidURL }
        let deadline = Date().addingTimeInterval(5 * 60)
        while Date() < deadline {
            try await Task.sleep(for: .milliseconds(1500))
            guard let data = try? await post(url, ["app_key": appKey, "state": state]),
                  let poll = try? JSONDecoder().decode(PollCodeResponse.self, from: data) else { continue }
            if poll.status == "cancelled" { throw AuthError.cancelledByUser }
            if poll.status == "ready", let code = poll.code { return code }
        }
        throw AuthError.popupTimeout
    }

    private func runWebAuthSession(_ urlString: String) async throws -> String {
        let scheme = "rork-\(projectID)"
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<String, Error>) in
            guard let url = URL(string: urlString) else {
                continuation.resume(throwing: AuthError.invalidURL)
                return
            }
            let session = ASWebAuthenticationSession(url: url, callbackURLScheme: scheme) { callbackURL, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let callbackURL,
                      let code = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)?
                        .queryItems?.first(where: { $0.name == "code" })?.value else {
                    continuation.resume(throwing: AuthError.noCode)
                    return
                }
                continuation.resume(returning: code)
            }
            webAuthSession = session
            session.presentationContextProvider = WebAuthPresentationContext.shared
            session.prefersEphemeralWebBrowserSession = false
            session.start()
        }
    }

    private func exchange(_ code: String) async throws -> User {
        guard let verifier = codeVerifier, let url = URL(string: "\(authURL)/oauth/token") else { throw AuthError.invalidURL }
        codeVerifier = nil
        let data = try await post(url, ["app_key": appKey, "code": code, "code_verifier": verifier])
        let token = try JSONDecoder().decode(TokenResponse.self, from: data)
        KeychainHelper.set("access_token", value: token.access_token)
        KeychainHelper.set("refresh_token", value: token.refresh_token)
        return token.user
    }

    private static func makeVerifier() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return base64URL(Data(bytes))
    }

    private static func challenge(for verifier: String) -> String {
        base64URL(Data(SHA256.hash(data: Data(verifier.utf8))))
    }

    private static func base64URL(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

private nonisolated struct InitiateResponse: Codable, Sendable {
    let auth_url: String
    let state: String
    let flow: String?
}

private nonisolated struct PollCodeResponse: Codable, Sendable {
    let status: String
    let code: String?
}

private nonisolated struct TokenResponse: Codable, Sendable {
    let access_token: String
    let refresh_token: String
    let user: AuthManager.User
}

nonisolated enum AuthError: LocalizedError {
    case noCode, invalidURL, popupTimeout, cancelledByUser
    case serverError(statusCode: Int)
}

final class WebAuthPresentationContext: NSObject, ASWebAuthenticationPresentationContextProviding {
    static let shared = WebAuthPresentationContext()

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow } ?? ASPresentationAnchor()
    }
}

nonisolated enum KeychainHelper {
    static func set(_ key: String, value: String) {
        guard let data = value.data(using: .utf8) else { return }
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrAccount as String: key]
        SecItemDelete(query as CFDictionary)
        var add = query
        add[kSecValueData as String] = data
        SecItemAdd(add as CFDictionary, nil)
    }

    static func delete(_ key: String) {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrAccount as String: key]
        SecItemDelete(query as CFDictionary)
    }
}
