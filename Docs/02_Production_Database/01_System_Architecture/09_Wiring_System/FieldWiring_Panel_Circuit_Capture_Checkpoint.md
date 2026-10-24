# FieldWiring panel circuit capture — implementation checkpoint

| Document control | Value |
|---|---|
| Status | SOURCE CANDIDATE — live catalog received; integrated release acceptance pending |
| Owner | #171 / #230 under #122 |
| Reviewed | 2026-10-22 |

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


## October 23 operator simplification — current source candidate

Greg wants the field workflow as simple as accepted breaker assignment: dropdown selections, only meaningful required identifiers, optional Notes instead of arbitrary free-text verification/evidence blockers. The generic device editor is for equipment inventory (DIN rail supplies, network switches, extenders, repeaters), not normal breaker entry. Combo means power **and** network, independently of whether the physical asset is a network box or light pole. Filter eligible selection by maintained physical classification and capability, never by a name substring.

Current PR #454 source work removes blank-source-evidence save rejection in the uninstalled candidate schema/commands, defaults ordinary new records to UNVERIFIED, and simplifies normal forms/assignment notes. The existing author/time and command audit remain mandatory. **Actual seasonal field evidence events retain their nonempty observation requirement** because otherwise the system could record empty work. A VERIFIED assertion still requires governed evidence/actor logic; ordinary save does not falsely claim verification.

This is a **partial candidate**, not yet released: existing panel/circuit identity strings and device identification remain typed because structured master-list/catalog and blocker-free breaker group integration are still unfinished. Do not label the whole interface dropdown-only. #319 waypoint/type integration and combined schema acceptance remain prerequisites. Reconcile existing regression expectations and test the save paths before disposable/browser review; do not deploy or promote while those gates are open.
