# MSB #171 / #319 / #230 — Site-source synchronization implementation contract

**Status:** Engineering candidate. Neither migrated nor deployed. Governed by #122 and existing Server Management runbooks.

## Three required production interfaces

| Data | Direction | Authority and guardrails |
|---|---|---|
| ExpertGPS GPX waypoint/track | **Bidirectional** ExpertGPS ↔ PostgreSQL | `ExpertGPS Label on Map` (`<label_text>`) is canonical. `<name>` remains Garmin/provenance, not comparison authority. Keep GPS shape, extensions, type/icon metadata, original traces, dates. DB becomes maintenance authority after initial reviewed promotion. Detect concurrent changes by baseline source SHA; do not overwrite conflicting edits. |
| LinkIQ FLW | **One-way** tester/LinkWare → PostgreSQL | Source `.flw` is SQLite and read **only**. Preserve every raw test UUID/payload; corrected LinkWare `Records.CableId` is distinct from immutable embedded `metadata.testId`. Preserve test appearance in all projects. Repeated UUID is one test, not two cables. Match tested cables to reviewed physical cable identities; never infer physical identity from name alone. No tester writeback dependency. |
| 19×13 Super B printable schematic / draw.io | **DB → diagram** | Keep operator-arranged layout and stable draw.io object IDs; update attributes via maintained `site_cable_id`→`drawio_object_id` binding. Circuit/topology and cable connection are DB-owned; schematic display coordinates are not GPS. A generated diagram is an output, not a manually maintained second source. |

## Canonical Shared Drive source locations — operator-confirmed 2026-10-11

Greg selected the following **current live Shared Drive source files** on the laptop and successfully validated them read-only. Use these exact Shared Drive-relative folders and filenames as the common starting locations for all authorized users; do not treat a local Downloads copy or a prior ChatGPT upload as the current source.

| Source | Current Windows `G:` path |
|---|---|
| ExpertGPS / GPX | `G:\Shared drives\Display Folders\Park Drawings\GPS Data\2026 Updates and DB connection\2026_msb_FRESH_START_CLEANED_2026-10-06.gpx` |
| LinkIQ / LinkWare FLW | `G:\Shared drives\Display Folders\Park Drawings\Network\LinkIQ Data Files\LinkIQ Data Import for DB with corrected names.flw` |

The stable shared-folder identity is the path **beneath `Shared drives\Display Folders`**, not an assumption that every user's Shared Drive is mounted as drive `G:`. A user with another mount or drive letter must resolve that same shared location explicitly. Do not silently choose a similarly named local file or substitute a prior export. Never hard-code an operator's `C:\Users\...` profile path in shared repository code.

Each operator may store their resolved absolute file paths and **current source SHA-256 fingerprints** in a local per-workstation configuration outside every Git checkout. Greg's laptop testing configuration is `C:\lor\ImportExport\MSB-319-local\source-paths.json` (a **local example, not a shared master**). The present scripts accept explicit paths; the JSON location is not yet an implemented automatic config loader, so do not claim subsequent commands read it unless wired/tested. Never commit local configuration, raw binary FLW files, or mutable source snapshots as an apparent shared master.

On each run, verify file existence and calculate the fresh SHA-256 before inspection/import. Compare with any saved baseline and fail with a review-required message if it changed; an intentional new ExpertGPS/LinkWare export can advance the baseline after source reconciliation and acceptance. Always inspect FLW read-only and write GPX/draw.io edits to separate reviewed outputs, not directly into shared source files.

**Actual laptop validation:** `2026_msb_FRESH_START_CLEANED_2026-10-06.gpx` contained 233 Label-on-Map waypoints and 181 tracks; `LinkIQ Data Import for DB with corrected names.flw` contained 684 project appearances, 476 unique test UUIDs, 208 duplicate appearances, and zero reported cross-project measurement conflicts. Both file hashes were identical before and after read-only inspection. This proves extraction/source conservation, not yet database import or full reference-link correctness.

## Source validation already executed

On `LinkIQ Data Import for DB with corrected names(5).flw`: **684** LinkWare project representations, **476** distinct UUIDs, **208** duplicate project appearances; original FLW remains read-only. On latest ExpertGPS `(20261011-023933).gpx`: **233** distinct nonempty Label on Map values, **181** tracks. Local pytest tests cover these exact inputs as well as synthetic fail-closed fixtures.

The normalized schema is proposed in `sql/171_site_infrastructure_schema_candidate.sql`. It contains maintained waypoint aliases, tracks, cable identities/network assignments, source observation provenance and test UUID history. Its candidate schema/synthetic SQL invariant gate passed against a current-Production disposable clone at `baefba3c1e849430536c45581a0bacb09db5bacb`, recorded in PR #319 comment 6108592361 and server report `/home/msbadmin/setup-acceptance-reports/Setup_Disposable_Acceptance_20261011T113238.txt`. That does not establish real-source import/reimport acceptance. It has not been migrated to Production. No Production privileges/grants are created.

## Immediate implementation path

