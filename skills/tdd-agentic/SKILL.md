---
name: tdd-agentic
description: Agentic TDD. One self-directed session with deploy and browser-test tools; the agent itself decides when to start the app, run the acceptance tests, repair and stop. Use only when the user explicitly invokes tdd-agentic for a TDD case-study run.
---

# Agentic TDD

You are an expert full-stack web developer working non-interactively.

## Inputs

Read these files first. Never modify them.

- `tdd/requirement.md` — the requirement.
- `tdd/tests.json` — the acceptance tests (`test_id`, `feature`, `steps`, `expected`).
- `tdd/app.md` — how to start and stop the app, its URL, and project conventions.

Never open `tdd/oracle-tests.json` or any `tdd/check-*.json`.

## Task

> Build a full-stack web application for this requirement: {tdd/requirement.md}
> The app must satisfy these acceptance test cases: {every test as
> `- [TC-01] feature: step1; step2 => EXPECTED: expected`}
>
> You also have deploy/test tools and should follow a test-driven workflow:
> 1. Write the application code.
> 2. `start_app` to deploy it; then `run_tests` to check the acceptance tests.
> 3. Fix failures and repeat until tests pass (or you judge further progress impossible).
> 4. `stop_app` before finishing.

## Your tools

- `start_app` — deploy the project (restarts a running instance so your code changes take
  effect); returns the app URL. Use the start command in `tdd/app.md`.
- `run_tests` — run all acceptance test cases against the deployed app; returns per-test verdicts
  and failure reports. Use the test procedure below over **all** tests in `tdd/tests.json`.
- `stop_app` — stop the deployed app as described in `tdd/app.md`.

## How to work

- **You decide** when to start the app, when to run the tests, what to repair and when to stop.
  There is no fixed number of rounds and no required order.
- Safety ceiling, not a budget: at most 25 `run_tests` calls in this session. Before each call
  write `Test run r; no fixed limit.`
- Every `run_tests` call covers the whole suite.
- Stop the app before you finish, log the `done` line, reply with a short summary and stop.

## Project rules

- Run the app only with the commands in `tdd/app.md`, and only through `start_app`/`stop_app`.
  No `curl`, ad-hoc probe scripts or other background servers. Never kill processes you did not
  start.
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
earlier lines. `round` is the number of the `run_tests` call (1, 2, 3, …).

```json
{"event": "tool", "approach": "agentic", "tool": "start_app"}
{"event": "test_eval", "approach": "agentic", "round": 1, "phase": "agentic", "test_id": "TC-01", "verdict": "fail", "report": "Feature: ..."}
{"event": "tool", "approach": "agentic", "tool": "stop_app"}
{"event": "done", "approach": "agentic", "rounds_used": 4, "stop_reason": "agent_decided"}
```

`verdict` is one of `pass`, `partial`, `fail`, `error`. `report` holds the failure report for
`fail`/`partial`, empty otherwise. `stop_reason` is `agent_decided` or `ceiling`.
