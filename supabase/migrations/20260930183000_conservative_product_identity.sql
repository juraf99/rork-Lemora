alter table public.flyer_items
  add column if not exists classification_status text not null default 'review_required',
  add column if not exists classification_notes text;

alter table public.flyer_items
  drop constraint if exists flyer_items_classification_status_check,
  add constraint flyer_items_classification_status_check
    check (classification_status in ('approved', 'review_required', 'rejected'));

create or replace function public.lemora_is_composite_or_flavored(input_name text)
returns boolean
language sql
immutable
set search_path = ''
as $function$
  select lower(public.unaccent(coalesce(input_name, ''))) ~
    '(flavou?r|saveur|ramen|instant noodle|nouille instant|cracker|craquelin|chips|croustille|juice|jus|beverage|boisson|pizza|soup|soupe|sauce|seasoned|assaisonne|marinated|marine|breaded|pane)'
$function$;

create or replace function public.lemora_food_category(input_name text)
returns text
language sql
immutable
set search_path = ''
as $function$
  with cleaned as (select lower(public.unaccent(coalesce(input_name, ''))) as s)
  select case
    when s ~ '(body wash|shampoo|conditioner|soap|detergent|cleaner|toilet|towel|cookware|zwilling|knife|pan set|storage container|garbage bag|foil|cosmetic|toothpaste|deodorant|vitamin|pharmacy|gift card|points card|mug|tasse|cup set|plate|assiette|bowl|bol|utensil|battery|pile|diaper|couche|pet food|dog food|cat food|decor|candle|bougie|laundry|lessive)' then null
    -- Product form must win over an ingredient mentioned only as a flavour.
    when s ~ '(twinkie|cracker|craquelin|chips|croustille|cookie|biscuit|chocolate|chocolat|candy|bonbon|popcorn|snack)' then 'snacks'
    when s ~ '(ramen|instant noodle|nouille instant|prepared|ready to eat|repas|fried|roasted|bbq|sandwich|pizza|soup|soupe|dumpling|siopao|chow mein|sushi|salad|salade|ketchup|spread|tartinade)' then 'prepared'
    when s ~ '(juice|jus|coffee|cafe|tea|the|beverage|drink|boisson|smoothie|nectar|soda|water|eau)' then 'beverages'
    when s ~ '(bread|pain|bagel|bun|brioche|croissant|pita|naan|tortilla|cake|gateau|muffin|donut|doughnut|pie|tarte)' then 'bakery'
    when s ~ '(frozen|surgele|ice cream|creme glacee)' then 'frozen'
    when s ~ '(chicken|poulet|beef|boeuf|steak|brisket|pork|porc|bacon|ham|jambon|lamb|agneau|duck|canard|goat|chevre|shrimp|crevette|salmon|saumon|tuna|thon|fish|poisson|catfish|tilapia|pompano|grouper|croaker|eel|turbot|barramundi|squid|calmar|mussel|moule|crab|crabe|abalone|sausage|saucisse)' then 'protein'
    when s ~ '(lettuce|laitue)' then 'produce'
    when s ~ '(^|[^a-z])(milk|lait)([^a-z]|$)' or s ~ '(yogurt|yoghurt|yaourt|yogourt|skyr|cheese|fromage|feta|parmesan|butter|beurre|cream|creme|egg|oeuf)' then 'dairy'
    when s ~ '(apple|pomme|pear|poire|orange|mandarin|mango|banana|banane|grape|raisin|berry|berries|bleuet|fraise|avocado|avocat|tomato|tomate|onion|oignon|garlic|ail|pepper|poivron|broccoli|brocoli|carrot|carotte|spinach|epinard|mushroom|champignon|bok choy|napa|okra|eggplant|aubergine|squash|courge|yam|patate|potato|pomme de terre|melon|durian|dragon fruit|lotus root|eddoes|peanut|arachide|chestnut|chataigne|vegetable|legume|fruit)' then 'produce'
    when s ~ '(rice|riz|pasta|pate|spaghetti|macaroni|flour|farine|oat|avoine|lentil|lentille|bean|haricot|chickpea|pois chiche|tofu|oil|huile|vinegar|vinaigre|spice|epice|salt|sel|pepper|poivre|cereal|cereale|granola|nut|noix|seed|graine|canned|conserve|tomato paste|pate de tomate)' then 'pantry'
    -- Unknown merchandise is not food by default. It stays out until a trusted rule or review approves it.
    else null
  end
  from cleaned