- `site_source_sync.py gpx-inspect file.gpx --output snapshot.json` gives a source-preserving manifest and explicit display labels.
- `site_source_sync.py flw-inspect file.flw --output evidence.json` gives test UUID/appearance groups with current LinkWare and original tester labels. No physical cable ID is inferred.
- `site_source_sync.py gpx-export previous.gpx approved_db_projection.json --output revised.gpx` patches a **copy**, only when the GPX hash equals the reviewed DB baseline. Preserve Garmin names and track geometry. Test final import/export in ExpertGPS before full two-way activation; confirm unknown extensions survive application save.
- `site_source_sync.py schematic-export template.drawio approved_db_bindings.json --output new_schematic.drawio` refreshes only bound cable fields in a copy, preserving layout and object IDs. Open/review in draw.io before acceptance.

For GPX bidirectional production mode, persist the last imported/exported source hash and stable waypoint IDs, compare both versions of edited properties, and present *conflicts* rather than last-write-wins. If source identity is ambiguous (old label/coordinates both changed) require explicit review; do not silently create a duplicate waypoint. A GPX plugin MSB-ID extension is optional only after verified ExpertGPS save/roundtrip preserves it.

For the LinkIQ production importer, the database writer must run in one transaction, save the original source SHA, append `(source SHA, project row, UUID)` evidence, insert a unique test only once by UUID, and **never** update a previously reviewed `physical_site_cable_id` based on imported cable text. Status, lengths and speed qualification come from original tester data. Qualification to 1000BASE-T is *not* actual negotiated link speed. Raw data including NVP must remain accessible for audit. Unknown timezone must not be invented. Maintain all spare-cable designations without forcing a network membership.

## Release gates still required

1. Review latest live schema and existing #171/#230 object inventory, reconcile migration number, and complete SQL PostgreSQL disposable tests with current clone. Do not replay Setup migrations 070/071/072.
2. Implement and test a transactionally idempotent PostgreSQL import writer and #230 governed maintenance/approval actions. Read-only extraction alone is not a production importer.
3. Demonstrate `ExpertGPS → DB → GPX → ExpertGPS` roundtrip with unchanged extension metadata and no lost unrelated tracks; demonstrate independent DB/GPX changes trigger conflict.
4. Validate draw.io generation opened, rendered, and printed at 19×13 Super B; verify no lost labels or network routes. Keep accessible print output independently of tablet map.
5. Match reviewed physical cable identities and network taxonomy, accept unresolved candidates explicitly. Test a second FLW containing one new test and a changed label of an old UUID: one appended test, zero duplicated UUIDs, no regression of reviewed cable identities.
6. Complete #122 shared disposable/browser acceptance, explicit Production authorization, Server Management maintenance/freeze/snapshot/deploy/online proof, exact release log, and #230 application acceptance. **No Production data or schema modified during preparation.**


## October 11 continuation — required completion and role boundary

Governing issue: **#122**. #171 owns reference/GIS/source synchronization; #230
owns usable governed reference editing. The Park Map already worked October 10;
the online waypoint identities were corrected and accepted October 11 through
PR #352 (deployed `2bc88ae627420c2138268e39a26b4942a3248580`). Do not rebuild the viewer
or describe the remaining work as merely rendering a map.

| Action | Manager | Production crew volunteer |
|---|---|---|
| Create/update waypoint and infrastructure identities, geographic position and ownership | Allowed through governed commands | Not allowed |
| Maintain circuits for existing infrastructure identities | Allowed | Allowed |
| Link circuits to existing waypoints | Allowed | Allowed |
| Maintain seasonal turn-on/turn-off instructions | Allowed | Allowed |
| Update meter IDs attached to existing infrastructure | Allowed | **Allowed** |

Meter IDs are explicitly crew-maintainable attributes. They are not immutable
panel keys. Backend authorization must enforce this distinction independently of
visible controls. Manager control of identities must not prevent crew circuit or
meter maintenance. Preserve actor/time history and reject stale concurrent edits.
No actual role grant is made by this contract.

Remaining acceptance is end-to-end: file-picker GPX and LinkWare imports (pickers
reported present but untested); PostgreSQL review/edit; map reads of accepted DB
reference revisions; versioned offline data; ExpertGPS export for track editing
and waypoint repositioning with conflict-aware reimport; bound draw.io refresh
that preserves unconverted elements/layout; panels/circuits/feed links, MSB/City
ownership, meter IDs and seasonal actions. Preserve original LinkIQ tests and
reviewed cable identity links while recording corrected names separately.

Do not equate the existing schema gate or 22-pass extraction regression with these
acceptance outcomes. Reuse completed evidence; test changed behavior and missing
integration only. Greg's working tree is
`C:\lor\ImportExport\VSCode-319-linkiq-test`, local branch previously recorded as
`review/319-linkiq-test`, remote `feature/171-cableiq-import-validation`, last
operator-reported pull `42316d5e..83a544b0`.

### Current attachment/source identity

The October 11 attachments match the previously accepted GPX and FLW bytes:

| Attachment | SHA-256 |
|---|---|
| `2026_msb_FRESH_START_CLEANED_2026-10-06(20261011-150141).gpx` | `3272269d493131f0b2e401013ac7f32dc55b598ebf3e7e53d6ab3fd9ec7e2cea` |
| `LinkIQ Data Import for DB with corrected names(6).flw` | `e76d39179da99bb74ed8e2af7f4e555a71ff530cae58bdb0015e770677a3ef5e` |
| `Park Network Schematic 2026(20261011-150238).drawio` | `65d7607485e526e4d058b4ce997a24f2fe53a731b4f52817dcd44233e420a0a8` |

