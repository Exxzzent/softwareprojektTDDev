# softwareprojektTDDev

Fünf Agent Skills, mit denen du die vier TDD-Ansätze aus dem Paper *From Runnable Code to
Shippable Applications* (Wan et al., ASE '26) an deinem eigenen Projekt vergleichst, in Claude
Code, Codex oder Antigravity. Dazu gehört ein Skript, das die Metriken des Papers berechnet.

| Skill | Ansatz | Was passiert |
| --- | --- | --- |
| `tdd-whole` | Whole-Project TDD | alles bauen, dann bis zu 5 Runden: App starten → alle Tests im Browser → reparieren |
| `tdd-incremental` | Incremental TDD | Feature für Feature; pro Feature bis zu 5 Runden über aktuelles Feature + bereits akzeptierte |
| `tdd-agentic` | Agentic TDD | bauen und testen, wann der Agent es für sinnvoll hält (max. 25 Testläufe als Notbremse) |
| `tdd-vanilla` | Vanilla (ohne TDD) | nur bauen, kein Start, kein Test; die Vergleichsbasis |
| `tdd-check` | Unabhängiger Check | prüft die fertige App in einer **neuen** Session und liefert die Accuracy |

Die Skills enthalten nur die Ansätze, ohne Verweise auf Paper oder Repo. Woher jeder Teil stammt,
steht unten unter [Herkunft](#herkunft-der-skill-inhalte).

## Inhalt

```text
skills/
  tdd-whole/SKILL.md
  tdd-incremental/SKILL.md
  tdd-agentic/SKILL.md
  tdd-vanilla/SKILL.md
  tdd-check/SKILL.md
templates/
  tdd/requirement.md      → Anforderung (kommt in dein Projekt)
  tdd/app.md              → Start/Stopp, URL, Konventionen (kommt in dein Projekt)
  tdd/tests.json          → Akzeptanztests (kommt in dein Projekt)
  runs.csv                → Ergebnistabelle für alle Läufe
tools/
  metrics.py              → rechnet alle Metriken aus (nur Python-Standardbibliothek)
```

---

## 1. Setup

Einmalig pro Rechner und Harness.

### 1.1 Voraussetzungen

- **Node.js ≥ 18** (für Playwright MCP): `node --version`
- **Python 3** (für `tools/metrics.py`, keine Pakete nötig): `python3 --version`

### 1.2 Skills installieren

Kopiere die fünf Ordner aus `skills/` dorthin, wo dein Harness Skills sucht:

| Harness | Ort |
| --- | --- |
| Claude Code | pro Projekt `<projekt>/.claude/skills/`, oder für alle Projekte `~/.claude/skills/` |
| Codex | Skills-Ordner laut Codex-Doku deiner Version |
| Antigravity | Skills-Ordner laut Antigravity-Doku deiner Version |

Für Claude Code, in einem Projekt:

```bash
mkdir -p .claude/skills && cp -R ~/Desktop/Code/Skills/softwareprojektTDDev/skills/* .claude/skills/
```

Die Skills nutzen im Kopf nur `name` und `description`, also das gemeinsame Agent-Skills-Format.
Die Ordnerpfade für Codex und Antigravity habe ich nicht verifiziert; prüfe sie in der Doku deiner
installierten Version.

### 1.3 Browser-Tool (Playwright MCP)

`tdd-whole`, `tdd-incremental`, `tdd-agentic` und `tdd-check` brauchen einen Browser.
`tdd-vanilla` braucht keinen.

**Claude Code** (Befehl aus der Playwright-MCP-Doku):

```bash
claude mcp add playwright npx @playwright/mcp@latest
```

Prüfen: in Claude Code `/mcp` öffnen, `playwright` muss als verbunden erscheinen.

**Codex:** Playwright MCP als MCP-Server eintragen, per `codex mcp add` oder in der Codex-Config.
Befehl `npx @playwright/mcp@latest`. Die genaue Syntax steht in der Codex-Doku deiner Version.

**Antigravity:** Antigravity hat einen eingebauten Browser-Agenten; alternativ Playwright MCP über
die MCP-Einstellungen eintragen. Wichtig ist nur, dass der Agent die Seite öffnen, klicken, tippen
und den Seiteninhalt (Accessibility-Snapshot) lesen kann.

Falls Playwright beim ersten Start meldet, dass ein Browser fehlt:

```bash
npx playwright install chromium
```

**Vanilla wirklich ohne Browser:** Der Skill verbietet den Browser. Strenger ist es, Playwright für
Vanilla-Läufe abzuschalten, in Claude Code über `/mcp` → `playwright` → disable.

---

## 2. Dein Projekt vorbereiten

Einmalig pro Case Study.

1. Lege in deinem Projekt einen Ordner `tdd/` an und kopiere die drei Vorlagen hinein:

   ```bash
   cp -R ~/Desktop/Code/Skills/softwareprojektTDDev/templates/tdd ./tdd
   ```

2. **`tdd/requirement.md`**: Beschreibe in 3–8 Sätzen, was gebaut werden soll, so wie ein Nutzer es
   formulieren würde („Please implement a website for …“).
3. **`tdd/app.md`**: Startbefehl, wie man stoppt, URL, Port, Stack und Einstiegsdatei. Alle Skills
   lesen nur hier, wie die App läuft.
4. **`tdd/tests.json`**: deine Akzeptanztests, 5–10 Stück. Format:

   ```json
   {"test_id": "TC-01", "feature": "Add a task",
    "steps": ["Open the app", "Fill 'Test Item' in the task input", "Click the Add button"],
    "expected": "'Test Item' appears in the task list"}
   ```

   Gute Tests nach dem Paper: ein Test pro unterscheidbarem Verhalten; auch Navigation zwischen
   Bereichen, geforderte visuelle Eigenschaften, reine Anzeige-Zustände und Verhalten, das die
   Anforderung nur andeutet. Breite statt Varianten desselben Tests. Feste Eingabewerte:
   `testuser@example.com`, `Test@1234`, „Test User“, „Test Item“. Bei Incremental ist die
   Reihenfolge der Tests die Bau-Reihenfolge.

5. **Optional `tdd/oracle-tests.json`**: eigene Tests nur für den Check. Ohne diese Datei nutzt
   `tdd-check` die `tests.json`. Im Paper waren Bau-Tests und Check-Tests inhaltlich gleich, nur
   anders formatiert.
6. **Einfrieren:** Ab jetzt ändert sich nichts mehr in `tdd/`. Lege einen Ausgangsstand an:

   ```bash
   git add tdd && git commit -m "TDD case study baseline" && git tag tdd-baseline
   ```

Damit `tdd-check` belastbar ist, prüfe ihn einmal vorab, wie im Paper (RQ1.2): Baue eine Version,
in der du **absichtlich ein Feature kaputt** machst, und lass `tdd-check` laufen. Der Check muss den
Fehler finden. Das Paper verlangt null übersehene Fehler; zu strenge Urteile sind weniger schlimm.

---

## 3. Ein Lauf

Ein Lauf = ein Agent × ein Ansatz × eine Wiederholung. Name: `<agent>-<ansatz>-r<n>`, z. B.
`claude-whole-r1`.

1. **Frischer Stand:** ein eigener Branch ab dem Ausgangsstand.

   ```bash
   git switch -c run/claude-whole-r1 tdd-baseline
   ```

2. **Neue Session** im Harness öffnen, im Projektordner.
3. **Skill aufrufen**, ohne weiteren Prompt:
   - Claude Code: `/tdd-whole`
   - Codex / Antigravity: den Skill per Name aufrufen, z. B. „Use the tdd-whole skill.“
4. Warten, bis der Agent fertig ist. Nicht eingreifen.
5. **Tokens ablesen** (siehe 5.2) und mit Laufzeit und Turns in `runs.csv` eintragen.
6. **Ergebnis sichern:**

   ```bash
   git add -A && git commit -m "run claude-whole-r1"
   ```

Wiederhole das für jeden Agenten und jeden Ansatz. Beispiel: 3 Agenten × 4 Ansätze × 2
Wiederholungen = 24 Läufe.

---

## 4. Der Check

Pro Lauf, nach dem Bauen:

1. Auf den Branch des Laufs wechseln: `git switch run/claude-whole-r1`
2. **Neue Session** öffnen, **immer im gleichen Harness mit dem gleichen Modell**, egal welcher
   Agent gebaut hat. Beispiel: alle Checks in Claude Code mit demselben Modell. Im Paper hat ein
   fester Prüfer alle Apps bewertet; sonst vergleichst du die Prüfer statt der Ansätze.
3. `/tdd-check claude-whole-r1` aufrufen.
4. Ergebnis: `tdd/check-<zeitstempel>.json` plus eine Zeile `n_pass,n_partial,n_fail,n_valid,accuracy`
   für `runs.csv`.
5. Empfehlung: den Check zweimal laufen lassen. Bei Abweichungen schaust du die betroffenen Tests
   selbst im Browser an und entscheidest.

Die Tokens des Checks zählen **nicht** zu den Kosten des Ansatzes.

---

## 5. Metriken: wo nachschauen, wie rechnen

### 5.1 Übersicht

| Metrik | Paper | Quelle | Befehl |
| --- | --- | --- | --- |
| Accuracy pro Lauf | Gl. 1, RQ2 | `tdd/check-*.json` | `python3 tools/metrics.py check tdd/check-*.json` |
| Δ zu Vanilla | RQ2 | `runs.csv` | `python3 tools/metrics.py summary runs.csv` |
| Bootstrap-KI, Wilcoxon | Sec. 4.5.2 | `runs.csv` | `summary` |
| Tokens, Kosten-Effizienz | Gl. 2, RQ4 | Harness-Anzeige → `runs.csv` | `summary` |
| acc@k, Accuracy pro Runde | Tabelle 8, RQ3 | `tdd/tdd-log.jsonl` | `python3 tools/metrics.py loop tdd/tdd-log.jsonl` |
| Failure-verdict-, Admission-, Abandonment-, Regression-Rate | Tabelle 7 | `tdd/tdd-log.jsonl` | `loop` |

### 5.2 Tokens ablesen

Gezählt wird nur die **Bau-Session**. Trage die vier Werte getrennt in `runs.csv` ein; das Skript
summiert sie:

$$\mathrm{Tok} = \text{input} + \text{cache read} + \text{cache write} + \text{output}$$

Das Paper zählt Cache-Reads als Input; 96,3 % aller Token waren dort Input. Weise den Cache-Anteil
trotzdem getrennt aus.

| Harness | Wo |
| --- | --- |
| Claude Code (interaktiv) | am Ende der Session `/usage` (Alias `/cost`): Abschnitt *Session*, pro Modell input, output, cache read, cache write. Alle Modelle addieren. |
| Claude Code (headless) | `claude -p "/tdd-whole" --output-format json > build.json`; Werte aus `modelUsage` (enthält Subagents; `usage` enthält sie nicht). Ob der Slash-Aufruf im `-p`-Modus startet, vorher einmal testen. |
| Codex | Token-Anzeige am Session-Ende bzw. Ausgabe von `codex exec --json`. Bei OpenAI sind gecachte Token meist **im** Input enthalten: dann `tok_input = input − cached`, `tok_cache_read = cached`. Bitte in deiner Version prüfen. |
| Antigravity | Habe ich nicht verifiziert. Wenn keine Token angezeigt werden, Spalten leer lassen; das Skript rechnet dann nur Accuracy. |

**Wichtig:** Token von GPT, Claude und Gemini sind nicht direkt vergleichbar (verschiedene
Tokenizer). Vergleiche deshalb pro Agent gegen dessen eigenes Vanilla; genau das macht CostEff.

### 5.3 Formeln

**Accuracy** (Gl. 1), pro Lauf, `error`-Tests ausgeschlossen:

$$\mathrm{acc} = \frac{N_{\mathrm{pass}} + 0{,}5 \cdot N_{\mathrm{partial}}}{N_{\mathrm{pass}} + N_{\mathrm{partial}} + N_{\mathrm{fail}}} \times 100\,\%$$

**Effekt** gegenüber Vanilla, pro Agent:

$$\Delta = \overline{\mathrm{acc}}_{\mathrm{Ansatz}} - \overline{\mathrm{acc}}_{\mathrm{Vanilla}} \quad [\mathrm{pp}]$$

**Kosten-Effizienz** (Gl. 2): Prozentpunkte Gewinn pro Million zusätzlicher Token. Ist der
Mehrverbrauch ≤ 0, gibt das Skript „—“ aus.

$$\mathrm{CostEff} = \frac{\mathrm{acc} - \mathrm{acc}_{\mathrm{Vanilla}}}{(\mathrm{Tok} - \mathrm{Tok}_{\mathrm{Vanilla}}) / 10^{6}} \quad [\mathrm{pp/Mtoken}]$$

**Statistik** (Sec. 4.5.2). Paare = gleicher Agent, gleiche Wiederholung (`repeat`):
- einseitiger Wilcoxon-Vorzeichen-Rang-Test, H0: Δ ≤ 0 gegen H1: Δ > 0, exakt berechnet;
- 95 %-Perzentil-Bootstrap-KI des mittleren Δ, 10 000 Resamples.

Mit n Paaren ist das kleinste mögliche p = 1/2ⁿ (n = 4: 0,0625; n = 5: 0,031). Bei wenigen Läufen
ist die Studie illustrativ: Berichte Δ, KI und die Einzelwerte, nicht nur das p.

**Schleifen-Verhalten** (aus `tdd-log.jsonl`, vom bauenden Agenten selbst geschrieben, daher nur
für das Verhalten, nicht für die Accuracy):
- *acc@k*: pro Test das beste der ersten k Urteile, gemittelt.
- *Accuracy pro Runde* (Whole, Agentic): sinkt sie von einer Runde zur nächsten, ist das eine
  Regression (Paper, Tabelle 8).
- *Failure-verdict-Rate* = fail-Urteile / alle echten Urteile.
- *Admission-Rate* = akzeptierte Features / versuchte Features (Incremental).
- *Abandonment-Rate* = aufgegebene Features / versuchte Features (Incremental).
- *Regression-Rate* = akzeptierte Features, die später unter ihr Niveau fallen / akzeptierte.

### 5.4 Beispiel

```bash
python3 tools/metrics.py summary runs.csv
```

```text
| agent  | approach | runs | mean accuracy (%) | Δ vs vanilla (pp) | mean tokens (M) | extra tokens (M) | CostEff (pp/M) | mean turns |
| claude | vanilla  | 2    | 54.1              | —                 | 0.21            | —                | —              | 21         |
| claude | whole    | 2    | 83.3              | 29.1              | 0.92            | 0.70             | 41.41          | 58         |
```

(Zahlen aus Testdaten, keine echten Ergebnisse.)

### 5.5 `runs.csv`

Eine Zeile pro Lauf, Vorlage in `templates/runs.csv`:

| Spalte | Inhalt |
| --- | --- |
| `run_id` | z. B. `claude-whole-r1` |
| `agent` | z. B. `claude`, `gpt`, `gemini` |
| `harness` | `claude-code`, `codex`, `antigravity` |
| `approach` | `vanilla`, `whole`, `incremental`, `agentic` (genau so schreiben) |
| `repeat` | 1, 2, … (bildet die Paare mit Vanilla) |
| `n_pass` … `accuracy` | aus `tdd-check` |
| `tok_input`, `tok_cache_read`, `tok_cache_write`, `tok_output` | aus der Bau-Session |
| `turns`, `minutes`, `notes` | optional |

---

## 6. Treue zum Paper

| Übernommen | Angepasst |
| --- | --- |
| Workflow-Texte der vier Ansätze, Bau- und Reparatur-Prompts | `start_app` / `run_tests` / `stop_app` sind keine Tools mehr, sondern Anweisungen an den Agenten |
| K = 5 Runden (Whole) bzw. 5 pro Feature (Incremental), 25 als Notbremse (Agentic) | Das Budget wird nur per Anweisung eingehalten, nicht technisch erzwungen. Ob der Agent sich daran hält, zeigt `tdd-log.jsonl`. |
| Stopp bei Whole erst, wenn alle Tests `pass` sind; keine Reparatur nach der letzten Runde | Der Agent testet im Selbsttest selbst; im Paper war das ein separater Tester mit dem gleichen Modell |
| Aufnahme bei Incremental ab `partial`; Regression = Abfall unter das aufgenommene Niveau | Technischer Vertrag (Node, Express, `server.js`) ersetzt durch dein `tdd/app.md` |
| Tester-Regeln: Urteile, Konto-Regel, Selektor-Regeln, Aktionsbudget, `error` = ausgeschlossen | Eigenes Projekt statt WebGen-Bench; eigene Tests |
| Accuracy-Formel, unabhängiger fester Prüfer, CostEff nur mit Bau-Token, Wilcoxon + Bootstrap | Kein temperature 0, keine abgeschaltete Reasoning-Funktion; das erlauben die Harnesses nicht einheitlich |

Wenn ein Agent die Regeln bricht (z. B. 7 statt 5 Runden), werte den Lauf trotzdem unter seinem
Ansatz. Das Paper nennt das intent-to-treat. Notiere den Regelbruch in `notes`.

## Herkunft der Skill-Inhalte

Nur für deine Dokumentation; die Skills selbst verweisen nicht darauf. Quelle:
[yxwan123/TDD](https://github.com/yxwan123/TDD), Commit `4f986be`.

| Skill-Abschnitt | Datei im TDDev-Repo |
| --- | --- |
| Workflow-Absätze (Whole, Incremental, Vanilla) | `tddev/oc_conditions.py`: `WHOLE`, `INCREMENTAL`, `NONE` |
| Agentic-Task mit 4-Schritte-Workflow, Tool-Beschreibungen | `tddev/dev_agents.py`: `_TDD_WORKFLOW`, `_TDD_TOOL_DESCRIPTIONS` |
| Bau-Prompt, Feature-Prompt, Reparatur-Prompt, Rolle | `tddev/dev_agents.py`: `implement`, `implement_feature`, `fix`, `_DEV_SYSTEM` |
| Projektregeln | `tddev/dev_agents.py`: `_NO_SELF_DEPLOY`, `_CONTRACT` |
| Ablauf, Abbruch, Washes, Fehlerbericht-Format | `tddev/strategies.py`: `whole_project`, `incremental`, `_incremental_check`, `_report` |
| Budget-/Statuszeilen, 25er-Notbremse | `tddev/mcp_server.py`: `Feedback.status`; `tddev/config.py`: `AGENTIC_MAX_BATCHES` |
| Test procedure, Verdikt-Regeln, Fehlerbericht | `tddev/tester.py`: `_SYSTEM`, `_final_report`; `tddev/config.py`: `tester_iters` |
| Accuracy, acc@k, Statistik, CostEff | `analysis/metrics.py`, `analysis/stats.py`, `analysis/tables.py` |

Paper: Wan, Liang, Xu, Xiao, Huo, Lyu (2026), *From Runnable Code to Shippable Applications:
Test-Driven Development for Full-Stack Web Application Generation*, ASE '26,
[doi:10.1145/3832783.3834388](https://doi.org/10.1145/3832783.3834388).

Lizenzhinweis zu den übernommenen Texten: [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
