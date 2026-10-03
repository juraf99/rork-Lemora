# Lemora — shared product context

This document records decisions available in the user's instructions and the shared code. Update it when a decision changes; a private conversation with either assistant is not automatically available to the other.

## Product and ownership

The application is **Lemora**. Its lemon mascot is **Zesty**, also the persona answering in Ask. Some older Swift types and artwork filenames still contain `Zest`; these are compatibility identifiers, not the mascot's product name.

Claude primarily develops onboarding and visual design. Codex primarily develops Steals of the Week, recipe content and Ask. Changes to shared state, authentication or backend contracts must preserve both features.

## Current onboarding and account model

The active entry point is `LemoraOnboardingView`, selected by `ContentView`. Preserve Claude's v2 flow, artwork, animations, back navigation and resumption behaviour. Its questions cover discovery source, goal, conditional body goals, household, diet, allergies, dislikes, meal types, location, stores, budget and shopping strategy.

Meal preferences include breakfast, lunch, dinner, snacks and desserts; an empty selection means all meal types. Saved onboarding answers are mapped into `UserProfile` and stored through `onboarding-profile`. An unfinished flow reopens at the landing page; an answered flow reopens at the plan. Completed users with a lapsed subscription return to the plan/paywall flow.

Profile preference editors now reuse Claude's onboarding screens, including their cards, emoji and Zesty speech bubbles. Each editor writes back only the field it edits when the user leaves the screen. Preserve this design and its current preference values.

Authentication uses Clerk, including Apple, Google and email verification. Onboarding and Ask must both obtain the current Clerk session with `Clerk.shared.auth.getToken()`. RevenueCat ties purchases to the Clerk user ID; the entitlement is `lemora_pro`, with annual and monthly products. Preserve the subscription routing implemented by Claude.

Trial availability and displayed billing terms depend on the actual StoreKit product and the Apple account's eligibility. Preserve the trial/no-trial variants. Claude's downloaded `apply-timeline.yml` corrects the paywall connectors by sizing each timeline row to its content; that source change is included directly in this integration.

## Ask

Zesty answers in writing with a concise, friendly, lightly playful tone, in the user's language. Intent determines the response: app/profile help gets a direct answer; a nutrition follow-up stays on the previously discussed recipe. Recommendation cards support the written answer.

For meal ideas, try to reference two suitable app recipes when available. Give requested portions, scaled quantities and steps directly in text. When catalogue recipes are insufficient, Zesty can create a personalized suggestion and use external research when useful, combined with verified app deals and the user's profile. Never fabricate prices or confirmed allergen/diet safety.

Recipe nutrition includes calories, protein, carbohydrates, fibre, sugars, fat, saturated fat and sodium per serving. Distinguish verified values, ingredient-based estimates and unknowns. Ask has read-only access to relevant information for the authenticated user; it cannot edit accounts or see other users' private records.

The selected model is `gpt-5.6-luna`. The backend is the `ask-zesty` Edge Function; do not restore the removed local `AskEngine` recipe-only fallback.

Ask access is checked server-side against RevenueCat's active `lemora_pro` entitlement for the authenticated Clerk user before every request. Trial users have 10 lifetime trial messages and 6 per rolling 24 hours. Paid users have 50 per rolling 30 days, 16 per rolling 7 days and 6 per rolling 24 hours. Trial events never count against paid allowances. Limits are configured in `zesty_usage_limits` and atomically reserved in `reserve_zesty_message`; per-request analytics live in `zesty_usage_events`. The app only displays the backend allowance and does not enforce a device-local quota. The actual trial duration still comes from the App Store product; the Ask quota does not change that product.

For latency, Ask now fetches relevant profile/recipe/deal context in parallel and makes one Responses API call with optional web search instead of serial Agent tool turns. The existing conversation history is passed explicitly for follow-ups. The server function can be updated independently of an iOS build; the allowance display requires an integrated build.

The native app still has a bundled development recipe catalogue distinct from Supabase's published recipes. Ask sends the installed catalogue's ingredients, steps, local IDs, allergens and existing estimated nutrition with its context. Recipe tools search both sources and resolve local IDs without treating them as database UUIDs. Bundled fixtures are explicitly unverified; absent nutrition values stay unknown, and they provide no confirmed prices or certifications. This bridge is needed for follow-ups about a recipe shown in the app, such as `teriyaki_bowl`.

## Canadian weekly flyers

Apify's `yugenox/flipp-flyer-deals-scraper` is the ingestion source for the Canadian pilot; the iOS app does not scrape stores. A flyer edition has a stable source ID and validity dates, while exact observed postal coverage is recorded **per item** as well as per flyer. Never infer nationwide, provincial, FSA, or physical-store coverage from a single observed postal. The actor's flyer mode does not reliably provide store IDs, so `flyer_regions` and store mappings remain unverified until corroborated by a stronger source.

New Apify v2 editions stay out of the legacy province/FSA feed. The iOS app calls `active_food_deals_for_postal` for a full Canadian postal code, combining approved, healthy, imaged offers with its existing feed. The October 2 No Frills/Toronto pilot produced 50 actor rows; 13 additional priced lines were imported from that existing export after owner review, and two stored prepared-food lines were rejected. The exact-postal feed now returns four distinct approved, imaged foods at M5V 2T6: beef, broccoli, chicken breast and tomatoes. This is not nationwide coverage, a completed store map, a scheduled production import, or a TestFlight release. Put a monthly Apify spend ceiling and geographic batch plan in place before recurring nationwide scans.

Owner-reviewed food policy: prioritize whole/minimally processed produce and protein, especially extra-lean ground beef and chicken; allow olive/avocado oil, rice, plain dairy staples (including cheese, butter and cream), beans, tuna, broth and honey as cooking ingredients. Milk alternatives and yogurt are candidates, but sweetened variants require nutrition review. Sausage and sliced meat require processing/sodium review. Reject prepared soups, frozen entrées/pizza, breaded chicken bites/burgers, ice cream, regular soda, chips, sugar, coffee, stuffing and non-food. A flyer line containing different foods or brands/sizes is review-only until exact variants are resolved. Points and coupons with no current price do not become price deals. Do not claim nutritional superiority for honey or make sodium/sugar claims without verified data. The source of truth for the 50 reviewed examples is `scripts/test-flipp-food-policy.mjs`.

Expired flyer editions are removed from the live app feed, **not physically deleted**: retain flyer, item, postal-coverage and price-history rows in Supabase. Supabase Cron runs `lemora-expire-past-flyers` daily at 12:00 GMT. `lemora_expire_past_flyers()` sets `is_stale` only when `valid_until` is strictly before the current Vancouver calendar date, a conservative Canada-wide boundary. Both legacy and exact-postal views use the same boundary so UTC rollover never hides a flyer still valid in western Canada. The ingestion function calls the same expiry routine; it must not use UTC's date to stale flyers.

## Shared service identities

- GitHub source: `juraf99/rork-Lemora`, release branch `main`.
- iOS project/scheme: `ios-bitewise/Lemora.xcodeproj`, `Lemora`.
- App Store product: Lemora; bundle ID `app.rork.yuf0zn4n53irodch38mtc`; Apple team `CV768N46QD`.
- Supabase project reference: `fsucqlqsafoligouzgrl`.
- Clerk issuer currently configured in the app and both authenticated functions: `https://promoted-ferret-5695.clerk.accounts.dev`.

These are identifiers, not secrets. Server API keys remain in their configured secret stores. A switch from Clerk's current development instance to a production instance is a separate coordinated migration.