Use canonical Shared Drive GPX/FLW locations above. The repository GIS authority
records the schematic at `Network\Park Network Schematic 2026.drawio` beneath
`Shared drives\Display Folders\Park Drawings`; attachment suffixes are upload
copies, not changes to those canonical filenames. Record these locations in #171.
Do not commit the 253 MB raw FLW into Git.

### Release/access checkpoint

PR #352 published source correction head `2bc88ae627420c2138268e39a26b4942a3248580`
has tested tree `c4d31e05054307fcc86c1e5b27b87fe0ba70d1f5`: 751 Setup Python
regressions and network browser harness PASS in the engineering environment.
This historical release checkpoint was superseded by operator Production acceptance
recorded in #171 comment 6110878342. Prior schematic/LOR snapshots remain unreviewed.
This environment has GitHub connector access but a read-only SSH reachability
check to documented `192.168.5.9` returned `Network is unreachable`. It cannot
operate Greg's workstation, run the private server acceptance launcher, or deploy
the map. No Production dump/migration/restart was attempted.

Greg reports an approved preview exception covering both `/setup` and `/reference`.
Preserve it; reconcile its exact implementation with Server Management before
launch. Do not invent a replacement preview or require a repeated dump simply
for source-map inspection. Source-only map deployment and database migration have
different runbook gates; neither has been executed by this continuation.


## Route matching identity repair — October 11 continuation

Read-only inspection of the supplied sources confirmed 233 waypoint labels,
181 tracks, and 372 structured cable objects / 60 node objects in the drawing.
Thirteen panel waypoints expose more than one lookup spelling. The geometry
matcher previously ranked each spelling as a separate waypoint, so one physical
point could fail its own ambiguity check. The candidate now collapses aliases by
existing waypoint ID only, normalizes cable lookup endpoints through that mapping,
and retains ambiguity between genuinely distinct nearby/coincident waypoint IDs.
Conflicting coordinates for the same ID fail closed. Input records are not changed.

Against the exact previously approved GPX/FLW bytes and released map geometry,
this yields **60 candidate routes rather than 32**, retaining all prior candidates;
121 routes remain unresolved. Among the additional candidates are t131
`NET WV-00 to WV-03`, t177 `NET FC-00A to Panel 09`, t178
`NET Panel-09 to FC-00A`, and Area 4 links t77/t78/t80.
Some additional candidate geometries are HV or unclassified tracks. This does
not prove they carry tested network cables; preserve their classification and
uncertainty, never rename/reclassify or certify them from matching proximity.
No source GPX/FLW/draw.io or Production snapshot was changed by this analysis.

Validation: four new identity/ambiguity/no-mutation tests; focused route/map tests
13 PASS; combined source/import policy/extraction suites 31 PASS, one existing
Linux-fixture-path skip. Actual attached source regeneration was independently
executed read-only, conserving all 476 test UUIDs and 684 appearances. These are
engineering results, not Windows/runbook/browser/Production acceptance.

GPX track labels visibly retain historical names such as `FE-09`, `A5R`, and
`Panel FE`; this confirms text drift but not the intended physical correction.
The next review must distinguish label aliases, endpoint assignments, surveyed
trace edits, and shared routes. Do not bulk-replace strings or move coordinates.

## Shared-route and initial GPX acceptance implementation — October 11

This implements the existing engineering finding in
`Docs/02_Production_Database/01_System_Architecture/11_Site_Infrastructure_GIS/engineering/Network_Source_Reconciliation_2026-10-09.md`;
it is not a new topology rule. Prioritize source tracks beginning NET, PRI and
HV. Preserve other GPX tracks and their geometry unchanged.

- Candidate `ref.site_route_segment` holds one reviewed waypoint-to-waypoint
  geometry; `site_cable_route_segment` associates any number of distinct physical
  cables with it, in traversal order. Identical endpoints do not merge parallel
  paths or physical cables. `site_route_source_track` retains explicit reviewed
  NET/PRI/HV trace evidence, reviewer and explanation. A shared HV corridor does
  not change a network cable's electrical classification.
- `site_source_db.py bootstrap-gpx` accepts a hash-pinned initial source into
  empty reference tables, preserving map labels separately from Garmin names.
  Source observations retain every original waypoint and track; source-bound
  IDs survive same-file replay without overwriting later edits. A different
  baseline against populated tables requires explicit reconciliation. This is
  not yet the conflict-review interface for subsequent ExpertGPS edits.
- Actual GPX inspection found two single-point tracks: ordinal 6,
  `HV A5R-18 to A5R-20`, and ordinal 177, `PRI to XFORM 17-30`.
  All 181 track identities are retained. These two have empty maintained line
  geometry and their original point retained in source observations. The import
  receipt reports `incomplete_track_ordinals`; no line or endpoint is invented.
- `site_source_db.py export-map` generates one consistent GeoJSON snapshot,
  with one feature per reviewed route and attached cable/source IDs, plus
  current waypoints and preserved source-track features. Only explicitly
  associated NET/PRI/HV traces are hidden by default; other traces remain visible.
  The content hash changes with data edits and can identify an offline dataset.
  This engineering exporter is **not yet wired to the live map/API**.

