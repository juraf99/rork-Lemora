-- New Apify editions are deliberately excluded from the legacy province/FSA
-- feed. This private view has the same row shape, but accepts only v2 editions.
create view public.active_food_deals_exact_postal_core
as
select
  fi.id,
  fi.normalized_name_en as ingredient_id,
  coalesce(cfi.canonical_name_en, replace(initcap(fi.normalized_name_en), '_', ' ')) as product_name,
  fi.raw_brand as brand,
  fi.raw_size as size_text,
  fi.sale_price,
  fi.regular_price,
  fi.multi_buy_quantity,
  fi.multi_buy_total_price,
  coalesce(fi.source_payload->>'priceUnit', '') as unit_label,
  fi.provider_discount_percent,
  fi.deal_score,
  fi.deal_confidence,
  case when fi.provider_discount_percent >= 45 then 'rareDeal'
       when fi.provider_discount_percent >= 30 then 'greatPrice'
       when fi.provider_discount_percent >= 15 then 'goodPrice' end as deal_label,
  fi.food_category,
  fi.dietary_flags,
  fi.allergen_flags,
  cfi.image_url,
  fi.product_url,
  fi.source_postal_code,
  fi.source_locale,
  coalesce(fi.source_payload->>'currency', 'CAD') as currency_code,
  fp.valid_from,
  fp.valid_until,
  fp.region_codes,
  c.id as chain_id,
  coalesce(c.canonical_name, lower(regexp_replace(c.name, '[^a-zA-Z0-9]+', '_', 'g'))) as retailer_id,
  c.name as retailer_name,
  c.country_code,
  fi.raw_description as retailer_product_name,
  fi.image_url as retailer_image_url,
  fi.processing_level,
  fi.health_priority_score,
  cfi.canonical_name_fr,
  cfi.source_page_url as image_source_page_url,
  cfi.photographer_or_creator as image_creator,
  cfi.license_code as image_license_code,
  cfi.attribution_text as image_attribution,
  public.lemora_common_food_score(fi.normalized_name_en) as common_food_score,
  round((
    least(100, greatest(coalesce(fi.deal_score, 0), coalesce(fi.provider_discount_percent, 0))) * 0.50
    + public.lemora_common_food_score(fi.normalized_name_en) * 0.30
    + coalesce(fi.health_priority_score, 0) * 0.20
  ) * case when fi.processing_level = 'processed' then 0.75 else 1.00 end, 2) as recommendation_score,
  public.lemora_goal_fit_tags(fi.dietary_flags) as goal_fit_tags,
  case
    when fi.processing_level in ('whole', 'minimally_processed') then 'whole_or_minimally_processed'
    when fi.processing_level = 'processed' and fi.dietary_flags->>'high_protein' = 'yes' then 'processed_high_protein_exception'
  end as health_eligibility_reason
from public.flyer_items fi
join public.flyer_publications fp on fp.id = fi.flyer_publication_id
join public.grocery_store_chains c on c.id = fp.chain_id
join public.canonical_food_images cfi
  on cfi.canonical_key = fi.normalized_name_en and cfi.quality_status = 'approved'
where fp.source_provider = 'apify_flipp_v2'
  and fi.is_food = true
  and fi.sale_price is not null
  and fi.classification_status = 'approved'
  and current_date between fp.valid_from and fp.valid_until
  and coalesce(fi.source_payload->>'itemType', 'flyer') = 'flyer'
  and c.country_code = 'CA'
  and public.lemora_is_health_recommendation_eligible(
    fi.processing_level, fi.food_category, fi.dietary_flags, fi.health_priority_score
  );

-- Never grant direct access to the core view: it has no postal restriction.
revoke all on public.active_food_deals_exact_postal_core from public, anon, authenticated;

create or replace function public.active_food_deals_for_postal(p_postal text)
returns setof public.active_food_deals_app
language sql stable security definer
set search_path = ''
as $$
  select distinct on (d.country_code, d.retailer_id, d.ingredient_id) d.*
  from public.active_food_deals_exact_postal_core d
  join public.flyer_items fi on fi.id = d.id
  join public.flyer_postal_coverage fpc
    on fpc.publication_id = fi.flyer_publication_id
  where upper(regexp_replace(coalesce(p_postal, ''), '[^A-Za-z0-9]', '', 'g'))
      ~ '^[ABCEGHJ-NPRSTVXY][0-9][ABCEGHJ-NPRSTV-Z][0-9][ABCEGHJ-NPRSTV-Z][0-9]$'
    and fpc.postal_code = upper(regexp_replace(p_postal, '[^A-Za-z0-9]', '', 'g'))
  order by d.country_code, d.retailer_id, d.ingredient_id,
           d.recommendation_score desc nulls last,
           d.deal_score desc nulls last, d.sale_price asc, d.id;
$$;

revoke all on function public.active_food_deals_for_postal(text) from public;
grant execute on function public.active_food_deals_for_postal(text) to anon, authenticated;

create index if not exists flyer_postal_coverage_run_idx
  on public.flyer_postal_coverage (last_ingestion_run_id);
create index if not exists flyer_publications_region_idx
  on public.flyer_publications (flyer_region_id);
create index if not exists grocery_store_locations_region_idx
  on public.grocery_store_locations (flyer_region_id);
