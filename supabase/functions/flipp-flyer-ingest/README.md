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
