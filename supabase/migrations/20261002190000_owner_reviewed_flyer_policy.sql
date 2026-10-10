-- Owner review is the final safety gate after the older lexical classifiers.
-- Keep the quoted price for audit, but do not publish unresolved variants.
create or replace function public.lemora_enforce_owner_flyer_policy()
returns trigger
language plpgsql
set search_path = ''
as $function$
declare
  decision text := coalesce(
    new.source_payload #>> '{foodPolicy,decision}',
    new.source_payload #>> '{ownerReview,decision}'
  );
begin
  if decision = 'rejected' then
    new.classification_status := 'rejected';
    new.classification_notes := 'Excluded by the owner-reviewed food policy.';
  elsif decision = 'review' then
    new.classification_status := 'review_required';
    new.classification_notes := 'Exact product variant or nutritional details require review.';
  end if;
  return new;
end
$function$;

drop trigger if exists zzz_lemora_owner_flyer_policy on public.flyer_items;
create trigger zzz_lemora_owner_flyer_policy
before insert or update on public.flyer_items
for each row execute function public.lemora_enforce_owner_flyer_policy();

-- Re-evaluate the manually reviewed pilot rows through the new final gate.
update public.flyer_items
set source_payload = source_payload
where flyer_publication_id in (
  select id from public.flyer_publications
  where source_provider = 'apify_flipp_v2' and source_flyer_id = '8164201'
)
  and dedup_key like 'owner_reviewed_apify_20261002_%';
