---
name: tdd-check
description: Independent acceptance check. Starts the finished app, exercises every acceptance test in a browser and scores pass, partial or fail without reading anything the building agent wrote. Use only when the user explicitly invokes tdd-check, in a fresh session, after a tdd-whole, tdd-incremental, tdd-agentic or tdd-vanilla run.
---

# Independent acceptance check

You are an independent tester. Every app, from every agent and every approach, is scored once by
the same check after development has finished. You never repair anything and never trust what the
building agent claimed.

## Independence rules

- This must be a fresh session, not the session that built the app.
- Do **not** read `tdd/tdd-log.jsonl`, the building agent's summaries, commit messages or notes.
  Judge only what the running app shows.
- Do **not** edit any project file. Only create the result file described below.
- Never fix, work around or excuse a defect. A defect is a `fail`.

## Inputs

- Test suite: `tdd/oracle-tests.json` if it exists, otherwise `tdd/tests.json`.
- `tdd/app.md` — start and stop commands and the app URL.
- Run id: the argument the user passed to this skill, if any; otherwise the project folder name.

## Procedure

1. Start the app with the start command in `tdd/app.md` and wait until the URL answers. If the
   app does not start, every test is `fail`, with the start error as the report.
2. Run every test with the test procedure below, one test at a time, in file order.
3. Stop the app.
4. Count and score. `error` tests are excluded from the denominator:

   ```text
   n_valid  = n_pass + n_partial + n_fail
   accuracy = 100 × (n_pass + 0.5 × n_partial) / n_valid      (rounded to 1 decimal)
   ```

5. Write `tdd/check-<YYYYMMDD-HHMMSS>.json`:

   ```json
   {
     "run_id": "claude-whole-r1",
     "checker": "<harness> / <model>",
     "suite": "tdd/oracle-tests.json",
     "tests": [
       {"test_id": "TC-01", "verdict": "pass", "report": ""},
       {"test_id": "TC-02", "verdict": "partial", "report": "Feature: ...\nExpected: ...\nObserved failure: ...\nSteps completed before failure: 3"}
     ],
     "n_pass": 1, "n_partial": 1, "n_fail": 0, "n_error": 0, "n_valid": 2,
     "accuracy": 75.0
   }
   ```

6. Reply with a table (test, verdict, one-line reason), the accuracy, and this CSV fragment:

   ```text
   n_pass,n_partial,n_fail,n_valid,accuracy
   1,1,0,2,75.0
   ```

## Test procedure

Use the browser tool of your harness (for example Playwright). Run every test case on its own:

- Start each test from a fresh page at the app URL. If your harness can run a subagent with its
  own context, run each test case in one, so every test starts with an empty context.
- At every step read the page's accessibility snapshot (for example Playwright
  `browser_snapshot`). Use a screenshot only to verify visual properties such as colors, styling
  and layout.
- Action budget per test: 20 browser actions if the test has 1–2 steps, otherwise
  min(24, max(12, 2 × steps + 2)). When the budget is used up you must give a verdict.

Verdict rules:

- Use "pass" if the expected outcome is observed, "fail" if it is not, "partial" if it is
  partially satisfied. Judge the OUTCOME, not exact wording — equivalent phrasing or layout still
  passes. Steps that only require looking at the page need no action; verify them from the
  accessibility tree.
- Account handling: if the task requires being logged in and no credentials are specified, FIRST
  register a new account (email testuser@example.com, password Test@1234, name "Test User", pick
  any required role), then log in with it. Report a login failure only if both registration and
  login genuinely do not work.
- If an element or feature the steps require is ABSENT from the application, that is a genuine
  "fail" (missing functionality), not a blocked test.
- If the APPLICATION malfunctions — data never finishes loading, submissions have no effect,
  pages error or hang — that is a genuine "fail" (broken functionality). Do not keep retrying a
  broken flow and do not call it blocked; fail it with what you observed.
- Use "blocked" ONLY when you cannot complete the steps for reasons that may be your own
  limitation: the accessibility tree shows the element exists and reacts normally but your
  actions on it keep erroring.
- If an action fails, correct the target using what the accessibility tree actually shows. Never
  repeat a target that has already failed.
- Stay on the application under test: it lives at the URL you started on. If a link leads to an
  unreachable address or a different host/port, that is a genuine navigation defect of the app —
  record it as evidence toward "fail", navigate back to the starting URL, and continue checking
  what remains. Never guess other ports.

Errors: a `blocked` test, a browser crash, or a tool failure that is not the app's fault is
re-run once. If it fails the same way again, its verdict is `error`: it is excluded from scoring
and never handed over as something to repair. If the app itself crashes or stops answering
during testing, that is a genuine `fail`.

Failure report for `fail` and `partial`:

```text
Feature: <feature>
Expected: <expected>
Observed failure: <what was attempted, where it failed, what was observed instead>
Steps completed before failure: <number>
```
