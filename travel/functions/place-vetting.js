// Shopping-place vetting.
//
// Google's place types are filled in by the business owner, so a shophouse
// selling robot vacuums can register itself as `shopping_mall` with no other
// type to contradict it. No type rule catches that. The name does:
// "Mi Việt Nam - chuyên gia robot hút bụi" says exactly what the place is.
//
// This module holds the pure pieces - schema, instruction, input and output
// validation - so they can be tested without a network or a provider. The
// transport lives in index.js (OpenAI, production) and local-server.js (Groq,
// development).

/// Bump when the instruction or the schema changes meaningfully. Cached
/// verdicts carrying a different version are ignored and re-judged.
export const verdictVersion = 1;

/// One provider call judges at most this many places. The planner sends at
/// most a dozen, so this is a guard against a malformed request, not a limit
/// anyone should hit.
export const maxPlacesPerRequest = 25;

export const verdictSchema = {
  type: "object",
  additionalProperties: false,
  required: ["verdicts"],
  properties: {
    verdicts: {
      type: "array",
      items: {
        type: "object",
        additionalProperties: false,
        required: ["placeId", "isShoppingDestination", "reason"],
        properties: {
          placeId: { type: "string" },
          isShoppingDestination: { type: "boolean" },
          reason: { type: "string" },
        },
      },
    },
  },
};

export const systemInstruction = `You decide whether a place is a SHOPPING DESTINATION worth putting in a tourist's day plan.

Answer true only for:
- a shopping mall, shopping centre, plaza or trade centre (Vincom, Lotte, Aeon, Parkson, Takashimaya)
- a large public or night market a visitor would browse for an hour or more (Chợ Bến Thành, Chợ Đà Lạt, Chợ Hàn, Chợ Đêm)
- a large multi-floor department store complex

Answer false for everything else, INCLUDING places whose Google type says "shopping_mall". Business owners choose their own type and often choose wrongly. False for:
- a shop selling one kind of product: shoes, clothes, phones, robot vacuums, appliances, furniture, jewellery, souvenirs, books
- a brand showroom, dealership, service or repair centre
- a supermarket, minimart, convenience store or grocery
- a single street-front shophouse of any kind

The NAME is your strongest evidence, and many are Vietnamese. Read it carefully:
- "chuyên gia robot hút bụi" = robot vacuum specialist -> false
- "Điện Máy" = electrical appliances -> false
- "Trung tâm thương mại" = trade/shopping centre -> true
- "Chợ" = market -> true if it is a real market, false for a shop that merely uses the word
- a street address in the name ("- 312 Điện Biên Phủ") suggests a single shophouse

Review count helps: a real mall or major market has thousands of reviews. A few hundred, on a place whose name reads like a shop, is a shop.

Return exactly one verdict for every placeId you were given, no more and no fewer, reusing each placeId exactly as it was written. Keep each reason under 15 words.`;

class VettingError extends Error {
  constructor(message, status) {
    super(message);
    this.status = status;
  }
}

function text(value, limit) {
  if (typeof value !== "string") return "";
  return value.trim().slice(0, limit);
}

/// Validates and trims what the client sent, so neither the provider nor the
/// cache ever sees unbounded input.
export function normalizeCandidates(value) {
  if (!Array.isArray(value) || value.length === 0) {
    throw new VettingError("places must be a non-empty array", 400);
  }
  if (value.length > maxPlacesPerRequest) {
    throw new VettingError(
      `At most ${maxPlacesPerRequest} places per request`,
      400,
    );
  }

  const seen = new Set();
  const candidates = [];
  for (const entry of value) {
    if (!entry || typeof entry !== "object") {
      throw new VettingError("Each place must be an object", 400);
    }
    const placeId = text(entry.placeId, 200);
    const name = text(entry.name, 200);
    if (placeId.length === 0 || name.length === 0) {
      throw new VettingError("Each place needs a placeId and a name", 400);
    }
    if (seen.has(placeId)) continue;
    seen.add(placeId);

    const types = Array.isArray(entry.types)
      ? entry.types
          .map((type) => text(type, 60))
          .filter((type) => type.length > 0)
          .slice(0, 20)
      : [];

    const reviewCount = Number.isFinite(entry.reviewCount)
      ? Math.max(0, Math.trunc(entry.reviewCount))
      : 0;

    candidates.push({
      placeId,
      name,
      address: text(entry.address, 300),
      primaryType: text(entry.primaryType, 60),
      types,
      reviewCount,
    });
  }

  if (candidates.length === 0) {
    throw new VettingError("places must be a non-empty array", 400);
  }
  return candidates;
}

/// Turns the model's reply into a placeId -> verdict map.
///
/// Verdicts for places that were not asked about are dropped. Places the model
/// skipped are simply absent: the caller decides what an absent verdict means,
/// and in this app it means "keep it", so a confused model can never empty a
/// traveler's shopping plan.
export function validateVerdicts(payload, candidates) {
  const asked = new Set(candidates.map((candidate) => candidate.placeId));
  const list = payload?.verdicts;
  if (!Array.isArray(list)) {
    throw new VettingError("The model returned no verdicts", 502);
  }

  const verdicts = {};
  for (const entry of list) {
    if (!entry || typeof entry !== "object") continue;
    const placeId = text(entry.placeId, 200);
    if (!asked.has(placeId)) continue;
    if (typeof entry.isShoppingDestination !== "boolean") continue;
    verdicts[placeId] = {
      isShoppingDestination: entry.isShoppingDestination,
      reason: text(entry.reason, 200),
    };
  }
  return verdicts;
}

/// What the provider is asked to judge. Deliberately small: a name, what
/// Google thinks it is, and how busy it is.
export function providerInput(candidates) {
  return JSON.stringify({
    places: candidates.map((candidate) => ({
      placeId: candidate.placeId,
      name: candidate.name,
      address: candidate.address,
      googlePrimaryType: candidate.primaryType,
      googleTypes: candidate.types,
      reviewCount: candidate.reviewCount,
    })),
  });
}

export { VettingError };
