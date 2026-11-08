---
name: tdd-incremental
description: Incremental TDD. Builds one feature at a time; after each feature runs that feature's test plus every already accepted test in a browser, with up to 5 deploy-test-repair rounds per feature. Use only when the user explicitly invokes tdd-incremental for a TDD case-study run.
---

# Incremental TDD

You are an expert full-stack web developer working non-interactively.

## Inputs

Read these files first. Never modify them.

- `tdd/requirement.md` — the requirement.
- `tdd/tests.json` — the acceptance tests (`test_id`, `feature`, `steps`, `expected`). Their order
  is the feature order.
- `tdd/app.md` — how to start and stop the app, its URL, and project conventions.

Never open `tdd/oracle-tests.json` or any `tdd/check-*.json`.

## Workflow

Build the application one feature at a time. Implement the current feature, then start_app and
run_tests. run_tests covers the feature you are on plus the features already accepted, so a
regression in earlier work surfaces immediately. A feature is accepted once its test reaches
partial or pass; move on once it is accepted.

- `start_app`: start the app with the start command in `tdd/app.md`.
- `run_tests`: the test procedure below over the current test plus every accepted test.
- `stop_app`: stop the app as described in `tdd/app.md`.

## Procedure

Keep an **accepted list**: each accepted test with the level it was accepted at (`pass` or
`partial`). It starts empty. Verdict rank: `pass` > `partial` > `fail`.

For each test `TC-i` in the order of `tdd/tests.json`:

1. **Implement only this feature.** Your task:

   > You are building a web application incrementally.
   > Overall requirement: {tdd/requirement.md}
   > Full acceptance suite (for context): {all tests}
   > Implement ONLY this feature now, extending the existing project without breaking features
   > that already pass: {TC-i}

   Follow the project rules below. Do not start the app while implementing.

2. **Test rounds k = 1 … 5 for this feature.** Before each round write the status line
   `Feature i of n (TC-i), attempt k of 5; m feature(s) accepted.` Then:
   1. `start_app`. **If the app does not start**, skip `run_tests`: every test of this round
      (the accepted tests plus TC-i) is a genuine `fail` with the report
      `Observed failure: the app did not start: <start error>`. Log one `deploy_failed` line and
      one `test_eval` line per test, then continue with step 4. The round counts.
   2. `run_tests` over **the accepted tests plus TC-i**, nothing else. Log one `test_eval` line per
      test with `phase: "incr:TC-i"`.
   3. `stop_app`.
   4. Collect problems:
      - every accepted test whose genuine verdict ranks **below its accepted level**:
        `REGRESSION (was <level>, now <verdict>)` (so pass → partial counts);
      - TC-i, if its verdict is `fail`: `failure (fail)`.
   5. **No problems and TC-i is `pass` or `partial`** → accept TC-i at that verdict, log
      `feature_admitted`, go to the next feature.
   6. **TC-i ended as `error` and there are no other problems** → *wash*: the round does not count.
      A second wash for the same feature: log `feature_excluded` and go to the next feature.
   7. **Problems, round < 5** → repair (step 3), then the next round.
   8. **Problems after round 5** → log `feature_abandoned` and go to the next feature. Do not
      repair after the 5th round. TC-i stays out of the accepted list.

3. **Failure report and repair.** The report lists only the problems from step 2.4, one block
   each: `[TC-xx] <tag>:` followed by that test's failure report. If two problems have the same tag
   and first line, write `[TC-yy] <tag>: same as above` for the second. Then repair:

   > You are fixing a web application that failed acceptance testing.
   > Original requirement: {requirement} — Latest test results: {report}
   > Inspect the relevant project files, find the cause, and fix it. Apply the smallest targeted
   > change that resolves the failures — do not rewrite or restructure parts that work. Then stop:
   > do not re-read or re-verify the rest of the project after making the fix.

   Log one `repair` line.

4. **Finish** after the last feature. Make sure the app is stopped, log the `done` line, reply
   with a short summary (accepted, abandoned, excluded features) and stop.

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

- **Separate tester.** If your harness can run a subagent, you must run each test case in its own
  subagent with an empty context. Give it only the test case (`test_id`, `feature`, `steps`,
  `expected`), the app URL and this test procedure: no source code, no file paths, no account of
  how you implemented anything. It returns the verdict and, for `fail`/`partial`, the failure
  report. Only if your harness has no subagents, run the test yourself and judge only what the
  browser shows, never what the code says. Record which of the two you used in the `done` line
  (`"tester": "subagent"` or `"tester": "self"`).
- Start each test from a fresh page at the app URL.
- During a test run, do not edit any project file (appending to `tdd/tdd-log.jsonl` is fine);
  finish every test of the run first.
- Take every verdict exactly as the test returned it. Never upgrade, downgrade or re-run a genuine
  verdict; only `error` cases are re-run (see below).
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
{"event": "test_eval", "approach": "incremental", "round": 1, "phase": "incr:TC-02", "test_id": "TC-01", "verdict": "pass", "report": ""}
{"event": "repair", "approach": "incremental", "round": 1, "phase": "incr:TC-02", "tests": ["TC-02"]}
{"event": "feature_admitted", "approach": "incremental", "test_id": "TC-02", "level": "partial", "round": 2}
{"event": "feature_abandoned", "approach": "incremental", "test_id": "TC-03"}
{"event": "feature_excluded", "approach": "incremental", "test_id": "TC-04"}
{"event": "wash", "approach": "incremental", "round": 1, "phase": "incr:TC-04"}
{"event": "deploy_failed", "approach": "incremental", "round": 2, "phase": "incr:TC-05", "error": "..."}
{"event": "done", "approach": "incremental", "rounds_used": 9, "stop_reason": "all_features_attempted", "tester": "subagent"}
```

`round` counts per feature (1–5); `rounds_used` in the `done` line is the total number of test
runs. `verdict` is one of `pass`, `partial`, `fail`, `error`. `report` holds the failure report
for `fail`/`partial`, empty otherwise.
