import http from "node:http";
import { fileURLToPath } from "node:url";

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
} from "./place-vetting.js";

const host = "127.0.0.1";
const port = Number.parseInt(process.env.AI_GATEWAY_PORT || "8787", 10);
const groqApiKey = process.env.GROQ_API_KEY;
// Only three Groq models support structured outputs with strict: true -
// openai/gpt-oss-20b, openai/gpt-oss-120b and qwen/qwen3.8-27b. The 120b is the
// largest of them and carries the same free-tier quota as the 20b, so it is the
// default; anything outside that list will fail the response_format check.
const model = process.env.GROQ_MODEL || "openai/gpt-oss-120b";
const maximumBodyBytes = 64 * 1024;

class GatewayError extends Error {
  constructor(message, status) {
    super(message);
    this.status = status;
  }
}

function send(response, status, value) {
  response.writeHead(status, {
    "Content-Type": "application/json; charset=utf-8",
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers": "Content-Type, Authorization",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
  });
  response.end(JSON.stringify(value));
}

async function readJson(request) {
  let size = 0;
  const chunks = [];
  for await (const chunk of request) {
    size += chunk.length;
    if (size > maximumBodyBytes) throw new Error("Request is too large");
    chunks.push(chunk);
  }
  return JSON.parse(Buffer.concat(chunks).toString("utf8"));
}

export function salvageFailedGeneration(errorBody) {
  try {
    const parsed = JSON.parse(errorBody);
    const raw = parsed?.error?.failed_generation;
    if (typeof raw !== "string") return null;
    const command = JSON.parse(raw);
    return command && typeof command === "object" && !Array.isArray(command)
      ? command
      : null;
  } catch {
    return null;
  }
}

export async function interpretWithGroq({ instruction, context, apiKey }) {
  if (!apiKey) throw new GatewayError("GROQ_API_KEY is not configured", 503);
  if (typeof instruction !== "string" || instruction.trim().length === 0) {
    throw new GatewayError("Instruction is required", 400);
  }
  if (instruction.length > 1000) {
    throw new GatewayError("Instruction is too long", 400);
  }
  if (!context) {
    throw new GatewayError("Trip context is required", 400);
  }
  // Same bound as the deployed function - see contextError in
  // trip-command.js. Two doors into the same model call, so a limit only one
  // of them enforces is not a limit.
  const contextProblem = contextError(context);
  if (contextProblem) {
    throw new GatewayError(contextProblem, 400);
  }
  const providerResponse = await fetch(
    "https://api.groq.com/openai/v1/chat/completions",
    {
      method: "POST",
      headers: {
        Authorization: `Bearer ${apiKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        model,
        temperature: 0,
        include_reasoning: false,
        response_format: {
          type: "json_schema",
          json_schema: {
            name: "trip_ai_command",
            strict: true,
            schema: commandSchema,
          },
        },
        messages: [
          { role: "system", content: systemInstruction },
          {
            role: "user",
            content: JSON.stringify({ instruction: instruction.trim(), context }),
          },
        ],
      }),
    },
  );
  if (!providerResponse.ok) {
    const providerError = await providerResponse.text();
    // Groq rejects its own generation when it misses a schema detail, but it
    // hands the generated JSON back in the error. That output is usually
    // correct in every way we care about, so salvage it rather than failing
    // the user's message: validateCommand still has the final say.
    const salvaged = salvageFailedGeneration(providerError);
    if (salvaged) {
      console.warn("Recovered a Groq generation that failed schema validation");
      return validateCommand(
        recoverExplicitArguments(salvaged, instruction),
        context.destinationId,
      );
    }
    console.error("Groq request failed", providerResponse.status, providerError);
    throw new GatewayError(
      `Groq request failed (${providerResponse.status})`,
      providerResponse.status === 429 ? 429 : 502,
    );
  }
  const result = await providerResponse.json();
  const content = result.choices?.[0]?.message?.content;
  if (!content) throw new Error("Groq returned no command");
  const parsed = recoverExplicitArguments(JSON.parse(content), instruction);
  return validateCommand(parsed, context.destinationId);
}

/// Development-only verdict cache.
///
/// Production caches in Firestore so a place is judged once for everybody.
/// Here a process-lifetime Map is enough, and it keeps local iteration from
/// spending tokens on the same shophouse over and over.
const localVerdictCache = new Map();

export function clearLocalVerdictCache() {
  localVerdictCache.clear();
}

export async function vetWithGroq({ places, apiKey }) {
  if (!apiKey) throw new GatewayError("GROQ_API_KEY is not configured", 503);
  const candidates = normalizeCandidates(places);

  const verdicts = {};
  const unjudged = [];
  for (const candidate of candidates) {
    if (localVerdictCache.has(candidate.placeId)) {
      verdicts[candidate.placeId] = localVerdictCache.get(candidate.placeId);
    } else {
      unjudged.push(candidate);
    }
  }
  if (unjudged.length === 0) return { verdicts };

  const providerResponse = await fetch(
    "https://api.groq.com/openai/v1/chat/completions",
    {
      method: "POST",
      headers: {
        Authorization: `Bearer ${apiKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        model,
        temperature: 0,
        include_reasoning: false,
        response_format: {
          type: "json_schema",
          json_schema: {
            name: "shopping_place_verdicts",
            strict: true,
            schema: verdictSchema,
          },
        },
        messages: [
          { role: "system", content: vettingInstruction },
          { role: "user", content: providerInput(unjudged) },
        ],
      }),
    },
  );
  if (!providerResponse.ok) {
    const providerError = await providerResponse.text();
    console.error(
      "Groq vetting failed",
      providerResponse.status,
      providerError,
    );
    // Fail open, exactly as production does.
    return { verdicts };
  }
  const result = await providerResponse.json();
  const content = result.choices?.[0]?.message?.content;
  if (!content) return { verdicts };

  const judged = validateVerdicts(JSON.parse(content), unjudged);
  for (const [placeId, verdict] of Object.entries(judged)) {
    localVerdictCache.set(placeId, verdict.isShoppingDestination);
    verdicts[placeId] = verdict.isShoppingDestination;
  }
  return { verdicts };
}

