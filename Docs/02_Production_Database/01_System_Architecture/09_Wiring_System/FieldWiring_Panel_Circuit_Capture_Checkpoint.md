# FieldWiring panel circuit capture — implementation checkpoint

| Document control | Value |
|---|---|
| Status | SOURCE CANDIDATE — live catalog received; integrated release acceptance pending |
| Owner | #171 / #230 under #122 |
| Reviewed | 2026-10-22 |

## October 23 panel-diagram candidate — supersedes V0.4.8

V0.4.8 operator review is CHANGES REQUIRED. V0.4.9-panel-diagram remains in #319:
compact same-side spanning breakers, circuit-click waypoint assignments, existing
controller inventory linked to network-box placement and independent outlet plugs.
The two association tables preserve retired rows and audit history; controller IDs
and catalogs are reused. Power-only waypoints expose circuit/plug controls without
network-box fields. A5 is disposable validation evidence, not a Production seed.

Main baseline remains e3590c264da048bdd8ffb5f368fd3f928e15d71a; parent candidate
1197f4f19fc32d61ebae5e6db5db7cbef3c919ad. Design commits precede implementation.
Exact published SHA and CI results belong in #319 before the unchanged cached-path
preview handoff is enabled. Current-clone/operator acceptance and Production remain
open. No new importer, inventory service, workflow or test procedure is introduced.

Local validation: FieldWiring 220 PASS; Setup 901 PASS; source/allowlist 44 PASS
and one real-PostGIS test reserved for existing CI; PGlite 130 command/denial checks
PASS. Actual Chromium page PASS includes 18 two-pole A5 blocks (nine each side),
200 A fixture main, per-leg waypoint assignment, retained IDs/exact retry, Power
outlet controller connection, two Combo inventory installations, light/dark, mobile
width and read-only policy. No Production connection was used for these checks.
The browser runtime was installed only in the engineering environment; operator
PC prerequisites and the existing PowerShell preview procedure are unchanged.

## October 23 integrated continuation (supersedes branch/gap status below)

Work is integrated in existing PR #319, `feature/171-cableiq-import-validation`;
there is one GIS/power schema candidate and one reusable disposable preview.
V0.4.8-breaker-schedule implements the operator's combined breaker entry, whole
amps, show/restoration state, same-breaker multiple outlets, exclusive OUT-Combo
supply, panel meter/remote-main relationship and separate waypoint equipment view.
The [controlled design](FieldWiring_Panel_Circuit_Design.md) records the command
contract and tests; the [candidate SOP](operatorSOP/Panel_Circuit_Capture.md) matches
this workflow. Earlier branch/gap and test entries below are historical evidence.

Current-clone/operator review and Production approval remain open. The supplied
CLEAN EXIT confirms port/source-lock release only. Recurring GPX review/apply and
PC ingestion contracts retain their existing #319/#378 ownership and open gates.

## Controlling requirements

Use [Site Infrastructure / GIS](../11_Site_Infrastructure_GIS/README.md), particularly
Required panel, circuit and seasonal power records, October 10 editing ownership,
and OUT-Combo assignments. The October 22 request activates implementation of the
previously deferred panel detail workflow in the existing FieldWiring application.
Production Crew may identify/correct circuits and assign existing waypoints;
Managers retain waypoint identity/coordinate maintenance. Directus remains role
authority. The separate GIS thread owns approved Master GPX synchronization.

## Verified source state

Current main inspected: `e3590c264da048bdd8ffb5f368fd3f928e15d71a`.
FieldWiring backend is `V0.4.2-controller-uid-explorer`; its routes provide wiring,
Controller Inventory and Controller commands, but no panel circuit capture API/page.
This is repository evidence, not a fresh verification of installed Production.

