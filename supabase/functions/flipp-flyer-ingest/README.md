# Canadian weekly flyer ingestion (Apify)

`flipp-flyer-ingest` invokes `yugenox/flipp-flyer-deals-scraper` in flyer mode
and writes **food offers only** to Supabase. It does not crawl retailer sites
from the app. `APIFY_TOKEN` and `LEMORA_INGEST_SECRET` are server-side Edge
Function secrets; the latter must be supplied as `x-lemora-ingest-secret` by a
trusted scheduler. JWT verification remains enabled. Never ship either secret
in the iOS app.

Each call requires full Canadian `postalCodes` or the actor's
`ca-major-cities` preset. The default merchant list covers major Canadian
banners, but support and flyer availability must be measured per banner and
postal. The actor response is capped at 500 items per call and 25 postals. A
500-item cap is **not a Canada-wide scan**; a scheduler needs geographic
batches, watermarks, and a monthly spend ceiling before expansion.
Every live invocation must also specify `maxTotalChargeUsd` (greater than 0,
at most US$10). This is passed to Apify's run API as a per-run hard charge
ceiling; the item cap alone does not cap spending. The result records observed
postal/item counts, unique flyer IDs, postals that hit their item cap, and
whether the global cap was hit. `noKnownTruncation` does **not** establish
complete banner or geographic coverage. There is still no recurring national
schedule or monthly spend ceiling.

The database uses stable source flyer IDs and validity dates to reuse a
publication across runs, stores exact observed postals for both flyers and
individual items, and uses a semantic item key to prevent repeated cards. Since flyer-mode rows lack a
reliable physical store ID, an observed postal is *not* generalized to a
province, FSA, or nearby store. New editions are intentionally excluded from
the old broad `active_food_deals_app` view. The iOS app calls
`active_food_deals_for_postal` for a full Canadian postal; that read exposes
only current, approved, healthy, imaged offers observed at that exact postal.

The October 2 pilot with No Frills at M5V 2T6 returned 50 actor rows. After
the owner's item-by-item review, 13 additional priced lines from that existing
Apify export were imported into the exact-postal pilot; two previously stored
prepared-food lines were marked rejected. The exact-postal feed currently
returns four distinct, approved and imaged products: beef, broccoli, chicken
breast, and tomatoes. Ambiguous multi-product lines remain under review.
Items without a quoted current price (including points-only and coupon-only
offers) are not deals; invalid date ranges are also rejected. The food policy
is tested with `node scripts/test-flipp-food-policy.mjs` and cannot be bypassed
by setting `healthFocus` to false. Other accepted foods still require a valid
image and existing recommendation eligibility before they can be displayed.
No nationwide coverage or scheduled ingestion is implied by this pilot.

On October 3, a separately authorized Apify discovery run
[`HFHSmWVQEi0gurDT6`](https://console.apify.com/actors/58sScnjADg9dhsVve/runs/HFHSmWVQEi0gurDT6)
used Montreal H2X 1Y4, Vancouver V6B 1A1, Calgary T2P 1J9 and Halifax
B3J 2K9, six requested merchants, `maxItems=200`,
`maxItemsPerPostalCode=50`, cross-postal deduplication disabled, and a
US$0.50 run ceiling. It cost US$0.40 and returned exactly 50 rows per postal:
Walmart in Montreal, Vancouver and Halifax, and IGA in Calgary. The actor
reported nine nearby flyers, but items came from only four flyer IDs. This
**does not** prove that the other requested banners have no flyers: the
per-postal cap truncated enumeration after an early flyer. Walmart's
`Groceries` flyer category also included pet food, soap and other non-food.
The discovery output was not imported or displayed in Lemora. Future coverage
checks need per-banner/postal batches with explicit completeness checks, then
owner-policy review before publication. A partial first-50-row sample is not
a complete weekly flyer or a basis for an 80% coverage claim.

The owner policy now checks the item description as well as its title.
Ambiguous `or`/selected-variety lines require review, and whipped dessert
toppings are rejected; `review` is never automatic publication. That first
description-aware filter shipped in version 21. The pilot still has no
national schedule or verified store-to-flyer-region map.

The owner's October 3 follow-up admits Natrel/other milk, fresh produce,
yogurt, cheese blocks, oats, Barebells and Clif bars as food candidates.
Version 22 applies this expanded family policy; it does not infer macros,
low sugar, allergens or diet compatibility from a marketing name. A line
with different products or package sizes stays under review. The independent
database normalizer was corrected to keep pineapple distinct from apple.
Neither this policy deployment nor that schema fix imports the truncated
four-city dataset or publishes new app cards; the app feed also requires a
verified postal, price, classification, goal eligibility and approved image.

Expiry is separate from ingestion. Supabase Cron runs
`lemora-expire-past-flyers` daily at 12:00 GMT and calls
`lemora_expire_past_flyers()`. It marks a publication stale only when
`valid_until` is **before** the current Vancouver calendar date. The same
database function is called after an ingestion run. Both app deal views use
that conservative Canadian cutoff, so a flyer valid today or in the future
is never hidden early by UTC rollover. This is a soft expiry: flyers, items,
postal evidence and price history remain in Supabase. The job can be checked
in `cron.job` and its executions in `cron.job_run_details`.

Apify's advertised per-deal price is not a reliable end-to-end budget. Actor
runs, filtering, retries, and repeated postals can change the effective cost;
measure actual console spend before setting a recurring schedule.
