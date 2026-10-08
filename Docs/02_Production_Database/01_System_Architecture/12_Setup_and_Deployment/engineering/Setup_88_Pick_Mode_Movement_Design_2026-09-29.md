# Setup #88 — Pick Mode and Movement Capture Design — 2026-09-29

| Document Control | Value |
|---|---|
| Status | ACTIVE IMPLEMENTATION DESIGN — V0.3.29 pick-clarity successor |
| Issue | #88 |
| Branch | `agent/setup-88-pick-mode-movement` |
| Baseline main | `ff6cc0b6f7c65fe736f85ce12297dbc141a69267` |
| Production Setup runtime | `6f53d7f0c4b15f7175e773a2069595eef3f0e698` / `V0.3.22-pick-list-delay` |
| Owner | Setup movement / Labeling and Scanning integration |

## 2026-10-07 contents reconciliation successor — candidate

The DBG-2026-007/009/010 physical decision model adds missed-unload reconciliation
alongside the accepted “What came off here?” Stage-group unload controls. The
first reconciliation candidate incorrectly removed those controls; V0.3.44
restores current-location group unloading without mixing it with prior-location
inference. See the
[current candidate and review contract](../../../../../Setup/Acceptance/Setup_88_Contents_Reconciliation_Candidate.md).
Every selected Container now has Empty / Not Empty / Not Sure decisions;
partial reconciliation asks which Display Names remain. Inference uses prior
last-known evidence; Return Empty uses canonical Home without Workshop GPS.
No schema additions or historical repairs. Production/operator acceptance is pending.

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
 -> display canonical Home Location prominently in Review and record
 -> final action names the exact location (for example: Returned CONT:36 to RA03-A-01)
 -> material handler confirms the return
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

## Planned access dates do not override observed physical evidence

Planned material-access dates are planning context, not a blocker against recording reality.

If an authenticated operator deliberately scans/selects an asset in **Record Location** and provides valid location evidence, that observation must be recorded even when:

- the planned park-access date has not arrived;
- the item has no prior `PICKED` event;
- the material reached the park through an exception or unrecorded prior movement.

A real movement/location observation is durable physical evidence. Do not invent a prerequisite movement merely to satisfy the plan, and do not discard a real observation because planned sequence was bypassed.

The command still requires valid identity, operator authorization, location evidence where applicable, idempotency, and normal movement-state integrity.

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
- real field movement/location evidence is accepted regardless of planned access date, while retaining normal identity/location/idempotency safeguards;
- Production fingerprint/live runtime remain unchanged throughout disposable/browser acceptance.

Production deployment remains a separate explicit runbook-authorized step.





## 2026-09-30 V0.3.29 pick-clarity successor

The V0.3.28 browser review validated the major field-evidence changes and materially improved Pick response time. It also exposed two final clarity issues in the picker surface.

### Pick List counters are physical-material counters

Do not mix Setup task-assignment counts with picker throughput in the same summary strip.

The Pick List summary is:

- **Items to pick** — demanded physical items not delayed and not already moved/out;
- **Delayed items** — demanded physical items currently held by Pick Delay;
- **Items already moved** — demanded physical items whose current movement state is already out/moved, whether Container or standalone Display;
- **Containers picked** — demanded Containers with an actual `PICKED` event in the current Setup Session.

A Container discovered in the park by Record Location may be **already moved** without ever having a Pick event. That observation must suppress it from the Needs pick working set, but it must **not** increase **Containers picked**.

This makes Containers picked a truthful throughput measure rather than a synonym for current outbound state.

### Remove obsolete Movement / Scanning shared-app view

The old **Movement / Scanning** Setup tab is no longer an operational workflow. It only linked back to Pick List and showed diagnostic movement-state row counts.

The accepted operational entry points are now:

```text
Pick List
    = workshop pull / PICKED workflow

Record Location
    = deliberate field location/movement observation
```

Remove the obsolete shared-app tab/view and stop fetching movement-summary solely to populate it. Keep the protected movement-summary API until separate system-wide review proves no remaining consumer needs it.

### Offline gate remains separate

Offline queue / cold start / reconnect / idempotent replay remains a required physical-device acceptance gate. Picker-summary and navigation cleanup do not substitute for that test.


## 2026-09-30 V0.3.28 field-evidence successor

