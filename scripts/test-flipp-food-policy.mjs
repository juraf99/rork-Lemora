import assert from "node:assert/strict";
import { assessFood } from "../supabase/functions/flipp-flyer-ingest/food-policy.mjs";

// 50 No Frills flyer lines reviewed by the owner on 2026-10-02.
// "review" means a food candidate, never an automatically published deal.
const cases = [
  [1, "BROCCOLI CROWNS", "accepted"],
  [2, "PC BLACK LABEL ICE CREAM, 500 ML", "rejected"],
  [3, "PC SOFT DRINKS, 12X355 ML", "rejected"],
  [4, "GIUSEPPE THIN CRUST OR RISING CRUST PIZZA", "rejected"],
  [5, "NO NAME OLIVE OIL, 750 ML", "accepted"],
  [6, "LIBERTÉ GREEK OR YOPLAIT SOURCE YOGURT", "review"],
  [7, "NO NAME FISH FILLETS OR FISH BURGERS OR FISH STICKS, NO NAME BLEACH", "rejected"],
  [8, "HOUSEHOLD CLEANER", "rejected"],
  [9, "NESCAFÉ SWEET AND CREAMY COFFEE", "rejected"],
  [10, "HAAGEN-DAZS ICE CREAM", "rejected"],
  [11, "NEILSON CREAM OR GAY LEA WHIPPED CREAM", "review"],
  [12, "MAPLE LEAF NATURAL SELECTIONS SLICED MEAT", "review"],
  [13, "SILK NON-DAIRY BEVERAGES", "review"],
  [14, "UTILITY or GRADE A TURKEY, 5-7 kg", "review"],
  [15, "HEINZ BEANS OR PASTA, 398 ML", "review"],
  [16, "ARMSTRONG OR PC SHREDDED CHEESE, 250-320 G", "review"],
  [17, "NO NAME FLAKED OR CHUNK LIGHT TUNA, 85/170 G", "review"],
  [18, "NEW ZEALAND SHORT CUT LAMB LEG, HALAL", "accepted"],
  [19, "RUSSET OR YELLOW POTATOES", "review"],
  [20, "NO NAME SCENTED GEL AIR FRESHENER", "rejected"],
  [21, "NO NAME BLEACH", "rejected"],
  [22, "PC SUPER SOFT HYPOALLERGENIC BATHROOM TISSUE", "rejected"],
  [23, "STOVE TOP STUFFING", "rejected"],
  [24, "PURINA NUTRITION FIRST CANNED CAT FOOD", "rejected"],
  [25, "CAMPBELL'S TOMATO OR CHICKEN NOODLE SOUP", "rejected"],
  [26, "PC SPLENDIDIO EXTRA VIRGIN OLIVE OIL, 1 L", "accepted"],
  [27, "STRAWBERRIES", "accepted"],
  [28, "JANES BONELESS CHICKEN BITES OR TENDERS", "rejected"],
  [29, "NEILSON CHOCOLATE MILK", "review"],
  [30, "HOLIDAY LUNCHEON MEAT OR MAPLE LEAF VIENNA SAUSAGE", "rejected"],
  [31, "CAMPBELL'S BROTH or CONCENTRATED BROTH", "review"],
  [32, "CHICKEN BREASTS", "accepted"],
  [33, "TILDA BASMATI RICE", "accepted"],
  [34, "PC DINNER ENTRÉES", "rejected"],
  [35, "UTILITY or GRADE A TURKEY, 9-11 kg", "review"],
  [36, "KNORR PREMIUM FLAVOUR BASE PASTES", "rejected"],
  [37, "PC SMOKED WILD SOCKEYE SALMON", "accepted"],
  [38, "PC THICK & CRISPY BREADED CHICKEN BURGERS", "rejected"],
  [39, "NO NAME BUTTER", "accepted"],
  [40, "MARCANGELO JUMBO PORK SAUSAGE", "review"],
  [41, "HEINZ SOUP", "rejected"],
  [42, "FRITTOS & CO. CHEESE BALL CROQUETTES", "rejected"],
  [43, "FARMER'S MARKET GRAPE TOMATOES", "accepted"],
  [44, "EXTRA LEAN GROUND BEEF", "accepted"],
  [45, "PC SANDWICH SPREAD", "rejected"],
  [46, "DORITOS TORTILLA CHIPS", "rejected"],
  [47, "LANTIC GRANULATED SUGAR", "rejected"],
  [48, "NO NAME HONEY", "accepted"],
  [49, "WATSON RIDGE CHICKEN BREASTS", "accepted"],
  [50, "PC BLACK LABEL PIZZA", "rejected"],
];

for (const [number, name, expected] of cases) {
  assert.equal(assessFood(name).decision, expected, `Owner-reviewed item ${number}: ${name}`);
}
assert.equal(assessFood("SHRIMP RAMEN").decision, "rejected");
assert.equal(assessFood("TRUFFLE HAM FLAVOUR CRACKERS").decision, "rejected");
assert.equal(assessFood("LIME JUICE").decision, "review");
assert.equal(assessFood("CANOLA OIL").decision, "rejected");
assert.equal(assessFood("KRAFT Cool Whip Aerosol Whip Cream Topping").decision, "rejected");
assert.equal(assessFood("ARMSTRONG Cheese", "600 g, Shreds 450-500 g or SAPUTO Mozzarellissima 600 g").decision, "review");
assert.equal(assessFood("Armstrong cheese blocks 400 g", "Each. Selected varieties.").decision, "review");
assert.equal(assessFood("Family Size Extra Lean Ground Beef", "22.02/kg").decision, "accepted");
console.log(`Passed ${cases.length} owner-reviewed flyer cases and 8 product-form checks.`);
