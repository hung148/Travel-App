import { readFile } from "node:fs/promises";

import { interpretWithGroq } from "../local-server.js";

const apiKey = process.env.GROQ_API_KEY;
const gatewayUrl = process.env.AI_ASSISTANT_URL;
if (!apiKey && !gatewayUrl) {
  console.error("Set GROQ_API_KEY or AI_ASSISTANT_URL before running AI evaluations.");
  process.exit(1);
}

const cases = JSON.parse(
  await readFile(new URL("./cases.json", import.meta.url), "utf8"),
);
const delayMs = Number.parseInt(process.env.AI_EVAL_DELAY_MS || "2100", 10);
const context = {
  destinationId: "eval-hue",
  destination: "Hue, Vietnam",
  budget: 1200,
  plannerStyle: "Balanced",
  history: [],
  days: [
    {
      dayNumber: 1,
      places: ["Imperial City", "Dong Ba Market", "Rustic Tea & Coffee"],
      stops: [
        { number: 1, name: "Rustic Tea & Coffee", role: "breakfast", startMinutes: 480, category: "coffee shop" },
        { number: 2, name: "Imperial City", role: "activity", startMinutes: 600, category: "tourist attraction" },
        { number: 3, name: "Dong Ba Market", role: "activity", startMinutes: 780, category: "market" },
      ],
    },
    {
      dayNumber: 2,
      places: ["Thien Mu Pagoda", "Museum", "Walking Street", "KDL Sinh thai Nam O"],
      stops: [
        { number: 1, name: "Thien Mu Pagoda", role: "activity", startMinutes: 540, category: "tourist attraction" },
        { number: 2, name: "Museum", role: "activity", startMinutes: 720, category: "museum" },
        { number: 3, name: "Walking Street", role: "activity", startMinutes: 900, category: "tourist attraction" },
        { number: 4, name: "KDL Sinh thai Nam O", role: "activity", startMinutes: 1080, category: "park" },
      ],
    },
  ],
};

let passed = 0;
async function interpret(instruction) {
  if (gatewayUrl) {
    const response = await fetch(gatewayUrl, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ instruction, context }),
    });
    if (!response.ok) {
      const detail = await response.text();
      throw new Error(`Gateway failed (${response.status}): ${detail}`);
    }
    return response.json();
  }
  return interpretWithGroq({ instruction, context, apiKey });
}

for (const [index, evaluation] of cases.entries()) {
  try {
    const command = await interpret(evaluation.instruction);
    const matches =
      command.command === evaluation.expectedCommand &&
      (evaluation.expectedDayNumber === undefined ||
        command.arguments.dayNumber === evaluation.expectedDayNumber) &&
      (evaluation.expectedBudget === undefined ||
        command.arguments.budget === evaluation.expectedBudget) &&
      (evaluation.expectedStyle === undefined ||
        command.arguments.style === evaluation.expectedStyle) &&
      (evaluation.expectedActivityName === undefined ||
        command.arguments.activityName === evaluation.expectedActivityName) &&
      (evaluation.expectedTargetDayNumber === undefined ||
        command.arguments.targetDayNumber === evaluation.expectedTargetDayNumber) &&
      (evaluation.expectedReplacementPreference === undefined ||
        command.arguments.replacementPreference === evaluation.expectedReplacementPreference) &&
      (evaluation.expectedMealType === undefined ||
        command.arguments.mealType === evaluation.expectedMealType) &&
      (evaluation.expectedActivityNumbers === undefined ||
        JSON.stringify(command.arguments.activityNumbers) ===
          JSON.stringify(evaluation.expectedActivityNumbers)) &&
      (evaluation.expectedReplacementCriterion === undefined ||
        command.arguments.replacementCriterion ===
          evaluation.expectedReplacementCriterion) &&
      (evaluation.expectedStopCount === undefined ||
        command.arguments.stopCount === evaluation.expectedStopCount) &&
      (evaluation.expectedStartMinutes === undefined ||
        command.arguments.startMinutes === evaluation.expectedStartMinutes);
    if (matches) passed += 1;
    console.log(
      `${matches ? "PASS" : "FAIL"} ${evaluation.name}: ${command.command}`,
    );
  } catch (error) {
    console.log(`ERROR ${evaluation.name}: ${error.message}`);
  }
  if (index !== cases.length - 1) {
    await new Promise((resolve) => setTimeout(resolve, delayMs));
  }
}

const score = passed / cases.length;
console.log(
  `\nAI command accuracy: ${passed}/${cases.length} (${(score * 100).toFixed(1)}%)`,
);
if (score < 0.8) process.exitCode = 1;
