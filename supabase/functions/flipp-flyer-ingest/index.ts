import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

const ACTOR = "yugenox~flipp-flyer-deals-scraper";
const APIFY_API = `https://api.apify.com/v2/acts/${ACTOR}`;
const DEFAULT_MERCHANTS = [
  "Maxi", "Provigo", "No Frills", "Real Canadian Superstore", "Loblaws",
  "Zehrs", "Fortinos", "Atlantic Superstore", "Dominion", "Independent",
  "IGA", "Sobeys", "Safeway", "FreshCo", "Foodland", "Farm Boy",
  "Longo's", "Thrifty Foods", "Marchés Tradition", "Bonichoix",
  "Metro", "Super C", "Food Basics", "Adonis", "Marché Richelieu",
  "Walmart", "Costco", "Save-On-Foods", "Buy-Low Foods",
  "PriceSmart Foods", "Co-op",
];
type Input = {
  postalCodes?: string[];
  regionPresets?: Array<"ca-major-cities" | "us-major-cities">;
  merchants?: string[];
  searchTerms?: string[];
  maxItems?: number;
  maxPostalCodes?: number;
  maxItemsPerPostalCode?: number;
  language?: "en" | "fr";
  onlyValidNow?: boolean;
  healthFocus?: boolean;
  dryRun?: boolean;
};

type FlippDeal = {
  itemId: string;
  itemType?: string;
  name: string;
  brand?: string | null;
  merchant: string;
  merchantId: number;
  flyerId?: number | null;
  flyerName?: string | null;
  currentPrice?: number | null;
  originalPrice?: number | null;
  effectivePrice?: number | null;
  currency?: string;
  priceText?: string | null;
  postPriceText?: string | null;
  prePriceText?: string | null;
  priceUnit?: string | null;
  size?: string | null;
  packageSize?: string | null;
  description?: string | null;
  multiBuy?: { quantity?: number; totalPrice?: number; pricePerItem?: number } | null;
  discountPct?: number | null;
  validFrom: string;
  validTo: string;
  imageUrl?: string | null;
  productUrl?: string | null;
  postalCode: string;
  locale?: string;
  flyerCategories?: string[];
  saleStory?: string | null;
  [key: string]: unknown;
};

function productSize(deal: FlippDeal): string | null {
  const direct = [deal.size, deal.packageSize].find((value) => typeof value === "string" && value.trim());
  if (direct) return direct.trim();
  const text = [deal.name, deal.description, deal.prePriceText, deal.postPriceText]
    .filter((value): value is string => typeof value === "string").join(" ");
  const match = text.match(/\b(?:\d+\s*[x×]\s*)?\d+(?:[.,]\d+)?\s*(?:kg|g|mg|l|ml|lb|lbs|oz|fl\.?\s*oz|un(?:it(?:é|e|s)?)?\.?|ct)\b/i);
  return match?.[0]?.replace(/\s+/g, " ").trim() ?? null;
}

function semanticDealKey(deal: FlippDeal): string {
  return [
    slug(deal.merchant),
    slug(deal.name),
    slug(deal.brand ?? ""),
    deal.currentPrice?.toFixed(2) ?? "",
    slug(deal.priceUnit ?? ""),
    slug(productSize(deal) ?? ""),
    String(deal.multiBuy?.quantity ?? ""),
    slug(deal.saleStory ?? ""),
    deal.validFrom,
    deal.validTo,
  ].join("|");
}

function slug(value: string): string {
  return value.normalize("NFKD").replace(/[\u0300-\u036f]/g, "")
    .toLowerCase().replace(/[^a-z0-9]+/g, "_").replace(/^_+|_+$/g, "");
}

function timeZoneFor(region: string): string {
  const zones: Record<string, string> = {
    BC: "America/Vancouver", AB: "America/Edmonton", SK: "America/Regina",
    MB: "America/Winnipeg", ON: "America/Toronto", QC: "America/Toronto",
    NB: "America/Moncton", NS: "America/Halifax", PE: "America/Halifax",
    NL: "America/St_Johns", YT: "America/Whitehorse", NT: "America/Yellowknife",
    NU: "America/Iqaluit",
    AK: "America/Anchorage", HI: "Pacific/Honolulu", CA: "America/Los_Angeles",
    WA: "America/Los_Angeles", OR: "America/Los_Angeles", NV: "America/Los_Angeles",
    AZ: "America/Phoenix", CO: "America/Denver", UT: "America/Denver", TX: "America/Chicago",
    IL: "America/Chicago", FL: "America/New_York", NY: "America/New_York", MA: "America/New_York",
  };
  return zones[region] ?? "America/New_York";
}