[Existing draft PR #319](https://github.com/Gregovate/MSB-Production-Database-Project/pull/319)
head inspected: `bbbdf25ff6f6b0294eef845ad24f1fafea37d7c6`, branch
`feature/171-cableiq-import-validation`. It is open/unmerged and explicitly lacks
current accepted Production-clone/editor acceptance. Do not merge that stale branch
wholesale or assume its schema is installed.

The draft's `Database/EngineeringTools/sql/171_site_infrastructure_schema_candidate.sql`
defines stable `ref.site_waypoint` / `site_waypoint_alias` identities. Its
`171_site_reference_operations_candidate.sql` proposes `site_panel`,
`site_power_circuit`, `site_circuit_destination`, `site_waypoint_network`, revision
and audit records. These are reuse candidates, not verified live contracts.

## Gaps that must be reconciled

- Draft authorization uses independent email-based `ref.site_editor_grant` records.
  Its Setup HTTP adapter adds a Directus read check, but SQL commands rely on that
  separate grant. Circuit capture must use current Directus authorization in the
  governed command path and preserve authenticated actor attribution. Do not copy
  the grant table as an independent role authority.
- Draft panel identity requires an existing waypoint; verify how permanent panels
  with unknown location are captured without fabricated waypoint or coordinates.
- Draft owner enum only permits UNKNOWN/MSB/CITY. Required responsible utility
  information, including Alliant, is not represented by that enumeration.
- Draft meter field is one text value; it does not establish meter-to-panel
  cardinality. Do not assume one unique meter per panel.
- Draft circuit/destination evidence lacks the full explicit verification/conflict
  contract and intermediate fuse/disconnect/feed relationships.
- Draft seasonal switching records contain instruction text by year. They do not
  implement separate structured show/off-season desired states, reported condition,
  field-verified condition, utility request versus completion, or Setup-owned
  seasonal activity evidence.
- Reuse many-to-many circuit destinations and independent network memberships.
  Search current labels and retained accepted aliases; selection stores stable IDs.
  Renaming a waypoint must not break relationships or change circuit identity.

## Live inventory received and implementation continuation

The operator supplied the complete read-only inventory from `msb`, captured
2026-10-22T23:45:38.139501-05:00: PostgreSQL 16.9/PostGIS 3.5.2; only `ref.season`
and `ref.site_network` among the queried relations; the three existing Directus
capability/actor functions returned. No waypoint/panel/circuit tables were present.
This resolves the initial catalog prerequisite, without establishing GPX data or
an installed circuit editor. The original [inventory query](Queries/02_Panel_Circuit_Schema_Inventory.sql)
is retained for repeatable comparison.

[Panel Circuit Design](FieldWiring_Panel_Circuit_Design.md) now controls the source
candidate. Existing FieldWiring hosts `/circuits` and guarded `/api/power` routes.
The candidate migration requires #319's waypoint/alias foundation. It replaces
the uninstalled draft POWER definitions, not the source synchronization work.
The two migration paths must be reconciled before combined disposable/Production
release; do not apply both proposed power schemas.

Continue on `engineering/171-230-circuit-capture`. Refreshed #319 head during this
implementation: `ac7b6933af9acb2f97d91012e7385948cca83a75`, now reconciled with
main by that owning thread; its recurring source promotion remains incomplete.

Required subsequent acceptance: real PostgreSQL command/authorization and audit
regression, concurrent correction protection, multiple destinations and networks,
unknown/conflicting feeds, seasonal state separation, current-clone browser
preview, and crew/Manager permission tests. A saved state or completed task never
proves physical de-energization. Production release requires separate accepted
candidate and governing Server Management procedure/authorization.

## Related documents

- [Wiring System](README.md)
- [FieldWiring Application](../../../../FieldWiring/Application/README.md)
- [Reference-data issue #230](https://github.com/Gregovate/MSB-Production-Database-Project/issues/230)

## Source acceptance — October 22 candidate

- Shared FieldWiring/Procedures: **274 passed**, including 11 new transport/atomicity checks.
- Isolated PGlite PostgreSQL: **43 command/denial checks passed**, plus snapshot,
  audit, seasonal separation, prerequisite, replay and transaction rollback assertions.
  This uses synthetic waypoint/Directus fixtures and actual repository capability/
  actor SQL; it is not a PostgreSQL 16 current-Production-clone acceptance run.
- Actual Chromium page: panel/circuit creation, retained-alias search, multiple
  waypoint selection, assignment retirement, two networks on one waypoint,
  utility request without fabricated confirmation, retry after committed save/lost
  confirmation, read-only user and 390px mobile width passed. Mobile screenshot
  inspected; no horizontal overflow. This is local fixture browser acceptance,
  not protected Production or real crew/operator acceptance.
- SQL syntax, JavaScript syntax, affected documentation links and diff whitespace
  checks passed. Existing CI FieldWiring job now runs the new isolated checks;
  remote CI status must be recorded separately.

**Still open:** combine the approved #319 waypoint/source foundation with the
single power schema and update its old map/operations power consumers; current
PostgreSQL 16 Production-clone migration/grant checks; protected role and operator
review; release approval; governed migration/source deployment; live field check.
No schema migration has been run on Production, no GPX source was changed, and
no issue is closed. No operator deployment command is ready yet.


## October 24 operator simplification integrated with #319 grouped breaker

This candidate reuses #319's permanent breaker/pole/circuit design; #454's older circuit-owned breaker schema is **not** an additional install step. Field entry uses existing identity selectors and dropdowns for amp rating, pole count, equipment owner, and equipment category. Routine site-reference records and controller/waypoint assignments require no manually selected verification or free-form evidence; a blank optional note is valid and saves as UNVERIFIED. Security-definer command attribution, revision/audit trail, role restrictions and append-only seasonal work observations remain authoritative. Only observed work evidence retains its mandatory description; blank reference notes are not fabricated.

**Combo is a power-plus-network capability**, not a physical-box class. The existing `ref.site_waypoint.waypoint_type` is structured source classification: controller installation and supplied-power eligibility recognize an independent `combo` type token on OUT-Combo boxes or Combo poles. They never inspect the human waypoint name. Actual production waypoint type labels are a field validation gate; unrecognized classifications must remain unselectable instead of guessing.

Electronic equipment types include DIN power supply, Ethernet switch, PoE switch, extender, splitter and RS485 repeater as separate typed options, without creating inventory records from example purchase links. Actual network/electrical details remain optional until observed.

Source commits on PR319 incorporate the #454 low-friction improvements and isolated regression cases. **Do not deploy #454's older power DDL alongside the #319 canonical migration.** Operator disposable/browser acceptance, current main currency, source lock/review ownership and governed deployment are separate pending gates; passing GitHub CI is not permission to mutate Production.


## October 24 integrated engineering gate — exact source CI

The canonical grouped-breaker #319 branch incorporates the tested low-friction editing correction from draft #454, but **not #454's competing older DDL**. Exact application/SQL/test candidate `75a9bc204be983eac8c0879cc2c7eaa0177356e6` completed all seven GitHub checks **SUCCESS**: FieldWiring full (includes isolated PGlite and Chromium), Setup full, Windows transport, safety, Engineering Compliance and both candidate checks. These checks prove source/fixture behavior, not current-Production-clone or operator acceptance.

The final source fixes:
- regular reference saves succeed without mandatory typed evidence or manual verification;
- stored status defaults to UNVERIFIED; a routine change to a previously verified reference demotes it to UNVERIFIED instead of falsely inheriting old verification;
- audit saves the original command payload so a lost-response retry is exactly idempotent, even when the database supplies defaults;
- breaker rating/pole count and equipment owner/kind are curated dropdowns, while existing nonstandard ratings and owner names remain selectable to avoid accidental loss;
- empty notes are not synthesized into fake field evidence; real seasonal events continue requiring an observation;
- controller placement and power paths use Combo capability from the structured waypoint type, including Combo light poles, never from human display-name substrings;
- new-record forms hide the irrelevant retirement checkbox. Existing records retain governed retirement and audit controls.

No current-Production clone, browser/physical operator acceptance, PR merge, migration or live server/source publication has occurred. The previously recorded GIS source lock must be owner-verified before any new review. Release gate: exact #319 source identity, existing disposable runner/port ownership, current PG16+PostGIS clone, protected Crew/Manager behavior and operator acceptance, then separate authorized #37 Production boundary. Retain #454 draft as reconciliation evidence, but never install its old power migration with this canonical candidate.


## October 24 follow-up: operator feedback corrections to previous browser candidate

The operator rejected another source-only handoff because it had omitted changes already requested from the previous on-screen review. Source engineering continues within the **existing #319 grouped-breaker candidate**, not a new deployment, separate schema or duplicate app.

Actual operator requests and current candidate response:

- **Panel:** optional installation year (4-digit whole-year, unknown blank), selected owner **City Owned / MSB Owned** (retained legacy values remain selectable). Panel meter remains panel-owned.
- **Circuit picker:** use structured power-capable waypoint classification; hide Panel/Stage and other non-endpoint types from ordinary assignment, while retaining already-recorded exceptional legacy assignments for reconciliation. Combo means both power and network and can apply to either a box or a light pole, not a name-substring test.
- **Grouped 2-pole breaker:** offer explicit **also add selected waypoint(s) to the other leg**, default OFF. Preserve the other leg's unrelated waypoints and distinct permanent circuit identities. Never parse a location name as verified physical wiring. Different endpoints per leg remain supported.
- **Waypoint/equipment navigation:** a direct **Open waypoint / equipment** control next to recorded circuit destinations expands the correct existing section and selects that waypoint without forcing a search below the panel board.
- **Add new equipment:** a visible action at the selected Combo location is separate from **Install existing controller**. Use the existing `ref.site_power_device` identities and category choices for DIN power supplies, industrial Ethernet/PoE switches, VDSL extenders, RJ45 splitters and RS485 repeaters. Model selections are dropdowns of supplied example models and retained records; selecting one supplies the category automatically. These are catalog choices, not fabricated installed stock. Physical instance IDs are database-generated. A free-text description is optional Notes.
- **Routine save:** no mandatory verification or evidence text, and no fictitious auto-generated evidence. Existing role, append-only audit, safe idempotent retry, season event verification boundaries and restored current power references remain authoritative.

Mandatory stable identities such as a new panel designation and meter identifier still require factual operator input; the general target remains dropdown-based selection plus optional notes rather than redundant free-form fields. Equipment catalogs can evolve through a later governed reference editor, not a new parallel ownership system.

As of this checkpoint, source changes and browser regression tests have been committed on #319. **This is engineering source, not accepted Production review.** Exact-head GitHub CI completion, current-Production PostgreSQL 16 disposable validation, protected operator acceptance, and #37 authorized release are separate gates. Never launch an overlapping preview while source-lock ownership is unresolved.

## New-thread handoff — final integrated design / October 24, 2026

**Authoritative design:** [FieldWiring_Panel_Circuit_Design.md](FieldWiring_Panel_Circuit_Design.md), heading **Final integrated system design — October 24, 2026**. Follow the controlling section rather than earlier abandoned assumptions about network ownership or Crew network editing.

**One project model, seven required capabilities:** Controller assignment to physically eligible waypoint; true network availability by reviewed GIS route at waypoint; surveyed power/network tracks; FLW LinkIQ cable tests between same permanent waypoint endpoints; Display→Controller→actual circuit demand versus branch breaker capacity; panel/meter/owner/position and source-aware waypoint safety; panel-level versus breaker-level show/off-season planned/actual states. These relationships are cumulative; do not replace existing identifiers/audits with new catalogs.

**Authority:** LOR sets Controller→network and Display→Controller; GPX/GIS reviewed trace/waypoint endpoints define network physical availability and power/network route; FLW is measured link evidence, not route geometry; Controller location/circuit plug associations are Crew-capturable subject to required LOR network availability; Crew **cannot edit networks or GIS traces**. Normal GIS/FieldWiring projection is read-only for network membership. Combo means both power and network facilities, not a specific network.

**Current code status:** #319 remains open with source changes to panel/branch breaker/editor/Combo and optional notes. Earlier exact SHA `f3588c27999333eb8c0be9546cfd72a27556973c` passed 7 GitHub CI checks, but **predates this final integrated design**. Latest checkpoint SHA must be refreshed and checked; don't quote the prior SHA as acceptance for new requirements. Draft #454 has an older incompatible power migration — never deploy both. The final Controller network availability gate, derived circuit amperage rollup, separate panel off-season supply state, safety projection, and network editor/API write denial are **not yet accepted as implemented**. Need reconcile current application and schemas, then implement and test.
 
**Operator preview cleanup receipt:**
```text
Setup REUSABLE DISPOSABLE BROWSER PREVIEW: CLEAN EXIT
PASS: preview port and GIS source lock are available.
Connection to 192.168.5.9 closed.
PASS: preview exited; port and GIS source lock available.
```
Interpretation: disposable browser preview teardown and postflight resource release PASS; **feature acceptance not granted** and no Production deployment. No remote report path shown. Another review requires fresh port/lock ownership check. The operator had identified CHANGES REQUIRED while reviewing.

**Next thread engineering order:** refresh main/#319/#171/#230/#122 and current Server Management runbooks; inventory installed/pending LOR Controller-network/Display load/circuit mappings and GIS source/FLW IDs; resolve schema joins and source-of-truth boundaries; update controlled design before new migrations; implement network availability restriction + deny Crew network-write UI/API, per-leg capacity rollup, panel-level seasonal state/safety and comprehensive tests; run exact-head GitHub checks; prepare and execute only existing disposable PG16/PostGIS/port8898 protected browser review after an actual preflight; retain report; coordinate release under #122/#37. No new parallel app, runtime, mailer, waypoint authority or duplicate migration. No operator technical design or repeated approval request; only request a bounded test or actual release authorization at its proper gate.


## October 24 integrated implementation continuation

Continued existing #319 from e97ab34, with design reconciliation committed first as a2a4347c24d8bb530d97734e3536486038dae131. Main baseline e3590c264da048bdd8ffb5f368fd3f928e15d71a remains contained. Candidate versions: FieldWiring **V0.4.10-integrated-power**, Setup **V0.3.91-integrated-power**.

Implemented in the same uninstalled power migration: derived reviewed route availability, stable-ID LOR prop/subprop requirement corroboration, database Controller placement denial for missing/stale/conflicting sources, read-only physical Display load lineage and per-pole recorded-current subtotal, independent panel plans and panel-targeted existing seasonal activities. Snapshot joins retained FLW UUID/provenance to the same cable endpoints. Waypoint safety follows stored feeds and upstream panels, shows planned targets separately from timestamped field/utility evidence, and never certifies isolation. GIS and FieldWiring use the same availability projection; Crew network assignment/removal controls are removed and the SQL network command is denied even for replay. Existing source bytes/geometry, inventory identities and history remain unchanged.

**Known evidence limits:** recorded Display amps have no verified branch voltage/basis/estimate flag or controller self-load. Rollup is always INCOMPLETE until the owning sources establish these facts; ambiguous multi-controller loads are excluded and listed. Absence of reviewed route provenance intentionally holds placement. E1.31/DMX physical partition remains unresolved by existing LOR Controller inventory and cannot be guessed into eligibility. Existing installation history remains visible when later source changes make it ineligible.

Validation uses existing FieldWiring/Setup suites, expanded PGlite command/denial cases, expanded existing browser script, and the existing PostGIS rollback validation. No new runner, clone sequence, infrastructure service or migration path. Local Chromium launch was blocked by environment socket restrictions; local browser success is NOT claimed. Exact published SHA/CI results are recorded on #319; current Production-clone and protected operator acceptance remain pending.

Browser preparation reuses `Setup/Acceptance/run_setup_disposable_browser_preview.ps1` with the existing three migration paths and two validation paths, port **8898**, original cached GPX/FLW sources, and ExpectedVersion **V0.3.91-integrated-power**. Select the exact final #319 SHA only after its CI passes. The launcher must recheck port/source-lock ownership; the earlier CLEAN EXIT is not a current preflight. Do not run #454's competing power migration. Production remains unchanged; separate #37 release gate still applies.

## October 24 deployment feedback continuation

Operator requirements add focused Panel Circuits, shared Controller Inventory waypoint editing, separate Combo Equipment, and read-only endpoint-pair FLW history. Design recorded first in 0a0baae1; those application changes are still pending. The further cardinality correction is implemented in the existing power command guard: every waypoint permits multiple legs of one breaker but rejects different breakers, including equipment feed paths. Assignment selection marks competing supplies unavailable and retains retirement history. FieldWiring version V0.4.11-waypoint-breaker. Local SQL regression: 193 checks; FieldWiring Python: 220 passed. Production and GIS source files were not accessed or modified. This is an engineering checkpoint, not a replacement browser-ready candidate or feature acceptance. Complete focused screens and exact-head CI before updating the governed disposable handoff.

### Explicit circuit continuation acceptance cases

The design now explicitly describes single-pole and two-pole continuation: both circuits of one two-pole breaker may reach the same waypoint and extend independently to additional waypoints; a single-pole circuit may likewise extend. Every reached waypoint remains exclusive to that supplying breaker. Existing recursive enforcement already supports this; no schema change was needed for this clarification. Expanded existing regression verifies two-pole continuation retains both circuit IDs, single-pole continuation retains its circuit ID, and competing direct/indirect feeds are rejected in both directions. Isolated SQL regression: 203 checks PASS. Browser feature acceptance and remaining focused deployment screens remain pending.

## October 24 deployment screen implementation

FieldWiring V0.4.12-deployment-connections implements focused Panel Circuits, Waypoint Connections, Combo Equipment and Cable Test History routes on the existing host/snapshot/command layer. Controller Inventory now displays and edits the same installation and power-connection rows; moves retire prior rows and create replacements in one existing revision-checked transaction, with exact request replay after an uncertain response. Network-only placement uses the same LOR/GIS gate as Combo placement. Deployment selectors use structured capability types. FLW history groups by stable endpoint pair then physical cable, preserves retests and unresolved bindings, and is read-only. No new tables, migration mechanism or source-file edits. Operator SOP updated. Exact-head regression and disposable candidate preparation are in progress; feature acceptance remains pending.

Deployment regression evidence: local FieldWiring 220 passed; Setup/application-preview 902 passed; source 87 passed/2 skipped; isolated PGlite 207 checks passed. Candidate d33b5705 passed the existing actual Chromium workflow (including shared-record edits, exact replay, stale denial and endpoint-pair history) and real PostGIS/source and release-tooling workflows. Final route isolation follow-up keeps breaker assignment dialogs on Panel Circuits, with waypoint links opening that route. Exact final SHA and CI results belong to the existing #319 handoff comment. Production-clone and protected operator feature acceptance remain pending; no preview was launched here.

## October 24 review follow-up: FE-00 feeder and FLW source pairs

Screenshots confirm the panel inventory/waypoint assignment and outlet choices work. Remaining review corrections implemented as FieldWiring V0.4.13-feeders-flw-pairs: source-declared endpoint labels/designations from the existing LinkIQ intake parser/proposals are visible before physical cable review; remote panels can record their known upstream panel with a nullable feeder breaker; matching panel-prefix waypoint choices sort first, while powered poles and other exceptions remain available. Empty circuit waypoint assignments remain valid for undiscovered/non-show lighting. Existing site_panel is extended, not replaced; no duplicate source parser or physical-cable authority is introduced. Active upstream consistency/cycle protection and unknown-isolation warnings remain. Operator feature acceptance is pending; the current browser review is not assumed closed. Prepare a replacement candidate only after its engineering gates pass; do not disturb port 8898 or the source lock.

## October 24 bounded deployment release scope

Greg directs proceeding with panels, breakers, meters, waypoint assignments **and Controller network placement and actual outlet/circuit assignments** so panel inventory can precede field deployment. The cleaned current master is the initial source; preserve its bytes, provenance and permanent waypoint identities. Later corrections must preserve existing panel/controller relationships. Do not require the later GPX synchronization interface before this release. This supersedes the earlier all-capabilities acceptance requirement only for the explicitly deferred work, not the shared schema or authorization boundaries.

Operator PASS: panel, breaker, waypoint assignment and existing Combo equipment screens on V0.4.13. Controller assignment remains incomplete operator acceptance. Existing model/instance inventory enhancement, failed component replacement and future 24 mm labels, cable-history simplification and direction-independent retest presentation, and GPX ingest/reconciliation workflow remain deferred. The current master is accepted for starting inventory; it does not certify all database geometry or reviewed network routes. No bypass of the LOR/GIS placement gate is authorized.

Controller empty selectors must explain the actual prerequisite from the existing snapshot: unresolved current LOR requirement versus confirmed network with no eligible reviewed route. An outlet with no active recorded supply must explicitly say so and link to Panel Circuits for assignment. Preserve two-pole selection and never choose a circuit from a similar name. Add no records from guesses or browser tests. Inventory may be recorded UNVERIFIED before technicians confirm physical associations.

Use the same canonical migration chain and application host, without competing tables or a new deployment runner. Deferred workflows are not declared accepted merely because their schema/read-only views are shared dependencies. Before Production: exact candidate checks, targeted Controller browser acceptance, current source import/reconciliation evidence, current live checkout preflight and the Server Management database-changing release procedure. No Production deployment has occurred.

### Controller selector prerequisite correction

The existing Controller screen now distinguishes unresolved current LOR programming from a confirmed network without eligible reviewed GIS paths. An outlet with no active recorded circuit displays that fact and links to the existing Panel Circuits editor. This is a presentation correction, not a relaxation of the database gate; V0.4.13 is retained per release identity policy. Existing browser regression now covers both missing-network prerequisites and an unassigned outlet. Local FieldWiring Python 220 passed; isolated PGlite 218 checks passed. Local Chromium could not start (SIGABRT in the restricted runtime); actual Chromium CI remains required. No current-clone data diagnosis, Production deployment, or full Controller operator acceptance is claimed.

## October 24 FLW authority correction — controlling release decision

Greg establishes LinkWare/FLW as physical cable, endpoint and network authority; GPX supplies cable-run geometry only. This supersedes the earlier requirement for reviewed GIS paths before Controller placement. Derive network membership at BOTH uniquely resolved endpoints from existing immutable FLW intake proposals/tests; normalize REG and AUX letter spellings (Aux E / AUX-E) against the existing network catalog. Do not permit Crew network editing or infer connections from waypoint prefixes. Multiple networks may belong to one waypoint. Retain current LOR programming validation and Network/Combo capability checks.

Cable retests group by unordered permanent endpoint pair and normalized network/designation, with recorded physical cable identity separating replacements. Newer reliable tester timestamps win regardless of age; never fall back to an older pass after a newer failure. Preserve known unset tester dates (2/10/1970) and other invalid/missing dates as raw evidence. Without reliable ordering, mark chronology uncertain instead of treating import order or UUID as physical test order. Such uncertainty does not erase endpoint/network evidence. Display test result separately from membership; a past test is not today's live-link proof.

This release reads existing imported records only. No test UPDATE/DELETE, new intake workflow, invented cable binding, duplicate inventory or GPX rewrite. Future incremental FLW ingestion and expanded cable-history presentation are deferred. Controller field acceptance is still required. Operator reports the latest preview CLEAN EXIT with port 8898 and source lock available; next launch must recheck them.

### FLW network implementation checkpoint

FieldWiring V0.4.14-flw-networks replaces the GIS-route prerequisite with FLW-derived endpoint/network membership in the existing site_network_availability projection. Geometry evidence remains separately queryable. Normalized Aux E/AUX-E joins to the existing catalog; both uniquely resolved endpoints participate, and conflicting/deleted source proposals are withheld. Existing LOR/UID checks, typed Network/Combo placement, command audit and shared Controller/Waypoint records remain. No imported test/source rows are modified. Read-only per-cable chronology groups reverse endpoint pairs, selects newest reliable timestamps without an age cutoff, retains newer failures, and marks 1970/missing dates and tied latest times uncertain. Known retired/replaced cable instances do not supply current membership.

Local validation: FieldWiring 220 tests, FLW intake 20 tests, isolated PGlite 219 SQL checks PASS. Exact-head real PostGIS and Chromium checks pending at commit preparation. No new ingestion interface, Production mutation, or operator acceptance claimed.

## October 24 panel endpoints and LOR topology clarification

Greg confirms all panel locations have network facilities, including RA-00 and CL-00. SW and PO are network distribution boxes without power. A GPX waypoint type that lacks Network/Combo must not hide an endpoint established by FLW; use the existing FLW network-membership projection for Controller placement on both screens and at the database boundary. Keep actual outlet power separate: network capability does not establish a power outlet. Specific Controller placement still requires its LOR network to match FLW evidence; do not assign every network to every panel.

LOR topology requirement: branching from one waypoint to two different waypoints uses a LOR repeater at that distribution point. Controllers on a branch are daisy-chained controller-to-controller. Record the end as a terminating resistor, or a return cable to the originating point that continues toward the next waypoint. A return-to-origin continuation must not be represented as an assumed closed electrical ring. Do not manufacture installed repeater inventory or verified branch/termination facts from graph degree alone. Existing RS485_REPEATER equipment classification remains the inventory owner.

The four Racing Arch Controllers are reported from memory as a waypoint-fed controller chain ending there; this is UNVERIFIED field evidence, including the actual termination. The current controller_installation record captures the network attachment waypoint, not Controller predecessor/successor order or branch termination. These are additional topology requirements, not capabilities already implemented or tested. Preserve them for the existing model's topology extension; do not claim complete topology capture from the endpoint fix.

### Endpoint authority and equipment expectations — final clarification

Every uniquely resolved FLW endpoint carrying the required network is eligible regardless of GPX waypoint type. No Panel, SW, PO or other name-based exceptions are needed. Power outlet eligibility remains a separate fact. The waypoint projection exposes FLW-derived network capability so Controller Inventory and Waypoint Connections use the same rule as the command guard. An attachment waypoint may be the origin of a Controller daisy chain; assigning it does not assert a direct cable from each Controller to that waypoint or record chain order.

At INET/E1.31 distribution points, prompt inventory/verification of switches and power supplies where contiguous runs approach roughly 300 feet, and PoE for any security cameras on the line. Multiple same-network neighboring endpoints flag possible LOR branching for repeater verification, not a proven branch or installed repeater. These are read-only equipment expectations. Do not create installed equipment from length, graph shape or network membership. Existing actual inventory is entered only from known equipment. Preserve the Racing Arch chain as unverified recollection.

Operator confirms the latest disposable review CLEAN EXIT and port/source-lock release. Next candidate needs exact-head tests and a fresh lock/port preflight; this is not Production deployment approval.

### V0.4.15 endpoint correction implemented

The snapshot now exposes network_capable from FLW membership. Both Controller and Waypoint selectors consume it, and the redundant database GPX-type veto is removed. Specific LOR/FLW matching remains mandatory, while power connection eligibility remains separate. Panel, SW, PO and arbitrary unclassified FLW endpoints are exercised without name exceptions. Read-only waypoint prompts identify possible LOR branches and INET/E1.31 switch/power/PoE expectations; no installed records are created. Local FieldWiring 220 tests and PGlite 232 SQL checks PASS. Existing browser regression includes panel placement and expectation-without-inventory-mutation checks. Exact-head Chromium/PostGIS gates pending at preparation. Production and immutable source tests remain unchanged. Chain-order/termination capture is not implemented by this endpoint correction; that limitation remains explicit.

## October 24 controller chain order — required before release

Greg requires the physical order, not only the shared network origin. Extend the existing
`ref.site_controller_installation` with `upstream_kind` (UNKNOWN, WAYPOINT,
CONTROLLER), nullable `upstream_controller_id`, and `chain_end` (UNKNOWN,
TERMINATOR, RETURN_TO_ORIGIN). The existing waypoint remains the chain origin.
UNKNOWN preserves incomplete observations; never infer a direct connection from
an older origin-only record. A controller predecessor is an existing inventory ID,
not another inventory or wiring system. Controller-to-display wiring is unchanged.

Both supported endings are explicit: RA-00 → 1001 → 1002 → 1003 → 1004 → RA-00
(return cable for onward continuation), or the same chain ending in a terminating
resistor. Return is an end designation at the origin, not a controller dependency
and not an inferred closed electrical ring. Only a last controller may have a
recorded ending. UNKNOWN allows incomplete inventory and is never called verified.

A predecessor must be active, have recorded upstream order, share the origin and
confirmed current LOR network, and have no other downstream controller. Every
member retains the existing FLW/LOR placement gate. Reject self-links, controller
cycles, controller branching, mixed networks/origins, and dangling dependencies.
Multiple independent chains at a waypoint are allowed; repeater equipment remains
a field verification expectation, never automatically installed inventory.

Use the existing serialized revision-checked command and audit history. Topology
corrections on an existing installation retain before/after audit evidence. Changing
origin continues to retire/create installations. Rewire or disconnect downstream
controllers first before retiring/moving their predecessor. Clear a recorded chain
ending before extending it. Do not silently cascade moves, change downstream wiring,
or invent termination. Controller Inventory and Waypoint Connections edit the same
fields; power remains independent and network-only saves remain possible.

Required regression: a four-controller ordered chain and both endings; mixed network,
self/cycle/fanout, wrong origin, terminated predecessor and retirement denial;
reordering, stale edits, exact replay, rollback, shared-screen persistence, unknown
order display and authorization. Reuse the current disposable runner and migration
chain. Current review exited cleanly; new exact-head browser acceptance is pending.

### V0.4.16-controller-chains implementation checkpoint

The existing installation now records upstream kind/controller and chain ending.
Controller Inventory shows the ordered chain and edits the same fields as Waypoint
Connections. Network-only saves remain possible without an outlet/circuit. Database
commands reject controller loops, fanout, terminated predecessors, dangling children
and different origins/current LOR networks. Return-to-origin is explicitly accepted.
Rewiring is audited; origin moves retain retire/create history and dependent children
must be reconnected first. Old origin-only records remain UNKNOWN, not inferred direct.

Local FieldWiring 220 tests and isolated PostgreSQL 257 command/denial checks PASS,
including four controllers, both endings, reordering, rollback, roles, stale/replay
and prior power/FLW protections. Existing actual-browser suite now exercises shared
screen topology persistence and four-controller order; exact-head CI is pending at
preparation. Use the existing PR #319 handoff for final SHA/status, not an older
candidate. Operator supplied CLEAN EXIT and port/source-lock release before this
work. Production and source files unchanged; no new preview launched here.

## October 24 reciprocal IN / OUT correction — controlling operator requirement

V0.4.16 is not accepted: recording only a predecessor and a terminal selector does
not expose the physical controller ports. Both screens must present editable IN and
OUT. OUT includes eligible controllers, terminating resistor and the named return
waypoint. Saving A OUT → B establishes B IN ← A; editing B IN establishes the same
relationship and A's displayed OUT. Store one edge using the existing predecessor
field; do not add a second independently editable successor column or another schema.

Extend the existing audited command boundary with an atomic controller_ports command.
It changes the selected installation and, if needed, the previous/new downstream
installation under the existing revision lock. Validate the completed graph before
commit. Retain audit before/after for every affected controller and preserve retired
origin records. Detaching an edge makes the released port UNKNOWN, never invents a
new waypoint cable or deletes the remaining chain. A known OUT may coexist with an
unknown IN; this supersedes V0.4.16's requirement for a known predecessor input.
Occupied controller ports must not be silently stolen: reconcile an existing input
or output explicitly. Reject self/circular links, fanout, different current LOR
networks/origins and ineligible FLW origins. Network and power remain independent.

Required operator examples (not automatically installed or verified):
RA-00 → 1001 → 1002 → 1003 → 1004 → resistor OR return to RA-00 (unverified);
ST-01 → 1005 → 1006 → 1036 → return to ST-01 (unverified).
Show each controller's IN and OUT with names and verification status, including
both ends when the operator navigates to the neighboring controller. Use the same
port editor from Controller Inventory and Waypoint Connections. Tests must start
with an unassigned next controller and prove it is selectable from OUT, persisted
reciprocally, replaceable without invented wiring, and protected on stale/replay,
invalid graphs, existing occupied ports and rollback. No replacement preview may
be started while the current review holds port 8898/source lock; current V0.4.16
review has no subsequent clean-exit receipt yet. Production unchanged.

### V0.4.17 reciprocal ports implementation / latest field clarification

The shared editor presents IN → Controller → OUT and allows selecting an unassigned
next controller from OUT. The atomic controller_ports command maintains one stored
edge, updates both screen views, preserves released chains with unknown input,
rejects occupied ports/cycles/network mismatches and records affected rows in audit.
No second successor column or duplicate inventory was introduced. Both screens now
use this same editor rather than separate topology forms. Stage filtering is unchanged.

Greg confirms stage filtering works. Racing Arches probably ends with a resistor;
that remains UNVERIFIED. Elf Choir returns via ST-01 for continuation toward Stars;
do not label it a terminated network. These are documentation/test examples only,
not seeded installed wiring. Latest operator receipt after V0.4.16 review confirms
CLEAN EXIT and free port 8898/GIS source lock. Next launch still rechecks both.

Local FieldWiring 220 tests and isolated SQL 281 command/denial checks PASS, including
both supplied controller sequences, reciprocal saves, released input, occupied
ports, known termination with unknown input, audit, rollback, role denial and replay.
Exact-head actual browser/PostGIS/regression CI pending at preparation. Existing
PR #319 handoff will identify final passing SHA and review checklist. Production
and original GIS/FLW sources remain unchanged; no new preview launched here.

## October 24 display names in network wiring

Greg's AUX-I review shows a recorded cross-stage chain from WV-03 through eight
Who Forest controllers and into Whoville, ending at CTRL 1061 with a resistor.
He reports difficulty identifying Tree 8 (CTRL 1094) from asset IDs alone; the
screenshots are evidence of the recorded chain, not confirmation that all intended
controllers or the physical wiring are verified. The current repeat preview has
no new CLEAN EXIT receipt yet.

Display the assigned physical display name below each Controller ID in the IN /
Controller / OUT table and alongside IDs in choices and the chain description.
Use existing ref.controller_display/ref.display relationships already exposed in
snapshot load_lineage, including controllers without power connections. Never use
wiring-source template names in place of physical display names, infer tree order
from IDs or stage order, rename controller assets, or copy names into installation
records. Show all assigned display names and an explicit no-display fallback.
Reuse the same labeling helpers on both screens. This is presentation only: network
eligibility, topology, power, audit and stage filtering remain unchanged.

### V0.4.18-display-names implementation

Both screens reuse physical display names already supplied by snapshot load_lineage;
no SQL, new schema, stored name copy or new assignment source is introduced. Names
appear beneath IDs in port tables and alongside IDs in IN/OUT choices, controller
selection and the full chain. All assigned names are shown; absent assignments have
an explicit fallback. Existing wiring-source template names do not replace physical
copy names. Local FieldWiring 220 tests PASS. Browser regression covers a physical
copy with a different template name, choices, chain, both screens and multiple/no
assignment labels. Exact-head CI pending at preparation. Latest AUX-I screenshots
show a recorded cross-stage chain ending in a resistor, with physical verification
still UNVERIFIED. No clean exit for this repeat review received yet; do not overlap
reviews. Production/source files unchanged.


## October 25 controller list sort — final operator refinement

Greg accepts V0.4.18's physical display names in network wiring and supplies CLEAN
EXIT with port 8898 and GIS source lock released. Retain earlier panel/breaker/
waypoint, Racing Arches and Elf Choir acceptance; physical wiring stays UNVERIFIED.

Add a visible Sort by selector in the left Controller list: Controller ID (default)
or Display name. Sort the existing filtered inventory response locally, using its
physical display_names, with natural numeric/case-insensitive name ordering,
unnamed/unassigned controllers last and numeric Controller ID as tie-breaker.
The choice remains active during filtering/refresh in this page. Sorting must only
rerender the list, retaining selected controller and unsaved detail/connection edits.
Do not change stage filters, network chain order, assignments, schemas or API.
Reuse the existing browser regression and disposable preview mechanism.


### V0.4.19-controller-sort implementation

The existing Controller Inventory list now offers Controller ID / Display name.
The filtered response is sorted without fetching or rebuilding the detail editor;
natural name comparison, unassigned-last and ID ties are explicit. List refresh
retains the selected sort. No SQL/API/topology changes. Local FieldWiring regression:
220 passed. Existing browser workflow extended for natural/tied/unassigned ordering,
stage scope, selected controller, unsaved network/power edits and refresh retention.
Exact-head browser and required CI pending at preparation; PR #319 holds final
candidate SHA/run results and the existing disposable handoff. V0.4.18 display names
accepted by Greg with screenshot and CLEAN EXIT; V0.4.19 sort acceptance pending.


## October 25 picker sorting follows Controller list

Greg accepts V0.4.19 left-list sorting, but screenshots 053857 / 054133 show the
IN/OUT controller options remain in ID order when the list uses Display name.
CLEAN EXIT confirms port 8898/source lock available. Extend the same sort choice
and comparison rules to both port pickers, initially and immediately on sort changes.
Keep non-controller choices first, preserve selected values and unsaved edits, and
retain all eligible controllers across stages. Reorder existing options without
triggering connection-change handlers, reloads or saves. Do not sort the recorded
chain or change eligibility, topology, power, database or source files.


### V0.4.20-picker-sort implementation

A shared comparator now orders the left inventory and IN/OUT controller choices.
Options are reordered in place, preserving selected values, special choices and
dirty edits; choice builders also apply current order after origin/input changes
and editor loading. Stage scope is not applied to eligible connection options.
Local FieldWiring 220 passed; browser regression extends the existing dirty-edit
sort test to both pickers, preserving eligibility sets and selected values in both
sort modes. Exact-head CI pending at preparation; final results and candidate pin
belong to the existing PR #319 handoff. V0.4.19 left-list accepted and CLEAN EXIT
received. V0.4.20 picker review pending. Production and source files unchanged.


## October 25 Production approval and observed live baseline

Greg approved V0.4.20-picker-sort at 439ab237beaae4ac648e7590f824a774969cd84f
for Production after ALL SORTS PASS and CLEAN EXIT. This approval persists.
No repeat feature review is required for unchanged accepted application bytes.

Read-only host receipt:
- shared /opt/fieldwiring: 17c522c4f8ec06549bf7a6d9e8530c61276203f7, clean;
  FieldWiring V0.4.2-controller-uid-explorer, postgres/ok.
- /opt/msb-setup: e3c39f2781b5a97648dce1f00965110becd2edd6, clean;
  Setup V0.3.87-catalog-scene-refresh-r3, postgres/ok.
- Controller real/ONLINE, database_fenced=false, read continuity OFF,
  last_error=null; all seven governed services/containers active/running,
  including Work Management. NAS mounted; replication current_run_ok=true.
- Local/NAS PostgreSQL and Directus backups available. The controller's October 22
  snapshot is historical, not this release's frozen rollback archive.
- Remote printservice sessions are normal while ONLINE; the controller fence,
  not a manual edit pause, must exclude them during the mutation window.

Current server runbooks were retrieved: Production_Database_Change_Deployment_Runbook,
Production_Database_Maintenance_Mode, FieldWiring_Production_Runtime and
Setup_Production_Runtime. Their historical SHA labels do not override this receipt.

Full #319 is DATABASE-CHANGING. Reuse setup_maintenance_deploy.py and its existing
profile pattern, deployment lock, controller, journal and fail-closed containment.
The September Controller launcher is not this release's installer. Never run it.
The source acceptance helper explicitly targets the disposable database and must
not be redirected to Production or have that guard weakened.

Before finalizing the release profile, collect current GIS/FLW catalog, row counts,
source bindings and operator capability using 171_site_production_preflight.sql.
This read-only transaction also establishes whether bootstrap is applicable or
existing stable identities require reconciliation; no TRUNCATE/recreate shortcut.
Verify the two accepted content-addressed cache files without changing their bytes.
No new schema, runner, source parser, Directus grant store or inventory is authorized.
Do not copy a preview database or disposable operator wiring into Production.
Release profile, its fault tests, exact migration/source identities and the merged
release target remain pending. No maintenance entry, merge or Production mutation
has occurred. Scope approval is not a claim that deployment engineering is complete.


## October 25 release profile preparation

Second read-only receipt: PostGIS 3.5.2, only ref.site_network with 27 rows,
existing Manager read/manage capability true. Accepted cached GPX/FLW hashes OK.
No waypoint/power/FLW tables/functions detected. Initial installation is applicable;
existing network IDs/rows must survive unchanged.

setup_171_release.py is a profile of the existing setup_maintenance_deploy.py,
not a replacement runner. Default source/live hooks extracted without changing
historical behavior; existing profiles' helper-byte pins refreshed accordingly.
setup_171_transport.py reuses existing committed-byte packaging. One existing-pattern
PowerShell wrapper provides foreground execution and PreflightOnly. The profile
holds both established deployment/source locks, preserves frozen business and
Directus rows, and loads sources through the existing parser/import functions via
the proved local administrator socket. Disposable source gate remains unchanged.

Accepted application SHA stays 439ab237beaae4ac648e7590f824a774969cd84f; later
commits are deployment tooling/documentation only. Profile requires that approved
application be contained in main before host execution. Local fault/default-profile
regression: 58 passed. CI adds real disposable PostGIS socket/import/replay refusal
and Windows transport/parse proof. Exact-head CI pending at preparation.
Production remains ONLINE and unchanged. No claim of server release success until
a retained host receipt proves snapshot, migration, source validation/promotion
and ONLINE health. A committed/uncertain failure retains maintenance and report.


### Release adapter integration proof and final schema gate

Tooling head 22e79b7b5488ec56643627908e3ebaf307e8aea8 passed all four existing
CI workflows: Setup, Site reference/PostGIS, release tooling, Engineering Compliance.
The actual ephemeral PostgreSQL test proves container-local admin connection,
initial GPX/FLW load, archive restoration and repeat-install refusal. Earlier CI
caught socket symlink traversal, string/Path normalization and missing ExpertGPS
labels in the synthetic fixture; all corrected before host execution.
The final preflight additionally compares existing site_network column types,
nullability and generated-identity mode against the operator's catalog receipt.
Local profile/default-runner failure checks: 60 passed. Exact final-head checks
are recorded in PR #319 before merge; no application bytes change.
Broader Setup/Acceptance: 153 passed, 2 skipped, six historical #88 report-contract
failures, each reproduced on the approved application baseline. No #88 report
implementation changes are part of this release. Production deployment and
protected live-browser closeout still require the retained host receipt.

## October 25 Production receipt and panel-entry follow-up

PR319 merged as 6aa23c399cea5dad7ba6b9cef619d469fe024991. Greg returned server
PASS for accepted application 439ab237beaae4ac648e7590f824a774969cd84f,
FieldWiring V0.4.20-picker-sort / Setup V0.3.91-integrated-power. Report:
/home/msbadmin/setup-deployment-reports/PR319-GIS-20261025T062215Z.
Preflight, freeze, snapshot, three migrations, GPX/FLW intake, database validation
and return to service all passed. Snapshot details remain in the retained report;
no separate archive path/hash was pasted. Do not rerun initial installation.

Greg is now entering real Production panels/breakers and provided WV-00 Panel 10
screenshots/photo. He reports the interface usable but needs the missing final
slots and clearer colors/groupings. This is not a claim that all follow-up UI
acceptance is complete. Preserve his Production entries.

Final correction: Number of slots in Panel setup, nullable until recorded;
1–200 actual numbered positions excluding main. No amperage inference or fixed
40-position expansion. Store on ref.site_panel via the existing audited command;
reject shrink and breaker placement beyond occupied extent. MSB light-blue and
City light-orange ownership labels, distinct selection, primary Save/Add,
outlined circuit assignment controls, neutral secondary actions, stronger breaker
groups and concise disclosures retaining uncertainty/safety details.

Candidate V0.4.21-panel-entry is engineering only. The incremental migration
171_panel_slot_count.sql extends the existing panel and command boundary; initial
schema/import files remain unchanged. Existing tests cover configured slot limits,
atomic denial, role boundary, 40-slot UI entry, reload and both ownership themes.
Local Python regression: 230 passed; isolated PostgreSQL command suite and slot
range/occupied-bound checks passed. Browser execution is delegated to existing CI
because this local runtime denies Chromium's Unix socket; no browser PASS claimed
until that workflow completes. Exact candidate and CI results belong to the PR.
Preview must clone current Production, apply only the incremental migration and
its read-only validation, and use existing saved panel data. No GPX/FLW reimport.

## October 25 — V0.4.22 follow-up candidate

Greg reviewed 70c856ce and confirmed CLEAN EXIT, port 8898 and GIS source lock
available. Further changes requested; this is not acceptance for deployment.
V0.4.22-panel-navigation adds Greg's supplied 19 breaker ratings (10–200 A),
preserves additional saved values without duplicates, restores panel context on
waypoint return, aligns screen navigation and distinguishes gray settings from
teal navigation actions in both themes. Custom rating entry was superseded by
Greg's explicit supplied list. Existing count migration remains the only migration.
Browser regression covers both return routes, filter/disclosure/scroll restoration,
rating choices and action colors. Exact CI evidence and preview SHA belong to PR455.
Production and original GIS sources remain untouched; preview uses a fresh current
Production clone, not the initial source importer. The observed 142M dump has not
yet been attributed to measured relation sizes; no source evidence is removed.
