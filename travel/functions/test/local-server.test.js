import test from "node:test";
import assert from "node:assert/strict";

import { createLocalServer, interpretWithGroq } from "../local-server.js";

test("converts a Groq JSON response into a validated command", async (context) => {
  const originalFetch = globalThis.fetch;
  context.after(() => {
    globalThis.fetch = originalFetch;
  });
  globalThis.fetch = async () =>
    new Response(
      JSON.stringify({
        choices: [
          {
            message: {
              content: JSON.stringify({
                command: "relax_day",
                destinationId: "hue",
                arguments: { dayNumber: 2, budget: null, style: null },
                explanation: "Simplify day 2.",
              }),
            },
          },
        ],
      }),
      { status: 200 },
    );

  const command = await interpretWithGroq({
    instruction: "Day 2 is too busy",
    context: { destinationId: "hue" },
    apiKey: "test-key",
  });

  assert.equal(command.command, "relax_day");
  assert.equal(command.destinationId, "hue");
});

test("serves health and a validated command over HTTP", async (context) => {
  const server = createLocalServer("test-key", async ({ context }) => ({
    command: "add_food",
    destinationId: context.destinationId,
    arguments: { dayNumber: null, budget: null, style: null },
    explanation: "Add available food stops.",
  }));
  await new Promise((resolve) => server.listen(0, "127.0.0.1", resolve));
  context.after(() => server.close());
  const address = server.address();
  const baseUrl = `http://127.0.0.1:${address.port}`;

  const healthResponse = await fetch(`${baseUrl}/health`);
  assert.equal(healthResponse.status, 200);
  assert.equal((await healthResponse.json()).configured, true);

  const commandResponse = await fetch(`${baseUrl}/interpretTripRequest`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      instruction: "Add more food",
      context: { destinationId: "hue" },
    }),
  });
  assert.equal(commandResponse.status, 200);
  assert.equal((await commandResponse.json()).destinationId, "hue");
});
