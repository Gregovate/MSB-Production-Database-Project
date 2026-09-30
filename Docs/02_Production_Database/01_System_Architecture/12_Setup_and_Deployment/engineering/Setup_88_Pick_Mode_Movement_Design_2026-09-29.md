# Setup #88 — Pick Mode and Movement Capture Design — 2026-09-29

| Document Control | Value |
|---|---|
| Status | ACTIVE IMPLEMENTATION DESIGN — V0.3.27 successor candidate |
| Issue | #88 |
| Branch | `agent/setup-88-pick-mode-movement` |
| Baseline main | `ff6cc0b6f7c65fe736f85ce12297dbc141a69267` |
| Production Setup runtime | `6f53d7f0c4b15f7175e773a2069595eef3f0e698` / `V0.3.22-pick-list-delay` |
| Owner | Setup movement / Labeling and Scanning integration |

## Purpose

Define the launch Pick Mode and shared Setup movement-capture contract without creating a second movement model, changing permanent labels, or turning the Pick List into a location-tracking screen.

#88 owns persisted movement events/current movement state. #206 owns Pick List demand/order/delay and the Pick List entry point. #113 owns scanner/tablet provisioning and HID behavior. #171 owns GIS/reference spatial interpretation.

## Accepted scanner fact

The current DS3678 V5 ADF configuration is the scanner-side normalization layer for existing Display/Container QR labels.

Existing physical labels remain full URLs:

```text
https://db.sheboyganlights.org/scan/CONT/216
https://db.sheboyganlights.org/scan/DISP/323
```

The accepted V5 ADF behavior sends compact HID values with Enter:

```text
CONT:216 + Enter
DISP:323 + Enter
```

Pick Mode therefore does not require new permanent labels or a new `PICK:` payload.

The existing Pick List row QR remains the upper-rack fallback. When the ER scanner reads that on-screen full-URL QR, the same V5 scanner rule normalizes it to the same compact canonical HID identity.

Because physical-label and on-screen-row QR scans intentionally converge to the same HID token, the application must not claim it can distinguish which one the scanner read. The truthful launch capture method is `HID_SCAN`.

## Pick Mode operator contract

Entry point:

```text
Setup -> Pick List -> Start Picking
```

Entering Pick Mode explicitly arms the action `PICKED`.

Normal sequence:

```text
Pick Mode armed
 -> operator drives to the item's Home Location
 -> preferred: scan physical asset label
 -> upper-rack fallback: visually verify row/item and scan that row's QR on the mounted tablet
 -> browser receives CONT:<id> or DISP:<id> + Enter
 -> validate against current Pick List
 -> valid active item records PICKED immediately
 -> large success feedback
 -> item disappears/suppresses from active Pick List
 -> Pick Mode remains armed for the next scan
```

A second touchscreen confirmation is not required for a normal valid pick. The explicit mode establishes the movement action and the subsequent scan is the operator confirmation.

While Pick Mode is armed:

- Manager override/edit inputs are hidden or disabled;
- HID input is captured regardless of scroll position and without a visible focused text field;
- the Pick List remains visible and scrollable;
- no scan keystrokes may land in another text input;
- a reload/new browser session returns to non-mutating browse mode unless an explicit accepted resume mechanism is later added.

## Required scan feedback

```text
ACTIVE PICK
 -> GREEN: PICKED
 -> record event
 -> remove/suppress from active queue

DELAYED
 -> RED: DELAYED — DO NOT PICK YET
 -> no event

NOT CURRENT ACTIVE PICK
 -> AMBER warning
 -> no event

ALREADY PICKED / CURRENTLY OUT
 -> clear already-moved feedback
 -> no duplicate event

INVALID / UNKNOWN IDENTITY
 -> error
 -> no state change

OFFLINE VALID PICK
 -> QUEUED OFFLINE
 -> visible queue count/state
 -> replay later with original event identity/time
```

The validation must use the complete current demand set so a delayed item still produces the correct red warning even when the operator has hidden delayed rows from the visible list.

## Movement modes after Pick

Do not infer physical meaning from scan order.

The same explicit-mode pattern should support the launch movement chain:

```text
WORKSHOP / HOME
 -> PICKED
 -> LOADED
 -> IN_TRANSIT              where used
 -> DELIVERED / UNLOADED
 -> STAGED
 -> PLACED / RELOCATED
 -> RETURNED / AT_HOME
```

The UI may later group buttons where field operation proves that safe, but the persisted event must retain the explicit action.

## Existing database foundation to evolve

Reuse:

```text
ops.setup_movement_event
ops.setup_movement_event_display
ops.setup_container_state
ops.setup_display_state
```