The V0.3.27 browser review established three additional launch facts.

### Observed movement outranks planned sequence

A real Record Location observation must not be rejected by the historical/planned October 5 material-access date. The system records physical evidence even when a prior Pick event is missing. Planning sequence and actual movement history remain separate facts.

### Return Home must name the destination

For Container return, the Review/Record surface must expose canonical `ref.container.location_code` and the confirmation action must name it. A generic **Returned to Home Location** action with no visible destination is not acceptable.

If Home Location is missing, the return action fails closed to Manager reference-data correction under #230. Movement does not invent or rewrite Home Location.

### Pick validation/performance

Disposable `SETUP_PERF` evidence measured normal online Pick scans at roughly:

```text
POST /api/setup/movements          ~1.28–1.38 s
GET  /api/setup/material-readiness ~1.32–1.44 s
combined server application work   ~2.60–2.81 s
```

The delay is caused by two serial full material-readiness builds: one solely to validate the scanned item and one synchronous list refresh after the successful write.

The accepted optimization boundary is:

1. keep authoritative server-side demand / delay / already-outbound validation;
2. validate only the scanned asset against the same current scheduling/material authorities instead of constructing the entire Pick List;
3. after a successful governed write, settle the scanned row/count immediately from the authoritative movement response;
4. refresh full material readiness in the background without making the operator wait for that rebuild;
5. preserve conservative offline validation/idempotent replay.

#222 remains the performance cross-reference and Production measurement authority. #88 owns the Pick workflow behavior and acceptance.


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


## Historical 2026-09-30 launch checkpoint — Oct. 2 closed-loop target

This checkpoint records the earlier closed-loop candidate and is superseded by the V0.3.28 contract above. The implementation remains under #88 / PR #255. Historical candidate identity:

```text
V0.3.23-movement-loop
```

The Oct. 2 launch target is not merely a PICKED proof. The scanner surface must support the same governed event contract through Pick, Load, Depart/In Transit, Unload, Stage, Place/Relocate, and Return Empty. GPS/accuracy evidence is persisted on the movement event and exposed on current-state reads; it does not become permanent GIS/reference identity. Return Empty must surface canonical Home Location and fail closed to a Manager correction when Home Location is missing.


## 2026-09-30 Production deployment authority split

The first V0.3.29 Production attempt correctly stopped before mutation when the feature-owned deployment runner compared the live Scan artifact against the obsolete September 3 Controller baseline. Read-only reconciliation then proved the live Scan runtime is the still-useful #219 `/scan/field-test` harness used for #171 GIS/reference evidence.

The Production deployment boundary is therefore deliberately split by runtime authority:

```text
Step 1 — Production Database / Setup authority
    -> exact accepted Setup application SHA
    -> Setup write freeze
    -> validated PostgreSQL rollback archive
    -> migration 065 only
    -> transactional movement validation
    -> /opt/msb-setup exact-target promotion
    -> Setup restart / health / live regression
    -> NO Directus/Scan file mutation

Step 2 — MSB-Server-Management Scan authority
    -> merged Production Database Scan candidate
    -> isolated Directus endpoint-extension validation
    -> verify current live #219 field-harness baseline
    -> create/hash fresh immediately-current Scan rollback
    -> replace only Scan dist/index.js
    -> Directus restart / route regression
    -> preserve /scan/field-test
    -> verify explicit Display/Container Record Location handoffs
```

The #88 Setup/PostgreSQL runner must not copy, stage, back up, restart, or otherwise administer the Directus Scan extension. Scan runtime mutation belongs to the Server Management Scan deployment/recovery runbook and its reviewed repository-owned wrappers.

The current live #219 field harness remains useful while #171 is open. A later Setup release must not silently regress or remove that route merely because its own Scan delta was based on an older source artifact.

Required order for V0.3.29 Production is Setup/PostgreSQL first, then Scan. This avoids exposing Record Location links before the target Setup route/movement API exists.

The failed preflight that exposed the stale Scan baseline made no database, Setup checkout, or Scan runtime mutation.


## 2026-09-30 Production recovery — shared audit prerequisite already fixed in source

The first bounded V0.3.29 Setup/PostgreSQL Production attempt committed migration 065, then stopped during the rollback-only #88 movement validation before the application checkout advanced.

Failure evidence:

