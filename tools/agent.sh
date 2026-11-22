#!/usr/bin/env bash
# Startet die Agenten der Case Study in isolierten Profilen. Immer aus dem TDDev-Klon starten.
#
#   agent.sh setup                 einmal: Profile ~/.tdd-case/{claude,codex} anlegen, Antigravity einstellen
#   agent.sh login claude|codex    einmal: im isolierten Profil anmelden
#   agent.sh run   <run-id>        Bau-Session starten (Skill wird als erste Eingabe übergeben)
#   agent.sh check <run-id>        Check-Session starten (immer derselbe Prüfer, siehe CHECKER)
#   agent.sh doctor [agent...]     Smoke-Test: Skills sichtbar, Subagent öffnet die App mit Playwright
#
# Agenten, Modelle und Reasoning stehen in harness/agents.tsv.
#
# Zwei Aufgabenstellungen: "opus5.5-whole-r1" ist t1, "t2-opus5.5-whole-r1" ist t2 (eigener
# Ausgangsstand, eigener Projekt-Klon; siehe tools/case.sh). setup, login und doctor nehmen die
# Aufgabe aus TASK (Standard t1): TASK=t2 agent.sh doctor opus5.5
set -euo pipefail

TDDEV="$(cd "$(dirname "$0")/.." && pwd)"
CASE_HOME="${CASE_HOME:-$HOME/.tdd-case}"
CHECKER="${CHECKER:-opus5.5}"
AGENTS="$TDDEV/harness/agents.tsv"
export CLAUDE_CONFIG_DIR="$CASE_HOME/claude"
export CODEX_HOME="$CASE_HOME/codex"
export ENABLE_CLAUDEAI_MCP_SERVERS=false
# Claude-Code-Tools, die nichts mit Bauen und Testen zu tun haben (Paper: nur Lesen, Schreiben, Bash).
# Read/Write/Edit/Bash, Agent (Test-Subagent), Skill und ToolSearch (lädt Playwright-Tools) bleiben.
CLAUDE_DENY=(WebSearch WebFetch Artifact ArtifactComments ArtifactData DesignSync CronCreate CronDelete
  CronList RemoteTrigger PushNotification ScheduleWakeup Workflow ReportFindings EnterWorktree ExitWorktree)

die() { echo "Fehler: $*" >&2; exit 1; }

# Aufgabe einer run-id: Präfix "t<n>-", sonst t1.
task_of() { if [[ "$1" =~ ^(t[0-9]+)- ]]; then echo "${BASH_REMATCH[1]}"; else echo t1; fi; }

# Projekt-Klon einer Aufgabe (ohne zu prüfen, ob er existiert).
project_of() {
  if [ "$1" = t1 ]; then
    echo "${PROJECT:-$HOME/Desktop/Uni/3.Semester/Softwareprojekt/App/softwareprojekt}"
  else
    local up; up="$(echo "$1" | tr a-z A-Z)"
    local var="PROJECT_$up"
    echo "${!var:-$HOME/Desktop/Uni/3.Semester/Softwareprojekt/App-$up/softwareprojekt}"
  fi
}

# Setzt TASK, PROJECT und TAG für eine Aufgabe (wie use_task in case.sh).
use_task() {
  TASK="$1"
  [[ "$TASK" =~ ^t[0-9]+$ ]] || die "unbekannte Aufgabe '$TASK' (t1, t2, ...)"
  PROJECT="$(project_of "$TASK")"
  if [ "$TASK" = t1 ]; then TAG="tdd-baseline"; else TAG="tdd-baseline-$TASK"; fi
  [ -d "$PROJECT/.git" ] || die "kein Git-Repo unter $PROJECT (Aufgabe $TASK)"
}

# agent -> "harness model reasoning"
lookup() {
  local row; row="$(awk -F'\t' -v a="$1" '$1==a {print $2, $3, $4}' "$AGENTS")"
  [ -n "$row" ] || die "Agent '$1' fehlt in harness/agents.tsv"
  echo "$row"
}