Do not create a parallel movement history.

Current legacy event types include:

```text
CONTAINER_MOVE
TASK_UNLOAD
DISPLAY_MOVE
DISPLAY_REATTACH
TASK_COMPLETION_RECONCILE
```

The current event constraint also requires a destination Stage or destination location note. That is incompatible with a truthful `PICKED`, `LOADED`, or `IN_TRANSIT` event and must be deliberately evolved rather than satisfied with a fabricated destination.

## Required launch event evidence

The server-side event contract must preserve, as applicable:

- durable client-generated idempotency identity;
- Setup Session identity;
- explicit movement action;
- Container or Display permanent identity;
- original captured/occurred timestamp;
- server received timestamp;
- authenticated actor;
- stable device identity;
- capture method;
- GPS latitude/longitude;
- reported GPS accuracy;
- source/Home Location snapshot where applicable;
- destination Stage/location evidence where applicable;
- whether capture originated from the offline queue.

Online and offline capture must converge on this same event contract.

## Current movement state

Movement action and physical location are separate facts.

The current-state tables need an explicit movement status/action separate from `current_stage_id` / `current_location_note`.

The Pick List must not use "any movement event exists" as a permanent synonym for "already picked".

For current demand, an asset is already out/not pickable when current state is an outbound/field state such as:

```text
PICKED
LOADED
IN_TRANSIT
DELIVERED / UNLOADED
STAGED
PLACED
RELOCATED
```

A later `RETURNED` / `AT_HOME` state allows later valid demand for the same physical item to become pickable again.

## Container versus Display movement

Container movement does not create synthetic Display GPS observations.

A Display may have an explainable effective location inherited from its Container while it remains with that Container, but only an actual Display movement/scan becomes a Display observation.

Permanent `ref.display.container_id` remains master assignment truth and is not rewritten by transient movement.

## Return-home launch boundary

Location barcode deployment is not required for normal Container return.

```text
Return mode
 -> scan CONT:<id>
 -> resolve ref.container.location_code
 -> display canonical Home Location prominently
 -> material handler returns it there
```

Material handlers do not type/select permanent Home Location.

If the database Home Location is missing or wrong, that is a Manager correction exception shared with #230. Do not guess a rack and do not overwrite Home Location from movement activity.

## Offline contract

Offline is launch-critical.

The browser must maintain a durable local queue, preferably IndexedDB rather than transient in-memory state.

Each queued event is created before attempting network delivery and contains at minimum:

- client event UUID/idempotency key;
- canonical asset identity;
- explicit movement action;
- original capture timestamp;
- Setup Session context available at capture time;
- device identity;
- GPS/accuracy snapshot when available;
- queue/sync status.

Required behavior:

```text
capture while online
 -> attempt same server command

capture while offline
 -> durable queue
 -> visible QUEUED OFFLINE state

reload while offline
 -> application shell and queue survive
 -> no queued event lost

connectivity returns
 -> replay in capture order
 -> server deduplicates by client event identity
 -> original event time preserved
 -> visible sync result
```

Offline mode must not create a second event schema.

## 2026 material-access boundary

Before 2026-10-05, shop-side `PICKED` / shop staging evidence is valid.

Park-side movement actions must not falsely claim that material is already in the park before the City material-access date.

This is a movement-operation safety rule. It must not be encoded as reusable Catalog readiness, a season task, a Wait/Gate, or Pick List demand logic.

## Application boundary

Pick List owns demand presentation.

Movement/Scan owns:

- explicit movement actions;
- latest movement state;
- movement history;
- GPS/location evidence;
- staging/placement/return context;
- offline event queue/sync.

Pick List consumes the resulting movement truth only to decide whether an item still needs picking.

## Implementation shape

The smallest safe implementation path is:

1. database migration evolving the existing movement event/current-state contract;
2. one governed movement-record command with idempotency;
3. Setup movement API around that command;
4. Pick Mode UI in the existing Pick List screen;
5. current Pick List suppression based on explicit current movement state;
6. durable browser offline queue and replay;
7. movement-mode screen/actions for the remainder of the launch movement chain;
8. acceptance on disposable current-Production clone;
9. exact-candidate browser review;
10. real rugged-tablet + Zebra ER field acceptance.

No Production mutation is part of implementation or disposable acceptance.

## Acceptance

Acceptance must prove:

