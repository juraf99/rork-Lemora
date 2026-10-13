import SwiftUI

/// Lemora onboarding v2: static data copied from the approved onboarding design
/// (allergen + ingredient lists with French names and synonyms, regional store lists, brand colours).
nonisolated struct OBItem: Hashable, Sendable {
    let id: String
    let en: String
    let fr: String
    let syn: [String]
}

nonisolated struct OBSearchResult: Hashable, Sendable, Identifiable {
    let id: String
    let en: String
    let fr: String
    let via: String?
    let score: Double
}

nonisolated enum OBData {
    static let allergens: [OBItem] = parse("""
peanut|Peanuts|Arachides|peanut,groundnut,cacahuete,peanut butter,beurre d'arachide
tree_nut|Tree Nuts|Noix|nuts,tree nut,fruits a coque
almond|Almonds|Amandes|almond
cashew|Cashews|Noix de cajou|cashew,cajou
walnut|Walnuts|Noix de Grenoble|walnut
pecan|Pecans|Pacanes|pecan
pistachio|Pistachios|Pistaches|pistachio
hazelnut|Hazelnuts|Noisettes|filbert,hazelnut
macadamia|Macadamia Nuts|Noix de macadamia|
brazil_nut|Brazil Nuts|Noix du Bresil|
milk|Milk|Lait|dairy,lactose,produits laitiers,casein,caseine,whey,lactoserum
egg|Eggs|Oeufs|egg,oeuf,œuf,œufs
wheat|Wheat|Ble|blé
gluten|Gluten|Gluten|celiac,coeliaque,barley,orge,rye,seigle
soy|Soy|Soja|soya,soybean,tofu,edamame
fish|Fish|Poisson|poissons
shellfish|Shellfish|Crustaces|crustacean,crustacés,seafood,fruits de mer
shrimp|Shrimp|Crevettes|prawn,crevette
crab|Crab|Crabe|
lobster|Lobster|Homard|
mollusc|Molluscs|Mollusques|mollusk
clam|Clams|Palourdes|
mussel|Mussels|Moules|
oyster|Oysters|Huitres|huîtres
scallop|Scallops|Petoncles|pétoncles,saint-jacques
squid|Squid|Calmar|calamari
sesame|Sesame|Sesame|sésame,tahini
mustard|Mustard|Moutarde|
celery|Celery|Celeri|céleri
lupin|Lupin|Lupin|
sulphite|Sulphites|Sulfites|sulfite
corn|Corn|Mais|maïs,maize
pea|Peas|Pois|green peas,petits pois
pea_protein|Pea Protein|Proteine de pois|protéine de pois
lentil|Lentils|Lentilles|
chickpea|Chickpeas|Pois chiches|garbanzo
buckwheat|Buckwheat|Sarrasin|
kiwi|Kiwi|Kiwi|
coconut|Coconut|Noix de coco|
peach|Peaches|Peches|pêches
strawberry|Strawberries|Fraises|
banana|Bananas|Bananes|
avocado|Avocado|Avocat|
garlic|Garlic|Ail|
""")

    static let ingredients: [OBItem] = parse("""
mushroom|Mushroom|Champignon|mushrooms,champignons,button mushroom
mushroom_powder|Mushroom Powder|Poudre de champignon|
shiitake|Shiitake Mushroom|Shiitake|
portobello|Portobello Mushroom|Portobello|
mustard|Mustard|Moutarde|dijon
mustard_greens|Mustard Greens|Feuilles de moutarde|
olive|Olives|Olives|olive
onion|Onion|Oignon|onions,oignons
red_onion|Red Onion|Oignon rouge|
green_onion|Green Onion|Oignon vert|scallion,echalote verte
shallot|Shallot|Echalote|échalote
garlic|Garlic|Ail|
tomato|Tomato|Tomate|tomatoes,tomates
cherry_tomato|Cherry Tomatoes|Tomates cerises|
sun_dried_tomato|Sun-Dried Tomatoes|Tomates sechees|
cilantro|Cilantro|Coriandre|coriander
parsley|Parsley|Persil|
basil|Basil|Basilic|
dill|Dill|Aneth|
mint|Mint|Menthe|
rosemary|Rosemary|Romarin|
thyme|Thyme|Thym|
bell_pepper|Bell Pepper|Poivron|sweet pepper,capsicum,poivrons
jalapeno|Jalapeno|Jalapeno|jalapeño
chili|Chili Pepper|Piment|hot pepper,chile
eggplant|Eggplant|Aubergine|brinjal
zucchini|Zucchini|Courgette|courgette
cucumber|Cucumber|Concombre|
pickle|Pickles|Cornichons|gherkin,dill pickle
avocado|Avocado|Avocat|guacamole
beet|Beets|Betteraves|beetroot
carrot|Carrot|Carotte|
celery|Celery|Celeri|céleri
broccoli|Broccoli|Brocoli|
cauliflower|Cauliflower|Chou-fleur|
brussels|Brussels Sprouts|Choux de Bruxelles|
cabbage|Cabbage|Chou|
kale|Kale|Chou frise|chou frisé
spinach|Spinach|Epinards|épinards
lettuce|Lettuce|Laitue|
arugula|Arugula|Roquette|rocket
asparagus|Asparagus|Asperges|
artichoke|Artichoke|Artichaut|
okra|Okra|Gombo|
peas|Peas|Petits pois|green peas
corn|Corn|Mais|maïs,sweetcorn
sweet_potato|Sweet Potato|Patate douce|yam
potato|Potato|Pomme de terre|patate
radish|Radish|Radis|
turnip|Turnip|Navet|
fennel|Fennel|Fenouil|
leek|Leek|Poireau|
ginger|Ginger|Gingembre|
tofu|Tofu|Tofu|bean curd
tempeh|Tempeh|Tempeh|
seitan|Seitan|Seitan|
chickpea|Chickpeas|Pois chiches|garbanzo
lentil|Lentils|Lentilles|
black_bean|Black Beans|Haricots noirs|
kidney_bean|Kidney Beans|Haricots rouges|
edamame|Edamame|Edamame|
quinoa|Quinoa|Quinoa|
couscous|Couscous|Couscous|
rice|Rice|Riz|
pasta|Pasta|Pates|pâtes
chicken|Chicken|Poulet|
beef|Beef|Boeuf|bœuf
ground_beef|Ground Beef|Boeuf hache|hamburger meat
pork|Pork|Porc|
bacon|Bacon|Bacon|
ham|Ham|Jambon|
sausage|Sausage|Saucisse|
lamb|Lamb|Agneau|
veal|Veal|Veau|
turkey|Turkey|Dinde|
duck|Duck|Canard|
liver|Liver|Foie|offal,abats
salmon|Salmon|Saumon|
tuna|Tuna|Thon|
cod|Cod|Morue|
tilapia|Tilapia|Tilapia|
sardine|Sardines|Sardines|
anchovy|Anchovies|Anchois|
shrimp|Shrimp|Crevettes|prawn
crab|Crab|Crabe|
lobster|Lobster|Homard|
mussel|Mussels|Moules|
oyster|Oysters|Huitres|huîtres
scallop|Scallops|Petoncles|pétoncles
squid|Squid|Calmar|calamari
seafood|Seafood|Fruits de mer|
egg|Eggs|Oeufs|œufs,oeuf
milk|Milk|Lait|
cream|Cream|Creme|crème
butter|Butter|Beurre|
yogurt|Yogurt|Yogourt|yoghurt,yaourt
cheese|Cheese|Fromage|
blue_cheese|Blue Cheese|Fromage bleu|roquefort,gorgonzola
goat_cheese|Goat Cheese|Fromage de chevre|chèvre
feta|Feta|Feta|
cottage_cheese|Cottage Cheese|Fromage cottage|
mayo|Mayonnaise|Mayonnaise|mayo
ketchup|Ketchup|Ketchup|
vinegar|Vinegar|Vinaigre|
soy_sauce|Soy Sauce|Sauce soya|
fish_sauce|Fish Sauce|Sauce de poisson|nuoc mam
coconut|Coconut|Noix de coco|coconut milk,lait de coco
peanut_butter|Peanut Butter|Beurre d'arachide|
almond|Almonds|Amandes|
walnut|Walnuts|Noix|
raisin|Raisins|Raisins secs|
banana|Banana|Banane|
apple|Apple|Pomme|
pineapple|Pineapple|Ananas|
mango|Mango|Mangue|
papaya|Papaya|Papaye|
grapefruit|Grapefruit|Pamplemousse|
lemon|Lemon|Citron|
lime|Lime|Lime|citron vert
orange|Orange|Orange|
strawberry|Strawberries|Fraises|
blueberry|Blueberries|Bleuets|myrtilles
raspberry|Raspberries|Framboises|
cranberry|Cranberries|Canneberges|
date|Dates|Dattes|
fig|Figs|Figues|
cinnamon|Cinnamon|Cannelle|
cumin|Cumin|Cumin|
curry|Curry Powder|Poudre de cari|curry
paprika|Paprika|Paprika|
turmeric|Turmeric|Curcuma|
nutmeg|Nutmeg|Muscade|
licorice|Licorice|Reglisse|anise,anis,réglisse
caper|Capers|Capres|câpres
spicy|Spicy Food|Nourriture epicee|hot,piquant,spicy,épicé
chocolate|Chocolate|Chocolat|
honey|Honey|Miel|
maple|Maple Syrup|Sirop d'erable|sirop d'érable
sugar|Added Sugar|Sucre ajoute|sucre
""")

    static func parse(_ s: String) -> [OBItem] {
        s.split(separator: "\n").compactMap { line in
            let parts = line.split(separator: "|", omittingEmptySubsequences: false).map(String.init)
            guard parts.count >= 3 else { return nil }
            let syn = parts.count > 3 ? parts[3].split(separator: ",").map(String.init).filter { !$0.isEmpty } : []
            return OBItem(id: parts[0], en: parts[1], fr: parts[2], syn: syn)
        }
    }

    static func norm(_ s: String) -> String {
        s.lowercased()
            .replacingOccurrences(of: "œ", with: "oe")
            .folding(options: [.diacriticInsensitive], locale: nil)
            .trimmingCharacters(in: .whitespaces)
    }

    static func lev(_ a: String, _ b: String) -> Int {
        let a = Array(a), b = Array(b)
        if a.isEmpty { return b.count }
        if b.isEmpty { return a.count }
        var prev = Array(0...b.count)
        for i in 1...a.count {
            var cur = [i] + Array(repeating: 0, count: b.count)
            for j in 1...b.count {
                cur[j] = min(prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + (a[i - 1] == b[j - 1] ? 0 : 1))
            }
            prev = cur
        }
        return prev[b.count]
    }

    /// Same ranking as the design: exact > prefix > word prefix > contains > fuzzy; synonyms/French slightly lower.
    static func search(_ db: [OBItem], _ query: String, limit: Int = 6) -> [OBSearchResult] {
        let q = norm(query)
        guard !q.isEmpty else { return [] }
        var out: [OBSearchResult] = []
        for it in db {
            var best: Double = 0
            var via: String? = nil
            let terms: [(String, Bool)] = [(it.en, false), (it.fr, true)] + it.syn.map { ($0, true) }
            for (raw, alt) in terms {
                let t = norm(raw)
                var sc: Double = 0
                if t == q { sc = 120 }
                else if t.hasPrefix(q) { sc = 100 - min(20, Double(t.count - q.count) * 0.6) }
                else if t.split(whereSeparator: { $0 == " " || $0 == "-" || $0 == "'" }).contains(where: { $0.hasPrefix(q) }) { sc = 80 }
                else if t.contains(q) { sc = 60 }
                else if q.count >= 3 && lev(q, String(t.prefix(q.count))) <= (q.count > 5 ? 2 : 1) { sc = 40 }
                if alt { sc -= 4 }
                if sc > best { best = sc; via = alt ? raw : nil }
            }
            if best > 0 { out.append(OBSearchResult(id: it.id, en: it.en, fr: it.fr, via: via, score: best)) }
        }
        return Array(out.sorted { $0.score != $1.score ? $0.score > $1.score : $0.en.count < $1.en.count }.prefix(limit))
    }

    static let stores: [String: [String: [String]]] = [
        "CA": [
            "QC": ["Maxi", "Metro", "Super C", "IGA", "Provigo", "Walmart", "Costco", "Adonis", "Loblaws"],
            "ON": ["No Frills", "Loblaws", "Metro", "FreshCo", "Food Basics", "Sobeys", "Walmart", "Costco", "T&T"],
            "WEST": ["Save-On-Foods", "Safeway", "Sobeys", "No Frills", "Walmart", "Costco", "T&T", "Loblaws"],
            "ANY": ["Walmart", "Costco", "Sobeys", "No Frills", "Loblaws", "Metro", "IGA", "Safeway"]
        ],
        "US": [
            "TX": ["H-E-B", "Walmart", "Kroger", "Costco", "Target", "Aldi", "Whole Foods", "Sam’s Club", "Trader Joe’s"],
            "SE": ["Publix", "Walmart", "Kroger", "Aldi", "Target", "Costco", "Food Lion", "Whole Foods", "Sam’s Club"],
            "NE": ["ShopRite", "Wegmans", "Walmart", "Target", "Costco", "Trader Joe’s", "Whole Foods", "Aldi", "Stop & Shop"],
            "MW": ["Meijer", "Kroger", "Walmart", "Aldi", "Target", "Costco", "Sam’s Club", "Whole Foods"],
            "W": ["Safeway", "Albertsons", "Walmart", "Costco", "Target", "Trader Joe’s", "Whole Foods", "Kroger"],
            "ANY": ["Walmart", "Target", "Costco", "Kroger", "Aldi", "Safeway", "Publix", "Trader Joe’s", "Whole Foods"]
        ],
        "AU": [
            "ANY": ["Woolworths", "Coles", "Aldi", "IGA", "Costco", "Harris Farm"]
        ]
    ]

    static let storesMore: [String: [String: [String]]] = [
        "CA": [
            "QC": ["Avril", "Rachelle-Béry", "Marché Tau", "Intermarché", "Marchés Richelieu", "PA Supermarché", "Kim Phat", "Mayrand", "Segal’s Market", "Marché Jean-Talon", "Giant Tiger", "Bulk Barn"],
            "ON": ["Farm Boy", "Longo’s", "Fortinos", "Zehrs", "Galleria", "Nations Fresh Foods", "Oceans", "Highland Farms", "Giant Tiger", "Bulk Barn", "H Mart", "Real Canadian Superstore"],
            "WEST": ["Co-op", "Choices Markets", "Nesters Market", "Urban Fare", "Thrifty Foods", "Buy-Low Foods", "Real Canadian Superstore", "H Mart", "Giant Tiger", "Bulk Barn"],
            "ANY": ["Giant Tiger", "Real Canadian Superstore", "Farm Boy", "Co-op", "Bulk Barn", "H Mart", "Longo’s", "Avril"]
        ],
        "US": [
            "TX": ["Central Market", "Fiesta Mart", "Sprouts", "Brookshire’s", "Randalls", "Tom Thumb", "H Mart", "99 Ranch", "Lidl"],
            "SE": ["Winn-Dixie", "Harris Teeter", "Ingles", "Lidl", "Sprouts", "The Fresh Market", "Piggly Wiggly", "Earth Fare", "H Mart"],
            "NE": ["Market Basket", "Hannaford", "Giant", "Price Chopper", "Lidl", "H Mart", "Fairway", "Big Y", "Sprouts"],
            "MW": ["Hy-Vee", "Jewel-Osco", "Schnucks", "Festival Foods", "Woodman’s", "Mariano’s", "Dierbergs", "Fareway", "Lidl"],
            "W": ["Sprouts", "WinCo", "Raley’s", "Fred Meyer", "Smart & Final", "Grocery Outlet", "99 Ranch", "Stater Bros.", "New Seasons"],
            "ANY": ["Sprouts", "Lidl", "Grocery Outlet", "WinCo", "H Mart", "99 Ranch", "Hy-Vee", "Market Basket"]
        ],
        "AU": [
            "ANY": ["FoodWorks", "Drakes", "Foodland", "Romeo’s", "Spar", "Friendly Grocer"]
        ]
    ]

    static func regionOf(country: String, code: String) -> (key: String, name: String) {
        let c = code.uppercased().trimmingCharacters(in: .whitespaces)
        guard let first = c.first else { return country == "CA" ? ("ANY", "Canada") : country == "AU" ? ("ANY", "Australia") : ("ANY", "United States") }
        if country == "AU" {
            let states: [Character: String] = ["0": "Northern Territory", "1": "New South Wales", "2": "New South Wales", "3": "Victoria", "4": "Queensland",
                                               "5": "South Australia", "6": "Western Australia", "7": "Tasmania", "8": "Victoria", "9": "Queensland"]
            if c.hasPrefix("26") || c.hasPrefix("29") { return ("ANY", "Canberra") }
            return ("ANY", states[first] ?? "Australia")
        }
        if country == "CA" {
            if "HGJ".contains(first) { return ("QC", "Québec") }
            if "KLMNP".contains(first) { return ("ON", "Ontario") }
            if "VT".contains(first) { return ("WEST", first == "V" ? "British Columbia" : "Alberta") }
            return ("ANY", "Canada")
        }
        if first == "7" { return ("TX", "Texas area") }
        if "23".contains(first) { return ("SE", "Southeast") }
        if "01".contains(first) { return ("NE", "Northeast") }
        if "456".contains(first) { return ("MW", "Midwest") }
        if "89".contains(first) { return ("W", "West") }
        return ("ANY", "United States")
    }

    /// Store brand colours: (background, foreground).
    static let brand: [String: (UInt32, UInt32)] = [
        "Maxi": (0xFFD200, 0x0055A5),
        "Metro": (0xE30613, 0xFFFFFF),
        "Super C": (0xFFD500, 0xE30613),
        "IGA": (0xE4002B, 0xFFFFFF),
        "Provigo": (0xF58220, 0xFFFFFF),
        "Walmart": (0x0071CE, 0xFFC220),
        "Costco": (0x005DAA, 0xE31837),
        "Adonis": (0x00843D, 0xFFFFFF),
        "Loblaws": (0xF47B20, 0xFFFFFF),
        "No Frills": (0xFFE600, 0x1A1A1A),
        "FreshCo": (0x8CC63F, 0xFFFFFF),
        "Food Basics": (0xFFD100, 0x00833E),
        "Sobeys": (0x00553D, 0xFFFFFF),
        "T&T": (0xE60012, 0xFFFFFF),
        "Save-On-Foods": (0xE31937, 0xFFFFFF),
        "Safeway": (0xE31837, 0xFFFFFF),
        "Target": (0xCC0000, 0xFFFFFF),
        "Kroger": (0x134B97, 0xFFFFFF),
        "H-E-B": (0xEE3124, 0xFFFFFF),
        "Aldi": (0x00005F, 0xF9B200),
        "Woolworths": (0x178841, 0xFFFFFF),
        "Coles": (0xE01A22, 0xFFFFFF),
        "Harris Farm": (0x1E5631, 0xFFFFFF),
        "Whole Foods": (0x00674B, 0xFFFFFF),
        "Sam’s Club": (0x0067A0, 0xFFFFFF),
        "Trader Joe’s": (0xD21242, 0xFFFFFF),
        "Publix": (0x3F8F29, 0xFFFFFF),
        "Food Lion": (0x005DAA, 0xFDB913),
        "Wegmans": (0x1A1A1A, 0xFFFFFF),
        "ShopRite": (0xE31837, 0xFFFFFF),
        "Stop & Shop": (0xE31837, 0xFFFFFF),
        "Meijer": (0xE31837, 0xFFFFFF),
        "Albertsons": (0x0073CF, 0xFFFFFF),
        "Avril": (0x7AB648, 0xFFFFFF),
        "Rachelle-Béry": (0x5E8C31, 0xFFFFFF),
        "Marché Tau": (0x00843D, 0xFFFFFF),
        "Intermarché": (0xE2001A, 0xFFFFFF),
        "Marchés Richelieu": (0xC8102E, 0xFFFFFF),
        "PA Supermarché": (0xE31E24, 0xFFFFFF),
        "Kim Phat": (0xD71920, 0xFFD200),
        "Mayrand": (0x003DA5, 0xFFFFFF),
        "Segal’s Market": (0x1D4F91, 0xFFFFFF),
        "Marché Jean-Talon": (0x2E7D32, 0xFFFFFF),
        "Giant Tiger": (0xE31837, 0xFFFFFF),
        "Bulk Barn": (0x0B6E3B, 0xFFD200),
        "Farm Boy": (0x006A4E, 0xFFFFFF),
        "Longo’s": (0x00843D, 0xFFFFFF),
        "Fortinos": (0xE31837, 0xFFFFFF),
        "Zehrs": (0xE31837, 0xFFFFFF),
        "Galleria": (0x1E3A8A, 0xFFFFFF),
        "Nations Fresh Foods": (0x111111, 0xFFFFFF),
        "Oceans": (0x0072BC, 0xFFFFFF),
        "Highland Farms": (0x00843D, 0xFFFFFF),
        "H Mart": (0xE31837, 0xFFFFFF),
        "Real Canadian Superstore": (0xE31837, 0xFFFFFF),
        "Co-op": (0x0055A5, 0xFFFFFF),
        "Choices Markets": (0x5B8C2A, 0xFFFFFF),
        "Nesters Market": (0xC8102E, 0xFFFFFF),
        "Urban Fare": (0x1A1A1A, 0xFFFFFF),
        "Thrifty Foods": (0xE31837, 0xFFFFFF),
        "Buy-Low Foods": (0xE31837, 0xFFD200),
        "Central Market": (0x8B1A1A, 0xFFFFFF),
        "Fiesta Mart": (0xE31837, 0xFFD200),
        "Sprouts": (0x5A8F29, 0xFFFFFF),
        "Brookshire’s": (0xC8102E, 0xFFFFFF),
        "Randalls": (0xE31837, 0xFFFFFF),
        "Tom Thumb": (0xE31837, 0xFFFFFF),
        "99 Ranch": (0xE31837, 0xFFFFFF),
        "Lidl": (0x0050AA, 0xFFF000),
        "Winn-Dixie": (0xE31837, 0xFFFFFF),
        "Harris Teeter": (0x00843D, 0xFFFFFF),
        "Ingles": (0xE31837, 0xFFFFFF),
        "The Fresh Market": (0x00533E, 0xFFFFFF),
        "Piggly Wiggly": (0xE31837, 0xFFFFFF),
        "Earth Fare": (0x5B8C2A, 0xFFFFFF),
        "Market Basket": (0xE31837, 0xFFFFFF),
        "Hannaford": (0xE31837, 0xFFFFFF),
        "Giant": (0x6C2C91, 0xFFFFFF),
        "Price Chopper": (0xE31837, 0xFFFFFF),
        "Fairway": (0x1A1A1A, 0xFFFFFF),
        "Big Y": (0xE31837, 0xFFFFFF),
        "Hy-Vee": (0xE31837, 0xFFFFFF),
        "Jewel-Osco": (0xE31837, 0xFFFFFF),
        "Schnucks": (0xE31837, 0xFFFFFF),
        "Festival Foods": (0x00843D, 0xFFFFFF),
        "Woodman’s": (0xE31837, 0xFFFFFF),
        "Mariano’s": (0x1A1A1A, 0xFFFFFF),
        "Dierbergs": (0x00533E, 0xFFFFFF),
        "Fareway": (0xE31837, 0xFFFFFF),
        "WinCo": (0xE31837, 0xFFD200),
        "Raley’s": (0xE31837, 0xFFFFFF),
        "Fred Meyer": (0x0055A5, 0xFFFFFF),
        "Smart & Final": (0xE31837, 0xFFFFFF),
        "Grocery Outlet": (0x00843D, 0xFFFFFF),
        "Stater Bros.": (0xE31837, 0xFFFFFF),
        "New Seasons": (0x00843D, 0xFFFFFF)
    ]
}
