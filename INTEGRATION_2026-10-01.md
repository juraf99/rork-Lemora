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

The shared GitHub workflow records the final source commit/build number, rejects obsolete uploads and retains both agents' features. Its upload result and TestFlight processing state must be verified before reporting tester availability. The older `2610011001` archive is historical, not the synchronized release.