$function$;

create or replace function public.lemora_processing_level(input_name text, category text)
returns text
language sql
immutable
set search_path = ''
as $function$
  with cleaned as (select lower(public.unaccent(coalesce(input_name, ''))) as s)
  select case
    when s ~ '(twinkie|chips|croustille|cracker|craquelin|cookie|biscuit|candy|bonbon|chocolat|soft drink|soda|liqueur|energy drink|boisson energ|frozen pizza|pizza surgelee|frozen meal|repas|ramen|instant noodle|nouille instant|donut|beigne|cake|gateau|pie|tarte|ice cream|creme glacee|hot dog|wiener|sausage|saucisse|ketchup|milkshake|lait frappe)'
      then 'ultra_processed'
    when s ~ '(rice|riz|oat|avoine|lentil|lentille|bean|haricot|chickpea|pois chiche|tofu|frozen vegetable|legume surgele)'
      then 'minimally_processed'
    when s ~ '(juice|jus|bread|pain|pasta|pate|rice|riz|cheese|fromage|yogurt|yogourt|hummus|peanut butter|beurre d arachide|canned|conserve|frozen|surgele|smoked|fume|spread|tartinade|seasoned|assaisonne|marinated|marine|evaporated|evapore|condensed|condense|clover leaf|rio mare|flamingo|dans l huile|in olive oil|thon pale|solid light tuna)'
      then 'processed'
    when s ~ '(egg|oeuf|lentil|lentille|bean|haricot|chickpea|pois chiche|tofu|oat|avoine|plain yogurt|yogourt nature|frozen vegetable|legume surgele)'
      or s ~ '(^|[^a-z])(milk|lait)([^a-z]|$)'
      then 'minimally_processed'
    when coalesce(category, '') in ('produce', 'protein')
      and s !~ '(breaded|pane|seasoned|assaisonne|marinated|marine|deli|charcuterie)'
      then 'whole'
    else 'unknown'
  end
  from cleaned
$function$;

