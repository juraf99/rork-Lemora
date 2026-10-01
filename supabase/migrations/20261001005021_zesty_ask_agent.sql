-- Zesty Ask: server-owned conversation, context and usage records.
-- The iOS app authenticates with Clerk/Rork, so these tables are never exposed
-- directly through the Data API. The ask-zesty Edge Function verifies the Clerk
-- token and uses the service role after deriving the caller id from that token.

create table public.zesty_user_contexts (
  clerk_user_id text primary key,
  context jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now(),
  constraint zesty_user_contexts_context_object check (jsonb_typeof(context) = 'object')
);

create table public.zesty_conversations (
  id uuid primary key default gen_random_uuid(),
  clerk_user_id text not null,
  openai_session_id text unique,
  locale text not null default 'en',
  title text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index zesty_conversations_user_updated_idx
  on public.zesty_conversations (clerk_user_id, updated_at desc);

create table public.zesty_messages (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.zesty_conversations(id) on delete cascade,
  clerk_user_id text not null,
  role text not null check (role in ('user', 'assistant')),
  content text not null check (length(content) between 1 and 20000),
  recommendations jsonb not null default '[]'::jsonb,
  openai_turn_id text,
  input_tokens integer not null default 0 check (input_tokens >= 0),
  output_tokens integer not null default 0 check (output_tokens >= 0),
  created_at timestamptz not null default now(),
  constraint zesty_messages_recommendations_array check (jsonb_typeof(recommendations) = 'array')
);

create index zesty_messages_conversation_created_idx
  on public.zesty_messages (conversation_id, created_at);

create table public.zesty_daily_usage (
  clerk_user_id text not null,
  usage_date date not null,
  question_count integer not null default 0 check (question_count >= 0),
  input_tokens bigint not null default 0 check (input_tokens >= 0),
  output_tokens bigint not null default 0 check (output_tokens >= 0),
  updated_at timestamptz not null default now(),
  primary key (clerk_user_id, usage_date)
);

alter table public.zesty_user_contexts enable row level security;
alter table public.zesty_conversations enable row level security;
alter table public.zesty_messages enable row level security;
alter table public.zesty_daily_usage enable row level security;

-- Explicit deny policies document that mobile clients have no direct access.
create policy zesty_user_contexts_server_only on public.zesty_user_contexts
  as restrictive for all to anon, authenticated using (false) with check (false);
create policy zesty_conversations_server_only on public.zesty_conversations
  as restrictive for all to anon, authenticated using (false) with check (false);
create policy zesty_messages_server_only on public.zesty_messages
  as restrictive for all to anon, authenticated using (false) with check (false);
create policy zesty_daily_usage_server_only on public.zesty_daily_usage
  as restrictive for all to anon, authenticated using (false) with check (false);

revoke all on public.zesty_user_contexts from anon, authenticated;
revoke all on public.zesty_conversations from anon, authenticated;
revoke all on public.zesty_messages from anon, authenticated;
revoke all on public.zesty_daily_usage from anon, authenticated;
grant all on public.zesty_user_contexts to service_role;
grant all on public.zesty_conversations to service_role;
grant all on public.zesty_messages to service_role;
grant all on public.zesty_daily_usage to service_role;

create or replace function public.record_zesty_usage(
  p_clerk_user_id text,
  p_usage_date date,
  p_input_tokens integer default 0,
  p_output_tokens integer default 0
)
returns public.zesty_daily_usage
language sql
security definer
set search_path = pg_catalog, public
as $$
  insert into public.zesty_daily_usage (
    clerk_user_id, usage_date, question_count, input_tokens, output_tokens, updated_at
  ) values (
    p_clerk_user_id,
    p_usage_date,
    1,
    greatest(p_input_tokens, 0),
    greatest(p_output_tokens, 0),
    now()
  )
  on conflict (clerk_user_id, usage_date) do update set
    question_count = public.zesty_daily_usage.question_count + 1,
    input_tokens = public.zesty_daily_usage.input_tokens + greatest(excluded.input_tokens, 0),
    output_tokens = public.zesty_daily_usage.output_tokens + greatest(excluded.output_tokens, 0),
    updated_at = now()
  returning *;
$$;

revoke all on function public.record_zesty_usage(text, date, integer, integer) from public, anon, authenticated;
grant execute on function public.record_zesty_usage(text, date, integer, integer) to service_role;
