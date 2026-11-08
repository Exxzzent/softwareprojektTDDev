#!/usr/bin/env python3
"""Metrics for the TDDev case study. Standard library only, no install needed.

    python3 tools/metrics.py check   <tdd/check-*.json> [...]   accuracy of one or more checks
    python3 tools/metrics.py loop    <tdd/tdd-log.jsonl>        loop behaviour of one build run
    python3 tools/metrics.py summary <runs.csv>                 accuracy, delta, tokens, CostEff, stats

Formulas follow the paper (Wan et al., ASE '26) and the reference code in
github.com/yxwan123/TDD (analysis/metrics.py, analysis/stats.py, analysis/tables.py).
"""
from __future__ import annotations

import csv
import itertools
import json
import random
import sys
from collections import defaultdict
from pathlib import Path

RANK = {"pass": 2, "partial": 1, "fail": 0}
SCORE = {"pass": 1.0, "partial": 0.5, "fail": 0.0}
K_MAX = 5
TOKEN_COLS = ("tok_input", "tok_cache_read", "tok_cache_write", "tok_output")


# -- accuracy (paper Eq. 1) ---------------------------------------------------

def accuracy(verdicts: list[str]) -> float | None:
    """acc = 100 * (N_pass + 0.5 * N_partial) / N_valid; `error` verdicts are excluded."""
    valid = [v for v in verdicts if v in RANK]
    if not valid:
        return None  # unscorable, never 0
    return round(100.0 * sum(SCORE[v] for v in valid) / len(valid), 1)


def cmd_check(paths: list[str]) -> None:
    print("| check file | run_id | pass | partial | fail | error | n_valid | accuracy (%) | stored |")
    print("|---|---|---|---|---|---|---|---|---|")
    for p in paths:
        data = json.loads(Path(p).read_text())
        vs = [t.get("verdict", "error") for t in data.get("tests", [])]
        acc = accuracy(vs)
        counts = {v: vs.count(v) for v in ("pass", "partial", "fail", "error")}
        stored = data.get("accuracy")
        flag = "" if stored is None or acc is None or abs(float(stored) - acc) < 0.05 else "  <- MISMATCH"
        print(f"| {Path(p).name} | {data.get('run_id', '')} | {counts['pass']} | {counts['partial']} "
              f"| {counts['fail']} | {counts['error']} | {sum(counts[v] for v in RANK)} "
              f"| {'—' if acc is None else acc} | {stored}{flag} |")


# -- loop behaviour (paper Tables 7 and 8) -----------------------------------

def read_jsonl(path: str) -> list[dict]:
    rows = []
    for i, line in enumerate(Path(path).read_text().splitlines(), 1):
        if line.strip():
            try:
                rows.append(json.loads(line))
            except json.JSONDecodeError:
                print(f"warning: line {i} is not valid JSON and was skipped", file=sys.stderr)
    return rows