create or replace function public.lemora_normalize_food_name(input_name text)
returns text
language sql
immutable
set search_path = ''
as $function$
  with cleaned as (select lower(public.unaccent(coalesce(input_name, ''))) as s)
  select case
    -- Identify the actual product before considering flavour words.
    when s ~ '(twinkie)' then 'twinkies'
    when s ~ '(french fries|frites|pommes de terre frites|pommes de terre rissolees)' then 'frozen_fries'
    when s ~ '(ramen|instant noodle|nouille instant)' then 'ramen'
    when s ~ '(cracker|craquelin)' then 'crackers'
    when s ~ '(lime juice|jus de lime|jus a la lime)' then 'lime_juice'
    when s ~ '(juice|jus|nectar)' then 'fruit_juice'
    when s ~ '(chips|croustille)' then 'chips'
    when s ~ '(pizza)' then 'pizza'
    when s ~ '(soup|soupe)' then 'soup'
    when s ~ '(ketchup)' then 'ketchup'
    when s ~ '(potato|pomme[s]? de terre|patate)' then 'potato'
    when s ~ '(lettuce|laitue)' then 'lettuce'
    when s ~ '(chicken breast|poitrine[s]? de poulet)' then 'chicken_breast'
    when s ~ '(chicken wing|aile[s]? de poulet)' then 'chicken_wing'
    when s ~ '(chicken|poulet)' then 'chicken'
    when s ~ '(flank steak|skirt steak|bavette)' then 'flank_steak'
    when s ~ '(beef|boeuf|steak|brisket)' then 'beef'
    when s ~ '(pork|porc|bacon|ham|jambon)' then 'pork'
    when s ~ '(lamb|agneau)' then 'lamb'
    when s ~ '(duck|canard)' then 'duck'
    when s ~ '(shrimp|crevette)' then 'shrimp'
    when s ~ '(salmon|saumon)' then 'salmon'
    when s ~ '(tuna|thon)' then 'tuna'
    when s ~ '(squid|calmar)' then 'squid'
    when s ~ '(mussel|moule)' then 'mussels'
    when s ~ '(crab|crabe)' then 'crab'
    when s ~ '(fish|poisson|catfish|tilapia|pompano|grouper|croaker|eel|turbot|barramundi|galunggong|basa|abalone)' then 'fish'
    when s ~ '(egg|oeuf)' then 'egg'
    when s ~ '(greek yogurt|greek yoghurt|skyr|yaourt grec|yogourt grec)' then 'greek_yogurt_or_skyr'
    when s ~ '(yogurt|yoghurt|yaourt|yogourt)' then 'yogurt'
    when s ~ '(cottage cheese|fromage cottage)' then 'cottage_cheese'
    when s ~ '(parmesan)' then 'parmesan'
    when s ~ '(cheese|fromage|feta|cotija|queso)' then 'cheese'
    when s ~ '(^|[^a-z])(milk|lait)([^a-z]|$)' then 'milk'
    when s ~ '(butter|beurre|cream|creme)' then 'dairy'
    when s ~ '(oat|avoine)' then 'oats'
    when s ~ '(apple|pomme)' then 'apple'
    when s ~ '(banana|banane)' then 'banana'
    when s ~ '(orange|mandarin|clementine)' then 'orange'
    when s ~ '(blueberr|bleuet)' then 'blueberries'
    when s ~ '(strawberr|fraise)' then 'strawberries'
    when s ~ '(raspberr|framboise)' then 'raspberries'
    when s ~ '(blackberr|mure)' then 'blackberries'
    when s ~ '(avocado|avocat)' then 'avocado'
    when s ~ '(^|[^a-z])(lime|lime[s]?)([^a-z]|$)' then 'lime'
    when s ~ '(garlic|ail)' then 'garlic'
    when s ~ '(onion|oignon)' then 'onion'
    when s ~ '(tomato|tomate)' then 'tomato'
    when s ~ '(bell pepper|poivron)' then 'bell_pepper'
    when s ~ '(cilantro|coriandre)' then 'cilantro'
    when s ~ '(basil|basilic)' then 'basil'
    when s ~ '(broccoli|brocoli)' then 'broccoli'
    when s ~ '(carrot|carotte)' then 'carrot'
    when s ~ '(spinach|epinard)' then 'spinach'
    when s ~ '(mushroom|champignon)' then 'mushroom'
    when s ~ '(corn|mais)' then 'corn'
    when s ~ '(black bean|haricot noir)' then 'black_beans'
    when s ~ '(chickpea|pois chiche|hummus)' then 'chickpeas'
    when s ~ '(lentil|lentille)' then 'lentils'
    when s ~ '(rigatoni)' then 'rigatoni'
    when s ~ '(pasta|spaghetti|macaroni|noodle|nouille)' then 'pasta'
    when s ~ '(corn tortilla|tortilla de mais)' then 'corn_tortillas'
    when s ~ '(tortilla)' then 'tortillas'
    when s ~ '(rice|riz)' then 'rice'
    when s ~ '(olive oil|huile d olive)' then 'olive_oil'
    else trim(both '_' from regexp_replace(s, '[^a-z0-9]+', '_', 'g'))
  end
  from cleaned
$function$;

