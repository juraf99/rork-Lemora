-- Verified Apify test run lYhTdmvC8EFKbjKHm / dataset UKxGrSuTfOEwa7R4S.
-- Exact promotion dates come from Flipp through the Actor; nothing is inferred.

with input as (
  select * from jsonb_to_recordset($data$
  [
    {"item_id":"1041313766","name":"Natrel fine-filtered milk","brand":null,"merchant":"Walmart","merchant_id":234,"flyer_id":8141628,"flyer_name":"Flyer","price":4.57,"regular_price":5.78,"discount_pct":21,"valid_from":"2026-09-24","valid_until":"2026-09-30","image_url":"https://f.wishabi.net/page_items/434174776/1789972338/extra_large.jpg","postal_code":"M5V2T6","locale":"en-ca","price_unit":null,"multi_quantity":null,"multi_total":null},
    {"item_id":"1043160689","name":"Natrel Milk Series","brand":"Natrel","merchant":"Fresh Land Supermarket","merchant_id":5666,"flyer_id":8160496,"flyer_name":"Indexed Weekly","price":5.98,"regular_price":8.99,"discount_pct":33,"valid_from":"2026-09-25","valid_until":"2026-10-01","image_url":"https://f.wishabi.net/page_items/435320360/1790230257/extra_large.jpg","postal_code":"M5V2T6","locale":"en-ca","price_unit":"each","multi_quantity":null,"multi_total":null},
    {"item_id":"1041968342","name":"NATREL PLUS MILK","brand":null,"merchant":"Metro","merchant_id":2269,"flyer_id":8146178,"flyer_name":"Ontario","price":7.99,"regular_price":null,"discount_pct":null,"valid_from":"2026-09-24","valid_until":"2026-09-30","image_url":"https://f.wishabi.net/page_items/434419152/1789963062/extra_large.jpg","postal_code":"M5V2T6","locale":"en-ca","price_unit":"each","multi_quantity":null,"multi_total":null},
    {"item_id":"1042163026","name":"Organic Milk","brand":null,"merchant":"Longos","merchant_id":1978,"flyer_id":8147923,"flyer_name":"Weekly Flyer","price":8.99,"regular_price":10.99,"discount_pct":18,"valid_from":"2026-09-24","valid_until":"2026-09-30","image_url":"https://f.wishabi.net/page_items/434478268/1790024352/extra_large.jpg","postal_code":"M5V2T6","locale":"en-ca","price_unit":null,"multi_quantity":null,"multi_total":null},
    {"item_id":"1041640590","name":"MILK 2 GO MILK, 6X200 ML","brand":null,"merchant":"Real Canadian Superstore","merchant_id":2271,"flyer_id":8144669,"flyer_name":"Weekly Flyer","price":5.50,"regular_price":6.97,"discount_pct":21,"valid_from":"2026-09-24","valid_until":"2026-09-30","image_url":"https://f.wishabi.net/page_items/434324402/1789766756/extra_large.jpg","postal_code":"M5V2T6","locale":"en-ca","price_unit":null,"multi_quantity":null,"multi_total":null},
    {"item_id":"1041517920","name":"LACTANTIA ULTRA PUR MILK","brand":null,"merchant":"Food Basics","merchant_id":2265,"flyer_id":8142714,"flyer_name":"Weekly Ad","price":7.49,"regular_price":null,"discount_pct":null,"valid_from":"2026-09-24","valid_until":"2026-09-30","image_url":"https://f.wishabi.net/page_items/434258215/1789724156/extra_large.jpg","postal_code":"M5V2T6","locale":"en-ca","price_unit":"each","multi_quantity":null,"multi_total":null},
    {"item_id":"1042163287","name":"UltraPür Milk","brand":null,"merchant":"Longos","merchant_id":1978,"flyer_id":8147923,"flyer_name":"Weekly Flyer","price":7.49,"regular_price":8.49,"discount_pct":12,"valid_from":"2026-09-24","valid_until":"2026-09-30","image_url":"https://f.wishabi.net/page_items/434478473/1790024347/extra_large.jpg","postal_code":"M5V2T6","locale":"en-ca","price_unit":null,"multi_quantity":null,"multi_total":null},
    {"item_id":"1041213436","name":"Phoenicia milk beverage","brand":null,"merchant":"Adonis","merchant_id":3384,"flyer_id":8141032,"flyer_name":"Weekly","price":5.00,"regular_price":null,"discount_pct":34,"valid_from":"2026-09-24","valid_until":"2026-09-30","image_url":"https://f.wishabi.net/page_items/434054188/1789601053/extra_large.jpg","postal_code":"M5V2T6","locale":"en-ca","price_unit":null,"multi_quantity":2,"multi_total":5.00},
    {"item_id":"1039800954","name":"Organic Meadow Organic Milk","brand":null,"merchant":"Nature's Emporium","merchant_id":3097,"flyer_id":8131574,"flyer_name":"In-Store Specials","price":9.99,"regular_price":12.99,"discount_pct":23,"valid_from":"2026-09-17","valid_until":"2026-09-30","image_url":"https://f.wishabi.net/page_items/433615585/1789088672/extra_large.jpg","postal_code":"M5V2T6","locale":"en-ca","price_unit":null,"multi_quantity":null,"multi_total":null},
    {"item_id":"1037741391","name":"BEST BAA Sheep Milk Feta","brand":"BEST BAA","merchant":"The Big Carrot","merchant_id":3304,"flyer_id":8119043,"flyer_name":"Indexed Monthly","price":9.29,"regular_price":10.99,"discount_pct":15,"valid_from":"2026-09-01","valid_until":"2026-09-30","image_url":"https://f.wishabi.net/page_items/432668742/1788241597/extra_large.jpg","postal_code":"M5V2T6","locale":"en-ca","price_unit":null,"multi_quantity":null,"multi_total":null}
  ]$data$::jsonb) as x(
    item_id text, name text, brand text, merchant text, merchant_id integer,
    flyer_id bigint, flyer_name text, price numeric, regular_price numeric,
    discount_pct numeric, valid_from date, valid_until date, image_url text,
    postal_code text, locale text, price_unit text, multi_quantity integer, multi_total numeric
  )
), source as (
  select id from public.data_sources
  where provider_type = 'RetailerApiProvider'
    and config->>'actor' = 'yugenox/flipp-flyer-deals-scraper'
  order by created_at desc limit 1
), run as (
  insert into public.ingestion_runs (data_source_id, status, items_seen, notes)
  select source.id, 'running', 10, 'Apify test run lYhTdmvC8EFKbjKHm; dataset UKxGrSuTfOEwa7R4S' from source
  returning id
), inserted_chains as (
  insert into public.grocery_store_chains (
    name, canonical_name, display_name_en, country_code, regions, province_state_code,
    is_active, data_source_type, data_source_identifier, data_confidence,
    last_ingestion_attempt, last_successful_ingestion
  )
  select distinct
    merchant,
    trim(both '_' from regexp_replace(lower(unaccent(merchant)), '[^a-z0-9]+', '_', 'g')),
    merchant, 'CA', array['ON'], 'ON', true, 'AUTOMATIC_PARTIAL',
    'apify_flipp:' || merchant_id, 'medium', now(), now()
  from input
  on conflict (country_code, canonical_name) where canonical_name is not null
  do update set
    regions = (select array_agg(distinct value) from unnest(coalesce(grocery_store_chains.regions, '{}') || excluded.regions) value),
    last_ingestion_attempt = excluded.last_ingestion_attempt,
    last_successful_ingestion = excluded.last_successful_ingestion
  returning id, country_code, canonical_name
), publications as (
  insert into public.flyer_publications (
    chain_id, data_source_id, region_codes, valid_from, valid_until,
    source_url, ingestion_run_id, is_stale
  )
  select distinct
    c.id, source.id, array['ON'], i.valid_from, i.valid_until,
    'https://console.apify.com/storage/datasets/UKxGrSuTfOEwa7R4S#flyer-' || i.flyer_id,
    run.id, false
  from input i
  join inserted_chains c
    on c.country_code='CA'
   and c.canonical_name=trim(both '_' from regexp_replace(lower(unaccent(i.merchant)), '[^a-z0-9]+', '_', 'g'))
  cross join source cross join run
  on conflict (chain_id, valid_from, valid_until, source_url)
  do update set ingestion_run_id=excluded.ingestion_run_id, region_codes=excluded.region_codes, is_stale=false
  returning id, chain_id, valid_from, valid_until, source_url
), written as (
  insert into public.flyer_items (
    flyer_publication_id, raw_description, raw_brand, regular_price, sale_price,
    multi_buy_quantity, multi_buy_total_price, dedup_key, source_item_id,
    source_locale, source_postal_code, image_url, source_payload
  )
  select
    p.id, i.name, i.brand, i.regular_price, i.price, i.multi_quantity, i.multi_total,
    i.item_id, i.item_id, i.locale, i.postal_code, i.image_url,
    jsonb_build_object(
      'itemId',i.item_id,'itemType','flyer','merchant',i.merchant,'merchantId',i.merchant_id,
      'flyerId',i.flyer_id,'flyerName',i.flyer_name,'currentPrice',i.price,
      'originalPrice',i.regular_price,'discountPct',i.discount_pct,'currency','CAD',
      'priceUnit',i.price_unit,'postalCode',i.postal_code,'locale',i.locale,
      'datasetId','UKxGrSuTfOEwa7R4S','apifyRunId','lYhTdmvC8EFKbjKHm'
    )
  from input i
  join inserted_chains c
    on c.country_code='CA'
   and c.canonical_name=trim(both '_' from regexp_replace(lower(unaccent(i.merchant)), '[^a-z0-9]+', '_', 'g'))
  join publications p on p.chain_id=c.id and p.valid_from=i.valid_from and p.valid_until=i.valid_until
    and p.source_url='https://console.apify.com/storage/datasets/UKxGrSuTfOEwa7R4S#flyer-' || i.flyer_id
  on conflict (flyer_publication_id, dedup_key)
  do update set
    raw_description=excluded.raw_description, raw_brand=excluded.raw_brand,
    regular_price=excluded.regular_price, sale_price=excluded.sale_price,
    multi_buy_quantity=excluded.multi_buy_quantity, multi_buy_total_price=excluded.multi_buy_total_price,
    image_url=excluded.image_url, source_payload=excluded.source_payload
  returning id
)
update public.ingestion_runs
set status='succeeded', finished_at=now(), items_upserted=(select count(*) from written), items_rejected=0
where id=(select id from run);
