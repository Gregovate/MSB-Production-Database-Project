# Database Foundation

This subsystem documents the shared PostgreSQL architecture that all Production Database operational systems depend on.

## Current State

PostgreSQL is the durable identity, relationship, history, and operational integration layer for the MSB Production Database. Shared schema boundaries, permanent-key rules, audit behavior, functions, procedures, triggers, and database-wide engineering contracts belong here.

## Design Intent

The foundation must support independent operational subsystems without coupling their permanent identities to application-specific or LOR-generated identifiers.

LOR remains authoritative for show topology and wiring configuration. The Production Database consumes LOR data but does not become a competing topology-authoring system.

## Authoritative Sources

- Current PostgreSQL schema, constraints, functions, procedures, and triggers are implementation truth.
- Current LOR ingestion/reconciliation implementation is maintained under [`LOR2DB`](../../../../LOR2DB/README.md).
- Historical architecture documents in this directory are being reconciled into the numbered subsystem structure before archival.

## Shared Responsibilities

- schema boundaries (`lor_snap`, `ref`, `ops`, `stage`, `dev` where currently applicable)
- permanent internal identities and foreign-key rules
- audit attribution and timestamp conventions
- PostgreSQL functions, procedures, and triggers
- database-wide integrity and history rules

## Database Object Documentation

Database-level PostgreSQL functions, procedures, and triggers have one canonical documentation home under Database Foundation:

- [Functions and Procedures](01_Functions_and_Procedures/README.md)
- [Triggers](02_Triggers/README.md)

This central index exists so database objects do not become scattered or lost as business workflows and user interfaces evolve.

A subsystem such as Testing, Work Orders, People and Identity, Containers and Storage, or Setup and Deployment may depend on these objects and should link to the authoritative database-object document. It should not maintain a second authoritative copy merely because that workflow invokes the object.

This rule is especially important for shared mechanisms such as auditing, actor attribution, Directus-to-`ref.person` lookup/mapping, integrity helpers, and lifecycle logic used by more than one system.

Standalone systems may own their own implementation artifacts when the database object or executable artifact is specific to that standalone system. LOR2DB is the primary example: LOR2DB-specific parser, reconciliation, promotion, validation, and reporting implementation remains with LOR2DB.

## Boundaries

Business workflow design, Directus flows, application behavior, and operator procedures remain with the subsystem that owns the business process. PostgreSQL function/procedure/trigger engineering documentation remains centralized here when the object is implemented in the shared Production Database.

## Related Systems

- [LOR2DB Ingest](../02_LOR2DB_Ingest/README.md)
- [People and Identity](../03_People_and_Identity/README.md)
- [Production Database Architecture](../README.md)

## Resume Development

Before changing a Production Database function, procedure, or trigger, inspect the live PostgreSQL implementation and its canonical document under Database Foundation, then review every subsystem that links to or depends on that object. Do not infer current behavior from legacy architecture documents alone.