def cmd_loop(path: str) -> None:
    rows = read_jsonl(path)
    evals = [r for r in rows if r.get("event") == "test_eval"]
    genuine = [r for r in evals if r.get("verdict") in RANK]
    approach = next((r.get("approach") for r in rows if r.get("approach")), "?")
    runs = sorted({(r.get("phase", ""), r.get("round")) for r in evals}, key=str)
    done = next((r for r in rows if r.get("event") == "done"), {})

    print(f"approach: {approach}")
    print(f"test runs (run_tests calls): {len(runs)}")
    print(f"repairs: {sum(1 for r in rows if r.get('event') == 'repair')}")
    print(f"washes: {sum(1 for r in rows if r.get('event') == 'wash')}")
    print(f"stop reason: {done.get('stop_reason', '— (no done line)')}")
    print(f"test evaluations: {len(evals)} (genuine {len(genuine)}, error {len(evals) - len(genuine)})")
    if genuine:
        fails = sum(1 for r in genuine if r["verdict"] == "fail")
        print(f"failure-verdict rate: {100 * fails / len(genuine):.1f} %  ({fails}/{len(genuine)})")

    # acc@k as in analysis/metrics.py: per test, best of its first k genuine verdicts
    per_test: dict[str, list[str]] = defaultdict(list)
    for r in genuine:
        per_test[r["test_id"]].append(r["verdict"])
    if per_test:
        print("\nacc@k (best of the first k verdicts per test, analysis/metrics.py):")
        for k in range(1, K_MAX + 1):
            total = sum(SCORE[max(vs[:k], key=RANK.get)] for vs in per_test.values())
            print(f"  k={k}: {100 * total / len(per_test):.1f} %")

    # accuracy per round (paper Table 8 style; meaningful for whole and agentic)
    if approach in ("whole", "agentic"):
        by_round: dict[int, list[str]] = defaultdict(list)
        for r in genuine:
            by_round[int(r.get("round", 0))].append(r["verdict"])
        if by_round:
            print("\naccuracy per round (verdicts of that round only, paper Table 8):")
            prev = None
            for k in sorted(by_round):
                acc = accuracy(by_round[k])
                dip = "  <- regression" if prev is not None and acc is not None and acc < prev else ""
                print(f"  round {k}: {acc} %{dip}")
                prev = acc

    # incremental: admission, abandonment, regression (paper Table 7)
    if approach == "incremental":
        phases = {r.get("phase") for r in evals if str(r.get("phase", "")).startswith("incr:")}
        admitted = [r for r in rows if r.get("event") == "feature_admitted"]
        abandoned = [r for r in rows if r.get("event") == "feature_abandoned"]
        excluded = [r for r in rows if r.get("event") == "feature_excluded"]
        n_feat = len(phases) or (len(admitted) + len(abandoned) + len(excluded))
        print(f"\nfeatures attempted: {n_feat}")
        if n_feat:
            print(f"feature-admission rate: {100 * len(admitted) / n_feat:.1f} %  ({len(admitted)}/{n_feat})")
            print(f"feature-abandonment rate: {100 * len(abandoned) / n_feat:.1f} %  ({len(abandoned)}/{n_feat})")
            print(f"features excluded (infra errors): {len(excluded)}")
        regressed = 0
        for adm in admitted:
            idx = rows.index(adm)
            level = RANK.get(adm.get("level", "pass"), 2)
            if any(r.get("event") == "test_eval" and r.get("test_id") == adm["test_id"]
                   and r.get("verdict") in RANK and RANK[r["verdict"]] < level
                   for r in rows[idx + 1:]):
                regressed += 1
        if admitted:
            print(f"regression rate: {100 * regressed / len(admitted):.1f} %  "
                  f"({regressed}/{len(admitted)} admitted features later dropped below their level)")


# -- summary across runs (paper RQ2-RQ4) -------------------------------------

def _num(x: str) -> float | None:
    try:
        return float(x)
    except (TypeError, ValueError):
        return None


def _tokens(row: dict) -> float | None:
    vals = [_num(row.get(c, "")) for c in TOKEN_COLS]
    if all(v is None for v in vals):
        return None
    return sum(v for v in vals if v is not None)


def _acc(row: dict) -> float | None:
    a = _num(row.get("accuracy", ""))
    if a is not None:
        return a
    p, pa, n = (_num(row.get(c, "")) for c in ("n_pass", "n_partial", "n_valid"))
    if p is None or pa is None or not n:
        return None
    return round(100 * (p + 0.5 * pa) / n, 1)


def _mean(xs: list[float]) -> float | None:
    xs = [x for x in xs if x is not None]
    return sum(xs) / len(xs) if xs else None


def bootstrap_ci(deltas: list[float], iters: int = 10000, alpha: float = 0.05, seed: int = 0):
    """Percentile bootstrap CI of the mean paired difference (analysis/stats.py)."""
    if not deltas:
        return None
    rng = random.Random(seed)
    n = len(deltas)
    means = sorted(sum(rng.choices(deltas, k=n)) / n for _ in range(iters))
    return round(means[int(alpha / 2 * iters)], 1), round(means[int((1 - alpha / 2) * iters)], 1)


