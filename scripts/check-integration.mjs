import { readFileSync, existsSync } from "node:fs";
import { resolve } from "node:path";

// Release guard: both agents' feature paths must survive a shared-file update.
const root = resolve(import.meta.dirname, "..");
const app = "ios-bitewise/Lemora/";
const failures = [];
const read = (path) => {
  const full = resolve(root, path);
  if (!existsSync(full)) {
    failures.push(`Missing shared feature source: ${path}`);
    return "";
  }
  return readFileSync(full, "utf8");
};
const requireText = (source, text, description) => {
  if (!source.includes(text)) failures.push(description);
};

const entry = read(app + "ContentView.swift");
requireText(entry, "LemoraOnboardingView(", "The active app entry point must preserve Claude's v2 onboarding.");
read(app + "Views/Onboarding/ZestyMascot.swift");
const onboarding = read(app + "Views/Onboarding/OnboardingSync.swift");
const zesty = read(app + "Services/ZestyService.swift");
for (const [name, source] of [["Onboarding", onboarding], ["Ask", zesty]]) {
  requireText(source, "Clerk.shared.auth.getToken()", `${name} must use the current Clerk session.`);
}
requireText(onboarding, "fsucqlqsafoligouzgrl.supabase.co", "Onboarding must target the shared Lemora backend.");
requireText(zesty, '"ask-zesty"', "Ask must call the deployed Zesty service.");
if (zesty.includes("KeychainHelper")) failures.push("Ask still uses the obsolete authentication token.");
const state = read(app + "ViewModels/AppStore.swift");
requireText(state, "zesty.ask(", "AppStore must preserve the server-backed Ask path.");
if (state.includes("AskEngine(")) failures.push("The local recipe-only Ask fallback was restored.");
requireText(read(app + "Services/SupabaseService.swift"), '"active_food_deals_unique"', "Weekly deals must keep the live, unique Supabase feed.");
requireText(read(app + "Views/Onboarding/OnboardingSteps.swift"), "Hi, I’m Zesty!", "The mascot's product name must remain Zesty.");

if (failures.length) {
  console.error(failures.join("\n"));
  process.exit(1);
}
console.log("Shared release verified: Claude onboarding + Clerk + Zesty Ask + live weekly deals.");
