# Requirements: Automatic Control of the Garden Railway

# Project Introduction

Please implement a web application that automatically controls a physical garden railway (layout:
see the [reference photo](../references/gartenbahn-aufbau.jpg)). For each of the two trains the
user defines a sequence of stops and starts operation. A control algorithm in the backend then
drives the trains to their stops via the existing hardware servers (Locomotive Server, Switch
Server), sets the switches and resolves conflicts when both trains need the same track section.
The positions of the trains are estimated from speed and driving time and are re-determined at a
calibration point. A preview shows the track, the switch positions and the train positions live.

Conventions of this document:

- Every requirement has a unique ID. "must" marks a mandatory requirement.
- **[Given]** marks an explicitly prescribed technology or design decision.
- `BAHN_SYNC_*` are environment variables of the backend; the value after "default" applies when
  the variable is not set.
- Terms: *train* = a locomotive with its cars; *block* = track section; *timetable* = the sequences
  of stops of all trains defined by the user; *reserve* = block a block for one train so that no
  other train may enter it.

# Components

The application consists of the components described below.

- **K-01** The *Initialization logic* of every component must run when the backend server starts
  (sequence: see stage [Initialization](#initialization)).
- **K-02** The *First Setup logic* of every component must run when the position of at least one
  train or the position of at least one switch is unknown. This state occurs immediately after the
  backend starts (sequence: see stage [First Setup](#first-setup)).

## World Information

German: `Welt-Informationen`.

- **WORLD-01** The `World Information` component must run in the backend.
- **WORLD-02** The component must represent the physical layout of the garden railway (track and
  trains) in code.
- **WORLD-03** The track layout is static: the application must support exactly one track layout.
  It must be stored in this component and be adjustable there.
- **WORLD-04** [Given] The track layout and the train data must be stored in a configuration file.
  A TypeScript file with arrays and objects (dictionaries) is acceptable as configuration file.
- **WORLD-05** All track lengths, train speeds and calibration values must be defined only in the
  configuration file, so that they can be measured and corrected by hand on the hardware after
  code generation without changing program logic.
- **WORLD-06** The track layout is based on the physical layout in the
  [reference photo](../references/gartenbahn-aufbau.jpg) and drawn schematically in the track
  graphic of the [UI mockup](../references/gartenbahn-mockup.html): an elongated oval main loop
  with long straight sides. Along the front straight, a siding runs on the outside of the loop,
  between two switches on the main line. A third switch lies on the siding; from it a dead-end
  spur leads away from the loop (outwards, not into the loop) and ends at a buffer stop. This spur
  is the calibration point.
- **WORLD-07** The track must be divided into sections (blocks).
  - **WORLD-07.1** The length (in cm) must be definable for each block individually.
  - **WORLD-07.2** Every block must have exactly one of the following block types: *track*,
    *switch*, *calibration point*.
  - **WORLD-07.3** Exactly one block of the track must be markable as *calibration waiting point*.
    During the First Setup the first calibrated train waits there (see SETUP-05).
  1. **Track**
     - **WORLD-08** A block of type track is a simple track section. It must have a length, exactly
       one predecessor block and exactly one successor block.
     - **WORLD-09** Every track must have one of the following track types:
       - **Normal track**: track section without a special function.
       - **Siding** (German: Ausweichstrecke): lies between two switches; is used only to let
         another train pass; is the alternative to the next-to-siding track between the same two
         switches.
       - **Next-to-siding track** (German: Next-to-Ausweich-Strecke): lies between two switches; is
         the main route next to the corresponding siding; can additionally be marked as stop.
       - **Stop** (German: Haltestelle): can be selected as destination of a train.
  2. **Switch**
     - **WORLD-10** A switch must connect exactly three blocks: either two predecessors and one
       successor, or one predecessor and two successors.
     - **WORLD-11** A switch must have two lengths: one for each of the two possible routes through
       the switch (from the single connection to the one or the other of the two connections on the
       opposite side).
     - **WORLD-12** Of the two connections on the side with two blocks, exactly one must be marked as
       connection of the siding (entry to the siding or exit from the siding).
     - **WORLD-13** The following metadata must be stored for every switch:
       - the name of the Switch Server that manages the switch;
       - the index of the switch in the switch array of this Switch Server, by which the switch is
         controlled.
     - **WORLD-14** For every switch the configuration must define, for each of its two switch
       positions, which two blocks the switch connects in that position. The switch positions are
       the `track` values of the Switch Server: `1` (straight) and `2` (diverging).
  3. **Calibration point**
     - **WORLD-15** A calibration point is a simple track section with a buffer stop at its end. It
       must have a length and exactly one predecessor block and must not have a successor block.
     - **WORLD-16** A train must be calibratable at the calibration point: the train drives against
       the buffer stop with the calibration speed for the calibration duration; afterwards its
       position is known.
- **WORLD-17** The following calibration values must be defined at the top level of the
  configuration (not per train):
  - calibration duration in ms (default: 3000);
  - calibration speed as speed value for the API of the Locomotive Server (integer 0–255,
    default: 60). It must be lower than the speed values of the trains.
- **WORLD-18** The application must support exactly two trains. The following metadata must be
  stored for each train:
  - name of the train; it is also the name under which the train's Locomotive Server is registered
    at the Railroad Server;
  - speed in the physical world in cm/s;
  - speed value for the API of the Locomotive Server (integer 0–255) that corresponds to this
    physical speed;
  - maximum distance without recalibration in cm, i.e. the distance the train may cover at most
    since its last calibration before it must be calibrated again;
  - driving direction: a default direction and an evasive direction, which is opposite to the
    default direction;
  - length of the train in cm.

## Position

- **POS-01** The `Position` component must run in the backend.
- **POS-02** The component must establish the connection to the physical trains and switches.
- **POS-03** For every train the component must read the speed metadata from the
  `World Information` component:
  - the speed value that is passed to the Locomotive Server;
  - the speed in the physical world that this value corresponds to.
- **POS-04** The component must read the switch metadata (WORLD-13, WORLD-14) from the
  `World Information` component.
- **POS-05** The component must allow other components to query to which trains and switches a
  connection has been established successfully.
- **POS-06** The component must offer the following control commands to other components:
  - **POS-06.1** set the movement of a train to exactly one of *forward*, *backward* or *stop*. For
    *forward* and *backward* the speed value stored in the train's metadata must be used. The only
    exception is the calibration: only while a train drives against the buffer stop of the
    calibration point, the calibration speed (WORLD-17) must be used. No other speeds are allowed.
  - **POS-06.2** change the position of a switch.
- **POS-07** The component must handle the communication with the hardware servers (Locomotive
  Server, Switch Server). Other components control trains and switches only through this
  component.
- **POS-08** The component must store the current real state:
  - the current position of every switch;
  - the current position of every train.
- **POS-09** The position of a train must be estimated:
  - **POS-09.1** The current position must be stored as (a) current block and (b) position within
    this block.
  - **POS-09.2** In every tick the position must be advanced by (tick duration × current speed).
    The component must use the same tick as the `Control Algorithm` (`BAHN_SYNC_TICK_MS`,
    default 50).
  - **POS-09.3** For every train the total distance covered since its last calibration must be
    stored.
- **POS-10** The Railroad Server to be used must be configurable via the environment variable
  `BAHN_SYNC_RAILROAD_URL` (default: `http://ise-rrs01:8095`, the live Railroad Server). It
  distinguishes the live environment from the test environment:
  - In the live environment the component must connect to the real Railroad Server.
  - In the test environment the component must connect to the mock variant of the Railroad Server
    (`http://localhost:8095`).

### Initialization logic

- **POS-INIT-01** The component must determine all switches stored in the `World Information`
  component and establish a WebSocket connection to them (via the responsible Switch Server).
- **POS-INIT-02** The component must determine all trains stored in the `World Information`
  component and establish a WebSocket connection to them (via the responsible Locomotive Server).
- **POS-INIT-03** The component must take the current position of every switch from its Switch
  Server. The positions reported by the Switch Server are regarded as correct; afterwards the
  positions of all switches are known.

## Control Algorithm

German: `Steuerungsalgorithmus`.

- **CTRL-01** The `Control Algorithm` component must run in the backend.
- **CTRL-02** The component must determine how the trains currently drive. It must work in ticks of
  `BAHN_SYNC_TICK_MS` milliseconds (default 50).
- **CTRL-03** The timetable must be defined by the `Control UI` component.
- **CTRL-04** As soon as a timetable has been defined and sent to the component, the component must
  start controlling.
- **CTRL-05** The component must drive every train to its stops one after the other in the defined
  order. After the last stop the train must start again with the first stop (loop).
- **CTRL-06** The component must read the track layout from the `World Information` component.
- **CTRL-07** The component must read the current state from the `Position` component:
  - the current positions of the trains;
  - the current positions of the switches.
- **CTRL-08** The component must pass all commands for controlling the physical trains and switches
  to the `Position` component, which executes them.
- **CTRL-09** As long as the `First Setup` stage is not completed, the component must not accept
  any control. It must query the `Position` component whether the stage is completed.
- **CTRL-10** When the component is stopped, all trains must stop.

The control algorithm must work according to the following criteria:

- **CTRL-11** Recalibration: if a train must be recalibrated (the distance it has covered since its
  last calibration has reached its maximum distance without recalibration), the component must
  temporarily ignore the stops of this train and set the calibration point as temporary
  destination.
  - **CTRL-11.1** When the train has reached the calibration point, the component must give the
    `Position` component a dedicated recalibration command: the train drives against the buffer
    stop with the calibration speed for the calibration duration (WORLD-17), so that its position
    is known afterwards. Then the train must be released again and continue with its stops.
  - **CTRL-11.2** If the environment variable `BAHN_SYNC_RECALIBRATION_DISTANCE_CM` is set, its
    value must replace the maximum distance without recalibration of all trains (WORLD-18). The
    test environment sets it to 1500 so that a recalibration happens within a short test.
- **CTRL-12** Reservation: on the way to its next stop a train must reserve the blocks it has to
  pass to reach its destination. It must always reserve exactly X blocks ahead; X is set by the
  environment variable `BAHN_SYNC_RESERVATION_BLOCKS` (default 3).
- **CTRL-13** Conflict resolution: if two trains want to reserve the same block, the component must
  apply the following rules:
  - **CTRL-13.1** The train that is on a next-to-siding track must wait until the other train has
    left the siding.
  - **CTRL-13.2** The train that is on a siding may continue if the other train is on a
    next-to-siding track and waits.
  - **CTRL-13.3** If neither train is on a siding or a next-to-siding track, the train that is
    closer to a siding must drive in its evasive direction (opposite to its default direction) to
    this siding. "Closer" is computed dynamically as the track distance in cm from the train's
    current position to the nearest siding. On the siding the train must wait until the other train
    is on the next-to-siding track.
  - **CTRL-13.4** If one train is already on its way to a siding, the other train must wait until
    the block it wants to reserve is free.

## Preview UI

- **PREV-01** The `Preview UI` component must run in the frontend.
- **PREV-02** The component must show a graphic of the track. The graphic must be generated from
  the data of the `World Information` component.
- **PREV-03** The component must show the live position of every train. It must get the positions
  from the `Position` component. The displayed positions must be updated every
  `BAHN_SYNC_PREVIEW_INTERVAL_MS` milliseconds (backend environment variable, default 100).
  - **PREV-03.1** A train to which no connection can be established must not be shown.
- **PREV-04** The component must show the live position of every switch. It must get the positions
  from the `Position` component.
  - **PREV-04.1** A switch to which no connection can be established must be highlighted in red.

### First Setup logic

- **PREV-SETUP-01** The component must show the hint that the user should check whether the
  switches are set correctly.
- **PREV-SETUP-02** The component must show a popup that asks the user to calibrate the trains.
- **PREV-SETUP-03** The component must send the user's input to the `Position` component, e.g. the
  confirmation "The train is now at the calibration point".
- **PREV-SETUP-04** The component must perform the calibration together with the `Position`
  component (sequence: see stage [First Setup](#first-setup)).
- **PREV-SETUP-05** Several frontends can be connected at the same time. All connected frontends
  must show the current step of the First Setup, and the user must be able to confirm the current
  step in any of them.
- **PREV-SETUP-06** Only the first confirmation of a step counts; no other frontend can overwrite
  it. If a frontend tries to confirm a step that has already been confirmed, it must show an error
  message and then switch to the current step.

## Control UI

German: `Steuerungs-UI`.

- **UI-01** The `Control UI` component must run in the frontend.
- **UI-02** The user must be able to define the sequence of stops for each train with this
  component. Any number of stops can be added, and the same stop can occur several times in one
  sequence.
- **UI-03** The component must show the live status of every train:
  - the current speed of the train;
  - whether a connection to the train exists.

  The component must get this information from the `Position` component.
- **UI-04** The component must be locked as long as the `First Setup` stage is not completed.
- **UI-05** After editing the stops the user must be able to press "Start". "Start" must:
  - send the timetable to the `Control Algorithm` component;
  - thereby start the control algorithm;
  - lock the editing of the stops.
- **UI-06** While the trains are running, the user must be able to press "Stop". "Stop" must:
  - stop the control algorithm, and thereby stop all trains;
  - unlock the editing of the stops.
- **UI-07** The list of selectable stops must come from the `World Information` component.
- **UI-08** The component must query the `Position` component whether the `First Setup` stage is
  completed. If it is not completed, the "Start" and "Stop" buttons must be locked (refines UI-04).
- **UI-09** The component must offer the button "Alle Strecken zurücksetzen" (reset all routes).
  It is a frontend action: while the trains are stopped (and the stops can be edited), it must
  remove all stops of all trains. While the trains are running it must be locked.

## Locomotive Server

- **LOK-01** The Locomotive Server is an external system. It is operated independently of this
  application and is not part of the application to be developed.
- **LOK-02** The Locomotive Server accepts commands to control a physical train.
- **LOK-03** The `Position` component must connect to the Locomotive Server and control the train
  via this connection.

### Mock variant

- **LOK-MOCK-01** There is a mock variant of the Locomotive Server. It accepts the same commands but
  does not control a physical train.
- **LOK-MOCK-02** The mock variant is used for local testing.
- **LOK-MOCK-03** The mock variant is provided in [`tdd/mock-servers/`](mock-servers/README.md)
  (protocol-compatible with the real server; part of the test setup, must not be modified). It
  provides the trains "Bahn 1" and "Bahn 2".

### Reference

- Source code: [`references/ise-server/locomotive-server`](../references/ise-server/locomotive-server)
  (git submodule `references/ise-server`).
- Original logging variant: `LoggingServlet` in
  [`locomotive-server/src/main/kotlin/locomotive/server/LoggingServlet.kt`](../references/ise-server/locomotive-server/src/main/kotlin/locomotive/server/LoggingServlet.kt).
- Protocol summary: [`tdd/mock-servers/README.md`](mock-servers/README.md).

## Switch Server

- **SW-01** The Switch Server is an external system. It is operated independently of this
  application and is not part of the application to be developed.
- **SW-02** The Switch Server accepts commands to control one or more physical switches.
- **SW-03** The `Position` component must connect to the Switch Server and control the switches via
  this connection.

### Mock variant

- **SW-MOCK-01** There is a mock variant of the Switch Server. It accepts the same commands but does
  not control a physical switch.
- **SW-MOCK-02** The mock variant is used for local testing.
- **SW-MOCK-03** The mock variant is provided in [`tdd/mock-servers/`](mock-servers/README.md)
  (protocol-compatible with the real server; part of the test setup, must not be modified). It
  provides the Switch Server "Weichen" with four switches (indices 0–3).

### Reference

- Source code: [`references/ise-server/switch-server`](../references/ise-server/switch-server)
  (git submodule `references/ise-server`).
- Original logging variant: `LoggingSwitchServlet` in
  [`switch-server/src/main/kotlin/servlet/railroadswitch/LoggingSwitchServlet.kt`](../references/ise-server/switch-server/src/main/kotlin/servlet/railroadswitch/LoggingSwitchServlet.kt).
- Protocol summary: [`tdd/mock-servers/README.md`](mock-servers/README.md).

## Railroad Server

- **RR-01** The Railroad Server is an external system. It is operated independently of this
  application and is not part of the application to be developed.
- **RR-02** The Railroad Server tells the backend which trains and switches exist in the physical
  world.
- **RR-03** The Railroad Server tells the backend at which addresses the control servers
  (Locomotive Server, Switch Server) can be reached.

### Mock variant

- **RR-MOCK-01** There is a mock variant of the Railroad Server. It provides the information about
  the connected mock servers (mock variants of the Locomotive Server and the Switch Server).
- **RR-MOCK-02** The mock variant is used for local testing.
- **RR-MOCK-03** The mock variant is provided in [`tdd/mock-servers/`](mock-servers/README.md)
  at `http://localhost:8095`. The start command of the test environment (see `tdd/app.md`) starts
  all mock servers together with the application and sets `BAHN_SYNC_RAILROAD_URL` accordingly
  and `BAHN_SYNC_RECALIBRATION_DISTANCE_CM` to 1500.

### Reference

- Source code: [`references/ise-server/railroad-server`](../references/ise-server/railroad-server)
  (git submodule `references/ise-server`; HTTP REST API, default port 8095).

# Stages

When the backend starts, the current positions of the trains and switches are unknown. Therefore a
setup must be performed first, which runs in the following stages in the given order.

## Initialization

> Trigger: start of the backend.

- **INIT-01** The `Position` component must ask the Railroad Server which trains and switches are
  connected.
- **INIT-02** The `Position` component must compare the trains and switches defined in the
  `World Information` component with the information of the Railroad Server.
  - **INIT-02.1** If at least one switch or train defined in the `World Information` component is
    missing at the Railroad Server, the frontend must show an error message with the literal text
    "Ich kann so nicht arbeiten".
- **INIT-03** The `Position` component must establish a WebSocket connection to all Locomotive
  Servers and Switch Servers that are needed for the trains and switches configured in the
  `World Information` component.
- **INIT-04** The `Position` component must take the current switch positions from the Switch
  Servers (POS-INIT-03).
- **INIT-05** After a connection has been established, the `Position` component must ensure that
  the WebSocket connection is kept; if it breaks, the component must re-establish it.
- **INIT-06** The stage is completed as soon as the connections to all servers are established.
- **INIT-07** As long as a server cannot be reached, the frontend must show an error message for
  each unreachable server that names this server. If a server cannot be reached during this stage,
  the stage is not completed and the `First Setup` stage is not executed.

## First Setup

> Trigger: a web frontend connects to the backend.

- **SETUP-01** When a web frontend connects to the backend, the `Position` component must check
  whether the positions of all switches and all trains are known. (The backend starts with unknown
  train positions; the switch positions are known after the Initialization stage.)
- **SETUP-02** If all positions are known, the stage is completed. Otherwise steps SETUP-03 to
  SETUP-10 must be executed in this order. Every connected frontend shows the current step
  (PREV-SETUP-05, PREV-SETUP-06).
- **SETUP-03** The `Position` component must ask the `Preview UI` component to show the user that
  the first train must be placed on the calibration point.
- **SETUP-04** The user confirms in the `Preview UI` component that the first train has been
  placed; the `Preview UI` component must send this confirmation to the `Position` component.
- **SETUP-05** The `Position` component must calibrate the first train. Afterwards it must drive the
  train to the calibration waiting point (WORLD-07.3) and stop it there. The train must wait there
  until the calibration of the second train is completed.
- **SETUP-06** The `Position` component must ask the `Preview UI` component to show the user that
  the second train must be placed on the calibration point.
- **SETUP-07** The user confirms in the `Preview UI` component that the second train has been
  placed; the `Preview UI` component must send this confirmation to the `Position` component.
- **SETUP-08** The `Position` component must calibrate the second train and then leave it at the
  calibration point.
- **SETUP-09** The `Position` component must tell the `Preview UI` component that the trains are
  calibrated and send it the current positions of the trains.
- **SETUP-10** Then the stage is completed.

# Use Cases

- **UC-01** Operating the garden railway. The following sequence must be possible in this order:
  1. The backend is started.
  2. The `Initialization` stage runs.
  3. A web frontend connects to the backend.
  4. The `First Setup` stage runs.
  5. Afterwards the user can:
     - edit the stops of the two trains;
     - make the trains drive with "Start"; the control algorithm then controls them according to
       the timetable;
     - stop the trains again with "Stop".

# References

- **REF-01** [Given] The frontend must be designed according to the
  [UI mockup](../references/gartenbahn-mockup.html), including its German UI texts and its
  shadcn/ui-like look (neutral zinc palette, thin borders, rounded corners). It must be styled with
  Tailwind CSS.
- **REF-02** [Given] The application must be built on the existing project setup. If libraries are
  needed for a task, their current versions must be used, in particular:
  - Bun as runtime;
  - Hono as web server, with server-side rendering via Hono JSX;
  - htmx for the interaction between frontend and backend (HTTP requests and live updates).

Reference files in the repository:

| Reference | Path |
| --- | --- |
| Reference photo of the physical layout | [`references/gartenbahn-aufbau.jpg`](../references/gartenbahn-aufbau.jpg) |
| UI mockup | [`references/gartenbahn-mockup.html`](../references/gartenbahn-mockup.html) |
| ISE servers (Locomotive, Switch, Railroad) as git submodule | [`references/ise-server`](../references/ise-server) |
| Mock servers of the test environment and protocol summary | [`tdd/mock-servers/README.md`](mock-servers/README.md) |