```text
ops.setup_container_state.updated_by = NULL
during record_setup_movement_event(...) UPSERT
```

This is not a new movement-model defect. It is the already-known shared audit-attribution defect reproduced during prior #122/#88 acceptance using the existing person/user 36 case.

The accepted database-wide source repair already exists:

```text
Database/Basic_Query_Tools_Dev/Repair-SetActorOnUpdate-Attribution.sql
```

The prior defect allowed an UPDATE trigger to retain an old non-null updater carried forward in `NEW` instead of stamping the currently resolved actor. The shared repair corrects that update-attribution rule and hardens usable actor-name resolution.

The earlier disposable #88 acceptance passed because the accepted order was:

```text
shared audit repair
-> database-wide audit rollback validation
-> migration 065
-> #88 movement rollback validation
```

The Production deployment incorrectly omitted the shared repair after assuming it was already live. It was not.

Current Production recovery state after the failed attempt:

- migration 065 is committed;
- rollback-only movement validation did not leave movement evidence;
- governed Setup business fingerprint remained unchanged;
- Setup runtime recovered to V0.3.22;
- Scan/Directus was not changed.

Therefore recovery is forward-only:

```text
prove 065 already installed
-> create fresh post-065 / pre-audit PostgreSQL rollback archive
-> apply the already-reviewed shared audit repair
-> database-wide audit rollback validation
-> #88 movement rollback validation
-> only if both PASS, promote exact V0.3.29 Setup application
```

Do not reapply migration 065 and do not invent a new #88-specific audit workaround.

## 2026-10-03 V0.3.36 Record Location scanner-mode correction

Physical rugged-tablet testing after the accepted Setup releases showed that the workshop Pick scanner path was reliable while the separate Record Location surface could fail to select a Zebra/HID-scanned Container or Display.

Read-only source tracing established that both applications already used the same capture-phase document HID collector and compact V5 Zebra payload + Enter contract. The relevant difference was scanner arming/focus policy:

```text
Pick Mode
    -> Start Picking explicitly arms HID capture
    -> active editable control is blurred
    -> repeated scanner input is handled by the focusless document collector

Record Location before V0.3.36
    -> HID collector was always installed
    -> collector intentionally ignored editable targets
    -> no explicit scanner-armed state established focus ownership
```

The correction is an explicit Record Location scanner mode rather than changing scanner programming, permanent QR identity, or movement semantics.

V0.3.36 candidate behavior:

- **Start Scanner** explicitly arms Record Location HID capture;
- starting scanner mode stops any active camera scan;
- camera scanning is disabled while scanner mode is armed;
- scanner activation blurs the currently active control so Android HID starts in the same focusless capture state used by Pick Mode;
- **Stop Scanner** disarms the document HID collector and re-enables camera scanning;
- scanner mode remains armed while the operator starts/stops GPS, chooses a GPS-derived nearby reference, chooses a known park reference, or adds an exception/location note;
- editable location controls may temporarily own focus while the operator enters information, but completing that interaction restores focusless scanner capture so the next Zebra scan does not require another **Start Scanner** tap;
- camera/manual/search/Scan-handoff identity paths remain available when scanner mode is not armed;
- camera, HID, manual, touch/search, and Scan-handoff identities converge on the same Record Location identity-selection logic;
- the visible identity input is updated with the resolved canonical `CONT:` / `DISP:` value regardless of capture source;
- free-text location notes remain observation evidence for later review; they do not automatically create or alter #171 GIS/reference authority or #230 permanent Home Location/reference records;
- Pick List behavior is unchanged;
- Zebra V5 ADF / Enter behavior is unchanged;
- permanent label / QR payload identity is unchanged;
- PostgreSQL movement schema and movement semantics are unchanged.

The Record Location service-worker cache generation advances from v6 to v7 and the JavaScript asset pin advances to `2026-10-03.1` so tablet acceptance cannot be satisfied by a stale pre-scanner-mode shell.

This candidate is based on current `main` after V0.3.35 schedule-usability, so the scanner correction uses the distinct release identity `V0.3.36-record-location-scanner`.

Required acceptance remains exact-candidate Setup regression, disposable/browser review, then real rugged-tablet + Zebra/camera/GPS verification before Production deployment.

## 2026-10-03 V0.3.37 browser-review correction

