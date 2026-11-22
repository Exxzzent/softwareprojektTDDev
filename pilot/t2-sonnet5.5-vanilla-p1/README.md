# Pilot t2-sonnet5.5-vanilla-p1 (nicht gewertet)

Ungezählter Probelauf vor dem Einfrieren der Aufgabe t2: Sonnet 5.5, Vanilla, headless
(`claude -p`, sonst dieselben Flags wie `tools/agent.sh`), Check mit Opus 5.5. Steht nicht in
`results/runs.csv`.

- Ausgangsstand: Kandidat `52568a5` (Anforderung 2, Tests 2 mit je vier Screenshots in TC-21/TC-25).
- Bau: 17,5 min, 1,55 Mio. Tokens, 11 Modellaufrufe.
- Check: 24 pass, 3 partial, 9 fail von 36 = 70,8 %.
- Ursache der meisten Fehlschläge: Nach „Start“ bleiben beide Bahnen stehen (nur „Bahn 2 wartet“
  im Betriebsprotokoll); dadurch fallen TC-20 bis TC-27 und TC-31. Dazu TC-06 (Kalibrierung
  dauert länger als 25 s) und TC-15 (zweite Auswahl geht verloren).
- Folge für die Tests: TC-21 und TC-25 nehmen drei statt vier Screenshots, weil das
  Aktionsbudget von 24 sonst nicht reicht.
