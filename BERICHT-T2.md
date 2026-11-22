# Bericht: zweite Aufgabenstellung (t2) „Gegenverkehr ohne Mockup“

Stand: 23. November 2026, nachts. Alles ist eingerichtet, eingefroren und gepusht. Gezählte Läufe
wurden nicht gestartet.

## 1. Stand in Kürze

| | |
| --- | --- |
| Ausgangsstand t2 | Branch `TDDev-origin-t2`, Tag `tdd-baseline-t2`, Commit `1ad6317` (ein Commit ohne Vorgänger) |
| Unterschied zu `tdd-baseline` | genau drei Dateien: `tdd/requirement.md` und `tdd/tests.json` neu, `references/gartenbahn-mockup.html` entfernt; die übrigen 46 Einträge (Skills, `tdd/app.md`, Mock-Server, Lockfile, Submodul) sind identisch |
| Lauf-Branches | 24 neue: `run/t2-<agent>-<ansatz>-r1|r2` für `opus5.5`, `sonnet5.5`, `gpt6.1terra` |
| Projekt-Klon für t2 | `Softwareprojekt/App-T2/softwareprojekt`, holt nur t2-Refs; Mockup, alte Anforderung und t1-Lösungen liegen dort nachweislich nicht vor |
| Tabelle | `results/runs.csv`: neue Spalte `task`; 16 Zeilen `t1` (wertgleich), 24 leere Zeilen `t2`; die 16 leeren T1-Codex-Zeilen sind entfernt |
| Vergleich alt/neu | `tasks/requirement-1.md`, `tasks/tests-1.json` (unverändert) neben `tasks/requirement-2.md`, `tasks/tests-2.json` |
| Sicherung | `Softwareprojekt/Backup-vor-T2/` (beide Repos als Bundle, Stand vor allen Änderungen) |

Gelöscht wurde nichts: Alle 55 Refs, die vor der Arbeit auf GitHub lagen (inklusive aller Fable-,
Gemini- und Codex-Branches und der 16 fertigen Läufe), sind unverändert. Hinzugekommen sind
1 Branch, 1 Tag und 24 Lauf-Branches. Auf `main` des Projekt-Repos wurde nichts gepusht.

## 2. Pilotläufe (ungezählt, nicht in `runs.csv`)

| Lauf | Ansatz | Bau | Tokens | Check (Opus 5.5) | Ergebnis |
| --- | --- | --- | --- | --- | --- |
| `t2-sonnet5.5-vanilla-p1` | Vanilla | 17,5 min | 1,55 Mio. | 37 min | 24 pass, 3 partial, 9 fail = **70,8 %** |
| `t2-sonnet5.5-agentic-p1` | Agentic | 85,4 min, 7 Testrunden | 61,9 Mio. | 39 min | 33 pass, 1 partial, 2 fail = **93,1 %** |
| `t2-sonnet5.5-agentic-p1b` | dieselbe App, überarbeitete Tests | – | – | 38 min | 35 pass, 1 partial, 0 fail = **98,6 %** |
| `t2-sonnet5.5-vanilla-p2` | Vanilla, nur Kartenkontrolle | 19,0 min | 2,30 Mio. | kein Check | Karte entspricht dem Mockup (`pilot/t2-sonnet5.5-vanilla-p2/track-graphic.png`) |

- Zum Vergleich t1: Sonnet-Vanilla 86,1 % und 97,2 %. Der Deckeneffekt ist weg; die Lücke zwischen
  Vanilla und Agentic liegt im Pilot bei gut 20 Punkten und damit in der Größenordnung des Papers.
- Vanilla scheitert am Gegenverkehr: Nach „Start“ bleiben beide Bahnen stehen, im
  Betriebsprotokoll steht nur „Bahn 2 wartet“. Daran hängen neun der zwölf Fehlschläge.
- Einschränkung: Das sind je ein Lauf mit Sonnet. Vanilla wurde mit dem ersten Teststand geprüft,
  Agentic mit dem ersten und dem überarbeiteten. Die Zahlen zeigen die Richtung, mehr nicht.

## 3. Messfehler, der auch t1 betrifft

Die Prüf-Subagenten senden oft mehrere Browser-Aufrufe in einer Nachricht, zum Beispiel
„Start klicken“, „30 s warten“ und „Seite lesen“. Playwright führt sie gleichzeitig aus; das Lesen
passiert dann vor Ablauf der Wartezeit.

- Beleg im Pilot: Bei TC-06 kam der Snapshot „Bahn 1 wird kalibriert …“ zurück, bevor die 25 s
  Wartezeit beendet war. Direkt an der App gemessen dauert die Kalibrierung 7,5 s; im selben
  Playwright-Browser nacheinander ausgeführt zeigt der Dialog nach 25 s korrekt Bahn 2.
- Bei TC-15 gingen zwei gleichzeitig gesendete Auswahlen verloren, bei TC-24 liefen zwei
  30-s-Wartezeiten parallel statt nacheinander.
