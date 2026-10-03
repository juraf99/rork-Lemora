-- Flyer dates are retailer-local calendar dates. Vancouver is the last
-- Canadian major time zone to enter a new day, so this cutoff is deliberately
-- conservative across Canada: it can expire late in the east, never early.
create or replace function public.lemora_canada_safe_today()
returns date
language sql stable
set search_path = ''
as $function$
  select (now() at time zone 'America/Vancouver')::date
$function$;

-- Keep all publication, item and price-history rows. Only remove an already
-- expired publication from live recommendation views.
create or replace function public.lemora_expire_past_flyers()
returns integer
language plpgsql
set search_path = ''
as $function$
declare
  expired_count integer;
begin
  update public.flyer_publications
     set is_stale = true
   where is_stale = false
     and valid_until < public.lemora_canada_safe_today();
  get diagnostics expired_count = row_count;
  return expired_count;
end
$function$;

revoke all on function public.lemora_expire_past_flyers() from public, anon, authenticated;
grant execute on function public.lemora_expire_past_flyers() to service_role;

-- Both legacy and exact-postal feeds previously used UTC CURRENT_DATE, which
-- could hide a still-current Canadian flyer several hours before local midnight.
-- Assert the expected view shape, then replace only those date expressions.
do $migration$
declare
  view_name text;
  view_sql text;
  use_count integer;
begin
  foreach view_name in array array['active_food_deals_source', 'active_food_deals_exact_postal_core'] loop
    select pg_get_viewdef(format('public.%I', view_name)::regclass, true) into view_sql;
    use_count := (length(view_sql) - length(replace(view_sql, 'CURRENT_DATE', ''))) / length('CURRENT_DATE');
    if use_count <> 2 then
      raise exception 'Unexpected date predicate in %, found % CURRENT_DATE expressions', view_name, use_count;
    end if;
    execute format(
      'create or replace view public.%I %s as %s',
      view_name,
      case when view_name = 'active_food_deals_source' then 'with (security_invoker = true)' else '' end,
      replace(view_sql, 'CURRENT_DATE', 'public.lemora_canada_safe_today()')
    );
  end loop;
end
$migration$;

-- The exact-postal core is unrestricted and must remain private; only its
-- postal-filtered RPC is exposed to the app.
revoke all on public.active_food_deals_exact_postal_core from public, anon, authenticated;

create extension if not exists pg_cron;

-- pg_cron runs in GMT. Noon GMT is after midnight in every Canadian province,
-- including the Pacific coast, year-round. The function re-checks the date
-- inside its UPDATE so a delayed or manual run remains safe.
select cron.schedule(
  'lemora-expire-past-flyers',
  '0 12 * * *',
  'select public.lemora_expire_past_flyers();'
);
