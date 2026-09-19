# Scan + GPS Field Acceptance Harness — 2026-09-18

| Document control | Value |
|---|---|
| Status | CANDIDATE — NOT DEPLOYED |
| Owner | Labeling and Scanning / Site Infrastructure GIS |
| Related issues | #113, #171, #206 |
| Candidate route | `/scan/field-test` |
| Production write behavior | None |

## Purpose

Provide a controlled field-test surface for the actual MSB tablet + Zebra + browser-GPS path before Setup movement/location writes are designed or enabled.

The test must answer with evidence:

1. Does Zebra HID input reach the protected Scan browser reliably without a preliminary tap?
2. Does the rugged tablet return usable high-accuracy GPS observations in the actual park environment?
3. When compared with current ExpertGPS reference points, which named locations are ranked nearest?
4. Can the device distinguish intentionally close reference locations well enough for a useful operator workflow?
5. Does the browser retain test evidence across an ordinary page reload / temporary connectivity interruption?
6. Can the same scanned identity still be handed to the normal accepted Scan route independently of the test harness?

This harness does **not** decide final GPS tolerances and does **not** prove that any GPX coordinate is authoritative merely because the tablet agrees with it.

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
- input method selected by operator;
- raw scanned value;
- parsed canonical `TYPE:key` when recognized;
- latitude/longitude;
- browser-reported horizontal accuracy;
- GPS fix timestamp and age;
- optional altitude/altitude accuracy/heading/speed supplied by the browser;
- elapsed time from starting GPS to the current fix;
- five nearest embedded GPX references and distances;
- expected reference rank and expected-reference distance.

The browser session also records the user agent and reference-source provenance.

## Field Procedure

Do not try to prove the whole park in one pass. Collect repeatable evidence.

Recommended first pass:

1. Open the candidate page on the actual rugged tablet through the accepted HTTPS Scan origin.
2. Select the named reference where you intentionally stand.
3. Start high-accuracy GPS and wait until the displayed fix/accuracy stabilizes.
4. Scan a real Display/Container/Controller label with the Zebra without first tapping the Scan field.
5. Repeat at least three observations at the same point.
6. Move to the next reference and repeat.
7. Use **Verify normal Scan route** separately to confirm the captured identity still resolves through the current accepted Scan path.
8. Export JSON at the end of the session; CSV is available for quick inspection.
9. Preserve the exported evidence with the acceptance notes.

High-value discrimination cases already identified from the current GPX include close pairs:

```text
23-Peanuts-PN <-> 24-Traditional Christmas-TC
03-Welcome Area-WA <-> 03a-Mega Cube-MC
20-Snow Storm-SS <-> 21-Polar Bear Playground-PB
```

Also include at least one comparatively isolated location and the QV/Santa's Station area.

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
