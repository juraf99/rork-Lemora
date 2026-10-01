import { readFileSync } from "node:fs";
import { stripTypeScriptTypes } from "node:module";
import { resolve } from "node:path";
import vm from "node:vm";
import assert from "node:assert/strict";

// Run the production tool functions without starting Deno's HTTP listener or calling OpenAI.
const root = resolve(import.meta.dirname, "..");
const source = stripTypeScriptTypes(readFileSync(resolve(root, "supabase/functions/ask-zesty/index.ts"), "utf8"));
const scope = {};
const start = source.indexOf("const isObject");
const end = source.indexOf("Deno.serve(async (req)");
assert.ok(start >= 0 && end > start, "Production tool section must be present");
vm.runInNewContext(source.slice(start, end), scope);

// Use the actual existing Teriyaki app fixture, rather than a second recipe definition.
const catalogue = readFileSync(resolve(root, "ios-bitewise/Lemora/Data/RecipeCatalog.swift"), "utf8");
const block = catalogue.match(/id: "teriyaki_bowl"[\s\S]*?source: \.bitewiseOriginal/)[0];
const nutrition = block.match(/Nutrition\(calories: (\d+), protein: (\d+), carbs: (\d+), fat: (\d+), fiber: (\d+)/).slice(1).map(Number);
const servings = Number(block.match(/servings: (\d+)/)[1]);
const ingredients = [...block.matchAll(/ri\("([^\"]+)", "([^\"]+)", ([\d.]+), \.(\w+)/g)].map((m) => ({
  ingredient_name: m[1].replaceAll("_", " "), normalized_name: m[1], quantity: Number(m[3]), unit: m[4], raw_text: m[2],
}));
const stepsBlock = block.match(/steps: \[([\s\S]*?)\],/)[1];
const recipe = {
  id: "teriyaki_bowl", name: "Teriyaki Chicken Bowl", description: "Existing app catalogue fixture",
  servings, prep_time_minutes: 10, cook_time_minutes: 20, cuisine: "japanese", meal_type: "dinner",
  recipe_ingredients: ingredients,
  recipe_steps: [...stepsBlock.matchAll(/"([^\"]+)"/g)].map((m, i) => ({ step_number: i + 1, instruction: m[1] })),
  recipe_nutrition: [{ calories: nutrition[0], protein_g: nutrition[1], carbs_g: nutrition[2], fat_g: nutrition[3], fiber_g: nutrition[4], sugars_g: null, saturated_fat_g: null, sodium_mg: null, status: "estimated" }],
  recipe_allergens: [{ allergen_key: "soy", state: "contains" }, { allergen_key: "wheat", state: "contains" }],
  // Even a client claiming positive certification must not establish it.
  recipe_diet_compatibility: [{ diet: "gluten_free", status: "yes" }],
};

function database(rows = [], error = null) {
  const ids = [];
  let calls = 0;
  const result = { data: rows, error };
  const query = {
    select() { return this; }, eq() { return this; }, order() { return this; },
    in(_column, values) { ids.push(...values); return this; },
    limit() { return Promise.resolve(result); },
    then(onResult, onError) { return Promise.resolve(result).then(onResult, onError); },
  };
  return { ids, get calls() { return calls; }, from() { calls++; return query; } };
}

const db = database();
const context = { appRecipes: [recipe], profile: { diets: [], allergyRefs: [], dislikedIngredients: [], mealTypes: ["dinner"] } };
const ctx = { db, clerkUserId: "test-user", clientContext: context };
const args = { query: "teriyaki", servings: 8, limit: 6 };
const search = await scope.searchRecipes(ctx, args);
assert.equal(search.count, 1);
assert.equal(search.recipes[0].requested_servings, 8);
const baseChicken = ingredients.find((r) => r.normalized_name === "chicken_breast").quantity;
assert.equal(search.recipes[0].recipe_ingredients.find((r) => r.normalized_name === "chicken_breast").quantity, baseChicken * 8 / servings);
assert.equal(search.recipes[0].recipe_nutrition[0].protein_g, nutrition[1]);
assert.equal(search.recipes[0].recipe_nutrition[0].sugars_g, null);
assert.equal(search.recipes[0].validation_status, "unverified_development_fixture");

const beforeDetails = db.calls;
const details = await scope.getRecipeDetails(ctx, { recipe_ids: ["teriyaki_bowl", "not-a-database-uuid"] });
assert.equal(details.recipes.length, 1);
assert.equal(details.recipes[0].recipe_steps.length, recipe.recipe_steps.length);
assert.equal(db.calls, beforeDetails, "Local recipe IDs must not be sent to a UUID database column");

const allergic = { ...ctx, clientContext: { ...context, profile: { allergyRefs: [{ id: "soy", kind: "allergen" }] } } };
assert.equal((await scope.searchRecipes(allergic, args)).count, 0);
const certified = { ...ctx, clientContext: { ...context, profile: { diets: ["glutenFree"] } } };
assert.equal((await scope.searchRecipes(certified, args)).count, 0, "Unverified client certification must remain unknown");
const excluded = { ...ctx, clientContext: { ...context, profile: { dislikedIngredients: [{ id: "chicken_breast" }] } } };
assert.equal((await scope.searchRecipes(excluded, args)).count, 0);

const unavailable = { ...ctx, db: database([], { message: "Unavailable" }) };
assert.equal((await scope.searchRecipes(unavailable, args)).count, 1, "The visible app recipe remains available if the server catalogue fails");
const serverRecipe = { ...recipe, id: "5907bcbd-d52e-436b-9ec4-919ffdeb3da5", recipe_nutrition: recipe.recipe_nutrition[0] };
const serverCtx = { ...ctx, db: database([serverRecipe]), clientContext: { profile: {} } };
assert.equal((await scope.searchRecipes(serverCtx, { ...args, min_protein_g: 40 })).count, 1, "One-to-one nutrition relations must be read as objects too");

for (const value of [null, undefined, "", " ", false, true, {}, [], "not a number", -1]) assert.equal(scope.nullableNumber(value), null);
for (const value of [0, "0", 46, "46"]) assert.equal(scope.nullableNumber(value), Number(value));
const output = scope.parseAgentOutput(JSON.stringify({ message: "Nutrition", recommendations: [{ title: recipe.name, kind: "recipe", nutrition: { calories: null, protein_g: 46, status: "unknown" } }] }));
assert.equal(output.recommendations[0].nutrition.calories, null);
assert.equal(output.recommendations[0].nutrition.protein_g, 46);
assert.equal(output.recommendations[0].nutrition.sodium_mg, null);
assert.equal(scope.parseNutrition({ sugar_g: 5, is_estimate: true }).sugars_g, 5, "The published recipe column is sugar_g");
const priorTurn = scope.agentInputWithHistory("What is its nutrition?", [
  { role: "user", content: "Show me a chicken and rice dinner" },
  { role: "assistant", content: "Try this one", recommendations: [
    { title: recipe.name, recipe_id: recipe.id },
  ] },
]);
assert.ok(priorTurn.includes(`Recipe cards: ${recipe.name} (recipe id: ${recipe.id})`));
assert.ok(priorTurn.endsWith("Latest user request: What is its nutrition?"));
const billingFailure = scope.agentFailure(new Error("Your organization has reached a usage or billing limit"), "fr");
assert.equal(billingFailure.code, "ai_billing_unavailable");
assert.equal(billingFailure.status, 503);
assert.ok(billingFailure.message.includes("Réessaie plus tard"));
assert.equal(scope.agentFailure({ error: { code: "project_spend_limit_exceeded" } }, "en").code, "ai_billing_unavailable");
assert.equal(scope.agentFailure({ code: "rate_limit_exceeded" }, "en").code, "ai_busy");
assert.equal(scope.agentFailure(new Error("request timed out"), "en").code, "ai_timeout");
assert.equal(scope.isMissingAgentSession(new Error("session not found")), true);
assert.equal(scope.isMissingAgentSession(new Error("Your organization has reached a usage or billing limit")), false);
async function* failedStream(error) {
  yield { type: "agent.session.turn.failed", turn: { error } };
}
await assert.rejects(
  scope.consumeAgentStream({}, failedStream({ code: "usage_limit_exceeded", message: "Budget exhausted" }), ctx),
  (error) => scope.agentFailure(error, "en").code === "ai_billing_unavailable",
  "The agent's streamed turn error must retain its billing code",
);
await assert.rejects(
  scope.consumeAgentStream({}, failedStream("Your organization has reached a usage or billing limit"), ctx),
  (error) => scope.agentFailure(error, "en").code === "ai_billing_unavailable",
  "String-shaped streamed errors must not lose the billing message",
);
let replacementSessions = 0;
const billingAgent = { beta: { agents: { sessions: {
  events: { stream: async () => { throw new Error("Your organization has reached a usage or billing limit"); } },
  create: async () => { replacementSessions++; throw new Error("Unexpected replacement session"); },
} } } };
await assert.rejects(scope.runAgent(billingAgent, "old-session", "Hello", "en", ctx, []), /billing limit/);
assert.equal(replacementSessions, 0, "Billing failure must not create a second paid agent session");
const guidance = scope.agentInstructions("en", context);
assert.ok(guidance.includes("buying shoes online"));
assert.ok(guidance.includes("more specific or niche recipe"));
assert.ok(scope.getAppHelp().profile_paths.meal_types.includes("Meal Types"));
assert.equal(scope.safeUserContext(context).profile.mealTypes[0], "dinner");
console.log("Zesty tool checks passed: actual Teriyaki quantities/steps, local IDs, safety filters, nutrition unknowns and meal preferences.");
