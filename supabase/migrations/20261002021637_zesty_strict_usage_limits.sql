-- Server-owned Ask allowances. All times are database UTC timestamps; no device clock is trusted.
create table public.zesty_usage_limits (
  id boolean primary key default true check (id),
  trial_total integer not null default 10 check (trial_total > 0),
  trial_24h integer not null default 6 check (trial_24h > 0),
  paid_30d integer not null default 50 check (paid_30d > 0),
  paid_7d integer not null default 16 check (paid_7d > 0),
  paid_24h integer not null default 6 check (paid_24h > 0)
);
insert into public.zesty_usage_limits(id) values (true);

create table public.zesty_usage_events (
  request_id uuid primary key,
  clerk_user_id text not null,
  created_at timestamptz not null default now(),
  access_phase text not null check (access_phase in ('trial', 'paid')),
  subscription_status text not null default 'active',
  entitlement_id text not null default 'lemora_pro',
  state text not null default 'reserved' check (state in ('reserved', 'accepted', 'completed', 'refunded')),
  model text,
  input_tokens integer check (input_tokens >= 0),
  output_tokens integer check (output_tokens >= 0),
  estimated_ai_cost_usd numeric(12, 8) check (estimated_ai_cost_usd >= 0),
  completed_at timestamptz
);
create index zesty_usage_events_user_phase_time_idx
  on public.zesty_usage_events (clerk_user_id, access_phase, created_at desc)
  where state <> 'refunded';

alter table public.zesty_usage_limits enable row level security;
alter table public.zesty_usage_events enable row level security;
revoke all on public.zesty_usage_limits, public.zesty_usage_events from public, anon, authenticated;
grant select on public.zesty_usage_limits to service_role;
grant select, insert, update on public.zesty_usage_events to service_role;

-- Called only after a fresh server-to-RevenueCat entitlement check. The transaction
-- advisory lock serializes concurrent requests for one Clerk user across devices.
create function public.reserve_zesty_message(
  p_clerk_user_id text, p_request_id uuid, p_access_phase text, p_model text
) returns jsonb
language plpgsql security definer set search_path = ''
as $$
declare
  v_limits public.zesty_usage_limits%rowtype;
  v_now timestamptz := now();
  v_total integer;
  v_day integer;
  v_week integer;
  v_month integer;
  v_block text;
begin
  if p_clerk_user_id is null or p_clerk_user_id = '' or
     p_access_phase not in ('trial', 'paid') then
    raise exception 'invalid_zesty_reservation';
  end if;
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(p_clerk_user_id, 902101));
  select * into strict v_limits from public.zesty_usage_limits where id = true;
  select count(*) filter (where access_phase = 'trial'),
         count(*) filter (where access_phase = p_access_phase and created_at > v_now - interval '24 hours'),
         count(*) filter (where access_phase = 'paid' and created_at > v_now - interval '7 days'),
         count(*) filter (where access_phase = 'paid' and created_at > v_now - interval '30 days')
  into v_total, v_day, v_week, v_month
  from public.zesty_usage_events
  where clerk_user_id = p_clerk_user_id and state <> 'refunded';
  if p_access_phase = 'trial' then
    if v_total >= v_limits.trial_total then v_block := 'trial_total_limit';
    elsif v_day >= v_limits.trial_24h then v_block := 'daily_limit'; end if;
  else
    if v_month >= v_limits.paid_30d then v_block := 'period_limit';
    elsif v_week >= v_limits.paid_7d then v_block := 'weekly_limit';
    elsif v_day >= v_limits.paid_24h then v_block := 'daily_limit'; end if;
  end if;
  if v_block is not null then
    return pg_catalog.jsonb_build_object('allowed', false, 'reason', v_block,
      'remaining', case when p_access_phase = 'trial' then
        greatest(0, v_limits.trial_total - v_total)
        else greatest(0, v_limits.paid_30d - v_month) end);
  end if;
  insert into public.zesty_usage_events(request_id, clerk_user_id, access_phase, model)
    values (p_request_id, p_clerk_user_id, p_access_phase, p_model);
  return pg_catalog.jsonb_build_object('allowed', true,
    'remaining', case when p_access_phase = 'trial' then
      greatest(0, v_limits.trial_total - v_total - 1)
      else greatest(0, v_limits.paid_30d - v_month - 1) end);
end;
$$;

create function public.zesty_usage_snapshot(p_clerk_user_id text, p_access_phase text)
returns jsonb language sql security definer set search_path = '' as $$
  select pg_catalog.jsonb_build_object(
    'phase', p_access_phase,
    'remaining', case when p_access_phase = 'trial' then
      greatest(0, l.trial_total - count(e.request_id) filter (where e.access_phase = 'trial'))
      else greatest(0, l.paid_30d - count(e.request_id) filter
        (where e.access_phase = 'paid' and e.created_at > now() - interval '30 days')) end,
    'total', case when p_access_phase = 'trial' then l.trial_total else l.paid_30d end
  ) from public.zesty_usage_limits l
  left join public.zesty_usage_events e on e.clerk_user_id = p_clerk_user_id and e.state <> 'refunded'
  where l.id = true group by l.trial_total, l.paid_30d;
$$;

revoke all on function public.reserve_zesty_message(text, uuid, text, text) from public, anon, authenticated;
revoke all on function public.zesty_usage_snapshot(text, text) from public, anon, authenticated;
grant execute on function public.reserve_zesty_message(text, uuid, text, text) to service_role;
grant execute on function public.zesty_usage_snapshot(text, text) to service_role;