- Das Warte-Werkzeug erlaubt höchstens 30 s pro Aufruf; längere Schritte werden gekappt.
- In den t1-Transkripten (alle 16 Läufe mit ihren Checks) wurden 2 332 von 3 947 Warte-Aufrufen
  (59 %) zusammen mit anderen Browser-Aufrufen gesendet, 1 837 davon mit einem Snapshot oder
  Screenshot. Die häufigsten t1-Fehlschläge (alt TC-09 und TC-26, je 11 von 16 Läufen) sind
  Tests mit Wartezeit. Dass sie Artefakte sind, ist damit sehr wahrscheinlich, für t1 aber nicht
  einzeln nachgeprüft.

Gegenmaßnahme in t2, nur in den Tests (die Skills sind unverändert): Jeder Test mit Interaktion
beginnt mit diesem Schritt:

> Work strictly sequentially in this test: send only one browser tool call per message and wait for its result before you send the next one (never several clicks, selections, waits, snapshots or screenshots in parallel)

Dazu sind alle Wartezeiten höchstens 30 s lang. Wirkung im Nach-Check: parallele
Browser-Nachrichten von rund 90 auf 14, TC-06, TC-15 und TC-24 bestanden.

## 4. Anforderungen: alt und neu im Wortlaut

Alle Zitate stammen wörtlich aus `tasks/requirement-1.md` (alt) und `tasks/requirement-2.md` (neu).
Das Streckenlayout ist nur in Worten beschrieben; das reale Foto wird genau einmal referenziert
(in WORLD-06), ein Mockup kommt im neuen Dokument nicht mehr vor.

### 4.1 Neu formuliert

#### WORLD-06 – Streckenlayout in Worten statt Verweis auf das Mockup

Alt:

> - **WORLD-06** The track layout is based on the physical layout in the
>   [reference photo](../references/gartenbahn-aufbau.jpg) and drawn schematically in the track
>   graphic of the [UI mockup](../references/gartenbahn-mockup.html): an elongated oval main loop
>   with long straight sides. Along the front straight, a siding runs on the outside of the loop,
>   between two switches on the main line. A third switch lies on the siding; from it a dead-end
>   spur leads away from the loop (outwards, not into the loop) and ends at a buffer stop. This spur
>   is the calibration point.

Neu:

> - **WORLD-06** The track layout is the physical layout shown in the
>   [reference photo](../references/gartenbahn-aufbau.jpg). It must be modelled, and drawn in the
>   track graphic, as seen from above with the front straight at the bottom. All position words in
>   this document (top, bottom, left, right, above, below) refer to this view. The layout consists
>   of exactly the following parts:
>   - **Main loop:** a closed, elongated oval. It consists of the back straight (top), the right
>     curve, the front straight (bottom) and the left curve. The two straights are horizontal,
>     parallel and equally long, and each of them is clearly longer than the oval is high. Each
>     curve is a half circle that joins the ends of the two straights on its side.
>   - **Siding:** a second track on the outside of the loop, below the front straight. It begins at
>     "Weiche 1" and ends at "Weiche 3". Both switches lie on the front straight, "Weiche 1" in its
>     left third and "Weiche 3" in its right third. From "Weiche 1" the siding runs a short piece
>     diagonally down to the right, then as a straight horizontal section parallel to the front
>     straight, then a short piece diagonally up to the right into "Weiche 3". The part of the front
>     straight between "Weiche 1" and "Weiche 3" is the next-to-siding track.
>   - **"Weiche 2":** lies on the siding at the right end of its horizontal section, exactly at the
>     point where the siding bends upwards towards "Weiche 3".
>   - **Spur (calibration point):** a dead-end track that begins at "Weiche 2" and continues the
>     horizontal section of the siding in a straight line to the right, at the same height as that
>     section. It does not branch off downwards. It passes below the right curve without touching
>     it, extends a little beyond the rightmost point of the loop and ends there at a buffer stop.
>     The spur lies outside the loop.
>
>   From top to bottom the layout therefore has exactly three horizontal track levels: the back
>   straight, the front straight and, below it, one level that is shared by the horizontal section
>   of the siding and the spur. There is no track below this third level.
>   - **WORLD-06.1** The spur can only be entered from the siding coming from "Weiche 1" (moving
>     from left to right, i.e. in the counter-clockwise sense) and can only be left in the opposite
>     sense. A train coming from "Weiche 3" cannot enter the spur.
>   - **WORLD-06.2** The track has exactly four stops: "Haltestelle 1" on the back straight,
>     "Haltestelle 2" at the rightmost point of the right curve, "Haltestelle 3" in the middle of
>     the next-to-siding track (the front straight between "Weiche 1" and "Weiche 3") and
>     "Haltestelle 4" at the leftmost point of the left curve. In clockwise order the stops are
>     1, 2, 3, 4.

#### WORLD-16 – Kalibrierrichtung je Bahn

Alt:

> - **WORLD-16** A train must be calibratable at the calibration point: the train drives against
>   the buffer stop with the calibration speed for the calibration duration; afterwards its
>   position is known.

Neu:

> - **WORLD-16** A train must be calibratable at the calibration point: the train drives against
>   the buffer stop with the calibration speed for the calibration duration; afterwards its
>   position is known. The train must drive in the direction that leads towards the buffer
>   stop for this train (see WORLD-18.1).

