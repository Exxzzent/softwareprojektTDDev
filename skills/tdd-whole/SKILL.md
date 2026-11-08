---
name: tdd-whole
description: Whole-Project TDD. Builds the whole requirement in one pass, then runs up to 5 deploy-test-repair rounds over the full acceptance suite in a browser. Use only when the user explicitly invokes tdd-whole for a TDD case-study run.
---

# Whole-Project TDD

You are an expert full-stack web developer working non-interactively.

## Inputs

Read these files first. Never modify them.

- `tdd/requirement.md` — the requirement.
- `tdd/tests.json` — the acceptance tests (`test_id`, `feature`, `steps`, `expected`).
- `tdd/app.md` — how to start and stop the app, its URL, and project conventions.

Never open `tdd/oracle-tests.json` or any `tdd/check-*.json`.

## Workflow

Build the complete application first, then verify it: write all the files, then start_app and
run_tests, repair what fails, and repeat. You have at most 5 test runs.

- `start_app`: start the app with the start command in `tdd/app.md`.
- `run_tests`: the test procedure below over **all** tests in `tdd/tests.json`.
- `stop_app`: stop the app as described in `tdd/app.md`.

## Procedure

1. **Implement everything in one pass.** Your task:

   > Build a full-stack web application for this requirement: {tdd/requirement.md}
   > The app must satisfy these acceptance test cases: {every test as
   > `- [TC-01] feature: step1; step2 => EXPECTED: expected`}

   Follow the project rules below. Do not start the app while implementing.

2. **Test rounds k = 1 … 5.** Before each round write the budget line
   `Test run k of 5; (6 - k) remaining.` Then:
   1. `start_app`.
   2. `run_tests` over all tests. Log one `test_eval` line per test (see Logging).
   3. `stop_app`.
   4. **Stop if every genuine verdict is `pass`** (`stop_reason: all_pass`). A `partial` does not
      stop the loop.
   5. **Stop after round 5** (`stop_reason: budget`). Do not repair after the 5th round.
   6. Otherwise build the failure report and repair (step 3), then start the next round.

   A round whose tests all ended as `error` (no genuine verdict) is a *wash*: it does not use up
   a round. A second wash ends the loop (`stop_reason: infra_error`).

3. **Failure report and repair.** The report lists every genuine non-`pass` test, one block each:
   `[TC-xx] failure (<verdict>):` followed by the test's failure report. If two tests fail with the
   same first line, write `[TC-yy] failure: same as above` for the second. Then repair:

   > You are fixing a web application that failed acceptance testing.
   > Original requirement: {requirement} — Latest test results: {report}
   > Inspect the relevant project files, find the cause, and fix it. Apply the smallest targeted
   > change that resolves the failures — do not rewrite or restructure parts that work. Then stop:
   > do not re-read or re-verify the rest of the project after making the fix.

   Log one `repair` line.

4. **Finish.** Make sure the app is stopped, log the `done` line, reply with a short summary and
   stop.

## Project rules

- Run the app only with the commands in `tdd/app.md`, and only inside a test round. No `curl`,
  ad-hoc probe scripts or other background servers. Never kill processes you did not start.
- Follow the conventions in `tdd/app.md` (entry point, port, start command). All frontend links
  and fetch/AJAX calls use relative URLs; never hardcode localhost or a port in frontend code.
  Install dependencies you add.
- Never edit files in `tdd/` except appending to `tdd/tdd-log.jsonl`. Never change a test to
  make it pass.

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

## Logging

Append one JSON object per line to `tdd/tdd-log.jsonl` (create it if missing). Never rewrite
earlier lines.

```json
{"event": "test_eval", "approach": "whole", "round": 1, "phase": "whole", "test_id": "TC-01", "verdict": "pass", "report": ""}
{"event": "repair", "approach": "whole", "round": 1, "tests": ["TC-02", "TC-04"]}
{"event": "wash", "approach": "whole", "round": 2}
{"event": "done", "approach": "whole", "rounds_used": 3, "stop_reason": "all_pass"}
```

`verdict` is one of `pass`, `partial`, `fail`, `error`. `report` holds the failure report for
`fail`/`partial`, empty otherwise.