export function createLocalServer(
  apiKey = groqApiKey,
  interpreter = interpretWithGroq,
  vetter = vetWithGroq,
) {
  return http.createServer(async (request, response) => {
    if (request.method === "OPTIONS") {
      send(response, 204, {});
      return;
    }
    if (request.method === "GET" && request.url === "/health") {
      send(response, 200, {
        status: "ok",
        provider: "groq",
        model,
        configured: Boolean(apiKey),
      });
      return;
    }
    if (request.method === "POST" && request.url === "/vetShoppingPlaces") {
      try {
        const body = await readJson(request);
        send(response, 200, await vetter({ places: body.places, apiKey }));
      } catch (error) {
        console.error(error instanceof Error ? error.message : error);
        send(response, error instanceof GatewayError ? error.status : 400, {
          error: "Unable to vet places",
          detail: error instanceof Error ? error.message : "Unknown error",
        });
      }
      return;
    }
    if (request.method !== "POST" || request.url !== "/interpretTripRequest") {
      send(response, 404, { error: "Not found" });
      return;
    }
    try {
      const body = await readJson(request);
      const command = await interpreter({
        instruction: body.instruction,
        context: body.context,
        apiKey,
      });
      send(response, 200, command);
    } catch (error) {
      console.error(error instanceof Error ? error.message : error);
      send(response, error instanceof GatewayError ? error.status : 400, {
        error: "Unable to interpret request",
        detail: error instanceof Error ? error.message : "Unknown error",
      });
    }
  });
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  if (!groqApiKey) {
    console.error("Set GROQ_API_KEY before starting the local AI gateway.");
    process.exit(1);
  }
  createLocalServer().listen(port, host, () => {
    console.log(`Travel AI gateway listening on http://${host}:${port}`);
  });
}