#### WORLD-17 – Haltezeit ergänzt

Alt:

> - **WORLD-17** The following calibration values must be defined at the top level of the
>   configuration (not per train):
>   - calibration duration in ms (default: 3000);
>   - calibration speed as speed value for the API of the Locomotive Server (integer 0–255,
>     default: 60). It must be lower than the speed values of the trains.

Neu:

> - **WORLD-17** The following values must be defined at the top level of the configuration (not per
>   train):
>   - calibration duration in ms (default: 3000);
>   - calibration speed as speed value for the API of the Locomotive Server (integer 0–255,
>     default: 60). It must be lower than the speed values of the trains;
>   - dwell time in ms (default: 2000): the time a train stands at each stop of its sequence before
>     it drives on.

#### WORLD-18 – Fahrtrichtung: Bahnen stehen entgegengesetzt

Alt:

> - **WORLD-18** The application must support exactly two trains. The following metadata must be
>   stored for each train:
>   - name of the train; it is also the name under which the train's Locomotive Server is registered
>     at the Railroad Server;
>   - speed in the physical world in cm/s;
>   - speed value for the API of the Locomotive Server (integer 0–255) that corresponds to this
>     physical speed;
>   - maximum distance without recalibration in cm, i.e. the distance the train may cover at most
>     since its last calibration before it must be calibrated again;
>   - driving direction: a default direction and an evasive direction, which is opposite to the
>     default direction;
>   - length of the train in cm.

Neu:

> - **WORLD-18** The application must support exactly two trains. The following metadata must be
>   stored for each train:
>   - name of the train; it is also the name under which the train's Locomotive Server is registered
>     at the Railroad Server;
>   - speed in the physical world in cm/s;
>   - speed value for the API of the Locomotive Server (integer 0–255) that corresponds to this
>     physical speed;
>   - maximum distance without recalibration in cm, i.e. the distance the train may cover at most
>     since its last calibration before it must be calibrated again;
>   - driving direction: a default direction and an evasive direction, which is opposite to the
>     default direction, and the sense of travel around the main loop (clockwise or
>     counter-clockwise) that the default direction corresponds to;
>   - length of the train in cm.
>   - **WORLD-18.1** [Given] The two trains stand on the track facing opposite ways, and a train
>     never turns around. For both trains the default direction is *forward* (direction `0` of the
>     Locomotive Server) and the evasive direction is *backward* (direction `1`). Driving forward
>     moves "Bahn 1" clockwise and "Bahn 2" counter-clockwise around the main loop; driving backward
>     moves each of them in the other sense. Consequently (WORLD-06.1) "Bahn 2" enters the
>     calibration point and reaches the buffer stop driving forward and leaves it driving backward,
>     whereas "Bahn 1" enters it and reaches the buffer stop driving backward and leaves it driving
>     forward.

#### CTRL-05 – Fahrt nur in Standardrichtung, Haltezeit

Alt:

> - **CTRL-05** The component must drive every train to its stops one after the other in the defined
>   order. After the last stop the train must start again with the first stop (loop).

Neu:

> - **CTRL-05** The component must drive every train to its stops one after the other in the defined
>   order. After the last stop the train must start again with the first stop (loop).
>   - **CTRL-05.1** A train must drive to its stops in its default direction (WORLD-18.1), i.e.
>     "Bahn 1" clockwise and "Bahn 2" counter-clockwise. It may drive in its evasive direction only
>     to evade (CTRL-13.3) and where the track layout requires it to enter or to leave the
>     calibration point (WORLD-18.1).
>   - **CTRL-05.2** When a train has reached a stop of its sequence, it must stand there for the
>     dwell time (WORLD-17) and then drive on to its next stop.

#### CTRL-13 – Begegnung als Dauerfall, Weiterfahrt nach dem Ausweichen

Alt:

> - **CTRL-13** Conflict resolution: if two trains want to reserve the same block, the component must
>   apply the following rules:
>   - **CTRL-13.1** The train that is on a next-to-siding track must wait until the other train has
>     left the siding.
>   - **CTRL-13.2** The train that is on a siding may continue if the other train is on a
>     next-to-siding track and waits.
>   - **CTRL-13.3** If neither train is on a siding or a next-to-siding track, the train that is
>     closer to a siding must drive in its evasive direction (opposite to its default direction) to
>     this siding. "Closer" is computed dynamically as the track distance in cm from the train's
>     current position to the nearest siding. On the siding the train must wait until the other train
>     is on the next-to-siding track.
>   - **CTRL-13.4** If one train is already on its way to a siding, the other train must wait until
>     the block it wants to reserve is free.

Neu:

