import assert from "node:assert/strict";
import test from "node:test";

import {
  maxPlacesPerRequest,
  normalizeCandidates,
  providerInput,
  validateVerdicts,
  verdictSchema,
} from "../place-vetting.js";

const vacuumShop = {
  placeId: "vacuum-shop",
  name: "Mi Việt Nam - 312 Điện Biên Phủ",
  address: "312 Điện Biên Phủ, Thanh Khê, Đà Nẵng",
  primaryType: "shopping_mall",
  types: ["shopping_mall", "point_of_interest"],
  reviewCount: 300,
};

test("normalizeCandidates keeps the fields the model needs", () => {
  const [candidate] = normalizeCandidates([vacuumShop]);
  assert.equal(candidate.placeId, "vacuum-shop");
  assert.equal(candidate.name, "Mi Việt Nam - 312 Điện Biên Phủ");
  assert.equal(candidate.primaryType, "shopping_mall");
  assert.deepEqual(candidate.types, ["shopping_mall", "point_of_interest"]);
  assert.equal(candidate.reviewCount, 300);
});

test("normalizeCandidates drops duplicate place ids", () => {
  const candidates = normalizeCandidates([vacuumShop, { ...vacuumShop }]);
  assert.equal(candidates.length, 1);
});

test("normalizeCandidates rejects unusable input", () => {
  assert.throws(() => normalizeCandidates([]), /non-empty/);
  assert.throws(() => normalizeCandidates("nope"), /non-empty/);
  assert.throws(
    () => normalizeCandidates([{ placeId: "x" }]),
    /placeId and a name/,
  );
  assert.throws(
    () =>
      normalizeCandidates(
        Array.from({ length: maxPlacesPerRequest + 1 }, (_, index) => ({
          placeId: `p${index}`,
          name: `Place ${index}`,
        })),
      ),
    /At most/,
  );
});

test("normalizeCandidates bounds every string it passes on", () => {
  const [candidate] = normalizeCandidates([
    {
      placeId: "p",
      name: "n".repeat(500),
      address: "a".repeat(1000),
      types: Array.from({ length: 50 }, () => "t".repeat(100)),
      reviewCount: -5,
    },
  ]);
  assert.equal(candidate.name.length, 200);
  assert.equal(candidate.address.length, 300);
  assert.equal(candidate.types.length, 20);
  assert.equal(candidate.types[0].length, 60);
  assert.equal(candidate.reviewCount, 0);
});

test("validateVerdicts reads a well-formed reply", () => {
  const candidates = normalizeCandidates([
    vacuumShop,
    { placeId: "vincom", name: "Vincom Plaza", reviewCount: 30000 },
  ]);
  const verdicts = validateVerdicts(
    {
      verdicts: [
        {
          placeId: "vacuum-shop",
          isShoppingDestination: false,
          reason: "Robot vacuum specialist, single shophouse",
        },
        {
          placeId: "vincom",
          isShoppingDestination: true,
          reason: "Major shopping mall",
        },
      ],
    },
    candidates,
  );
  assert.equal(verdicts["vacuum-shop"].isShoppingDestination, false);
  assert.equal(verdicts.vincom.isShoppingDestination, true);
});

test("validateVerdicts ignores places nobody asked about", () => {
  const candidates = normalizeCandidates([vacuumShop]);
  const verdicts = validateVerdicts(
    {
      verdicts: [
        { placeId: "vacuum-shop", isShoppingDestination: false, reason: "" },
        { placeId: "invented", isShoppingDestination: true, reason: "" },
      ],
    },
    candidates,
  );
  assert.deepEqual(Object.keys(verdicts), ["vacuum-shop"]);
});

test("a skipped place gets no verdict, so the client keeps it", () => {
  const candidates = normalizeCandidates([
    vacuumShop,
    { placeId: "vincom", name: "Vincom Plaza" },
  ]);
  const verdicts = validateVerdicts(
    {
      verdicts: [
        { placeId: "vacuum-shop", isShoppingDestination: false, reason: "" },
      ],
    },
    candidates,
  );
  assert.equal(verdicts.vincom, undefined);
});

test("validateVerdicts rejects a reply that is not a verdict list", () => {
  const candidates = normalizeCandidates([vacuumShop]);
  assert.throws(() => validateVerdicts({}, candidates), /no verdicts/);
  assert.throws(() => validateVerdicts(null, candidates), /no verdicts/);
});

test("validateVerdicts skips entries with a non-boolean answer", () => {
  const candidates = normalizeCandidates([vacuumShop]);
  const verdicts = validateVerdicts(
    { verdicts: [{ placeId: "vacuum-shop", isShoppingDestination: "no" }] },
    candidates,
  );
  assert.deepEqual(verdicts, {});
});

test("providerInput sends the name, types and review count", () => {
  const payload = JSON.parse(providerInput(normalizeCandidates([vacuumShop])));
  assert.equal(payload.places.length, 1);
  assert.equal(payload.places[0].name, "Mi Việt Nam - 312 Điện Biên Phủ");
  assert.equal(payload.places[0].googlePrimaryType, "shopping_mall");
  assert.equal(payload.places[0].reviewCount, 300);
});

test("the schema is strict enough for structured outputs", () => {
  assert.equal(verdictSchema.additionalProperties, false);
  const item = verdictSchema.properties.verdicts.items;
  assert.equal(item.additionalProperties, false);
  assert.deepEqual(item.required, [
    "placeId",
    "isShoppingDestination",
    "reason",
  ]);
  // strict mode requires every declared property to be required.
  assert.deepEqual(Object.keys(item.properties).sort(), item.required.sort());
});
