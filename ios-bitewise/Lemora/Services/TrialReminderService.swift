import Foundation
import UserNotifications

/// Schedules the real "your trial ends soon" reminder promised on the paywall timeline.
nonisolated enum TrialReminderService {
    static let identifier = "lemora.trial.reminder"

    /// Reminder is sent 2 days before the trial ends (day 5 of a 7-day trial).
    static func reminderDay(forTrialDays days: Int) -> Int {
        max(1, days - (days > 3 ? 2 : 1))
    }

    static func schedule(trialDays: Int, priceText: String) async {
        let center = UNUserNotificationCenter.current()
        let granted = (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        guard granted else { return }
        let day = reminderDay(forTrialDays: trialDays)
        let remaining = trialDays - day
        let content = UNMutableNotificationContent()
        content.title = String(localized: "Your Lemora free trial ends soon")
        content.body = remaining == 1
            ? String(localized: "Your free trial ends tomorrow. After that, \(priceText)/year starts unless you cancel in Settings.")
            : String(localized: "Your free trial ends in \(remaining) days. After that, \(priceText)/year starts unless you cancel in Settings.")
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: Double(day) * 86_400, repeats: false)
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        try? await center.add(UNNotificationRequest(identifier: identifier, content: content, trigger: trigger))
    }
}
