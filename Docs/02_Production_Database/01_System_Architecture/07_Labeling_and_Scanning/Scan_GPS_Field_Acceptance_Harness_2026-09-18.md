# Scan + GPS Field Acceptance Harness — 2026-09-18

| Document control | Value |
|---|---|
| Status | CANDIDATE — NOT DEPLOYED |
| Owner | Issue #219 — Scan + GPS acceptance harness; #122 governs Setup integration decisions |
| Related issues | #219 (owner), #122 (governing Setup), #113, #171 |
| Candidate route | `/scan/field-test` |
| Production write behavior | None |

## Purpose

Provide a controlled field-test surface for the actual MSB tablet + Zebra + browser-GPS path before Setup movement/location writes are designed or enabled.

The test must answer with evidence:

1. Does Zebra HID input reach the protected Scan browser reliably without a preliminary tap?
2. Does the rugged tablet return usable high-accuracy GPS observations in the actual park environment?
3. Does GPS continue to produce usable observations when both cellular data and Wi-Fi are deliberately unavailable?
4. When compared with current ExpertGPS reference points, which named locations are ranked nearest?
5. Can the device distinguish intentionally close reference locations well enough for a useful operator workflow?
6. Does the browser retain test evidence while disconnected and across browser backgrounding / reload where possible?
7. Can the same scanned identity still be handed to the normal accepted Scan route independently of the test harness?
8. What additional offline-app-shell behavior is required before a no-SIM tablet can recover from a reload/restart in a dead zone?

This harness does **not** decide final GPS tolerances and does **not** prove that any GPX coordinate is authoritative merely because the tablet agrees with it.

## Park Connectivity Assumption

The production field fleet must not depend on cellular service.

Current 2026 operating facts:

- one rugged tablet currently has a SIM/cellular connection;
- the other tablets do not;
- seasonal SIM service is not expected to be purchased for every tablet;
- park Wi-Fi exists only in limited/key locations and can be used as periodic synchronization points.

A store-and-forward workflow is one hypothesis that this experiment may inform, not an accepted Production design. Issue #219 is collecting evidence only; #122 will decide later whether and how disconnected work should synchronize after the field results are reviewed.

The field test should therefore observe whether this sequence is technically viable without treating it as a committed architecture:

```text
scan + GPS + field context
    -> retain test evidence locally while disconnected
    -> continue testing without network
    -> later regain connectivity
    -> confirm retained evidence can still be exported and reviewed
```

The SIM-equipped tablet is a useful acceptance device because the operator can deliberately disable cellular/Wi-Fi and compare connected versus disconnected behavior on the same hardware.

## Safety / Data Boundary

The harness is intentionally read-only.

It does not:

- insert/update/delete PostgreSQL rows;
- create Setup movement events;
- change Container/Display current state;
- create a 2026 Setup Session;
- create GIS/site-location records;
- silently promote GPX names into Production Stage/Scene hierarchy;
- alter physical QR/barcode payloads.

Test observations are stored only in browser `localStorage` and can be exported as JSON/CSV.

## Reference Dataset

Candidate reference source:

```text
2026_msb.gpx
creator: ExpertGPS 9.34 using Garmin GPSMAP 66sr
modified: 2026-09-15T20:51:16.014Z
sha256: eff23e666e0c288b52741621c1450b5a95150b36394de38bfe50b307c311de74
source waypoints: 519
selection rule: type=Stage
selected references: 31
```

The candidate embeds the 31 waypoints currently exported with GPX `type=Stage` as named test references.

The GPX type is not treated as Production Database hierarchy authority. For example, `30-Santa's Station Entrance` is a meaningful Scene/significant-area location within QV even though the GPX exports it using the Stage type/symbol convention.

The test page uses GPX latitude/longitude and browser latitude/longitude only for disposable field ranking. Final Production/PostGIS integration must preserve the working GIS coordinate contract:

```text
NAD83 HARN WISCRS Sheboygan County Feet (USft)
```

and must explicitly transform/normalize device coordinates.

## Evidence Captured Per Observation

Each scan or GPS-only sample records:

- local test observation UUID;
- test-session UUID;
- observation timestamp;
- selected expected reference name, when supplied by the operator;
- free-text operator location comment describing where the operator believes the scan should resolve or other field context;
- input method selected by operator;
- raw scanned value;
- parsed canonical `TYPE:key` when recognized;
- latitude/longitude;
- browser-reported horizontal accuracy;
- browser online/offline state and available Network Information API hints;
- GPS fix timestamp and age;
- optional altitude/altitude accuracy/heading/speed supplied by the browser;
- elapsed time from starting GPS to the current fix;
- five nearest embedded GPX references and distances;
- expected reference rank and expected-reference distance;
- the expected reference latitude/longitude used for the comparison; and
- the complete embedded 31-point reference snapshot in the JSON session evidence.

The browser session also records the user agent and frozen reference-source provenance, including the exact GPX SHA-256, source waypoint count, selection rule, and selected reference count. CSV includes the GPS fix timestamp, connectivity evidence, source identity, and all five ranked references.

## Field Procedure

Do not try to prove the whole park in one pass. Collect repeatable evidence.

Recommended first pass:

