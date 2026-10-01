# Flipp flyer ingestion

This Edge Function starts `yugenox/flipp-flyer-deals-scraper`, stores exact
`valid_from` and `valid_until` dates, classifies food through the database
trigger, and updates the existing `active_food_deals_app` read model.

Required server secret:

```text
APIFY_TOKEN
```

The function intentionally has JWT verification enabled. Scheduled calls must
send a valid Supabase authorization token. Keep the Apify token server-side;
never add it to the iPhone project or Git.

The scheduled payload controls the cost through `maxItems`. At the current
Actor price of USD 0.0015 per returned deal, 500 items is at most USD 0.75 per
run before any future Actor pricing change.

