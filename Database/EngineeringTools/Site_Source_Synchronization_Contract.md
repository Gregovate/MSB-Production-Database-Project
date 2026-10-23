# MSB #171 / #319 / #230 — Site-source synchronization implementation contract

## October 23 — operator-controlled living-master snapshot intake

Greg controls the source and timing of each intake from the Shared Drive master.
The master is expected to change. A historical upload digest is not a permanent
allowlist. The existing runner calculates a digest of the selected revision;
that digest pins the captured bytes, transfer and review, not future master edits.
No watcher, scheduled import or save-triggered Production write is authorized.

Reuse the control pattern in [LOR promotion design](../../LOR2DB/02_Reconciliation/01_LOR_Production_Promotion_Pipeline_Design.md)
and [operator workflow](../../LOR2DB/02_Reconciliation/00_LOR_Production_Import_and_Reconciliation_Procedure.md):
Capture selected source -> inspect snapshot -> explicitly start comparison ->
resolve/review exceptions -> explicitly Finish/apply -> validate/report.
This is an extension of the existing GIS importer/Manager, not a second importer
or an instruction to run GIS through the LOR data model/Windows listener.

Comparison uses last accepted source, selected incoming source and current
maintained database state. Latest staged or most recently uploaded is not the
accepted baseline. An open review retains its captured source even while Greg
continues editing the master. Any later source selection or changed database
revision invalidates earlier apply approval and requires fresh comparison.

Every waypoint map-name or GPS-name change is a review item, regardless of count.
Report additions, missing records, symbol/type changes, coordinates, descriptions,
track labels/geometry/style and database-only corrections. Show old/new values,
counts and stable identity. Missing features are retained, not automatically
deleted. A rename preserves permanent waypoint ID and retains the old map label
as an alias; aliases, GPS/PANEL lookup ambiguity, splits/merges and duplicate
identity claims must be resolved. Track replacement retains old geometry/history.
No arbitrary percentage threshold makes a rename or a deletion safe.

Before promotion, the existing reference model must enumerate affected panels,
breaker/circuit feeds, receptacles, reviewed cable/track/route associations,
network assignments, FieldWiring picker and LinkIQ evidence matches. Unavailable
or incomplete dependency analysis blocks apply; it must not be reported as zero
impact. GPX changes never rewrite circuit definitions or electrical topology.
Finish must revalidate source/baseline/database revision, permissions and frozen
decisions; apply one approved change set transactionally, preserve history and
aliases, validate consumers, and publish a durable result. No-op does not update
reference audit fields. Cancel/defer leaves maintained references unchanged.

Implementation status: pure three-way comparison/identity/alias conflict checks
exist. This continuation adds per-kind counts and explicit review categories,
including GPS names/symbols that must not be silently omitted. Its output always
states no writes and not ready for promotion. Coherent database dependency
capture, persisted operator decisions, Manager review UI, recurring transactional
apply, stale-approval enforcement and operator acceptance remain release gates.
The current disposable bootstrap is not recurring synchronization acceptance.

## October 23 — ExpertGPS track label and presentation correction

