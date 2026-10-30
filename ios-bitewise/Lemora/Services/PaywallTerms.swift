import Foundation

/// Everything the paywall says about price and trial, derived from the live StoreKit products.
/// Until those products load, the paywall shows a placeholder instead of a hardcoded price.
/// The free trial is only offered on the yearly plan.
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
    let pricesLoaded: Bool

    /// Trial offered on the yearly plan for this user, if any. Never the monthly plan.
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
        guard annualValue > 0 else { return "…" }
        return (annualValue / 12).formatted(.currency(code: currencyCode).presentation(.narrow).locale(AppLanguage.current.locale))
    }

    var ctaTitle: String {
        guard pricesLoaded else { return String(localized: "Loading prices…") }
        switch trialDays {
        case .some(7): return String(localized: "Start My Free Week")
        case .some(let days): return String(localized: "Start My \(days)-Day Free Trial")
        case .none: return String(localized: "Unlock My Full Plan")
        }
    }

    var footnote: String {
        guard pricesLoaded else { return String(localized: "Prices load from the App Store.") }
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
    static func make(sub: SubscriptionService, annualSelected: Bool) -> PaywallTerms {
        let productTrial = sub.introductoryTrialDays(for: .annual)
        // TestFlight purchases are free tests, so testers see the yearly free-trial design when the
        // product has an intro offer, even on an Apple ID that already used the trial.
        let eligible = sub.isEligibleForTrial || (SubscriptionService.isTestFlight && productTrial != nil)
        let loaded = sub.pricesLoaded
        return PaywallTerms(
            annualPrice: sub.annualPriceText ?? "…",
            annualValue: sub.annualAmount ?? 0,
            monthlyPrice: sub.monthlyPriceText ?? "…",
            monthlyValue: sub.monthlyAmount ?? 0,
            currencyCode: sub.currencyCode ?? "USD",
            currencySuffix: "",
            configuredTrialDays: loaded ? productTrial : nil,
            isEligibleForTrial: eligible,
            annualSelected: annualSelected,
            pricesLoaded: loaded)
    }
}
