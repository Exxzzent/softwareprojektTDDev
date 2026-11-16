#!/usr/bin/env bash
# Git-Ablauf der Case Study über zwei Repos. Immer aus dem TDDev-Klon starten.
#   Projekt-Repo (App-Code, ein Branch pro Lauf)  -> $PROJECT, Remote "origin"
#   TDDev-Repo   (Ergebnisse unter results/)       -> dieses Repo, Remote "origin"
#
#   case.sh freeze                         Baseline einfrieren: committen, Tag tdd-baseline, pushen
#   case.sh branches <wdh> <agent>...      alle Lauf-Branches anlegen + pushen, Zeilen in runs.csv
#   case.sh start  <run-id>                auf run/<run-id> wechseln (bzw. anlegen), Arbeitsbaum leeren
#   case.sh check  <run-id>                vor dem Check: Arbeitsbaum leeren, Branch prüfen
#   case.sh finish <run-id>                committen + pushen, Ergebnisse nach results/, runs.csv füllen
#   case.sh csv                            results/runs.csv committen + pushen
set -euo pipefail

TDDEV="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT="${PROJECT:-$HOME/Desktop/Uni/3.Semester/Softwareprojekt/App/softwareprojekt}"
BASE_BRANCH="${BASE_BRANCH:-TDDev-origin}"
TAG="tdd-baseline"
APPROACHES="vanilla whole incremental agentic"
CSV="$TDDEV/results/runs.csv"

die() { echo "Fehler: $*" >&2; exit 1; }
p() { git -C "$PROJECT" "$@"; }
t() { git -C "$TDDEV" "$@"; }

[ "$TDDEV" != "$PROJECT" ] || die "case.sh läuft im Projekt-Repo. Aus dem TDDev-Klon starten: ~/Desktop/Code/Skills/softwareprojektTDDev/tools/case.sh"
[ -d "$PROJECT/.git" ] || die "kein Git-Repo unter PROJECT=$PROJECT"

# Alles, was nicht im Git liegt (node_modules, gebautes CSS, DB, Playwright-Reste), wird entfernt,
# damit kein Lauf etwas vom vorherigen erbt. Danach Submodul zurücksetzen und Dependencies
# frisch aus dem Lockfile des Branches installieren, damit jeder Lauf gleich startet.
clean_runtime() {
  p clean -fdxq
  p submodule update --init --recursive -q
  p submodule foreach -q --recursive 'git reset -q --hard && git clean -fdxq'
  (cd "$PROJECT" && bun install ${1:---frozen-lockfile} >/dev/null)
}
need_submodule() { ! p submodule status --recursive | grep -q '^-' || die "Submodul references/ise-server fehlt ('git submodule update --init')"; }

need_tag() { p rev-parse -q --verify "refs/tags/$TAG" >/dev/null || die "Tag $TAG fehlt, zuerst 'case.sh freeze'"; }
need_clean() { [ -z "$(p status --porcelain --ignore-submodules=untracked)" ] || die "Projekt hat uncommittete Änderungen (erst 'case.sh finish <run-id>')"; }

cmd="${1:-}"; run="${2:-}"

