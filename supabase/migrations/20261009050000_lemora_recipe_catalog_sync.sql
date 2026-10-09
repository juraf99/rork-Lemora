-- Additive contract for the permanent Lemora recipe catalogue.
-- Existing recipes remain unchanged; catalogue rows are identified by catalogue_id.

alter table public.recipes
  add column if not exists catalogue_id text,
  add column if not exists title_fr text,
  add column if not exists title_en text,
  add column if not exists description_fr text,
  add column if not exists description_en text,
  add column if not exists meal_type text,
  add column if not exists rest_time_minutes integer,
  add column if not exists total_time_minutes integer,
  add column if not exists time_is_estimate boolean,
  add column if not exists categories text[] not null default '{}',
  add column if not exists price numeric,
  add column if not exists price_status text not null default 'unknown',
  add column if not exists kitchen_tested boolean not null default false,
  add column if not exists food_safety_source text,
  add column if not exists collection text,
  add column if not exists catalogue_payload jsonb;

create unique index if not exists recipes_catalogue_id_key
  on public.recipes (catalogue_id)
  where catalogue_id is not null;

alter table public.recipe_ingredients
  add column if not exists name_fr text,
  add column if not exists name_en text;

create unique index if not exists recipe_ingredients_recipe_sort_key
  on public.recipe_ingredients (recipe_id, sort_order);

alter table public.recipe_steps
  add column if not exists instruction_fr text,
  add column if not exists instruction_en text;

alter table public.recipe_nutrition
  add column if not exists saturated_fat_g numeric,
  add column if not exists status text not null default 'unknown',
  add column if not exists basis text not null default 'per_serving',
  add column if not exists source text,
  add column if not exists method text;

alter table public.recipe_allergens
  add column if not exists presence text not null default 'identified',
  add column if not exists reasoning text;

alter table public.recipe_media
  add column if not exists storage_bucket text,
  add column if not exists storage_object_path text,
  add column if not exists catalogue_asset_id text;

create unique index if not exists recipe_media_catalogue_asset_key
  on public.recipe_media (catalogue_asset_id)
  where catalogue_asset_id is not null;

alter table public.recipes
  drop constraint if exists recipes_price_status_check,
  add constraint recipes_price_status_check
    check (price_status in ('unknown', 'estimated', 'verified')),
  drop constraint if exists recipes_nonnegative_times_check,
  add constraint recipes_nonnegative_times_check
    check (
      coalesce(prep_time_minutes, 0) >= 0 and
      coalesce(cook_time_minutes, 0) >= 0 and
      coalesce(rest_time_minutes, 0) >= 0 and
      coalesce(total_time_minutes, 0) >= 0
    );

alter table public.recipe_nutrition
  drop constraint if exists recipe_nutrition_status_check,
  add constraint recipe_nutrition_status_check
    check (status in ('unknown', 'estimated', 'verified')),
  drop constraint if exists recipe_nutrition_basis_check,
  add constraint recipe_nutrition_basis_check
    check (basis = 'per_serving');

alter table public.recipe_allergens
  drop constraint if exists recipe_allergens_presence_check,
  add constraint recipe_allergens_presence_check
    check (presence in ('identified', 'possible'));

comment on column public.recipes.catalogue_id is
  'Stable ID from the permanent local Lemora recipe catalogue.';
comment on column public.recipes.catalogue_payload is
  'Lossless source payload retained for validation and forward-compatible fields.';
comment on column public.recipe_allergens.presence is
  'Separates identified allergens from possible label or cross-contact allergens.';

create or replace function public.sync_lemora_catalog_recipe(payload jsonb)
returns text
language plpgsql
security invoker
set search_path = public
as $$
declare
  parent jsonb := payload -> 'parent';
  recipe_uuid uuid := (parent ->> 'id')::uuid;
  stable_id text := parent ->> 'catalogue_id';
