import SwiftUI
import UIKit

/// Clean photos of fresh foods, shipped in the app (Resources/FoodPhotos/food-<type>.webp).
/// They replace every food emoji: a food is shown with a real photo or a calm aisle icon, never an emoji.
nonisolated enum FoodPhotos {
    /// Recipe ingredient id -> photo type (only when the photo shows exactly that food).
    static let typeForIngredient: [String: String] = [
        "acorn_squash": "squash",
        "asparagus": "asparagus",
        "avocado": "avocado",
        "beef_minced": "beef_ground_lean",
        "beet": "beet",
        "broccoli": "broccoli",
        "brussels_sprout": "brussels",
        "cabbage": "cabbage",
        "carrot": "carrot",
        "carrot_purple": "carrot",
        "cauliflower": "cauliflower",
        "celery": "celery",
        "chicken": "chicken_breast",
        "chicken_breast": "chicken_breast",
        "chicken_leg": "chicken_leg",
        "cod": "cod",
        "cooked_beet": "beet",
        "corn": "corn",
        "crab": "crab",
        "cucumber": "cucumber",
        "eggplant": "eggplant",
        "flank_steak": "beef_steak",
        "ground_beef": "beef_ground_lean",
        "ground_pork": "pork_ground",
        "ground_turkey": "turkey_ground",
        "kale": "kale",
        "leek": "leek",
        "lettuce": "lettuce",
        "mushroom": "mushroom",
        "onion": "onion",
        "orange": "orange",
        "peach": "peach",
        "pear": "pear",
        "pork": "pork_tenderloin",
        "pork_tenderloin": "pork_tenderloin",
        "potato": "potato",
        "radish": "radish",
        "red_onion": "onion_red",
        "romaine": "lettuce_romaine",
        "salmon": "salmon_fillet",
        "scallion": "onion_green",
        "snow_pea": "snap_peas",
        "spinach": "spinach",
        "strawberry": "strawberries",
        "tomato": "tomato",
        "trout": "trout",
    ]

    /// Photo URLs used by the deals feed for a kind of fresh food -> the same photo bundled in the app.
    static let typeForURL: [String: String] = [
        "https://cdn.epiceries.ca/94080_KG_ml_primary_front_NA_042222_VOILA_ef721d10a01e0d8c2dba76d7747c652589630af6.JPG": "asparagus",
        "https://cdn.epiceries.ca/21097012001_fr_front_1200.png": "avocado",
        "https://cdn.epiceries.ca/21634501_fr_front_1200.png": "basa",
        "https://cdn.epiceries.ca/13784218304542.jpg": "beef_ground",
        "https://cdn.epiceries.ca/14902377119774.jpg": "beef_ground_lean",
        "https://cdn.epiceries.ca/13556175536158.jpg": "beef_roast",
        "https://cdn.epiceries.ca/21623567_fr_front_1200.png": "beef_steak",
        "https://cdn.epiceries.ca/14977867186206.jpg": "beef_stew",
        "https://cdn.epiceries.ca/8422_EA_ml_primary_front_VOILA_8e6507c33e2f159c08b58d0e0a23e70329517e56.JPG": "beet",
        "https://cdn.epiceries.ca/212932_EA_ml_primary_front_na_VOILA_38df6bc67b589f600ca27dc167fe03131b8ad44f.JPG": "blackberries",
        "https://cdn.epiceries.ca/073574810108_VOILA_d4a5c4a46b40d4f6d1434ca0035529053b9d41e1.JPG": "broccoli",
        "https://cdn.epiceries.ca/6000198711543.jpg": "brussels",
        "https://cdn.epiceries.ca/20125182001_fr_front_1200.png": "cabbage",
        "https://cdn.epiceries.ca/8874230054942.jpg": "cantaloupe",
        "https://cdn.epiceries.ca/7898_EA_ml_primary_front_VOILA_46ec1be169757c676f4e500c69e4aa6362dee572.JPG": "carrot",
        "https://cdn.epiceries.ca/4572_7952_VOILA_5598898a6e78b4fdeb202294f72ea59d0a67d70f.JPG": "cauliflower",
        "https://cdn.epiceries.ca/033383653211_7956_VOILA_ec3279cdc2d572343b4e9e1705e6f70514e01de9.JPG": "celery",
        "https://cdn.epiceries.ca/6000209842736.jpg": "chicken_breast",
        "https://cdn.epiceries.ca/8886525689886.jpg": "chicken_drumstick",
        "https://cdn.epiceries.ca/8886644408350.jpg": "chicken_leg",
        "https://cdn.epiceries.ca/9233855741982.jpg": "chicken_thigh",
        "https://cdn.epiceries.ca/20036193_enfr_front_v1_1200.png": "chicken_whole",
        "https://cdn.epiceries.ca/338999_KG_ml_primary_front_NA_VOILA_3d44ed263e743343823cbfdaa6ab3c78030fcfec.JPG": "clementine",
        "https://cdn.epiceries.ca/12699460534302.jpg": "cod",
        "https://cdn.epiceries.ca/20131170001_fr_front_1200.png": "corn",
        "https://cdn.epiceries.ca/20084917_fr_front_1200.png": "crab",
        "https://cdn.epiceries.ca/94593_VOILA_88bb79ec46fc872af1d4f080d3735a38fabf77df.JPG": "cucumber",
        "https://cdn.epiceries.ca/7992_KG_ml_primary_front_VOILA_643e50a7d77771d329c18fad42503999b146fcd8.JPG": "eggplant",
        "https://cdn.epiceries.ca/4023_7664_VOILA_364fd490f89096e491e708e6302a6d6afb17122f.JPG": "grapes",
        "https://cdn.epiceries.ca/204066000008_VOILA_bc66c6460a0390a9c8d8f83a6c06b5c980080150.JPG": "green_beans",
        "https://cdn.epiceries.ca/4627_8451_VOILA_6b36188f868be7fcd1ac1d7ef0278afaa88d6a99.JPG": "kale",
        "https://cdn.epiceries.ca/163812_EA_ml_front_VOILA_468ed3a7e1a25241d2a77fcd755978df39419ee1.JPG": "kiwi",
        "https://cdn.epiceries.ca/7047_EA_ml_primary_front_VOILA_ddf79c87c3553c42a2c7083d48e5b7e848b8342a.JPG": "leek",
        "https://cdn.epiceries.ca/16228109058078.jpg": "lettuce",
        "https://cdn.epiceries.ca/20065036001_fr_front_1200.png": "lettuce_romaine",
        "https://cdn.epiceries.ca/575619_EA_ml_primary_front_NA_061622_VOILA_520125ebca188e44a2577c52effb215128e875fa.JPG": "melon_honeydew",
        "https://cdn.epiceries.ca/112842_EA_ml_primary_front_na_VOILA_a06a8e62e69c400782a352202eb41ef8ac4e1618.JPG": "mushroom",
        "https://cdn.epiceries.ca/130657_EA_ml_front_VOILA_3eb5df09dfac40a856bb0f250a0d5ae9fe105044.JPG": "onion",
        "https://cdn.epiceries.ca/4068_8046_VOILA_eeb1d9313a72d006e58461d45649e9d7ca407fe6.JPG": "onion_green",
        "https://cdn.epiceries.ca/112710_EA_ml_primary_front_na_120621_VOILA_bf211495d8c25a8c5348272d1b5ed84ad54eddf4.JPG": "onion_red",
        "https://cdn.epiceries.ca/207105_EA_ml_primary_front_VOILA_76c4be512431b0dc2e8b65c2178cd25c794a6ec1.JPG": "orange",
        "https://cdn.epiceries.ca/20002646001_fr_front_1200.png": "peach",
        "https://cdn.epiceries.ca/20172240001_fr_front_1200.png": "pear",
        "https://cdn.epiceries.ca/5050372116002_VOILA_b864fb6f845b3f3714e75c864cb6e73abd47c38e.JPG": "pineapple",
        "https://cdn.epiceries.ca/1002146_KG_ml_primary_front_NA_VOILA_7a4f117130902a25ead3eb522ec2bd5f30c94978.JPG": "pork_ground",
        "https://cdn.epiceries.ca/9053250912286.jpg": "pork_loin",
        "https://cdn.epiceries.ca/213243000007_131885_VOILA_2dd2b272e49ccbc94d4cf59d5286a93025f5ea54.JPG": "pork_ribs",
        "https://cdn.epiceries.ca/44758_KG_ml_primary_front_na_VOILA_b7d880d4a868be4f34344aa2b0625cf77eaff61a.JPG": "pork_shoulder",
        "https://cdn.epiceries.ca/213262000002_567628_VOILA_5f2c1586fbed5ea579494f94158bd6454f1d319b.JPG": "pork_tenderloin",
        "https://cdn.epiceries.ca/21105450001_enfr_front_v1_1200.png": "potato",
        "https://cdn.epiceries.ca/2217_KG_ml_primary_front_NA_VOILA_6fd2e8297d7c29cf29fad923260d84b56bc78685.JPG": "potato_baby",
        "https://cdn.epiceries.ca/256206_EA_ml_primary_front_NA_052523_VOILA_44a92d80b66a847cfb1c37989631212a6eadd88b.JPG": "radish",
        "https://cdn.epiceries.ca/14020977098782.jpg": "salmon_fillet",
        "https://cdn.epiceries.ca/16448898826270.jpg": "scallops",
        "https://cdn.epiceries.ca/679295000837.jpg": "snap_peas",
        "https://cdn.epiceries.ca/7668_EA_ml_primary_front_VOILA_e2ce5b79d92ab22a36ca65add6bb1c05073cfa90.JPG": "spinach",
        "https://cdn.epiceries.ca/45275_KG_ml_primary_front_NA_VOILA_b61825443b11b265a43c0d3b1ea3cbf028756620.JPG": "squash",
        "https://cdn.epiceries.ca/7633_EA_ml_front_VOILA_f608aa6638a457687945b371eeb39a940008cf09.JPG": "strawberries",
        "https://cdn.epiceries.ca/20897812_fr_front_1200.png": "tilapia",
        "https://cdn.epiceries.ca/8136_KG_ml_primary_top_na_100422_VOILA_9ee634be63c229f80dc8e7812ce9b26aa01ba403.JPG": "tomato",
        "https://cdn.epiceries.ca/139325_KG_ml_primary_front_NA_042222_VOILA_69099092cc2615e88ad9373937e053c9f44cc5eb.JPG": "tomato_heirloom",
        "https://cdn.epiceries.ca/20143381001_enfr_front_v1_1200.png": "tomato_roma",
        "https://cdn.epiceries.ca/20127917001_fr_front_1200.png": "tomato_vine",
        "https://cdn.epiceries.ca/13132122226718.jpg": "trout",
        "https://cdn.epiceries.ca/6000202032768.jpg": "turkey_ground",
        "https://cdn.epiceries.ca/21459601_fr_front_1200.png": "veal",
        "https://cdn.epiceries.ca/3421_VOILA_d622e10a60f6fd88f00dbba0db8c867bdb9f7db1.JPG": "watermelon",
    ]

    private static let cache = NSCache<NSString, UIImage>()

    static func image(forType type: String) -> UIImage? {
        if let hit = cache.object(forKey: type as NSString) { return hit }
        guard let url = Bundle.main.url(forResource: "food-\(type)", withExtension: "webp"),
              let image = UIImage(contentsOfFile: url.path) else { return nil }
        cache.setObject(image, forKey: type as NSString)
        return image
    }

    static func image(forIngredient id: String) -> UIImage? {
        typeForIngredient[id].flatMap(image(forType:))
    }

    static func bundledImage(for url: URL?) -> UIImage? {
        guard let url else { return nil }
        return typeForURL[url.absoluteString].flatMap(image(forType:))
    }

    static func category(_ id: String) -> GroceryCategory {
        IngredientCatalog.all[id]?.category ?? CatalogIngredientInfo.info[id]?.category ?? .other
    }
}

