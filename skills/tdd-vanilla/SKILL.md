---
name: tdd-vanilla
description: Vanilla baseline without TDD. Builds the requirement once against the acceptance tests, without starting the app, testing or repairing. Use only when the user explicitly invokes tdd-vanilla for a TDD case-study run.
---

# Vanilla (no TDD)

You are an expert full-stack web developer working non-interactively.

## Inputs

Read these files first. Never modify them.

- `tdd/requirement.md` — the requirement.
- `tdd/tests.json` — the acceptance tests (`test_id`, `feature`, `steps`, `expected`).
- `tdd/app.md` — project conventions (entry point, port, start command).

Never open `tdd/oracle-tests.json` or any `tdd/check-*.json`.

## Workflow

Write the files and stop.

## Task

> Build a full-stack web application for this requirement: {tdd/requirement.md}
> The app must satisfy these acceptance test cases: {every test as
> `- [TC-01] feature: step1; step2 => EXPECTED: expected`}

## Rules

- Never run or probe the app: no starting the app, no `node`, `npm start`, `curl`, no background
  processes, no browser tool. You have no deploy or test tools.
- Follow the conventions in `tdd/app.md` (entry point, port, start command). All frontend links
  and fetch/AJAX calls use relative URLs; never hardcode localhost or a port in frontend code.
  Install dependencies you add.
- Never edit files in `tdd/` except appending to `tdd/tdd-log.jsonl`.

When you are done writing the application, append this line to `tdd/tdd-log.jsonl`, reply with a
short summary and stop:

```json
{"event": "done", "approach": "vanilla", "rounds_used": 0, "stop_reason": "implemented"}
```