# Startet einen Harness interaktiv im Projekt mit einer ersten Eingabe.
launch() {
  local agent="$1" prompt="$2" harness model reasoning
  read -r harness model reasoning <<<"$(lookup "$agent")"
  # Vanilla bekommt wie im Paper keine Test-Tools: kein Playwright.
  local mcp="$PROJECT/.mcp.json" pw=true
  if [ "$prompt" = tdd-vanilla ]; then mcp='{"mcpServers":{}}'; pw=false; fi
  cd "$PROJECT"
  case "$harness" in
    claude)
      exec claude --model "$model" --effort "$reasoning" \
        --strict-mcp-config --mcp-config "$mcp" --disallowedTools "${CLAUDE_DENY[@]}" \
        --dangerously-skip-permissions -- "/$prompt" ;;
    codex)
      exec codex -m "$model" -c "model_reasoning_effort=\"$reasoning\"" \
        -c "mcp_servers.playwright.enabled=$pw" "\$$prompt" ;;
    antigravity)
      if [ "$pw" = true ]; then agy mcp enable playwright >/dev/null; else agy mcp disable playwright >/dev/null; fi
      exec agy --model "$model" --dangerously-skip-permissions -i "/$prompt" ;;
    *) die "unbekannter Harness '$harness'" ;;
  esac
}

version_of() {
  case "$1" in
    claude) claude --version 2>/dev/null | head -1 ;;
    codex) codex --version 2>/dev/null | head -1 ;;
    antigravity) agy --version 2>/dev/null | head -1 ;;
  esac
}

# Hält Start, Modell und Harness-Version fest; tools/tokens.py liest den Startzeitpunkt.
write_launch() {
  local run="$1" kind="$2" agent="$3" harness model reasoning
  read -r harness model reasoning <<<"$(lookup "$agent")"
  local dest="$TDDEV/results/$run"; mkdir -p "$dest"
  {
    echo "kind: $kind"
    echo "task: $TASK"
    echo "agent: $agent"
    echo "harness: $harness"
    echo "model: $model"
    echo "reasoning: $reasoning"
    echo "version: $(version_of "$harness")"
    echo "started_utc: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo "branch: $(git -C "$PROJECT" branch --show-current)"
    echo "commit: $(git -C "$PROJECT" rev-parse HEAD)"
  } > "$dest/launch-$kind.txt"
}

need_branch() {
  [ "$(git -C "$PROJECT" branch --show-current)" = "run/$1" ] \
    || die "Projekt ist nicht auf run/$1 (zuerst 'case.sh start $1' bzw. 'case.sh check $1')"
}

cmd="${1:-}"
case "$cmd" in
  run|check) [ -n "${2:-}" ] && use_task "$(task_of "$2")" ;;
  setup|login|doctor) use_task "${TASK:-t1}" ;;
esac

