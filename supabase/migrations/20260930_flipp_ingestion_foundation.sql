-- Lemora weekly flyer ingestion foundation.
-- The existing active_food_deals_app view already exposes valid_from/valid_until
-- and only returns food flyer items whose promotion is active today.

create unique index if not exists grocery_store_chains_country_canonical_uidx
  on public.grocery_store_chains (country_code, canonical_name)
  where canonical_name is not null;

create index if not exists flyer_publications_active_dates_idx
  on public.flyer_publications (is_stale, valid_from, valid_until);

create index if not exists flyer_publications_region_codes_gin_idx
  on public.flyer_publications using gin (region_codes);

create index if not exists flyer_items_publication_food_score_idx
  on public.flyer_items (flyer_publication_id, is_food, deal_score desc)
  where sale_price is not null;

-- Internal operational tables must not be readable from the mobile client.
drop policy if exists ingestion_runs_public_read on public.ingestion_runs;
drop policy if exists ingestion_errors_public_read on public.ingestion_errors;
revoke select on public.ingestion_runs, public.ingestion_errors from anon, authenticated;

-- Keep the app-facing view invoker-safe and explicitly readable.
alter view public.active_food_deals_app set (security_invoker = true);
grant select on public.active_food_deals_app to anon, authenticated;