create or replace function public.lemora_common_food_score(canonical_key text)
returns smallint
language sql
immutable
set search_path = ''
as $function$
  select case coalesce(canonical_key, '')
    when 'chicken_breast' then 100 when 'chicken' then 100 when 'egg' then 100
    when 'pork' then 95 when 'beef' then 95 when 'milk' then 95
    when 'rice' then 95 when 'potato' then 95 when 'onion' then 95
    when 'tomato' then 95 when 'carrot' then 95 when 'banana' then 95
    when 'apple' then 95 when 'yogurt' then 90 when 'cheese' then 90
    when 'oats' then 90 when 'broccoli' then 90 when 'spinach' then 85
    when 'bell_pepper' then 85 when 'avocado' then 85 when 'pasta' then 85
    when 'salmon' then 80 when 'tuna' then 80 when 'fish' then 80
    when 'lentils' then 80 when 'black_beans' then 80 when 'chickpeas' then 80
    when 'blueberries' then 75 when 'strawberries' then 75 when 'tofu' then 75
    when 'shrimp' then 70 when 'olive_oil' then 70
    when 'fruit_juice' then 45 when 'lime_juice' then 35 when 'soup' then 45
    when 'frozen_fries' then 55 when 'ketchup' then 30 when 'crackers' then 30
    when 'ramen' then 25 when 'chips' then 20 when 'pizza' then 20 when 'twinkies' then 0
    else 40
  end::smallint
$function$;

create or replace function public.lemora_dietary_flags(input_name text, input_category text)
returns jsonb
language sql
immutable
set search_path = ''
as $function$
  with n as (
    select public.lemora_normalize_food_name(input_name) as name,
           coalesce(input_category, 'other') as category,
           public.lemora_is_composite_or_flavored(input_name) as composite
  ), unknown_flags as (
    select jsonb_build_object(
      'vegetarian','unknown','vegan','unknown','pescatarian','unknown','keto','unknown',
      'low_carb','unknown','high_protein','unknown','gluten_free','unknown',
      'dairy_free','unknown','lactose_free','unknown','halal','unknown','kosher','unknown') as flags
  )
  select case
    when composite then (select flags from unknown_flags)
    when name = 'pork' then jsonb_build_object(
      'vegetarian','no','vegan','no','pescatarian','no','keto','yes','low_carb','yes','high_protein','yes',
      'gluten_free','unknown','dairy_free','yes','lactose_free','yes','halal','no','kosher','no')
    when name in ('chicken','chicken_breast','chicken_wing','beef','flank_steak','lamb','duck') then jsonb_build_object(
      'vegetarian','no','vegan','no','pescatarian','no','keto','yes','low_carb','yes','high_protein','yes',
      'gluten_free','unknown','dairy_free','yes','lactose_free','yes','halal','unknown','kosher','unknown')
    when name in ('shrimp','squid','mussels','crab') then jsonb_build_object(
      'vegetarian','no','vegan','no','pescatarian','yes','keto','yes','low_carb','yes','high_protein','yes',
      'gluten_free','unknown','dairy_free','yes','lactose_free','yes','halal','unknown','kosher','no')
    when name in ('salmon','tuna','fish') then jsonb_build_object(
      'vegetarian','no','vegan','no','pescatarian','yes','keto','yes','low_carb','yes','high_protein','yes',
      'gluten_free','unknown','dairy_free','yes','lactose_free','yes','halal','unknown','kosher','unknown')
    when name = 'egg' then jsonb_build_object(
      'vegetarian','yes','vegan','no','pescatarian','yes','keto','yes','low_carb','yes','high_protein','yes',
      'gluten_free','yes','dairy_free','yes','lactose_free','yes','halal','unknown','kosher','unknown')
    when category = 'produce' then jsonb_build_object(
      'vegetarian','yes','vegan','yes','pescatarian','yes','keto','unknown','low_carb','unknown','high_protein','no',
      'gluten_free','yes','dairy_free','yes','lactose_free','yes','halal','yes','kosher','yes')
    when category = 'dairy' then jsonb_build_object(
      'vegetarian','yes','vegan','no','pescatarian','yes','keto','unknown','low_carb','unknown','high_protein','unknown',
      'gluten_free','unknown','dairy_free','no','lactose_free','unknown','halal','unknown','kosher','unknown')
    else (select flags from unknown_flags)
  end
  from n