- current full Setup regression passes;
- duplicate client event replay is idempotent;
- active Pick scan records exactly one PICKED event;
- delayed scan produces no event;
- non-demand scan produces no event;
- already-picked scan produces no duplicate;
- upper-rack on-screen Pick List QR works with the ER/V5 profile;
- HID capture works without visible input focus;
- repeated successful scans require no touchscreen interaction;
- reload exits mutating Pick Mode;
- offline pick survives reload and later syncs exactly once;
- original event time is retained through offline replay;
- GPS/accuracy is retained when supplied;
- Container event does not fabricate Display observation rows;
- permanent Home Location is unchanged by movement;
- return flow displays canonical Home Location without requiring LOC barcode;
- pre-2026-10-05 park-side false movement is rejected/blocked;
- Production fingerprint/live runtime remain unchanged throughout disposable/browser acceptance.

Production deployment remains a separate explicit runbook-authorized step.



## 2026-09-30 browser-review successor — V0.3.27 field training UX

The V0.3.26 disposable browser review completed safely but was **not operator-accepted**. The review established that the movement/data rules were safe while several field/operator interactions still needed correction.

The successor release identity is:

```text
V0.3.27-field-training-ux
```

This section supersedes earlier UI details where they conflict.

### Training applies to both material-handler workflows

Training is deliberately read-only but uses the real authenticated Production context and real device hardware.

```text
Workshop Pick List — TRAINING
    -> real current Pick List
    -> real Zebra HID / manual identity validation
    -> delayed / not-demanded / already-moved feedback remains real
    -> WOULD PICK feedback
    -> NO movement POST
    -> NO offline movement queue
    -> NO real Pick List suppression
    -> NO change to persisted Containers-picked totals

Record Location — TRAINING
    -> real Container/Display lookup
    -> real Zebra / camera / GPS / reference data
    -> real mixed-Container review
    -> WOULD RECORD feedback
    -> NO movement POST
    -> NO offline movement queue
```

Training entry remains explicit and confirmation-gated. Active training must continuously show **TRAINING MODE — NOTHING WILL BE RECORDED** and provide an obvious Exit Training action.

### Pick List field feedback

While Pick Mode is armed, the sticky scanner panel must keep the real **Containers picked** count visible so the forklift/material handler does not lose throughput visibility while scrolling the rack list.

Training may additionally show an in-memory **Training picks** counter. It is not database state and resets with the training page/session.

### Record Location interaction order

The accepted field interaction is:

```text
1. Scan / select asset
2. Establish or confirm location evidence
3. Review asset + exact location evidence together
4. Record
```

A current GPS fix alone is valid location evidence. Selecting a nearby named reference is optional confirmation/context, not a second required identity.

The final Record action must not appear ready before valid location evidence exists. The review step must show what will be recorded, for example:

```text
CONT:036 — T-Posts - Used For Panels
Location confirmed: 01-Front Entrance-FE
GPS ±18 ft
Record CONT:036 at 01-Front Entrance-FE
```

On phone/tablet, successful identity selection should guide the operator to Location Evidence and a compact workflow status should keep the selected asset/location readiness visible near the action.

Explicit GPS Start/Stop remains required. Do not force high-accuracy GPS continuously.

### Perform Work labor KPI meaning

Keep schedule workload visibility separate from performance comparison:

- **Planned labor** = planned person-hours for the active Captain scope, independent of whether completed rows are currently hidden;
- **Actual labor** = reported person-hours for that Captain scope;
- **Completed-work variance** = actual person-hours minus planned person-hours using completed assignments only.

Future scheduled work must not distort completed-work variance. If any completed assignment in the comparison lacks a plan estimate, variance remains TBD with an explicit completed-assignment missing-estimate count.

### Acceptance consequence

V0.3.26 browser-review evidence remains historical review evidence only. V0.3.27 must restart the exact-candidate chain:

```text
full Setup/Application regression
 -> reusable current-Production disposable acceptance
 -> fresh exact-candidate disposable browser review
 -> physical rugged-tablet + Zebra / camera / GPS review
 -> Wi-Fi loss / offline replay proof
 -> formal Scan Node-runtime test
 -> separate governed Production deployment authorization
```


## 2026-09-30 launch checkpoint — Oct. 2 closed-loop target

The implementation remains under #88 / PR #255. The bounded candidate release identity is:

```text
V0.3.23-movement-loop
```

The Oct. 2 launch target is not merely a PICKED proof. The scanner surface must support the same governed event contract through Pick, Load, Depart/In Transit, Unload, Stage, Place/Relocate, and Return Empty. GPS/accuracy evidence is persisted on the movement event and exposed on current-state reads; it does not become permanent GIS/reference identity. Return Empty must surface canonical Home Location and fail closed to a Manager correction when Home Location is missing.
