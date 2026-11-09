#!/usr/bin/env bash
# Git-Ablauf der Case Study über zwei Repos:
#   Projekt-Repo (App-Code, ein Branch pro Lauf)  -> $PROJECT, Remote "origin"
#   TDDev-Repo   (Ergebnisse unter results/)       -> dieses Repo, Remote "origin"
#
#   tools/case.sh freeze            Baseline einfrieren: tdd/ committen, Tag tdd-baseline, pushen
#   tools/case.sh start  <run-id>   Branch run/<run-id> vom Tag tdd-baseline anlegen und auschecken
#   tools/case.sh finish <run-id>   Lauf committen + pushen, Ergebnisse ins TDDev-Repo kopieren + pushen
#                                   (nach dem Bauen und nochmal nach dem Check aufrufen)
set -euo pipefail

TDDEV="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT="${PROJECT:-$HOME/Desktop/Uni/3.Semester/Softwareprojekt/App/softwareprojekt}"
BASE_BRANCH="${BASE_BRANCH:-TDDev-origin}"
TAG="tdd-baseline"

die() { echo "Fehler: $*" >&2; exit 1; }
p() { git -C "$PROJECT" "$@"; }
t() { git -C "$TDDEV" "$@"; }

cmd="${1:-}"; run="${2:-}"

case "$cmd" in
  freeze)
    [ "$(p branch --show-current)" = "$BASE_BRANCH" ] || die "im Projekt zuerst '$BASE_BRANCH' auschecken"
    grep -q 'Please implement \.\.\.' "$PROJECT/tdd/requirement.md" && die "tdd/requirement.md ist noch nicht ausgefüllt"
    grep -q 'ANLEITUNG' "$PROJECT/tdd/requirement.md" && die "Anleitungs-Kommentar in tdd/requirement.md noch löschen"
    python3 -c "import json,sys; json.load(open(sys.argv[1]))" "$PROJECT/tdd/tests.json" || die "tdd/tests.json ist kein gültiges JSON"
    p rev-parse -q --verify "refs/tags/$TAG" >/dev/null && die "Tag $TAG existiert schon (Baseline ist bereits eingefroren)"
    p add -A
    p diff --cached --quiet || p commit -m "TDD case study baseline"
    p tag "$TAG"
    p push -u origin "$BASE_BRANCH"
    p push origin "$TAG"
    echo "Baseline eingefroren: $BASE_BRANCH @ $(p rev-parse --short HEAD), Tag $TAG gepusht."
    ;;

  start)
    [ -n "$run" ] || die "Aufruf: case.sh start <run-id>   z. B. sonnet-whole-r1"
    [ -z "$(p status --porcelain)" ] || die "Projekt hat uncommittete Änderungen"
    p rev-parse -q --verify "refs/tags/$TAG" >/dev/null || die "Tag $TAG fehlt, zuerst 'case.sh freeze'"
    p switch -c "run/$run" "$TAG"
    echo "Auf run/$run (ab $TAG). Jetzt neue Session im Projekt öffnen und den Skill aufrufen."
    ;;

  finish)
    [ -n "$run" ] || die "Aufruf: case.sh finish <run-id>"
    [ "$(p branch --show-current)" = "run/$run" ] || die "Projekt ist nicht auf run/$run"
    # 1) Projekt: Lauf committen und auf softwareprojekt.git pushen
    p add -A
    if p diff --cached --quiet; then echo "Projekt: nichts Neues zu committen."
    else
      if p diff --cached --name-only | grep -q '^tdd/check-'; then
        p commit -m "check $run"
      else
        p commit -m "run $run"
      fi
    fi
    p push -u origin "run/$run"
    # 2) TDDev: Ergebnisse nach results/<run-id>/ kopieren und pushen
    dest="$TDDEV/results/$run"; mkdir -p "$dest"
    for f in "$PROJECT"/tdd/tdd-log.jsonl "$PROJECT"/tdd/check-*.json; do
      [ -f "$f" ] && cp "$f" "$dest/"
    done
    printf 'branch: run/%s\ncommit: %s\nrepo: %s\n' "$run" "$(p rev-parse HEAD)" "$(p remote get-url origin)" > "$dest/source.txt"
    t add results
    t diff --cached --quiet || t commit -m "results $run"
    t push
    echo "Fertig: run/$run gepusht, Ergebnisse in results/$run/ gepusht."
    echo "Nicht vergessen: Tokens/Check-Werte in results/runs.csv eintragen, dann 'case.sh csv'."
    ;;

  csv)
    t add results/runs.csv
    t diff --cached --quiet && { echo "runs.csv unverändert."; exit 0; }
    t commit -m "update runs.csv"
    t push
    ;;

  *)
    sed -n '2,9p' "$0"; exit 1 ;;
esac
