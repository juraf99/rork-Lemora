// Owner-reviewed Lemora flyer policy. This is a product decision, not a nutrition claim.
// A mixed flyer line is never silently converted to a single exact SKU.
export function assessFood(name, description = "") {
  const value = String(name ?? "").normalize("NFKD").replace(/[\u0300-\u036f]/g, "")
    .toLowerCase().replace(/[®™]/g, "").replace(/\s+/g, " ").trim();
  const details = String(description ?? "").normalize("NFKD").replace(/[\u0300-\u036f]/g, "")
    .toLowerCase().replace(/[®™]/g, "").replace(/\s+/g, " ").trim();
  const result = (decision, priority, reason) => ({ decision, priority, reason });
  if (!value) return result("rejected", 0, "missing_product_name");
  if (/\b(cat food|dog food|dog biscuits|pet food|pet treats?|milk-bone|purina|air freshener|bleach|bathroom tissue|cleaner|detergent|soap|shampoo|toothpaste)\b/.test(value))
    return result("rejected", 0, "not_human_food");
  if (/\b(ice cream|soft drinks?|soda|pizza|chips|cheese balls?|croquettes|stuffing|luncheon meat|vienna sausage|dinner entr[eé]es?|flavou?r base|sandwich spread|soup|chicken bites?|chicken tenders?|crispy chicken sandwich|breaded chicken|chicken burgers?|fish burgers?|fish sticks?|ramen|instant noodles?|crackers?|sugar|coffee|cool whip|whipped topping|aerosol whip cream topping|apple turnovers?|cookies?|candy|chocolate bars?|milk chocolate|chocolate truffles?)\b/.test(value))
    return result("rejected", 0, "outside_owner_food_policy");
  if (/\b(canola|vegetable oil|sunflower oil|corn oil)\b/.test(value))
    return result("rejected", 0, "oil_not_selected_by_owner");
  if (/\b(chocolate milk|sweetened|sweet and creamy|sliced meat|deli meat|sausage|saucisse)\b/.test(value))
    return result("review", 35, "nutrition_or_processing_review_required");
  // A different product or package size is not one exact flyer item. Flavour
  // choices within an owner-approved family confer no verified nutrition claim.
  if (/\b(or|ou|varieties and sizes|selected sizes|select sizes)\b/.test(details))
    return result("review", 55, "description_has_multiple_variants");
  // "Beans or pasta" and different brands/sizes are not one verified item.
  if (/\b(or|ou)\b/.test(value))
    return result("review", 55, "multiple_products_require_exact_variant");
  const approvedFamily = /\b(yogurt|yoghurt|yogourt|yaourt|skyr|milk|lait|cheese|fromage|barebells|clif bars?)\b/.test(value);
  if (/\b(selected varieties|select varieties|assorted varieties|selected flavo[u]?rs|select flavo[u]?rs)\b/.test(details)
      && !approvedFamily)
    return result("review", 55, "description_has_unresolved_varieties");
  if (/\b(broth|bouillon)\b/.test(value))
    return result("review", 55, "broth_variant_and_sodium_require_verification");
  if (/\b(barebells|clif bars?)\b/.test(value))
    return result("accepted", 65, "owner_approved_bar_exception_no_verified_macro_claim");
  if (/\b(yogurt|yoghurt|yogourt|yaourt|skyr)\b/.test(value))
    return result("accepted", 80, "owner_approved_yogurt_no_verified_sugar_claim");
  if (/\b(fine-filtered milk|milk|lait|non-dairy beverage|plant[- ]based milk|almond milk|oat milk)\b/.test(value))
    return result("accepted", 75, "owner_approved_milk_no_verified_nutrition_claim");
  if (/\b(oatmeal|oats|avoine)\b/.test(value))
    return result("accepted", 85, "owner_approved_oats_no_verified_protein_claim");
  if (/\b(extra lean ground beef|boeuf hache extra maigre)\b/.test(value))
    return result("accepted", 100, "owner_priority_staple");
  if (/\b(chicken breasts?|poitrines? de poulet|turkey|dinde|salmon|saumon|lamb|agneau|tuna|thon)\b/.test(value))
    return result("accepted", 95, "owner_approved_protein");
  if (/\b(broccoli|brocoli|strawberries|fraises|tomatoes|tomates|potatoes|pommes de terre|apples?|pommes?|pineapples?|ananas|bananas?|bananes?|oranges?|pears?|poires?|grapes?|raisins?|blueberries|bleuets|raspberries|framboises|blackberries|mures|onions?|oignons?|carrots?|carottes?|spinach|epinards?|peppers?|poivrons?)\b/.test(value)
      && !/\b(juice|jus|sauce|paste|pate|jam|jelly|turnover|pie|tart|snacks?|flavou?red|flavou?r|bread|bagels?|vinegar|vinaigre|rings?)\b/.test(value))
    return result("accepted", 90, "owner_approved_fresh_produce");
  if (/\b(olive oil|huile d olive|avocado oil|huile d avocat|basmati rice|riz basmati|butter|beurre|honey|miel|cream|creme|cheese|fromage)\b/.test(value))
    return result("accepted", 70, "owner_approved_cooking_ingredient");
  return result("review", 30, "not_yet_reviewed_by_owner");
}
