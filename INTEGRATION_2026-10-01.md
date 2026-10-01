# Lemora integration — 1 October 2026

The initial Codex release checkout was 29 commits behind Claude's main branch. Integration starts from Claude's latest code and preserves his onboarding, authentication, RevenueCat, paywall, meal-type question, resumption rules and profile editors. The shared product name for the mascot is Zesty.

Codex's server-backed Ask and live weekly-deal feed are integrated into that application. Ask now uses Clerk's current token and receives the actual bundled app recipes for follow-ups; those recipes were absent from Supabase's published catalogue. Their existing nutrition remains explicitly estimated, with missing fields unknown.

## Verification

- Integrated iOS Debug build for generic iOS: succeeded. Existing subscription-price actor-isolation warnings remain in Claude's code.
- Recipe-tool regression checks: passed for the actual Teriyaki fixture, 4-to-8 portion scaling, written steps, local recipe IDs, allergen/diet exclusions, unknown nutrition and one-to-one server nutrition relations.
- Shared integration guard, workflow YAML and certificate-helper Python syntax: passed.
- Supabase project: `fsucqlqsafoligouzgrl`; `ask-zesty` ACTIVE version 7; `onboarding-profile` ACTIVE version 2; `flipp-flyer-ingest` ACTIVE version 8.
- Onboarding source and flyer-ingestion source copied/compared with the deployed versions. Ask version 7 matches the integration source.
- Both private functions return HTTP 401 without a Clerk session. No database reset, blanket migration push or user-record overwrite was performed.
- No authenticated OpenAI conversation was run during these checks; installed-device answers still require a signed-in end-to-end test.

## Integrated release

- Source commit: `d4c167065829b8a92e5b8dbdafcfd786a585b64c`, shared `main`.
- GitHub Actions run: https://github.com/juraf99/rork-Lemora/actions/runs/36907164181 — succeeded, including archive and upload.
- Version/build: `1.0.0 (2610011829)`; App Store Connect received it on 1 October at 14:34 EDT. Processing completed; the build is assigned to `Internal Testing` (one tester). Verified on the build detail page: https://appstoreconnect.apple.com/teams/5472140c-2be4-4235-be97-fef27e947263/apps/6817623465/testflight/ios/88bbcfee-d12b-4c97-b427-8718c40117a1.
- The local `lemora` checkout now follows the same shared `main`.

The shared workflow records the source commit/build number, rejects obsolete uploads and retains both agents' features. The older `2610011001` archive is historical, not the synchronized release.

## Remaining verification

Flyer ingestion last succeeded at `2026-10-01 04:39 UTC` (623 items seen, 567 written). The ingestion function is deployed, but no scheduled GitHub ingestion workflow, local Codex automation, or installed Supabase `pg_cron`/`pg_net` extension was found. An external scheduler may exist; automatic refresh is not yet confirmed. Do not represent an active function as proof of scheduled execution, or copy server secrets into the application to enable it.

An installed-device, signed-in Ask conversation still needs an end-to-end check. Recipe-tool tests and a successful upload do not establish the OpenAI account's current billing availability or conversational model behaviour.
