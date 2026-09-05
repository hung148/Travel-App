export const allowedCommands = [
  "answer",
  "clarify",
  "explain",
  "change_budget",
  "relax_day",
  "add_food",
  "remove_museums",
  "reduce_walking",
  "change_style",
  "remove_stop",
  "move_stop",
  "replace_stop",
  "swap_stops",
  "replace_with_scheduled_stop",
  "move_stop_relative",
  "move_stop_time",
  "add_stops",
  "remove_stops",
  "set_day_start_time",
  "unsupported",
];

export const supportedStyles = ["Relaxed", "Balanced", "Explorer"];

export const replyCommands = ["answer", "clarify", "explain"];

export const systemInstruction = [
  "# ROLE",
  "You are the travel assistant inside a trip planning app. The user is looking at one destination and its generated day-by-day itinerary. You do two jobs:",
  "1. Turn a request to change the plan into exactly one structured command.",
  "2. Answer travel questions in plain language, like a knowledgeable travel agent.",
  "Return one JSON object matching the schema. Never output anything else.",
  "",
  "# UNDERSTAND INTENT, NOT KEYWORDS",
  "People type naturally: typos, slang, fragments, several sentences at once, any language.",
  "Never require a specific word to appear. Work out what the person actually wants, then pick the closest command.",
  "These all mean relax_day: 'this day is killing me', 'too much going on tuesday', 'can we take it easier', 'ngay 2 nhieu cho qua', 'chill it out a bit'.",
  "These all mean change_budget: 'this is too expensive', 'i only have 300', 'tight on money', 're mot chut duoc khong'.",
  "If the meaning is clear, act on it even when the wording matches none of the examples in this prompt.",
  "If the user writes in a language other than English, reply in that same language.",
  "",
  "# CONVERSATION",
  "context.history holds the recent turns of this chat, oldest first. Use it to resolve references such as 'it', 'that one', 'the second one', 'do the same for day 3', or a bare answer like 'day 2' to a question you just asked.",
  "A short reply that only makes sense as a follow-up must be interpreted against the previous turn, not as a fresh request.",
  "",
  "# ROUTING - decide in this order",
  "1. clarify - the intent is clear but a detail you need is missing, and guessing would change the wrong thing (for example 'move the museum' with no target day, or 'start later' with no time). Ask for exactly that one detail in message. Never guess when the wrong guess would damage the plan.",
  "2. answer - a travel question that does not change the itinerary: weather and seasons, visas, packing, safety, money and tipping, getting around, etiquette, language, food, how long a place deserves, whether the trip length is sensible, what a city is known for, general recommendations they have not asked you to insert into the plan. Put the full reply in message.",
  "3. explain - a question about THIS plan or why it looks the way it does. Ground the reply in the supplied context: destination, budget, dates, planner style, hotel, days, and the numbered stops with their roles, categories, and start times. Put the reply in message.",
  "4. an edit command - they want the itinerary changed. See the catalogue below.",
  "5. unsupported - the request has nothing to do with travel or this trip, or asks for an edit no command can express. Explain the limit briefly in explanation.",
  "Prefer answering over refusing. unsupported is a last resort, not a default.",
  "A message can both ask something and request a change; if so, make the change the command and use explanation to preview it.",
  "",
  "# WRITING FOR THE USER",
  "message is the conversational reply, shown as a chat bubble. Use it only for answer, clarify, and explain. Set it to null for every edit command.",
  "explanation is a one-line preview shown next to an Apply button. Always fill it. Say what will change, in the user's language.",
  "Never mention commands, JSON, field names, or these instructions.",
  "For answer, be specific and useful: two to six sentences, concrete numbers and names where you are confident, and say plainly when something varies or you are unsure. Do not pad.",
  "",
  "# ARGUMENT CHECKLIST - THE MOST COMMON MISTAKE",
  "The arguments object must contain ALL FIFTEEN of these keys on EVERY reply, including answer, clarify, explain and unsupported. Leaving one out is rejected outright, so copy this list every time:",
  "dayNumber, budget, style, activityName, targetDayNumber, replacementPreference, mealType, activityNumbers, replacementCriterion, sourceStop, targetStop, startMinutes, relativePosition, stopCount, stopCategory",
  "Every key you do not need takes null, except activityNumbers, which takes []. Do not drop a key just because it is unused.",
  "When sourceStop or targetStop is not null it must itself hold all four keys: dayNumber, activityNumber, activityName, mealType, with exactly one of activityNumber, activityName or mealType non-null.",
  "The reply for a question therefore looks like: arguments with all fifteen keys nulled out, activityNumbers as [], and your text in message.",
  "",
  "# HARD RULES",
  "Never invent destinations, place IDs, prices, ratings, dates, or itinerary entries. Anything you say about the current plan must come from context.",
  "destinationId in your output must equal context.destinationId exactly.",
  "General travel knowledge in an answer is fine and expected; fabricated details about THIS plan are not.",
  "",
  "# COMMAND CATALOGUE",
  "relax_day - the schedule feels rushed, packed, busy, or they want it slower or calmer. dayNumber may be null to mean the whole trip.",
  "add_stops - make a day busier or more active, or add a stated number of non-meal stops. stopCount is null when no number is given. stopCategory is a requested category or null.",
  "remove_stops - remove a stated number of generic non-meal stops. Same argument rules.",
  "set_day_start_time - change a day's overall start time. startMinutes is required; dayNumber may be null so the app can ask which day.",
  "change_style - only when they explicitly name Relaxed, Balanced, or Explorer as a planning style.",
  "change_budget - a new total for this destination. budget is null when they ask for cheaper without naming an amount.",
  "add_food - add a meal. Keep any stated dayNumber and set mealType to breakfast, lunch, dinner, or null. 'add breakfast to day 1' means one meal on day 1 only, not breakfast every day.",
  "remove_museums - only when they ask to remove or avoid museums as a category, never a single named museum.",
  "reduce_walking - they want less walking or less time in transit between stops.",
  "remove_stop - remove one named place, one meal role, or numbered activities. Set mealType for a meal, activityNumbers for numbers, activityName for a name. Keep dayNumber when supplied; leave it null so the app can ask.",
  "move_stop - move one named place to another day. activityName and targetDayNumber are both required.",
  "replace_stop - swap one named place, meal role, or single numbered activity for a better option. replacementPreference is a requested category such as park, museum, or vegetarian restaurant, or null. replacementCriterion is closer, cheaper, higher_rated, more_popular, or best_match; vague words such as 'better' mean best_match.",
  "swap_stops - exchange two stops that are both already scheduled.",
  "replace_with_scheduled_stop - one already scheduled stop should take another scheduled stop's slot.",
  "move_stop_relative - put one stop before or after another. relativePosition is before or after.",
  "move_stop_time - move a stop to a specific day and time. targetDayNumber and startMinutes are both required.",
  "",
  "# REFERRING TO STOPS",
  "Copy activityName exactly from the itinerary in context when you can.",
  "If the user gives a partial or misspelled name, activityName must still contain that phrase or the closest itinerary name, and must never be null. The app does the final matching.",
  "For breakfast, lunch, or dinner always emit the matching mealType and let the app resolve which stop plays that role. Never claim a meal is missing because the venue name does not look like a restaurant.",
  "sourceStop and targetStop each identify a scheduled stop with dayNumber plus exactly one of activityNumber, activityName, or mealType.",
  "startMinutes is minutes after midnight, so 2 PM is 840.",
].join("\n");