Validation uses the existing allowlisted candidate schema and
`Database/Acceptance/171_site_infrastructure_disposable_validation.sql` through
`Setup/Acceptance/run_setup_disposable_acceptance.ps1`. Additional assertions
cover two cables/one displayed route, distinct parallel paths, required review
attribution, source-track identity uniqueness and incomplete trace geometry.
The previous PostgreSQL PASS does not cover these new assertions. Python tests
exercise source hash refusal, replay protection, reference bootstrap, incomplete
tracks and stable/changing map revisions; they do not simulate PostgreSQL/PostGIS
execution. No new Production migration, grants or testing workflow is introduced.

Still open under #230/#122: live reference editor and field-level authorization,
file-picker integration, full source reimport conflict review, circuit/panel and
meter-ID maintenance, live map refresh and delivery of offline/export files.
Managers maintain waypoint/infrastructure identities; Production Crew can maintain
circuit information and meter IDs. This candidate does not claim those UI or
authorization requirements are complete.

## Recurring LinkIQ intake implementation — October 11 recovery continuation

The existing #319 branch was reconciled with main
`04de9cfa94e2ff4f641130fdbbacfff9c1c56aca` and the documentation commits from
#358 (through `3a5b24382c6dec63fb85e00d63b2cdba382c8eeb`). The GIS README records
Greg's reaffirmed two-source integration, PostgreSQL authority, Manager/crew
editing boundary, GPX roundtrip, unchanged track geometry with stale track names,
shared waypoint relationships, keyed network-only draw.io output and October 12
ongoing testing requirement. This candidate builds on those decisions.

### Implemented engineering boundary

`site_source_db.py import-flw` now reads a stable FLW export, compares its hash
before/after extraction, and transactionally records:

- new versus previously known test UUID counts and new source-appearance counts;
- every full source appearance, including original payload and LinkWare metadata,
  in `ops.site_source_observation`, without replacing first-seen test evidence;
- source-specific reconciliation proposals in `ops.linkiq_intake_review`;
- a separate successful-run receipt in `ops.linkiq_import_receipt`, including
  replay/count information; the returned JSON contains current proposals;
- original reviewed physical-cable links, unchanged by intake.

`linkiq_intake.py` resolves endpoints only through maintained canonical labels
and accepted aliases. It does not import prototype hard-coded spelling rewrites
as authority. Aliases of one waypoint collapse by identity; multiple identities
remain ambiguous. Reviewed cable candidates require both endpoints and matching
network/spare designation, with all parallel candidates retained. A new test UUID
never creates a cable or automatically becomes a retest association. Source
payload/measurement variants, changed existing evidence, changed display names,
deleted source records, ambiguous endpoints and competing cables surface as
review reasons. Source proposals are immutable per file/test; replays produce
new run receipts without overwriting original proposals or accepted links.

The engineering `review-linkiq` command accepts a source SHA, test UUID, existing
reviewed cable ID, actor, evidence notes and expected previous cable ID. It rejects
stale bindings or unreviewed/incomplete/retired targets; appends an attributed
`ops.linkiq_identity_decision`; updates only test-to-cable review fields, never
original measurements. It permits explicit human reconciliation beyond automatic
candidates and requires supporting notes. This is NOT a public endpoint or role
grant: #230 must supply server-side authorization before operator exposure.

### Actual source findings and verification

Latest attached GPX SHA:
`a4e48a8938a6e3e889065df74d6140b95e8097d76cd53c0d4dbbce1fb591e0af`.
Greg confirms the revision includes icon work. There are 233 waypoints and 181
tracks. Use this source for the next reviewed bootstrap, not the old hash.
FLW remains SHA
`e76d39179da99bb74ed8e2af7f4e555a71ff530cae58bdb0015e770677a3ef5e`;
drawing remains SHA
`65d7607485e526e4d058b4ce997a24f2fe53a731b4f52817dcd44233e420a0a8`.

Read-only execution against the actual attached GPX/FLW: 476 distinct tests,
684 appearances. With canonical waypoint labels only (no invented accepted
aliases or reviewed cable inventory), 307 tests resolve to two distinct waypoint
IDs; 148 have unresolved/ambiguous endpoints, 19 require name review, and 2 have
the same resolved endpoint. Seven source-deleted tests and one raw-payload variant
are additional overlapping review flags. These are test/proposal counts, NOT
accepted cable counts, and no database was populated by this read-only analysis.

The raw-payload variant is UUID `c79663cd-e179-4829-95b0-bfb65902e76a`, label
`WW-00 TO WW-04 REG`, across MSB-Park-Network and Park Network projects. Different
payload hashes do not by themselves prove measurement disagreement. Retain both
payloads and review; do not silently select one as a correction.

Validation: 44 focused Python tests PASS, one pre-existing environment-path skip;
existing map network browser checks PASS; `git diff --check` PASS. Tests cover
new/replay receipts, raw-appearance retention, reviewed-link preservation, numeric
length comparison, duplicate aliases, parallel cables, source drift, payload and
label changes, deleted records, explicit review attribution and stale-link refusal.
DB call-boundary fixtures are NOT PostgreSQL execution. New disposable SQL
assertions cover intake tables, proposal replay, per-run receipts and decision
notes. They have not been executed against PostgreSQL in this environment.

