-- One publication is one source flyer edition, independent of Apify run/dataset.
-- Keep the existing source_url uniqueness for legacy imports; new imports use the
-- stable provider flyer ID and the uniqueness index below.
alter table public.flyer_publications
  add column if not exists source_provider text,
  add column if not exists source_flyer_id text,
  add column if not exists source_merchant_id text,
  add column if not exists original_flyer_url text,
  add column if not exists last_observed_at timestamptz;

-- Historical records are only backfilled when all their items agree on flyer ID.
with unambiguous as (
  select fi.flyer_publication_id,
         min(fi.source_payload->>'flyerId') as flyer_id,
         min(fi.source_payload->>'merchantId') as merchant_id
  from public.flyer_items fi
  where nullif(fi.source_payload->>'flyerId', '') is not null
  group by fi.flyer_publication_id
  having count(distinct fi.source_payload->>'flyerId') = 1
)
update public.flyer_publications fp
set source_provider = 'apify_flipp',
    source_flyer_id = u.flyer_id,
    source_merchant_id = u.merchant_id
from unambiguous u
where fp.id = u.flyer_publication_id
  and fp.source_flyer_id is null;

create unique index if not exists flyer_publications_source_edition_key
  on public.flyer_publications
  (chain_id, source_provider, source_flyer_id, valid_from, valid_until)
  where source_provider is not null and source_flyer_id is not null;

-- A postal observation is evidence for that exact postal code, not for a
-- province, FSA, neighbouring postal code, or every branch of the banner.
create table if not exists public.flyer_postal_coverage (
  publication_id uuid not null references public.flyer_publications(id) on delete cascade,
  postal_code text not null,
  first_observed_at timestamptz not null default now(),
  last_observed_at timestamptz not null default now(),
  last_ingestion_run_id uuid references public.ingestion_runs(id) on delete set null,
  primary key (publication_id, postal_code),
  constraint flyer_postal_coverage_canadian_postal_check
    check (postal_code ~ '^[ABCEGHJ-NPRSTVXY][0-9][ABCEGHJ-NPRSTV-Z][0-9][ABCEGHJ-NPRSTV-Z][0-9]$')
);

create index if not exists flyer_postal_coverage_postal_idx
  on public.flyer_postal_coverage (postal_code, publication_id);

-- The old Apify sweep used cross-postal deduplication. Its observed postals
-- can be recorded, but missing observations must never imply coverage.
insert into public.flyer_postal_coverage (publication_id, postal_code)
select distinct fi.flyer_publication_id,
       upper(regexp_replace(fi.source_postal_code, '[^A-Za-z0-9]', '', 'g'))
from public.flyer_items fi
join public.flyer_publications fp on fp.id = fi.flyer_publication_id
where fp.source_provider = 'apify_flipp'
  and upper(regexp_replace(coalesce(fi.source_postal_code, ''), '[^A-Za-z0-9]', '', 'g'))
      ~ '^[ABCEGHJ-NPRSTVXY][0-9][ABCEGHJ-NPRSTV-Z][0-9][ABCEGHJ-NPRSTV-Z][0-9]$'
on conflict (publication_id, postal_code) do nothing;

-- A stable flyer region can be assigned only after a store-level mapping has
-- been verified. The Apify flyer feed usually has no store ID.
create table if not exists public.flyer_regions (
  id uuid primary key default gen_random_uuid(),
  chain_id uuid not null references public.grocery_store_chains(id) on delete cascade,
  region_key text not null,
  display_name text,
  mapping_status text not null default 'unverified'
    check (mapping_status in ('unverified', 'verified')),
  created_at timestamptz not null default now(),
  unique (chain_id, region_key)
);

alter table public.grocery_store_locations
  add column if not exists source_provider text,
  add column if not exists source_store_id text,
  add column if not exists flyer_region_id uuid references public.flyer_regions(id) on delete set null;

create unique index if not exists grocery_store_locations_source_key
  on public.grocery_store_locations (chain_id, source_provider, source_store_id)
  where source_provider is not null and source_store_id is not null;

alter table public.flyer_publications
  add column if not exists flyer_region_id uuid references public.flyer_regions(id) on delete set null;

create index if not exists flyer_publications_active_source_idx
  on public.flyer_publications (chain_id, valid_until, valid_from)
  where is_stale = false;

alter table public.flyer_postal_coverage enable row level security;
alter table public.flyer_regions enable row level security;

-- Only server-side ingestion may mutate the evidence and region mapping.
revoke all on public.flyer_postal_coverage from anon, authenticated;
revoke all on public.flyer_regions from anon, authenticated;
grant select, insert, update, delete on public.flyer_postal_coverage to service_role;
grant select, insert, update, delete on public.flyer_regions to service_role;