The first V0.3.36 disposable browser review was intentionally stopped as **CHANGES REQUIRED** after the operator proved initial focusless HID capture, then found the next-asset workflow too dependent on browser focus after entering location evidence.

Observed failure mode:

```text
Start Scanner
  -> CONT:<id> + Enter works
  -> operator enters/selects location evidence
  -> editable field temporarily owns keyboard focus
  -> scanner still says ON, but operator must understand blur/focus details
  -> successful Record leaves prior identity visible
  -> next-asset readiness is not explicit
```

This is an operator-workflow defect, not operator error and not a Zebra programming defect.

The corrected V0.3.37 contract is:

```text
Start Scanner
  -> scanner ready; no field focus required
  -> scan asset
  -> Zebra Enter terminates the asset identity only
  -> scanner pauses while that asset is pending
  -> operator chooses a known/nearby reference or enters a manual location note
  -> Record or Clear
  -> prior identity/location-entry evidence is cleared
  -> scanner explicitly returns to ready
  -> scan next asset without Use and without re-focusing the identity field
```

The Record action remains explicit. The scanner's Enter suffix never Records movement. Enter in a free-text location/GPS-quality note only finishes note editing; scanner capture remains paused until the pending asset is Record/Clear. A second scan cannot silently replace the pending asset.

The corrected candidate uses the visible release `V0.3.37-record-location-scanner`, Record Location cache generation v10, Record Location JavaScript pin `2026-10-03.3`, Record Location CSS pin `2026-10-03.1`, and shared Setup client-build asset pin `2026-10-03.2`.


### 2026-10-03 launch reference refresh

For launch, the known-location chooser continues to use a curated versioned reference file until #171 provides a proper maintenance/import workflow.

The launch-time authority is ExpertGPS / Garmin GIS data in the accepted working CRS:

`EPSG:8158 — NAD83 HARN WISCRS Sheboygan County Feet (USft)`

The 2026-10-03 Church correction supplied by the operator updates `15-Church-Bells-CH` and adds `15-Church-ParkingLot`. The source Easting/Northing values are retained in the reference JSON together with the transformed browser-facing WGS84 latitude/longitude values. This is a temporary curated launch mechanism, not a new permanent GIS store.

### Scanner-on desktop layout correction

A later V0.3.37 disposable browser review exposed a presentation defect when **Start Scanner** was enabled at desktop width. The identity entry area collapsed into a narrow strip because the scanner/camera action column was sized as `auto` and its longer Scanner ON status text consumed most of the grid width.

The corrected layout gives the identity column a real desktop minimum width, bounds the action column so its controls/status wrap internally, and stacks the two areas below 900 px. This is presentation-only; it does not change scanner state, movement semantics, or release identity.

### Pick-style compact scanner presentation

A later V0.3.37 browser review showed that simply preserving desktop widths was still not the right field design. The operator confirmed that when Scanner is armed, Record Location should follow the same compact interaction pattern already accepted for Workshop Pick.

Required presentation:

```text
Scanner OFF
    -> full normal Record Location entry
    -> manual entry / Find / camera visible

Scanner ON, waiting for asset
    -> compact Step 1 scanner strip
    -> identity input + Stop Scanner + scanner status
    -> camera and explanatory help hidden

Scanner ON, asset pending
    -> Step 1 collapses further
    -> pending asset + Stop Scanner remain visible
    -> screen priority moves to Location Evidence + Review / Record
    -> scanner remains paused until Record or Clear

Stop Scanner
    -> full normal entry surface restored
```

This is presentation-only and deliberately mirrors the accepted Pick List scanner-mode body-class pattern. It does not change the V0.3.37 scanner state machine, movement semantics, or release identity.

Record Location service-worker cache generation advances to v11 and the CSS asset pin advances to `2026-10-03.2` so browser acceptance cannot reuse the prior non-compact layout.

### Compact location-evidence presentation

Browser review also showed duplicate nearest-reference text and buttons consumed unnecessary tablet space.

For V0.3.37:
- the three nearest-reference choices are shown as vertically stacked buttons to the right of the **Where is it now?** / GPS summary at wider widths;
- the duplicate inline `Nearest: ...` text is hidden from normal operator view;
- the layout stacks naturally at narrower widths;
- **Known park reference** remains below the GPS/nearest-choice area;
- **Reference data** provenance is hidden during normal operation and remains available only in Training/device-test mode.

