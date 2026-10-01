alter table public.flyer_items
  add column if not exists processing_level text,
  add column if not exists health_priority_score smallint;

alter table public.flyer_items
  drop constraint if exists flyer_items_processing_level_check,
  add constraint flyer_items_processing_level_check
    check (processing_level in ('whole', 'minimally_processed', 'processed', 'ultra_processed', 'unknown')),
  drop constraint if exists flyer_items_health_priority_score_check,
  add constraint flyer_items_health_priority_score_check
    check (health_priority_score between 0 and 100);

create or replace function public.lemora_processing_level(input_name text, category text)
returns text
language sql
immutable
set search_path = ''
as $function$
  with cleaned as (
    select lower(public.unaccent(coalesce(input_name, ''))) as s
  )
  select case
    when s ~ '(chips|croustille|cookie|biscuit|candy|bonbon|chocolat|soft drink|soda|liqueur|energy drink|boisson energ|frozen pizza|pizza surgelee|frozen meal|repas surgele|instant noodle|nouille instant|donut|beigne|cake|gateau|ice cream|creme glacee|hot dog|wiener|saucisse fumee)'
      then 'ultra_processed'
    when coalesce(category, '') in ('produce', 'protein')
      and s !~ '(breaded|pane|seasoned|assaisonne|marinated|marine|deli|charcuterie)'
      then 'whole'
    when s ~ '(egg|oeuf|lentil|lentille|bean|haricot|chickpea|pois chiche|tofu|oat|avoine|plain yogurt|yogourt nature|milk|lait|frozen vegetable|legume surgele)'
      then 'minimally_processed'
    when s ~ '(bread|pain|pasta|pate|rice|riz|cheese|fromage|yogurt|yogourt|hummus|peanut butter|beurre d arachide|canned|conserve|frozen|surgele)'
      then 'processed'
    else 'unknown'
  end
  from cleaned
$function$;

create or replace function public.lemora_health_priority(input_name text, category text)
returns smallint
language sql
immutable
set search_path = ''
as $function$
  select case public.lemora_processing_level(input_name, category)
    when 'whole' then 100
    when 'minimally_processed' then 85
    when 'processed' then 60
    when 'ultra_processed' then 15
    else 50
  end::smallint
$function$;

create or replace function public.lemora_set_health_priority()
returns trigger
language plpgsql
set search_path = ''
as $function$
begin
  new.processing_level := public.lemora_processing_level(new.raw_description, new.food_category);
  new.health_priority_score := public.lemora_health_priority(new.raw_description, new.food_category);
  return new;
end
$function$;

drop trigger if exists zz_lemora_set_health_priority on public.flyer_items;
create trigger zz_lemora_set_health_priority
before insert or update of raw_description, food_category
on public.flyer_items
for each row execute function public.lemora_set_health_priority();

update public.flyer_items
set processing_level = public.lemora_processing_level(raw_description, food_category),
    health_priority_score = public.lemora_health_priority(raw_description, food_category)
where processing_level is null or health_priority_score is null;

create table if not exists public.canonical_food_images (
  canonical_key text primary key,
  canonical_name_en text not null,
  canonical_name_fr text not null,
  image_url text not null,
  source_page_url text not null,
  photographer_or_creator text,
  license_code text not null,
  license_url text not null,
  attribution_text text,
  quality_status text not null default 'approved'
    check (quality_status in ('candidate', 'approved', 'rejected')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.canonical_food_images enable row level security;
revoke all on public.canonical_food_images from anon, authenticated;
grant select on public.canonical_food_images to anon, authenticated;

drop policy if exists canonical_food_images_public_read on public.canonical_food_images;
create policy canonical_food_images_public_read
on public.canonical_food_images for select
to anon, authenticated
using (quality_status = 'approved');

create index if not exists idx_flyer_items_health_priority
  on public.flyer_items (health_priority_score desc, deal_score desc)
  where is_food = true and sale_price is not null;

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
  case
    when fi.provider_discount_percent >= 45 then 'rareDeal'
    when fi.provider_discount_percent >= 30 then 'greatPrice'
    when fi.provider_discount_percent >= 15 then 'goodPrice'
    else null
  end as deal_label,
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
  cfi.attribution_text as image_attribution
from public.flyer_items fi
join public.flyer_publications fp on fp.id = fi.flyer_publication_id
join public.grocery_store_chains c on c.id = fp.chain_id
left join public.canonical_food_images cfi
  on cfi.canonical_key = fi.normalized_name_en
 and cfi.quality_status = 'approved'
where fi.is_food = true
  and fi.sale_price is not null
  and fp.is_stale = false
  and current_date between fp.valid_from and fp.valid_until
  and coalesce(fi.source_payload->>'itemType', 'flyer') = 'flyer'
  and coalesce(fi.health_priority_score, 50) >= 50;

grant select on public.active_food_deals_app to anon, authenticated;
