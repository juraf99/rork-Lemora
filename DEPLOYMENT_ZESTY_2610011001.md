# Zesty Ask deployment — build 2610011001

Historical isolated build, created before integrating Claude's latest onboarding. Current releases must use the shared GitHub main workflow described in `COLLABORATION.md`.

- App Store Connect app: Eat Smarter - Lemora
- Bundle identifier: `app.rork.yuf0zn4n53irodch38mtc`
- Apple team: `CV768N46QD`
- iOS version/build: `1.0.0 (2610011001)`
- Supabase Edge Function: `ask-zesty`
- Agent configuration: `2026-10-01.3`
- Model: `gpt-5.6-luna`
- Archive: `/private/tmp/Lemora-Zesty-2610011001.xcarchive` (`ARCHIVE SUCCEEDED`)
- App Store Connect upload: succeeded October 1, 2026 at 2:22 AM local time
- Internal Testing group: `Testing` for build `1.0.0 (2610011001)`
- Tester device observed before update: iPhone 15 Pro Max running build `2610010604`

## Verification target

The Ask screen must display `Zesty AI · build 2610011001`. Responses must come from `ZestyService` through the authenticated Supabase Edge Function, preserve the conversation id for follow-up questions, and render written nutrition per serving when provided. The removed local `AskEngine` must not be present in the built product.

The signed archive was inspected: `CFBundleIdentifier=app.rork.yuf0zn4n53irodch38mtc`, `CFBundleVersion=2610011001`, `TeamIdentifier=CV768N46QD`; its binary contains `Zesty AI` and `Nutrition per serving`. Supabase `ask-zesty` was ACTIVE at version 5. In the two hours before this upload, Supabase Edge Function logs showed no iPhone requests to `ask-zesty`; only a manual `curl` request appeared. This supports the report that the installed build's Ask screen was still using a local path.
