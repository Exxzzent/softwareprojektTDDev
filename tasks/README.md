# Aufgabenstellungen

| Datei | Inhalt |
| --- | --- |
| `requirement-1.md`, `tests-1.json` | Aufgabe t1 „Folgefahrt mit Mockup“: unveränderte Kopie von `tdd/requirement.md` und `tdd/tests.json` am Tag `tdd-baseline` |
| `requirement-2.md`, `tests-2.json` | Aufgabe t2 „Gegenverkehr ohne Mockup“: liegt byte-gleich als `tdd/requirement.md` und `tdd/tests.json` am Tag `tdd-baseline-t2` |

Vergleich: `diff tasks/requirement-1.md tasks/requirement-2.md`.

## Was sich in der Anforderung ändert (t1 → t2)

| Stelle | Änderung |
| --- | --- |
| Einleitung, Begriffe | Gegenverkehr als Normalfall; Definition von „clockwise“ / „counter-clockwise“ |
| WORLD-06, 06.1, 06.2 | Strecke nur in Worten (ein Verweis auf das Foto, kein Mockup): Schleife, Ausweichgleis, Weiche 2 am rechten Ende des geraden Ausweichgleis-Stücks, Stumpfgleis als gerade Verlängerung auf gleicher Höhe, drei Gleisebenen, vier Haltestellen mit Position |
| WORLD-16, WORLD-18.1 | Bahnen stehen entgegengesetzt: `forward` = Bahn 1 im Uhrzeigersinn, Bahn 2 dagegen; Bahn 1 fährt rückwärts, Bahn 2 vorwärts an den Prellbock |
| WORLD-17, WORLD-19, SETUP-11 | Zeitvorgaben: Haltezeit 2 s, Runde 20–30 s, Kalibrierung im First Setup höchstens 15 s |
| CTRL-05.1, 05.2 | Fahrt zu den Haltestellen nur in Standardrichtung; Haltezeit an jeder Haltestelle |
| CTRL-13, 13.5, CTRL-14 | Begegnung als Dauerfall; Weiterfahrt nach dem Ausweichen; keine gemeinsame Blockbelegung, kein Deadlock |
| UI-05.1 | Start nur mit mindestens einer Haltestelle |
| UI-10 | Betriebsprotokoll mit festen Ereignistexten (macht Ausweichen, Warten, Rundkurs und Kalibrierung prüfbar) |
| SETUP-03, 05, 08 | erste Bahn = Bahn 1, zweite = Bahn 2, mit Kalibrierrichtung |
| REF-01, „UI Specification“ | Mockup entfernt; stattdessen Komponenten, Farbpalette, Layout, Texte und Verhaltensregeln als Text |

## Was sich in den Tests ändert (weiter 36)

- In Nachbartests aufgegangen (in t1 von jedem Lauf bestanden): alt TC-05, 07, 12, 15, 19, 31, 34.
- Neu: TC-12 Layout bei 800 px, TC-17 Start ohne Haltestelle, TC-21 entgegengesetzte
  Umlaufrichtung, TC-23 Ausweichen bei Begegnung, TC-24 Weiterfahrt ohne Deadlock, TC-28
  Betriebsprotokoll, TC-31 erneuter Start nach Stop.
- Geändert: TC-02/03/11 prüfen gegen UI-Spezifikation und WORLD-06; TC-09/10 prüfen die
  Kalibrierrichtung je Bahn; TC-06/08 warten 25 s statt 20 s; TC-26/27 lesen das
  Betriebsprotokoll statt nur Screenshots; alle Fahrtests nutzen feste Haltestellen
  (Bahn 1: 2 → 4, Bahn 2: 4 → 2) und stellen sie nur bei Bedarf her.
- Gegen parallele Browser-Aufrufe der Prüfer: Jeder Test mit Interaktion beginnt mit dem Schritt
  „Work strictly sequentially …“, und keine Wartezeit ist länger als 30 s (Grenze des
  Warte-Werkzeugs).

Wortlaut aller Änderungen mit alt/neu: `BERICHT-T2.md` im Wurzelverzeichnis.
