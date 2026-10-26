import Foundation
import OSLog
import PostHog
import SwiftUI

/// Public PostHog client settings. The project token is an ingestion key and is safe to ship in the app.
enum PostHogSettings {
    static let apiKey = "phc_CEMRpUvXyQK9CytuMeKuBE742cNZn67Ny8BXAq2u43Wh"
    static let host = "https://us.i.posthog.com"
}

/// Product analytics. Event names and properties live here so call sites stay consistent.
enum Analytics {
    private static let logger = Logger(subsystem: "app.lemora", category: "analytics")

    enum Event {
        case onboardingStepViewed(step: String)
        case onboardingCompleted(goal: String)
        case onboardingStarted
        case planBuildStarted
        case signUp(method: String)
        case login(method: String)
        case accountCreated
        case welcomeCompleted
        case locationStoreSetupCompleted(method: String, storeCount: Int, context: String)
        case dealViewed(dealId: String)
        case recipeViewed(recipeId: String)
        case recipeSaved(recipeId: String)
        case allStoresEnabled
        case worthItOpened
        case stealsOpened
        case smartSwapShown(recipeId: String, count: Int)
        case cookTonight(recipeId: String)
        case streakOpened(days: Int)
        case currencyChanged(currency: String)
        case shoppingListItemAdded(source: String, recipeId: String?, dealId: String?, lineCount: Int)
        case shoppingListItemRemoved(ingredientId: String)
        case zestyQuestionAsked(isFollowUp: Bool)
        case paywallViewed(context: String)
        case trialStarted(productId: String, isSandbox: Bool)
        case subscriptionPurchased(productId: String, isSandbox: Bool)
        case subscriptionPlanChanged(fromProductId: String?, toProductId: String, isSandbox: Bool)
        case restorePurchases(productId: String?, isTrial: Bool, isSandbox: Bool)
        case recipeCatalogueLoadFailed
        case liveDealsLoadFailed
        case currentPricesLoadFailed

        var name: String {
            switch self {
            case .onboardingStepViewed: "onboarding_step_viewed"
            case .onboardingCompleted: "onboarding_completed"
            case .onboardingStarted: "onboarding_started"
            case .planBuildStarted: "plan_build_started"
            case .signUp: "sign_up"
            case .login: "login"
            case .accountCreated: "account_created"
            case .welcomeCompleted: "welcome_completed"
            case .locationStoreSetupCompleted: "location_store_setup_completed"
            case .dealViewed: "deal_viewed"
            case .recipeViewed: "recipe_viewed"
            case .recipeSaved: "recipe_saved"
            case .allStoresEnabled: "all_stores_enabled"
            case .worthItOpened: "worth_it_opened"
            case .stealsOpened: "steals_opened"
            case .smartSwapShown: "smart_swap_shown"
            case .cookTonight: "cook_tonight"
            case .streakOpened: "streak_opened"
            case .currencyChanged: "currency_changed"
            case .shoppingListItemAdded: "shopping_list_item_added"
            case .shoppingListItemRemoved: "shopping_list_item_removed"
            case .zestyQuestionAsked: "zesty_question_asked"
            case .paywallViewed: "paywall_viewed"
            case .trialStarted: "trial_started"
            case .subscriptionPurchased: "subscription_purchased"
            case .subscriptionPlanChanged: "subscription_plan_changed"
            case .restorePurchases: "restore_purchases"
            case .recipeCatalogueLoadFailed: "recipe_catalogue_load_failed"
            case .liveDealsLoadFailed: "live_deals_load_failed"
            case .currentPricesLoadFailed: "current_prices_load_failed"
            }
        }

