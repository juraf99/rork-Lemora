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
        case signUp(method: String)
        case login(method: String)
        case locationStoreSetupCompleted(method: String, storeCount: Int, context: String)
        case dealViewed(dealId: String)
        case recipeViewed(recipeId: String)
        case recipeSaved(recipeId: String)
        case shoppingListItemAdded(source: String, recipeId: String?, dealId: String?, lineCount: Int)
        case shoppingListItemRemoved(ingredientId: String)
        case zestyQuestionAsked(isFollowUp: Bool)
        case paywallViewed(context: String)
        case trialStarted(productId: String, isTrial: Bool)
        case subscriptionPurchased(productId: String, isTrial: Bool)
        case restorePurchases(productId: String?, isTrial: Bool)

        var name: String {
            switch self {
            case .onboardingStepViewed: "onboarding_step_viewed"
            case .onboardingCompleted: "onboarding_completed"
            case .signUp: "sign_up"
            case .login: "login"
            case .locationStoreSetupCompleted: "location_store_setup_completed"
            case .dealViewed: "deal_viewed"
            case .recipeViewed: "recipe_viewed"
            case .recipeSaved: "recipe_saved"
            case .shoppingListItemAdded: "shopping_list_item_added"
            case .shoppingListItemRemoved: "shopping_list_item_removed"
            case .zestyQuestionAsked: "zesty_question_asked"
            case .paywallViewed: "paywall_viewed"
            case .trialStarted: "trial_started"
            case .subscriptionPurchased: "subscription_purchased"
            case .restorePurchases: "restore_purchases"
            }
        }

        var properties: [String: Any] {
            switch self {
            case .onboardingStepViewed(let step):
                return ["step": step]
            case .onboardingCompleted(let goal):
                return ["goal": goal]
            case .signUp(let method), .login(let method):
                return ["method": method]
            case .locationStoreSetupCompleted(let method, let storeCount, let context):
                return ["method": method, "store_count": storeCount, "context": context]
            case .dealViewed(let dealId):
                return ["deal_id": dealId]
            case .recipeViewed(let recipeId), .recipeSaved(let recipeId):
                return ["recipe_id": recipeId]
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
            case .trialStarted(let productId, let isTrial):
                return ["product_id": productId, "is_trial": isTrial]
            case .subscriptionPurchased(let productId, let isTrial):
                return ["product_id": productId, "is_trial": isTrial]
            case .restorePurchases(let productId, let isTrial):
                var props: [String: Any] = ["is_trial": isTrial, "restored": true]
                if let productId { props["product_id"] = productId }
                return props
            }
        }
    }

    /// Call once from the app entry point, before any screen is shown.
    static func start() {
        let config = PostHogConfig(projectToken: PostHogSettings.apiKey, host: PostHogSettings.host)
        config.captureApplicationLifecycleEvents = true
        // SwiftUI screen names from UIKit swizzling are not meaningful. Screens are recorded manually.
        config.captureScreenViews = false
        config.sessionReplay = false
        config.surveys = false
        PostHogSDK.shared.setup(config)
    }

    /// Links this device's events to the signed-in user. Pass the Clerk user id (also the Supabase profile key).
    /// Never pass an email address.
    static func identify(userId: String) {
        let id = userId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !id.isEmpty else { return }
        PostHogSDK.shared.identify(id)
    }

    static func reset() {
        PostHogSDK.shared.reset()
    }

    static func track(_ event: Event) {
        PostHogSDK.shared.capture(event.name, properties: event.properties)
        logger.debug("event=\(event.name, privacy: .public)")
    }

    static func screen(_ name: String) {
        PostHogSDK.shared.screen(name)
    }
}

extension View {
    /// Records a `$screen` event with a stable name when this view appears.
    func analyticsScreen(_ name: String) -> some View {
        onAppear { Analytics.screen(name) }
    }
}