function localDate(value: string, region: string, exclusiveEnd = false): string {
  // The actor normally supplies a retailer-local UTC offset. Preserve that
  // date rather than forcing a single time zone on all Nunavut stores.
  const localWithOffset = value.match(/^(\d{4}-\d{2}-\d{2})T(\d{2}:\d{2}:\d{2})[+-]\d{2}:\d{2}$/);
  if (localWithOffset && !/[+-]00:00$/.test(value)) {
    if (exclusiveEnd && localWithOffset[2] === "00:00:00") {
      return new Date(new Date(`${localWithOffset[1]}T00:00:00Z`).getTime() - 1_000).toISOString().slice(0, 10);
    }
    return localWithOffset[1];
  }
  const instant = new Date(new Date(value).getTime() - (exclusiveEnd ? 1_000 : 0));
  return new Intl.DateTimeFormat("en-CA", {
    timeZone: timeZoneFor(region), year: "numeric", month: "2-digit", day: "2-digit",
  }).format(instant);
}

function countryFor(postalCode: string): "CA" | "US" {
  return /^\d/.test(postalCode.replace(/\s/g, "")) ? "US" : "CA";
}

function regionFor(postalCode: string): string {
  const code = postalCode.replace(/\s/g, "").toUpperCase();
  if (!/^\d/.test(code)) {
    if (/^X0[ABC]/.test(code)) return "NU";
    const map: Record<string, string> = {
      A: "NL", B: "NS", C: "PE", E: "NB", G: "QC", H: "QC", J: "QC",
      K: "ON", L: "ON", M: "ON", N: "ON", P: "ON", R: "MB", S: "SK",
      T: "AB", V: "BC", X: "NT", Y: "YT",
    };
    return map[code[0]] ?? "CA";
  }
  const n = Number(code.slice(0, 3));
  const ranges: Array<[number, number, string]> = [
    [10,27,"MA"],[28,29,"RI"],[30,38,"NH"],[39,49,"ME"],[50,59,"VT"],[60,69,"CT"],
    [70,89,"NJ"],[100,149,"NY"],[150,196,"PA"],[197,199,"DE"],[200,205,"DC"],[206,219,"MD"],
    [220,246,"VA"],[247,268,"WV"],[270,289,"NC"],[290,299,"SC"],[300,319,"GA"],[320,349,"FL"],
    [350,369,"AL"],[370,385,"TN"],[386,397,"MS"],[400,427,"KY"],[430,458,"OH"],[460,479,"IN"],
    [480,499,"MI"],[500,528,"IA"],[530,549,"WI"],[550,567,"MN"],[570,577,"SD"],[580,588,"ND"],
    [590,599,"MT"],[600,629,"IL"],[630,658,"MO"],[660,679,"KS"],[680,693,"NE"],[700,714,"LA"],
    [716,729,"AR"],[730,749,"OK"],[750,799,"TX"],[800,816,"CO"],[820,831,"WY"],[832,838,"ID"],
    [840,847,"UT"],[850,865,"AZ"],[870,884,"NM"],[889,898,"NV"],[900,961,"CA"],[967,968,"HI"],
    [970,979,"OR"],[980,994,"WA"],[995,999,"AK"],
  ];
  return ranges.find(([start, end]) => n >= start && n <= end)?.[2] ?? "US";
}

function healthPriority(name: string): number {
  const value = name.normalize("NFKD").replace(/[\u0300-\u036f]/g, "").toLowerCase();
  if (/(chips|croustille|cookie|biscuit|candy|bonbon|chocolat|soft drink|soda|liqueur|energy drink|boisson energ|frozen pizza|pizza surgelee|frozen meal|repas surgele|instant noodle|nouille instant|donut|beigne|cake|gateau|ice cream|creme glacee|hot dog|wiener|saucisse fumee)/.test(value)) return 15;
  if (/(fruit|legume|vegetable|pomme|banane|orange|bleuet|fraise|avocat|tomate|brocoli|epinard|carotte|poivron|poulet|chicken|poisson|fish|saumon|salmon|thon|tuna|oeuf|egg|lentille|haricot|pois chiche|tofu|avoine|oat)/.test(value)) return 100;
  if (/(lait|milk|yogourt|yogurt|riz|rice|pain|bread|pasta|pates|fromage|cheese|hummus|beurre d arachide|peanut butter|surgele|frozen|conserve|canned)/.test(value)) return 75;
  return 45;
}

