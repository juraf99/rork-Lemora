# Lemora — shared product context

This document records decisions available in the user's instructions and the shared code. Update it when a decision changes; a private conversation with either assistant is not automatically available to the other.

## Product and ownership

The application is **Lemora**. Its lemon mascot is **Zesty**, also the persona answering in Ask. Some older Swift types and artwork filenames still contain `Zest`; these are compatibility identifiers, not the mascot's product name.

Claude primarily develops onboarding and visual design. Codex primarily develops Steals of the Week, recipe content and Ask. Changes to shared state, authentication or backend contracts must preserve both features.

## Current onboarding and account model

The active entry point is `LemoraOnboardingView`, selected by `ContentView`. Preserve Claude's v2 flow, artwork, animations, back navigation and resumption behaviour. Its questions cover discovery source, goal, conditional body goals, household, diet, allergies, dislikes, meal types, location, stores, budget and shopping strategy.

Meal preferences include breakfast, lunch, dinner, snacks and desserts; an empty selection means all meal types. Saved onboarding answers are mapped into `UserProfile` and stored through `onboarding-profile`. An unfinished flow reopens at the landing page; an answered flow reopens at the plan. Completed users with a lapsed subscription return to the plan/paywall flow.

Profile preference editors now reuse Claude's onboarding screens, including their cards, emoji and Zesty speech bubbles. Each editor writes back only the field it edits when the user leaves the screen. Preserve this design and its current preference values.

Authentication uses Clerk, including Apple, Google and email verification. Onboarding and Ask must both obtain the current Clerk session with `Clerk.shared.auth.getToken()`. RevenueCat ties purchases to the Clerk user ID. The entitlement is `lemora_pro`. The paywall buys the current offering's `$rc_annual` and `$rc_monthly` packages, so Offerings and Experiments choose the products. Prices and the free trial come from the StoreKit product. The yearly plan is $29.99 USD with a 3-day free trial. Monthly is $9.99 with no trial. Until StoreKit loads, the paywall shows a placeholder instead of a price.

Product analytics go to PostHog (US cloud, project 684936). People are identified with the Clerk user id after RevenueCat `logIn`. Signing out resets that person and signs out of Clerk and RevenueCat. GeoIP lookup is off. Each onboarding screen sends `onboarding_screen_viewed`. The App Store privacy label should list Usage Data and User ID as linked to the user, and Tracking as no.

Price tests use the current RevenueCat offering only (`$rc_annual` and `$rc_monthly`). Superwall is not part of Lemora. Both paywalls show the StoreKit price that will be charged, in one column, with the trial terms, Terms, Privacy and Restore.

Profile can request an Apple refund, and shows a retention offer before cancellation: an eligible RevenueCat promotional offer when Apple has one, otherwise the yearly price for a monthly subscriber. Marketing email is off until the person opts in. That choice is stored in Resend by `marketing-consent`.

A new person pays before creating an account: the plan leads to the paywall, the App Store payment, then Sign in with Apple. The purchase stays on the device until Apple sign-in attaches it to the Clerk user. Someone who already paid and reopens the app goes to Sign in with Apple instead of being charged again.

Onboarding asks allergies and disliked foods on one screen, and the weekly budget with the shopping strategy on the next. The first screen shows a real flyer deal turned into a recipe, with the flyer’s real end date. Skip cannot pass a question that still needs an answer. Both notification buttons open Apple’s permission sheet. The onboarding savings page uses the original household and budget estimate, with the week, month and year chart. A recipe’s price per serving buys the smallest whole package that covers the ingredient, so a bulk pack is not treated as if you could buy a fraction of it.

Deals keeps a search field on screen, with an under-30-minute filter and a minimum savings percent. Recipes tied to this week's deals sit under a smaller Premium row. Ask is the Demander button on that same bar. Deal and recipe cards use the smaller format.

Trial availability and displayed billing terms depend on the actual StoreKit product and the Apple account's eligibility. Preserve the trial/no-trial variants. Claude's downloaded `apply-timeline.yml` corrects the paywall connectors by sizing each timeline row to its content; that source change is included directly in this integration.

## Ask

