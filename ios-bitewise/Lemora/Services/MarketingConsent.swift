import Foundation
import ClerkKit
import OSLog

/// Marketing opt-in. The address is sent to Resend only after the person agrees, through the
/// `marketing-consent` Edge Function. The Resend key stays on the server.
enum MarketingConsent {
    private static let endpoint = URL(string: "https://fsucqlqsafoligouzgrl.supabase.co/functions/v1/marketing-consent")!
    private static let publishableKey = "sb_publishable_2iPvFh4m-T-1oG-s84VOzw_1H4R9T3G"
    private static let keyPrefix = "lemora.marketingConsent."
    private static let logger = Logger(subsystem: "app.lemora", category: "marketing")

    static func isOn(email: String) -> Bool {
        let key = storageKey(email)
        guard !key.isEmpty else { return false }
        return UserDefaults.standard.bool(forKey: key)
    }

    /// Returns true when Resend accepted the choice. The local toggle follows that answer.
    static func set(email: String, name: String, consent: Bool) async -> Bool {
        let address = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard address.contains("@"), address.count <= 320 else { return false }
        guard let token = try? await Clerk.shared.auth.getToken(), !token.isEmpty else { return false }
        var body: [String: String] = ["email": address, "consent": consent ? "true" : "false"]
        let first = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if !first.isEmpty { body["first_name"] = String(first.prefix(80)) }
        guard let data = try? JSONSerialization.data(withJSONObject: body) else { return false }
        var req = URLRequest(url: endpoint)
        req.httpMethod = "POST"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue(publishableKey, forHTTPHeaderField: "apikey")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = data
        req.timeoutInterval = 15
        do {
            let (_, response) = try await URLSession.shared.data(for: req)
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            guard (200..<300).contains(code) else {
                logger.error("Marketing consent failed: \(code)")
                return false
            }
            UserDefaults.standard.set(consent, forKey: storageKey(address))
            return true
        } catch {
            logger.error("Marketing consent error")
            return false
        }
    }

    private static func storageKey(_ email: String) -> String {
        let address = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !address.isEmpty else { return "" }
        return keyPrefix + address
    }
}
