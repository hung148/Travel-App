#!/usr/bin/env node
//
// Shows what Google actually returns for a destination, so shopping bugs can
// be diagnosed with data instead of guesses.
//
//   node tools/probe-places.js "Da Nang" YOUR_MAPS_API_KEY
//
// Prints, in order:
//   1. where the destination resolves to      (a wrong centre explains a lot)
//   2. what Text Search returns for shopping  (what the app now uses)
//   3. what Nearby Search returns for shopping (what the app used before)
//
// For each place: name, primary type, review count, distance from the centre,
// and whether the app's rules would keep it.

const [, , destination, apiKey] = process.argv;

if (!destination || !apiKey) {
  console.error(
    'Usage: node tools/probe-places.js "<destination>" <MAPS_API_KEY>',
  );
  process.exit(1);
}

const fieldMask = [
  "places.id",
  "places.displayName",
  "places.formattedAddress",
  "places.location",
  "places.rating",
  "places.userRatingCount",
  "places.types",
  "places.primaryType",
].join(",");

// Kept in step with lib/models/place_role.dart.
const majorShoppingTypes = new Set(["shopping_mall", "market"]);
const narrowRetailTypes = new Set([
  "supermarket",
  "wholesaler",
  "warehouse_store",
]);

function isMajorShoppingPlace(types = [], primaryType = "") {
  const normalized = types.map((type) => type.toLowerCase().trim());
  const primary = primaryType.toLowerCase().trim();
  if (primary) return majorShoppingTypes.has(primary);
  if (!normalized.some((type) => majorShoppingTypes.has(type))) return false;
  return !normalized.some(
    (type) => type.endsWith("_store") || narrowRetailTypes.has(type),
  );
}

async function places(url, body) {
  const response = await fetch(url, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "X-Goog-Api-Key": apiKey,
      "X-Goog-FieldMask": fieldMask,
    },
    body: JSON.stringify(body),
  });
  if (!response.ok) {
    throw new Error(`${response.status} ${await response.text()}`);
  }
  return (await response.json()).places ?? [];
}

function distanceKm(from, to) {
  const radians = (degrees) => (degrees * Math.PI) / 180;
  const dLat = radians(to.latitude - from.latitude);
  const dLng = radians(to.longitude - from.longitude);
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(radians(from.latitude)) *
      Math.cos(radians(to.latitude)) *
      Math.sin(dLng / 2) ** 2;
  return 6371 * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

function report(title, results, centre) {
  console.log(`\n${title}`);
  if (results.length === 0) {
    console.log("  (nothing returned)");
    return;
  }
  for (const place of results) {
    const kept = isMajorShoppingPlace(place.types, place.primaryType);
    const reviews = place.userRatingCount ?? 0;
    const away = place.location
      ? `${distanceKm(centre, place.location).toFixed(1)}km`
      : "?";
    console.log(
      `  ${kept ? "keep" : "DROP"}  ${String(reviews).padStart(6)} reviews  ` +
        `${away.padStart(7)}  ${place.primaryType ?? "-"}  ` +
        `${place.displayName?.text ?? place.id}`,
    );
  }
  const kept = results.filter((place) =>
    isMajorShoppingPlace(place.types, place.primaryType),
  );
  if (kept.length > 0) {
    const busiest = Math.max(
      ...kept.map((place) => place.userRatingCount ?? 0),
    );
    const floor = Math.max(1000, Math.round(busiest * 0.05));
    console.log(
      `  -> review floor for this destination: ${floor} ` +
        `(busiest kept: ${busiest})`,
    );
  }
}

async function main() {
  const found = await places(
    "https://places.googleapis.com/v1/places:searchText",
    { textQuery: destination, maxResultCount: 5 },
  );
  const centre = found[0]?.location;
  if (!centre) throw new Error(`Could not resolve "${destination}"`);

  console.log(`Destination "${destination}" resolves to:`);
  console.log(
    `  ${found[0].displayName?.text} (${found[0].primaryType ?? "-"})`,
  );
  console.log(`  ${centre.latitude}, ${centre.longitude}`);
  console.log(`  https://www.google.com/maps/@${centre.latitude},${centre.longitude},13z`);
  console.log("  ^ open this. A centre in the wrong place explains everything.");

  const radius = 15000;
  for (const query of ["shopping mall", "market"]) {
    report(
      `Text Search "${query}" (what the app uses now):`,
      await places("https://places.googleapis.com/v1/places:searchText", {
        textQuery: query,
        maxResultCount: 20,
        locationBias: {
          circle: { center: centre, radius },
        },
      }),
      centre,
    );
  }

  for (const type of ["shopping_mall", "market"]) {
    report(
      `Nearby Search includedTypes:[${type}] (what it used before):`,
      await places("https://places.googleapis.com/v1/places:searchNearby", {
        includedTypes: [type],
        maxResultCount: 20,
        locationRestriction: {
          circle: { center: centre, radius },
        },
      }),
      centre,
    );
  }
}

main().catch((error) => {
  console.error(error.message);
  process.exit(1);
});