        var properties: [String: Any] {
            switch self {
            case .onboardingStepViewed(let step):
                return ["step": step]
            case .onboardingCompleted(let goal):
                return ["goal": goal]
            case .onboardingStarted, .planBuildStarted, .accountCreated, .welcomeCompleted,
                 .allStoresEnabled, .worthItOpened, .stealsOpened,
                 .recipeCatalogueLoadFailed, .liveDealsLoadFailed, .currentPricesLoadFailed:
                return [:]
            case .signUp(let method), .login(let method):
                return ["method": method]
            case .locationStoreSetupCompleted(let method, let storeCount, let context):
                return ["method": method, "store_count": storeCount, "context": context]
            case .dealViewed(let dealId):
                return ["deal_id": dealId]
            case .recipeViewed(let recipeId), .recipeSaved(let recipeId), .cookTonight(let recipeId):
                return ["recipe_id": recipeId]
            case .smartSwapShown(let recipeId, let count):
                return ["recipe_id": recipeId, "count": count]
            case .streakOpened(let days):
                return ["days": days]
            case .currencyChanged(let currency):
                return ["currency": currency]
            case .shoppingListItemAdded(let source, let recipeId, let dealId, let lineCount):
                var props: [String: Any] = ["source": source, "line_count": lineCount]
                if let recipeId { props["recipe_id"] = recipeId }
                if let dealId { props["deal_id"] = dealId }
                return props
            case .shoppingListItemRemoved(let ingredientId):
                return ["ingredient_id": ingredientId]
            case .zestyQuestionAsked(let isFollowUp):
                return ["is_follow_up": isFollowUp]
            case .paywallViewed(let context):
                return ["context": context]
            case .trialStarted(let productId, let isSandbox):
                return ["product_id": productId, "is_trial": true, "is_sandbox": isSandbox]
            case .subscriptionPurchased(let productId, let isSandbox):
                return ["product_id": productId, "is_trial": false, "is_sandbox": isSandbox]
            case .subscriptionPlanChanged(let fromProductId, let toProductId, let isSandbox):
                var props: [String: Any] = ["to_product_id": toProductId, "is_sandbox": isSandbox]
                if let fromProductId, !fromProductId.isEmpty {
                    props["from_product_id"] = fromProductId
                }
                return props
            case .restorePurchases(let productId, let isTrial, let isSandbox):
                var props: [String: Any] = ["is_trial": isTrial, "restored": true, "is_sandbox": isSandbox]
                if let productId { props["product_id"] = productId }
                return props
            }
        }
    }

    /// Call once from the app entry point, before any screen is shown.
    static func start() {
        let config = PostHogConfig(projectToken: PostHogSettings.apiKey, host: PostHogSettings.host)
        // Lifecycle events stay on (SDK default). Screen names come from `analyticsScreen`, not UIKit swizzling.
        config.captureScreenViews = false
        config.sessionReplay = false
        config.surveys = false
        config.disableGeoIp = true
        PostHogSDK.shared.setup(config)
        registerSuperProperties()
    }

    /// Links this device's events to the signed-in user. Pass the Clerk user id (also the Supabase profile key).
    /// Never pass an email address. Identifying a second user while the first is still identified is a no-op
    /// in posthog-ios 3.92.4 — call `reset()` first when the user changes.
    static func identify(userId: String) {
        let id = userId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !id.isEmpty else { return }
        PostHogSDK.shared.identify(id)
    }

    /// Clears the current person. Super properties are wiped too, so the debug flag is registered again.
    static func reset() {
        PostHogSDK.shared.reset()
        registerSuperProperties()
    }

    static func track(_ event: Event) {
        let properties = event.properties
        if properties.isEmpty {
            PostHogSDK.shared.capture(event.name)
        } else {
            PostHogSDK.shared.capture(event.name, properties: properties)
        }
        logger.debug("event=\(event.name, privacy: .public)")
    }

    static func screen(_ name: String) {
        PostHogSDK.shared.screen(name)
    }

    /// `reset()` drops registered properties, so this runs after setup and after every reset.
    private static func registerSuperProperties() {
        #if DEBUG
        let isDebugBuild = true
        #else
        let isDebugBuild = false
        #endif
        PostHogSDK.shared.register(["is_debug_build": isDebugBuild])
    }
}

extension View {
    /// Records a `$screen` event with a stable name when this view appears.
    func analyticsScreen(_ name: String) -> some View {
        onAppear { Analytics.screen(name) }
    }
}