$function$;

create or replace function public.lemora_allergen_flags(input_name text)
returns jsonb
language sql
immutable
set search_path = ''
as $function$
  with n as (
    select public.lemora_normalize_food_name(input_name) as name,
           lower(public.unaccent(coalesce(input_name,''))) as s,
           public.lemora_is_composite_or_flavored(input_name) as composite
  )
  select jsonb_strip_nulls(jsonb_build_object(
    'peanuts', case when s ~ '(peanut|arachide)' then case when composite then 'may_contain' else 'contains' end end,
    'tree_nuts', case when s ~ '(almond|amande|cashew|cajou|walnut|noix|hazelnut|noisette|pistach)' then case when composite then 'may_contain' else 'contains' end end,
    'milk', case when name in ('milk','yogurt','greek_yogurt_or_skyr','cottage_cheese','parmesan','cheese','dairy') then case when composite then 'may_contain' else 'contains' end end,
    'egg', case when name = 'egg' then case when composite then 'may_contain' else 'contains' end end,
    'fish', case when name in ('salmon','tuna','fish') or (composite and s ~ '(fish|poisson|salmon|saumon|tuna|thon)') then case when composite then 'may_contain' else 'contains' end end,
    'shellfish', case when name in ('shrimp','squid','mussels','crab') or (composite and s ~ '(shrimp|crevette|crab|crabe|shellfish|mollusque)') then case when composite then 'may_contain' else 'contains' end end,
    'soy', case when s ~ '(soy|soya|tofu|edamame)' then case when composite then 'may_contain' else 'contains' end end,
    'wheat', case when s ~ '(wheat|ble)' then 'contains' when s ~ '(bread|pain|pasta|noodle|nouille|ramen|cracker|craquelin|cookie|biscuit|cake|gateau)' then 'may_contain' end,
    'sesame', case when s ~ '(sesame|tahini)' then case when composite then 'may_contain' else 'contains' end end
  ))
  from n
$function$;

create or replace function public.lemora_set_health_priority()
returns trigger
language plpgsql
set search_path = ''
as $function$
declare
  normalized_key text := public.lemora_normalize_food_name(new.raw_description);
  is_known boolean;
begin
  new.processing_level := public.lemora_processing_level(new.raw_description, new.food_category);
  new.health_priority_score := public.lemora_health_priority(new.raw_description, new.food_category);

  is_known := normalized_key in (
    'ramen','crackers','lime_juice','fruit_juice','chips','pizza','soup','ketchup','frozen_fries','twinkies',
    'chicken_breast','chicken_wing','chicken','flank_steak','beef','pork','lamb','duck',
    'shrimp','salmon','tuna','squid','mussels','crab','fish','egg','greek_yogurt_or_skyr',
    'yogurt','cottage_cheese','parmesan','cheese','milk','dairy','oats','apple','banana','orange','potato','lettuce','blueberries',
    'strawberries','raspberries','blackberries','avocado','lime','garlic','onion','tomato',
    'bell_pepper','cilantro','basil','broccoli','carrot','spinach','mushroom','corn',
    'black_beans','chickpeas','lentils','rigatoni','pasta','corn_tortillas','tortillas','rice','olive_oil'
  );
  new.classification_status := case
    when normalized_key = 'twinkies' then 'rejected'
    when normalized_key = 'frozen_fries'
      and lower(public.unaccent(coalesce(new.raw_description, ''))) !~ '(mccain|cavendish)'
      then 'review_required'
    when lower(public.unaccent(coalesce(new.raw_description, ''))) ~ '(^|[^a-z])(ou|or)([^a-z]|$)'
      then 'review_required'
    when is_known then 'approved'
    else 'review_required'
  end;
  new.classification_notes := case
    when normalized_key = 'twinkies' then 'Blocked from Lemora health recommendations.'
    when normalized_key = 'frozen_fries'
      and lower(public.unaccent(coalesce(new.raw_description, ''))) !~ '(mccain|cavendish)'
      then 'Frozen fries require a recognized brand before inclusion.'
    when lower(public.unaccent(coalesce(new.raw_description, ''))) ~ '(^|[^a-z])(ou|or)([^a-z]|$)'
      then 'Multiple alternative products in one flyer item; excluded until split or reviewed.'
    when not is_known then 'No trusted canonical product rule matched; excluded until reviewed.'
    when public.lemora_is_composite_or_flavored(new.raw_description)
      then 'Canonicalized by product form; flavour words were not treated as the product itself. Dietary claims remain unknown.'
    else 'Canonicalized by a high-confidence direct product rule.'
  end;
  return new;
