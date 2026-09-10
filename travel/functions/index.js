import { groqJson } from './groq-provider.js';
import { authenticatedUser, consumeAiQuota } from './endpoint-security.js';
import { validateImportText, validateImportResult, importSchema, importInstruction } from './itinerary-import.js';
import { getApps, initializeApp } from "firebase-admin/app";
import { getAuth } from "firebase-admin/auth";
import { FieldValue, getFirestore } from "firebase-admin/firestore";
import { onRequest } from "firebase-functions/v2/https";
import { defineSecret } from "firebase-functions/params";
import {
  commandSchema,
  contextError,
  recoverExplicitArguments,
  systemInstruction,
  validateCommand,
} from "./trip-command.js";
import {
  normalizeCandidates,
  providerInput,
  systemInstruction as vettingInstruction,
  validateVerdicts,
  verdictSchema,
  verdictVersion,
} from "./place-vetting.js";

if (getApps().length === 0) initializeApp();

const groqApiKey = defineSecret("GROQ_API_KEY");

export const interpretTripRequest = onRequest(
  { cors: true, secrets: [groqApiKey], timeoutSeconds: 60, maxInstances: 2 },
  async (request, response) => {
    try {
      if (request.method !== "POST") {
        response.status(405).json({ error: "POST required" });
        return;
      }
      const bearer = request.headers.authorization ?? "";
      if (!bearer.startsWith("Bearer ")) {
        response.status(401).json({ error: "Authentication required" });
        return;
      }
      const uid = await authenticatedUser(request, getAuth());

      const instruction = typeof request.body?.instruction === "string" ? request.body.instruction.trim() : "";
      const context = request.body?.context ?? {};
      if (instruction.length === 0 || instruction.length > 1000) {
        response.status(400).json({ error: "Invalid instruction" });
        return;
      }

      // The context is serialized straight into the model input, so it is a
      // second, much larger way to spend tokens. The app caps chat history at
      // eight turns, but that is a client and any signed-in account can post
      // whatever it likes directly to this endpoint - so the bound has to
      // live here. Shared with the local gateway; see trip-command.js.
      const contextProblem = contextError(context);
      if (contextProblem) {
        response.status(400).json({ error: contextProblem });
        return;
      }

      await consumeAiQuota(getFirestore(), uid);
      const result = await groqJson({apiKey: groqApiKey.value(),
        name: 'trip_ai_command', schema: commandSchema,
        instruction: systemInstruction, input: JSON.stringify({instruction, context})});
      const command = validateCommand(
        recoverExplicitArguments(result, instruction), context.destinationId);
      response.status(200).json(command);
    } catch (error) {
      console.error('AI endpoint failed', error.status ?? 500);
      response.status(error.status ?? 500).json({ error: error.status ? error.message : "Unable to interpret request" });
    }
  },
);

/// Every place ever judged, keyed by Google place id.
///
/// The verdict for a given place never changes, so this is a permanent cache
/// shared by every user: the second traveler to plan a trip to Da Nang pays
/// nothing. Written with the admin SDK, which bypasses security rules - no
/// client ever reads or writes it.
const verdictCollection = "placeVerdicts";

async function cachedVerdicts(database, placeIds) {
  if (placeIds.length === 0) return {};
  const references = placeIds.map((placeId) =>
    database.collection(verdictCollection).doc(placeId),
  );
  const snapshots = await database.getAll(...references);
  const verdicts = {};
  for (const snapshot of snapshots) {
    if (!snapshot.exists) continue;
    const data = snapshot.data();
    // A changed instruction or schema invalidates old judgements.
    if (data?.version !== verdictVersion) continue;
    if (typeof data.isShoppingDestination !== "boolean") continue;
    verdicts[snapshot.id] = {
      isShoppingDestination: data.isShoppingDestination,
      reason: typeof data.reason === "string" ? data.reason : "",
    };
  }
  return verdicts;
}

