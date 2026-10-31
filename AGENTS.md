# Lemora — collaboration

Read `PRODUCT_CONTEXT.md` and `COLLABORATION.md` before changing this application. They record the shared product decisions and release workflow for Claude and Codex.

- The mascot and Ask persona are named **Zesty**.
- Claude primarily owns onboarding, visual design, navigation and the subscription experience.
- Codex primarily owns weekly steals/deals, recipe content and the Ask service.
- Preserve the latest work of the other agent. Integrate from current `origin/main`; resolve shared-file changes deliberately.
- Use the existing Clerk instance, Supabase project and Lemora App Store identity described in `PRODUCT_CONTEXT.md`.
- Publish TestFlight builds only through the shared main-branch workflow after integration and compilation. Read `COLLABORATION.md` before releasing.
- Recipe catalogue instructions inherited from the enclosing workspace remain applicable. Adding local catalogue content does not authorize publishing it into Supabase.

If a product decision from another conversation is unavailable, identify the missing decision explicitly; do not claim access to that conversation.

## Cursor Cloud specific instructions

The iOS app is `ios-bitewise/Lemora.xcodeproj`, scheme `Lemora`. Building and launching it requires macOS with Xcode. Cloud Agent machines are Linux, so `xcodebuild` and the iOS Simulator are not available. TestFlight still publishes from `.github/workflows/testflight_1.yml` on macOS.

On a Cloud Agent, check the shared app logic with these commands from the repository root:

- `node scripts/check-integration.mjs` confirms onboarding, Clerk session use, Ask, and weekly deals are present.
- `node scripts/test-zesty-tools.mjs` needs Node 24 or newer. It runs the Ask recipe tools against the bundled Teriyaki fixture. It does not use the network, OpenAI, or an API key. Node still prints an experimental warning for `stripTypeScriptTypes`; the check passes when the process exits 0.

The environment install puts Node 24.22.1 at `~/.local/bin/node` and `/usr/local/bin/node`. A login shell resolves `node` to that Node 24 binary, ahead of the image Node 22. There is no Linux dev server to start: the app UI runs only in the iOS Simulator.

Do not run `supabase db push`, reset the database, or publish the recipe catalogue from a Cloud Agent. Those are release actions described in `COLLABORATION.md`.
