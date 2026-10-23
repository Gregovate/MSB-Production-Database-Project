# FieldWiring panel circuit capture — implementation checkpoint

| Document control | Value |
|---|---|
| Status | RECON — live-schema prerequisite outstanding; no implementation candidate |
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

## Immediate prerequisite and continuation

#230 requires inventory of current live schema, constraints, grants, triggers and
runtime before application/schema changes. This workspace has no configured
Production database connection. Repository snapshots and draft SQL cannot prove
which objects the parallel GIS work has installed or populated.

Run [read-only schema inventory](Queries/02_Panel_Circuit_Schema_Inventory.sql) as a
whole script in the existing DBeaver connection and retain its one JSON result.
It reads PostgreSQL catalogs in a read-only transaction, tolerates absent proposed
tables, and does not query private operator records or mutate equipment data.
Syntax parsing is a source check, not live execution or current-schema acceptance.

Then reconcile installed objects with the GIS synchronization thread's accepted
schema/source identity and current FieldWiring deployment; establish required
additive changes in this owning engineering document before implementing them.
Continue on the existing `engineering/171-230-circuit-capture` branch after
refreshing main and checking concurrent work. No replacement GIS source/importer,
free-form waypoint foreign keys, or independent user-role store.

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