async function cacheVerdicts(database, candidates, verdicts) {
  const entries = Object.entries(verdicts);
  if (entries.length === 0) return;
  const namesById = new Map(
    candidates.map((candidate) => [candidate.placeId, candidate.name]),
  );
  const batch = database.batch();
  for (const [placeId, verdict] of entries) {
    batch.set(database.collection(verdictCollection).doc(placeId), {
      ...verdict,
      // Stored only so a human reading the collection can tell what was
      // judged; nothing reads it back.
      name: namesById.get(placeId) ?? "",
      version: verdictVersion,
      updatedAt: FieldValue.serverTimestamp(),
    });
  }
  await batch.commit();
}

/// Judges whether shopping candidates are real shopping destinations.
///
/// Request:  { places: [{ placeId, name, address, primaryType, types,
///                        reviewCount }] }
/// Response: { verdicts: { <placeId>: boolean } }
///
/// A place the model did not judge is simply absent from the response. The
/// client treats absence as "keep", so neither a provider outage nor a
/// confused model can empty a traveler's shopping plan.
export const vetShoppingPlaces = onRequest(
  { cors: true, secrets: [groqApiKey], timeoutSeconds: 60, maxInstances: 2 },
  async (request, response) => {
    try {
      if (request.method !== "POST") {
        response.status(405).json({ error: "POST required" });
        return;
      }
      const bearer = request.headers.authorization ?? "";
      if (!bearer.startsWith("Bearer ")) {
        response.status(401).json({ error: "Authentication required" });
        return;
      }
      const uid = await authenticatedUser(request, getAuth());

      let candidates;
      try {
        candidates = normalizeCandidates(request.body?.places);
      } catch (error) {
        response.status(error.status ?? 400).json({ error: error.message });
        return;
      }

      const database = getFirestore();
      const known = await cachedVerdicts(
        database,
        candidates.map((candidate) => candidate.placeId),
      );
      const unjudged = candidates.filter(
        (candidate) => known[candidate.placeId] === undefined,
      );

      let fresh = {};
      if (unjudged.length > 0) {
        await consumeAiQuota(database, uid);
        try {
          const result = await groqJson({apiKey: groqApiKey.value(),
            name: 'shopping_place_verdicts', schema: verdictSchema,
            instruction: vettingInstruction, input: providerInput(unjudged)});
          fresh = validateVerdicts(result, unjudged);
          await cacheVerdicts(database, unjudged, fresh);
        } catch {
          // Preserve cached verdicts and keep unjudged places on provider failure.
          response.status(200).json({verdicts: booleanVerdicts(known)});
          return;
        }
      }

      response.status(200).json({
        verdicts: booleanVerdicts({ ...known, ...fresh }),
      });
    } catch (error) {
      console.error('AI endpoint failed', error.status ?? 500);
      response.status(error.status ?? 500).json({ error: error.status ? error.message : "Unable to vet places" });
    }
  },
);

function booleanVerdicts(verdicts) {
  const flat = {};
  for (const [placeId, verdict] of Object.entries(verdicts)) {
    flat[placeId] = verdict.isShoppingDestination;
  }
  return flat;
}

export const importItinerary = onRequest(
  {cors: true, secrets: [groqApiKey], timeoutSeconds: 60, maxInstances: 2},
  async (request, response) => {
    try {
      if (request.method !== 'POST') { response.status(405).json({error: 'POST required'}); return; }
      const uid = await authenticatedUser(request, getAuth());
      const text = validateImportText(request.body?.text);
      await consumeAiQuota(getFirestore(), uid);
      const result = await groqJson({apiKey: groqApiKey.value(),
        name: 'itinerary_import', schema: importSchema,
        instruction: importInstruction, input: text});
      response.json(validateImportResult(result, text));
    } catch (error) {
      response.status(error.status ?? 500).json({error: error.status ? error.message : 'Unable to import itinerary'});
    }
  },
);
