import Foundation
import ClerkKit
import OSLog

/// Stores onboarding answers in Supabase (`onboarding_profiles`), keyed by the Clerk user id.
/// Goes through the `onboarding-profile` Edge Function, which verifies the Clerk session token.
enum OnboardingSync {
    private static let endpoint = URL(string: "https://fsucqlqsafoligouzgrl.supabase.co/functions/v1/onboarding-profile")!
    private static let publishableKey = "sb_publishable_2iPvFh4m-T-1oG-s84VOzw_1H4R9T3G"
    private static let logger = Logger(subsystem: "app.lemora", category: "onboarding-sync")

    nonisolated struct Payload: Codable, Sendable {
        var email: String?
        var displayName: String?
        var authState: String
        var answers: OnboardingAnswers
        var regionKey: String?
        var regionName: String?
        var currencyCode: String
        var savingsEstimate: SavingsEstimate
        var onboardingProgress: String

        enum CodingKeys: String, CodingKey {
            case email
            case displayName = "display_name"
            case authState = "auth_state"
            case answers
            case regionKey = "region_key"
            case regionName = "region_name"
            case currencyCode = "currency_code"
            case savingsEstimate = "savings_estimate"
            case onboardingProgress = "onboarding_progress"
        }
    }

    private nonisolated struct FetchResponse: Decodable, Sendable {
        let profile: StoredProfile?
    }

    private nonisolated struct StoredProfile: Decodable, Sendable {
        let answers: OnboardingAnswers?
    }

    private static func request(method: String, body: Data? = nil) async -> URLRequest? {
        guard let token = try? await Clerk.shared.auth.getToken(), !token.isEmpty else { return nil }
        var req = URLRequest(url: endpoint)
        req.httpMethod = method
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue(publishableKey, forHTTPHeaderField: "apikey")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = body
        req.timeoutInterval = 15
        return req
    }

    static func save(_ payload: Payload) async {
        guard let body = try? JSONEncoder().encode(payload),
              let req = await request(method: "POST", body: body) else { return }
        do {
            let (_, response) = try await URLSession.shared.data(for: req)
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            if code >= 300 { logger.error("Onboarding save failed: \(code)") }
        } catch {
            logger.error("Onboarding save error: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// The signed-in user's saved answers, if any.
    static func fetch() async -> OnboardingAnswers? {
        guard let req = await request(method: "GET") else { return nil }
        do {
            let (data, response) = try await URLSession.shared.data(for: req)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }
            return try JSONDecoder().decode(FetchResponse.self, from: data).profile?.answers
        } catch {
            logger.error("Onboarding fetch error: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }
}

