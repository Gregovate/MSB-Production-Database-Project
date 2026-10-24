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