The operator's timestamp track has GPS name `10/14/2026 12:17:44 PM`, map label
`HV PANEL 09 to LPFC-01`, and ExpertGPS line color `fc180d`, width `1.0417` mm,
opacity 1 and white casing. Prior extraction archived the XML but failed to
project map labels/style. Track display identity must use overlay label_text
when present, with GPX name retained separately. Project existing GPX line
color/opacity/width/pattern/casing; convert millimeters to CSS pixels at 96 dpi.
Width units follow the [TopoGrafix style schema](https://www.topografix.com/gpx/gpx_style/0/2/).
Keep original XML/bytes unchanged. Display-label exports edit overlay label_text,
never overwrite the GPS name; legacy tracks lacking map labels retain explicit
name-edit compatibility. No inferred network assignment or geometry shifts.

Local correction verification: 14 of the supplied 220 tracks have different map
and GPS names; 218 use Solid and two use Dot. Regression: 167 engineering/shared-host
checks passed, two explicit PostGIS skips locally, six subtests; Setup application
901 and FieldWiring 220 passed in separate processes (their legacy module names
collide if collected together). Existing PGlite command suite: 82 checks passed.
Existing Chromium panel workflow passed for main 100 A, branch positions 18/20,
two circuits, mobile width and read-only denial. Local actual-map HTML with an API
fixture from the supplied GPX shows the correct HV label, color #fc180d and width
3.937 CSS px; wrong source still blocks. This is not server/operator acceptance.

## October 23 — operator review rejected; shared-host correction

Greg reports nonfunctional circuit buttons, absent preloaded panels and a map
that displays older GPX data. Treat the prior candidate as REVIEW FAILED,
not accepted. The shared host must serve FieldWiring static resources using its
explicit application root and resolve its repository from the owning Flask app,
not the already-loaded Setup backend module. Shared-host tests must GET the
actual circuit JS/CSS and exercise both power read and command endpoints.

Initial intake must create unverified panel references for accepted GPX waypoints
explicitly typed Panel, retaining the waypoint IDs and source SHA. Use the existing
power command for role enforcement and audit. Preserve existing/retired records
on replay; do not infer breaker numbers, amps, circuits or topology from labels.
The map's About source label must reflect the successfully rendered database GPX
hash and counts. Exact-source disposable review must remove the embedded older
GPX before rendering and reject any database source hash mismatch. API failure
must visibly block the map, without historical or offline fallback. The actual
operator map mismatch still requires the failed preview status/report evidence;
correcting the misleading source label alone does not prove its root cause.

### Exact-source review and clean exit evidence

The operator subsequently confirmed actual old map data and reported
`Setup REUSABLE DISPOSABLE BROWSER PREVIEW: CLEAN EXIT`. This is teardown evidence,
not browser acceptance or proof of import success. Keep operator review FAILED
until corrected behavior is demonstrated in the current-Production clone.

The existing runner now passes its selected GPX hash to the existing map host.
Strict review strips old embedded features on the server and the client requires
the same accepted database source fingerprint before rendering. A changed HTML
bootstrap boundary also fails closed. Normal governed offline behavior outside
this exact-source preview is unchanged.

Local Chromium verification used actual host-rendered strict HTML and a reference
API fixture derived from the approved GPX
`87b195845a0334769334be9e22d056c3061feaa5f5a2d9dae127db975ce8bc24`:
240 current waypoint markers and 220 tracks rendered; replacing the API source
hash blocked the map and left zero waypoint markers, with no old-data fallback.
This is browser regression evidence, not a current-Production clone result.
Setup regression: 902 tests passed. The actual shared-host test verifies the
strict HTML and FieldWiring assets/read/write routing. No Production mutation.

## October 23 — combined implementation test checkpoint

One candidate combines #319 and #454. The existing power schema now owns breaker
identity/rating/poles, circuit pole membership, receptacle devices, and cable
conductor/shared-neutral associations. Existing GIS physical cable IDs and
waypoint IDs are reused. The old competing power tables and email grant store
are removed from the uninstalled GIS operations draft. Directus remains authority.
The existing browser runner requires all three migrations in dependency order;
one clone and listener serve Setup GIS and FieldWiring. The real-source gate
compares both consumers' waypoint IDs/names and exercises two circuit legs and
two receptacles at an imported waypoint, then rolls back only those fixtures.

Source preservation/replay and first-load acceptance are implemented. Recurring
reviewed promotion of subsequent GPX geometry revisions remains unfinished and
is not represented as operational by this candidate. Initial source acceptance
does not verify field topology; A5 verification is still pending. No Production
installation, operator acceptance or current-clone PASS is claimed here.

## October 23 — one GIS and circuit database release (operator direction)

Greg requires one coordinated schema change, including circuit identities. The
commanding integration remains PR #319, incorporating PR #454 head
`57174f1066ebf3c1f994d54208028f260bb2ccb0` with its history. There is one planned
current-Production clone, exact combined candidate and operator review, followed
by one explicitly approved #37 maintenance/snapshot/deployment window. No interim
GIS-only Production installation. SQL dependency files may remain separate for
review but are one ordered migration set: infrastructure foundation, PR #454 power
capture, then GIS operations/read projection. Existing network identities remain.

Remove the uninstalled legacy power definitions and commands from GIS operations.
PR #454 owns panel/circuit/device/feed/network/action IDs, desired states, seasonal
events, actor attribution and correction history. The existing Park Map consumes
that model through a read-only projection, including indirect device feed paths;
power editing links to FieldWiring's circuit editor. Do not adapt old writes to
silently discard the new evidence/verification/idempotency requirements.

GIS identity writes must use installed Directus capability/actor authority, not
an independent email grant table. Existing positive-grant test tooling becomes
obsolete and must not run in the combined candidate. The same reusable disposable
runner and exact-path allowlist gain the power migration and combined assertions;
no new deployment service, runner or port. Synthetic CI fixtures of installed
actor dependencies are NOT live role provisioning or current-clone evidence.

## October 23 — complete GPX evidence and source-name rules

Current supplied master is `MSB-Park-Infrastructure(20261023-074556).gpx`,
SHA256 `87b195845a0334769334be9e22d056c3061feaa5f5a2d9dae127db975ce8bc24`,
240 waypoints and 220 tracks. It supersedes the October 22 source selection
below. A5 field verification remains pending. Initial source acceptance is not
physical verification; bootstrap must leave verified_by/verified_at unset.
Latest supplied FLW `LinkIQ Data Import for DB with corrected names(20261023-075657).flw`
has SHA256 `de23ad7a096e8118366d82d0524879372a9780834d8c3ce8d5ec91628317403e`.
Its 510 active records have no unmatched park waypoint references under the
operator's panel abbreviation rule; one `E1 .31` suffix remains. Retests are
history, never duplicate-name errors. Deleted appearances remain evidence.

Store the entire original GPX bytes as a base64 DOCUMENT observation within the
existing source ledger, in the same transaction as staging/bootstrap. Feature
JSON/XML alone omits root metadata, routes, namespace bindings, comments and
other document-level evidence. The original-byte SHA is authoritative. A
no-edit export must be byte-identical. Edited exports patch only the explicitly
supported reviewed fields in a DOM preserving namespace declarations, unknown
extensions, comments and processing instructions; compare the entire resulting
XML document before publishing. Never overwrite an existing output or original.
Unsupported edit fields must fail instead of being silently ignored. Reject DTD
input rather than expanding external/entity content. Reuse site_source_sync.py,
site_source_db.py and existing ops.site_source_observation, not another importer.

ExpertGPS Name on Map and Name on GPS are independent source values. Lookup may
use either, retaining collisions as ambiguous. Approved programming convention:
PANEL-prefixed labels may resolve their suffix, and PANEL 10 WV-00 also resolves
WV-00. This creates lookup candidates, not physical cable identity approval.
Command Center is the plugged-in trailer, not automatically the park area label.
MSB OFFICE/FOOD BANK are outside park reconciliation. Preserve all raw text.

Current #171/#230 handoff from PR #454 supplies the live catalog inventory and
confirms the existing site_network shape. PR #454 owns the new circuit model;
its power migration and the older uninstalled #319 power definitions must NOT
be installed together. Combined consumer/schema acceptance remains unfinished.
This preservation increment does not authorize Production or establish recurring
promotion, Windows ExpertGPS acceptance, or current-clone acceptance.

## October 22 — supplied current master and initial-load correction

Greg confirms no waypoint/track reference tables have yet been created in
Production. Treat this as operator-reported state, to be checked by the existing
current-clone schema gate, not as an already-populated synchronization deployment.
The immediate delivery is the existing #319 schema/bootstrap and current waypoint
reference lookup for FieldWiring circuits. Recurring revisions remain required
but must not be confused with the first load.

Supplied source `MSB-Park-Infrastructure(8).gpx` is the current input for this
acceptance candidate: 462701 bytes; SHA256
`286d449e0e02446d0377915ef6bd015c3ad75a7b98c2bcd2bc332a13874a8462`;
240 uniquely labeled waypoints, 211 source tracks, 17 Panel-type waypoints.
All 240 waypoint symbols are present. Preserve source Type spellings, including
`OUT-Combo` and `Outlet_Combo`, without inventing a normalization/icon mapping.
Three incomplete source tracks (ordinals 5,150,185) retain source evidence and
empty geometry; duplicate track names do not identify the same physical cable.
No separate Garmin calibration observations were supplied for this intake.

LinkIQ/FLW intake is one-way evidence. Database waypoints can help resolve test
endpoint labels after file import; there is no supported MSB waypoint-upload
workflow to the LinkIQ tester. Tester upload and FLW availability are not gates
for waypoint/circuit lookup. Extend the EXISTING reusable disposable acceptance
runner to allow GPX-only intake, explicitly reporting FLW NOT_REQUESTED while
preserving combined GPX+FLW tests when selected. Keep the same single clone,
source SHA validation, replay, conservation, source cache and cleanup controls.
A GPX-only run must not prune unrelated cached FLW inputs. This is no permission
for Production installation or creation of circuit definitions.

## October 22 — recurring-source preview implementation boundary

Current-main reconciliation uses `e3590c264da048bdd8ffb5f368fd3f928e15d71a`
and preserves both parents of existing #319. Priority 0 is current approved
ExpertGPS master to maintained PostgreSQL, consumed by FieldWiring. Garmin
calibration observations are explicitly excluded; preserve 2019 calibration.

The existing extractor must hash the exact bytes it parses and retain symbol,
marker and extension evidence. Recurring preview must require the incoming SHA,
accepted baseline SHA, database revision and explicit per-source-row permanent
identity decisions. Source ordinals identify observations within one SHA only;
they are never identities across exports. Names/proximity are not authorization.
Compare each resolved item against its accepted baseline and current maintained
record. Preserve database-only edits; report divergent edits as conflicts. Renames
must preview retained aliases and reject collisions. Unmapped, missing and split
items require review; absence is never an automatic deletion or retirement.
Track geometry replacement retains source snapshots and permanent track identity;
physical cable topology/route associations cannot be inferred from that geometry.

This iteration supplies read-only deterministic preview logic in the EXISTING
source synchronization module. A preview hash binds the complete decision inputs
and output but is NOT an approval token or a permission to write. Atomic governed
promotion, saved review UI, current-clone schema inventory and FieldWiring picker
integration remain required before operational acceptance. Do not expose an apply
command until those write-path gates are implemented and tested. Existing bootstrap
must continue refusing changed sources in populated references.

Newest Library filename located during reconnaissance is
`MSB-Park-Infrastructure-2026-10-19.gpx` (uploaded October 20). That filename and
upload date do not establish current Shared Drive bytes or operator approval.
The attached repository text file contains only the GitHub URL. Current master
fingerprint and live database binding remain unverified; older 236-point snapshots
must not be promoted as current by default.

## #171 source-parity dependency for ongoing #319 reconciliation — October 13

The #171 engineering operator has prioritized verification of the same scanned-map raster/calibration on authorized workstations, exact YOGA-GREG ExpertGPS Type/marker/GPS-symbol/reverse-map/PNG synchronization to Office and Show, and disposable GPX icon/extension-preserving round trips BEFORE declaring continuing master GPX sources safe for recurring #319 intake. The Office same-image map correction was operator-accepted, but the reverse Office working-map distribution and icon sync are still unaccepted. Recent network repair surveys and new Garmin tracks make the source continuously changing. Do not treat one-time imported snapshots as authoritative current revisions.

The existing #319 engine can develop and test in parallel using source snapshots, but the recurring real-world source acceptance must be gated on confirmed #171 workstation parity and controlled GPX read/write integrity. Preserve original GPX and LinkIQ immutable evidence, review revisions/conflicts against existing PostGIS identities, and label current published Park Map source revision/age. FLW remains strictly one-way intake. Avoid creating a separate desktop database engine or changing Production based on an unverified workstation GPX export.

## CURRENT ENGINEERING CHECKPOINT — October 13, 2026, GPX/FLW recurring intake (PR #319)

**Status: INCOMPLETE / operator acceptance CHANGES REQUIRED; no Production GPX migration or accepted recurring import.** This is the current resume point for #171/#230 under #122. Detailed design above remains authoritative. Do not infer completion from a successful one-time empty-disposable bootstrap, uploaded GPX, passing synthetic CI, or read-only map. The existing #319 code is an engineering candidate; keep the active main/parallel branches reconciled.

**Latest operator-designated GPX source:** `MSB-Park-Infrastructure.gpx`, permanent Shared Drive location `Display Folders/Park Drawings/MSB GIS/MSB-Park-Infrastructure.gpx` (mount letter is host-specific). Most recent October 13 uploaded candidate `MSB-Park-Infrastructure(4).gpx` was reported inspected with SHA-256 `1594ce1f96c1df8f6751e0d436a99acc824a95274768c2f1b1160376175943fd`, 236 waypoints and 195 tracks. The parenthetical upload suffix is **not** part of the canonical master filename. Verify actual Shared Drive bytes/hash freshly before each run; do not assume the uploaded attachment proves the current G: contents. Earlier 2026-named GPX path remains historical provenance, not a second current master. Command Center (`40-Command Center-CC`), Workshop-related revisions, rerouted/retired/added tracks and newly surveyed repaired-cable lines require source-to-DB reconciliation, not silent replacement.

**What is implemented:** Source-preserving GPX and FLW inspectors; strict hash acceptance on disposable source upload; initial `bootstrap_expertgps` into empty PostGIS and idempotent same-source replay; one-way read-only FLW import/replay proposals; PostGIS snapshot and map consumption candidate; Setup Record Location picker candidate now reads accepted maintained PostGIS waypoints and caches an offline version rather than October 3 fixed Stage choices. GitHub Actions for the prior candidate demonstrated isolated synthetic/ephemeral PostGIS + broad regression PASS, **not** full latest-file promotion or operator acceptance. The last browser review found useful NET/PRI track inspection but was not overall accepted.

**Critical missing recurring GPX workflow:** `bootstrap_expertgps` refuses a different GPX source SHA if maintained waypoint/track rows already exist. No accepted **online stage → compare additions/edits/deletions/track geometry and labels → stable identity/conflict review → explicit attributed promotion → downstream/ offline revision refresh** interface exists yet. A renamed track is not a new cable, and source name, route geometry, physical cable, tests and equipment identity remain different controlled facts. Preserve original GPX extension/type/sym/marker evidence; parallel #171 icon/ExpertGPS authority has documented importer loss of `sym`/marker fields. Do not add a hardcoded Type→icon case list as a substitute. Do not overwrite reviewed geometry or routes based on inferred topology, tester labels or old source ordinals.

**Critical missing recurring FLW workflow:** FLW is strictly one-way immutable tester/LinkWare evidence; retain UUIDs, appearances, retests, prior reviewed cable IDs, raw results and source SHA. Existing importer/tests do not establish a complete Manager/Production-crew usable ongoing intake-and-reconciliation application. Reimport must prove new tests, same-source replay, changed labels, retests and review/conflicts without FLW writeback.

**Application ownership:** #319 owns PostgreSQL/PostGIS intake, guarded writes, identities, reference APIs and acceptance. #230 owns governed permanent waypoint/reference editing. Existing Setup Park Map and Field Wiring Map are consumers; preserve #88 intentional C131/C034 partial unload and movement semantics. Field Wiring retains existing Controller wiring, seasonal Controller position observations, and scoped online Production crew circuit/waypoint assignment and seasonal switching controls; offline engineering edits forbidden. **#378** currently owns Icon Library Manager/ExpertGPS workstation Types, symbols and aerial calibration comparison (parallel work); no shared-file changes or GIS ingest code there without deliberate integration and ownership reconciliation. A future operator-facing GPX/FLW import action may be linked into its GUI only after its scope/permissions are expressly coordinated; PowerShell/CLI is not the desired ongoing Production user workflow.

**Next engineering sequence (do not ask the operator to repeat design):**
1. Refresh current main, #319 head, #378 status and governing rules; preserve parallel source changes. Inspect the actual new Shared Drive GPX SHA and existing accepted PostGIS source binding.
2. Implement staging/diff/identity reconciliation for an already-populated PostGIS reference dataset, including modified/split/new geographic tracks and effective historical relationships. Add test for yesterday's → today's GPX change, immutable source preservation, stale-edit conflict, and repeated no-op import.
3. Expose governed online GPX/FLW source review and promotion in an application UI, with recorded operator approval, not recurring manual PowerShell. Preserve offline read-only reference cache and offline Setup movement queue.
4. Prove accepted `40-Command Center-CC` and other drop points appear in the actual Setup dropdown and updated offline snapshot; no fabricated coordinates, no old static picker.
5. Run targeted/full Setup + Field Wiring, guarded PostGIS migrations/validations, same-source replay/new-source/retest acceptance, one governed current-Production disposable browser review; record exact SHA, version, clone/fingerprint cleanup. No Production mutation without Server Management runbook and separate authorization.

**Evidence and limitations:** latest supplied October 13 GPX was inspected in chat; this checkpoint does not claim the bytes were committed to Git, re-read from canonical Shared Drive, imported to live Production, or fully reconciled in a populated database. Use issue #171/#230 and PR #319 for evidence, not as competing design specifications. This checkpoint supersedes older October 11–12 resume points where they conflict.

## Governing engineering design priority — ONE maintained site infrastructure system (October 12, 2026)

**Operator-confirmed, mandatory #171/#230 design and acceptance authority under #122.** This section supersedes any earlier wording or example that would treat the GPS data, LinkIQ tests, draw.io schematic, Setup Park Map, and Field Wiring Map as independently editable inventories. Historical notes below remain provenance, not authorization to create competing records.

**Problem being solved.** Greg originally walked real installed power/network routes and recorded them with GPS. Subsequent crews did not consistently walk, consult, or maintain those routes; draw.io was constructed as a practical substitute, but the hand-maintained schematic developed inconsistencies. Failed links after 2026 roadwork and between seasons demonstrate the operational cost. The purpose of this subsystem is to eliminate reliance on one person's recollection and on three separately flawed or conflicting systems. **PostgreSQL/PostGIS is the one governed, maintained engineering system of record** for reviewed site waypoints, surveyed routes, physical cables, termination/topology, circuit/panel/outlet relationships, lifecycle and attributed revisions. It retains source provenance and uncertainty; it must never manufacture a geographic route from a schematic connection.

### Engineering workstation versus maintained database operations (October 13, 2026)

**Operator-approved boundary for #171 and draft #319:** The Windows MSB GIS Manager is an **engineering-only** application for source acquisition, read-only evidence capture, source validation, comparison, controlled intake proposals and source/device synchronization. It is not the ongoing record editor, a parallel GIS database, or a general volunteer-facing CRUD tool. Engineers use it with ExpertGPS, Garmin GPX and LinkIQ/FLW sources. Once reviewed data is promoted into the maintained PostgreSQL/PostGIS model, subsequent normal editing of waypoints, tracks, endpoints, physical cables, relationships, circuits, and history takes place in the authenticated database application through its existing role-gated audited editor workflows (including #230 ownership where applicable). Avoid duplicate business logic: the desktop client consumes the governed #319 intake/export contract and does not implement a competing spatial/cable model.

**Directions are deliberately asymmetric:** ExpertGPS/GPX and the maintained database are a **review-controlled two-way** interface: original GPX surveyed evidence remains immutable, later database-maintained corrections may generate conflict-checked GPX export, and external GPX changes must be independently reconciled before promotion. Never overwrite an original source or silently resolve competing edits. LinkIQ/FLW is a **one-way intake into the database only**: retain the original tester file, UUIDs, measurements and retest history, never modify or regenerate FLW to reflect database edits, and do not treat tester labels or link pairs as automatically approved physical-cable identities.

**Parallel development:** The #171 workstation/desktop interface and #319 maintained PostGIS intake/editor/backend may progress in parallel against the same versioned engineering contract. Keep their branches and acceptance independent until intentionally integrated with precise source SHA, schema/API version, disposable tests and repository ancestry. No direct desktop writes to Production PostgreSQL; use governed authorization and revision-checked API/ingest transactions when accepted. Do not duplicate the #319 backend inside the desktop application. The five desktop workspaces are Icon Library, ExpertGPS Workstations, Garmin GPS, LinkIQ Intake, GPX Synchronization. These workspaces do not imply that regular database record management moves out of the server application.

### Source interfaces, not separate masters

- **ExpertGPS/GPX ↔ PostgreSQL (two-way, review-controlled):** GPX supplies authoritative surveyed waypoint locations and original recorded route geometry. Preserve the ExpertGPS `Label on Map` field, original Garmin names, coordinates, track geometry, type, extensions, dates, source SHA and historical versions. Following reviewed promotion, database maintenance changes must be eligible for a conflict-aware GPX export/reimport and real ExpertGPS save/reopen round-trip. If both sides changed independently, present a conflict rather than overwriting either side. Do not silently overwrite a shared GPX or replace a surveyed trace with phone GPS.
- **LinkIQ/FLW → PostgreSQL (one-way):** Import all original tester labels, UUIDs, project appearances, measured results, status and retest history as immutable evidence. FLW is read-only; never write it back. Tester naming convention is `Waypoint1 TO Waypoint2 NETWORK` or `Waypoint1 TO Waypoint2 SPARE X`, but tester fields are free-form and contain capitalization/spelling/spacing errors. Resolve using reviewed waypoint identities and aliases; ambiguous strings generate review proposals, not automatic identities. Maintain reviewed physical-cable links across repeated source imports and renamed tester labels. A test or endpoint pair is not automatically a physical cable.
- **PostgreSQL → draw.io:** Keep the manually useful schematic presentation, page layout and stable object IDs, but project reviewed connection/cable attributes from database relationships. Drawing paths and layout are not survey coordinates. Discrepancies return to one review workflow rather than encouraging another independent edit inventory.

### What the system must represent

Maintain distinct historical identities and relationships for **(1)** site waypoint and reviewed location, **(2)** individual physical cable, **(3)** present and past termination endpoints, **(4)** surveyed GPX geographic trace and ordered segment association or explicit unknown route, **(5)** network/spare designation, **(6)** installation type (buried, temporary above ground, or unknown), **(7)** damage, reroute, retermination, repair, planned replacement, actual replacement and retirement events, and **(8)** original LinkIQ results/retests. Multiple parallel cables can share endpoints and surveyed routes without merging. A repaired/rerouted existing physical conductor may keep its identity; a replacement gets a new identity with predecessor/successor linkage. A failed test does not by itself prove the cause, destruction, or replacement.

**Connectivity is not geography.** A tested direct home run FE-01→FE-07 is NOT inferred to physically travel via FE-03 or FE-05 simply because those are connected to FE-01. A route's bend/intermediate survey points do not automatically become cable termination nodes. Never convert topology graph paths, drawing edges or tester cable lengths into authoritative surveyed GPX geometry. Locating decisions must expose missing geography and uncertainty, not false safety.

**Operator-provided regression scenarios:** LP-08→CL-00 historically working cables damaged by 2026 roadwork; new CL-00→CL-10 cables and rerouted original LP-08→CL-10 cables subsequently did not test successfully and are anticipated for replacement. LPFC-03→FE-01 worked last year and failed this year. A temporary above-ground FE-01→FE-07 cable was recorded in prior LinkIQ evidence and scheduled for replacement; FE-01→FE-03, FE-01→FE-05 and FE-01→FE-07 are distinct reported connections, not proof of an inferred FE-01→FE-03→FE-07 geographic path. These are operator observations requiring reconciliation to source rows and surveyed traces, not permission to invent confirmed cable IDs, dates, test outcomes or route geometry.

### Application and edit boundaries — dedicated #230 Site Reference Map owns ALL reference edits

**Three interfaces, one PostgreSQL/PostGIS reference authority.** The prior disposable browser, which placed an engineering editor in the Setup reference map and mixed in seasonal assets, was rejected. Do NOT recreate it, and do NOT make Field Wiring a reference-data editor.

- **Dedicated #230 Site Reference Map / Reference Data Editor:** This is the sole UI entrypoint for adding or editing engineering reference waypoints (including `OUT POWER`, `OUT COMBO`, `OUT NET`), panels, source locations, surveyed track/endpoint/network/spare associations, and panel/circuit/waypoint relationships. Online authorized **Production crew** can create/edit circuits within Manager-controlled panels, select existing maintained waypoints to assign to circuits, and update authorized cable-track endpoints/designations; **Manager** controls protected waypoint identity, type and coordinates. Structured circuit/route metadata must not permit arbitrary renaming or relocation of protected waypoint records. Use revision conflict checks, source provenance, attributed audit and required authorization.
- **Existing Setup Park Map:** Preserve its entrypoint and function. It **consumes** the governed waypoints and tracks read-only and shows Setup-owned scan-derived Container/Display positions, find/search, and seasonal status. No engineering reference edits or #230 maintenance controls; do not move the seasonal asset editor or unlocated list into the #230 reference app. Do not modify Setup Park Map for this editor.
- **Existing Field Wiring Map:** Preserve its *separate existing entrypoint* and Display↔Controller field-wiring workflow. It **consumes** governed `OUT POWER`/`OUT COMBO`/`OUT NET`, panels/outlets, and geographic network/power tracks read-only, with optional Controller locations and panel/breaker/shutoff lookup from a power waypoint. No reference editing from Field Wiring, even for Production crew. Any edit is performed by navigating to the dedicated #230 Site Reference editor under its own authorization; never replace Field Wiring with Setup's map.
- **Offline reference operation:** Each applicable viewer and the #230 reference map may inspect versioned locally cached reference data and **locally packaged Plain SVG markers** (including `stage.svg`). ALL #230 reference/circuit/cable writes and GPX/FLW import/reconciliation are DISABLED offline with no edit queue. Reconnection requires fresh authentication, current lookups and revision verification. A cache miss is unknown/unavailable, not authoritative absence. SVG publication does not establish offline visual acceptance.

**Regression/acceptance:** assert distinct Setup, Field Wiring and #230 entrypoints; no reference edit controls/endpoints in Setup or Field Wiring; positive role-scoped online crew circuit/track edits ONLY through #230 and denial of protected Manager fields; OUT waypoint→source panel/shutoff read-only tracing in Field Wiring; offline cached viewing without writes; no changes to Setup movement projection.

### Field Wiring Production-crew workflow versus durable reference (operator decision, October 12)

**Do not disrupt the established Field Wiring panel-to-Controller wiring workflow.** Crews must continue scanning a Controller, opening its existing wiring workflow and wiring Displays/panels to Controllers as they do today. A Controller scan may capture its **season-specific observed location** with time, operator and GPS accuracy/evidence in the existing seasonal observation model. This is NOT a new permanent surveyed waypoint, and must not overwrite protected GIS positions. Preserve existing controller identity, scan and wiring behaviors.

Field Wiring also needs a **separate, focused Production-crew action area**, accessible within the existing Field Wiring screen but not replacing the wiring interface or turning its map into a general GIS reference editor. While online, authorized Production crew can add/edit panel breaker/circuit records, assign existing governed OUT POWER / OUT COMBO / OUT NET or other applicable waypoint identities, and maintain planned seasonal ON/OFF state. Only a Manager/reference custodian may create, rename, reclassify or move protected waypoint identities and surveyed geographic authority. Crew editing must be audited, revision-guarded and limited to the relationship fields. A powered outlet/waypoint displays its source Panel and applicable breaker/shutoff information.

**Different lifetimes must remain separate:** panel/breaker/circuit-to-waypoint assignment is **durable engineering reference data that rarely changes**; it must persist across annual Setup seasons unless deliberately revised. Seasonal planned ON/OFF is a **season-scoped operational plan**, not an overwrite of durable wiring. A Controller's scanned placement is a **seasonal field observation**, not reference waypoint geometry. Planned power/network/primary routing is not proof of surveyed GPX route; preserve reviewed physical geometry separately. No repeated re-entry of stable circuit assignments every year.

Application ownership: the dedicated #230 Site Reference Map is for governed master waypoint/track/reference administration; the existing Field Wiring work surface can invoke **scoped circuit/assignment/seasonal-control commands** without permitting reference waypoint master edits. Setup Park Map remains its existing read-only engineering-reference consumer with Setup movement views; no seasonal Controller location list belongs in the #230 editor.

**Acceptance/regression gates:** (1) existing Controller scan → Display/Controller wiring unchanged; (2) Controller seasonal location scan captures provenance without changing reference GPS; (3) crew online circuit creation, breaker assignment, existing waypoint selection and season planned ON/OFF; (4) durability of circuit-waypoint relationships across seasons; (5) crew denial on waypoint identity/coordinate mutation; (6) Panel source lookup at power waypoints; (7) offline cached inspection works but all reference/circuit edits are disabled, no offline edit replay. Keep those interactions visually and functionally separate from the existing wiring controls.

### Mandatory system-level acceptance

Demonstrate a complete operator trace: select a physical cable → see verified versus unknown surveyed geography, endpoints/network designation, GPX source history, LinkIQ test/retest evidence, condition and maintenance work → make scoped attributed online engineering updates → reimport FLW without losing reviewed identity/history → conflict-aware GPX round-trip in ExpertGPS → generate draw.io schematic without a second manually maintained master. Test historical failures/replacements, direct home-run versus segment distinctions, Manager protected-waypoint denial versus Production crew positive circuit/track editing, power-waypoint-to-Panel shutoff lookup, and disconnected cached view with **no edits**. Preserve the existing Setup and Field Wiring map boundaries and do not claim browser/Production acceptance from source-only tests.


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


### #171/#230 existing-map PostgreSQL + operational editor implementation — 2026-10-11 continuation

**Authorization:** Greg explicitly authorized implementation from the 18:24 CDT
checkpoint under #122 on draft PR #319. Branch remains
\`feature/171-cableiq-import-validation\`. Current-main reconnaissance was
\`2beead54e849a90596a208596c9dedaaac5290d8\`; this contained the separate
icon-publishing #360 and must not be overwritten. Source/intake checkpoint
evidence (c2b206a2 GIS_SOURCE_ACCEPTANCE_PASS, browser CLEAN EXIT/CHANGES
REQUIRED) has **not** been retested or represented as acceptance of new code.
No Production schema/DB, source GPX/FLW, movement events or Synology artwork
were modified in this continuation.

**New candidate data contract** (additive **second** SQL candidate after the
earlier site-infrastructure migration):

- \`Database/EngineeringTools/sql/171_site_reference_operations_candidate.sql\`
  adds versioned reference revision, positive independently provisioned
  Manager/Production crew editor grant, panel-level owner + crew-editable meter,
  panel-scoped circuit number and independent circuit ownership, many-to-many
  existing-waypoint circuit destinations, actual reviewed network memberships,
  seasonal planned on/off instructions **separate from observed power state**,
  and append-only attributed before/after edit log. Defaults are
  \`UNKNOWN\`/unreviewed, not inferred City or MSB ownership.
- \`ref.site_reference_snapshot()\` yields maintained EPSG:8158 waypoint and
  historical track geometry transformed to browser WGS84, only reviewed shared
  route associations, explicit reviewed physical cables and their *separately*
  identified LinkIQ UUID/results/length/test standard/date, panel circuits,
  circuit destinations, memberships, switching instructions, source hashes and
  unresolved LinkIQ count. A LinkIQ test standard is NOT a measured link speed;
  projection reports \`measured_link_speed_mbps: null\` until actual independent
  decoding/verification is implemented. Physical cable counts are never
  inferred from GPX track descriptions or overlapping routes.
- Accepted GPX binding SHA is reported separately from latest staged GPX SHA.
  Later staged GPX is not silently promoted; browser visibly warns of source
  drift. FLW SHA is labeled latest **evidence**, not accepted topology.
- \`ref.site_reference_command()\` is a narrow named-command
  \`SECURITY DEFINER\` operation. It requires explicit positive editor scope,
  nonblank evidence, an optimistic global expected revision, and records
  before/after + actor/email + time. The protected Setup HTTP API additionally
  requires the existing Cloudflare/Directus read gate; Manager coordinate/name/
  type/owner edits also require \`can_manage_setup\`. Crew circuit/link/network/
  meter/switching operations do **not** grant waypoint-position editing.
  Existing \`fieldwiring_app\` is granted EXECUTE only; no broad new table DML.
  Editor grants are **not automatically seeded from unrelated Setup roles**.
  Provision them only through reviewed acceptance/administration.

**Existing map integration** (not a competing viewer):

- \`Setup/Application/setup_site_reference_api.py\`: GET
  \`/api/setup/locate/references\`, POST
  \`/api/setup/locate/references/command\` (same-origin setup-command header,
  explicit JSON, expected revision). Uses existing psycopg2, closes the
  permissions-read transaction before switching to one guarded write
  transaction, commits or rolls back atomically. No new server DB library.
- \`Setup/Application/production_backend.py\` registers that blueprint and
  allowlists \`setup_site_reference.js\` on the existing \`/locate/assets/\`
  endpoint. The **same** \`Setup/Application/locate_preview.html\` inserts one
  script between existing map search and historical network discovery.
- \`Setup/Application/setup_site_reference.js\` loads maintained references at
  page load, rebuilds source waypoint/track/reviewed-route layers, maintains
  the existing aerial, GPS, layer toggles, map searching and existing (NOT
  visually accepted) marker/icon objects, and shows operational detail on the selected waypoint/panel/network:
  supplying breaker number and outlets, separate panel/circuit owner, meter,
  intended season switching, explicit actual network membership, reviewed
  physical cables with per-UUID LinkIQ test data, and source year. Raw GPX
  description/comment/full timestamp live in a secondary provenance section.
  Missing network/circuit/speed/ownership values are prominently
  \`Not recorded / unreviewed\`, not guessed.
- \`setup_locate_search.js\` reindexes permanent map entries after DB reload,
  retains dynamic #88 asset/search records, and replaces only curated network
  references. \`setup_locate_networks.js\` no longer replaces the network picker
  with dated \`setup_locate_networks.json\` after successful live loading.
  If the GIS DB API is absent/unavailable, existing snapshot geometry/network
  remains available **with a visible STATIC SOURCE SNAPSHOT ONLY warning and
  no editor**; this is NOT an offline guarantee or an acceptance of stale
  reference as current truth. The original static HTML is retained temporarily
  to keep current icon mapping and pre-cutover compatibility until the separate
  approved icon/source publication is reconciled. Removal of baked HTML and
  generated network JSON remains part of final cutover.
- Only GPX/reference map layers are rebuilt; #88 Container/Display runtime
  observations, home anchor and movements are not edited. No duplicate
  Workshop injection. The icon thread continues owning SVG/PNG publication,
  type mapping and non-square marker sizing, so this PR does not implement
  those changes.

**Candidate verification added:**

- \`Database/Acceptance/171_site_reference_operations_disposable_validation.sql\`:
  transaction rollback assertions for no editor grant by default, distinct
  Manager/crew rights, explicit meter identifier, circuit with multiple
  outlets, separate panel/circuit ownership, reviewed actual network membership,
  seasonal on/off data, audit revisions, stale-edit rejection, and preservation
  of the actual reviewed LinkIQ test UUID/result/length with UNKNOWN speed.
- \`Database/Acceptance/reference_data_disposable_allowlist.json\` adds the
  additive migration/validation paths **in exact order** to the existing single
  governed disposable acceptance workflow. No stand-alone dump/clone. The
  #230 table/action allowlist lists new proposed operational scopes but remains
  globally \`DESIGN_ONLY_NOT_ENFORCED\` for its other collections.
- \`Setup/Application/test_setup_site_reference_api.py\` tests GET/POST auth,
  request guard, default-deny, Manager-vs-crew distinction, evidence/expected
  revision and transaction boundary without a live DB.
- \`Database/EngineeringTools/test_reference_data_allowlist.py\` now asserts
  exact schema paths, SQL boundary and existing-map integration.
  \`.github/workflows/site-reference-tests.yml\` defines isolated PostGIS
  synthetic SQL, Python HTTP tests and Node syntax checks. Creating a workflow
  is **not evidence that GitHub has executed it**.
- Three changed JavaScript modules were independently parsed with V8
  (\`setup_site_reference.js\`, \`setup_locate_search.js\`,
  \`setup_locate_networks.js\`) and passed **syntax-only** checks on the latest
  inspected code. The new SQL, Flask tests, Node DOM/browser operation and
  live PostgreSQL admission have not yet been executed on the governed
  server; no fabricated PASS or claim of completed operator acceptance.

**Acceptance gate and known incomplete work:**

1. Refresh existing operator review checkout only when clean and fast-forward
   from this remote branch; never reset primary checkout. Apply both candidate
   migrations then both rollback-only SQL validations using the existing
   \`run_setup_disposable_browser_preview.ps1\` with GPX/FLW intake and
   regression enabled in **ONE** governed disposable clone. Source-cache reuse
   by hash avoids repeated unchanged 253 MB FLW transfers. Respect Server
   Management #73 and preview port 8898. Test positive editor grants only
   inside disposable. No Production writes.
2. Browser test the **existing** \`/setup/locate/\` map: select known waypoint,
   check 233/181 source feature conservation; create fixture panel/circuit
   relationship, link two existing fixture outlets, verify both directions,
   update crew meter, planned seasonal switching and assigned network, and
   verify missing data is explicitly missing. Manager revise a fixture point,
   reload and search new label: it must update without regenerating HTML.
   Deny crew coordinate edits; stale tabs must get conflict 409. Compare
   revised GPX export against source and perform ExpertGPS application
   save/reopen for genuine roundtrip acceptance. No actual panel wiring
   should be invented in test fixtures.
3. Remaining mandatory #171/#230 work **NOT COMPLETE**: authorized new
   waypoint/alias/track-lifecycle and physical-cable review UI, explicit
   LinkIQ test-to-cable decision UI and speed extraction where the original
   payload proves it, conflict-aware GPX reimport/edit integration and track
   roundtrip, draw.io projection acceptance, first-class production grant
   provisioning, source/HTML/icon cutover without baked static geography,
   and the versioned/offline tile/Leaflet/symbol/reference package with
   rugged-tablet airplane-mode proof. No label, circuit or switch state
   invented from names, historical track notes or LinkIQ standard.
4. No Production migration/deployment/merge approval yet. Preserve the
   candidate PR as draft until governed disposable SQL/application tests and
   operator acceptance PASS under #122.



### Icon integration remains OPEN — operator correction after #319 implementation checkpoint

Greg confirms the parallel icon thread has **not solved the Park Map icon problem**.
Do not imply that publication tooling/PNG distribution being merged, a successful
hash check for one SVG, or reuse of marker objects by #319 means map icons are
correct or accepted. The **intended Park Map format is approved Plain SVG**;
ExpertGPS uses its own locally installed PNGs; historical web PNGs are a
compatibility layer, not the target map implementation. Existing merged
\`locate_preview.html\` still consumes legacy GPX-derived
\`webassets/images/symbols/msb/*.png\` references and forces 32×32 sizing.
Thus #319's current practice of reusing those existing icon objects preserves
known behavior but **does not repair incorrect URL/type mapping, icon geometry,
image publication/case sensitivity or rectangular SVG sizing**.

Ownership and order:
- #171's parallel icon workstream must establish the actual cause, approved
  Plain SVG lookup/publication contract, correct sizing/anchors and accepted
  rendering in the existing map. Do not preempt its changes or duplicate a
  simultaneous edit to \`locate_preview.html\`.
- #319 can continue PostgreSQL, reviewed topology, protected commands, audit,
  and disposable API tests independently. Integration must later reconcile
  the shared map source with the accepted icon changes (not silently overwrite
  them), and run final combined map/search/layer regression.
- **Visual map acceptance is BLOCKED** until the operator verifies the Plain
  SVG icons on the same DB-backed existing map. Neither branch merge nor
  Production cutover may use icon test/tooling success as a substitute for
  the actual map rendering check. #122 deployment authority remains separate.


### Physical-cable/editor and offline integration milestone — 2026-10-11 later continuation

**Exact recovered integrated candidate:** two-parent merge
\`4354f5bf6ae06ef2be18cf788ddf450f4a10b6a8\` merges the already
divergent PostgreSQL editor history
\`07261a6f5bebe3a4264776a32f0547acbd6f04ce\` and the separate
existing-map Plain SVG/offline history
\`7281e418fe47f26e4c4113a55c151e1703f81f31\`.
Both commit histories are ancestors of this merge (GitHub compare each
parent to merge reports ahead/behind=0 behind). Do not reset either parent.
A concurrent Contents API update on the shared PR branch had temporarily
left the parallel offline history unreachable; this merge recovered it
**without deleting or rewriting its commits**. Future concurrent work MUST
use separate branches or Git Data commits with expected-head lease;
Contents API updates against a moving shared branch are unsafe.

**Actually implemented on draft PR #319, still not Production deployed:**

- Maintained \`ref.site_cable\` records can now be created as **distinct
  reviewed physical cable IDs** with two existing waypoint endpoint IDs,
  one separately confirmed network or explicit SPARE designation, documented
  evidence, reviewer and lifecycle. Parallel physical cables with identical
  endpoints/designation are allowed, never collapsed by a LinkIQ UUID.
- Manager-only \`manager_link_test\` binds a stable
  \`ops.linkiq_test.test_uuid\` to an existing reviewed cable only after
  selecting the retained source-specific \`ops.linkiq_intake_review\`
  \`source_sha256\`, **explicit previous cable binding**, and review
  evidence. It appends \`ops.linkiq_identity_decision\` and a concise
  \`ops.site_reference_edit_log\` revision with actor, before/after
  association; it does not clone the immutable raw LinkIQ BinRec into audit
  and never overwrites original test names/lengths/status/history. A
  mistaken earlier decision may be revised with an expected prior binding,
  preserving both decisions; unchanged reapproval is rejected.
- The existing Park Map's manager controls expose reviewed cable
  creation/revision and LinkIQ UUIDs with the corrected LinkWare display
  label **separate** from original tester name, preserved test
  timestamp/length/raw result, source hash, existing binding, and
  *review-required* state. This is human review, **not** auto-selection
  from guessed endpoints, proximity or test standard.
- Other maintained operations: manager-reviewed historical waypoint alias
  additions (reject collisions with any existing canonical label/alias),
  reviewed physical-cable retirement with evidence, and Production crew
  commands to remove a previously assigned circuit outlet, network
  membership or seasonal switching plan. All removals record before-data,
  actor/evidence/revision. Crew still cannot move/rename waypoint identities.
- The parallel source candidate contributes bounded offline preparation and
  service-worker/reference loading, local Leaflet assets and Plain-SVG
  rendering adapter on the SAME map. The merge preserves its edits and
  forces offline saved-reference permissions to \`identity:false\`,
  \`operations:false\`; cached data never confers editor access. The
  icon's real-world rendering and tablet airplane-mode workflow remain
  unaccepted, separately owned. \`/setup/locate/\` Production is unchanged.

**Real isolated GitHub Actions PASS (not just a static assertion):**
\`https://github.com/Gregovate/MSB-Production-Database-Project/actions/runs/38187654454\`
for exact merge \`4354f5bf\`. Job includes checked-in node/offline source
contract assertions, **6 protected Flask API tests PASS**, and Docker
\`postgis/postgis:16-3.5\` execution of both SQL schema candidates plus
rollback-only operations validation (reported \`PASS: #171/#230 reference
default-deny, audited commands, live map, m:n circuits, network, switching,
meter and speed-unknown\`). Candidate SQL assertions now exercise
manager-created distinct parallel cable identities, retained LinkIQ UUID
assignment, explicit correction with prior binding, two append-only decisions,
unchanged original tester name, collision-safe aliasing, reversible crew
relationships and retirement preservation. PostgreSQL container is ephemeral,
NOT current Production schema or live Server Management clone.

**Still-open acceptance / no false completion:**
governed current-Production disposable schema/real-GPX/real-FLW/browser
single-clone gate, source-cache server test, actual operator authorization
provisioning, real map live PostgreSQL and server navigation, offline rugged
tablet + aerial/icons field acceptance, ExpertGPS application roundtrip and
conflict-aware reimport, prior missing icon correction, full physical
network/route/schematic reconciliation and final #230 storage reference UI.
No SQL migration, FLW rewrite, Production import, web SVG publication, or
deployment was performed in this continuation.


### Reviewed track-label finding — October 11, 19:31 CDT

Operator identifies the GPX network track formerly labeled "NET FT-SS Reg, Spare, Aux-A, Aux-B, " as the **LP-08 to CL-00** link. The approved maintained label is **NET LP-08 to CL-00**. Existing embedded-map feature is t102, 12 vertices; generated t102 is not a PostgreSQL primary key. Confirm the accepted GPX SHA and source-track ordinal binding before any database edit.

Read-only geographic cross-check: first vertex [-87.74624455, 43.77693051] is approximately 2.90 ft from LP-08 (w88). Last vertex [-87.74701645, 43.77678431] is approximately 4.29 ft from PANEL CL-00 (w114). Preserve exact route geometry, GPX type Network, and original label including its trailing blank. Original description "TBD 7 Cables" is unverified historical source text, not accepted physical cable count or confirmed network assignments.

Candidate reviewed workflow: manager_update_track_label changes the maintained ref.site_track name with expected old name, accepted source binding, audit and optimistic revision. The same map/search reads the maintained name; GPX projection and gpx_roundtrip export a SHA-pinned, source-ordinal-checked change without overwriting the baseline or altering track geometry/description. The Manager editor is a generic reviewed function, not a special-case HTML rename. Export files still require ExpertGPS application acceptance and governed Production deployment.

**No Production or shared GPX mutation has been made; the reviewed correction is documented on #171 and not yet saved to a live accepted PostgreSQL track.**

### LinkIQ versus reviewed GPX route cross-check — operator decision

PostgreSQL remains the one place to edit maintained waypoint, network,
physical-cable and surveyed-track associations. GPX and FLW remain distinct,
preserved evidence inputs. On each LinkIQ intake, compare resolved test
endpoint candidates with the *reviewed physical cable*, then compare the
reviewed cable's ordered route segments and accepted GPX track associations.
Record agreement, uncertain/unassociated evidence, or a discrepancy for
attributed review. Never auto-rename geometry, rewrite FLW, or update a
reviewed cable because strings differ. One route can carry multiple cables,
and retests/project copies are not new physical cables; partial routes may
lack end-to-end coverage. Test length need not equal surveyed route distance.

Existing linkiq_intake.py flags some source-vs-reviewed-cable disagreements.
The second cable-vs-reviewed-GPX-route validation and visible map exception
workflow remain unimplemented. Acceptance needs mismatched endpoint, broken
route, missing association, parallel cables, and later changed test evidence.


## October 23 — #378 PC intake consumer contract (integration specification)

Owner: #378 PC interaction, under #122; #319 owns schema, migration, capture/
comparison/reconciliation backend and integrated acceptance. Coordinate #171
workstation/source controls, #230 reference maintenance and #428 track history.
This section defines required consumer behavior, not implemented HTTP endpoints.
Inspected #378 head 3b58fbf936536cc38da57f05651adca1ff6dab2d and #319 head
fcdc7e53b9d2aa30cad8b52ba4e505ce3f26063a against main
e3590c264da048bdd8ffb5f368fd3f928e15d71a. No independent deployment.

### Two operator entry points in the existing GIS Manager

**Master GPX reference intake:** Select revision -> Capture -> explicitly Compare
-> Review changes and dependencies -> Resolve/defer -> Review final summary ->
explicitly Approve/Finish -> show durable result. Selection alone never imports
or approves. Display accepted source, captured incoming source and maintained
database revision together. Backend supplies three-way categories/counts, exact
old/new field values, permanent identities, aliases/conflicts and impacts.
Missing features remain retained pending explicit reviewed disposition.
Show map labels separately from GPS names; preserve source styles/extensions
and #428 original/current/proposed geometry and source-point lineage.
Changing the selected file starts a new capture, never replaces an open review.

**LinkIQ FLW operational intake:** Select read-only source -> Capture -> explicitly
Compare evidence -> inspect new/changed/unchanged appearances and dated retests
-> review associations to existing reference/cable identities -> explicit
approval of supported evidence/association actions -> show durable result.
Test UUID identifies test evidence, not cable identity. Show each original
tester result/time separately from corrected display name, source appearance/
project and current reviewed association. Same-name later tests remain separate
dated evidence; duplicate project appearances of a UUID are not new cables.
Changed original payload for an existing UUID is a backend conflict to review,
never an overwrite. Deleted source appearances do not erase historical evidence.
No FLW writeback, guessed cable creation, automatic endpoint association,
reference geometry change or latest-result overwrite is an intake side effect.

### Required backend boundary; wire names/routes require #319 implementation

Use the existing protected application/API and Directus authority. Do not create
a desktop role store, database connection, embedded service credential, trusted
actor-email header or new import service. The existing read-only network-catalog
SSH helper is not authority for writes. #319 must define the supported desktop
authentication/session handoff and CSRF behavior before network mutation wiring.
A logged-in Windows account or successful source capture never confers approval.

The following are semantic operations, not invented live route paths:

| Operation | PC supplies | Backend returns/owns |
| --- | --- | --- |
| Capture selected source | Kind GPX/FLW, immutable byte stream and source metadata | Source identity/hash/size, capture receipt/time, verification status |
| Open comparison | Captured source identity; explicit operator request | Accepted baseline, coherent maintained revision, persisted review identity/revision and existing comparator output |
| Read review | Review identity; paging/filter cursor | Complete counts, stable item identities, before/after/evidence, conflicts, dependency completeness and affected identities |
| Record decision | Review/item identity, expected review revision, supported action and evidence | Validated saved decision, new revision, remaining conflicts and invalidated approval |
| Request final summary | Review identity and expected revision | Frozen decisions/preview hash, source/baseline/database bindings, impact completeness, server permissions and blockers |
| Approve/Finish | Explicit confirmation of exact returned bindings/hash and idempotency identity | Transactional result/receipt or stale/denied/blocked response; no client-side apply |
| Reopen/status/cancel/defer | Existing review/operation identity and expected revision as required | Durable status/history; no maintained-reference change for cancel/defer |

The server owns accepted-baseline selection; latest upload/stage is not a
baseline. Capture must verify bytes and reject unstable/inconsistent reads.
Reuse existing #319 preservation/parser/source-ledger implementation; do not
copy parsers or compare logic into #378. Large FLW transfer must use the existing
approved transport with visible progress/cancel and content-addressed reuse;
do not upload unchanged large files repeatedly or invent a second cache service.

Minimum review envelope: source kind and immutable identity/hash, accepted
baseline identity/hash (or explicit initial-intake status), maintained revision,
review identity/revision, preview hash, comparison schema version, current
permissions, counts, paginated items, conflicts, dependency status/impacts,
allowed decisions, blocking reasons and durable result/status when applicable.
Backend field names and serialization must be published/tested by #319 before
the adapter is connected; these names describe semantics rather than a new
schema. A missing/null dependency result displays **Not evaluated**, never zero.
Zero impact is only valid when the backend explicitly reports analysis complete.
Paging/filtering must not hide unresolved items from the final approval gate.

### Desktop state and failure behavior

States: No source selected; Capturing; Captured; Comparing; Review required;
Blocked; Ready for explicit approval; Applying; Result verified; Deferred;
Cancelled; Unavailable. Status wording must distinguish staged evidence, accepted
source, applied maintained change and consumer validation; never call capture
or bootstrap completion recurring synchronization acceptance.

Disable Finish unless backend capability exists, authentication is current,
all decision/source/baseline/database bindings are current, required conflicts
are resolved, dependency analysis is complete and server says approval allowed.
Changing decisions, selected capture, baseline or maintained revision invalidates
the displayed approval. Server repeats every guard transactionally. On stale
response retain operator work for review and require fresh comparison; never
resubmit changed data automatically. On timeout after Finish display outcome
unknown and query the same operation identity; no new blind apply request.
Offline/cached views are labelled historical/read-only and cannot queue edits.
Reconnection requires fresh authentication and review state, not cached grants.
Cancel does not erase source evidence, audit or completed transactions.

Preserve existing symbol-library distribution, host-specific shared-drive paths,
ExpertGPS profile/type/reverse mapping, approved 2019 aerial/calibration,
Garmin observations, per-PC backups and saved track drafts. Intake is a new
workflow inside the same Manager, not permission to repair workstation settings
or overwrite the shared master. Existing two-local-file GPX comparison is only
a local inspection utility; its name-based diff cannot populate this review or
be treated as accepted source/database reconciliation.

### Single integrated acceptance and current blockers

Use the #319 integrated GIS/circuit/FieldWiring candidate and existing single
disposable clone/review path. No independent #378 Production release.
Acceptance must include: source edited after capture; server baseline differing
from latest upload; database change after comparison; unknown dependency
analysis; rename/alias ambiguity; missing feature retention; track replacement
with history; same-name dated FLW retests; repeated UUID/project appearances;
changed payload conflicts; corrected display name with original result intact;
association correction with prior binding; authorization revocation; offline
denial; timeout/status recovery; both PC workflows reopening durable reviews.
Verify affected map/picker/circuit/FieldWiring identities after approval and
preserve the existing workstation controls in regression.

Current #319 API offers reference snapshot and named maintenance commands,
not the lifecycle above. Current comparator returns no-write/not-ready output.
Persisted capture/review/decision/apply APIs, dependency analysis, desktop
authenticated transport and integrated Windows/operator acceptance therefore
remain OPEN. No endpoint, approval or release capability is claimed by this
specification. #378 UI implementation must consume the agreed #319 contract;
do not work around missing backend capabilities with local reconciliation.