case "$cmd" in
  freeze)
    [ "$(p branch --show-current)" = "$BASE_BRANCH" ] || die "im Projekt zuerst '$BASE_BRANCH' auschecken"
    grep -q 'Please implement \.\.\.' "$PROJECT/tdd/requirement.md" && die "tdd/requirement.md ist noch nicht ausgefüllt"
    grep -q 'ANLEITUNG' "$PROJECT/tdd/requirement.md" && die "Anleitungs-Kommentar in tdd/requirement.md noch löschen"
    grep -q "'Test Item' is shown as completed" "$PROJECT/tdd/tests.json" && die "tdd/tests.json enthält noch die Beispiel-Tests"
    python3 -c "import json,sys; json.load(open(sys.argv[1]))" "$PROJECT/tdd/tests.json" || die "tdd/tests.json ist kein gültiges JSON"
    p rev-parse -q --verify "refs/tags/$TAG" >/dev/null && die "Tag $TAG existiert schon (Baseline ist bereits eingefroren)"
    need_submodule
    p add -A
    p diff --cached --quiet || p commit -m "TDD case study baseline"
    p tag "$TAG"
    p push -u origin "$BASE_BRANCH"
    p push origin "$TAG"
    echo "Baseline eingefroren: $BASE_BRANCH @ $(p rev-parse --short HEAD), Tag $TAG gepusht."
    ;;

  branches)
    reps="${2:-}"; shift 2 || true
    [[ "$reps" =~ ^[1-9][0-9]*$ ]] && [ $# -gt 0 ] || die "Aufruf: case.sh branches <wiederholungen> <agent>...   z. B. branches 2 sonnet opus gpt gemini"
    need_tag
    refs=()
    for a in "$@"; do
      [[ "$a" =~ ^[a-z0-9.]+$ ]] || die "Agent-Name '$a': nur Kleinbuchstaben, Ziffern, Punkt (kein Bindestrich)"
      for ap in $APPROACHES; do for r in $(seq 1 "$reps"); do
        b="run/$a-$ap-r$r"
        p rev-parse -q --verify "refs/heads/$b" >/dev/null || p branch "$b" "$TAG"
        refs+=("$b")
      done; done
    done
    p push -u origin "${refs[@]}"
    python3 - "$CSV" "$APPROACHES" "$reps" "$TDDEV/harness/agents.tsv" "$@" <<'EOF'
import csv, sys
path, approaches, reps, spec, agents = sys.argv[1], sys.argv[2].split(), int(sys.argv[3]), sys.argv[4], sys.argv[5:]
table = {l.split("\t")[0]: l.rstrip("\n").split("\t")[1:] for l in open(spec) if l.strip() and not l.startswith("#")}
missing = [a for a in agents if a not in table]
if missing: sys.exit(f"Fehler: {missing} fehlen in harness/agents.tsv")
with open(path, newline="") as f:
    rows = list(csv.DictReader(f)); f.seek(0); header = next(csv.reader(f))
rows = [r for r in rows if not r["agent"].startswith("modell")]   # Platzhalter der Vorlage
have = {r["run_id"] for r in rows}
for a in agents:
    for ap in approaches:
        for n in range(1, reps + 1):
            rid = f"{a}-{ap}-r{n}"
            if rid not in have:
                row = dict.fromkeys(header, "")
                h, m, r = table[a]
                row.update(run_id=rid, agent=a, harness=h, model=m, reasoning=r, approach=ap, repeat=str(n))
                rows.append(row)
with open(path, "w", newline="") as f:
    w = csv.DictWriter(f, fieldnames=header, lineterminator="\n"); w.writeheader(); w.writerows(rows)
print(f"runs.csv: {len(rows)} Zeilen")
EOF
    echo "${#refs[@]} Branches ab $TAG angelegt und gepusht. 'case.sh csv' pusht die neue runs.csv."
    ;;

  start)
    [ -n "$run" ] || die "Aufruf: case.sh start <run-id>   z. B. sonnet-whole-r1"
    need_clean; need_tag
    b="run/$run"
    if p rev-parse -q --verify "refs/heads/$b" >/dev/null; then
      [ -z "$(p rev-list "$TAG..$b")" ] || die "$b hat schon Commits nach $TAG, der Lauf wurde bereits gemacht"
      p switch "$b"
    else
      p switch -c "$b" "$TAG"
    fi
    clean_runtime
    echo "Auf $b (= $TAG), Arbeitsbaum geleert und Dependencies installiert. Jetzt: tools/agent.sh run $run"
    ;;

  check)
    [ -n "$run" ] || die "Aufruf: case.sh check <run-id>"
    [ "$(p branch --show-current)" = "run/$run" ] || die "Projekt ist nicht auf run/$run"
    need_clean
    clean_runtime " "
    echo "Bereit für den Check: tools/agent.sh check $run"
    ;;

  finish)
    [ -n "$run" ] || die "Aufruf: case.sh finish <run-id>"
    [ "$(p branch --show-current)" = "run/$run" ] || die "Projekt ist nicht auf run/$run"
    # 1) Projekt: Lauf committen und auf softwareprojekt.git pushen
    p add -A
    if p diff --cached --quiet; then echo "Projekt: nichts Neues zu committen."
    elif p diff --cached --name-only | grep -q '^tdd/check-'; then p commit -q -m "check $run"
    else p commit -q -m "run $run"
    fi
    p push -q -u origin "run/$run"
    # 2) TDDev: Ergebnisse nach results/<run-id>/ kopieren
    dest="$TDDEV/results/$run"; mkdir -p "$dest"
    for f in "$PROJECT"/tdd/tdd-log.jsonl "$PROJECT"/tdd/check-*.json; do
      [ -f "$f" ] && cp "$f" "$dest/"
    done
    printf 'branch: run/%s\ncommit: %s\nrepo: %s\n' "$run" "$(p rev-parse HEAD)" "$(p remote get-url origin)" > "$dest/source.txt"
    # 3) runs.csv: tester aus dem Log, Werte aus dem ERSTEN Check (der zählt); Vorhandenes bleibt
    tok="{}"
    if [ -f "$dest/launch-run.txt" ] && [ ! -f "$dest/tokens.json" ]; then
      CLAUDE_CONFIG_DIR="${CASE_HOME:-$HOME/.tdd-case}/claude" CODEX_HOME="${CASE_HOME:-$HOME/.tdd-case}/codex" \
        python3 "$TDDEV/tools/tokens.py" "$dest/launch-run.txt" "$PROJECT" > "$dest/tokens.json" || echo "{}" > "$dest/tokens.json"
    fi
    [ -f "$dest/tokens.json" ] && tok="$(cat "$dest/tokens.json")"
    python3 - "$CSV" "$run" "$dest" "$tok" <<'EOF'