begin
  if stable_id is null or stable_id = '' then
    raise exception 'catalogue_id is required';
  end if;
  if exists (select 1 from public.recipes where catalogue_id = stable_id) then
    return 'skipped';
  end if;

  insert into public.recipes (
    id, catalogue_id, name, title_fr, title_en, description, description_fr,
    description_en, language, servings, prep_time_minutes, cook_time_minutes,
    rest_time_minutes, total_time_minutes, time_is_estimate, meal_type, cuisine,
    source_type, status, version, is_published, categories, price, price_status,
    kitchen_tested, food_safety_source, collection, content_hash, catalogue_payload
  ) values (
    recipe_uuid, stable_id, parent ->> 'name', parent ->> 'title_fr', parent ->> 'title_en',
    parent ->> 'description', parent ->> 'description_fr', parent ->> 'description_en',
    parent ->> 'language', (parent ->> 'servings')::integer,
    (parent ->> 'prep_time_minutes')::integer, (parent ->> 'cook_time_minutes')::integer,
    (parent ->> 'rest_time_minutes')::integer, (parent ->> 'total_time_minutes')::integer,
    (parent ->> 'time_is_estimate')::boolean, parent ->> 'meal_type', parent ->> 'cuisine',
    parent ->> 'source_type', parent ->> 'status', (parent ->> 'version')::integer,
    (parent ->> 'is_published')::boolean,
    array(select jsonb_array_elements_text(parent -> 'categories')),
    nullif(parent ->> 'price', '')::numeric, parent ->> 'price_status',
    (parent ->> 'kitchen_tested')::boolean, parent ->> 'food_safety_source',
    parent ->> 'collection', parent ->> 'content_hash', parent -> 'catalogue_payload'
  );

  insert into public.recipe_ingredients
    (recipe_id, ingredient_name, name_fr, name_en, normalized_name, quantity, unit, is_optional, sort_order)
  select recipe_uuid, item ->> 'ingredient_name', item ->> 'name_fr', item ->> 'name_en',
    item ->> 'normalized_name', (item ->> 'quantity')::numeric, item ->> 'unit',
    (item ->> 'is_optional')::boolean, (item ->> 'sort_order')::integer
  from jsonb_array_elements(payload -> 'ingredients') item;

  insert into public.recipe_steps
    (recipe_id, step_number, instruction, instruction_fr, instruction_en)
  select recipe_uuid, (item ->> 'step_number')::integer, item ->> 'instruction',
    item ->> 'instruction_fr', item ->> 'instruction_en'
  from jsonb_array_elements(payload -> 'steps') item;

  insert into public.recipe_nutrition
    (recipe_id, calories, protein_g, carbs_g, fiber_g, sugar_g, fat_g,
     saturated_fat_g, sodium_mg, is_estimate, status, basis, source, method)
  select recipe_uuid, nullif(item ->> 'calories', '')::numeric,
    nullif(item ->> 'protein_g', '')::numeric, nullif(item ->> 'carbs_g', '')::numeric,
    nullif(item ->> 'fiber_g', '')::numeric, nullif(item ->> 'sugar_g', '')::numeric,
    nullif(item ->> 'fat_g', '')::numeric, nullif(item ->> 'saturated_fat_g', '')::numeric,
    nullif(item ->> 'sodium_mg', '')::numeric, (item ->> 'is_estimate')::boolean,
    item ->> 'status', item ->> 'basis', item ->> 'source', item ->> 'method'
  from jsonb_array_elements(jsonb_build_array(payload -> 'nutrition')) item;

  insert into public.recipe_allergens
    (recipe_id, allergen_key, presence, source, confidence, reasoning)
  select recipe_uuid, item ->> 'allergen_key', item ->> 'presence', item ->> 'source',
    item ->> 'confidence', item ->> 'reasoning'
  from jsonb_array_elements(payload -> 'allergens') item;

  insert into public.recipe_diet_compatibility
    (recipe_id, diet, status, reasoning)
  select recipe_uuid, item ->> 'diet', item ->> 'status', item ->> 'reasoning'
  from jsonb_array_elements(payload -> 'diets') item;

  insert into public.recipe_media
    (recipe_id, media_type, url, is_primary, storage_bucket, storage_object_path, catalogue_asset_id)
  select recipe_uuid, item ->> 'media_type', item ->> 'url',
    (item ->> 'is_primary')::boolean, item ->> 'storage_bucket',
    item ->> 'storage_object_path', item ->> 'catalogue_asset_id'
  from jsonb_array_elements(jsonb_build_array(payload -> 'media')) item;

  insert into public.recipe_sources (recipe_id, creator_name, platform, original_url, license_type)
  values (recipe_uuid, 'Lemora', 'local_catalogue', null, null);

  return 'inserted';
end;
$$;

revoke all on function public.sync_lemora_catalog_recipe(jsonb) from public, anon, authenticated;
grant execute on function public.sync_lemora_catalog_recipe(jsonb) to service_role;

-- Public app clients only need the lossless payload and its primary image URL.
-- Keeping this behind a stable function prevents mobile builds from depending on
-- the normalized table layout or broad table permissions.
create or replace function public.get_lemora_recipe_catalog()
returns table (catalogue_id text, catalogue_payload jsonb, image_url text)
language sql
stable
security definer
set search_path = public
as $$
  select r.catalogue_id, r.catalogue_payload, m.url
  from public.recipes r
  join public.recipe_media m on m.recipe_id = r.id and m.is_primary = true
  where r.catalogue_id is not null
    and r.catalogue_payload is not null
  order by r.catalogue_id;
$$;

revoke all on function public.get_lemora_recipe_catalog() from public;
grant execute on function public.get_lemora_recipe_catalog() to anon, authenticated, service_role;
