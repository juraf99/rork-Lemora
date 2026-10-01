# Lemora — parallel work and releases

## Shared source

GitHub `juraf99/rork-Lemora` is the shared application source. Before starting work, fetch the current main branch, then create or update a feature branch. Claude's branches focus on onboarding/design; Codex's branches focus on deals/recipes/Ask.

Commit changes and normally integrate them through a pull request. An explicitly authorized integration may also publish a tested commit to main by a normal fast-forward push after fetching the current remote. Do not replace a shared file with a stale downloaded copy. In shared files such as `AppStore.swift`, `AuthManager.swift`, the Xcode project and backend configuration, merge the actual changes from both sides. Record newly agreed product behaviour in `PRODUCT_CONTEXT.md`.

Claude's existing download/upload workflow uses one-shot YAML scripts that edit main and start a TestFlight build. For future changes, apply those edits to a branch based on current main and review the resulting diff. Do not upload an old whole-app ZIP or run an old patch against main without checking its anchors and effect on Ask and shared services.

## One TestFlight publisher

The main-branch GitHub Actions workflow `.github/workflows/testflight_1.yml` is the shared TestFlight publisher. Merge the latest features, compile the combined project, then release that integrated main commit. A manually dispatched release must also run from main. Avoid independent uploads from feature branches or older local archives.

The workflow publishes the latest main commit, cancels superseded runs, checks that onboarding/Clerk/Ask/live deals are all present and records the build number/source commit in its run summary. It checks main again before uploading to prevent an outdated archive from replacing a newer integration. Confirm the exact build number in App Store Connect/TestFlight before saying a release is available to testers. Upload success, Apple processing and tester availability are separate states.

## Clerk and Supabase

Preserve one Clerk identity across authentication, onboarding, subscriptions and Ask. Both private Edge Functions verify Clerk tokens and derive the user ID from the token; client-supplied user IDs do not grant access.

Use Supabase project `fsucqlqsafoligouzgrl`. Version Edge Function source alongside the app and document deployments. Schema changes require a migration reviewed against the existing remote history. Several historical SQL files in this repository have timestamps different from their already-applied remote migrations: do not run an unreviewed `supabase db push` or reapply the entire directory. Reconcile history before introducing automated database deployment. Never reset the shared database to synchronize code.

The deployed onboarding function and Ask function are independent of an iOS upload. Check their contracts and authenticated paths when integrating client changes; verify active deal dates and supported stores from the database.

## Integration checks

1. Fetch current main and preserve the latest onboarding/design and Ask/deals commits.
2. Compile the integrated iOS app; check that Clerk sessions are used by onboarding and Ask.
3. Confirm Supabase project, function versions and required tables/views without changing user data.
4. Publish the tested integration to main and let the shared publisher build it.
5. Record the commit, workflow result and exact TestFlight build. Test one account through onboarding and an Ask follow-up on the installed integrated build.

Run `node scripts/check-integration.mjs` to check the shared release paths. Run `node scripts/test-zesty-tools.mjs` with Node 24+ for the network-free recipe-tool regression checks; these do not call OpenAI or require an API key.
