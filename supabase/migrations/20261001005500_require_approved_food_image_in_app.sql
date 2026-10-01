create or replace view public.active_food_deals_app
with (security_invoker = true)
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
  coalesce(fi.source_payload->>'currency', case when c.country_code='US' then 'USD' else 'CAD' end) as currency_code,
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
left join public.canonical_food_images cfi on cfi.canonical_key = fi.normalized_name_en and cfi.quality_status='approved'
where fi.is_food = true
  and fi.sale_price is not null
  and fi.classification_status = 'approved'
  and fp.is_stale = false
  and current_date between fp.valid_from and fp.valid_until
  and coalesce(fi.source_payload->>'itemType', 'flyer') = 'flyer'
  and cfi.image_url is not null
  and lower(c.name) = any (array['maxi','provigo','iga','metro','super c','walmart','costco'])
  and public.lemora_is_health_recommendation_eligible(
    fi.processing_level,
    fi.food_category,
    fi.dietary_flags,
    fi.health_priority_score
  );

grant select on public.active_food_deals_app to anon, authenticated;

