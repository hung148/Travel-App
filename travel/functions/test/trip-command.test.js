import test from "node:test";
import assert from "node:assert/strict";

import {
  commandSchema,
  recoverExplicitArguments,
  systemInstruction,
  validateCommand,
} from "../trip-command.js";

test("accepts and normalizes a destination-scoped command", () => {
  const command = validateCommand(
    {
      command: "relax_day",
      destinationId: "hue",
      arguments: { dayNumber: 2, budget: null, style: null },
      explanation: "  Relax day 2.  ",
    },
    "hue",
  );

  assert.equal(command.command, "relax_day");
  assert.equal(command.arguments.dayNumber, 2);
  assert.equal(command.explanation, "Relax day 2.");
});

test("rejects a command targeting another destination", () => {
  assert.throws(
    () =>
      validateCommand(
        {
          command: "add_food",
          destinationId: "danang",
          arguments: { dayNumber: null, budget: null, style: null },
          explanation: "Add a food stop.",
        },
        "hue",
      ),
    /Destination scope mismatch/,
  );
});

test("rejects invalid command arguments", () => {
  assert.throws(
    () =>
      validateCommand(
        {
          command: "change_budget",
          destinationId: "hue",
          arguments: { dayNumber: null, budget: -5, style: null },
          explanation: "Change the budget.",
        },
        "hue",
      ),
    /Invalid budget/,
  );
});

test("removes irrelevant arguments from a command", () => {
  const command = validateCommand(
    {
      command: "remove_museums",
      destinationId: "hue",
      arguments: { dayNumber: 2, budget: 500, style: "Explorer" },
      explanation: "Remove museums.",
    },
    "hue",
  );

  assert.deepEqual(command.arguments, {
    dayNumber: null,
    budget: null,
    style: null,
    activityName: null,
    targetDayNumber: null,
    replacementPreference: null,
    mealType: null,
    activityNumbers: [],
    replacementCriterion: null,
    sourceStop: null,
    targetStop: null,
    startMinutes: null,
    relativePosition: null,
    stopCount: null,
    stopCategory: null,
  });
});

test("normalizes exact stop counts and day start times", () => {
  const add = validateCommand(
    {
      command: "add_stops",
      destinationId: "hue",
      arguments: { dayNumber: 2, stopCount: 3, stopCategory: "park" },
      explanation: "Add three parks to day 2.",
    },
    "hue",
  );
  const start = validateCommand(
    {
      command: "set_day_start_time",
      destinationId: "hue",
      arguments: { dayNumber: 1, startMinutes: 540 },
      explanation: "Start day 1 at 9 AM.",
    },
    "hue",
  );
  assert.equal(add.arguments.stopCount, 3);
  assert.equal(add.arguments.stopCategory, "park");
  assert.equal(start.arguments.startMinutes, 540);
});

test("normalizes a smart numbered replacement", () => {
  const command = validateCommand(
    {
      command: "replace_stop",
      destinationId: "hue",
      arguments: {
        dayNumber: 2,
        budget: null,
        style: null,
        activityName: null,
        targetDayNumber: null,
        replacementPreference: "park",
        mealType: null,
        activityNumbers: [3],
        replacementCriterion: "closer",
      },
      explanation: "Replace activity 3 with a closer park.",
    },
    "hue",
  );
  assert.equal(command.arguments.dayNumber, 2);
  assert.deepEqual(command.arguments.activityNumbers, [3]);
  assert.equal(command.arguments.replacementPreference, "park");
  assert.equal(command.arguments.replacementCriterion, "closer");
});

test("normalizes a cross-day swap with two stop references", () => {
  const command = validateCommand(
    {
      command: "swap_stops",
      destinationId: "hue",
      arguments: {
        sourceStop: { dayNumber: 1, activityNumber: 3, activityName: null, mealType: null },
        targetStop: { dayNumber: 2, activityNumber: null, activityName: null, mealType: "lunch" },
      },
      explanation: "Swap activity 3 on day 1 with lunch on day 2.",
    },
    "hue",
  );
  assert.equal(command.arguments.sourceStop.activityNumber, 3);
  assert.equal(command.arguments.targetStop.mealType, "lunch");
});

test("normalizes a move to a specific time", () => {
  const command = validateCommand(
    {
      command: "move_stop_time",
      destinationId: "hue",
      arguments: {
        targetDayNumber: 3,
        startMinutes: 840,
        sourceStop: { dayNumber: 1, activityNumber: null, activityName: "Imperial City", mealType: null },
      },
      explanation: "Move Imperial City to 2 PM on day 3.",
    },
    "hue",
  );
  assert.equal(command.arguments.targetDayNumber, 3);
  assert.equal(command.arguments.startMinutes, 840);
});

test("keeps numbered stop removals scoped to a day", () => {
  const command = validateCommand(
    {
      command: "remove_stop",
      destinationId: "hue",
      arguments: {
        dayNumber: 1,
        budget: null,
        style: null,
        activityName: null,
        targetDayNumber: null,
        replacementPreference: null,
        mealType: null,
        activityNumbers: [3, 4],
      },
      explanation: "Remove activities 3 and 4 from day 1.",
    },
    "hue",
  );
  assert.deepEqual(command.arguments.activityNumbers, [3, 4]);
  assert.equal(command.arguments.dayNumber, 1);
});

