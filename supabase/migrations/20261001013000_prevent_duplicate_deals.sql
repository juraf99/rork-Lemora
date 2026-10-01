create or replace view public.active_food_deals_unique
with (security_invoker = true)
as
select distinct on (country_code, retailer_id, ingredient_id, region_codes)
  *
from public.active_food_deals_app
order by
  country_code,
  retailer_id,
  ingredient_id,
  region_codes,
  recommendation_score desc nulls last,
  deal_score desc nulls last,
  sale_price asc,
  id;

grant select on public.active_food_deals_unique to anon, authenticated;