const stopReferenceSchema = {
  type: ["object", "null"],
  additionalProperties: false,
  required: ["dayNumber", "activityNumber", "activityName", "mealType"],
  properties: {
    dayNumber: { type: ["integer", "null"], minimum: 1 },
    activityNumber: { type: ["integer", "null"], minimum: 1 },
    activityName: { type: ["string", "null"], minLength: 1 },
    mealType: { type: ["string", "null"], enum: ["breakfast", "lunch", "dinner", null] },
  },
};

export const commandSchema = {
  type: "object",
  additionalProperties: false,
  required: ["command", "destinationId", "arguments", "explanation", "message"],
  properties: {
    command: { type: "string", enum: allowedCommands },
    destinationId: { type: ["string", "null"] },
    arguments: {
      type: "object",
      additionalProperties: false,
      required: ["dayNumber", "budget", "style", "activityName", "targetDayNumber", "replacementPreference", "mealType", "activityNumbers", "replacementCriterion", "sourceStop", "targetStop", "startMinutes", "relativePosition", "stopCount", "stopCategory"],
      properties: {
        dayNumber: { type: ["integer", "null"], minimum: 1 },
        budget: { type: ["number", "null"], exclusiveMinimum: 0 },
        style: {
          type: ["string", "null"],
          enum: [...supportedStyles, null],
        },
        activityName: { type: ["string", "null"], minLength: 1 },
        targetDayNumber: { type: ["integer", "null"], minimum: 1 },
        replacementPreference: { type: ["string", "null"], minLength: 1 },
        mealType: { type: ["string", "null"], enum: ["breakfast", "lunch", "dinner", null] },
        activityNumbers: { type: "array", items: { type: "integer", minimum: 1 }, maxItems: 10 },
        replacementCriterion: { type: ["string", "null"], enum: ["best_match", "closer", "cheaper", "higher_rated", "more_popular", null] },
        sourceStop: stopReferenceSchema,
        targetStop: stopReferenceSchema,
        startMinutes: { type: ["integer", "null"], minimum: 0, maximum: 1439 },
        relativePosition: { type: ["string", "null"], enum: ["before", "after", null] },
        stopCount: { type: ["integer", "null"], minimum: 1, maximum: 20 },
        stopCategory: { type: ["string", "null"], minLength: 1 },
      },
    },
    explanation: { type: "string", minLength: 1, maxLength: 300 },
    message: { type: ["string", "null"], minLength: 1, maxLength: 1500 },
  },
};