Zesty answers in writing with a concise, friendly, lightly playful tone, in the user's language. Intent determines the response: app/profile help gets a direct answer; a nutrition follow-up stays on the previously discussed recipe. Recommendation cards support the written answer.

For meal ideas, try to reference two suitable app recipes when available. Give requested portions, scaled quantities and steps directly in text. When catalogue recipes are insufficient, Zesty can create a personalized suggestion and use external research when useful, combined with verified app deals and the user's profile. Never fabricate prices or confirmed allergen/diet safety.

Recipe nutrition includes calories, protein, carbohydrates, fibre, sugars, fat, saturated fat and sodium per serving. Distinguish verified values, ingredient-based estimates and unknowns. Ask has read-only access to relevant information for the authenticated user; it cannot edit accounts or see other users' private records.

The selected model is `gpt-5.6-luna`. The backend is the `ask-zesty` Edge Function; do not restore the removed local `AskEngine` recipe-only fallback.

Ask access is checked server-side against RevenueCat's active `lemora_pro` entitlement for the authenticated Clerk user before every request. Trial users have 10 lifetime trial messages and 6 per rolling 24 hours. Paid users have 50 per rolling 30 days, 16 per rolling 7 days and 6 per rolling 24 hours. Trial events never count against paid allowances. Limits are configured in `zesty_usage_limits` and atomically reserved in `reserve_zesty_message`; per-request analytics live in `zesty_usage_events`. The app only displays the backend allowance and does not enforce a device-local quota. The actual trial duration still comes from the App Store product; the Ask quota does not change that product.

For latency, Ask now fetches relevant profile/recipe/deal context in parallel and makes one Responses API call with optional web search instead of serial Agent tool turns. The existing conversation history is passed explicitly for follow-ups. The server function can be updated independently of an iOS build; the allowance display requires an integrated build.

The native app loads the permanent recipe catalogue from Supabase at startup and keeps the bundled development fixtures only as an offline fallback. Ask sends the active catalogue's ingredients, steps, stable catalogue IDs, allergens and available nutrition with its context. Recipe tools resolve catalogue IDs without treating them as database UUIDs. Missing nutrition and prices stay unknown, and the app makes no unverified certification claims.

## Shared service identities

The permanent local recipe catalogue is synchronized to Supabase through
`scripts/sync-recipe-catalog.mjs`. Catalogue rows keep their stable `lemora-*`
identifier in `recipes.catalogue_id`, store the complete source payload, and
use deterministic UUIDs for existing app relations. Local compatibility
`yes`/`no` maps to database `true`/`false`; uncertainty remains excluded by
the catalogue's “doubt means no” policy. Recipe images live in the public
`recipe-photos` bucket under `catalogue/<catalogue_id>.webp`. The synchronizer
only inserts missing catalogue IDs and never changes existing recipes. Local
scheduled runs read `SUPABASE_SERVICE_ROLE_KEY` from the ignored project `.env`
file when the variable is not already provided by the environment.

- GitHub source: `juraf99/rork-Lemora`, release branch `main`.
- iOS project/scheme: `ios-bitewise/Lemora.xcodeproj`, `Lemora`.
- App Store product: Lemora; bundle ID `app.rork.yuf0zn4n53irodch38mtc`; Apple team `CV768N46QD`.
- Supabase project reference: `fsucqlqsafoligouzgrl`.
- Clerk issuer currently configured in the app and both authenticated functions: `https://promoted-ferret-5695.clerk.accounts.dev`.

These are identifiers, not secrets. Server API keys remain in their configured secret stores. A switch from Clerk's current development instance to a production instance is a separate coordinated migration.

## Pantry and page titles

Saved and Ask use the lowercase `lemora` wordmark as their page title, the same Figtree ExtraBold as Aubaines and Discover. The Saved screen still switches between Enregistrés and Plan de la semaine.

The grocery list has a small Pantry button at the top. Profile’s Shopping section opens the same screen. Checking an item, or adding one by name, stores it at home: that ingredient leaves the grocery list and is skipped the next time a recipe or deal would add it. Unchecking puts it back on the list if it was already there. The list is stored on the device in `AppData.pantry` and is not synced to Supabase.
