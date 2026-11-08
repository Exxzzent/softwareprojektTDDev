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

## 2. Setup (einmal pro Rechner)

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

Für Vanilla-Läufe Playwright abschalten, damit der Agent sicher nicht testet (Claude Code:
`/mcp` → `playwright` → disable).

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
5. Empfehlung: den Check zweimal laufen lassen. Bei Abweichungen die betroffenen Tests selbst im
   Browser ansehen und entscheiden.

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

Gezählt wird nur die Session, in der gebaut wurde. Die vier Werte werden getrennt in `runs.csv`
eingetragen; das Skript summiert sie:

$$\mathrm{Tok} = \text{input} + \text{cache read} + \text{cache write} + \text{output}$$

| Harness | Wo |
| --- | --- |
| Claude Code (interaktiv) | am Ende der Session `/usage` (Alias `/cost`): Abschnitt *Session*, pro Modell input, output, cache read, cache write; alle Modelle addieren |
| Claude Code (headless) | `claude -p "/tdd-whole" --output-format json > build.json`; Werte aus `modelUsage` (enthält Subagents, `usage` nicht). Ob der Slash-Aufruf im `-p`-Modus startet, vorher testen. |
| Codex | Token-Anzeige am Session-Ende bzw. `codex exec --json`. Bei OpenAI sind gecachte Token meist im Input enthalten: dann `tok_input = input − cached` und `tok_cache_read = cached`. In der installierten Version prüfen. |
| Antigravity | nicht verifiziert. Ohne Token-Anzeige bleiben die Spalten leer; das Skript rechnet dann nur Accuracy. |

Token von GPT, Claude und Gemini sind nicht direkt vergleichbar (verschiedene Tokenizer).
Deshalb wird pro Agent gegen dessen eigenes Vanilla verglichen; genau das macht CostEff.

### 6.3 Formeln

**Accuracy** pro Lauf (Gl. 1). Tests mit `error` (Werkzeugfehler) zählen nicht mit:

$$\mathrm{acc} = \frac{N_{\mathrm{pass}} + 0{,}5 \cdot N_{\mathrm{partial}}}{N_{\mathrm{pass}} + N_{\mathrm{partial}} + N_{\mathrm{fail}}} \times 100\,\%$$

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

Eine Zeile pro Lauf; Vorlage in `templates/runs.csv`.

| Spalte | Inhalt |
| --- | --- |
| `run_id` | z. B. `claude-whole-r1` |
| `agent` | z. B. `claude`, `gpt`, `gemini` |
| `harness` | `claude-code`, `codex`, `antigravity` |
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
| 5 Runden (Whole), 5 Runden pro Feature (Incremental), 25 als Notbremse (Agentic) | Budgets gelten per Anweisung, nicht technisch erzwungen; `tdd-log.jsonl` zeigt, ob sie eingehalten wurden |
| Whole stoppt erst, wenn alle Tests `pass` sind; keine Reparatur nach der letzten Runde | Der bauende Agent testet selbst; im Paper war das ein separater Tester mit demselben Modell |
| Incremental akzeptiert ab `partial`; Regression = Abfall unter das akzeptierte Niveau | Technischer Rahmen (Node, Express, `server.js`) ersetzt durch `tdd/app.md` |
| Testregeln: Urteile, Konto-Regel, Selektor-Regeln, Aktionsbudget, `error` zählt nicht | Eigenes Projekt und eigene Tests statt WebGen-Bench |
| Accuracy-Formel, fester unabhängiger Prüfer, CostEff nur mit Bau-Tokens, Wilcoxon + Bootstrap | Keine einheitliche Temperatur 0 und kein abgeschaltetes Reasoning; die Harnesses erlauben das nicht einheitlich |

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