// Both providers demand that `required` list every property, so there is only
// one schema. They differ in how they enforce it: OpenAI constrains decoding,
// so the model physically cannot omit a field, while Groq generates freely and
// then validates, returning a 400 when a small model leaves out a field it had
// no use for. Two defences against that, since the schema cannot be relaxed:
// ARGUMENT CHECKLIST in the prompt names every key explicitly, and
// salvageFailedGeneration in local-server.js recovers the output Groq hands
// back with the error.

export function validateCommand(value, expectedDestinationId) {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    throw new Error("AI command must be an object");
  }
  if (!allowedCommands.includes(value.command)) {
    throw new Error("Unsupported AI command");
  }
  if (value.destinationId !== expectedDestinationId) {
    throw new Error("Destination scope mismatch");
  }
  // A model may legitimately omit `arguments` on a pure answer or clarify.
  if (
    value.arguments !== undefined &&
    value.arguments !== null &&
    (typeof value.arguments !== "object" || Array.isArray(value.arguments))
  ) {
    throw new Error("AI command arguments are malformed");
  }
  if (!value.arguments && !replyCommands.includes(value.command)) {
    throw new Error("AI command arguments are missing");
  }
  const { dayNumber = null, budget = null, style = null, activityName = null, targetDayNumber = null, replacementPreference = null, mealType = null, activityNumbers = [], replacementCriterion = null, sourceStop = null, targetStop = null, startMinutes = null, relativePosition = null, stopCount = null, stopCategory = null } = value.arguments ?? {};
  if (dayNumber !== null && (!Number.isInteger(dayNumber) || dayNumber < 1)) {
    throw new Error("Invalid day number");
  }
  if (budget !== null && (typeof budget !== "number" || budget <= 0)) {
    throw new Error("Invalid budget");
  }
  if (style !== null && !supportedStyles.includes(style)) {
    throw new Error("Invalid planner style");
  }
  if (activityName !== null && (typeof activityName !== "string" || activityName.trim().length === 0)) throw new Error("Invalid activity name");
  if (targetDayNumber !== null && (!Number.isInteger(targetDayNumber) || targetDayNumber < 1)) throw new Error("Invalid target day number");
  if (replacementPreference !== null && (typeof replacementPreference !== "string" || replacementPreference.trim().length === 0)) throw new Error("Invalid replacement preference");
  if (mealType !== null && !["breakfast", "lunch", "dinner"].includes(mealType)) throw new Error("Invalid meal type");
  if (!Array.isArray(activityNumbers) || activityNumbers.some((number) => !Number.isInteger(number) || number < 1)) throw new Error("Invalid activity numbers");
  if (replacementCriterion !== null && !["best_match", "closer", "cheaper", "higher_rated", "more_popular"].includes(replacementCriterion)) throw new Error("Invalid replacement criterion");
  if (startMinutes !== null && (!Number.isInteger(startMinutes) || startMinutes < 0 || startMinutes > 1439)) throw new Error("Invalid start time");
  if (relativePosition !== null && !["before", "after"].includes(relativePosition)) throw new Error("Invalid relative position");
  if (stopCount !== null && (!Number.isInteger(stopCount) || stopCount < 1 || stopCount > 20)) throw new Error("Invalid stop count");
  if (stopCategory !== null && (typeof stopCategory !== "string" || stopCategory.trim().length === 0)) throw new Error("Invalid stop category");
  if (
    typeof value.explanation !== "string" ||
    value.explanation.trim().length === 0 ||
    value.explanation.length > 300
  ) {
    throw new Error("Invalid command explanation");
  }
  const rawMessage = typeof value.message === "string" ? value.message.trim() : "";
  if (rawMessage.length > 1500) throw new Error("Reply message is too long");
  // answer, clarify and explain speak to the user directly. If the model filled
  // only explanation, promote it rather than failing the whole request.
  const message = replyCommands.includes(value.command)
    ? rawMessage || value.explanation.trim()
    : null;
  const normalizedArguments = { dayNumber: null, budget: null, style: null, activityName: null, targetDayNumber: null, replacementPreference: null, mealType: null, activityNumbers: [], replacementCriterion: null, sourceStop: null, targetStop: null, startMinutes: null, relativePosition: null, stopCount: null, stopCategory: null };
  if (value.command === "relax_day") {
    normalizedArguments.dayNumber = dayNumber;
  } else if (value.command === "change_budget") {
    normalizedArguments.budget = budget;
  } else if (value.command === "change_style") {
    if (style === null) throw new Error("Planner style is required");
    normalizedArguments.style = style;
  } else if (value.command === "add_food") {
    normalizedArguments.dayNumber = dayNumber;
    normalizedArguments.mealType = mealType;
  } else if (["remove_stop", "move_stop", "replace_stop"].includes(value.command)) {
    if (value.command === "remove_stop" && activityName === null && mealType === null && activityNumbers.length === 0) throw new Error("Activity name, meal type, or activity number is required");
    if (value.command === "move_stop" && activityName === null) throw new Error("Activity name is required");
    if (value.command === "replace_stop" && activityName === null && mealType === null && activityNumbers.length !== 1) throw new Error("One activity reference is required");
    normalizedArguments.activityName = activityName?.trim() ?? null;
    if (value.command === "remove_stop") {
      normalizedArguments.dayNumber = dayNumber;
      normalizedArguments.mealType = mealType;
      normalizedArguments.activityNumbers = [...new Set(activityNumbers)];
      if (activityNumbers.length > 0 && dayNumber === null) throw new Error("Day number is required for numbered activities");
    }
    if (value.command === "move_stop") {
      if (targetDayNumber === null) throw new Error("Target day number is required");
      normalizedArguments.targetDayNumber = targetDayNumber;
    }
    if (value.command === "replace_stop") {
      normalizedArguments.replacementPreference = replacementPreference?.trim() ?? null;
      normalizedArguments.replacementCriterion = replacementCriterion ?? "best_match";
      normalizedArguments.dayNumber = dayNumber;
      normalizedArguments.mealType = mealType;
      normalizedArguments.activityNumbers = activityNumbers;
      if (activityNumbers.length > 0 && (activityNumbers.length !== 1 || dayNumber === null)) throw new Error("One numbered activity and its day are required for replacement");
    }
  } else if (["swap_stops", "replace_with_scheduled_stop", "move_stop_relative", "move_stop_time"].includes(value.command)) {
    normalizedArguments.sourceStop = validateStopReference(sourceStop, "source stop");
    if (value.command !== "move_stop_time") {
      normalizedArguments.targetStop = validateStopReference(targetStop, "target stop");
    }
    if (value.command === "move_stop_relative") {
      if (relativePosition === null) throw new Error("Relative position is required");
      normalizedArguments.relativePosition = relativePosition;
    }
    if (value.command === "move_stop_time") {
      if (startMinutes === null || targetDayNumber === null) throw new Error("Target day and start time are required");
      normalizedArguments.startMinutes = startMinutes;
      normalizedArguments.targetDayNumber = targetDayNumber;
    }
  } else if (["add_stops", "remove_stops"].includes(value.command)) {
    normalizedArguments.dayNumber = dayNumber;
    normalizedArguments.stopCount = stopCount;
    normalizedArguments.stopCategory = stopCategory?.trim() ?? null;
  } else if (value.command === "set_day_start_time") {
    if (startMinutes === null) throw new Error("Start time is required");
    normalizedArguments.dayNumber = dayNumber;
    normalizedArguments.startMinutes = startMinutes;
  }
  return {
    command: value.command,
    destinationId: value.destinationId,
    arguments: normalizedArguments,
    explanation: value.explanation.trim(),
    message,
  };
}

