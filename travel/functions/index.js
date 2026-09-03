import { getApps, initializeApp } from "firebase-admin/app";
import { getAuth } from "firebase-admin/auth";
import { onRequest } from "firebase-functions/v2/https";
import { defineSecret } from "firebase-functions/params";
import {
  commandSchema,
  systemInstruction,
  validateCommand,
} from "./trip-command.js";

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