This is presentation-only. Reference ranking, selected-reference meaning, raw GPS evidence, and movement semantics are unchanged.

### Operator GPS diagnostics boundary

Launch Record Location should not ask unload operators to rate GPS quality.

The normal operator surface now retains the useful evidence automatically:

- browser latitude / longitude;
- device-reported accuracy;
- fix timestamp / age;
- chosen known reference when confirmed;
- manually entered location when the real location is not in the known-reference list.

The former **GPS quality / uncertainty** operator controls are removed from Record Location. Movement payloads continue to carry the existing neutral `UNASSESSED` / no-note values so the persisted contract remains compatible without implying an operator judgment that was never made.

The fallback free-text control is intentionally framed as **Location not listed? Enter another location**. It exists for a meaningful real-world drop location that is not yet in the curated known-reference set, not as a general diagnostic comment field.

Engineering GPS/device quality work remains owned by the read-only `/scan/field-test` harness under #219.

The failed V0.3.36 browser review does not carry acceptance forward. V0.3.37 must restart exact-candidate regression, reusable disposable acceptance, and browser review.


### V0.3.45 compact contents interaction — 2026-10-08

The restored group unload exposed every Display Name by default, making a large
Container span many screens. Greg rejected that interaction because checked
groups and final controls were separated by excessive paging. Stage rows now
show Stage/count, with names in a separate disclosure. A fixed summary/action
dock shows selected Stage names, unloading/staying counts and location basis.
Missed-unload contents checking occupies a separate view; view changes reset the
other operation. Remaining Display IDs are held in asset-local state so name
filtering never drops hidden checked rows. A focused modal review shows affected
Stage/counts and HERE/PRIOR basis, with names expandable. Back/Escape cancels,
preserves selection and writes nothing; an open review blocks repeated commands
and asset replacement. Movement/event payloads and migration 070 are unchanged.
Browser/tablet acceptance of this candidate is still required.


### Container drop and physical Display removal — operator meaning, 2026-10-07

Greg reports that an operator interpreted "unload Container" as removing the
loaded Container from its vehicle at park staging. Many scans therefore combined
a Container location observation with Display detachment even though Displays
stayed physically loaded. C216 Production event 48 detached only Peace on Earth
correctly; later event 122 detached seven Mt. Crumpit panels and WhoMatrix. The
panels are confirmed still loaded. This establishes a wider workflow meaning
problem; it does not prove all unload events are wrong or confirm WhoMatrix's
physical contents. See the controlled candidate handoff for evidence and the
broader SELECT-only audit.

The next interaction must separate Container drop (contents stay attached),
Displays physically removed (explicit Stage-group selection and here-location
review), and current physical contents checking (Empty / Not Empty / Not Sure;
prior evidence for missed removal). Generic "unload" or "came off" cannot supply
operator intent. Park arrival/Stage suggestion cannot select removal. Retain the
quick grouped method, compact rows, expandable names and persistent summary.
Label historical derived contents as last recorded contents rather than physical
confirmation. V0.3.45's labels and review did not resolve the reported meaning problem.
V0.3.46 implements these explicit intent views; disposable/browser acceptance
remains pending.
No new schema/event model is justified. Historical correction is separate from
preventing new mistaken commands: audit all relevant grouped-unload events,
confirm actual contents, preserve subsequent valid work and original history,
and prove a guarded corrective event/projection before Production authorization.


### Wider Production audit supplied — 2026-10-07

The operator supplied the read-only audit summary and event detail: database msb,
Session 2 / PLANNING, October 5–6 Chicago observations, 19 Container scans across
18 distinct Containers and 152 UNLOADED Display effects. All 152 still match the
current DETACHED state's last movement event at the query snapshot. The tshircel
account has 13 October 6 scans/127 effects and two October 5 scans/two effects.
Five Wrap Containers account for 80 effects within 2m15s; these are physical-review
candidates, not automatically proven mistakes. C177/C178/C199 currently have
Standalone Display type and seven effects, exposing the type-contract cases.
C216 event 48 remains the valid Peace on Earth removal; seven panels from event
122 are physically confirmed loaded and WhoMatrix remains unconfirmed. Event 122
has GPS with 13-foot accuracy despite its blank named destination. Event 99's
EC-Scaffold has no current permanent Container, so permanent assignment alone is
not a recovery membership proof. Full event table and recovery boundaries are in
the linked candidate handoff. Aggregate Display-name cells in the supplied paste
are truncated; they cannot serve as a complete Display recovery manifest.

