import SwiftUI

/// Display names, emoji, grocery aisle and flyer-deal aliases for the ingredient ids used by the
/// permanent recipe catalogue (Supabase `catalogue_payload.ingredients[].normalized_name`).
nonisolated enum CatalogIngredientInfo {
    typealias Info = (name: String, emoji: String, category: GroceryCategory, dealIds: [String])

    static let info: [String: Info] = [
        "acorn_squash": ("Acorn squash", "🎃", .produce, ["squash"]),
        "almond": ("Almonds", "🌰", .pantry, ["almonds"]),
        "anchovy": ("Anchovy fillets", "🐟", .protein, []),
        "apple": ("Apples", "🍎", .produce, ["apple"]),
        "apricot": ("Dried apricots", "🍑", .pantry, []),
        "arborio": ("Arborio rice", "🍚", .pantry, ["rice"]),
        "artichoke": ("Artichoke hearts", "🌿", .pantry, []),
        "arugula": ("Arugula", "🥬", .produce, []),
        "asparagus": ("Asparagus", "🌱", .produce, ["asparagus"]),
        "avocado": ("Avocado", "🥑", .produce, ["avocado"]),
        "bacon": ("Bacon", "🥓", .protein, ["bacon", "pork"]),
        "baking_powder": ("Baking powder", "🧂", .pantry, []),
        "balsamic": ("Balsamic vinegar", "🫙", .pantry, []),
        "banana": ("Bananas", "🍌", .produce, ["banana"]),
        "barley": ("Barley", "🌾", .pantry, []),
        "basil": ("Basil", "🌿", .produce, []),
        "basil_pesto": ("Basil pesto", "🌿", .pantry, []),
        "bean_sprout": ("Bean sprouts", "🌱", .produce, []),
        "bean_sprouts": ("Bean sprouts", "🌱", .produce, []),
        "beef": ("Beef strips", "🥩", .protein, ["beef"]),
        "beef_broth": ("Beef broth", "🥣", .pantry, ["broth"]),
        "beef_minced": ("Lean ground beef", "🥩", .protein, ["ground_beef", "beef"]),
        "beet": ("Beets", "🟣", .produce, ["beets"]),
        "beet_hummus": ("Beet hummus", "🥣", .dairy, ["hummus"]),
        "bell_pepper": ("Bell peppers", "🫑", .produce, ["bell_pepper"]),
        "beluga_lentil": ("Black lentils", "🫘", .pantry, ["lentils"]),
        "black_bean": ("Black beans", "🫘", .pantry, ["black_beans", "beans"]),
        "black_pepper": ("Black pepper", "🧂", .pantry, []),
        "black_rice": ("Black rice", "🍚", .pantry, ["rice"]),
        "blueberry": ("Blueberries", "🫐", .produce, ["blueberries"]),
        "bok_choy": ("Bok choy", "🥬", .produce, ["bok_choy"]),
        "bread": ("Bread", "🍞", .bakery, ["bread"]),
        "breadcrumb": ("Breadcrumbs", "🍞", .pantry, []),
        "brioche_bun": ("Brioche bun", "🍞", .bakery, ["bread"]),
        "broccoli": ("Broccoli", "🥦", .produce, ["broccoli"]),
        "broccoli_rabe": ("Rapini", "🥦", .produce, []),
        "broth": ("Vegetable broth", "🥣", .pantry, ["broth"]),
        "brown_rice": ("Brown rice", "🍚", .pantry, ["rice"]),
        "brown_sugar": ("Brown sugar", "🧂", .pantry, ["sugar"]),
        "brussels_sprout": ("Brussels sprouts", "🥬", .produce, ["brussels_sprouts"]),
        "bucatini": ("Bucatini", "🍝", .pantry, ["pasta"]),
        "buckwheat": ("Buckwheat", "🌾", .pantry, []),
        "buckwheat_flour": ("Buckwheat flour", "🌾", .pantry, []),
        "bulgur": ("Bulgur", "🌾", .pantry, []),
        "bun": ("Burger bun", "🍞", .bakery, ["bread"]),
        "burrata": ("Burrata", "🧀", .dairy, ["cheese"]),
        "butter": ("Butter", "🧈", .dairy, ["butter"]),
        "butter_bean": ("Butter beans", "🫘", .pantry, ["beans"]),
        "butternut": ("Butternut squash", "🎃", .produce, ["squash"]),
        "cabbage": ("Cabbage", "🥬", .produce, ["cabbage"]),
        "canola_oil": ("Canola oil", "🫗", .pantry, ["vegetable_oil"]),
        "caper": ("Capers", "🫙", .pantry, []),
        "caraway": ("Caraway", "🧂", .pantry, []),
        "cardamom": ("Cardamom", "🧂", .pantry, []),
        "carrot": ("Carrots", "🥕", .produce, ["carrot"]),
        "carrot_purple": ("Rainbow carrots", "🥕", .produce, ["carrot"]),
        "casarecce": ("Casarecce", "🍝", .pantry, ["pasta"]),
        "cashew": ("Cashews", "🌰", .pantry, ["cashews"]),
        "cauliflower": ("Cauliflower", "🥦", .produce, ["cauliflower"]),
        "celery": ("Celery", "🥬", .produce, ["celery"]),
        "cheddar": ("Cheddar", "🧀", .dairy, ["cheese"]),
        "cherry_tomato": ("Cherry tomatoes", "🍅", .produce, ["tomato"]),
        "chia": ("Chia seeds", "⚫️", .pantry, []),
        "chicken": ("Chicken breast", "🍗", .protein, ["chicken_breast", "chicken"]),
        "chicken_leg": ("Chicken legs", "🍗", .protein, ["chicken"]),
        "chickpea": ("Chickpeas", "🫘", .pantry, ["chickpeas"]),
        "chickpeas": ("Chickpeas", "🫘", .pantry, ["chickpeas"]),
        "chili": ("Chili", "🌶️", .pantry, []),
        "chili_powder": ("Chili powder", "🌶️", .pantry, []),
        "chipotle": ("Ground chipotle", "🌶️", .pantry, []),
        "chive": ("Chives", "🌿", .produce, []),
        "chives": ("Chives", "🌿", .produce, []),
        "cilantro": ("Cilantro", "🌿", .produce, ["cilantro"]),
        "cinnamon": ("Cinnamon", "🧂", .pantry, []),
        "clam": ("Clams", "🦪", .protein, ["clams"]),
        "clams": ("Clam meat", "🦪", .protein, ["clams"]),
        "clove": ("Ground cloves", "🧂", .pantry, []),
        "cocoa": ("Cocoa powder", "🍫", .pantry, []),
        "coconut": ("Unsweetened coconut", "🥥", .pantry, []),
        "coconut_flake": ("Coconut flakes", "🥥", .pantry, []),
        "coconut_milk": ("Coconut milk", "🥥", .pantry, ["coconut_milk"]),
        "cod": ("Cod fillet", "🐟", .protein, ["cod", "fish"]),
        "conchiglioni": ("Conchiglioni", "🍝", .pantry, ["pasta"]),
        "cooked_beet": ("Cooked beets", "🟣", .produce, ["beets"]),
        "coriander": ("Cilantro", "🌿", .produce, ["cilantro"]),
        "coriander_seed": ("Coriander seeds", "🧂", .pantry, []),
        "corn": ("Corn", "🌽", .frozen, ["corn"]),
        "corn_tortilla": ("Corn tortilla", "🌮", .bakery, ["tortillas"]),
        "cornstarch": ("Cornstarch", "🌽", .pantry, []),
        "cottage": ("Cottage cheese", "🧀", .dairy, ["cheese"]),
        "couscous": ("Couscous", "🌾", .pantry, []),
        "crab": ("Crab meat", "🦀", .protein, ["crab"]),
        "cranberry": ("Dried cranberries", "🍒", .pantry, []),
        "cream": ("Cooking cream", "🥛", .dairy, ["cream"]),
        "cream_cheese": ("Cream cheese", "🧀", .dairy, ["cheese"]),
        "crushed_tomato": ("Crushed tomatoes", "🍅", .pantry, ["canned_tomatoes"]),
        "cucumber": ("Cucumber", "🥒", .produce, ["cucumber"]),
        "cumin": ("Ground cumin", "🧂", .pantry, []),
        "cumin_seed": ("Cumin seeds", "🧂", .pantry, []),
        "curry": ("Curry paste", "🍛", .pantry, ["curry_paste"]),
        "curry_leaf": ("Curry leaves", "🌿", .produce, []),
        "curry_powder": ("Curry powder", "🧂", .pantry, []),
        "dark_chocolate": ("Dark chocolate", "🍫", .pantry, ["chocolate"]),
        "dijon_mustard": ("Dijon mustard", "🫙", .pantry, []),
        "dill": ("Dill", "🌿", .produce, []),
        "ditalini": ("Ditalini", "🍝", .pantry, ["pasta"]),
        "dried_chili": ("Dried chilies", "🌶️", .pantry, []),
        "dried_ginger": ("Ground ginger", "🧂", .pantry, []),
        "duck": ("Duck breast", "🦆", .protein, ["duck"]),
        "edamame": ("Edamame", "🫛", .frozen, ["edamame"]),
        "egg": ("Eggs", "🥚", .dairy, ["egg", "eggs"]),
        "eggplant": ("Eggplant", "🍆", .produce, ["eggplant"]),
        "falafel": ("Falafel", "🧆", .protein, []),
        "farfalle": ("Farfalle", "🍝", .pantry, ["pasta"]),
        "farro": ("Farro", "🌾", .pantry, []),
        "fennel": ("Fennel", "🌿", .produce, []),
        "fennel_seed": ("Fennel seeds", "🧂", .pantry, []),
        "feta": ("Feta", "🧀", .dairy, ["cheese"]),
        "firm_tofu": ("Firm tofu", "🧈", .protein, ["tofu"]),
        "fish_sauce": ("Fish sauce", "🐟", .pantry, []),
        "flat_rice_noodles": ("Flat rice noodles", "🍜", .pantry, ["noodles"]),
        "flour": ("Flour", "🌾", .pantry, []),
        "freekeh": ("Freekeh", "🌾", .pantry, []),
        "fresh_mint": ("Mint", "🌿", .produce, []),
        "fresh_roll": ("Shrimp spring roll", "🥢", .frozen, []),
        "fusilli": ("Fusilli", "🍝", .pantry, ["pasta"]),
        "fusilli_whole": ("Whole-wheat fusilli", "🍝", .pantry, ["pasta"]),
        "garam_masala": ("Garam masala", "🧂", .pantry, []),
        "garlic": ("Garlic", "🧄", .produce, ["garlic"]),
        "ginger": ("Ginger", "🫚", .produce, ["ginger"]),
        "glass_noodles": ("Glass noodles", "🍜", .pantry, ["noodles"]),
        "gnocchi": ("Potato gnocchi", "🥔", .pantry, ["pasta"]),
        "goat_cheese": ("Goat cheese", "🧀", .dairy, ["cheese"]),
        "gochujang": ("Gochujang", "🌶️", .pantry, []),
        "granola": ("Granola", "🥣", .pantry, ["granola"]),
        "green_bean": ("Green beans", "🫛", .produce, ["green_beans"]),
        "green_pepper": ("Green bell pepper", "🫑", .produce, ["bell_pepper", "green_peppers"]),
        "greens": ("Baby greens", "🥬", .produce, ["lettuce"]),
        "ground_beef": ("Lean ground beef", "🥩", .protein, ["ground_beef", "beef"]),
        "ground_pork": ("Ground pork", "🥩", .protein, ["ground_pork", "pork"]),
        "ground_turkey": ("Ground turkey", "🦃", .protein, ["turkey"]),
        "gruyere": ("Gruyère", "🧀", .dairy, ["cheese"]),
        "guanciale": ("Guanciale", "🥓", .protein, []),
        "haddock": ("Haddock fillet", "🐟", .protein, ["haddock", "fish"]),
        "halloumi": ("Halloumi", "🧀", .dairy, ["cheese"]),
        "ham": ("Cooked ham", "🍖", .protein, ["ham"]),
        "hard_cheese": ("Hard cheese", "🧀", .dairy, ["cheese"]),
        "herbs": ("Fresh herbs", "🌿", .produce, []),
        "honey": ("Honey", "🍯", .pantry, ["honey"]),
        "hot_sauce": ("Hot sauce", "🌶️", .pantry, []),
        "hummus": ("Hummus", "🥣", .dairy, ["hummus"]),
        "kale": ("Kale", "🥬", .produce, ["kale"]),
        "kidney_bean": ("Kidney beans", "🫘", .pantry, ["beans"]),
        "lamb": ("Lamb", "🍖", .protein, ["lamb"]),
        "lasagna": ("Lasagna sheets", "🍝", .pantry, ["pasta"]),
        "leek": ("Leek", "🥬", .produce, []),
        "lemon": ("Lemon", "🍋", .produce, ["lemon"]),
        "lemon_juice": ("Lemon juice", "🍋", .produce, ["lemon"]),
        "lemon_zest": ("Lemon zest", "🍋", .produce, ["lemon"]),
        "lemongrass": ("Lemongrass", "🌿", .produce, []),
        "lentil": ("Lentils", "🫘", .pantry, ["lentils"]),
        "lettuce": ("Lettuce", "🥬", .produce, ["lettuce"]),
        "lime": ("Lime", "🍋", .produce, ["lime"]),
        "lime_juice": ("Lime juice", "🍋", .produce, ["lime"]),
        "lime_zest": ("Lime zest", "🍋", .produce, ["lime"]),
        "linguine": ("Linguine", "🍝", .pantry, ["pasta"]),
        "mango": ("Mango", "🥭", .produce, ["mango"]),
        "maple": ("Maple syrup", "🍁", .pantry, ["maple_syrup"]),
        "maple_syrup": ("Maple syrup", "🍁", .pantry, ["maple_syrup"]),
        "mascarpone": ("Mascarpone", "🧀", .dairy, ["cheese"]),
        "mayonnaise": ("Mayonnaise", "🫙", .pantry, ["mayonnaise"]),
        "milk": ("Milk", "🥛", .dairy, ["milk"]),
        "millet": ("Millet", "🌾", .pantry, []),
        "mint": ("Mint", "🌿", .produce, []),
        "miso": ("Miso", "🥣", .pantry, []),
        "mixed_pasta": ("Short pasta", "🍝", .pantry, ["pasta"]),
        "mozzarella": ("Mozzarella", "🧀", .dairy, ["cheese"]),
        "mushroom": ("Mushrooms", "🍄", .produce, ["mushroom"]),
        "mussel": ("Mussels", "🦪", .protein, ["mussels"]),
        "mustard": ("Mustard", "🫙", .pantry, []),
        "naan": ("Naan", "🫓", .bakery, ["naan"]),
        "napa": ("Napa cabbage", "🥬", .produce, ["napa_cabbage"]),
        "noodles": ("Rice noodles", "🍜", .pantry, ["noodles"]),
        "nori": ("Nori", "🟩", .pantry, []),
        "nutmeg": ("Nutmeg", "🧂", .pantry, []),
        "oat": ("Rolled oats", "🥣", .pantry, ["oats"]),
        "oat_cream": ("Oat cooking cream", "🥛", .dairy, []),
        "okra": ("Okra", "🌿", .produce, []),
        "olive": ("Olives", "🫒", .pantry, ["olives"]),
        "olive_oil": ("Olive oil", "🫒", .pantry, ["olive_oil"]),
        "onion": ("Onion", "🧅", .produce, ["onion"]),
        "orange": ("Oranges", "🍊", .produce, ["orange"]),
        "orange_juice": ("Orange juice", "🍊", .pantry, ["fruit_juice"]),
        "orecchiette": ("Orecchiette", "🍝", .pantry, ["pasta"]),
        "oregano": ("Oregano", "🧂", .pantry, []),
        "orzo": ("Orzo", "🍝", .pantry, ["pasta"]),
        "paneer": ("Paneer", "🧀", .dairy, ["cheese"]),
        "pappardelle": ("Pappardelle", "🍝", .pantry, ["pasta"]),
        "paprika": ("Paprika", "🧂", .pantry, []),
        "parmesan": ("Parmesan", "🧀", .dairy, ["cheese"]),
        "parsley": ("Parsley", "🌿", .produce, ["parsley"]),
        "pea": ("Green peas", "🫛", .frozen, ["peas"]),
        "peach": ("Peaches", "🍑", .produce, ["peach"]),
        "peanut": ("Peanuts", "🥜", .pantry, ["peanuts"]),
        "peanut_butter": ("Peanut butter", "🥜", .pantry, ["peanut_butter"]),
        "pear": ("Pears", "🍐", .produce, ["pear"]),
        "peas": ("Green peas", "🫛", .frozen, ["peas"]),
        "pecan": ("Pecans", "🌰", .pantry, []),
        "pecorino": ("Pecorino Romano", "🧀", .dairy, ["cheese"]),
        "penne": ("Penne", "🍝", .pantry, ["pasta"]),
        "penne_whole": ("Whole-wheat penne", "🍝", .pantry, ["pasta"]),
        "pepper": ("Black pepper", "🧂", .pantry, []),
        "phyllo": ("Phyllo pastry", "🥐", .bakery, []),
        "pickle": ("Pickles", "🥒", .pantry, []),
        "pie_crust": ("Pastry crust", "🥧", .bakery, []),
        "pine_nut": ("Pine nuts", "🌰", .pantry, []),
        "pineapple": ("Pineapple", "🍍", .produce, ["pineapple"]),
        "pinto_bean": ("Pinto beans", "🫘", .pantry, ["beans"]),
        "pistachio": ("Pistachios", "🌰", .pantry, []),
        "pita": ("Pita", "🫓", .bakery, ["pita"]),
        "polenta": ("Polenta", "🌽", .pantry, []),
        "pomegranate": ("Pomegranate seeds", "🍎", .produce, ["pomegranate"]),
        "pomelo": ("Pomelo", "🍊", .produce, []),
        "pork": ("Pork tenderloin", "🥩", .protein, ["pork"]),
        "pork_belly": ("Pork belly", "🥓", .protein, ["pork"]),
        "pork_tenderloin": ("Pork tenderloin", "🥩", .protein, ["pork"]),
        "portobello": ("Portobello", "🍄", .produce, ["mushroom"]),
        "potato": ("Potatoes", "🥔", .produce, ["potato"]),
        "provolone": ("Provolone", "🧀", .dairy, ["cheese"]),
        "prune": ("Prunes", "🫐", .pantry, []),
        "pumpkin": ("Squash purée", "🎃", .pantry, []),
        "pumpkin_seed": ("Pumpkin seeds", "🎃", .pantry, []),
        "quinoa": ("Quinoa", "🌾", .pantry, ["quinoa"]),
        "radish": ("Radishes", "🔴", .produce, ["radish"]),
        "ramen": ("Ramen noodles", "🍜", .pantry, ["ramen", "noodles"]),
        "ramen_noodles": ("Ramen noodles", "🍜", .pantry, ["ramen", "noodles"]),
        "rapini": ("Rapini", "🥦", .produce, []),
        "raspberry": ("Raspberries", "🍓", .produce, ["raspberries"]),
        "red_bell_pepper": ("Red bell pepper", "🫑", .produce, ["bell_pepper"]),
        "red_cabbage": ("Red cabbage", "🥬", .produce, ["cabbage"]),
        "red_lentil": ("Red lentils", "🫘", .pantry, ["lentils"]),
        "red_onion": ("Red onion", "🧅", .produce, ["onion"]),
        "red_pepper": ("Red bell pepper", "🫑", .produce, ["bell_pepper"]),
        "rice": ("Rice", "🍚", .pantry, ["rice"]),
        "rice_noodle": ("Rice noodles", "🍜", .pantry, ["noodles"]),
        "rice_round": ("Short-grain rice", "🍚", .pantry, ["rice"]),
        "rice_vermicelli": ("Rice vermicelli", "🍜", .pantry, ["noodles"]),
        "rice_vinegar": ("Rice vinegar", "🫙", .pantry, []),
        "ricotta": ("Ricotta", "🧀", .dairy, ["cheese"]),
        "rigatoni": ("Rigatoni", "🍝", .pantry, ["rigatoni", "pasta"]),
        "rolled_oat": ("Rolled oats", "🥣", .pantry, ["oats"]),
        "romaine": ("Romaine lettuce", "🥬", .produce, ["lettuce"]),
        "rosemary": ("Rosemary", "🌿", .produce, []),
        "saffron": ("Saffron", "🧂", .pantry, []),
        "sage": ("Sage", "🌿", .produce, []),
        "salmon": ("Salmon fillet", "🐟", .protein, ["salmon", "fish"]),
        "salsa": ("Salsa", "🍅", .pantry, ["salsa"]),
        "salt": ("Salt", "🧂", .pantry, []),
        "sardine": ("Canned sardines", "🐟", .protein, ["sardine", "fish"]),
        "scallion": ("Green onions", "🧅", .produce, ["green_onion"]),
        "sea_bass": ("Sea bass fillet", "🐟", .protein, ["fish"]),
        "sesame": ("Sesame seeds", "⚪️", .pantry, []),
        "sesame_oil": ("Sesame oil", "🫗", .pantry, []),
        "sesame_seed": ("Sesame seeds", "⚪️", .pantry, []),
        "shiitake": ("Shiitake", "🍄", .produce, ["mushroom"]),
        "shrimp": ("Shrimp", "🦐", .protein, ["shrimp"]),
        "smoked_salmon": ("Smoked salmon", "🐟", .protein, ["salmon"]),
        "snow_pea": ("Snow peas", "🫛", .produce, []),
        "soba": ("Soba noodles", "🍜", .pantry, ["noodles"]),
        "soy_sauce": ("Soy sauce", "🥢", .pantry, ["soy_sauce"]),
        "spaghetti": ("Spaghetti", "🍝", .pantry, ["pasta"]),
        "spaghetti_whole": ("Whole-wheat spaghetti", "🍝", .pantry, ["pasta"]),
        "spinach": ("Spinach", "🌿", .produce, ["spinach"]),
        "sprouts": ("Alfalfa sprouts", "🌱", .produce, []),
        "squash": ("Butternut squash", "🎃", .produce, ["squash"]),
        "squid": ("Squid", "🦑", .protein, ["squid"]),
        "star_anise": ("Star anise", "🧂", .pantry, []),
        "stock": ("Stock", "🥣", .pantry, ["broth"]),
        "strawberry": ("Strawberries", "🍓", .produce, ["strawberries"]),
        "sugar": ("Sugar", "🧂", .pantry, ["sugar"]),
        "sun_dried_tomato": ("Sun-dried tomatoes", "🍅", .pantry, []),
        "sunflower_seed": ("Sunflower seeds", "🌻", .pantry, []),
        "sushi_rice": ("Sushi rice", "🍚", .pantry, ["rice"]),
        "sweet_potato": ("Sweet potatoes", "🍠", .produce, ["sweet_potato", "potato"]),
        "sweet_potato_noodles": ("Sweet potato noodles", "🍜", .pantry, ["noodles"]),
        "tagliatelle": ("Tagliatelle", "🍝", .pantry, ["pasta"]),
        "tahini": ("Tahini", "🫙", .pantry, []),
        "tamarind": ("Tamarind paste", "🫙", .pantry, []),
        "tempeh": ("Tempeh", "🧈", .protein, ["tempeh"]),
        "thai_basil": ("Thai basil", "🌿", .produce, []),
        "thyme": ("Thyme", "🌿", .produce, []),
        "tofu": ("Firm tofu", "🧈", .protein, ["tofu"]),
        "tomato": ("Tomatoes", "🍅", .produce, ["tomato"]),
        "tomato_paste": ("Tomato paste", "🍅", .pantry, []),
        "tomato_sauce": ("Tomato sauce", "🍅", .pantry, ["pasta_sauce"]),
        "tonnarelli": ("Tonnarelli", "🍝", .pantry, ["pasta"]),
        "toor_dal": ("Toor dal", "🫘", .pantry, ["lentils"]),
        "tortilla": ("Wheat tortilla", "🌮", .bakery, ["tortillas"]),
        "trofie": ("Trofie", "🍝", .pantry, ["pasta"]),
        "trout": ("Trout fillet", "🐟", .protein, ["trout", "fish"]),
        "tuna": ("Canned tuna", "🐟", .protein, ["tuna"]),
        "turkey": ("Turkey", "🦃", .protein, ["turkey"]),
        "turmeric": ("Turmeric", "🧂", .pantry, []),
        "tzatziki": ("Tzatziki", "🥣", .dairy, []),
        "udon": ("Udon noodles", "🍜", .pantry, ["noodles"]),
        "vanilla": ("Vanilla extract", "🫙", .pantry, []),
        "vegetable_broth": ("Vegetable broth", "🥣", .pantry, ["broth"]),
        "vienna_sausage": ("Vienna sausages", "🌭", .protein, ["sausage"]),
        "vinegar": ("Vinegar", "🫙", .pantry, []),
        "vodka": ("Vodka", "🍸", .pantry, []),
        "walnut": ("Walnuts", "🌰", .pantry, ["walnuts"]),
        "water": ("Water", "💧", .pantry, []),
        "wheat_flour": ("Flour", "🌾", .pantry, []),
        "white_bean": ("White beans", "🫘", .pantry, ["beans"]),
        "white_rice": ("White rice", "🍚", .pantry, ["rice"]),
        "white_wine": ("Dry white wine", "🍷", .pantry, []),
        "whole_tortilla": ("Whole-wheat tortilla", "🌮", .bakery, ["tortillas"]),
        "whole_urad": ("Whole urad", "🫘", .pantry, ["lentils"]),
        "whole_wheat_pasta": ("Whole-wheat pasta", "🍝", .pantry, ["pasta"]),
        "whole_wheat_tortilla": ("Whole-wheat tortilla", "🌮", .bakery, ["tortillas"]),
        "wide_rice_noodles": ("Wide rice noodles", "🍜", .pantry, ["noodles"]),
        "wild_rice": ("Wild rice", "🍚", .pantry, ["rice"]),
        "yellow_pepper": ("Yellow bell pepper", "🫑", .produce, ["bell_pepper"]),
        "yogurt": ("Plain yogurt", "🥛", .dairy, ["yogurt", "greek_yogurt_or_skyr"]),
        "zucchini": ("Zucchini", "🥒", .produce, ["zucchini"]),
    ]

    /// Flyer ingredient ids that can discount this catalogue ingredient (always includes itself).
    static func dealIds(for id: String) -> [String] {
        var out = [id]
        for alias in info[id]?.dealIds ?? [] where !out.contains(alias) { out.append(alias) }
        return out
    }
}

