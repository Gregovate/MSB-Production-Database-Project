# Database Foundation

This subsystem documents the shared PostgreSQL architecture that all Production Database operational systems depend on.

## Current State

PostgreSQL is the durable identity, relationship, history, and operational integration layer for the MSB Production Database. Shared schema boundaries, permanent-key rules, audit behavior, functions, procedures, triggers, and database-wide engineering contracts belong here.

## Design Intent

The foundation must support independent operational subsystems without coupling their permanent identities to application-specific or LOR-generated identifiers.

LOR remains authoritative for show topology and wiring configuration. The Production Database consumes LOR data but does not become a competing topology-authoring system.

## Authoritative Sources

- The live PostgreSQL database is runtime implementation truth.
- The newest dated schema-only export under [`Database/Schema_Snapshots`](../../../../../Database/Schema_Snapshots/README.md) is the durable point-in-time implementation reference used for table/column/FK/constraint/function/trigger/view verification during engineering and documentation work.
- Current LOR ingestion/reconciliation implementation is maintained under [`LOR2DB`](../../../../LOR2DB/README.md).
- Historical architecture documents may preserve design history, but they are not implementation authority after reconciliation into the numbered subsystem tree.

## Shared Responsibilities

- schema boundaries (`lor_snap`, `ref`, `ops`, `stage`, `dev` where currently applicable)
- permanent internal identities and foreign-key rules
- audit attribution and timestamp conventions
- PostgreSQL functions, procedures, and triggers
- database-wide integrity and history rules

## History and Lifecycle Contract

History tables are purposeful, not automatic. Current state stays on the owning record unless a workflow genuinely requires a reconstructable event/history trail. Standard audit fields provide normal accountability for changes that do not need separate event history.

This means the database does **not** create generic movement or assignment history merely because a current relationship changes. A subsystem may preserve history when the real operational workflow requires it, such as a yearly deployment sequence, work-order lifecycle, testing history, or another explicitly engineered business event.

Display lifecycle currently uses three operational meanings:

- **ACTIVE** — currently in service and deployable.
- **RETIRED** — the physical display still exists but is no longer part of the current show/use.
- **RECYCLED** — the original display no longer exists as a display; some or all components such as frames, lights, or hardware may have been reused elsewhere.

The current implementation conservatively retains `ref.display` after RECYCLED because existing foreign-key relationships make deletion unsafe. Cleanup removes only eligible operational structures and preserves protected relationships. A preferred future direction is to preserve sufficient historical display identity separately so a physically RECYCLED display could eventually be removed from current inventory, but that is a future engineering item and is not part of the present schema contract.

## Database Object Documentation

Database-level PostgreSQL functions, procedures, and triggers have one canonical documentation home under Database Foundation:

- [Functions and Procedures](01_Functions_and_Procedures/README.md)
- [Triggers](02_Triggers/README.md)

This central index exists so database objects do not become scattered or lost as business workflows and user interfaces evolve.

A subsystem such as Testing, Work Orders, People and Identity, Containers and Storage, or Setup and Deployment may depend on these objects and should link to the authoritative database-object document. It should not maintain a second authoritative copy merely because that workflow invokes the object.

This rule is especially important for shared mechanisms such as auditing, actor attribution, Directus-to-`ref.person` lookup/mapping, integrity helpers, and lifecycle logic used by more than one system.

Standalone systems may own their own implementation artifacts when the database object or executable artifact is specific to that standalone system. LOR2DB is the primary example: LOR2DB-specific parser, reconciliation, promotion, validation, and reporting implementation remains with LOR2DB.

## Schema Snapshot Rule

The current production schema snapshot is a required engineering artifact, not disposable documentation. Repository cleanup or reorganization must never remove the only current schema snapshot without first establishing its replacement under [`Database/Schema_Snapshots`](../../../../../Database/Schema_Snapshots/README.md).

A new schema-only export should be captured after significant schema changes so repository documentation and engineering work have a trustworthy point-in-time reference.

Before documenting or changing a table, field, relationship, function, procedure, trigger, constraint, or view, verify names and implementation against the newest schema snapshot or the live database rather than relying on memory or an older design document.

## Boundaries

Business workflow design, Directus flows, application behavior, and operator procedures remain with the subsystem that owns the business process. PostgreSQL function/procedure/trigger engineering documentation remains centralized here when the object is implemented in the shared Production Database.

## Related Systems

- [PostgreSQL Schema Snapshots](../../../../../Database/Schema_Snapshots/README.md)
- [LOR2DB Ingest](../02_LOR2DB_Ingest/README.md)
- [People and Identity](../03_People_and_Identity/README.md)
- [Production Database Architecture](../README.md)

## Resume Development

Before changing a Production Database function, procedure, trigger, or shared schema contract, inspect the live PostgreSQL implementation and/or newest schema snapshot, then review its canonical Database Foundation documentation and every subsystem that links to or depends on that object. Do not infer current behavior from legacy architecture documents alone.