1. Open the candidate page on the actual rugged tablet through the accepted HTTPS Scan origin while connected.
2. Select the named reference where you intentionally stand.
3. Start high-accuracy GPS and wait until the displayed fix/accuracy stabilizes.
4. Scan a real Display/Container/Controller label with the Zebra without first tapping the Scan field.
5. Repeat at least three observations at the same point while connected.
6. Deliberately disable both cellular data and Wi-Fi.
7. Confirm the page shows OFFLINE, wait for fresh GPS fixes, and capture at least three additional scans/GPS samples.
8. Background and restore the browser while still offline; verify locally retained observations remain present.
9. If practical, reload/restart while still offline. Record whether the field-test page itself remains available. Failure here is evidence that an offline app shell/service-worker or equivalent is required; do not treat it as operator error.
10. Re-enable connectivity or move to a known Wi-Fi area and verify the retained local evidence remains intact.
11. Use **Verify normal Scan route** separately after connectivity returns to confirm the captured identity resolves through the current accepted Scan path.
12. Repeat at additional reference locations, including close-pair stress cases.
13. Export JSON at the end of the session; CSV carries the scan/GPS/connectivity fields, frozen-source identity, and all five ranked references for quick inspection.
14. Preserve the exported evidence with the acceptance notes.

High-value discrimination cases already identified from the current GPX include close pairs:

```text
23-Peanuts-PN <-> 24-Traditional Christmas-TC
03-Welcome Area-WA <-> 03a-Mega Cube-MC
20-Snow Storm-SS <-> 21-Polar Bear Playground-PB
```

Also include at least one comparatively isolated location and the QV/Santa's Station area.

## Minimal Park Test — SIM-Equipped HOTWAV R9

This is the immediate acceptance test Greg can perform next week with a second/similar HOTWAV R9 that has cellular service.

Required physical items:

- one real Container label;
- one real Display label;
- the Zebra scanner used for the field workflow;
- the SIM-equipped HOTWAV R9.

The labels are test identities only. They may be carried to known reference points for this read-only test. The harness must not create movement/location history merely because the same label is scanned at several test points.

### Connectivity setup

Before beginning:

1. turn **Wi-Fi OFF** on the tablet;
2. leave **cellular data ON**;
3. open the protected test route over cellular;
4. verify the page reports `ONLINE`;
5. start high-accuracy GPS.

This proves the park test is not accidentally depending on local Wi-Fi while still allowing the protected browser route and evidence export to work.

### Test at each chosen reference point

At a known ExpertGPS location:

1. select the expected named reference in the harness;
2. enter an operator location comment when useful (for example, "standing at Santa's Station driveway entrance; expect Entrance");
3. wait for the GPS fix and reported accuracy to stabilize;
4. scan the Container label with the Zebra;
5. scan the Display label with the Zebra;
6. repeat each scan at least twice;
7. confirm the page retained the complete `CONT:<id>` / `DISP:<id>` value and Enter submission without first tapping the field;
8. note the nearest reference, expected-reference rank, distance, reported GPS accuracy, and preserved operator comment;
9. use **Verify normal Scan route** for each identity to prove current production routing still works over cellular.

Recommended location coverage for the first trip:

- one relatively isolated reference point to establish a simple baseline;
- one close-pair area such as `03-Welcome Area-WA` / `03a-Mega Cube-MC` or `23-Peanuts-PN` / `24-Traditional Christmas-TC`;
- optionally the Santa's Station/QV area to observe meaningful within-Stage location behavior.

The same two physical labels can be used at every point because the harness is read-only.

### Optional GPS-only offline check

After the connected cellular scans are complete at one known point:

1. leave the test page open;
2. turn **cellular data OFF** as well as Wi-Fi;
3. verify the page reports `OFFLINE`;
4. wait for fresh GPS fixes;
5. capture several GPS-only samples;
6. optionally scan the two labels again and confirm the harness retains them locally;
7. restore cellular service and export the session.

This optional pass tests whether GNSS/scan capture continues without data service. It is not yet the production offline-cold-start acceptance.

## Acceptance Decision

Do not set a universal acceptable-distance number before field evidence exists.

After the first park session, review:

- actual accuracy values and stability;
- time to first useful fix;
- repeatability while stationary;
- expected-reference rank;
- distance gap between the first and second candidates;
- behavior near close Stage/Scene/significant-location pairs;
- HID focus reliability;
- browser/local-storage behavior when connectivity changes;
- whether operators can understand the named-location result without raw-coordinate interpretation.

Those results determine whether Plan A (tablet GPS) is sufficient and what location-specific confidence/tolerance rules are justified.

If tablet GPS cannot reliably discriminate meaningful nearby locations, retain the movement observation and move to the already-defined Plan B choices: external GNSS, explicit named-location confirmation, LOC marker where appropriate, or unresolved/low-confidence location evidence.

## Deployment Boundary

This candidate is not deployed by this branch.

Before installing it on the protected Scan origin, follow the current Server Management Scan extension deployment/recovery runbook and preserve rollback/runtime-hash evidence. Production deployment is additive and must not change accepted DISP/CONT/CTRL behavior.

After field acceptance, this harness may remain as an engineering diagnostic route or be removed. It is not the final Setup movement user interface.