Missed-removal reconciliation cannot restore Displays already incorrectly detached.
Historical correction needs a separately proved, guarded, auditable attachment
operation; the existing movement command does not accept DISPLAY_REATTACH despite
that enum being present. No correction command is ready and no Production repair
has been performed. Keep physical confirmation, exact membership/current-state
proof, disposable recovery validation and Production authorization separate from
preventing future mistakes in the explicit-intent operator workflow.


### V0.3.46 explicit Container intent — 2026-10-07

New scans default to Container drop: existing CONTAINER_MOVE, empty removal IDs,
no reconciliation claim, and container_drop_contents_unchanged=true in existing
notes. Physical Display removal explicitly opens compact Stage-group selection;
physical contents checking explicitly opens Empty / Not Empty / Not Sure. Switching
intents clears hidden selections and cannot change an open review. Return Empty is
shown only during contents checking and requires explicit Empty. Historical derived
counts, including zero, say physical contents are unconfirmed. No schema, API or SQL
change was necessary. Full Setup regression 753 passed, targeted movement/location
46 passed, no-Node Windows application simulation 708 passed / two skipped. Real
browser/current-Production-clone acceptance remains pending; no historical repair.


### Scan-at-stop clarification — 2026-10-07

Greg restated the already intended physical workflow: scans normally occur when
Containers stop; pick is not required. Ordinary loads need a guided Empty / Not
Empty / Not Sure check at the stop, including an all-still-here shortcut and
remaining Display Names when contents changed. Missing contents use the previous
scanned Container location before the new location is recorded. V0.3.46 instead
makes contents checking optional behind three intent views; this does not yet
satisfy the instructional workflow and final browser acceptance is paused.

Preserve the accepted trailer scan -> Location/GPS -> Stage-group physical removal
-> move -> repeat method. Independent Display placement can detach only that Display
without a Container move or prior pick. Standalone Displays never detach. Helpers
without accounts need not have recorded earlier removal; an authorized operator
can report later physical contents, without claiming to be the earlier remover.
January Container-based testing remains separately undesigned and is not a
Standalone exception. Workshop-only Empty/Home return is recommended when prior
field evidence is trustworthy; a compulsory park-departure scan remains an open
choice. Full scenario table and acceptance boundary are in the candidate handoff's
Scan-at-stop design authority section. No application change in this clarification.


Repeated interim stops can retain the entire load: Workshop -> temporary staging
-> another temporary stop -> Display staging does not imply removal at any point.
Advance Container/attached-Display location after each unchanged-load confirmation;
use the latest prior stop for inferred missing contents only if a subsequent scan
actually reports a contents change. Fewer/empty are conditional branches, not an
expected next-stop state. Add consecutive unchanged loaded stops to acceptance,
with quick confirmation and no per-Display re-entry. Road-work staging and network
repairs make low-attention, offline-capable operation a launch requirement. This
clarification changes no application source and requests no further browser test.


### Delayed Not Sure review — required completion gap, 2026-10-07

Greg asks about desk review two/three days later with nobody near the Container.
Current source writes contents_review_required=true in notes; no UI consumer or
resolution command exists. Not Sure payloads have no frozen expected contents or
pinned prior event, and Container-only event-display rows do not preserve the full
attached scope. A fresh scan/latest-stop reconciliation is not historical review.

#88 needs a Manager contents-review queue retaining the original uncertain stop,
known snapshot/prior anchor, subsequent movement evidence and unresolved scope.
Desk actions must capture documented evidence, actual observation versus recording
time and guarded audited corrections linked to the original event, preserving
later valid work. Confirmed-now facts cannot automatically resolve earlier unknown
physical history. Partial/no-evidence cases remain unresolved; derived Display
location must show uncertainty. Reporting helpers need not have accounts. No new
model/schema is justified without first proving use of existing event/notes scope.
Full proposed tool and acceptance cases are in the candidate handoff's Delayed
contents review section. This capability is unimplemented and required before the
Not Sure workflow can be considered complete; no runtime or Production change.