/// Price per serving at each banner: average regular price, minus this week's deals at that store.
/// A store with a deal gets a "Deal" tag even when another store is still cheaper overall.
struct StorePricesCard: View {
    let prices: [String: Double]
    let recipe: Recipe
    @Environment(AppStore.self) private var store

    private struct StoreDeal: Identifiable {
        let id: String
        let ingredientId: String
        let deal: Deal
    }

    private struct Row: Identifiable {
        let id: String
        let regular: Double
        let price: Double
        let deals: [StoreDeal]
    }

    private var rows: [Row] {
        let servings = Double(max(recipe.servings, 1))
        let now = Date()
        return prices.map { storeId, regular -> Row in
            var found: [StoreDeal] = []
            var savings = 0.0
            for item in recipe.ingredients {
                let ids = PricingEngine.compatibleDealIds(for: item.ingredientId)
                let candidates = store.deals.filter {
                    $0.retailerId.lowercased() == storeId && ids.contains($0.ingredientId) && $0.validUntil >= now
                }
                let costed: [(Deal, Double?)] = candidates.map { deal in
                    if let c = deal.cost(for: item.quantity, unit: item.unit) { return (deal, c) }
                    if deal.discountPercent != nil, let regularCost = item.estimatedCost { return (deal, regularCost * deal.priceRatio) }
                    return (deal, nil)
                }
                guard let best = costed.min(by: { ($0.1 ?? .infinity) < ($1.1 ?? .infinity) }) else { continue }
                if let sale = best.1, let regularCost = item.estimatedCost { savings += max(0, regularCost - sale) }
                found.append(StoreDeal(id: best.0.id + "|" + item.ingredientId, ingredientId: item.ingredientId, deal: best.0))
            }
            return Row(id: storeId, regular: regular, price: max(0, regular - savings / servings), deals: found)
        }
        .sorted { $0.price < $1.price }
    }