### Remaining acceptance and next implementation

No PostgreSQL binaries/driver are available in this engineering environment;
package installation failed under runtime permissions. Use the EXISTING governed
shared disposable acceptance wrapper and updated allowlisted candidate schema/
validation paths. Do not substitute SQLite for PostgreSQL acceptance, improvise a
server preview or touch Production. The prior schema PASS does not cover these
new tables/statements.

The next gate must execute actual initial GPX bootstrap plus FLW ingestion,
identical replay, a later export with a new test/retest/changed label, and explicit
identity review on the governed disposable DB. No claim that these engine changes
are ready for October 12 operator use until that gate and operator access are proven.

Still required: usable authorized #230 import/reconciliation and reference editor,
reviewed physical-cable creation, panel/circuit/on-off maintenance, actual maintained
map reads, complete GPX export/reimport with source metadata, and eventual keyed
color-coded draw.io updates. This commit does not deliver those interfaces or
claim the overall engineering objective complete. Preserve existing candidates
and move through the same #319/#230 workstream under #122.

## FLW additive imports and unsafe writeback history — October 11 recovery

**Operator correction, October 11 at 16:43 America/Chicago:** the supplied FLW
contains **two imports**. Import is additive; preserve both collections of test
evidence. Greg reports a prior assistant directly edited the FLW, LinkWare rebuilt
it, and all displayed cable lengths changed. This was unsafe. The exact cause
of the length changes has not been established; do not assert an NVP/calibration
explanation or prescribe repair of unknown internal fields.

