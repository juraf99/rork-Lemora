-- A flyer edition can share its ID across postals while individual offers
-- differ. Publication coverage alone is not evidence for every item.
create table public.flyer_item_postal_coverage (
  item_id uuid not null references public.flyer_items(id) on delete cascade,
  postal_code text not null,
  first_observed_at timestamptz not null default now(),
  last_observed_at timestamptz not null default now(),
  last_ingestion_run_id uuid references public.ingestion_runs(id) on delete set null,
  primary key (item_id, postal_code),
  constraint flyer_item_postal_coverage_canadian_postal_check
    check (postal_code ~ '^[ABCEGHJ-NPRSTVXY][0-9][ABCEGHJ-NPRSTV-Z][0-9][ABCEGHJ-NPRSTV-Z][0-9]$')
);

create index flyer_item_postal_coverage_postal_idx
  on public.flyer_item_postal_coverage (postal_code, item_id);
create index flyer_item_postal_coverage_run_idx
  on public.flyer_item_postal_coverage (last_ingestion_run_id);

insert into public.flyer_item_postal_coverage (item_id, postal_code)
select fi.id, upper(regexp_replace(fi.source_postal_code, '[^A-Za-z0-9]', '', 'g'))
from public.flyer_items fi
join public.flyer_publications fp on fp.id = fi.flyer_publication_id
where fp.source_provider = 'apify_flipp_v2'
  and upper(regexp_replace(coalesce(fi.source_postal_code, ''), '[^A-Za-z0-9]', '', 'g'))
      ~ '^[ABCEGHJ-NPRSTVXY][0-9][ABCEGHJ-NPRSTV-Z][0-9][ABCEGHJ-NPRSTV-Z][0-9]$'
on conflict (item_id, postal_code) do nothing;

alter table public.flyer_item_postal_coverage enable row level security;
revoke all on public.flyer_item_postal_coverage from anon, authenticated;
grant select, insert, update, delete on public.flyer_item_postal_coverage to service_role;

create or replace function public.active_food_deals_for_postal(p_postal text)
returns setof public.active_food_deals_app
language sql stable security definer
set search_path = ''
as $$
  select distinct on (d.country_code, d.retailer_id, d.ingredient_id) d.*
  from public.active_food_deals_exact_postal_core d
  join public.flyer_item_postal_coverage fic on fic.item_id = d.id
  where upper(regexp_replace(coalesce(p_postal, ''), '[^A-Za-z0-9]', '', 'g'))
      ~ '^[ABCEGHJ-NPRSTVXY][0-9][ABCEGHJ-NPRSTV-Z][0-9][ABCEGHJ-NPRSTV-Z][0-9]$'
    and fic.postal_code = upper(regexp_replace(p_postal, '[^A-Za-z0-9]', '', 'g'))
  order by d.country_code, d.retailer_id, d.ingredient_id,
           d.recommendation_score desc nulls last,
           d.deal_score desc nulls last, d.sale_price asc, d.id;
$$;
