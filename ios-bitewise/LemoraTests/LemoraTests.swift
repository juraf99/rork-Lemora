import Testing
import Foundation
@testable import Lemora

struct SafetyTests {
    let engine = RecommendationEngine()

    private func profile(_ change: (inout UserProfile) -> Void) -> UserProfile {
        var p = UserProfile()
        change(&p)
        return p
    }

    @Test func sesameAllergyNeverSeesSesameOrUncertainRecipes() {
        let p = profile { $0.allergies = [.sesame] }
        let ranked = engine.rank(recipes: RecipeCatalog.all, profile: p, taste: [:], seen: [],
                                 prices: prices(), weights: RecommendationWeights())
        for item in ranked {
            let ids = item.recipe.ingredients.compactMap { IngredientCatalog.ingredient($0.ingredientId) }
            #expect(!ids.contains { $0.contains.contains(.sesame) || $0.mayContain.contains(.sesame) })
        }
    }

    @Test func veganNeverGetsAnimalProducts() {
        let p = profile { $0.diets = [.vegan] }
        for recipe in RecipeCatalog.all where engine.passesHardFilters(recipe, profile: p) {
            #expect(recipe.ingredients.allSatisfy { IngredientCatalog.ingredient($0.ingredientId)?.animal == AnimalKind.none })
        }
    }

    @Test func glutenFreeExcludesUncertainGluten() {
        let p = profile { $0.diets = [.glutenFree] }
        let tacos = RecipeCatalog.byId["carne_asada_tacos"]!
        #expect(!engine.passesHardFilters(tacos, profile: p))
    }

    @Test func dislikesAreFiltered() {
        let p = profile { $0.dislikes = ["Avocado"] }
        let bowl = RecipeCatalog.byId["burrito_bowl"]!
        #expect(!engine.passesHardFilters(bowl, profile: p))
    }

    @Test func expiredDealsAreNeverActive() {
        let deals = SampleDealProvider.deals(now: .now)
        let expired = deals.first { $0.id == "d_tomato_old" }!
        #expect(!expired.isActive(at: .now))
    }

    @Test func multiBuyNormalizesPerItem() {
        let pepper = SampleDealProvider.deals().first { $0.id == "d_pepper" }!
        #expect(abs(pepper.effectivePrice - 4.0 / 3.0) < 0.001)
    }

    @Test func noDiscountWithoutReferencePrice() {
        let blueberries = SampleDealProvider.deals().first { $0.id == "d_blueberries" }!
        #expect(blueberries.discountPercent == nil)
    }

    @Test func servingScalingIsProportional() {
        let recipe = RecipeCatalog.byId["burrito_bowl"]!
        let base = PricingEngine().price(recipe: recipe, servings: 4, deals: [])
        let doubled = PricingEngine().price(recipe: recipe, servings: 8, deals: [])
        #expect(abs(doubled.total - base.total * 2) < 0.01)
    }

    private func terms(trial: Int?, eligible: Bool, annual: Bool = true) -> PaywallTerms {
        PaywallTerms(annualPrice: "$29.99", annualValue: 29.99, monthlyPrice: "$9.99", monthlyValue: 9.99,
                     currencyCode: "USD", currencySuffix: "", configuredTrialDays: trial,
                     isEligibleForTrial: eligible, annualSelected: annual, pricesLoaded: true)
    }

    @Test func freeWeekOnlyWhenEligibleForSevenDayTrial() {
        #expect(terms(trial: 7, eligible: true).ctaTitle == "Start My Free Week")
        #expect(terms(trial: 7, eligible: true).reminderDay == 5)
        #expect(terms(trial: 7, eligible: false).trialDays == nil)
        #expect(terms(trial: 7, eligible: false).ctaTitle != "Start My Free Week")
        #expect(terms(trial: nil, eligible: true).trialDays == nil)
    }

    @Test func threeDayAnnualTrialDoesNotPromiseAFreeWeek() {
        #expect(terms(trial: 3, eligible: true).ctaTitle == "Start My 3-Day Free Trial")
        #expect(terms(trial: 3, eligible: true).reminderDay == 2)
        #expect(terms(trial: 3, eligible: true, annual: false).trialDays == nil)
        #expect(terms(trial: 3, eligible: true, annual: false).ctaTitle == "Unlock My Full Plan")
    }

    @Test func monthlyPlanHasNoTrial() {
        #expect(terms(trial: 7, eligible: true, annual: false).trialDays == nil)
        #expect(terms(trial: 3, eligible: true, annual: false).footnote.contains("/month"))
    }

    @Test func yearlySavingsIsComputedFromRealPrices() {
        #expect(terms(trial: 3, eligible: true).savingsPercent == 75)
    }

    @Test func pricesStayHiddenUntilStoreKitLoads() {
        let loading = PaywallTerms(annualPrice: "…", annualValue: 0, monthlyPrice: "…", monthlyValue: 0,
                                   currencyCode: "USD", currencySuffix: "", configuredTrialDays: nil,
                                   isEligibleForTrial: false, annualSelected: true, pricesLoaded: false)
        #expect(loading.ctaTitle == "Loading prices…")
        #expect(loading.trialDays == nil)
        #expect(loading.savingsPercent == nil)
    }

    private func prices() -> [String: RecipePrice] {
        let deals = SampleDealProvider.deals()
        return Dictionary(uniqueKeysWithValues: RecipeCatalog.all.map { ($0.id, PricingEngine().price(recipe: $0, servings: $0.servings, deals: deals)) })
    }
}