> - **CTRL-13** Conflict resolution: because the trains run in opposite directions (WORLD-18.1),
>   they meet head-on again and again during operation. If two trains want to reserve the same
>   block, the component must apply the following rules:
>   - **CTRL-13.1** The train that is on a next-to-siding track must wait until the other train has
>     left the siding.
>   - **CTRL-13.2** The train that is on a siding may continue if the other train is on a
>     next-to-siding track and waits.
>   - **CTRL-13.3** If neither train is on a siding or a next-to-siding track, the train that is
>     closer to a siding must drive in its evasive direction (opposite to its default direction) to
>     this siding. "Closer" is computed dynamically as the track distance in cm from the train's
>     current position to the nearest siding. On the siding the train must wait until the other train
>     is on the next-to-siding track.
>   - **CTRL-13.4** If one train is already on its way to a siding, the other train must wait until
>     the block it wants to reserve is free.
>   - **CTRL-13.5** As soon as the other train has passed, the train that evaded must leave the
>     siding and continue to its next stop in its default direction.

#### PREV-02 – Ausrichtung der Streckengrafik

Alt:

> - **PREV-02** The component must show a graphic of the track. The graphic must be generated from
>   the data of the `World Information` component.

Neu:

> - **PREV-02** The component must show a graphic of the track. The graphic must be generated from
>   the data of the `World Information` component and show the layout in the orientation of
>   WORLD-06 (front straight with the siding at the bottom, spur to the right).

#### UI-05 – Start nur mit mindestens einer Haltestelle

Alt:

> - **UI-05** After editing the stops the user must be able to press "Start". "Start" must:
>   - send the timetable to the `Control Algorithm` component;
>   - thereby start the control algorithm;
>   - lock the editing of the stops.

Neu:

> - **UI-05** After editing the stops the user must be able to press "Start". "Start" must:
>   - send the timetable to the `Control Algorithm` component;
>   - thereby start the control algorithm;
>   - lock the editing of the stops.
>   - **UI-05.1** "Start" is only possible if at least one train has at least one stop. Otherwise
>     the component must show the message "Bitte mindestens eine Haltestelle wählen" and must not
>     start the control algorithm. A train without stops stays where it is.

#### SETUP-03 – erste und zweite Bahn benannt

Alt:

> - **SETUP-03** The `Position` component must ask the `Preview UI` component to show the user that
>   the first train must be placed on the calibration point.

Neu:

> - **SETUP-03** The `Position` component must ask the `Preview UI` component to show the user that
>   the first train must be placed on the calibration point. The first train is "Bahn 1", the
>   second train is "Bahn 2".

#### SETUP-05 – Kalibrierrichtung Bahn 1

Alt:

> - **SETUP-05** The `Position` component must calibrate the first train. Afterwards it must drive the
>   train to the calibration waiting point (WORLD-07.3) and stop it there. The train must wait there
>   until the calibration of the second train is completed.

Neu:

> - **SETUP-05** The `Position` component must calibrate the first train ("Bahn 1" drives backward
>   against the buffer stop, WORLD-18.1). Afterwards it must drive the train forward to the
>   calibration waiting point (WORLD-07.3) and stop it there. The train must wait there until the
>   calibration of the second train is completed.

#### SETUP-08 – Kalibrierrichtung Bahn 2

Alt:

> - **SETUP-08** The `Position` component must calibrate the second train and then leave it at the
>   calibration point.

Neu:

> - **SETUP-08** The `Position` component must calibrate the second train ("Bahn 2" drives forward
>   against the buffer stop, WORLD-18.1) and then leave it at the calibration point.

#### REF-01 – UI-Spezifikation statt Mockup

Alt:

> - **REF-01** [Given] The frontend must be designed according to the
>   [UI mockup](../references/gartenbahn-mockup.html), including its German UI texts and its
>   shadcn/ui-like look (neutral zinc palette, thin borders, rounded corners). It must be styled with
>   Tailwind CSS.

Neu:

> - **REF-01** [Given] The frontend must be designed according to the
>   [UI Specification](#ui-specification) below, including its German UI texts and its
>   shadcn/ui-like look (neutral zinc palette, thin borders, rounded corners). It must be styled with
>   Tailwind CSS.

### 4.2 Neu hinzugekommen

#### WORLD-19 – Zeitvorgabe für eine Runde

> - **WORLD-19** [Given] Until the real values have been measured on the hardware (WORLD-05), the
>   values in the configuration must be chosen such that a train that drives at its normal speed and
>   does not have to wait needs between 20 and 30 seconds for one full lap of the main loop.

#### CTRL-14 – keine gemeinsame Blockbelegung, kein Deadlock

> - **CTRL-14** The two trains must never be in the same block at the same time, and the control
>   must never end in a state in which both trains wait for each other permanently (deadlock):
>   while the control algorithm is running, every train that has at least one stop must keep
>   reaching its stops.

#### UI-10 – Betriebsprotokoll

> - **UI-10** The component must show an operation log with the title "Betriebsprotokoll". It lists
>   the events of the control algorithm, newest first, each with its time of day (hh:mm:ss) and a
>   German text, and is updated live in every connected frontend. At least the 50 most recent
>   events must be shown; the log is kept as long as the backend runs (neither "Stop" nor "Alle
>   Strecken zurücksetzen" clears it). At least the following events must be logged with exactly
>   these texts (`<Bahn>` = name of the train, `<Haltestelle>` = name of the stop):
>   - "Start" — the user has pressed "Start" and the control algorithm has started;
>   - "Stop" — the user has pressed "Stop" and all trains have been stopped;
>   - "`<Bahn>` erreicht `<Haltestelle>`" — the train has arrived at a stop of its sequence
>     (CTRL-05.2);
>   - "`<Bahn>` weicht aus" — the train starts to drive in its evasive direction to the siding
>     (CTRL-13.3);
>   - "`<Bahn>` wartet auf dem Ausweichgleis" — the evading train has stopped on the siding;
>   - "`<Bahn>` wartet" — the train stops and waits because a block it needs is reserved by the
>     other train (CTRL-13.1, CTRL-13.4);
>   - "`<Bahn>` fährt weiter" — a train that was waiting (on the siding or elsewhere) drives on;
>   - "`<Bahn>` wird kalibriert" — the train drives against the buffer stop for a recalibration
>     (CTRL-11.1);
>   - "`<Bahn>` ist kalibriert" — the recalibration is finished and the train is released again.

#### SETUP-11 – Zeitvorgabe für die Kalibrierung

> - **SETUP-11** [Given] With the values of the configuration, the calibration of one train during
>   the First Setup must take at most 15 seconds, measured from the user's confirmation until the
>   next step is shown (for the first train this includes the drive to the calibration waiting
>   point).

Ebenfalls neu, in 4.1 mitzitiert: WORLD-06.1, WORLD-06.2, WORLD-18.1, CTRL-05.1, CTRL-05.2,
CTRL-13.5, UI-05.1. In der Einleitung steht neu der Satz zum Gegenverkehr, in den Begriffen die
Definition von „clockwise“ und „counter-clockwise“.

### 4.3 Abschnitt „UI Specification“ (ersetzt das Mockup)

Neu am Ende des Dokuments, rein als Text: Komponenten (Card, Button, Icon button, Select, Badge,
Tabs, Dialog, Alert, Toast, Logo, Track graphic), Schrift und Radien, die Zinc-Farbpalette hell und
dunkel, das Layout (zwei Spalten über 900 px, eine Spalte darunter, Telefon bis 640 px), der Aufbau
des Control Panels, der Dialog „Ersteinrichtung“ und acht Verhaltensregeln. Grundlage ist die
Stil-Liste aus Issue #2, angepasst an den letzten Mockup-Stand (zwei Bahnen, kein Login, beliebig
viele Haltestellen). Beispiel:

> 1. There is one common Start/Stop button for both trains.
> 2. State "Gestoppt": the stops of each train can be added, changed and removed; the button shows
>    "Start".
> 3. State "In Fahrt": the button shows "Stop" (red); the selects are disabled, the remove buttons
>    are hidden, the button "Haltestelle hinzufügen" is replaced by the disabled button "Während der
>    Fahrt gesperrt", and "Alle Strecken zurücksetzen" is disabled.
> 4. No layout shift: the status badge, the buttons and the lists keep their position and size when
>    the state changes.
> 5. There is no message on Start or Stop. A toast appears only for errors (e.g. "Bitte mindestens
>    eine Haltestelle wählen") and after resetting ("Alle Strecken zurückgesetzt").
> 6. When the page is opened after a backend start, all trains are stopped.
> 7. Trains cannot be renamed; there is no login.
> 8. Accessibility: visible focus ring, `aria-label` / `aria-pressed` on the controls, reduced
>    animations with `prefers-reduced-motion`.

### 4.4 Unverändert

Komponenten K-01/K-02, WORLD-01 bis -05 und -07 bis -15, alle POS-, INIT- und PREV-SETUP-
Anforderungen, CTRL-01 bis -04 und -06 bis -12, PREV-01/-03/-04, UI-01 bis -04 und -06 bis -09,
LOK-, SW- und RR-Abschnitte, SETUP-01/-02/-04/-06/-07/-09/-10, UC-01, REF-02.

## 5. Tests: alt und neu

Weiterhin 36 Tests. Alle Zitate stammen wörtlich aus `tasks/tests-1.json` (alt) und
`tasks/tests-2.json` (neu); der Schritt „Work strictly sequentially …“ ist in den Zitaten
weggelassen.

### 5.1 Entfallen als eigene Tests (in Nachbartests aufgegangen)

In t1 hat jeder der 16 Läufe diese sieben Tests bestanden; sie haben also nichts unterschieden.

| Alt | Feature (alt) | Jetzt geprüft in |
| --- | --- | --- |
| TC-05 | Exactly two trains | TC-02 – Page structure follows the UI specification |
| TC-07 | First setup shows the switch hint | TC-04 – First setup asks for the first train and shows the switch hint |
| TC-12 | Both trains are shown after the setup | TC-08 – Completing the setup in one frontend completes it in all frontends |
| TC-15 | The second train stays at the calibration point | TC-10 – After the setup the first train waits at the calibration waiting point and the second stays at the calibration point |
| TC-19 | Each train has its own stop list | TC-15 – Any number of stops, the same stop several times, one list per train |
| TC-31 | Unreachable switch server: error message | TC-32 – Unreachable switch server: switches turn red and an error message is shown |
| TC-34 | Unreachable locomotive server: error message | TC-34 – Unreachable locomotive server: train hidden, disconnected and an error message is shown |

### 5.2 Neu hinzugekommen

**TC-12 – Responsive layout**

> Steps: Open the app; Resize the browser window to 800 pixels width and 900 pixels height; Take a screenshot of the page; Resize the browser window to 1280 pixels width and 900 pixels height; Take a screenshot of the page
>
> Expected: At 800 pixels width the cards are stacked in one column, 'Gartenbahn-Ansicht' above 'Control Panel' above 'Alle Strecken zurücksetzen', and nothing is cut off at the right edge; at 1280 pixels width 'Gartenbahn-Ansicht' (left, wider) and 'Control Panel' (right) are side by side

**TC-17 – Start without any stop is refused**

> Steps: Open the app; If the status badge shows 'In Fahrt', click the Stop button; Click 'Alle Strecken zurücksetzen'; Click the Start button and read the page immediately afterwards; Read the status badge
>
> Expected: The control does not start: the status badge still shows 'Gestoppt' and the Start button is still shown, and the message 'Bitte mindestens eine Haltestelle wählen' appears (it may disappear again after a few seconds)

**TC-21 – The trains run around the loop in opposite directions**

> Steps: Open the app; If the status badge shows 'In Fahrt', click the Stop button; Select 'Bahn 1' and make sure that its stop list is exactly 1. 'Haltestelle 2', 2. 'Haltestelle 4': add, change or remove stops only if necessary, one change at a time; Select 'Bahn 2' and make sure that its stop list is exactly 1. 'Haltestelle 4', 2. 'Haltestelle 2': add, change or remove stops only if necessary, one change at a time; Click the Start button; Wait 10 seconds; when the wait has finished, take a new screenshot of the track graphic; Wait 5 seconds; when the wait has finished, take a new screenshot of the track graphic; Wait 5 seconds; when the wait has finished, take a new screenshot of the track graphic; Wait 5 seconds; when the wait has finished, take a new screenshot of the track graphic; Wait 5 seconds; when the wait has finished, take a new screenshot of the track graphic
>
> Expected: Comparing consecutive screenshots, the marker of 'Bahn 1' moves clockwise along the main loop (on the top straight from left to right, on the right curve downwards, on the bottom straight from right to left, on the left curve upwards) and the marker of 'Bahn 2' moves counter-clockwise; phases in which a train stands still, evades to the siding or drives to or from the calibration point do not count, and it is sufficient that each train is seen moving in its own sense in at least one pair of consecutive screenshots; the two trains do not circle the loop in the same sense

**TC-23 – Head-on meeting: one train evades to the siding**

> Steps: Open the app; If the status badge shows 'In Fahrt', click the Stop button; Select 'Bahn 1' and make sure that its stop list is exactly 1. 'Haltestelle 2', 2. 'Haltestelle 4': add, change or remove stops only if necessary, one change at a time; Select 'Bahn 2' and make sure that its stop list is exactly 1. 'Haltestelle 4', 2. 'Haltestelle 2': add, change or remove stops only if necessary, one change at a time; Click the Start button; Wait 30 seconds; Wait 30 seconds; Wait 30 seconds; Take a new accessibility snapshot and read the entries of the 'Betriebsprotokoll' that are newer than the most recent entry 'Start'
>
> Expected: Since the last 'Start' the log contains at least one entry '<train> weicht aus' and, later, an entry '<train> wartet auf dem Ausweichgleis' for the same train: when the trains met head-on, one of them drove back to the siding

**TC-24 – After a meeting both trains continue (no deadlock)**

> Steps: Open the app; If the status badge shows 'In Fahrt', click the Stop button; Select 'Bahn 1' and make sure that its stop list is exactly 1. 'Haltestelle 2', 2. 'Haltestelle 4': add, change or remove stops only if necessary, one change at a time; Select 'Bahn 2' and make sure that its stop list is exactly 1. 'Haltestelle 4', 2. 'Haltestelle 2': add, change or remove stops only if necessary, one change at a time; Click the Start button; Wait 30 seconds; Wait 30 seconds; Wait 30 seconds; Wait 30 seconds; Take a new accessibility snapshot and read the entries of the 'Betriebsprotokoll' that are newer than the most recent entry 'Start'
>
> Expected: Since the last 'Start' the log contains an entry '<train> wartet auf dem Ausweichgleis', later '<train> fährt weiter' for the same train, and after that further entries '… erreicht …' for both 'Bahn 1' and 'Bahn 2': the trains passed each other and both keep reaching their stops

**TC-28 – The operation log shows Start and Stop**

> Steps: Open the app; If the status badge shows 'In Fahrt', click the Stop button; Select 'Bahn 1' and make sure that its stop list is exactly 1. 'Haltestelle 2', 2. 'Haltestelle 4': add, change or remove stops only if necessary, one change at a time; Select 'Bahn 2' and make sure that its stop list is exactly 1. 'Haltestelle 4', 2. 'Haltestelle 2': add, change or remove stops only if necessary, one change at a time; Click the Start button; Take a new accessibility snapshot and read the newest entries of the 'Betriebsprotokoll'; Wait 5 seconds; Click the Stop button; Take a new accessibility snapshot and read the newest entries of the 'Betriebsprotokoll'
>
> Expected: After Start the log shows a new entry 'Start', and after Stop the newest entry, at the top of the log, is 'Stop'; every entry shows a time of day

**TC-31 – Operation can be started again after a Stop**

> Steps: Open the app; If the status badge shows 'In Fahrt', click the Stop button; Select 'Bahn 1' and make sure that its stop list is exactly 1. 'Haltestelle 2', 2. 'Haltestelle 4': add, change or remove stops only if necessary, one change at a time; Select 'Bahn 2' and make sure that its stop list is exactly 1. 'Haltestelle 4', 2. 'Haltestelle 2': add, change or remove stops only if necessary, one change at a time; Click the Start button; Wait 20 seconds; Click the Stop button; Wait 3 seconds; Click the Start button; Wait 30 seconds; Wait 30 seconds; Take a new accessibility snapshot and read the entries of the 'Betriebsprotokoll' that are newer than the most recent entry 'Start'
>
> Expected: The log shows, from old to new, 'Start', 'Stop' and 'Start' again, and after the second 'Start' at least one new entry '<train> erreicht <stop>': after a Stop the operation starts again and the trains continue to reach their stops

### 5.3 Inhaltlich geändert

| Neu | Alt | Änderung |
| --- | --- | --- |
| TC-02 | TC-02 + TC-05 | „UI specification“ statt „UI mockup“; genau zwei Bahnen; Karte „Betriebsprotokoll“ |
| TC-03 | TC-04 | Karte muss die Lage aus WORLD-06 zeigen (Stumpfgleis als gerade Verlängerung, nicht nach unten) |
| TC-04 | TC-06 + TC-07 | Dialog für Bahn 1 und Weichenhinweis in einem Test |
| TC-06, TC-08 | TC-09, TC-11 | 25 s statt 20 s, Lesen erst nach Ablauf der Wartezeit; TC-08 prüft zusätzlich beide Marker |
| TC-09 | TC-13 | Kalibrierrichtung: Bahn 1 rückwärts, Bahn 2 vorwärts |
| TC-10 | TC-14 + TC-15 | Bahn 1 fährt danach vorwärts zum Wartepunkt, Bahn 2 bleibt stehen |
| TC-11 | TC-03 | Stil nach UI-Spezifikation; nach dem Setup, damit der Dialog das Bild nicht abdunkelt |
| TC-14, TC-15 | TC-17, TC-18 + TC-19 | feste Haltestellennamen, eine Auswahl pro Schritt |
| TC-19 | TC-22 | normale Geschwindigkeit muss mit Richtung „forward“ vorkommen |
| TC-26, TC-27 | TC-26, TC-27 | Nachweis über das Betriebsprotokoll statt nur über Screenshots |
| TC-32, TC-34 | TC-30 + TC-31, TC-33 + TC-34 | rote Weichen bzw. versteckte Bahn und Fehlermeldung in einem Test |

Zwei Beispiele im Wortlaut:

Alt **TC-13 – Calibration uses the slow calibration speed**

> Steps: Open the mock server console at http://localhost:3031; Read the column 'Applied speed changes (oldest first)' of 'Bahn 1' and 'Bahn 2'
>
> Expected: For both trains the history contains a low speed greater than 0 (the calibration speed) that is later followed by speed 0

Neu **TC-09 – Each train is calibrated in its own direction**

> Steps: Open the mock server console at http://localhost:3031; Read the column 'Applied speed changes (oldest first)' of 'Bahn 1' and 'Bahn 2'
>
> Expected: The history of 'Bahn 1' contains a low speed greater than 0 with the direction backward (the calibration speed: 'Bahn 1' backs against the buffer stop), the history of 'Bahn 2' contains the same low speed with the direction forward, and for both trains it is later followed by speed 0

Alt **TC-26 – Stops are driven in a loop**

> Steps: Open the app; If the status badge shows 'In Fahrt', click the Stop button; Click 'Alle Strecken zurücksetzen'; Select 'Bahn 1' and click 'Haltestelle hinzufügen' twice; If both stops of 'Bahn 1' show the same stop, set the second one to a different stop; call the two stops A and B; Select 'Bahn 2' and click 'Haltestelle hinzufügen' twice; Set the first stop of 'Bahn 2' to A and the second stop of 'Bahn 2' to B; Click the Start button; Take a screenshot of the track graphic; Wait 25 seconds, then take a new screenshot of the track graphic; Wait 25 seconds, then take a new screenshot of the track graphic; Wait 25 seconds, then take a new screenshot of the track graphic; Wait 25 seconds, then take a new screenshot of the track graphic
>
> Expected: 'Bahn 1' is seen at stop A, later at stop B and later again at stop A (a detour to the calibration point in between is allowed); it does not stay at stop B

Neu **TC-26 – Stops are driven in a loop**

> Steps: Open the app; If the status badge shows 'In Fahrt', click the Stop button; Select 'Bahn 1' and make sure that its stop list is exactly 1. 'Haltestelle 2', 2. 'Haltestelle 4': add, change or remove stops only if necessary, one change at a time; Select 'Bahn 2' and make sure that its stop list is exactly 1. 'Haltestelle 4', 2. 'Haltestelle 2': add, change or remove stops only if necessary, one change at a time; Click the Start button; Wait 30 seconds; Wait 30 seconds; Wait 30 seconds; Wait 30 seconds; Wait 30 seconds; Take a new accessibility snapshot and read the entries of the 'Betriebsprotokoll' that are newer than the most recent entry 'Start'
>
> Expected: Since the last 'Start' the log contains 'Bahn 1 erreicht Haltestelle 2', later 'Bahn 1 erreicht Haltestelle 4' and later again 'Bahn 1 erreicht Haltestelle 2' (other entries in between are allowed): after its last stop the train starts again with its first stop

### 5.4 Nur umnummeriert oder in der Vorbereitung angepasst

TC-01, TC-05, TC-07, TC-13, TC-16, TC-18, TC-20, TC-22, TC-25, TC-29, TC-30, TC-33, TC-35, TC-36.
Die Fahrtests nutzen jetzt feste Haltestellen (Bahn 1: Haltestelle 2 → 4, Bahn 2: Haltestelle
4 → 2) und stellen sie nur her, wenn sie nicht schon stimmen:

> Select 'Bahn 1' and make sure that its stop list is exactly 1. 'Haltestelle 2', 2. 'Haltestelle 4': add, change or remove stops only if necessary, one change at a time

## 6. Was über den freigegebenen Plan hinausgeht

- **Betriebsprotokoll (UI-10):** nötig, damit Ausweichen, Warten, Rundkurs und Kalibrierung ohne
  zufällig getimte Screenshots prüfbar sind.
- **Sequenz-Schritt und 30-s-Grenze** in den Tests (Abschnitt 3).
- **TC-21 und TC-25:** weniger bzw. länger verteilte Screenshots, weil das Aktionsbudget von 24
  sonst nicht reicht oder eine Bahn gerade auf Kalibrierfahrt ist.
- **Streckenlayout:** nach deinem Hinweis zweimal präzisiert, zuletzt als Aufzählung der Teile
  mit dem Satz zu den drei Gleisebenen.
- **Codex:** für t2 `gpt6.1terra`, kein Sol; die leeren T1-Codex-Zeilen sind aus der Tabelle
  entfernt, die T1-Codex-Branches bestehen weiter.

## 7. So startest du

Einmalig auf dem Mac, bevor der erste gezählte Lauf startet (Claude Code fragt im neuen Ordner
einmal nach Vertrauen; das soll nicht in einer gezählten Session passieren):

```bash
TASK=t2 ~/Desktop/Code/Skills/softwareprojektTDDev/tools/agent.sh login claude
```

Dort den Ordner bestätigen und mit `/exit` beenden. Danach pro Lauf wie bisher, nur mit `t2-`:

```bash
C=~/Desktop/Code/Skills/softwareprojektTDDev/tools/case.sh
A=~/Desktop/Code/Skills/softwareprojektTDDev/tools/agent.sh
$C start  t2-sonnet5.5-vanilla-r1
$A run    t2-sonnet5.5-vanilla-r1
$C finish t2-sonnet5.5-vanilla-r1
$C check  t2-sonnet5.5-vanilla-r1
$A check  t2-sonnet5.5-vanilla-r1
$C finish t2-sonnet5.5-vanilla-r1
```

- Reihenfolge: Vanilla, Agentic, Whole, Incremental zuletzt. Bei t1 entfielen 52 von 70,5
  Baustunden auf die vier Incremental-Läufe.
- Pro Rechner nur eine Session (feste Ports 3030, 3031, 8095, 8076–8078).
- Auswertung: `python3 tools/metrics.py summary results/runs.csv` rechnet t1 und t2 getrennt.
- Linux (Codex): README Abschnitt 1b „Zweiter Rechner“. Dort `TASK=t2 $A setup`,
  `$A login codex`, `TASK=t2 $A doctor gpt6.1terra`. Der Check läuft danach auf dem Mac:
  `$C check <run-id>` holt den Branch selbst.

## 8. Offene Punkte

- **Codex ist ungetestet.** Start-Flags und Token-Zählung für Codex sind nie mit einer echten
  Session gelaufen. Vor dem ersten gezählten Codex-Lauf muss `doctor` auf Linux alle fünf Skills,
  `subagent_used: true` und den Seitentitel melden; nach dem ersten Lauf die Token-Zeile prüfen.
- **Parallele Aufrufe sind seltener, nicht weg.** Im Nach-Check blieben 14 von 380
  Browser-Nachrichten parallel, 5 davon mit Wartezeit.
- **Hohe Streuung zu erwarten.** Viele Fahrtests hängen an derselben Ursache; ein Stillstand
  nach „Start“ kostet auf einen Schlag rund neun Tests.
- **Headless-Pilot.** Die Piloten liefen mit `claude -p`, die gezählten Läufe starten interaktiv
  über `agent.sh`. Flags und Profil sind gleich.
- **Pilot-Klone** liegen unter `Softwareprojekt/App-T2-Pilot`, `-Pilot2`, `-Pilot3`. Sie sind nur
  lokal, nirgends gepusht und können bleiben oder gelöscht werden.