end
$function$;

-- Re-run the complete classification after changing rule precedence.
update public.flyer_items
set raw_description = raw_description;

create or replace view public.active_food_deals_app
with (security_invoker = true)
as
select
  fi.id,
  fi.normalized_name_en as ingredient_id,
  coalesce(cfi.canonical_name_en, replace(initcap(fi.normalized_name_en), '_', ' ')) as product_name,
  fi.raw_brand as brand,
  fi.raw_size as size_text,
  fi.sale_price,
  fi.regular_price,
  fi.multi_buy_quantity,
  fi.multi_buy_total_price,
  coalesce(fi.source_payload->>'priceUnit', '') as unit_label,
  fi.provider_discount_percent,
  fi.deal_score,
  fi.deal_confidence,
  case when fi.provider_discount_percent >= 45 then 'rareDeal'
       when fi.provider_discount_percent >= 30 then 'greatPrice'
       when fi.provider_discount_percent >= 15 then 'goodPrice' end as deal_label,
  fi.food_category,
  fi.dietary_flags,
  fi.allergen_flags,
  cfi.image_url,
  fi.product_url,
  fi.source_postal_code,
  fi.source_locale,
  coalesce(fi.source_payload->>'currency', case when c.country_code='US' then 'USD' else 'CAD' end) as currency_code,
  fp.valid_from,
  fp.valid_until,
  fp.region_codes,
  c.id as chain_id,
  coalesce(c.canonical_name, lower(regexp_replace(c.name, '[^a-zA-Z0-9]+', '_', 'g'))) as retailer_id,
  c.name as retailer_name,
  c.country_code,
  fi.raw_description as retailer_product_name,
  fi.image_url as retailer_image_url,
  fi.processing_level,
  fi.health_priority_score,
  cfi.canonical_name_fr,
  cfi.source_page_url as image_source_page_url,
  cfi.photographer_or_creator as image_creator,
  cfi.license_code as image_license_code,
  cfi.attribution_text as image_attribution,
  public.lemora_common_food_score(fi.normalized_name_en) as common_food_score,
  round(
    least(100, greatest(coalesce(fi.deal_score, 0), coalesce(fi.provider_discount_percent, 0))) * 0.50
    + public.lemora_common_food_score(fi.normalized_name_en) * 0.30
    + coalesce(fi.health_priority_score, 50) * 0.20,
    2
  ) as recommendation_score
from public.flyer_items fi
join public.flyer_publications fp on fp.id = fi.flyer_publication_id
join public.grocery_store_chains c on c.id = fp.chain_id
left join public.canonical_food_images cfi on cfi.canonical_key = fi.normalized_name_en and cfi.quality_status='approved'
where fi.is_food = true
  and fi.sale_price is not null
  and fi.classification_status = 'approved'
  and fp.is_stale = false
  and current_date between fp.valid_from and fp.valid_until
  and coalesce(fi.source_payload->>'itemType', 'flyer') = 'flyer'
  and (
    coalesce(fi.health_priority_score, 50) >= 50
    or (
      fi.processing_level = 'ultra_processed'
      and coalesce(fi.provider_discount_percent, 0) >= 40
    )
  );

grant select on public.active_food_deals_app to anon, authenticated;