def wilcoxon_greater(deltas: list[float]) -> float | None:
    """Exact one-sided Wilcoxon signed-rank p for H1: delta > 0 (zeros dropped)."""
    d = [x for x in deltas if x != 0]
    if not deltas:
        return None
    if not d:
        return 1.0
    order = sorted(range(len(d)), key=lambda i: abs(d[i]))
    ranks = [0.0] * len(d)
    i = 0
    while i < len(order):  # average ranks for ties
        j = i
        while j + 1 < len(order) and abs(d[order[j + 1]]) == abs(d[order[i]]):
            j += 1
        for t in range(i, j + 1):
            ranks[order[t]] = (i + j) / 2 + 1
        i = j + 1
    w_obs = sum(r for r, x in zip(ranks, d) if x > 0)
    hits = sum(1 for signs in itertools.product((0, 1), repeat=len(d))
               if sum(r for r, s in zip(ranks, signs) if s) >= w_obs - 1e-9)
    return hits / 2 ** len(d)


def cmd_summary(path: str) -> None:
    rows = list(csv.DictReader(Path(path).open()))
    groups: dict[tuple[str, str], list[dict]] = defaultdict(list)
    for r in rows:
        groups[(r["agent"].strip(), r["approach"].strip().lower())].append(r)

    print("## Accuracy and tokens per agent and approach\n")
    print("| agent | approach | runs | mean accuracy (%) | Δ vs vanilla (pp) | mean tokens (M) "
          "| extra tokens (M) | CostEff (pp/M) | mean turns |")
    print("|---|---|---|---|---|---|---|---|---|")
    order = {"vanilla": 0, "whole": 1, "incremental": 2, "agentic": 3}
    for (agent, appr) in sorted(groups, key=lambda g: (g[0], order.get(g[1], 9))):
        rs = groups[(agent, appr)]
        acc = _mean([_acc(r) for r in rs])
        tok = _mean([_tokens(r) for r in rs])
        turns = _mean([_num(r.get("turns", "")) for r in rs])
        base = groups.get((agent, "vanilla"), [])
        b_acc = _mean([_acc(r) for r in base]) if base else None
        b_tok = _mean([_tokens(r) for r in base]) if base else None
        delta = extra = eff = None
        if appr != "vanilla" and acc is not None and b_acc is not None:
            delta = acc - b_acc
            if tok is not None and b_tok is not None:
                extra = (tok - b_tok) / 1e6
                eff = delta / extra if extra > 0 else None
        f = lambda x, d=1: "—" if x is None else f"{x:.{d}f}"
        print(f"| {agent} | {appr} | {len(rs)} | {f(acc)} | {f(delta)} | "
              f"{f(None if tok is None else tok / 1e6, 2)} | {f(extra, 2)} | {f(eff, 2)} | {f(turns, 0)} |")

    print("\n## Paired comparison with vanilla (pairs = same agent, same `repeat`)\n")
    print("| agent | approach | pairs | mean Δ (pp) | 95 % bootstrap CI | Wilcoxon p (one-sided) |")
    print("|---|---|---|---|---|---|")
    for (agent, appr) in sorted(groups, key=lambda g: (g[0], order.get(g[1], 9))):
        if appr == "vanilla":
            continue
        base = {r.get("repeat"): _acc(r) for r in groups.get((agent, "vanilla"), [])}
        deltas = [_acc(r) - base[r.get("repeat")] for r in groups[(agent, appr)]
                  if _acc(r) is not None and base.get(r.get("repeat")) is not None]
        if not deltas:
            print(f"| {agent} | {appr} | 0 | — | — | — |")
            continue
        ci = bootstrap_ci(deltas)
        p = wilcoxon_greater(deltas)
        print(f"| {agent} | {appr} | {len(deltas)} | {sum(deltas) / len(deltas):.1f} "
              f"| [{ci[0]}, {ci[1]}] | {p:.3f} |")
    print("\nNote: with n pairs the smallest possible one-sided Wilcoxon p is 1/2^n "
          "(n=4: 0.0625, n=5: 0.031). Few pairs = illustrative, not significant.")


def main() -> None:
    if len(sys.argv) < 3 or sys.argv[1] not in ("check", "loop", "summary"):
        print(__doc__)
        sys.exit(1)
    cmd, args = sys.argv[1], sys.argv[2:]
    if cmd == "check":
        cmd_check(args)
    elif cmd == "loop":
        cmd_loop(args[0])
    else:
        cmd_summary(args[0])


if __name__ == "__main__":
    main()
