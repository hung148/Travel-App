import test from "node:test";
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";

import { allowedCommands, supportedStyles } from "../trip-command.js";

test("AI evaluation cases use supported expected values", async () => {
  const cases = JSON.parse(
    await readFile(new URL("../evals/cases.json", import.meta.url), "utf8"),
  );
  assert.ok(cases.length >= 10);
  for (const evaluation of cases) {
    assert.ok(evaluation.name);
    assert.ok(evaluation.instruction);
    assert.ok(allowedCommands.includes(evaluation.expectedCommand));
    if (evaluation.expectedStyle !== undefined) {
      assert.ok(supportedStyles.includes(evaluation.expectedStyle));
    }
  }
});
