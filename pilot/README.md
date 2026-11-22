# Pilotläufe zur Aufgabe t2 (nicht gewertet)

Ungezählte Probeläufe vor dem Einfrieren von `tdd-baseline-t2`. Alle mit Sonnet 5.5, headless
(`claude -p`, sonst dieselben Flags wie `tools/agent.sh`), Check mit Opus 5.5. Keiner steht in
`results/runs.csv`. Auswertung und Folgerungen: `BERICHT-T2.md`.

| Ordner | Ansatz | Teststand | Ergebnis |
| --- | --- | --- | --- |
| `t2-sonnet5.5-vanilla-p1` | Vanilla | erster Entwurf | 70,8 % (24 pass, 3 partial, 9 fail) |
| `t2-sonnet5.5-agentic-p1` | Agentic | erster Entwurf, 3 statt 4 Screenshots | 93,1 % (33 / 1 / 2) |
| `t2-sonnet5.5-agentic-p1b` | dieselbe App wie p1 | sequenzielle Schritte, Wartezeiten bis 30 s | 98,6 % (35 / 1 / 0) |
| `t2-sonnet5.5-vanilla-p2` | Vanilla | wie p1b, WORLD-06 präzisiert | kein Check; `track-graphic.png` zeigt die Karte |

`baseline-candidate.txt` enthält den Commit, der als `tdd-baseline-t2` eingefroren wurde. Nach p1b
und p2 wurden noch WORLD-06 ausformuliert, der Foto-Verweis auf eine Stelle reduziert, TC-21 auf
fünf Screenshots erweitert und TC-18 um einen Leseschritt ergänzt.
