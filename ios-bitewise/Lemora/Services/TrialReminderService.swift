import Foundation
import UserNotifications

/// Schedules the real "your trial ends soon" reminder promised on the paywall timeline.
/// The offset is unchanged: about 48 hours before the end when the trial is longer than 3 days,
/// and 1 day before the end for a 3-day trial (`reminderDay`).
nonisolated enum TrialReminderService {
    static let identifier = "lemora.trial.reminder"

    enum Outcome: Sendable {
        case unchanged
        case scheduled
        case cancelled
    }

    struct Snapshot: Sendable {
        var inTrial: Bool
        var willRenew: Bool
        var expiration: Date?
        var trialDays: Int?
        var priceText: String
    }

    /// Reminder is sent 2 days before the trial ends (day 5 of a 7-day trial, day 2 of a 3-day trial).
    static func reminderDay(forTrialDays days: Int) -> Int {
        max(1, days - (days > 3 ? 2 : 1))
    }

    /// Cancels a pending reminder when a trial will not renew, and schedules one when a renewing
    /// trial is active and nothing is already pending (including on the next launch).
    static func reconcile(_ snapshot: Snapshot) async -> Outcome {
        if snapshot.inTrial && !snapshot.willRenew {
            cancel()
            return .cancelled
        }
        guard snapshot.inTrial, snapshot.willRenew,
              let expiration = snapshot.expiration, expiration > Date() else {
            return .unchanged
        }
        if await hasPending() { return .unchanged }
        let days = snapshot.trialDays ?? max(1, Int(ceil(expiration.timeIntervalSinceNow / 86_400)))
        let lead = max(1, days - reminderDay(forTrialDays: days))
        let fire = expiration.addingTimeInterval(-Double(lead) * 86_400)
        let interval = fire.timeIntervalSinceNow
        guard interval > 60 else { return .unchanged }
        let scheduled = await schedule(fireAfter: interval, remainingDays: lead, priceText: snapshot.priceText)
        return scheduled ? .scheduled : .unchanged
    }

    static func cancel() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
    }

    static func hasPending() async -> Bool {
        let pending = await UNUserNotificationCenter.current().pendingNotificationRequests()
        return pending.contains { $0.identifier == identifier }
    }

    private static func schedule(fireAfter interval: TimeInterval, remainingDays: Int, priceText: String) async -> Bool {
        let center = UNUserNotificationCenter.current()
        let granted = (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        guard granted, interval > 1 else { return false }
        let content = UNMutableNotificationContent()
        content.title = String(localized: "Your Lemora free trial ends soon")
        if priceText.isEmpty {
            content.body = String(localized: "Your free trial is ending. After that, the yearly plan starts unless you cancel in Settings.")
        } else if remainingDays == 1 {
            content.body = String(localized: "Your free trial ends tomorrow. After that, \(priceText)/year starts unless you cancel in Settings.")
        } else {
            content.body = String(localized: "Your free trial ends in \(remainingDays) days. After that, \(priceText)/year starts unless you cancel in Settings.")
        }
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        do {
            try await center.add(UNNotificationRequest(identifier: identifier, content: content, trigger: trigger))
            return true
        } catch {
            return false
        }
    }
}
