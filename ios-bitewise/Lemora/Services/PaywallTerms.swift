import Foundation
import StoreKit

/// Everything the paywall says about price and trial, derived from the live StoreKit products
/// (or remote-config fallbacks before they load). Never invents dates or billing behaviour.
nonisolated struct PaywallTerms: Sendable {
    let annualPrice: String
    let annualValue: Double
    let monthlyPrice: String
    let monthlyValue: Double
    let currencyCode: String
    /// Appended in running text when the price string doesn't already carry the currency.
    let currencySuffix: String
    let configuredTrialDays: Int?
    let isEligibleForTrial: Bool
    let annualSelected: Bool

    /// Trial offered on the yearly plan for this user, if any.
    var annualTrialDays: Int? {
        guard isEligibleForTrial, let days = configuredTrialDays, days > 0 else { return nil }
        return days
    }

    /// Trial that applies to the currently selected plan.
    var trialDays: Int? { annualSelected ? annualTrialDays : nil }

    var reminderDay: Int? { trialDays.map(TrialReminderService.reminderDay) }

    var savingsPercent: Int? {
        guard monthlyValue > 0, annualValue > 0 else { return nil }
        let percent = Int(((1 - annualValue / (monthlyValue * 12)) * 100).rounded())
        return percent > 0 ? percent : nil
    }

    var annualPerMonth: String {
        (annualValue / 12).formatted(.currency(code: currencyCode).presentation(.narrow))
    }

    var ctaTitle: String {
        switch trialDays {
        case .some(7): String(localized: "Start My Free Week")
        case .some(let days): String(localized: "Start My \(days)-Day Free Trial")
        case .none: String(localized: "Unlock My Full Plan")
        }
    }

    var footnote: String {
        if let days = trialDays {
            return String(localized: "Free for \(days) days, then \(annualPrice)\(currencySuffix)/year. Cancel anytime.")
        }
        return annualSelected
            ? String(localized: "\(annualPrice)\(currencySuffix)/year. Cancel anytime.")
            : String(localized: "\(monthlyPrice)\(currencySuffix)/month. Cancel anytime.")
    }
}

extension PaywallTerms {
    @MainActor
    static func make(sub: SubscriptionService, config: RemoteConfig, annualSelected: Bool) -> PaywallTerms {
        let trial: Int?
        if let annual = sub.annual {
            trial = SubscriptionService.trialDays(of: annual)
        } else {
            trial = config.trialEnabled ? config.trialDays : nil
        }
        let hasProducts = sub.annual != nil
        return PaywallTerms(
            annualPrice: sub.annual?.displayPrice ?? config.annualPriceFallback,
            annualValue: sub.annual.map(SubscriptionService.amount) ?? config.annualPriceValue,
            monthlyPrice: sub.monthly?.displayPrice ?? config.monthlyPriceFallback,
            monthlyValue: sub.monthly.map(SubscriptionService.amount) ?? config.monthlyPriceValue,
            currencyCode: sub.annual?.priceFormatStyle.currencyCode ?? "CAD",
            currencySuffix: hasProducts ? "" : " CAD",
            configuredTrialDays: trial,
            isEligibleForTrial: sub.isEligibleForTrial,
            annualSelected: annualSelected)
    }
}
