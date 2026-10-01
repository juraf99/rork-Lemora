import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

const ACTOR = "yugenox~flipp-flyer-deals-scraper";
const APIFY_API = `https://api.apify.com/v2/acts/${ACTOR}`;
const DEFAULT_MERCHANTS = [
  "Maxi", "IGA", "Metro", "Super C", "Provigo", "Walmart", "Costco",
];
const DEFAULT_SEARCH_TERMS = [
  "poulet", "poisson", "saumon", "thon", "oeufs", "tofu", "lait", "yogourt",
  "lentilles", "haricots", "pois chiches", "riz", "avoine", "pain grains entiers",
  "pommes", "bananes", "oranges", "bleuets", "fraises", "avocats", "tomates",
  "brocoli", "épinards", "carottes", "poivrons", "légumes surgelés",
];

type Input = {
  postalCodes?: string[];
  regionPresets?: Array<"ca-major-cities" | "us-major-cities">;
  merchants?: string[];
  searchTerms?: string[];
  maxItems?: number;
  maxPostalCodes?: number;
  language?: "en" | "fr";
  onlyValidNow?: boolean;
  healthFocus?: boolean;
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
    deal.currentPrice?.toFixed(2) ?? "",
    slug(deal.priceUnit ?? ""),
    slug(productSize(deal) ?? ""),
    String(deal.multiBuy?.quantity ?? ""),
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
    AK: "America/Anchorage", HI: "Pacific/Honolulu", CA: "America/Los_Angeles",
    WA: "America/Los_Angeles", OR: "America/Los_Angeles", NV: "America/Los_Angeles",
    AZ: "America/Phoenix", CO: "America/Denver", UT: "America/Denver", TX: "America/Chicago",
    IL: "America/Chicago", FL: "America/New_York", NY: "America/New_York", MA: "America/New_York",
  };
  return zones[region] ?? "America/New_York";
}

function localDate(value: string, region: string, exclusiveEnd = false): string {
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

Deno.serve(async (req: Request) => {
  if (req.method !== "POST") return new Response("POST required", { status: 405 });

  const token = Deno.env.get("APIFY_TOKEN");
  if (!token) return Response.json({ ok: false, error: "APIFY_TOKEN is not configured" }, { status: 503 });

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );
  const body = (await req.json().catch(() => ({}))) as Input;
  const maxItems = Math.min(Math.max(body.maxItems ?? 500, 1), 10_000);
  const actorInput = {
    mode: "flyers",
    postalCodes: body.postalCodes ?? ["H2X 1Y4"],
    regionPresets: body.regionPresets ?? [],
    merchants: body.merchants ?? DEFAULT_MERCHANTS,
    searchTerms: body.searchTerms ?? DEFAULT_SEARCH_TERMS,
    categories: ["Groceries"],
    itemTypes: ["flyer"],
    onlyValidNow: body.onlyValidNow ?? false,
    language: body.language ?? "fr",
    maxItems,
    maxPostalCodes: Math.min(Math.max(body.maxPostalCodes ?? 100, 1), 100),
    completeCoverage: true,
    dedupeAcrossPostalCodes: true,
    includeItemDetails: true,
  };

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
      && (!healthFocus || healthPriority(deal.name) >= 50)
    );
    const publicationCache = new Map<string, string>();
    let written = 0;

    for (const deal of flyerDeals) {
      const country = countryFor(deal.postalCode);
      const region = regionFor(deal.postalCode);
      const canonicalName = slug(deal.merchant);
      const chainPayload = {
        name: deal.merchant,
        canonical_name: canonicalName,
        display_name_en: deal.merchant,
        country_code: country,
        province_state_code: region,
        regions: [region],
        is_active: true,
        data_source_type: "AUTOMATIC_PARTIAL",
        data_source_identifier: `apify_flipp:${deal.merchantId}`,
        last_ingestion_attempt: new Date().toISOString(),
        last_successful_ingestion: new Date().toISOString(),
        data_confidence: "medium",
      };
      const { data: existingChain, error: lookupError } = await supabase
        .from("grocery_store_chains")
        .select("id")
        .eq("country_code", country)
        .eq("canonical_name", canonicalName)
        .limit(1)
        .maybeSingle();
      if (lookupError) throw lookupError;

      let chain = existingChain;
      if (chain) {
        const { error: updateError } = await supabase.from("grocery_store_chains")
          .update(chainPayload).eq("id", chain.id);
        if (updateError) throw updateError;
      } else {
        const { data: insertedChain, error: insertError } = await supabase
          .from("grocery_store_chains")
          .insert(chainPayload)
          .select("id")
          .single();
        if (insertError) {
          // A concurrent regional import may have created the chain after our lookup.
          const { data: racedChain, error: racedLookupError } = await supabase
            .from("grocery_store_chains")
            .select("id")
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

      const validFrom = localDate(deal.validFrom, region);
      const validUntil = localDate(deal.validTo, region, true);
      const sourceUrl = `https://console.apify.com/storage/datasets/${datasetId}#flyer-${deal.flyerId ?? "unknown"}`;
      const publicationKey = `${chain.id}:${deal.flyerId}:${validFrom}:${validUntil}:${region}`;
      let publicationId = publicationCache.get(publicationKey);
      if (!publicationId) {
        const { data: publication, error: publicationError } = await supabase.from("flyer_publications")
          .upsert({
            chain_id: chain.id,
            data_source_id: source?.id ?? null,
            region_codes: [region],
            valid_from: validFrom,
            valid_until: validUntil,
            source_url: sourceUrl,
            ingestion_run_id: run.id,
            is_stale: false,
          }, { onConflict: "chain_id,valid_from,valid_until,source_url" })
          .select("id").single();
        if (publicationError) throw publicationError;
        publicationId = publication.id;
        publicationCache.set(publicationKey, publicationId);
      }

      const payload = { ...deal, datasetId, apifyRunId: actorRun.id, healthPriorityScore: healthPriority(deal.name) };
      const { error: itemError } = await supabase.from("flyer_items").upsert({
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
        source_postal_code: deal.postalCode.replace(/\s/g, "").toUpperCase(),
        image_url: deal.imageUrl ?? null,
        product_url: deal.productUrl ?? null,
        source_payload: payload,
      }, { onConflict: "flyer_publication_id,dedup_key" });
      if (itemError) throw itemError;
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