import csv, glob, json, os, sys
path, run, dest, tok = sys.argv[1:]
with open(path, newline="") as f:
    rows = list(csv.DictReader(f)); f.seek(0); header = next(csv.reader(f))
row = next((r for r in rows if r["run_id"] == run), None)
if row is None:
    row = dict.fromkeys(header, ""); parts = run.split("-")
    if len(parts) == 3 and parts[2].startswith("r"):
        row.update(agent=parts[0], approach=parts[1], repeat=parts[2][1:])
    row["run_id"] = run; rows.append(row)
empty = lambda k: row.get(k, "") in ("", "XXX")
filled = []
log = os.path.join(dest, "tdd-log.jsonl")
if os.path.exists(log) and empty("tester"):
    for line in open(log):
        try: e = json.loads(line)
        except ValueError: continue
        if e.get("event") == "done" and e.get("tester"): row["tester"] = e["tester"]
    if row["tester"]: filled.append("tester")
for k, v in json.loads(tok or "{}").items():
    if k in row and empty(k): row[k] = str(v); filled.append(k)
checks = sorted(glob.glob(os.path.join(dest, "check-*.json")))
if checks:
    c = json.load(open(checks[0]))
    for k in ("n_pass", "n_partial", "n_fail", "n_valid", "accuracy"):
        if empty(k) and k in c: row[k] = str(c[k]); filled.append(k)
    if len(checks) > 1: print(f"Hinweis: {len(checks)} Checks, gewertet wird der erste ({os.path.basename(checks[0])})")
with open(path, "w", newline="") as f:
    w = csv.DictWriter(f, fieldnames=header, lineterminator="\n"); w.writeheader(); w.writerows(rows)
print("runs.csv:", ", ".join(filled) if filled else "nichts Neues eingetragen")
EOF
    t add results
    t diff --cached --quiet || t commit -q -m "results $run"
    t push -q
    echo "Fertig: run/$run gepusht, Ergebnisse in results/$run/ gepusht."
    echo "Tokens: aus den Transkripten (results/$run/tokens.json). Nur bei Antigravity tok_* von Hand eintragen, dann 'case.sh csv'."
    ;;

  csv)
    t add "$CSV"
    t diff --cached --quiet && { echo "runs.csv unverändert."; exit 0; }
    t commit -q -m "update runs.csv"
    t push -q
    echo "runs.csv gepusht."
    ;;

  *)
    sed -n '2,11p' "$0"; exit 1 ;;
esac
