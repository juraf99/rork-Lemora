#!/usr/bin/env node
import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));
const appRoot = path.resolve(here, '..');
const workspaceRoot = path.resolve(appRoot, '..');
const catalogueRoot = path.join(workspaceRoot, 'recipe-photos');

// Scheduled local runs load their Supabase credentials from the ignored project
// .env file. Explicit environment variables still take precedence in CI or shells.
const envPath = path.join(appRoot, '.env');
if (fs.existsSync(envPath)) {
  for (const line of fs.readFileSync(envPath, 'utf8').split(/\r?\n/)) {
    const match = line.match(/^([A-Z][A-Z0-9_]*)=(.*)$/);
    if (!match || process.env[match[1]]) continue;
    const value = match[2].trim().replace(/^(['"])(.*)\1$/, '$2');
    process.env[match[1]] = value;
  }
}

const projectUrl = process.env.SUPABASE_URL ?? 'https://fsucqlqsafoligouzgrl.supabase.co';
const serviceKey = process.env.SUPABASE_SERVICE_ROLE_KEY;
const syncToken = process.env.LEMORA_CATALOG_SYNC_TOKEN;
const publishableKey = process.env.SUPABASE_PUBLISHABLE_KEY ?? 'sb_publishable_2iPvFh4m-T-1oG-s84VOzw_1H4R9T3G';
const dryRun = process.argv.includes('--dry-run');

if (!serviceKey && !syncToken && !dryRun) {
  throw new Error('LEMORA_CATALOG_SYNC_TOKEN or SUPABASE_SERVICE_ROLE_KEY is required unless --dry-run is used.');
}

const catalogue = JSON.parse(fs.readFileSync(path.join(catalogueRoot, 'recipes.json'), 'utf8'));
const assets = JSON.parse(fs.readFileSync(path.join(catalogueRoot, 'catalog.json'), 'utf8'));
const recipes = catalogue.recipes;
const assetByAppPath = new Map(assets.map((asset) => [asset.appAsset, asset]));
const namespace = '965e6366-20fd-5ad4-b7e7-b3a3d30c76d9';
const allergenAliases = { molluscs: 'mollusk' };
const supportedDiets = new Set([
  'vegetarian', 'vegan', 'pescatarian', 'keto', 'low_carb',
  'high_protein', 'gluten_free', 'dairy_free', 'lactose_free',
  'halal', 'kosher',
]);

function uuidToBytes(uuid) {
  return Buffer.from(uuid.replaceAll('-', ''), 'hex');
}

function uuidV5(value) {
  const hash = crypto.createHash('sha1').update(uuidToBytes(namespace)).update(value).digest();
  hash[6] = (hash[6] & 0x0f) | 0x50;
  hash[8] = (hash[8] & 0x3f) | 0x80;
  const hex = hash.subarray(0, 16).toString('hex');
  return `${hex.slice(0, 8)}-${hex.slice(8, 12)}-${hex.slice(12, 16)}-${hex.slice(16, 20)}-${hex.slice(20)}`;
}

function headers(extra = {}) {
  return { apikey: serviceKey, Authorization: `Bearer ${serviceKey}`, ...extra };
}

function publicHeaders(extra = {}) {
  return { apikey: publishableKey, ...extra };
}

async function request(url, options = {}) {
  const response = await fetch(url, options);
  const body = await response.text();
  if (!response.ok) throw new Error(`${response.status} ${response.statusText}: ${body}`);
  return body ? JSON.parse(body) : null;
}

function ensureCatalogueIntegrity() {
  if (recipes.length !== assets.length) throw new Error('Every recipe must have exactly one image.');
  if (new Set(recipes.map((recipe) => recipe.id)).size !== recipes.length) throw new Error('Duplicate catalogue recipe ID.');
  for (const recipe of recipes) {
    const asset = assetByAppPath.get(recipe.image.app);
    if (!asset || asset.original !== recipe.image.original) throw new Error(`Image manifest mismatch: ${recipe.id}`);
    for (const field of ['calories_kcal', 'protein_g', 'carbohydrates_g', 'fiber_g', 'sugars_g', 'fat_g', 'saturated_fat_g', 'sodium_mg']) {
      if (!(field in recipe.nutrition)) throw new Error(`Missing nutrition field ${field}: ${recipe.id}`);
    }
    for (const diet of ['vegetarian', 'vegan', 'pescatarian', 'keto', 'low_carb', 'high_protein', 'gluten_free', 'dairy_free', 'lactose_free', 'halal', 'kosher']) {
      if (!['yes', 'no'].includes(recipe.diet_classification[diet])) throw new Error(`Unresolved compatibility ${diet}: ${recipe.id}`);
    }
    if (recipe.total_minutes !== recipe.prep_minutes + recipe.cook_minutes + recipe.rest_minutes) throw new Error(`Time mismatch: ${recipe.id}`);
  }
}

async function existingCatalogueIds() {
  if (serviceKey) {
    const rows = await request(`${projectUrl}/rest/v1/recipes?select=catalogue_id&catalogue_id=not.is.null`, { headers: headers() });
    return new Set(rows.map((row) => row.catalogue_id));
  }
  const rows = await request(`${projectUrl}/rest/v1/rpc/get_lemora_recipe_catalog`, {
    method: 'POST',
    headers: publicHeaders({ 'Content-Type': 'application/json' }),
    body: '{}',
  });
  return new Set(rows.map((row) => row.catalogue_id));
}

async function uploadImage(recipe) {
  const objectPath = `catalogue/${recipe.id}.webp`;
  const sourcePath = path.join(catalogueRoot, recipe.image.app);
  const publicUrl = `${projectUrl}/storage/v1/object/public/recipe-photos/${objectPath}`;
  const probe = await fetch(publicUrl, { method: 'HEAD' });
  if (probe.ok) return { objectPath, publicUrl, uploaded: false };
  await request(`${projectUrl}/storage/v1/object/recipe-photos/${objectPath}`, {
    method: 'POST',
    headers: headers({ 'Content-Type': 'image/webp', 'x-upsert': 'false' }),
    body: fs.readFileSync(sourcePath),
  });
  return { objectPath, publicUrl, uploaded: true };
}

async function syncThroughEdgeFunction(recipe, rows) {
  const sourcePath = path.join(catalogueRoot, recipe.image.app);
  return request(`${projectUrl}/functions/v1/sync-recipe-catalog`, {
    method: 'POST',
    headers: { Authorization: `Bearer ${syncToken}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({ payload: rows, image_base64: fs.readFileSync(sourcePath).toString('base64') }),
  });
}

function recipeRows(recipe, image) {
  const id = uuidV5(recipe.id);
  const nutrition = recipe.nutrition;
  const priceStatus = recipe.price?.status ?? 'unknown';
  const parent = {
    id,
    catalogue_id: recipe.id,
    name: recipe.title.fr,
    title_fr: recipe.title.fr,
    title_en: recipe.title.en,
    description: recipe.description?.fr ?? null,
    description_fr: recipe.description?.fr ?? null,
    description_en: recipe.description?.en ?? null,
    language: 'fr',
    servings: recipe.servings,
    prep_time_minutes: recipe.prep_minutes,
    cook_time_minutes: recipe.cook_minutes,
    rest_time_minutes: recipe.rest_minutes,
    total_time_minutes: recipe.total_minutes,
    time_is_estimate: recipe.time_is_estimate,
    meal_type: recipe.meal_type,
    cuisine: recipe.cuisine,
    source_type: recipe.source_type,
    status: recipe.status,
    version: recipe.version,
    is_published: recipe.status === 'published',
    categories: recipe.categories,
    price: recipe.price?.value ?? null,
    price_status: priceStatus,
    kitchen_tested: recipe.kitchen_tested,
    food_safety_source: recipe.food_safety_source,
    collection: recipe.collection,
    content_hash: crypto.createHash('sha256').update(JSON.stringify(recipe)).digest('hex'),
    catalogue_payload: recipe,
  };
  return {
    parent,
    ingredients: recipe.ingredients.map((item, index) => ({ recipe_id: id, ingredient_name: item.name.fr, name_fr: item.name.fr, name_en: item.name.en, normalized_name: item.normalized_name, quantity: item.quantity, unit: item.unit, is_optional: item.optional, sort_order: index })),
    steps: recipe.instructions.fr.map((instruction, index) => ({ recipe_id: id, step_number: index + 1, instruction, instruction_fr: instruction, instruction_en: recipe.instructions.en[index] })),
    nutrition: { recipe_id: id, calories: nutrition.calories_kcal, protein_g: nutrition.protein_g, carbs_g: nutrition.carbohydrates_g, fiber_g: nutrition.fiber_g, sugar_g: nutrition.sugars_g, fat_g: nutrition.fat_g, saturated_fat_g: nutrition.saturated_fat_g, sodium_mg: nutrition.sodium_mg, is_estimate: nutrition.status === 'estimated', status: nutrition.status, basis: nutrition.basis, source: nutrition.source, method: nutrition.method },
    allergens: [...recipe.known_allergens.map((key) => ({ recipe_id: id, allergen_key: allergenAliases[key] ?? key, presence: 'identified', source: 'manual', confidence: 'high' })), ...recipe.possible_allergens.filter((key) => !recipe.known_allergens.includes(key)).map((key) => ({ recipe_id: id, allergen_key: allergenAliases[key] ?? key, presence: 'possible', source: 'manual', confidence: 'low', reasoning: recipe.allergen_review?.possible_reason ?? null }))],
    diets: Object.entries(recipe.diet_classification).filter(([diet]) => supportedDiets.has(diet)).map(([diet, status]) => ({ recipe_id: id, diet, status: status === 'yes' ? 'true' : 'false', reasoning: recipe.compatibility_assessment?.reasons?.[diet] ?? null })),
    media: { recipe_id: id, media_type: 'image', url: image.publicUrl, is_primary: true, storage_bucket: 'recipe-photos', storage_object_path: image.objectPath, catalogue_asset_id: recipe.image.app },
  };
}

ensureCatalogueIntegrity();
if (dryRun) {
  console.log(JSON.stringify({ status: 'valid', examined: recipes.length, photos: assets.length, deterministic_ids: new Set(recipes.map((recipe) => uuidV5(recipe.id))).size }, null, 2));
  process.exit(0);
}

const existing = await existingCatalogueIds();
const result = { examined: recipes.length, added: [], skipped: [], failed: [] };
const pending = recipes.filter((recipe) => {
  if (!existing.has(recipe.id)) return true;
  result.skipped.push(recipe.id);
  return false;
});
let nextRecipe = 0;
async function syncWorker() {
  while (nextRecipe < pending.length) {
    const recipe = pending[nextRecipe++];
    try {
      const objectPath = `catalogue/${recipe.id}.webp`;
      const image = serviceKey
        ? await uploadImage(recipe)
        : { objectPath, publicUrl: `${projectUrl}/storage/v1/object/public/recipe-photos/${objectPath}`, uploaded: false };
      const rows = recipeRows(recipe, image);
      const edgeResult = syncToken ? await syncThroughEdgeFunction(recipe, rows) : null;
      const status = edgeResult?.status ?? await request(`${projectUrl}/rest/v1/rpc/sync_lemora_catalog_recipe`, {
          method: 'POST',
          headers: headers({ 'Content-Type': 'application/json' }),
          body: JSON.stringify({ payload: rows }),
        });
      if (status !== 'inserted' && status !== 'skipped') throw new Error(`Unexpected sync status: ${status}`);
      result.added.push({ id: recipe.id, database_id: rows.parent.id, image_uploaded: edgeResult?.image_uploaded ?? image.uploaded });
    } catch (error) {
      result.failed.push({ id: recipe.id, error: error.message });
    }
  }
}
await Promise.all(Array.from({ length: Math.min(4, pending.length) }, () => syncWorker()));

const verification = await existingCatalogueIds();
result.verified = [...result.added].filter(({ id }) => verification.has(id)).map(({ id }) => id);
console.log(JSON.stringify(result, null, 2));
if (result.failed.length || result.verified.length !== result.added.length) process.exitCode = 1;
