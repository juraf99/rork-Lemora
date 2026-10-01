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
