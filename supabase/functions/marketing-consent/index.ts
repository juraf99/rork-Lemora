// Records a marketing opt-in or opt-out in Resend for the signed-in Clerk user.
// The app sends the address only after the person uses the profile toggle.
// Auth: Clerk session token. The Resend key is RESEND_API_KEY. Optional RESEND_SEGMENT_ID adds or removes the contact.
import { createRemoteJWKSet, jwtVerify } from "npm:jose@5.9.6";

const ISSUER = "https://clerk.lemoraapp.com";
const JWKS = createRemoteJWKSet(new URL(`${ISSUER}/.well-known/jwks.json`));
const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { ...cors, "Content-Type": "application/json" } });

const emailOk = (value: string) => value.length <= 320 && /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(value);

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);

  const token = (req.headers.get("Authorization") ?? "").replace(/^Bearer\s+/i, "");
  try {
    const { payload } = await jwtVerify(token, JWKS, { issuer: ISSUER });
    if (typeof payload.sub !== "string" || !payload.sub) throw new Error("no sub");
  } catch {
    return json({ error: "unauthorized" }, 401);
  }

  const apiKey = Deno.env.get("RESEND_API_KEY");
  if (!apiKey) return json({ error: "not_configured" }, 503);

  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch {
    return json({ error: "bad_json" }, 400);
  }
  const email = typeof body.email === "string" ? body.email.trim().toLowerCase() : "";
  if (!emailOk(email)) return json({ error: "bad_email" }, 400);
  const consent = body.consent === true || body.consent === "true";
  const firstName = typeof body.first_name === "string" ? body.first_name.trim().slice(0, 80) : "";

  const payload: Record<string, unknown> = { email, unsubscribed: !consent };
  if (firstName) payload.first_name = firstName;

  const created = await resend(apiKey, "POST", "/contacts", payload);
  let contactId = idOf(created.body);
  if (!created.ok) {
    const updated = await resend(apiKey, "PATCH", `/contacts/${encodeURIComponent(email)}`, {
      unsubscribed: !consent,
      ...(firstName ? { first_name: firstName } : {}),
    });
    if (!updated.ok) return json({ error: "resend_failed" }, 502);
    contactId = idOf(updated.body) ?? contactId;
  }

  const segment = Deno.env.get("RESEND_SEGMENT_ID");
  if (segment && !contactId) {
    const looked = await resend(apiKey, "GET", `/contacts/${encodeURIComponent(email)}`);
    contactId = idOf(looked.body);
  }
  if (segment && contactId) {
    if (consent) await resend(apiKey, "POST", `/contacts/${contactId}/segments`, { segment_id: segment });
    else await resend(apiKey, "DELETE", `/contacts/${contactId}/segments/${segment}`);
  }

  return json({ ok: true, consent });
});

function idOf(body: unknown): string | null {
  if (!body || typeof body !== "object") return null;
  const id = (body as { id?: unknown }).id;
  return typeof id === "string" && id ? id : null;
}

async function resend(apiKey: string, method: string, path: string, body?: unknown) {
  const res = await fetch(`https://api.resend.com${path}`, {
    method,
    headers: { Authorization: `Bearer ${apiKey}`, "Content-Type": "application/json" },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  const text = await res.text();
  let parsed: unknown = null;
  if (text) {
    try { parsed = JSON.parse(text); } catch { parsed = null; }
  }
  if (!res.ok) console.error("resend_status", res.status);
  return { ok: res.ok, body: parsed };
}
