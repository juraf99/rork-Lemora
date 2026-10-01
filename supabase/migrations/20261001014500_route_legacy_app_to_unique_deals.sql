alter view public.active_food_deals_app rename to active_food_deals_source;

create view public.active_food_deals_app
with (security_invoker = true)
as
select * from public.active_food_deals_unique;

grant select on public.active_food_deals_source to anon, authenticated;
grant select on public.active_food_deals_app to anon, authenticated;
