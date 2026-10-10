// Privileged, narrowly scoped ingestion endpoint for the local Lemora catalogue.
// The bearer token itself lives only in the ignored local .env file; this source
// contains its SHA-256 digest so the secret is never committed or deployed.
import { createClient } from "npm:@supabase/supabase-js@2.45.4";

const EXPECTED_TOKEN_SHA256 = "9ccec9835da48900fa6d8fbf43e28c7e0e20c90295585c63745e28ccfee0bd3e";
const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { "Content-Type": "application/json" } });

async function sha256(value: string) {
  const bytes = new TextEncoder().encode(value);
  return Array.from(new Uint8Array(await crypto.subtle.digest("SHA-256", bytes)))
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
}

function safeEqual(left: string, right: string) {
  if (left.length !== right.length) return false;
  let difference = 0;
  for (let index = 0; index < left.length; index += 1) {
    difference |= left.charCodeAt(index) ^ right.charCodeAt(index);
  }
  return difference === 0;
}

function decodeBase64(value: string) {
  const binary = atob(value);
  const bytes = new Uint8Array(binary.length);
  for (let index = 0; index < binary.length; index += 1) bytes[index] = binary.charCodeAt(index);
  return bytes;
}

Deno.serve(async (request) => {
  if (request.method !== "POST") return json({ error: "method_not_allowed" }, 405);

  const token = (request.headers.get("Authorization") ?? "").replace(/^Bearer\s+/i, "");
  if (!token || !safeEqual(await sha256(token), EXPECTED_TOKEN_SHA256)) {
    return json({ error: "unauthorized" }, 401);
  }

  let body: Record<string, unknown>;
  try {
    body = await request.json();
  } catch {
    return json({ error: "bad_json" }, 400);
  }

  const payload = body.payload as Record<string, unknown> | undefined;
  const parent = payload?.parent as Record<string, unknown> | undefined;
  const stableId = parent?.catalogue_id;
  const imageBase64 = body.image_base64;
  const expectedObjectPath = typeof stableId === "string" ? `catalogue/${stableId}.webp` : "";
  const media = payload?.media as Record<string, unknown> | undefined;

  if (
    typeof stableId !== "string" || !/^[a-z0-9][a-z0-9-]{5,159}$/.test(stableId) ||
    typeof imageBase64 !== "string" || imageBase64.length > 8_000_000 ||
    media?.storage_bucket !== "recipe-photos" || media?.storage_object_path !== expectedObjectPath
  ) {
    return json({ error: "invalid_catalogue_payload" }, 400);
  }

  const db = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, {
    auth: { persistSession: false },
  });
  const { data: existing, error: existingError } = await db
    .from("recipes")
    .select("id")
    .eq("catalogue_id", stableId)
    .maybeSingle();
  if (existingError) return json({ error: "catalogue_lookup_failed" }, 500);
  if (existing) return json({ status: "skipped", image_uploaded: false });

  const filename = `${stableId}.webp`;
  const { data: stored, error: listError } = await db.storage
    .from("recipe-photos")
    .list("catalogue", { limit: 2, search: filename });
  if (listError) return json({ error: "image_lookup_failed" }, 500);
  const imageExists = (stored ?? []).some((item) => item.name === filename);

  if (!imageExists) {
    let image: Uint8Array;
    try {
      image = decodeBase64(imageBase64);
    } catch {
      return json({ error: "invalid_image" }, 400);
    }
    const { error: uploadError } = await db.storage
      .from("recipe-photos")
      .upload(expectedObjectPath, image, { contentType: "image/webp", upsert: false });
    if (uploadError) return json({ error: "image_upload_failed", detail: uploadError.message }, 500);
  }

  const { data: syncStatus, error: syncError } = await db.rpc("sync_lemora_catalog_recipe", { payload });
  if (syncError) return json({ error: "recipe_sync_failed", detail: syncError.message }, 500);
  if (syncStatus !== "inserted" && syncStatus !== "skipped") {
    return json({ error: "unexpected_sync_status" }, 500);
  }
  return json({ status: syncStatus, image_uploaded: !imageExists });
});
