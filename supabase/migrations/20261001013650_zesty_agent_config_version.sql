alter table public.zesty_conversations
  add column if not exists agent_config_version text;

comment on column public.zesty_conversations.agent_config_version is
  'Version of the Zesty instructions and tool configuration used to create the OpenAI Agents session.';