    var body: some View {
        let allRows = self.rows
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Price per serving by store").font(.bw(.title3)).foregroundStyle(BW.ink)
                Text("Average regular prices, with this week's deals applied.")
                    .font(.bw(.caption, weight: .medium)).foregroundStyle(BW.inkSecondary)
            }
            VStack(spacing: 0) {
                ForEach(Array(allRows.enumerated()), id: \.element.id) { idx, row in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            StoreChip(retailerId: row.id, name: RetailerCatalog.name(row.id))
                            if !row.deals.isEmpty {
                                Label("Deal", systemImage: "tag.fill")
                                    .font(.bw(.caption2, weight: .heavy)).foregroundStyle(BW.ink)
                                    .padding(.horizontal, 8).padding(.vertical, 3)
                                    .background(BW.lemon, in: .capsule)
                            }
                            if idx == 0 {
                                Text("Cheapest")
                                    .font(.bw(.caption2, weight: .heavy)).foregroundStyle(BW.leafDeep)
                                    .padding(.horizontal, 8).padding(.vertical, 3)
                                    .background(BW.leafSoft, in: .capsule)
                            }
                            Spacer(minLength: 4)
                            VStack(alignment: .trailing, spacing: 0) {
                                if row.price < row.regular - 0.005 {
                                    Text(Money.format(row.regular))
                                        .font(.bw(.caption, weight: .medium)).monospacedDigit()
                                        .strikethrough().foregroundStyle(BW.inkSecondary)
                                }
                                Text(Money.format(row.price))
                                    .font(.bw(.headline, weight: idx == 0 ? .heavy : .semibold)).monospacedDigit()
                                    .foregroundStyle(idx == 0 || !row.deals.isEmpty ? BW.leafDeep : BW.ink)
                            }
                        }
                        ForEach(row.deals) { d in
                            HStack(alignment: .firstTextBaseline, spacing: 6) {
                                IngredientThumb(ingredientId: d.ingredientId, size: 22)
                                VStack(alignment: .leading, spacing: 1) {
                                    HStack(spacing: 4) {
                                        Text(d.deal.productName).fontWeight(.bold).lineLimit(1)
                                        Text(d.deal.priceText).fontWeight(.heavy).foregroundStyle(BW.leafDeep)
                                        if let was = d.deal.regularPrice, was > d.deal.effectivePrice {
                                            Text("\(Money.format(was))\(d.deal.unitLabel)").strikethrough().foregroundStyle(BW.inkSecondary)
                                        }
                                    }
                                    Text(DealTiming.endText(d.deal.validUntil)).foregroundStyle(BW.amber)
                                }
                            }
                            .font(.bw(.caption, weight: .medium))
                            .foregroundStyle(BW.ink)
                            .padding(.leading, 4)
                        }
                    }
                    .padding(.horizontal, 16).padding(.vertical, 11)
                    .background(row.deals.isEmpty ? Color.clear : BW.lemonSoft.opacity(0.45))
                    if idx < allRows.count - 1 { Divider().overlay(BW.hairline).padding(.leading, 16) }
                }
            }
            .bwCard()
        }
    }
}
