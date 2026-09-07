import { getApps, initializeApp } from "firebase-admin/app";
import { getAuth } from "firebase-admin/auth";
import { FieldValue, getFirestore } from "firebase-admin/firestore";
import { onRequest } from "firebase-functions/v2/https";
import { defineSecret } from "firebase-functions/params";
import {
  commandSchema,
  contextError,
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

const openAiApiKey = defineSecret("OPENAI_API_KEY");

export const interpretTripRequest = onRequest(
  { cors: true, secrets: [openAiApiKey], timeoutSeconds: 30 },
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
      await getAuth().verifyIdToken(bearer.slice(7));

      const instruction = String(request.body?.instruction ?? "").trim();
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

      const openAiResponse = await fetch("https://api.openai.com/v1/responses", {
        method: "POST",
        headers: {
          Authorization: `Bearer ${openAiApiKey.value()}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          model: process.env.OPENAI_MODEL || "gpt-5-mini",
          instructions: systemInstruction,
          input: JSON.stringify({ instruction, context }),
          text: {
            format: {
              type: "json_schema",
              name: "trip_ai_command",
              strict: true,
              schema: commandSchema,
            },
          },
        }),
      });
      if (!openAiResponse.ok) {
        const detail = await openAiResponse.text();
        console.error("OpenAI request failed", openAiResponse.status, detail);
        response.status(502).json({ error: "AI provider request failed" });
        return;
      }
      const result = await openAiResponse.json();
      const outputText = result.output
        ?.flatMap((item) => item.content ?? [])
        .find((item) => item.type === "output_text")?.text;
      if (!outputText) {
        response.status(502).json({ error: "AI returned no command" });
        return;
      }
      const command = validateCommand(
        JSON.parse(outputText),
        context.destinationId,
      );
      response.status(200).json(command);
    } catch (error) {
      console.error(error);
      response.status(500).json({ error: "Unable to interpret request" });
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
  { cors: true, secrets: [openAiApiKey], timeoutSeconds: 30 },
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
      await getAuth().verifyIdToken(bearer.slice(7));

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
        const openAiResponse = await fetch(
          "https://api.openai.com/v1/responses",
          {
            method: "POST",
            headers: {
              Authorization: `Bearer ${openAiApiKey.value()}`,
              "Content-Type": "application/json",
            },
            body: JSON.stringify({
              model: process.env.OPENAI_VETTING_MODEL ||
                process.env.OPENAI_MODEL ||
                "gpt-5-mini",
              instructions: vettingInstruction,
              input: providerInput(unjudged),
              text: {
                format: {
                  type: "json_schema",
                  name: "shopping_place_verdicts",
                  strict: true,
                  schema: verdictSchema,
                },
              },
            }),
          },
        );
        if (!openAiResponse.ok) {
          const detail = await openAiResponse.text();
          console.error(
            "OpenAI vetting request failed",
            openAiResponse.status,
            detail,
          );
          // Fail open: answer with whatever the cache knew. The client keeps
          // every place it got no verdict for.
          response.status(200).json({ verdicts: booleanVerdicts(known) });
          return;
        }
        const result = await openAiResponse.json();
        const outputText = result.output
          ?.flatMap((item) => item.content ?? [])
          .find((item) => item.type === "output_text")?.text;
        if (outputText) {
          fresh = validateVerdicts(JSON.parse(outputText), unjudged);
          await cacheVerdicts(database, unjudged, fresh);
        }
      }

      response.status(200).json({
        verdicts: booleanVerdicts({ ...known, ...fresh }),
      });
    } catch (error) {
      console.error(error);
      response.status(500).json({ error: "Unable to vet places" });
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
