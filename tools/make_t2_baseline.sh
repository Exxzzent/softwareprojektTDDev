#!/usr/bin/env bash
# make_t2_baseline.sh <projekt-repo> <requirement-2.md> <tests-2.json>  -> gibt die Commit-ID aus
set -euo pipefail
repo="$1"; req="$2"; tests="$3"
export GIT_INDEX_FILE; GIT_INDEX_FILE="$(mktemp -t t2index)"; rm -f "$GIT_INDEX_FILE"
g() { git -C "$repo" "$@"; }
g read-tree "tdd-baseline^{tree}"
g update-index --force-remove references/gartenbahn-mockup.html
g update-index --cacheinfo "100644,$(g hash-object -w "$req"),tdd/requirement.md"
g update-index --cacheinfo "100644,$(g hash-object -w "$tests"),tdd/tests.json"
tree="$(g write-tree)"
g commit-tree "$tree" -m "TDD case study baseline (task t2)

Co-Authored-By: Claude Fable 5.2 <noreply@anthropic.com>"
rm -f "$GIT_INDEX_FILE"