The [original #122 handoff](https://github.com/Gregovate/MSB-Production-Database-Project/issues/122#issuecomment-6100758741)
requires preserving Rich's new tests and comparing the latest export to prior
round-trip evidence. It does NOT authorize replacing a newer file with yesterday's
cleaned snapshot. DBG-2026-011 in that same comment concerns deferred tablet GPS;
it is not the identifier of the FLW-writeback failure.

Distinguish the two historical operations:
- The controlled Network Source Reconciliation document records a **supported
  LinkWare property edit followed by read-only SQLite inspection**. It preserved
  470 UUIDs and recorded lengths/results/binary data for that particular file.
  This proved readback of Notes, Faceplate and OutletId, not arbitrary SQLite
  write safety or tester writeback.
- Retrieved prior-conversation summaries describe an externally modified
  `26-10-10-Park-Data-MSB-Reconciliation-Candidate.flw`, changing CableId,
  CableIdLong and Deleted, followed by LinkWare's outside-modification/rebuild
  warning. Greg now directly confirms the subsequent displayed-length problem.
  The old candidate and rebuild output were not independently re-compared in
  this recovery; exact repair mechanics remain unknown.

**Current mandatory implementation boundary:** FLW is read-only input. Do not
edit SQLite Records/RecordData, hashes, results, lengths or metadata; do not create
a corrected FLW copy, engineer around the rebuild mechanism, or push corrections
to the tester. Maintain corrected names, aliases and reviewed relationships in
PostgreSQL. GPX/draw.io output capability does not extend to FLW output.

Latest trusted uploaded FLW SHA remains
`e76d39179da99bb74ed8e2af7f4e555a71ff530cae58bdb0015e770677a3ef5e`:
684 project appearances, 476 distinct test UUIDs and 208 repeated appearances.
Those counts do not mean 684 physical cables and do not independently establish
which rows belong to each of the two operator-reported import sessions.
Retain every appearance, deduplicate only test UUID identity, append new tests
and retests, and preserve original test values plus reviewed DB corrections.
Missing records from a later export do not authorize deleting historical tests.

The current candidate uses SQLite URI mode=ro/immutable=1 and query_only=ON;
`ingest_linkiq` verifies source SHA before/after extraction and writes PostgreSQL
only. Existing source-preservation regression checks verify unchanged FLW hash.
The matching current hash does not independently validate the earlier failed
candidate; no attempt to repair or overwrite the supplied FLW was performed.

Earlier text proposing FLW metadata correction or device writeback is historical
and superseded by this prohibition. Additive DB reconciliation, not FLW rewrite,
is the required ongoing workflow.


### Immediate real-source database acceptance — 2026-10-11

Operator deadline is today, not tomorrow. GIS is not accepted as working merely
because extractor/unit tests pass. The existing governed disposable browser runner now
accepts `-GisGpxPath`, `-GisFlwPath`, and a nonblank `-GisActor` alongside the
#171 schema migration and validation paths. It copies sources into its existing
upload bundle, records SHA256, verifies uploaded bytes before the production
read, and runs `accept_site_sources.py` against the disposable container only.
No additional dump workflow or production write is introduced.

The gate loads GPX before FLW, verifies GPX replay, imports FLW twice, verifies
zero duplicate tests/appearances and unchanged original results/cable bindings,
checks source appearance/proposal counts, and exports PostgreSQL map GeoJSON and
GPX. Reports and exports remain in the existing server acceptance report folder;
the disposable database remains available through browser review and is removed
by established cleanup after the operator ends the review. This is an
integration gate, not a deployment or a manager editing UI. Failures must be
resolved before claiming actual GIS operation. PowerShell and live PostgreSQL
execution remain unverified in this environment.

Explicit operator clarification: cable tests belong in `ops`. Implemented tables
are `ops.linkiq_test`, `ops.linkiq_test_appearance`, `ops.linkiq_intake_review`,
`ops.linkiq_import_receipt`, and `ops.linkiq_identity_decision`. Maintained GIS
waypoints and physical cable identities belong in `ref`. Endpoint proposals use
loaded database waypoint IDs and accepted aliases; GPX ordinals are never used
as database identities. Corrected FLW display names drive proposals, while the
original tester names and all appearances remain immutable evidence.

Read-only inspection of supplied FLW confirms 684 appearances / 476 UUIDs:
MSB-Park-Network 470, Park Network 194, Command Trailer 20. These are project
buckets, not a claim of three import sessions; operator reports two additive
imports. Corrected names `CC-00 TO A5-02A REG` (original `CC-00 to IT-00 REG`),
`FC-00A TO PANEL 09 REG` (original `FC-00A TO PANEL 9 REG`), and
`A5-14/16 TO A5-12 REG` (original `A5-14&16 TO A5-12 REG`) resolve against the
supplied GPX labels. `FE-10 TO FE-10 SPARE-1` resolves to one identical endpoint
and must remain under review. No FLW bytes were edited.

Validation: 44 engineering tests passed / 1 skipped; 21 existing acceptance
runner contract tests passed; Bash syntax, Python compilation and diff checks
passed. No PostgreSQL integration success or production deployment is claimed.

### Single-clone correction — operator instruction, 2026-10-11

The initial 7d4d2a8 placement of the real-source gate in the standalone acceptance
runner would require another clone for browser review. Superseded: the source
parameters and gate now live in the existing browser runner, which already runs
regression, migrations and SQL validation before launching the browser. Use ONE
dump/clone for this full lifecycle, with normal cleanup only after the operator
ends browser review. Preserve existing failure/reconnect handling. The standalone
runner changes from 7d4d2a8 are reverted. The browser wrapper consumes the existing
#230 exact-candidate reference SQL allowlist and supports LocalReviewBranch.
The acceptance README's stale instruction to create a fresh browser clone is
corrected. Server Management remains runtime authority. No live execution claimed.

### Runtime preflight failure and correction — 2026-10-11 17:26 CDT

Operator run of 855fa678 passed the reported 202-test regression block, then
failed before pg_dump: `ModuleNotFoundError: No module named psycopg`.
Report: `/home/msbadmin/setup-acceptance-reports/Setup_Disposable_Browser_Preview_20261011T222501.txt`.
Production Setup fingerprint remained `b68f5d22d666fd552983d0a200f07d62`;
live Setup SHA remained `2bc88ae627420c2138268e39a26b4942a3248580`.
No browser started and this preflight failure is not resumable. No dump was taken.

Cause: candidate importer assumed psycopg v3 despite existing Setup/FieldWiring
repositories using psycopg2 in the governed shared runtime. Corrected importer
and preflight to use psycopg2, without installing packages or changing server
runtime. `site_db_connection.py` explicitly brackets each import in BEGIN /
COMMIT or ROLLBACK, closes the connection, and rejects nested transaction use.
Focused verification: 63 passed / 1 skipped, including commit, failure rollback,
retry, and nested-transaction rejection; Bash syntax and diff checks passed.
Actual PostgreSQL import/replay and browser review remain pending the retry.

### Reuse unchanged source transfers — 2026-10-11 17:29 CDT

Greg reports the unchanged 253 MB FLW being uploaded again on every retry.
Corrected browser wrapper: compute source SHA256 locally, perform one foreground
SSH cache-presence probe, and put only missing sources in the existing SCP bundle.
Server stores verified immutable source bytes in `$HOME/setup-source-cache`, keyed
by SHA256 plus extension, and checks their hashes on each run before intake.
Atomic publication prevents partially copied files being treated as cached.
Preview cleanup removes its temporary bundle/clone, not this reusable source cache.
A changed source gets a distinct key and retains the earlier evidence. Cache
corruption fails closed. This adds no database dump and no background SSH process.
The in-flight c2b206a2 run is not altered; its old cleanup may remove source files,
so the first corrected run may need one cache-populating upload. No claim that
already-deleted files can be reused. Validation: 25 tests passed including actual
Bash cache reuse, new hash isolation, bad-upload rejection and existing runner
contracts; Bash syntax and diff checks passed. Windows/server validation pending.


### Operator-proven disposable intake and browser readiness — 2026-10-11 17:35 CDT

Exact executed candidate: `c2b206a2ef4475851807941e46d5824d3021b1e3`.
Operator supplied `GIS_SOURCE_ACCEPTANCE_PASS` at
`/home/msbadmin/setup-acceptance-reports/GIS_Source_Acceptance_20261011T222827`.
This establishes successful actual GPX bootstrap/replay, FLW import/replay evidence
checks, source conservation checks and map/GPX exports enforced by that candidate's
accept_site_sources.py. Detailed counts remain in acceptance.json; not pasted in
this operator output and not independently retrieved here.

Preview health PASS: Setup V0.3.62-field-networks, data_mode postgres;
authorization PASS; Field Wiring V0.4.1-gis-entry health and GIS navigation PASS.
Browser ready on 8898, operator gliebig@sheboyganlights.org; reconnect state
`/tmp/msb-setup-browser-preview-state-8898.env`. Greg reports the map appears to
work. Review remains OPEN; no clean exit or production approval recorded.
The later df269c63 source-cache change has NOT been exercised by this run.
Postgres health does not prove reference map cutover: current network frontend
still fetches assets/setup_locate_networks.json; no site_waypoint/export_map_projection
consumer was found in Setup or FieldWiring application code. DB-backed reference
map/editing remain unfinished. Preserve this clone through the ongoing review;
do not repeat the dump merely to move between database and browser gates.

### Popup evidence and parallel icon-work boundary — 2026-10-11 17:54 CDT

Greg supplied six screenshots from the open map review; all six were successfully
read from attachments despite the chat's earlier missing-file errors.

| Example | Visible source metadata |
|---|---|
| WV-03 | Type OUT-Combo; source time 2020-11-07T21:05:47Z |
| PANEL GG-00 | Type Panel; description and comment both 932344017; source time 2023-01-17T20:30:31Z |
| HV Panel CL to CL-03 | Type High Voltage; description 2021 New |
| NET CH Icicle Tunnel to Bridge | Type Network; description Installed 2023 New 5 Cables 2 Reg Aux G |
| PRI 27-01 to HWY 42 | Type Primary; no description shown |
| XFORM 36-03 | Type Transformer; description and comment both 36 03; source time 2016-08-30T15:57:42Z |

Preserve these source fields through database import and map consumption. Source
timestamps are provenance, not current inspection or test dates. Do not infer
that 932344017 is a meter ID without confirmation. Track description cable counts
are historical notes, not authoritative current physical cable counts; reconcile
LinkIQ evidence and reviewed cable identities separately. Track endpoint/name
corrections remain outstanding; preserve geometry and shared waypoint capability.

Greg reports another thread owns icon publication and map rendering corrections:
legacy PNG URLs still used instead of msb-svg; forced 32x32 sizing distorts
non-square icons; approved Plain SVG publication also pending. Do not duplicate
that work or change waypoint identities/GPX to compensate. This workstream owns
PostgreSQL data integration and reference-map consumption. Coordinate edits to
locate_preview.html with that work before integration; preserve approved icon
mapping and aspect ratio. No claim that icon fixes are deployed or accepted.

Screenshot filenames, in order: image(20261011-224831).png,
image(20261011-224918).png, image(20261011-225135).png,
image(20261011-225254).png, image(20261011-225343).png,
image(20261011-225424).png.

### Correction: operational popup requirements — 2026-10-11 17:56 CDT

Greg rejects the current popup metadata as inadequate. The six screenshots are
evidence of the gap, NOT acceptance of the fields or presentation. Preservation
of raw source metadata is a provenance obligation, not the user-facing design.

Required useful content:
- Outlet/power waypoint: supplying panel and circuit number(s), actual maintained
  network assignments, linked physical cables and available LinkIQ speed/result
  evidence, with test date and unresolved mappings explicit.
- Panel: circuit-by-circuit supplied waypoints/loads, what gets turned on/off for
  MSB operations, and MSB versus City ownership. Record instructions separately
  from observed on/off state; do not infer either from GPX names or track colors.
- Network route/cable: actual network designations and individual linked cable
  test results/speed evidence; do not represent multiple cables by one assumed
  result or treat a requested test standard as achieved/passed speed.
- Relevant installation/source year is useful. Preserve exact timestamps,
  original descriptions/comments and importer provenance in secondary detail,
  rather than making them the principal operational content.

Ownership must have an explicit maintained value and an unknown/unconfirmed
state, rather than guessed MSB/City ownership. Clarify panel-level and circuit-level
ownership distinctions when evidence requires them. Switching designation and
seasonal actions belong to the existing Production Crew panel/circuit scope.
Missing/unreviewed circuit, network, ownership, speed or switching information
must be visibly missing, not silently defaulted, invented, or inferred from
historical descriptions. Waypoint maintenance remains PostgreSQL-authoritative;
LinkIQ remains measurement/test authority. Source timestamps are not test dates.


### Browser session closeout — 2026-10-11 18:11 CDT

Greg reported `SETUP REUSABLE DISPOSABLE BROWSER PREVIEW: CLEAN EXIT` for the
c2b206a2ef4475851807941e46d5824d3021b1e3 review above. The combined
regression/import/browser session has ended through the normal runner cleanup
path. Detailed teardown lines were not supplied here; record the reported clean
exit without inventing individual resource checks. Actual source intake/replay
and exports passed. Browser disposition: CHANGES REQUIRED — reference map still
uses snapshot data; operational circuit/network/test/ownership/switching popups
remain incomplete. No production deployment approval or production import is
established. Later source-cache changes were not tested by this session.


### Restart checkpoint — 2026-10-11 18:24 CDT

**Stop point:** Greg requested a checkpoint. Work is authorized to continue;
there is no outstanding user decision blocking implementation. Previous replies
stopped at status updates instead of implementing the next slice. No background
implementation should be assumed.

**Governing work:** #122 commanding; #171 GIS; #230 maintained reference editing;
draft PR #319 / feature/171-cableiq-import-validation. #88 movement unchanged.
Separate icon thread owns SVG publication, legacy PNG replacement, and aspect
ratio rendering. Coordinate shared map-file edits; do not duplicate icon work.

**Actually proved:** operator ran c2b206a2ef4475851807941e46d5824d3021b1e3.
Actual GPX bootstrap/replay, FLW import/replay and source-conservation assertions,
map/GPX exports passed in disposable PostgreSQL. GIS_SOURCE_ACCEPTANCE_PASS:
 /home/msbadmin/setup-acceptance-reports/GIS_Source_Acceptance_20261011T222827
Setup V0.3.62-field-networks and Field Wiring V0.4.1-gis-entry health,
authorization and navigation passed. Operator inspected map, rejected current
popup metadata as inadequate, then reported CLEAN EXIT at 18:11 CDT.
Disposition: CHANGES REQUIRED. No production import, deployment or approval.
The disposable session ended; do not assume its database remains.

**Later candidate work:** df269c63a46ed98a24d87c86e10d1512931e0923 added
hash-keyed server source cache; 25 focused tests passed, server execution not yet
proved. Subsequent commits record evidence and requirements. Refresh current
PR head and main before editing; tested c2b206a2 is not current branch head.

**Sources / authority:**
- GPX: 233 waypoints, 181 tracks. Latest uploaded SHA256
  a4e48a8938a6e3e889065df74d6140b95e8097d76cd53c0d4dbbce1fb591e0af.
  Waypoint names/icons updated; NET/PRI/HV track names still need reconciliation.
  Track geometry unchanged per operator; multiple tracks may share waypoints.
- FLW: 476 unique test UUIDs / 684 appearances, two additive imports per operator.
  SHA256 e76d39179da99bb74ed8e2af7f4e555a71ff530cae58bdb0015e770677a3ef5e.
  Preserve all source/project appearances. Corrected display endpoint names are
  separate from original tester names. 307 tests resolved to two distinct GPX
  labels in source-only analysis; NOT an accepted physical cable count.
- draw.io SHA256
  65d7607485e526e4d058b4ce997a24f2fe53a731b4f52817dcd44233e420a0a8.
  Downstream park-network schematic; structured keys incomplete. Eventually
  refresh bound entities with GPS identities and LinkIQ pass/fail/speed colors.
- PostgreSQL is maintained waypoint/reference authority; LinkIQ is test evidence
  authority. Tests, appearances, intake proposals, receipts and decisions in ops;
  maintained waypoints/cables in ref. NEVER modify FLW or write back to tester.
  Prior external SQLite editing/rebuild changed lengths per operator; cause
  unproved. Preserve originals and reconcile in PostgreSQL.

**Implementation still missing:** existing displayed map still consumes baked
reference geography/static network JSON. Actual imported data has not been
connected to the application map or a usable authorized maintenance interface.
Reviewed cable creation/reconciliation, maintained circuit/panel/network links,
track endpoint/name reconciliation, conflict-aware ExpertGPS reimport, completed
draw.io projection and offline acceptance remain incomplete. Export checks do
not prove ExpertGPS application save/reopen roundtrip. CLI import success does
not prove role-authorized operator editing.

**Next implementation:** connect the EXISTING map to governed PostgreSQL
reference reads, preserving #88 overlays and icon-thread work. Surface useful
operational information: outlet supplying panel/circuit(s), actual networks,
individual cable LinkIQ results/speed/length/date; panel circuit destinations,
MSB/City ownership, seasonal on/off instructions distinct from observed state.
Keep useful year; move raw source provenance to secondary detail. Unknown values
must be explicit, not inferred from labels, track colors or historical notes.
PANEL GG-00 number 932344017 is not confirmed as meter ID. Do not infer achieved
speed from test standard. Add maintained editing through existing #230 scope,
with real authorization/audit boundaries, not another independent data store.

**Execution constraints:** ONE production dump/clone for regression, intake and
browser review; normal cleanup after clean operator review exit. Existing
reconnect/failure handling remains. No repeat uploads of unchanged sources after
cache is populated. Existing governed shared runtime uses psycopg2; missing
psycopg v3 caused earlier preflight failure and was fixed without installation.
Server Management owns runbooks and port allocation (Setup review 8898).
Runbook clarification PR: Gregovate/MSB-Server-Management#73; verify current
status. Production mutation is a separate explicit #122/runbook approval gate.

**Operator environment:** review checkout
C:\\lor\\ImportExport\\VSCode-319-linkiq-test, local review/319-linkiq-test;
remote feature/171-cableiq-import-validation. Do not reset primary checkout.
Recorded current-source G: paths are in this document's source table. No active
server access is established in this assistant environment. Local scratch clone
contains published edits but its local HEAD may lag remote history; reconcile
without discarding edits. Retrieve this checkpoint from GitHub if scratch is lost.

**Resume instruction:** Continue #171/#230 under #122 from the 2026-10-11
18:24 CDT checkpoint in Site_Source_Synchronization_Contract.md on PR #319.
Read current main/PR/issues and rules; implement the PostgreSQL-backed existing
map and maintained operational relationships. Do not repeat already-proven
source extraction or ask Greg to restate requirements. Record new work durably.
