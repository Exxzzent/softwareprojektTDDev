# softwareprojektTDDev

Fünf Agent Skills für eine Case Study zu den vier TDD-Ansätzen aus dem Paper *From Runnable Code
to Shippable Applications* (Wan et al., ASE '26), plus ein Skript für die Metriken des Papers.
Die Skills laufen in Claude Code, Codex und Antigravity.

| Skill | Ansatz | Ablauf |
| --- | --- | --- |
| `tdd-whole` | Whole-Project TDD | alles bauen, dann bis zu 5 Runden: App starten → alle Tests im Browser → reparieren |
| `tdd-incremental` | Incremental TDD | Feature für Feature; pro Feature bis zu 5 Runden über das aktuelle und alle bereits akzeptierten Features |
| `tdd-agentic` | Agentic TDD | bauen und testen, wann der Agent es für sinnvoll hält (Notbremse: 25 Testläufe) |
| `tdd-vanilla` | Vanilla (ohne TDD) | nur bauen, kein Start, kein Test; Vergleichsbasis |
| `tdd-check` | Unabhängiger Check | prüft die fertige App in einer neuen Session und liefert die Accuracy |

## Kurzablauf

1. **Einmal einrichten:** Skills und Playwright installieren (Abschnitt 2).
2. **Einmal vorbereiten:** im Projekt `tdd/requirement.md`, `tdd/tests.json` und `tdd/app.md`
   ausfüllen und einfrieren (Abschnitt 3).
3. **Pro Lauf:** frischen Branch anlegen → neue Session → `/tdd-whole` (bzw. ein anderer Ansatz)
   → warten → Tokens notieren (Abschnitt 4).
4. **Pro Lauf prüfen:** neue Session → `/tdd-check <lauf-name>` → Ergebnis in `runs.csv`
   eintragen (Abschnitt 5).
5. **Am Ende auswerten:** `python3 tools/metrics.py summary runs.csv` (Abschnitt 6).

Die Anforderung allein reicht nicht: Die Ansätze arbeiten gegen feste Akzeptanztests. Ohne
`tdd/tests.json` gibt es nichts, wogegen gebaut, getestet und geprüft wird.

## 1. Was liegt wo

| Ort | Inhalt | Wer liest es |
| --- | --- | --- |
| `skills/<name>/SKILL.md` | die fünf Skills | der Agent |
| `templates/tdd/requirement.md` | Vorlage: was gebaut werden soll | der Agent (nach dem Ausfüllen) |
| `templates/tdd/tests.json` | Vorlage: Akzeptanztests | der Agent und der Check |
| `templates/tdd/app.md` | Vorlage: App starten/stoppen, URL, Stack | der Agent und der Check |
| `templates/runs.csv` | Ergebnistabelle, eine Zeile pro Lauf | `tools/metrics.py` |
| `tools/metrics.py` | rechnet alle Metriken aus | wird von Hand ausgeführt |
| `THIRD_PARTY_NOTICES.md` | MIT-Lizenzhinweis von TDDev | — |

Was ein Lauf im Projekt erzeugt:

| Datei | Erzeugt von | Inhalt |
| --- | --- | --- |
| `tdd/tdd-log.jsonl` | `tdd-whole`, `tdd-incremental`, `tdd-agentic`, `tdd-vanilla` | jede Testrunde und jedes Urteil des bauenden Agenten |
| `tdd/check-<zeitstempel>.json` | `tdd-check` | Urteil pro Test und Accuracy |

## 1a. Zwei Repos: was wohin gehört

| Repo | Inhalt | Sieht der Agent? |
| --- | --- | --- |
| `softwareprojekt.git` | App-Gerüst, `tdd/`, `.claude/skills/`, `.agents/skills/`, Settings. Branch `TDDev-origin` = Ausgangsstand, Tag `tdd-baseline`; pro Lauf ein Branch `run/<run-id>` | ja, das ist sein Projekt |
| `softwareprojektTDDev.git` (dieses Repo) | Skill-Quellen, Vorlagen, `tools/case.sh`, `tools/metrics.py`, Ergebnisse unter `results/` | nein, nur du |

Die Skills lesen und schreiben nur Dateien in `tdd/` des Projekts (`requirement.md`, `tests.json`,
`app.md` lesen; `tdd-log.jsonl` bzw. `check-*.json` schreiben). Vorlagen und Skripte braucht der
Agent nie; sie bleiben deshalb aus dem Ausgangsstand heraus. Die Git-Arbeit macht `tools/case.sh`,
nicht der Skill: Git-Befehle in der Bau-Session würden Tokens kosten und die Messung verfälschen.

```bash
C=~/Desktop/Code/Skills/softwareprojektTDDev/tools/case.sh
A=~/Desktop/Code/Skills/softwareprojektTDDev/tools/agent.sh
$A setup                           # einmal: isolierte Profile anlegen (Abschnitt 2.0)
$A login claude; $A login codex    # einmal: in den isolierten Profilen anmelden
$A doctor                          # einmal: Smoke-Test aller Agenten (Skills, Subagent, Playwright)
$C freeze                          # einmal: Baseline committen, Tag tdd-baseline, pushen
$C branches 2 opus5.5 fable5.2 sonnet5.5 gpt6.1sol gpt6.1terra gemini3.8flash   # einmal

# pro Lauf
$C start  opus5.5-whole-r1         # auf run/opus5.5-whole-r1, Arbeitsbaum leeren, bun install
$A run    opus5.5-whole-r1         # Bau-Session startet mit /tdd-whole; warten, dann Session beenden
$C finish opus5.5-whole-r1         # Code + Log pushen, Tokens aus den Transkripten in runs.csv
$C check  opus5.5-whole-r1         # Arbeitsbaum leeren, bun install
$A check  opus5.5-whole-r1         # Check-Session (fester Prüfer) startet mit /tdd-check
$C finish opus5.5-whole-r1         # Check pushen, Accuracy in runs.csv
$C csv
```

- `start` verweigert einen Branch, der schon Commits nach `tdd-baseline` hat, und läuft nur bei
  sauberem Arbeitsbaum. `start` und `check` löschen alles, was nicht im Git liegt
  (`git clean -fdx`: `node_modules`, gebautes CSS, DB, Playwright-Reste), setzen das Submodul
  `references/ise-server` zurück und installieren die Dependencies frisch aus dem Lockfile.
  So erbt kein Lauf etwas vom vorherigen.
- `finish` direkt nach dem Bauen, vor `check`: nur dann zählt `tools/tokens.py` ausschließlich
  die Bau-Session (inklusive Test-Subagenten). `check` verlangt einen sauberen Baum und erzwingt
  das.
- `finish` trägt in `runs.csv` nur leere Felder ein und nimmt immer den **ersten** Check.
- Agent-Namen nur aus Kleinbuchstaben, Ziffern und Punkt (z. B. `gpt5.1`), ohne Bindestrich.
- Projektpfad über `PROJECT=...` änderbar (Aufgabe t2: `PROJECT_T2=...`).
- Auswertung: `python3 tools/metrics.py summary results/runs.csv`.

## 1b. Zwei Aufgabenstellungen (t1, t2)

Die Case Study hat zwei Aufgabenstellungen. Beide liegen zum Vergleich unter `tasks/`
(Unterschiede: `tasks/README.md`); der Agent sieht dieses Repo nie.

| | t1: Folgefahrt mit Mockup | t2: Gegenverkehr ohne Mockup |
| --- | --- | --- |
| Anforderung, Tests | `tasks/requirement-1.md`, `tasks/tests-1.json` | `tasks/requirement-2.md`, `tasks/tests-2.json` |
| Ausgangsstand im Projekt-Repo | Branch `TDDev-origin`, Tag `tdd-baseline` | Branch `TDDev-origin-t2`, Tag `tdd-baseline-t2` (ein Commit ohne Vorgänger) |
| run-id | `opus5.5-whole-r1` | `t2-opus5.5-whole-r1` |
| Lauf-Branch | `run/opus5.5-whole-r1` | `run/t2-opus5.5-whole-r1` |
| Projekt-Klon (`PROJECT` / `PROJECT_T2`) | `…/Softwareprojekt/App/softwareprojekt` | `…/Softwareprojekt/App-T2/softwareprojekt` |
| `task` in `runs.csv` | `t1` | `t2` |

- Im Projekt heißen die Dateien in beiden Aufgaben `tdd/requirement.md` und `tdd/tests.json`,
  weil die Skills genau diese Namen lesen. Der t2-Ausgangsstand ist bis auf diese beiden Dateien
  und das entfernte Mockup identisch mit `tdd-baseline` (gleiche Skills, `tdd/app.md`,
  Mock-Server, Lockfile).
- t2 läuft in einem eigenen Klon, der nur die t2-Branches holt. So liegen die alte Anforderung,
  das Mockup und die t1-Lösungen dort nicht vor:

  ```bash
  git clone --single-branch --branch TDDev-origin-t2 --no-tags \
    https://github.com/Exxzzent/softwareprojekt.git ~/Desktop/Uni/3.Semester/Softwareprojekt/App-T2/softwareprojekt
  cd ~/Desktop/Uni/3.Semester/Softwareprojekt/App-T2/softwareprojekt
  git config --replace-all remote.origin.fetch '+refs/heads/TDDev-origin-t2:refs/remotes/origin/TDDev-origin-t2'
  git config --add remote.origin.fetch '+refs/heads/run/t2-*:refs/remotes/origin/run/t2-*'
  git config remote.origin.tagOpt --no-tags
  git fetch origin tag tdd-baseline-t2 --no-tags && git submodule update --init
  git config user.email "<dieselbe E-Mail wie in diesem Repo: git config user.email>"
  ```

  Ohne die letzte Zeile committet der neue Klon mit der globalen Adresse. Ist die bei GitHub als
  privat geschützt, wird der Push am Ende des Laufs abgelehnt (GH007). `case.sh start` und
  `finish` brechen deshalb ab, wenn die E-Mail im Projekt-Klon von der in diesem Repo abweicht.

- Die Befehle sind dieselben; die Aufgabe steckt in der run-id:

  ```bash
  TASK=t2 $C branches 2 opus5.5 sonnet5.5 gpt6.1terra   # einmal: run/t2-…-Branches + Zeilen in runs.csv
  $C start  t2-opus5.5-whole-r1
  $A run    t2-opus5.5-whole-r1
  $C finish t2-opus5.5-whole-r1
  $C check  t2-opus5.5-whole-r1
  $A check  t2-opus5.5-whole-r1
  $C finish t2-opus5.5-whole-r1
  ```

- `setup`, `login` und `doctor` nehmen die Aufgabe aus `TASK` (Standard `t1`), z. B.
  `TASK=t2 $A doctor opus5.5`.
- `tools/metrics.py summary` rechnet jede Aufgabe für sich: Δ und CostEff immer gegen das
  Vanilla desselben Agenten in derselben Aufgabe.

### Zweiter Rechner (z. B. Codex auf Linux)

- Voraussetzungen auf dem zweiten Rechner: `git`, `bash`, `python3`, Node.js ≥ 18, `bun`, die
  Harness-CLI (z. B. `codex`) und der Browser für Playwright
  (`npx -y playwright install --with-deps chromium`).
- Auf dem zweiten Rechner: dieses Repo und den t2-Klon holen (`PROJECT_T2=<pfad>` setzen, wenn der
  Pfad abweicht), in beiden Klonen die GitHub-No-Reply-Adresse setzen
  (`git config user.email <id>+<name>@users.noreply.github.com`), `TASK=t2 $A setup`, `$A login codex`, `TASK=t2 $A doctor gpt6.1terra`.
  `doctor` muss die fünf `tdd-`Skills, `subagent_used: true` und den Seitentitel melden; erst
  dann zählt ein Lauf.
- Bauen dort: `$C start <run-id>` → `$A run <run-id>` → `$C finish <run-id>`. `finish` zählt die
  Tokens aus den Transkripten **dieses** Rechners und pusht Lauf-Branch und Ergebnisse.
- Prüfen auf dem Rechner mit dem festen Prüfer: `$C check <run-id>` holt den Lauf-Branch von
  GitHub, wenn er lokal fehlt, danach `$A check <run-id>` und `$C finish <run-id>`.
- `finish` holt vor dem Schreiben den Stand des Ergebnis-Repos (`git pull --rebase`), damit beide
  Rechner in dieselbe `runs.csv` schreiben können.
- Pro Rechner läuft immer nur eine Session: App, Mock-Server und Konsole haben feste Ports
  (3030, 3031, 8095, 8076–8078).

## 2. Setup (einmal pro Rechner)

### 2.0 Isolierte Profile (`tools/agent.sh`)

Damit nur die Case-Study-Skills und Playwright auf den Agenten wirken, laufen alle Sessions über
`tools/agent.sh`, nie über die Desktop-Apps (die bringen eigene Tools, Konnektoren und Skills mit).

| Harness | Isolation |
| --- | --- |
| Claude Code | eigenes `CLAUDE_CONFIG_DIR=~/.tdd-case/claude` (keine Plugins, Hooks, User-Skills, Memory, claude.ai-Konnektoren), `--strict-mcp-config --mcp-config .mcp.json` (nur Playwright), `--model`, `--effort`, `--dangerously-skip-permissions`; gesperrt: Websuche/WebFetch und Account-Tools (Artifact, Cron, Workflow, RemoteTrigger …, Liste `CLAUDE_DENY` in `agent.sh`) |
| Codex | eigenes `CODEX_HOME=~/.tdd-case/codex` (Memories, Plugins, Hooks aus; Skills aus `~/.agents/skills` einzeln abgeschaltet; `multi_agent` an), Apps/Konnektoren, Browser-Use, Computer-Use, Bildgenerierung, Goals und Websuche aus; `approval_policy = never`, `sandbox_mode = danger-full-access`; Playwright aus `.codex/config.toml` des Projekts |
| Antigravity (`agy`) | kein eigenes Profilverzeichnis: `setup` schaltet global das Plugin `modern-web-guidance-plugin` und den MCP-Server `xcodebuild` ab und trägt Playwright ein. Rückgängig: `agy plugin enable modern-web-guidance-plugin`, `agy mcp enable xcodebuild`, `agy mcp remove playwright`. Antigravitys eigenes Gedächtnis (Knowledge/Implicit) lässt sich nicht abschalten; Restrisiko |

Agenten, Modell-IDs und Reasoning stehen in `harness/agents.tsv` (alle `medium`). Playwright MCP
ist überall auf dieselbe Version fest eingestellt (`@playwright/mcp@0.0.85 --isolated`: frisches
Browserprofil pro Server, keine Cookies zwischen Läufen). Prüfer für alle Checks: `CHECKER`
(Standard `opus5.5`).

`agent.sh run` schreibt `results/<run-id>/launch-run.txt` (Harness-Version, Modell, Startzeit,
Commit). `--dangerously-skip-permissions` bzw. `danger-full-access` sind nötig, damit die Läufe
ohne Rückfragen durchlaufen wie der Agent im Paper; der Agent hat damit vollen Zugriff auf den
Rechner.

### 2.1 Voraussetzungen

- Node.js ≥ 18 (für Playwright MCP): `node --version`
- Python 3 (für `tools/metrics.py`, keine Pakete nötig): `python3 --version`

### 2.2 Skills installieren

Die fünf Ordner aus `skills/` werden dorthin kopiert, wo der Harness Skills sucht:

| Harness | Ort |
| --- | --- |
| Claude Code | pro Projekt `<projekt>/.claude/skills/`, oder für alle Projekte `~/.claude/skills/` |
| Codex | Skills-Ordner laut Codex-Doku der installierten Version |
| Antigravity | Skills-Ordner laut Antigravity-Doku der installierten Version |

Claude Code, im Projektordner:

```bash
mkdir -p .claude/skills && cp -R ~/Desktop/Code/Skills/softwareprojektTDDev/skills/* .claude/skills/
```

Alternativ den Agenten in einer Session bitten: „Kopiere die Ordner aus
`~/Desktop/Code/Skills/softwareprojektTDDev/skills/` in den Skills-Ordner dieses Projekts.“
Danach eine neue Session öffnen, damit die Skills geladen sind.

Die Skills nutzen im Kopf nur `name` und `description` (gemeinsames Agent-Skills-Format). Die
Ordnerpfade für Codex und Antigravity sind nicht verifiziert.

### 2.3 Browser-Tool (Playwright MCP)

Nötig für `tdd-whole`, `tdd-incremental`, `tdd-agentic` und `tdd-check`. `tdd-vanilla` braucht
keinen Browser.

Claude Code:

```bash
claude mcp add playwright npx @playwright/mcp@latest
```

Kontrolle: in Claude Code `/mcp` öffnen; `playwright` muss als verbunden erscheinen.

- **Codex:** Playwright MCP als MCP-Server eintragen (`codex mcp add` oder Codex-Config), Befehl
  `npx @playwright/mcp@latest`. Genaue Syntax laut Codex-Doku.
- **Antigravity:** eingebauter Browser-Agent oder Playwright MCP über die MCP-Einstellungen. Der
  Agent muss Seiten öffnen, klicken, tippen und den Seiteninhalt lesen können.

Falls Playwright meldet, dass ein Browser fehlt:

```bash
npx playwright install chromium
```

Vanilla-Läufe startet `agent.sh run` automatisch ohne Playwright (wie im Paper: keine
Test-Tools).

## 3. Projekt vorbereiten (einmal pro Case Study)

### 3.1 Vorlagen kopieren

Im Projektordner:

```bash
cp -R ~/Desktop/Code/Skills/softwareprojektTDDev/templates/tdd ./tdd
```

### 3.2 `tdd/requirement.md`: was gebaut werden soll

Die Datei enthält eine Anleitung als Kommentar; der Kommentar wird vor dem ersten Lauf gelöscht.
Kurzfassung, nach dem Vorbild der 101 Benchmark-Aufgaben des Papers:

- 3 bis 8 Sätze, typisch 4 Sätze, etwa 70 Wörter, Englisch.
- Satz 1: was gebaut wird („Please implement a … that …“).
- Satz 2–3: was es können muss. Satz 4: was Nutzer damit tun. Optional ein Satz zum Aussehen.
- Keine Technik und keine Testschritte; die gehören in `app.md` bzw. `tests.json`.

### 3.3 `tdd/tests.json`: die Akzeptanztests

- 4 bis 11 Tests, typisch 6 (wie im Benchmark).
- Ein Test pro unterscheidbarem Verhalten. Dazu gehören auch Navigation zwischen Bereichen,
  geforderte visuelle Eigenschaften, reine Anzeige-Zustände und Verhalten, das die Anforderung
  nur andeutet. Breite statt Varianten desselben Tests.
- Feste Eingabewerte: `testuser@example.com`, `Test@1234`, „Test User“, „Test Item“.
- Die Reihenfolge der Tests ist bei `tdd-incremental` die Bau-Reihenfolge.

Format pro Test:

```json
{"test_id": "TC-01", "feature": "Add a task",
 "steps": ["Open the app", "Fill 'Test Item' in the task input", "Click the Add button"],
 "expected": "'Test Item' appears in the task list"}
```

Die Tests können von Hand geschrieben oder von einem Modell entworfen und dann geprüft werden.
Im Paper werden generierte Tests vor der Entwicklung vom Nutzer geprüft.

Optional: `tdd/oracle-tests.json` mit eigenen Tests nur für den Check. Ohne diese Datei prüft
`tdd-check` gegen `tdd/tests.json`.

### 3.4 `tdd/app.md`: wie die App läuft

Startbefehl, Stopp, URL, Port, Stack, Einstiegsdatei. Alle Skills lesen nur hier, wie die App
gestartet wird.

### 3.5 Einfrieren

Der Ausgangsstand enthält **keinen App-Code**: nur `tdd/` und höchstens ein Gerüst, das für alle
Läufe gleich ist (z. B. `.gitignore`). Im Paper beginnt jeder Lauf in einem leeren Projekt.
Enthält der Ausgangsstand schon Teile der Features, bauen alle Ansätze darauf auf, und die
Unterschiede zwischen ihnen verschwimmen. Wenn die Case Study in einem bestehenden Projekt läuft,
die App in einen eigenen, leeren Ordner bzw. ein eigenes Repo legen.

Ab hier ändert sich nichts mehr in `tdd/`. Ausgangsstand festhalten:

```bash
git add tdd && git commit -m "TDD case study baseline" && git tag tdd-baseline
```

### 3.6 Check einmal testen

Eine Version der App bauen, in der absichtlich ein Feature kaputt ist, und `tdd-check` darauf
laufen lassen. Der Check muss den Fehler finden. Im Paper findet der Tester 100 % der
eingebauten Fehler; zu strenge Urteile sind weniger schlimm als übersehene Fehler.

## 4. Einen Lauf durchführen

Ein Lauf = ein Agent × ein Ansatz × eine Wiederholung. Name: `<agent>-<ansatz>-r<n>`, z. B.
`claude-whole-r1`.

1. Frischen Branch vom Ausgangsstand anlegen:

   ```bash
   git switch -c run/claude-whole-r1 tdd-baseline
   ```

2. Neue Session im Harness öffnen, im Projektordner.
3. Skill aufrufen, ohne weiteren Text:
   - Claude Code: `/tdd-whole`
   - Codex / Antigravity: Skill per Name aufrufen, z. B. „Use the tdd-whole skill.“
4. Warten, bis der Agent fertig ist. Nicht eingreifen.
5. **Vor dem Schließen der Session** Tokens ablesen (Abschnitt 6.2) und in `runs.csv` eintragen.
6. Ergebnis sichern:

   ```bash
   git add -A && git commit -m "run claude-whole-r1"
   ```

Für jeden Agenten und jeden Ansatz wiederholen. Beispiel: 3 Agenten × 4 Ansätze × 2
Wiederholungen = 24 Läufe.

## 5. Den Check durchführen

Pro Lauf, nach dem Bauen:

1. Auf den Branch des Laufs wechseln: `git switch run/claude-whole-r1`
2. Neue Session öffnen, **immer im gleichen Harness mit dem gleichen Modell**, egal welcher Agent
   gebaut hat. Im Paper bewertet ein fester Prüfer alle Apps; ein wechselnder Prüfer würde die
   Prüfer vergleichen statt der Ansätze.
3. `/tdd-check claude-whole-r1` aufrufen.
4. Ausgabe: eine Tabelle pro Test, die Accuracy, die Datei `tdd/check-<zeitstempel>.json` und
   eine Zeile `n_pass,n_partial,n_fail,n_valid,accuracy`. Diese Werte kommen in `runs.csv`.
5. Gewertet wird der **erste** Check, wie im Paper ein einziger Durchlauf des festen Prüfers.
   Optional (nicht im Paper): ein zweiter Check als Angabe zur Zuverlässigkeit des Prüfers, weil
   die Harnesses keine Temperatur 0 erlauben. Abweichende Tests kommen in `notes`, die Wertung
   bleibt beim ersten Check.

Die Tokens des Checks zählen nicht zu den Kosten des Ansatzes.

## 6. Metriken

### 6.1 Übersicht

| Metrik | Paper | Quelle | Befehl |
| --- | --- | --- | --- |
| Accuracy pro Lauf | Gl. 1 | `tdd/check-*.json` | `python3 tools/metrics.py check tdd/check-*.json` |
| Δ zu Vanilla | RQ2 | `runs.csv` | `python3 tools/metrics.py summary runs.csv` |
| Bootstrap-KI, Wilcoxon-Test | Sec. 4.5.2 | `runs.csv` | `summary` |
| Tokens, Kosten-Effizienz | Gl. 2 | Token-Anzeige des Harness → `runs.csv` | `summary` |
| acc@k, Accuracy pro Runde | Tabelle 8 | `tdd/tdd-log.jsonl` | `python3 tools/metrics.py loop tdd/tdd-log.jsonl` |
| Fail-, Admission-, Abandonment-, Regression-Rate | Tabelle 7 | `tdd/tdd-log.jsonl` | `loop` |

### 6.2 Tokens ablesen

Gezählt wird nur die Session, in der gebaut wurde, einschließlich der Test-Subagenten: Im Paper
gehören Entwicklung und Testen im Loop zu den Bau-Tokens, nur der abschließende Check nicht. Die
vier Werte werden getrennt in `runs.csv` eingetragen; das Skript summiert sie:

$$\mathrm{Tok} = \text{input} + \text{cache read} + \text{cache write} + \text{output}$$

Abweichung vom Paper: Dort ist Tok „input and output tokens“; im Referenzcode sind das die
ungecachten Input-Token plus Output, Cache-Reads fallen weg (gecacht wird dort nur der kurze
System-Prompt). In Claude Code und Codex machen Cache-Reads den Großteil des verarbeiteten
Kontexts aus, deshalb zählen sie hier mit. Die absoluten Werte sind so nicht mit Tabelle 9 des
Papers vergleichbar, der Vergleich der Ansätze untereinander bleibt gültig.

| Harness | Wo |
| --- | --- |
| Claude Code, Codex über `agent.sh` | automatisch: `case.sh finish` ruft `tools/tokens.py` auf, das alle Modellaufrufe (Haupt-Agent und Subagenten) seit `launch-run.txt` aus den Transkripten im isolierten Profil summiert → `results/<run-id>/tokens.json` und `runs.csv` (inkl. `turns`, `minutes`) |
| Claude Code (interaktiv, von Hand) | am Ende der Session `/usage` (Alias `/cost`): Abschnitt *Session*, pro Modell input, output, cache read, cache write; alle Modelle addieren |
| Claude Code (headless) | `claude -p "/tdd-whole" --output-format json > build.json`; Werte aus `modelUsage` (enthält Subagents, `usage` nicht). Ob der Slash-Aufruf im `-p`-Modus startet, vorher testen. |
| Codex | Token-Anzeige am Session-Ende bzw. `codex exec --json`. Bei OpenAI sind gecachte Token meist im Input enthalten: dann `tok_input = input − cached` und `tok_cache_read = cached`. In der installierten Version prüfen. |
| Antigravity | nicht verifiziert. Ohne Token-Anzeige bleiben die Spalten leer; das Skript rechnet dann nur Accuracy. |

Token von GPT, Claude und Gemini sind nicht direkt vergleichbar (verschiedene Tokenizer).
Deshalb wird pro Agent gegen dessen eigenes Vanilla verglichen; genau das macht CostEff.

### 6.3 Formeln

**Accuracy** pro Lauf (Gl. 1). Tests mit `error` (Werkzeugfehler) zählen nicht mit:

$$\mathrm{acc} = \frac{N_{\mathrm{pass}} + 0{,}5 \cdot N_{\mathrm{partial}}}{N_{\mathrm{pass}} + N_{\mathrm{partial}} + N_{\mathrm{fail}}} \times 100\,\%$$

Im Paper steht im Nenner $N_{\mathrm{Total}}$. Der Referenzcode (`analysis/metrics.py`) teilt
durch $N_{\mathrm{valid}}$, also ohne `error`-Tests; diese Variante wird hier verwendet. Ohne
`error`-Tests sind beide gleich.

**Δ**, der Gewinn gegenüber Vanilla, pro Agent in Prozentpunkten:

$$\Delta = \overline{\mathrm{acc}}_{\mathrm{Ansatz}} - \overline{\mathrm{acc}}_{\mathrm{Vanilla}}$$

**Kosten-Effizienz** (Gl. 2): Prozentpunkte Gewinn pro Million zusätzlicher Tokens. Bei
Mehrverbrauch ≤ 0 gibt das Skript „—“ aus.

$$\mathrm{CostEff} = \frac{\mathrm{acc} - \mathrm{acc}_{\mathrm{Vanilla}}}{(\mathrm{Tok} - \mathrm{Tok}_{\mathrm{Vanilla}}) / 10^{6}}$$

**Statistik** (Sec. 4.5.2). Ein Paar = gleicher Agent, gleiche Wiederholung (`repeat`):

- einseitiger Wilcoxon-Vorzeichen-Rang-Test, H0: Δ ≤ 0 gegen H1: Δ > 0, exakt berechnet;
- 95 %-Bootstrap-Konfidenzintervall des mittleren Δ, 10 000 Wiederholungen.

Mit n Paaren ist das kleinste mögliche p = 1/2ⁿ (n = 4: 0,0625; n = 5: 0,031). Bei wenigen
Läufen ist die Studie illustrativ; berichtet werden Δ, Konfidenzintervall und Einzelwerte.

Vorbehalt zur Paarung: Im Paper bildet die **Anwendung** das Paar (20 Apps, jede unter jedem
Ansatz gebaut). Mit nur einer Anwendung paart das Skript nach Wiederholungsnummer. Die Läufe
`r1` von Vanilla und `r1` von Whole teilen aber nichts außer der Nummer, die Paarung ist also
willkürlich. Hauptergebnis sind deshalb Δ und Einzelwerte; p und Konfidenzintervall nur als
grobe Orientierung.

**Schleifen-Verhalten** aus `tdd-log.jsonl`. Diese Datei schreibt der bauende Agent selbst; sie
zeigt das Verhalten, nicht die Accuracy:

- acc@k: pro Test das beste der ersten k Urteile, gemittelt.
- Accuracy pro Runde (Whole, Agentic): sinkt sie von einer Runde zur nächsten, ist das eine
  Regression.
- Fail-Rate = fail-Urteile / alle echten Urteile.
- Admission-Rate = akzeptierte / versuchte Features (Incremental).
- Abandonment-Rate = aufgegebene / versuchte Features (Incremental).
- Regression-Rate = akzeptierte Features, die später unter ihr Niveau fallen / akzeptierte.

### 6.4 `runs.csv`

Eine Zeile pro Lauf; Vorlage in `templates/runs.csv`. Die Vorlage hat schon 32 Zeilen:
4 Modelle (`modell1` … `modell4`) × 4 Ansätze × 2 Wiederholungen. Ausgefüllt sind `run_id`,
`agent`, `approach` und `repeat`; `XXX` und leere Zellen sind Platzhalter.

Die Tabelle liegt in `results/runs.csv` in diesem Repo. `case.sh branches` ersetzt die
Platzhalter `modell1` … `modell4` durch die echten Agent-Namen; `XXX` durch die echten Werte ersetzen.

Format:

- Trennzeichen ist das Komma `,`. Nur so zeigt GitHub die Datei als Tabelle an.
- Kommazahlen mit **Punkt**: `58.3`. So gibt `tdd-check` sie auch aus. Ein Komma in einer Zahl
  trennt sonst die Zelle in zwei. Wer lieber `58,3` schreibt, setzt die Zahl in Anführungszeichen:
  `"58,3"`. Vergisst man das, meldet `tools/metrics.py` die Zeile und lässt sie weg.
- Token-Zahlen ohne Tausendertrennzeichen: `1234567`, nicht `1.234.567`.
- Noch nicht gemessene Werte leer lassen oder `XXX` stehen lassen; das Skript ignoriert sie.
- Bearbeiten am einfachsten in einem Texteditor (z. B. VS Code) oder direkt auf GitHub über den
  Stift-Knopf. Numbers öffnet die Datei direkt als Tabelle. Ein deutsches Excel erwartet
  Semikolons; dort über *Daten → Aus Text/CSV* mit Trennzeichen Komma importieren. Speichert
  Excel die Datei mit Semikolons, liest das Skript sie trotzdem, nur die GitHub-Vorschau zeigt
  dann keine Tabelle mehr.

Eine ausgefüllte Zeile im Texteditor:

```text
sonnet-whole-r1,t1,sonnet,claude-code,claude-sonnet-4-6,default,subagent,whole,1,5,1,0,6,91.7,3000,900000,20000,9000,,,
```

| Spalte | Inhalt |
| --- | --- |
| `run_id` | z. B. `claude-whole-r1`, bei Aufgabe t2 `t2-claude-whole-r1` |
| `task` | Aufgabenstellung: `t1` oder `t2` (Abschnitt 1b) |
| `agent` | z. B. `claude`, `gpt`, `gemini` |
| `harness` | `claude-code`, `codex`, `antigravity` |
| `model` | genaue Modell-ID der Bau-Session, z. B. `claude-sonnet-4-6` |
| `reasoning` | Reasoning-/Effort-Einstellung der Bau-Session, z. B. `off`, `low`, `high`, `default` |
| `tester` | `subagent` oder `self`, aus der `done`-Zeile in `tdd/tdd-log.jsonl` (leer bei Vanilla) |
| `approach` | `vanilla`, `whole`, `incremental`, `agentic` (genau so) |
| `repeat` | 1, 2, … (bildet die Paare mit Vanilla) |
| `n_pass`, `n_partial`, `n_fail`, `n_valid`, `accuracy` | aus `tdd-check` |
| `tok_input`, `tok_cache_read`, `tok_cache_write`, `tok_output` | aus der Bau-Session |
| `turns`, `minutes`, `notes` | optional |

Beispielausgabe von `summary` (Testdaten, keine echten Ergebnisse):

```text
| agent  | approach | runs | mean accuracy (%) | Δ vs vanilla (pp) | mean tokens (M) | extra tokens (M) | CostEff (pp/M) |
| claude | vanilla  | 2    | 54.1              | —                 | 0.21            | —                | —              |
| claude | whole    | 2    | 83.3              | 29.1              | 0.92            | 0.70             | 41.41          |
```

## 7. Treue zum Paper

| Übernommen | Angepasst |
| --- | --- |
| Workflow-Texte der vier Ansätze; Bau-, Feature- und Reparatur-Prompt | `start_app`, `run_tests`, `stop_app` sind Anweisungen an den Agenten statt eigener Tools |
| 5 Runden (Whole), 5 Runden pro Feature (Incremental), 25 als Notbremse (Agentic) | Budgets und der Umfang eines Testlaufs gelten per Anweisung, nicht technisch erzwungen; `tdd-log.jsonl` zeigt, ob sie eingehalten wurden |
| Keine Reparatur nach der letzten Runde; startet die App nicht, sind alle Tests der Runde `fail` und die Runde zählt | Getestet wird in einem Subagenten ohne Code-Kontext, wo der Harness das kann, sonst vom bauenden Agenten selbst (`tester` in `runs.csv`); im Paper war das ein separater Tester mit demselben Modell |
| Incremental akzeptiert ab `partial`; Regression = Abfall unter das akzeptierte Niveau | Technischer Rahmen (Node, Express, `server.js`) ersetzt durch `tdd/app.md` |
| Testregeln: Urteile, Konto-Regel, Selektor-Regeln, Aktionsbudget, `error` zählt nicht | Eigenes Projekt und eigene Tests statt WebGen-Bench |
| Leeres Projekt als Ausgangsstand, gleiche Tests für alle Ansätze | Eine Session pro Lauf; im minimalen Agenten des Papers ist jeder Bau- und Reparaturaufruf ein frisches Gespräch. Das verändert das Kostenprofil (RQ4) |
| Fester unabhängiger Prüfer, CostEff nur mit Bau-Tokens, Wilcoxon + Bootstrap | Keine einheitliche Temperatur 0 und kein abgeschaltetes Reasoning; die Harnesses erlauben das nicht einheitlich |

Wo Paper und Referenzcode sich widersprechen oder der Code etwas anders macht, als das Paper
schreibt:

| Punkt | Paper | Hier verwendet |
| --- | --- | --- |
| Abbruch bei Whole | Algorithm 2: Abbruch, wenn alle Tests `pass` **oder** `partial` sind | Code (`strategies._all_pass`): Abbruch erst, wenn alle echten Urteile `pass` sind; ein `partial` führt zu einer weiteren Reparatur |
| Nenner der Accuracy | Gl. 1: $N_{\mathrm{Total}}$ | Code: $N_{\mathrm{valid}}$, ohne `error`-Tests (Abschnitt 6.3) |
| Tokens | input + output | input + cache read + cache write + output (Abschnitt 6.2) |
| Paarung im Wilcoxon-Test | gleiche Anwendung | gleiche Wiederholung, mit Vorbehalt (Abschnitt 6.3) |
| Zweiter Check | nicht vorgesehen | optional, nur als Zuverlässigkeitsangabe; gewertet wird der erste (Abschnitt 5) |

Bei einem harness-übergreifenden Vergleich ändern sich Harness und Modell oft gleichzeitig (Claude
Code/Claude, Codex/GPT, Antigravity/Gemini). Das Paper variiert immer nur eins von beiden. Wo ein
Harness dasselbe Modell wie ein anderer anbietet, trennt ein solcher Lauf die beiden Einflüsse;
`model` in `runs.csv` macht das sichtbar.

Bricht ein Agent die Regeln (z. B. 7 statt 5 Runden), zählt der Lauf trotzdem zu seinem Ansatz
(im Paper „intent-to-treat“). Der Regelbruch wird in `notes` vermerkt.

## 8. Herkunft der Skill-Inhalte

Die Skills selbst verweisen nicht auf Paper oder Repo. Herkunft der Inhalte:
[yxwan123/TDD](https://github.com/yxwan123/TDD), Commit `4f986be`.

| Skill-Abschnitt | Datei im TDDev-Repo |
| --- | --- |
| Workflow-Absätze (Whole, Incremental, Vanilla) | `tddev/oc_conditions.py`: `WHOLE`, `INCREMENTAL`, `NONE` |
| Agentic-Aufgabe mit 4-Schritte-Workflow, Tool-Beschreibungen | `tddev/dev_agents.py`: `_TDD_WORKFLOW`, `_TDD_TOOL_DESCRIPTIONS` |
| Bau-, Feature- und Reparatur-Prompt, Rolle | `tddev/dev_agents.py`: `implement`, `implement_feature`, `fix`, `_DEV_SYSTEM` |
| Projektregeln | `tddev/dev_agents.py`: `_NO_SELF_DEPLOY`, `_CONTRACT` |
| Ablauf, Abbruch, Washes, Fehlerbericht-Format | `tddev/strategies.py`: `whole_project`, `incremental`, `_incremental_check`, `_report` |
| Budget- und Statuszeilen, Notbremse | `tddev/mcp_server.py`: `Feedback.status`; `tddev/config.py`: `AGENTIC_MAX_BATCHES` |
| Testablauf, Urteilsregeln, Fehlerbericht | `tddev/tester.py`: `_SYSTEM`, `_final_report`; `tddev/config.py`: `tester_iters` |
| Accuracy, acc@k, Statistik, CostEff | `analysis/metrics.py`, `analysis/stats.py`, `analysis/tables.py` |
| Länge der Anforderung und Anzahl Tests | ausgezählt aus `data/test.jsonl` (101 Aufgaben) |

Paper: Wan, Liang, Xu, Xiao, Huo, Lyu (2026), *From Runnable Code to Shippable Applications:
Test-Driven Development for Full-Stack Web Application Generation*, ASE '26,
[doi:10.1145/3832783.3834388](https://doi.org/10.1145/3832783.3834388).

Lizenzhinweis: [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