/// Small round ingredient picture: a real photo when we have one, otherwise the aisle icon.
struct IngredientThumb: View {
    let ingredientId: String
    var size: CGFloat = 32

    var body: some View {
        ZStack {
            Circle().fill(Color.white)
            if let image = FoodPhotos.image(forIngredient: ingredientId) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .padding(size * 0.1)
            } else {
                Image(systemName: FoodPhotos.category(ingredientId).symbol)
                    .font(.system(size: size * 0.42, weight: .semibold))
                    .foregroundStyle(BW.leafDeep)
            }
        }
        .frame(width: size, height: size)
        .clipShape(.circle)
        .overlay(Circle().stroke(BW.ink.opacity(0.08), lineWidth: 0.5))
        .accessibilityHidden(true)
    }
}

/// Product photo for a deal or a shelf price, shown whole on white (packshots are never cropped).
struct ProductPhoto: View {
    let url: URL?
    let category: GroceryCategory
    @State private var image: UIImage?

    init(url: URL?, category: GroceryCategory) {
        self.url = url
        self.category = category
        _image = State(initialValue: FoodPhotos.bundledImage(for: url) ?? url.flatMap { RemoteImagePipeline.shared.immediate($0) })
    }

    var body: some View {
        ZStack {
            Color.white
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .padding(10)
                    .transition(.opacity)
            } else {
                Image(systemName: category.symbol)
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(BW.leaf.opacity(0.55))
            }
        }
        .task(id: url) {
            guard image == nil, let url else { return }
            let loaded = await RemoteImagePipeline.shared.image(for: url)
            withAnimation(.easeOut(duration: 0.18)) { image = loaded }
        }
    }
}
