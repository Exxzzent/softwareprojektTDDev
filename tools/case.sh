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
#
# Zwei Aufgabenstellungen (tasks/): t1 = Folgefahrt mit Mockup, t2 = Gegenverkehr ohne Mockup.
# Die Aufgabe steckt in der run-id: "opus5.5-whole-r1" ist t1, "t2-opus5.5-whole-r1" ist t2.
# Jede Aufgabe hat ihren eigenen Ausgangsstand (Branch + Tag) und ihren eigenen Projekt-Klon.
# Befehle ohne run-id (freeze, branches) nehmen die Aufgabe aus TASK (Standard t1): TASK=t2 case.sh branches 2 opus5.5
set -euo pipefail

TDDEV="$(cd "$(dirname "$0")/.." && pwd)"
APPROACHES="vanilla whole incremental agentic"
CSV="$TDDEV/results/runs.csv"

die() { echo "Fehler: $*" >&2; exit 1; }
p() { git -C "$PROJECT" "$@"; }
t() { git -C "$TDDEV" "$@"; }

# Aufgabe einer run-id: Präfix "t<n>-", sonst t1.
task_of() { if [[ "$1" =~ ^(t[0-9]+)- ]]; then echo "${BASH_REMATCH[1]}"; else echo t1; fi; }

# Setzt TASK, PROJECT, BASE_BRANCH und TAG für eine Aufgabe.
#   t1: Klon $PROJECT,    Branch TDDev-origin,    Tag tdd-baseline      (unverändert)
#   t2: Klon $PROJECT_T2, Branch TDDev-origin-t2, Tag tdd-baseline-t2
use_task() {
  TASK="$1"
  [[ "$TASK" =~ ^t[0-9]+$ ]] || die "unbekannte Aufgabe '$TASK' (t1, t2, ...)"
  if [ "$TASK" = t1 ]; then
    PROJECT="${PROJECT:-$HOME/Desktop/Uni/3.Semester/Softwareprojekt/App/softwareprojekt}"
    BASE_BRANCH="${BASE_BRANCH:-TDDev-origin}"
    TAG="tdd-baseline"
  else
    local up; up="$(echo "$TASK" | tr a-z A-Z)"
    local var="PROJECT_$up"
    PROJECT="${!var:-$HOME/Desktop/Uni/3.Semester/Softwareprojekt/App-$up/softwareprojekt}"
    BASE_BRANCH="TDDev-origin-$TASK"
    TAG="tdd-baseline-$TASK"
  fi
  [ "$TDDEV" != "$PROJECT" ] || die "case.sh läuft im Projekt-Repo. Aus dem TDDev-Klon starten: ~/Desktop/Code/Skills/softwareprojektTDDev/tools/case.sh"
  [ -d "$PROJECT/.git" ] || die "kein Git-Repo unter $PROJECT (Aufgabe $TASK)"
}

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

# Der Projekt-Klon muss mit derselben Git-E-Mail committen wie dieses Repo. Sonst lehnt GitHub den
# Push am Ende eines Laufs ab, wenn dort die private Adresse geschützt ist (GH007).
need_identity() {
  local pe te; pe="$(p config user.email || true)"; te="$(t config user.email || true)"
  [ -n "$pe" ] && [ "$pe" = "$te" ] || die "Git-E-Mail im Projekt-Klon ('$pe') weicht von der im TDDev-Repo ('$te') ab. Beheben: git -C \"$PROJECT\" config user.email \"$te\""
}

need_tag() { p rev-parse -q --verify "refs/tags/$TAG" >/dev/null || die "Tag $TAG fehlt, zuerst 'case.sh freeze'"; }
need_clean() { [ -z "$(p status --porcelain --ignore-submodules=untracked)" ] || die "Projekt hat uncommittete Änderungen (erst 'case.sh finish <run-id>')"; }

cmd="${1:-}"; run="${2:-}"

case "$cmd" in
  start|check|finish) [ -n "$run" ] && use_task "$(task_of "$run")" ;;
  freeze|branches) use_task "${TASK:-t1}" ;;
esac

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
    prefix=""; [ "$TASK" = t1 ] || prefix="$TASK-"
    refs=()
    for a in "$@"; do
      [[ "$a" =~ ^[a-z0-9.]+$ ]] || die "Agent-Name '$a': nur Kleinbuchstaben, Ziffern, Punkt (kein Bindestrich)"
      for ap in $APPROACHES; do for r in $(seq 1 "$reps"); do
        b="run/$prefix$a-$ap-r$r"
        p rev-parse -q --verify "refs/heads/$b" >/dev/null || p branch "$b" "$TAG"
        refs+=("$b")
      done; done
    done
    p push -u origin "${refs[@]}"
    python3 - "$CSV" "$APPROACHES" "$reps" "$TDDEV/harness/agents.tsv" "$TASK" "$@" <<'EOF'
