import Foundation

/// Development recipe library (clearly Lemora Original fixtures). A backend-driven
/// `RecipeRepository` replaces this once the admin ingestion pipeline is live.
nonisolated enum RecipeCatalog {
    private static func ri(_ id: String, _ raw: String, _ q: Double, _ u: IngredientUnit, _ cost: Double) -> RecipeIngredient {
        RecipeIngredient(ingredientId: id, rawText: raw, quantity: q, unit: u, estimatedCost: cost)
    }

    /// English source recipes. `all` returns them in the language picked in the app.
    private static let source: [Recipe] = [
        Recipe(
            id: "burrito_bowl", title: "Crispy Chicken Burrito Bowl",
            summary: "Smoky seared chicken over rice with black beans, charred corn, fresh pico and creamy lime crema.",
            imageName: "chicken_burrito_bowl", cuisine: .mexican, mealType: .dinner, mainProtein: "chicken",
            servings: 4, prepMinutes: 10, cookMinutes: 15,
            ingredients: [
                ri("chicken_breast", "700 g boneless chicken breast", 700, .g, 11.00),
                ri("rice", "1½ cups long-grain rice", 1.5, .cup, 0.90),
                ri("black_beans", "1 can black beans, rinsed", 1, .can, 1.29),
                ri("corn", "1½ cups corn kernels", 1.5, .cup, 1.10),
                ri("bell_pepper", "2 bell peppers, diced", 2, .unit, 3.20),
                ri("avocado", "2 ripe avocados", 2, .unit, 3.00),
                ri("tomato", "2 tomatoes, diced", 2, .unit, 1.30),
                ri("lime", "1 lime", 1, .unit, 0.50),
                ri("cilantro", "½ bunch cilantro", 0.5, .unit, 0.99),
                ri("sour_cream", "4 tbsp sour cream", 4, .tbsp, 0.80),
            ],
            steps: [
                "Cook the rice according to the package. Fluff with a squeeze of lime.",
                "Season the chicken with salt, cumin and smoked paprika. Sear 6–7 min per side until crispy and cooked through. Rest, then dice.",
                "Char the corn and peppers in the same pan for 4 minutes.",
                "Mix tomatoes, cilantro and a pinch of salt for a quick pico. Stir lime juice into the sour cream.",
                "Build bowls: rice, beans, chicken, corn and peppers, avocado, pico and a drizzle of crema.",
            ],
            nutrition: Nutrition(calories: 640, protein: 52, carbs: 62, fat: 18, fiber: 13, status: .estimated),
            tags: [.highProtein, .mealPrep, .bowl], source: .bitewiseOriginal
        ),
        Recipe(
            id: "teriyaki_bowl", title: "Teriyaki Chicken Bowl",
            summary: "Sticky teriyaki chicken with broccoli, edamame and carrots. Built for meal prep.",
            imageName: "teriyaki_chicken_rice_bowl", cuisine: .japanese, mealType: .dinner, mainProtein: "chicken",
            servings: 4, prepMinutes: 10, cookMinutes: 20,
            ingredients: [
                ri("chicken_breast", "600 g chicken breast, cubed", 600, .g, 9.40),
                ri("rice", "1½ cups rice", 1.5, .cup, 0.90),
                ri("broccoli", "1 head broccoli", 1, .unit, 3.49),
                ri("edamame", "1 cup shelled edamame", 1, .cup, 1.60),
                ri("carrot", "2 carrots, shredded", 2, .unit, 0.60),
                ri("teriyaki_sauce", "½ cup teriyaki sauce", 8, .tbsp, 1.20),
                ri("sesame_seeds", "1 tbsp sesame seeds", 1, .tbsp, 0.20),
            ],
            steps: [
                "Cook the rice. Steam the broccoli and edamame for 4 minutes.",
                "Sear the chicken cubes until golden, about 8 minutes.",
                "Pour in the teriyaki sauce and simmer until sticky and glossy.",
                "Divide rice, chicken and vegetables into bowls or containers. Top with carrots and sesame.",
            ],
            nutrition: Nutrition(calories: 560, protein: 46, carbs: 64, fat: 11, fiber: 7, status: .estimated),
            tags: [.highProtein, .mealPrep, .bowl, .budget], source: .bitewiseOriginal
        ),
        Recipe(
            id: "shakshuka", title: "Feta Shakshuka",
            summary: "Eggs gently poached in a spiced tomato and pepper sauce, finished with feta and herbs.",
            imageName: "shakshuka_cast_iron", cuisine: .middleEastern, mealType: .breakfast, mainProtein: "eggs",
            servings: 2, prepMinutes: 5, cookMinutes: 20,
            ingredients: [
                ri("eggs", "4 eggs", 4, .unit, 1.80),
                ri("canned_tomatoes", "1 can crushed tomatoes", 1, .can, 1.79),
                ri("bell_pepper", "1 red bell pepper", 1, .unit, 1.60),
                ri("onion", "1 onion", 1, .unit, 0.50),
                ri("garlic", "2 cloves garlic", 2, .clove, 0.20),
                ri("feta", "60 g feta", 60, .g, 1.50),
                ri("parsley", "Small handful parsley", 0.25, .unit, 0.50),
            ],
            steps: [
                "Soften onion and pepper in olive oil for 6 minutes. Add garlic, cumin and paprika.",
                "Pour in tomatoes and simmer 8 minutes until thick.",
                "Make 4 wells, crack in the eggs, cover and cook 5–6 minutes.",
                "Finish with crumbled feta and parsley. Serve with bread.",
            ],
            nutrition: Nutrition(calories: 340, protein: 20, carbs: 22, fat: 19, fiber: 6, status: .estimated),
            tags: [.quick, .vegetarianFriendly, .budget], source: .bitewiseOriginal
        ),
        Recipe(
            id: "chickpea_curry", title: "Chickpea Cauliflower Curry",
            summary: "Creamy coconut curry loaded with roasted cauliflower and chickpeas.",
            imageName: "close_up_food", cuisine: .indian, mealType: .dinner, mainProtein: "chickpeas",
            servings: 4, prepMinutes: 10, cookMinutes: 25,
            ingredients: [
                ri("chickpeas", "2 cans chickpeas", 2, .can, 3.58),
                ri("cauliflower", "1 head cauliflower", 1, .unit, 3.99),
                ri("coconut_milk", "1 can coconut milk", 1, .can, 2.29),
                ri("curry_paste", "3 tbsp curry paste", 3, .tbsp, 1.20),
                ri("onion", "1 onion", 1, .unit, 0.50),
                ri("garlic", "3 cloves garlic", 3, .clove, 0.30),
                ri("spinach", "2 cups spinach", 2, .cup, 1.20),
                ri("rice", "1½ cups basmati rice", 1.5, .cup, 1.10),
            ],
            steps: [
                "Roast cauliflower florets at 220°C for 20 minutes.",
                "Sauté onion and garlic, then stir in the curry paste for 1 minute.",
                "Add coconut milk and chickpeas. Simmer 10 minutes.",
                "Fold in roasted cauliflower and spinach. Serve over rice.",
            ],
            nutrition: Nutrition(calories: 520, protein: 17, carbs: 68, fat: 21, fiber: 15, status: .estimated),
            tags: [.mealPrep, .comfort, .vegetarianFriendly, .spicy, .budget], source: .bitewiseOriginal
        ),
        Recipe(
            id: "salmon_bowl", title: "Teriyaki Salmon Rice Bowl",
            summary: "Glazed salmon over rice with cucumber, avocado and edamame.",
            imageName: "teriyaki_salmon_rice_bowl", cuisine: .japanese, mealType: .dinner, mainProtein: "salmon",
            servings: 2, prepMinutes: 10, cookMinutes: 12,
            ingredients: [
                ri("salmon", "2 salmon fillets (300 g)", 300, .g, 9.90),
                ri("rice", "1 cup rice", 1, .cup, 0.60),
                ri("cucumber", "1 cucumber", 1, .unit, 1.29),
                ri("avocado", "1 avocado", 1, .unit, 1.50),
                ri("edamame", "½ cup edamame", 0.5, .cup, 0.80),
                ri("soy_sauce", "3 tbsp soy sauce", 3, .tbsp, 0.40),
                ri("sesame_seeds", "1 tsp sesame seeds", 1, .tsp, 0.10),
            ],
            steps: [
                "Cook the rice.",
                "Brush salmon with soy sauce and a little maple. Bake at 200°C for 12 minutes.",
                "Slice cucumber and avocado.",
                "Assemble bowls and finish with sesame seeds.",
            ],
            nutrition: Nutrition(calories: 610, protein: 38, carbs: 58, fat: 24, fiber: 8, status: .estimated),
            tags: [.bowl, .quick, .highProtein], source: .bitewiseOriginal
        ),
        Recipe(
            id: "chicken_rigatoni", title: "High-Protein Chicken Rigatoni",
            summary: "Creamy tomato rigatoni with sliced grilled chicken and parmesan.",
            imageName: "chicken_rigatoni_pasta", cuisine: .italian, mealType: .dinner, mainProtein: "chicken",
            servings: 4, prepMinutes: 10, cookMinutes: 20,
            ingredients: [
                ri("rigatoni", "400 g rigatoni", 400, .g, 2.49),
                ri("chicken_breast", "500 g chicken breast", 500, .g, 7.85),
                ri("canned_tomatoes", "1 can crushed tomatoes", 1, .can, 1.79),
                ri("cream", "½ cup cooking cream", 0.5, .cup, 1.20),
                ri("parmesan", "40 g parmesan", 40, .g, 1.60),
                ri("garlic", "3 cloves garlic", 3, .clove, 0.30),
                ri("basil", "Handful basil", 0.25, .unit, 0.75),
            ],
            steps: [
                "Boil the rigatoni until al dente. Save a cup of pasta water.",
                "Grill the seasoned chicken 6 minutes per side. Rest and slice.",
                "Sauté garlic, add tomatoes and simmer 8 minutes. Stir in cream and parmesan.",
                "Toss pasta with sauce, loosen with pasta water, top with chicken and basil.",
            ],
            nutrition: Nutrition(calories: 690, protein: 49, carbs: 78, fat: 17, fiber: 5, status: .estimated),
            tags: [.highProtein, .comfort, .mealPrep], source: .bitewiseOriginal
        ),
        Recipe(
            id: "carne_asada_tacos", title: "Carne Asada Tacos",
            summary: "Citrus-marinated grilled steak on warm corn tortillas with salsa verde.",
            imageName: "carne_asada_tacos", cuisine: .mexican, mealType: .dinner, mainProtein: "beef",
            servings: 3, prepMinutes: 15, cookMinutes: 10,
            ingredients: [
                ri("flank_steak", "500 g flank steak", 500, .g, 13.50),
                ri("corn_tortillas", "9 corn tortillas", 9, .unit, 2.50),
                ri("onion", "½ white onion", 0.5, .unit, 0.25),
                ri("cilantro", "½ bunch cilantro", 0.5, .unit, 0.99),
                ri("lime", "2 limes", 2, .unit, 1.00),
                ri("salsa_verde", "½ cup salsa verde", 0.5, .cup, 1.50),
                ri("radish", "4 radishes", 4, .unit, 0.80),
            ],
            steps: [
                "Marinate the steak in lime juice, garlic, cumin and salt for 15 minutes.",
                "Grill over high heat 4 minutes per side. Rest 5 minutes and slice thinly against the grain.",
                "Warm tortillas in a dry pan.",
                "Top with steak, onion, cilantro, radish and salsa verde.",
            ],
            nutrition: Nutrition(calories: 520, protein: 42, carbs: 38, fat: 21, fiber: 6, status: .estimated),
            tags: [.highProtein, .quick, .spicy], source: .bitewiseOriginal
        ),
        Recipe(
            id: "lentil_salad", title: "Lentil Sweet Potato Salad",
            summary: "Roasted sweet potato, lentils and arugula with a lemon tahini dressing.",
            imageName: "lentil_sweet_potato_salad", cuisine: .mediterranean, mealType: .lunch, mainProtein: "lentils",
            servings: 3, prepMinutes: 10, cookMinutes: 25,
            ingredients: [
                ri("lentils", "1 cup green lentils", 1, .cup, 1.40),
                ri("sweet_potato", "2 sweet potatoes", 2, .unit, 2.40),
                ri("arugula", "3 cups arugula", 3, .cup, 2.50),
                ri("feta", "60 g feta", 60, .g, 1.50),
                ri("tahini", "3 tbsp tahini", 3, .tbsp, 0.90),
                ri("lemon", "1 lemon", 1, .unit, 0.60),
                ri("pumpkin_seeds", "2 tbsp pumpkin seeds", 2, .tbsp, 0.50),
            ],
            steps: [
                "Roast cubed sweet potato at 220°C for 25 minutes.",
                "Simmer lentils 20 minutes until tender. Drain.",
                "Whisk tahini, lemon juice, water and salt into a dressing.",
                "Toss everything with arugula, feta and pumpkin seeds.",
            ],
            nutrition: Nutrition(calories: 470, protein: 21, carbs: 60, fat: 16, fiber: 16, status: .estimated),
            tags: [.vegetarianFriendly, .mealPrep, .budget], source: .bitewiseOriginal
        ),
        Recipe(
            id: "protein_pancakes", title: "Protein Blueberry Pancakes",
            summary: "Fluffy oat and whey pancakes studded with blueberries. Breakfast in 15 minutes.",
            imageName: "blueberry_pancakes_stack", cuisine: .american, mealType: .breakfast, mainProtein: "eggs",
            servings: 1, prepMinutes: 5, cookMinutes: 10,
            ingredients: [
                ri("oats", "½ cup oats", 0.5, .cup, 0.30),
                ri("protein_powder", "1 scoop whey protein", 1, .unit, 1.20),
                ri("eggs", "2 eggs", 2, .unit, 0.90),
                ri("greek_yogurt", "½ cup Greek yogurt", 0.5, .cup, 1.10),
                ri("blueberries", "½ cup blueberries", 0.5, .cup, 1.25),
                ri("maple_syrup", "1 tbsp maple syrup", 1, .tbsp, 0.40),
            ],
            steps: [
                "Blend oats, protein powder, eggs and half the yogurt into a batter.",
                "Fold in most of the blueberries.",
                "Cook small pancakes on a buttered pan, 2 minutes per side.",
                "Top with remaining yogurt, blueberries and maple syrup.",
            ],
            nutrition: Nutrition(calories: 480, protein: 45, carbs: 44, fat: 13, fiber: 6, status: .estimated),
            tags: [.highProtein, .quick], source: .bitewiseOriginal
        ),
    ]

    /// The bundled recipes in the language picked in the app (titles, descriptions and steps are in Localizable.xcstrings).
    static var all: [Recipe] {
        source.map { r in
            Recipe(id: r.id, title: lemoraLocalized(r.title), summary: lemoraLocalized(r.summary), imageName: r.imageName,
                   cuisine: r.cuisine, mealType: r.mealType, mainProtein: r.mainProtein, servings: r.servings,
                   prepMinutes: r.prepMinutes, cookMinutes: r.cookMinutes, ingredients: r.ingredients,
                   steps: r.steps.map { lemoraLocalized($0) }, nutrition: r.nutrition, tags: r.tags, source: r.source,
                   verifiedDietKeys: r.verifiedDietKeys, rejectedDietKeys: r.rejectedDietKeys,
                   identifiedAllergenKeys: r.identifiedAllergenKeys, possibleAllergenKeys: r.possibleAllergenKeys,
                   priceStatus: r.priceStatus, storePricesPerServing: r.storePricesPerServing)
        }
    }

    static var byId: [String: Recipe] { Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) }) }
}
