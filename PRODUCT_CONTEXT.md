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

The native app still has a bundled development recipe catalogue distinct from Supabase's published recipes. Ask sends the installed catalogue's ingredients, steps, local IDs, allergens and existing estimated nutrition with its context. Recipe tools search both sources and resolve local IDs without treating them as database UUIDs. Bundled fixtures are explicitly unverified; absent nutrition values stay unknown, and they provide no confirmed prices or certifications. This bridge is needed for follow-ups about a recipe shown in the app, such as `teriyaki_bowl`.

## Shared service identities

- GitHub source: `juraf99/rork-Lemora`, release branch `main`.
- iOS project/scheme: `ios-bitewise/Lemora.xcodeproj`, `Lemora`.
- App Store product: Lemora; bundle ID `app.rork.yuf0zn4n53irodch38mtc`; Apple team `CV768N46QD`.
- Supabase project reference: `fsucqlqsafoligouzgrl`.
- Clerk issuer currently configured in the app and both authenticated functions: `https://promoted-ferret-5695.clerk.accounts.dev`.

These are identifiers, not secrets. Server API keys remain in their configured secret stores. A switch from Clerk's current development instance to a production instance is a separate coordinated migration.