test("keeps a targeted meal on only the requested day", () => {
  const command = validateCommand(
    {
      command: "add_food",
      destinationId: "hue",
      arguments: {
        dayNumber: 1,
        budget: null,
        style: null,
        activityName: null,
        targetDayNumber: null,
        replacementPreference: null,
        mealType: "breakfast",
      },
      explanation: "Add breakfast to day 1.",
    },
    "hue",
  );
  assert.equal(command.arguments.dayNumber, 1);
  assert.equal(command.arguments.mealType, "breakfast");
});

test("requires a named activity and target day for move_stop", () => {
  const command = validateCommand(
    {
      command: "move_stop",
      destinationId: "hue",
      arguments: {
        dayNumber: null,
        budget: null,
        style: null,
        activityName: "Imperial City",
        targetDayNumber: 2,
        replacementPreference: null,
      },
      explanation: "Move Imperial City to day 2.",
    },
    "hue",
  );
  assert.equal(command.arguments.activityName, "Imperial City");
  assert.equal(command.arguments.targetDayNumber, 2);
});

test("recovers a partial stop name omitted by the model", () => {
  const raw = {
    command: "move_stop",
    destinationId: "hue",
    arguments: {
      dayNumber: null,
      budget: null,
      style: null,
      activityName: null,
      targetDayNumber: null,
      replacementPreference: null,
    },
    explanation: "Move the requested stop.",
  };

  const recovered = recoverExplicitArguments(raw, "Move KDL to day 1");

  assert.equal(recovered.arguments.activityName, "KDL");
  assert.equal(recovered.arguments.targetDayNumber, 1);
  assert.equal(validateCommand(recovered, "hue").command, "move_stop");
});

test("keeps the reply message on a conversational answer", () => {
  const command = validateCommand(
    {
      command: "answer",
      destinationId: "hue",
      arguments: {},
      explanation: "Answered a packing question.",
      message: "  Pack light layers and a rain shell for November.  ",
    },
    "hue",
  );

  assert.equal(command.command, "answer");
  assert.equal(
    command.message,
    "Pack light layers and a rain shell for November.",
  );
  assert.equal(command.arguments.dayNumber, null);
});

test("asks a question back with clarify", () => {
  const command = validateCommand(
    {
      command: "clarify",
      destinationId: "hue",
      arguments: {},
      explanation: "Need the start time.",
      message: "What time should the day start?",
    },
    "hue",
  );

  assert.equal(command.command, "clarify");
  assert.equal(command.message, "What time should the day start?");
});

test("promotes explanation when a reply command omits message", () => {
  const command = validateCommand(
    {
      command: "explain",
      destinationId: "hue",
      arguments: {},
      explanation: "Built from your budget, style and route proximity.",
      message: null,
    },
    "hue",
  );

  assert.equal(
    command.message,
    "Built from your budget, style and route proximity.",
  );
});

test("drops any reply message from an edit command", () => {
  const command = validateCommand(
    {
      command: "relax_day",
      destinationId: "hue",
      arguments: { dayNumber: 2 },
      explanation: "Relax day 2.",
      message: "chatty text that does not belong on an edit",
    },
    "hue",
  );

  assert.equal(command.message, null);
});

test("accepts sparse arguments from a model that omits unused fields", () => {
  // Reproduces the Groq 400: gpt-oss-20b emitted every argument except
  // targetDayNumber on a clarify.
  const command = validateCommand(
    {
      command: "clarify",
      destinationId: "hue",
      arguments: {
        activityName: null,
        activityNumbers: [],
        budget: null,
        dayNumber: null,
        mealType: null,
        relativePosition: null,
        replacementCriterion: null,
        replacementPreference: null,
        sourceStop: null,
        targetStop: null,
        startMinutes: null,
        stopCount: null,
        stopCategory: null,
        style: null,
      },
      explanation: "Which day would you like to shift later?",
      message: "Which day would you like to shift later?",
    },
    "hue",
  );

  assert.equal(command.command, "clarify");
  assert.equal(command.arguments.targetDayNumber, null);
});

test("accepts a reply command with no arguments object at all", () => {
  const command = validateCommand(
    {
      command: "answer",
      destinationId: "hue",
      explanation: "Answered a weather question.",
      message: "November in Hue is the wettest month.",
    },
    "hue",
  );

  assert.equal(command.command, "answer");
  assert.deepEqual(command.arguments.activityNumbers, []);
});

test("still requires arguments on an edit command", () => {
  assert.throws(
    () =>
      validateCommand(
        { command: "relax_day", destinationId: "hue", explanation: "Relax." },
        "hue",
      ),
    /arguments are missing/,
  );
});

test("the schema still lists every argument key as required", () => {
  // Both providers reject a schema whose `required` omits any property, so this
  // list cannot be relaxed - the prompt checklist is what keeps the model honest.
  assert.ok(commandSchema.required.includes("message"));
  assert.equal(commandSchema.properties.arguments.required.length, 15);
  assert.deepEqual(
    commandSchema.properties.arguments.properties.sourceStop.required,
    ["dayNumber", "activityNumber", "activityName", "mealType"],
  );
});

test("the prompt names every argument key the schema requires", () => {
  for (const key of commandSchema.properties.arguments.required) {
    assert.ok(
      systemInstruction.includes(key),
      `system prompt never mentions the required argument ${key}`,
    );
  }
  assert.ok(systemInstruction.includes("ARGUMENT CHECKLIST"));
});
