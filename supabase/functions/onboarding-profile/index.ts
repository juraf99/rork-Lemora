// Saves / reads Lemora onboarding answers for the signed-in Clerk user.
// Auth: the Clerk session token (Authorization: Bearer ...) is verified against Clerk's JWKS.
import { createRemoteJWKSet, jwtVerify } from "npm:jose@5.9.6";
import { createClient } from "npm:@supabase/supabase-js@2.45.4";

const ISSUER = "https://promoted-ferret-5695.clerk.accounts.dev";
const JWKS = createRemoteJWKSet(new URL(`${ISSUER}/.well-known/jwks.json`));
const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, apikey, content-type",
  "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
};
const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { ...cors, "Content-Type": "application/json" } });

const str = (v: unknown, max = 200) => (typeof v === "string" && v.length <= max ? v : null);
const int = (v: unknown) => (typeof v === "number" && Number.isFinite(v) ? Math.round(v) : null);
const strs = (v: unknown) => (Array.isArray(v) ? v.filter((x) => typeof x === "string" && x.length <= 120).slice(0, 100) : []);

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  const token = (req.headers.get("Authorization") ?? "").replace(/^Bearer\s+/i, "");
  let userId: string;
  try {
    const { payload } = await jwtVerify(token, JWKS, { issuer: ISSUER });
    if (typeof payload.sub !== "string" || !payload.sub) throw new Error("no sub");
    userId = payload.sub;
  } catch {
    return json({ error: "unauthorized" }, 401);
  }

  const db = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, {
    auth: { persistSession: false },
  });

  if (req.method === "GET") {
    const { data, error } = await db.from("onboarding_profiles").select("answers, onboarding_completed, updated_at").eq("clerk_user_id", userId).maybeSingle();
    if (error) return json({ error: "read_failed" }, 500);
    return json({ profile: data ?? null });
  }

  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);

  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch {
    return json({ error: "bad_json" }, 400);
  }
  const a = (body.answers ?? {}) as Record<string, unknown>;
  const completed = a.completed === true;
  const row: Record<string, unknown> = {
    clerk_user_id: userId,
    email: str(body.email, 320),
    display_name: str(body.display_name),
    auth_state: str(body.auth_state, 40),
    referral_source: str(a.referral, 60),
    user_goal: str(a.goal, 60),
    current_weight_lb: int(a.current),
    target_weight_lb: int(a.target),
    weight_unit: str(a.unit, 5),
    cuisines: strs(a.cuisines),
    household_size: int(a.household),
    diet_preferences: strs(a.diets),
    no_allergies: a.noAllergy === true,
    allergies: strs(a.allergies),
    disliked_ingredients: Array.isArray(a.dislikes) ? a.dislikes.slice(0, 100) : [],
    location_mode: str(a.locMode, 20),
    country_code: str(a.country, 4),
    postal_code: str(a.postal, 12),
    region_key: str(body.region_key, 20),
    region_name: str(body.region_name, 80),
    preferred_stores: strs(a.stores),
    weekly_budget: a.noBudget === true ? null : int(a.budget),
    no_strict_budget: a.noBudget === true,
    currency_code: str(body.currency_code, 5),
    shopping_strategy: str(a.strategy, 20),
    notification_preference: str(a.notif, 30),
    selected_plan: str(a.plan, 20),
    savings_estimate: typeof body.savings_estimate === "object" ? body.savings_estimate : null,
    onboarding_progress: str(body.onboarding_progress, 40),
    onboarding_completed: completed,
    answers: a,
    updated_at: new Date().toISOString(),
  };
  if (completed) row.onboarding_completed_at = new Date().toISOString();
  const { error } = await db.from("onboarding_profiles").upsert(row, { onConflict: "clerk_user_id" });
  if (error) return json({ error: "write_failed" }, 500);
  return json({ ok: true });
});
