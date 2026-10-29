// rc-webhook: receives RevenueCat webhooks and stores them in affiliate.transactions (idempotent on event.id).
//
// Auth: the shared secret is the Authorization header value configured on the RevenueCat webhook
// ("Bearer <secret>" or the raw secret). RevenueCat supports a custom authorization header.
// The ?key= query param is accepted only so an existing webhook URL keeps working during cutover.
// Remove that branch after the dashboard sends the header and a test event returns 200.
// Only the SHA-256 of the secret is stored (affiliate.settings). This file is not deployed by the app change.
//
// Deploy with verify_jwt = false. DB access uses SUPABASE_DB_URL (schema `affiliate` is not exposed to the API).
import postgres from "npm:postgres@3.4.5";

const sql = postgres(Deno.env.get("SUPABASE_DB_URL")!, { prepare: false, max: 2, idle_timeout: 20 });
const json = (b: unknown, s = 200) => new Response(JSON.stringify(b), { status: s, headers: { "Content-Type": "application/json" } });

async function sha256Hex(s: string) {
  const d = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(s));
  return Array.from(new Uint8Array(d)).map((b) => b.toString(16).padStart(2, "0")).join("");
}
function safeEqual(a: string, b: string) {
  if (a.length !== b.length) return false;
  let r = 0;
  for (let i = 0; i < a.length; i++) r |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return r === 0;
}

let cachedHash: string | null = null;
let cachedAt = 0;
async function expectedHash(): Promise<string | null> {
  if (cachedHash && Date.now() - cachedAt < 300_000) return cachedHash;
  const rows = await sql`select webhook_secret_sha256 from affiliate.settings where id`;
  cachedHash = rows[0]?.webhook_secret_sha256 ?? null;
  cachedAt = Date.now();
  return cachedHash;
}

Deno.serve(async (req) => {
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);
  const header = (req.headers.get("Authorization") ?? "").replace(/^Bearer\s+/i, "").trim();
  // Temporary. Delete this once RevenueCat's webhook uses the Authorization header only.
  const key = new URL(req.url).searchParams.get("key") ?? "";
  const expected = await expectedHash();
  if (!expected) return json({ error: "not_configured" }, 503);
  const ok = (header && safeEqual(await sha256Hex(header), expected)) || (key && safeEqual(await sha256Hex(key), expected));
  if (!ok) return json({ error: "unauthorized" }, 401);

  let body: unknown;
  try { body = await req.json(); } catch { return json({ error: "bad_json" }, 400); }
  try {
    const rows = await sql`select affiliate.ingest_rc_event(${sql.json(body as never)}::jsonb) as result`;
    return json({ ok: true, result: rows[0].result });
  } catch (e) {
    console.error("ingest_failed", (e as Error).message);
    return json({ error: "ingest_failed" }, 500); // RevenueCat retries
  }
});