async function apifyJson(path: string, token: string, init?: RequestInit) {
  const response = await fetch(path, {
    ...init,
    headers: { "Authorization": `Bearer ${token}`, "Content-Type": "application/json", ...(init?.headers ?? {}) },
  });
  if (!response.ok) throw new Error(`Apify HTTP ${response.status}: ${await response.text()}`);
  return await response.json();
}

function matchesSecret(provided: string | null, expected: string | undefined): boolean {
  if (!provided || !expected || provided.length !== expected.length) return false;
  let difference = 0;
  for (let index = 0; index < expected.length; index++) {
    difference |= provided.charCodeAt(index) ^ expected.charCodeAt(index);
  }
  return difference === 0;
}

Deno.serve(async (req: Request) => {
  if (req.method !== "POST") return new Response("POST required", { status: 405 });
  if (!matchesSecret(req.headers.get("x-lemora-ingest-secret"), Deno.env.get("LEMORA_INGEST_SECRET"))) {
    return Response.json({ ok: false, error: "Forbidden" }, { status: 403 });
  }
  const body = (await req.json().catch(() => ({}))) as Input;
  if (!body.postalCodes?.length && !body.regionPresets?.length) {
    return Response.json({ ok: false, error: "Specify Canadian postalCodes or ca-major-cities" }, { status: 400 });
  }
  if (body.postalCodes?.some((code) => !/^[ABCEGHJ-NPRSTVXY]\d[ABCEGHJ-NPRSTV-Z][ -]?\d[ABCEGHJ-NPRSTV-Z]\d$/i.test(code))) {
    return Response.json({ ok: false, error: "Invalid Canadian postal code" }, { status: 400 });
  }
  if (body.regionPresets?.some((preset) => preset !== "ca-major-cities")) {
    return Response.json({ ok: false, error: "Only ca-major-cities is supported" }, { status: 400 });
  }
  // A bounded run keeps accidental nationwide sweeps within a small spend.
  // Expand only after cost/coverage are measured and a monthly budget is set.
  const maxItems = Math.min(Math.max(body.maxItems ?? 500, 1), 500);
  const actorInput = {
    mode: "flyers",
    postalCodes: body.postalCodes ?? [],
    regionPresets: body.regionPresets ?? [],
    merchants: body.merchants ?? DEFAULT_MERCHANTS,
    // In full-flyer mode, keywords are an optional filter. The old French
    // defaults silently excluded English-language flyers outside Quebec.
    searchTerms: body.searchTerms ?? [],
    categories: ["Groceries"],
    itemTypes: ["flyer"],
    onlyValidNow: body.onlyValidNow ?? false,
    language: body.language ?? "en",
    maxItems,
    maxPostalCodes: Math.min(Math.max(body.maxPostalCodes ?? 25, 1), 25),
    maxItemsPerPostalCode: Math.min(Math.max(body.maxItemsPerPostalCode ?? maxItems, 1), maxItems),
    completeCoverage: true,
    // A deduped result retains only one postal code and cannot prove where a
    // flyer applies. Deduplicate publications/items in Postgres instead.
    dedupeAcrossPostalCodes: false,
    includeItemDetails: true,
  };

  if (body.dryRun) return Response.json({ ok: true, dryRun: true, actorInput });

  const token = Deno.env.get("APIFY_TOKEN");
  if (!token) return Response.json({ ok: false, error: "APIFY_TOKEN is not configured" }, { status: 503 });

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  const { data: source } = await supabase.from("data_sources").select("id")
    .eq("provider_type", "RetailerApiProvider").contains("config", { actor: "yugenox/flipp-flyer-deals-scraper" })
    .limit(1).maybeSingle();
  const { data: run, error: runError } = await supabase.from("ingestion_runs")
    .insert({ data_source_id: source?.id ?? null, status: "running", notes: JSON.stringify({ actorInput }) })
    .select("id").single();
  if (runError) throw runError;

  try {
    const started = await apifyJson(`${APIFY_API}/runs?waitForFinish=120`, token, {
      method: "POST", body: JSON.stringify(actorInput),
    });
    const actorRun = started.data;
    if (actorRun.status !== "SUCCEEDED") throw new Error(`Actor finished with status ${actorRun.status}`);

    const datasetId = actorRun.defaultDatasetId as string;
    const deals = await apifyJson(
      `https://api.apify.com/v2/datasets/${datasetId}/items?clean=true&format=json&limit=${maxItems}`,
      token,
    ) as FlippDeal[];
    const healthFocus = body.healthFocus ?? true;
    const flyerDeals = deals.filter((deal) =>
      deal.itemType === "flyer" && deal.name && deal.currentPrice != null
      && deal.flyerId != null && deal.postalCode
      && countryFor(deal.postalCode) === "CA" && deal.currency === "CAD"
      && (!healthFocus || healthPriority(deal.name) >= 50)
    );
    const publicationCache = new Map<string, string>();
    const chainCache = new Map<string, string>();
    const coverageCache = new Set<string>();
    const itemCoverageCache = new Set<string>();
    let written = 0;

    for (const deal of flyerDeals) {
      const country = countryFor(deal.postalCode);
      const region = regionFor(deal.postalCode);
      const canonicalName = slug(deal.merchant);
      const chainKey = `${country}:${canonicalName}:${region}`;
      let chainId = chainCache.get(chainKey);
      if (!chainId) {
      const chainPayload = {
        name: deal.merchant,
        canonical_name: canonicalName,
        display_name_en: deal.merchant,
        country_code: country,
        // A banner is national; never overwrite it with the latest province.
        province_state_code: null,
        is_active: true,
        data_source_type: "AUTOMATIC_PARTIAL",
        data_source_identifier: `apify_flipp:${deal.merchantId}`,
        last_ingestion_attempt: new Date().toISOString(),
        last_successful_ingestion: new Date().toISOString(),
        data_confidence: "medium",
      };
      const { data: existingChain, error: lookupError } = await supabase
        .from("grocery_store_chains")
        .select("id,regions")
        .eq("country_code", country)
        .eq("canonical_name", canonicalName)
        .limit(1)
        .maybeSingle();
      if (lookupError) throw lookupError;

      let chain = existingChain;
      const knownRegions = Array.isArray(existingChain?.regions) ? existingChain.regions : [];
      const mergedRegions = [...new Set([...knownRegions, region])];
      if (chain) {
        const { error: updateError } = await supabase.from("grocery_store_chains")
          .update({ ...chainPayload, regions: mergedRegions }).eq("id", chain.id);
        if (updateError) throw updateError;
      } else {
        const { data: insertedChain, error: insertError } = await supabase
          .from("grocery_store_chains")
          .insert({ ...chainPayload, regions: mergedRegions })
          .select("id,regions")
          .single();
        if (insertError) {
          // A concurrent regional import may have created the chain after our lookup.
          const { data: racedChain, error: racedLookupError } = await supabase
            .from("grocery_store_chains")
            .select("id,regions")
            .eq("country_code", country)
            .eq("canonical_name", canonicalName)
            .limit(1)
            .maybeSingle();
          if (racedLookupError || !racedChain) throw insertError;
          chain = racedChain;
        } else {
          chain = insertedChain;
        }
      }
      if (!chain) throw new Error(`Unable to resolve grocery chain ${country}/${canonicalName}`);
      chainId = chain.id;
      chainCache.set(chainKey, chainId);
      }

      const validFrom = localDate(deal.validFrom, region);
      const validUntil = localDate(deal.validTo, region, true);
      const sourceUrl = `https://console.apify.com/storage/datasets/${datasetId}#flyer-${deal.flyerId ?? "unknown"}`;
      const publicationKey = `${chainId}:${deal.flyerId}:${validFrom}:${validUntil}`;
      let publicationId = publicationCache.get(publicationKey);
      if (!publicationId) {
        const publicationQuery = () => supabase.from("flyer_publications")
          .select("id")
          .eq("chain_id", chainId)
          .eq("source_provider", "apify_flipp_v2")
          .eq("source_flyer_id", String(deal.flyerId))
          .eq("valid_from", validFrom)
          .eq("valid_until", validUntil)
          .limit(1).maybeSingle();
        const { data: existingPublication, error: publicationLookupError } = await publicationQuery();
        if (publicationLookupError) throw publicationLookupError;
        let publication = existingPublication;
        if (!publication) {
          const { data: insertedPublication, error: publicationInsertError } = await supabase.from("flyer_publications")
          .insert({
            chain_id: chainId,
            data_source_id: source?.id ?? null,
            // Region is an observation, not proof of province-wide validity.
            region_codes: [],
            valid_from: validFrom,
            valid_until: validUntil,
            source_url: sourceUrl,
            source_provider: "apify_flipp_v2",
            source_flyer_id: String(deal.flyerId),
            source_merchant_id: String(deal.merchantId),
            last_observed_at: new Date().toISOString(),
            ingestion_run_id: run.id,
            // Keep this pilot out of the legacy province/FSA-based app feed.
            // A verified exact-postal query is required before promotion.
            is_stale: true,
          })
          .select("id").single();
          if (publicationInsertError) {
            // Concurrent import of the same edition: resolve the unique key.
            const raced = await publicationQuery();
            if (raced.error || !raced.data) throw publicationInsertError;
            publication = raced.data;
          } else publication = insertedPublication;
        } else {
          const { error: observedError } = await supabase.from("flyer_publications")
            .update({ last_observed_at: new Date().toISOString() }).eq("id", publication.id);
          if (observedError) throw observedError;
        }
        if (!publication) throw new Error(`Unable to resolve flyer ${deal.flyerId}`);
        publicationId = publication.id;
        publicationCache.set(publicationKey, publicationId);
      }

      const postalCode = deal.postalCode.replace(/[^A-Za-z0-9]/g, "").toUpperCase();
      const coverageKey = `${publicationId}:${postalCode}`;
      if (!coverageCache.has(coverageKey)) {
        const { error: coverageError } = await supabase.from("flyer_postal_coverage")
          .upsert({
            publication_id: publicationId,
            postal_code: postalCode,
            last_observed_at: new Date().toISOString(),
            last_ingestion_run_id: run.id,
          }, { onConflict: "publication_id,postal_code" });
        if (coverageError) throw coverageError;
        coverageCache.add(coverageKey);
      }

      const payload = { ...deal, datasetId, apifyRunId: actorRun.id, healthPriorityScore: healthPriority(deal.name) };
      const { data: storedItem, error: itemError } = await supabase.from("flyer_items").upsert({
        flyer_publication_id: publicationId,
        raw_description: deal.name,
        raw_brand: deal.brand ?? null,
        raw_size: productSize(deal),
        regular_price: deal.originalPrice ?? null,
        sale_price: deal.currentPrice,
        multi_buy_quantity: deal.multiBuy?.quantity ?? null,
        multi_buy_total_price: deal.multiBuy?.totalPrice ?? null,
        // Flipp can return the same promotion with a different itemId for every
        // queried postal code. This stable identity prevents those copies forever.
        dedup_key: semanticDealKey(deal),
        source_item_id: String(deal.itemId),
        source_locale: deal.locale ?? null,
        source_postal_code: postalCode,
        image_url: deal.imageUrl ?? null,
        product_url: deal.productUrl ?? null,
        source_payload: payload,
      }, { onConflict: "flyer_publication_id,dedup_key" }).select("id").single();
      if (itemError) throw itemError;
      const itemPostalKey = `${storedItem.id}:${postalCode}`;
      if (!itemCoverageCache.has(itemPostalKey)) {
        const { error: itemCoverageError } = await supabase.from("flyer_item_postal_coverage")
          .upsert({
            item_id: storedItem.id,
            postal_code: postalCode,
            last_observed_at: new Date().toISOString(),
            last_ingestion_run_id: run.id,
          }, { onConflict: "item_id,postal_code" });
        if (itemCoverageError) throw itemCoverageError;
        itemCoverageCache.add(itemPostalKey);
      }
      written += 1;
    }

    await supabase.from("flyer_publications").update({ is_stale: true })
      .lt("valid_until", new Date().toISOString().slice(0, 10));
    await supabase.from("ingestion_runs").update({
      status: "succeeded", finished_at: new Date().toISOString(), items_seen: deals.length,
      items_upserted: written, items_rejected: deals.length - written,
      notes: JSON.stringify({ apifyRunId: actorRun.id, datasetId, actorInput }),
    }).eq("id", run.id);

    return Response.json({ ok: true, runId: run.id, apifyRunId: actorRun.id, datasetId, itemsSeen: deals.length, itemsWritten: written });
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    await supabase.from("ingestion_runs").update({ status: "failed", finished_at: new Date().toISOString(), notes: message }).eq("id", run.id);
    await supabase.from("ingestion_errors").insert({ ingestion_run_id: run.id, severity: "critical", message });
    return Response.json({ ok: false, runId: run.id, error: message }, { status: 500 });
  }
});