import csv, sys
path, approaches, reps, spec, task, agents = sys.argv[1], sys.argv[2].split(), int(sys.argv[3]), sys.argv[4], sys.argv[5], sys.argv[6:]
prefix = "" if task == "t1" else task + "-"
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
            rid = f"{prefix}{a}-{ap}-r{n}"
            if rid not in have:
                row = dict.fromkeys(header, "")
                h, m, r = table[a][:3]
                row.update(run_id=rid, agent=a, harness=h, model=m, reasoning=r, approach=ap, repeat=str(n))
                if "task" in row: row["task"] = task
                rows.append(row)
with open(path, "w", newline="") as f:
    w = csv.DictWriter(f, fieldnames=header, lineterminator="\n"); w.writeheader(); w.writerows(rows)
print(f"runs.csv: {len(rows)} Zeilen")
EOF
    echo "${#refs[@]} Branches ab $TAG angelegt und gepusht. 'case.sh csv' pusht die neue runs.csv."
    ;;

  start)
    [ -n "$run" ] || die "Aufruf: case.sh start <run-id>   z. B. sonnet-whole-r1"
    need_clean; need_tag; need_identity
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
    b="run/$run"
    if [ "$(p branch --show-current)" != "$b" ]; then
      # Lauf wurde auf einem anderen Rechner gebaut (oder ein anderer Branch ist ausgecheckt): holen.
      need_clean
      p fetch -q origin "+refs/heads/$b:refs/remotes/origin/$b" || die "run/$run nicht auf origin gefunden"
      if p rev-parse -q --verify "refs/heads/$b" >/dev/null; then
        p switch -q "$b"; p merge -q --ff-only "origin/$b"
      else
        p switch -q -c "$b" --track "origin/$b"
      fi
    fi
    need_clean; need_tag
    [ -n "$(p rev-list "$TAG..$b")" ] || die "$b hat noch keine Commits nach $TAG (erst bauen, dann 'case.sh finish $run')"
    clean_runtime " "
    echo "Bereit für den Check: tools/agent.sh check $run"
    ;;

  finish)
    [ -n "$run" ] || die "Aufruf: case.sh finish <run-id>"
    [ "$(p branch --show-current)" = "run/$run" ] || die "Projekt ist nicht auf run/$run"
    need_identity
    # 1) Projekt: Lauf committen und auf softwareprojekt.git pushen
    p add -A
    if p diff --cached --quiet; then echo "Projekt: nichts Neues zu committen."
    elif p diff --cached --name-only | grep -q '^tdd/check-'; then p commit -q -m "check $run"
    else p commit -q -m "run $run"
    fi
    p push -q -u origin "run/$run"
    # 2) TDDev: Ergebnisse nach results/<run-id>/ kopieren. Vorher den Stand von origin holen,
    #    damit zwei Rechner (z. B. Mac und Linux) in dieselbe Tabelle schreiben können.
    t pull -q --rebase --autostash || echo "Hinweis: 'git pull --rebase' im TDDev-Repo fehlgeschlagen (offline?), es geht mit dem lokalen Stand weiter."
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
      # Keine Transkripte gefunden (falscher Rechner, falsches Profil): nichts eintragen statt 0 Tokens.
      if [ "$(tr -d '[:space:]' < "$dest/tokens.json")" = "{}" ]; then
        rm -f "$dest/tokens.json"
        echo "WARNUNG: keine Transkripte der Bau-Session gefunden, tok_* bleiben leer. 'finish' auf dem Rechner ausführen, auf dem gebaut wurde."
      fi
    fi
    [ -f "$dest/tokens.json" ] && tok="$(cat "$dest/tokens.json")"
    python3 - "$CSV" "$run" "$dest" "$tok" "$TASK" <<'EOF'
import csv, glob, json, os, sys
path, run, dest, tok, task = sys.argv[1:]
with open(path, newline="") as f:
    rows = list(csv.DictReader(f)); f.seek(0); header = next(csv.reader(f))
row = next((r for r in rows if r["run_id"] == run), None)
if row is None:
    row = dict.fromkeys(header, ""); parts = run.split("-")
    if task != "t1" and parts[0] == task: parts = parts[1:]
    if len(parts) == 3 and parts[2].startswith("r"):
        row.update(agent=parts[0], approach=parts[1], repeat=parts[2][1:])
    row["run_id"] = run; rows.append(row)
if "task" in row and not row["task"]: row["task"] = task
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
    sed -n '2,16p' "$0"; exit 1 ;;
esac
