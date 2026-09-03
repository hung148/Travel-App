export const allowedCommands = [
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

export const systemInstruction =
  "You interpret requests for a travel planner. Return exactly one supported command as JSON. " +
  "Never invent destinations, place IDs, prices, dates, or itinerary entries. " +
  "Use unsupported when the request cannot be represented safely. " +
  "Keep destinationId exactly equal to the provided destinationId. " +
  "The JSON must contain command, destinationId, arguments, and explanation. " +
  "arguments must contain every schema field, using null or an empty array when unused. " +
  "Use relax_day when the user says a day or schedule is rushed, packed, busy, easier, slower, calmer, or more relaxed; dayNumber may be null for the whole schedule. " +
  "Use add_stops for make busier, more active, pack the schedule, or add a requested number of non-meal stops. Use remove_stops for removing a requested number of generic non-meal stops. stopCount is null when no count is stated and stopCategory is a requested category or null. Use set_day_start_time when the user changes a day's overall start time; startMinutes is required and dayNumber may be null so the app can ask which day. " +
  "Use change_style only when the user explicitly names Relaxed, Balanced, or Explorer as a planning style. " +
  "Use change_budget with budget null when the user asks for cheaper or less expensive without naming an amount. " +
  "For add_food, preserve a requested dayNumber and set mealType to breakfast, lunch, dinner, or null. A request such as add breakfast to day 1 means exactly one meal on only day 1, not food on every day. " +
  "Use remove_museums only when the user explicitly asks to remove or avoid all museums, not a named stop. " +
  "For remove breakfast, lunch, or dinner, use remove_stop with mealType and preserve dayNumber when supplied; leave dayNumber null so the app can ask. For remove activity 3 from day 1, use remove_stop with dayNumber 1 and activityNumbers [3]. Preserve multiple requested activity numbers. " +
  "Use remove_stop to remove one named itinerary place, move_stop to move one named place to a target day, and replace_stop to replace one named place, meal role, or one numbered activity. Copy activityName exactly from the supplied itinerary when possible. If the user gives only a partial or misspelled stop name, activityName must contain that phrase or the closest itinerary name and must never be null; the app performs final matching. For breakfast, lunch, or dinner requests, always emit the matching mealType command and let the app resolve the role; never claim the meal is absent based only on its venue name. replacementPreference is a requested category such as park, museum, vegetarian restaurant, or null. For replace_stop set replacementCriterion to closer, cheaper, higher_rated, more_popular, or best_match; words like better with no specific meaning use best_match. " +
  "Use swap_stops for swapping two scheduled stops, replace_with_scheduled_stop when one scheduled stop should take another scheduled stop's place, move_stop_relative for before/after requests, and move_stop_time for a specific day and time. sourceStop and targetStop each identify a currently scheduled stop using dayNumber plus exactly one of activityNumber, activityName, or mealType. For move_stop_time, targetDayNumber is the destination day. startMinutes is minutes after midnight; for example 2 PM is 840.";

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
  required: ["command", "destinationId", "arguments", "explanation"],
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
  },
};

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
  if (!value.arguments || typeof value.arguments !== "object") {
    throw new Error("AI command arguments are missing");
  }
  const { dayNumber = null, budget = null, style = null, activityName = null, targetDayNumber = null, replacementPreference = null, mealType = null, activityNumbers = [], replacementCriterion = null, sourceStop = null, targetStop = null, startMinutes = null, relativePosition = null, stopCount = null, stopCategory = null } = value.arguments;
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