case "$cmd" in
  setup)
    mkdir -p "$CLAUDE_CONFIG_DIR" "$CODEX_HOME"
    cp "$TDDEV/harness/claude-settings.json" "$CLAUDE_CONFIG_DIR/settings.json"
    {
      cat "$TDDEV/harness/codex-config.toml"
      # Alle vorhandenen Projekt-Klone (t1, t2, ...) für Codex als vertrauenswürdig eintragen.
      for tk in t1 t2 t3; do
        pd="$(project_of "$tk")"
        [ -d "$pd/.git" ] && printf '\n[projects."%s"]\ntrust_level = "trusted"\n' "$pd"
      done
      for s in "$HOME"/.agents/skills/*/SKILL.md; do
        [ -f "$s" ] && printf '\n[[skills.config]]\npath = "%s"\nenabled = false\n' "$s"
      done
    } > "$CODEX_HOME/config.toml"
    # Antigravity hat kein eigenes Profilverzeichnis: Plugin und fremde MCP-Server global aus,
    # Playwright (gleiche Version wie im Projekt) global an. Rückgängig: siehe README.
    pw_args="$(python3 -c "import json,sys;print(' '.join(json.load(open(sys.argv[1]))['mcpServers']['playwright']['args']))" "$PROJECT/.mcp.json")"
    agy plugin disable modern-web-guidance-plugin >/dev/null 2>&1 || true
    agy mcp disable xcodebuild >/dev/null 2>&1 || true
    agy mcp remove playwright >/dev/null 2>&1 || true
    # shellcheck disable=SC2086
    agy mcp add playwright -- npx $pw_args >/dev/null 2>&1 || echo "Hinweis: 'agy mcp add playwright -- npx $pw_args' bitte von Hand ausführen"
    echo "Profile angelegt: $CLAUDE_CONFIG_DIR, $CODEX_HOME. Jetzt 'agent.sh login claude' und 'agent.sh login codex'."
    ;;

  login)
    case "${2:-}" in
      # --strict-mcp-config: sonst fragt Claude Code nach den Servern aus .mcp.json und schreibt die
      # Antwort in die versionierte .claude/settings.local.json (der Arbeitsbaum wäre dann nicht sauber).
      claude) cd "$PROJECT"; echo "Ordner bestätigen, bei Bedarf /login ausführen, danach /exit."
              exec claude --strict-mcp-config --mcp-config '{"mcpServers":{}}' ;;
      codex) exec codex login ;;
      *) die "Aufruf: agent.sh login claude|codex" ;;
    esac
    ;;

  run)
    run="${2:-}"; [ -n "$run" ] || die "Aufruf: agent.sh run <run-id>   z. B. opus5.5-whole-r1"
    [[ "$run" =~ ^(t[0-9]+-)?([a-z0-9.]+)-(vanilla|whole|incremental|agentic)-r[0-9]+$ ]] || die "run-id '$run' hat nicht die Form [t<n>-]<agent>-<ansatz>-r<n>"
    agent="${BASH_REMATCH[2]}"; approach="${BASH_REMATCH[3]}"
    need_branch "$run"
    # Jeder Bau startet exakt auf dem Ausgangsstand, ohne Reste eines abgebrochenen Laufs.
    [ "$(git -C "$PROJECT" rev-parse HEAD)" = "$(git -C "$PROJECT" rev-parse "$TAG^{commit}")" ] \
      || die "run/$run ist nicht mehr auf $TAG (Lauf schon gemacht?)"
    [ -z "$(git -C "$PROJECT" status --porcelain --ignore-submodules=untracked)" ] \
      || die "Projekt hat Änderungen (abgebrochener Lauf?). Neu aufsetzen: git -C \"$PROJECT\" reset --hard && tools/case.sh start $run"
    write_launch "$run" run "$agent"
    launch "$agent" "tdd-$approach"
    ;;

  check)
    run="${2:-}"; [ -n "$run" ] || die "Aufruf: agent.sh check <run-id>"
    need_branch "$run"
    write_launch "$run" check "$CHECKER"
    launch "$CHECKER" "tdd-check $run"
    ;;

  doctor)
    shift
    [ $# -gt 0 ] || set -- $(awk -F'\t' '!/^#/ {print $1}' "$AGENTS")
    # MAIN_PROFILE=1: mit den normalen Profilen testen (nur zur Fehlersuche, nicht isoliert)
    [ "${MAIN_PROFILE:-0}" = 1 ] && unset CLAUDE_CONFIG_DIR CODEX_HOME
    cd "$PROJECT"
    [ -d node_modules ] || bun install --frozen-lockfile >/dev/null
    out="$(mktemp -d)"
    bun tdd/mock-servers/start.ts >"$out/app.log" 2>&1 &
    app=$!
    trap 'kill $app 2>/dev/null; wait $app 2>/dev/null; rm -rf "$PROJECT/.playwright-mcp"' EXIT
    for _ in $(seq 1 60); do curl -fs -o /dev/null http://localhost:3030 && break; sleep 1; done
    curl -fs -o /dev/null http://localhost:3030 || die "App antwortet nicht auf :3030 (Log: $out/app.log)"
    P='Smoke test, do not modify any file. (1) List the names of all skills available to you whose name starts with "tdd-". (2) Spawn ONE subagent with an empty context and give it only this task: "Open http://localhost:3030 with the Playwright browser tool, read the accessibility snapshot and return the page title and the text of the first heading." Do not open the page yourself. (3) Reply with exactly one line of JSON and nothing else: {"skills": [...], "subagent_used": true or false, "title": "...", "heading": "..."}'
    for agent in "$@"; do
      read -r harness model reasoning <<<"$(lookup "$agent")"
      echo "== $agent ($harness, $model, $reasoning)"
      case "$harness" in
        claude) claude -p "$P" --model "$model" --effort "$reasoning" --strict-mcp-config \
                  --mcp-config "$PROJECT/.mcp.json" --disallowedTools "${CLAUDE_DENY[@]}" \
                  --dangerously-skip-permissions ;;
        codex) codex exec -m "$model" -c "model_reasoning_effort=\"$reasoning\"" \
                 -o "$out/$agent.txt" "$P" >"$out/$agent.log" 2>&1; cat "$out/$agent.txt" ;;
        antigravity) agy mcp enable playwright >/dev/null; agy -p "$P" --model "$model" --dangerously-skip-permissions ;;
      esac 2>&1 | tail -5
    done
    git -C "$PROJECT" status --short
    ;;

  *) sed -n '2,14p' "$0"; exit 1 ;;
esac