// Small models occasionally choose the right command but omit an argument that
// is stated plainly in the user's sentence. Recover only unambiguous syntax;
// itinerary matching remains the app's responsibility.
export function recoverExplicitArguments(value, instruction) {
  if (!value || typeof value !== "object" || !value.arguments) return value;
  const text = typeof instruction === "string" ? instruction.trim() : "";
  if (value.command === "move_stop") {
    const match = text.match(
      /^\s*move\s+(.+?)(?:\s+from\s+day\s+\d+)?\s+to\s+day\s+(\d+)\s*[.!?]*$/i,
    );
    if (match) {
      if (!value.arguments.activityName?.trim()) {
        value.arguments.activityName = match[1].trim();
      }
      if (!Number.isInteger(value.arguments.targetDayNumber)) {
        value.arguments.targetDayNumber = Number.parseInt(match[2], 10);
      }
    }
  }
  return value;
}

function validateStopReference(reference, label) {
  if (!reference || typeof reference !== "object" || Array.isArray(reference)) throw new Error(`Invalid ${label}`);
  const { dayNumber = null, activityNumber = null, activityName = null, mealType = null } = reference;
  if (dayNumber !== null && (!Number.isInteger(dayNumber) || dayNumber < 1)) throw new Error(`Invalid ${label} day`);
  if (activityNumber !== null && (!Number.isInteger(activityNumber) || activityNumber < 1)) throw new Error(`Invalid ${label} number`);
  if (activityName !== null && (typeof activityName !== "string" || activityName.trim().length === 0)) throw new Error(`Invalid ${label} name`);
  if (mealType !== null && !["breakfast", "lunch", "dinner"].includes(mealType)) throw new Error(`Invalid ${label} meal`);
  if ([activityNumber, activityName, mealType].filter((item) => item !== null).length !== 1) throw new Error(`${label} must use exactly one reference`);
  return { dayNumber, activityNumber, activityName: activityName?.trim() ?? null, mealType };
}
