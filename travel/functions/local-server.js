import http from "node:http";
import { fileURLToPath } from "node:url";

import {
  commandSchema,
  recoverExplicitArguments,
  systemInstruction,
  validateCommand,
} from "./trip-command.js";

const host = "127.0.0.1";
const port = Number.parseInt(process.env.AI_GATEWAY_PORT || "8787", 10);
const groqApiKey = process.env.GROQ_API_KEY;
const model = process.env.GROQ_MODEL || "openai/gpt-oss-20b";
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

export async function interpretWithGroq({ instruction, context, apiKey }) {
  if (!apiKey) throw new GatewayError("GROQ_API_KEY is not configured", 503);
  if (typeof instruction !== "string" || instruction.trim().length === 0) {
    throw new GatewayError("Instruction is required", 400);
  }
  if (instruction.length > 1000) {
    throw new GatewayError("Instruction is too long", 400);
  }
  if (!context || typeof context !== "object") {
    throw new GatewayError("Trip context is required", 400);
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

export function createLocalServer(
  apiKey = groqApiKey,
  interpreter = interpretWithGroq,
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
