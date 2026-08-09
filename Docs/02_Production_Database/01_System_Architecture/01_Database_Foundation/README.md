# Database Foundation

This subsystem documents the shared PostgreSQL architecture that all Production Database operational systems depend on.

## Current State

PostgreSQL is the durable identity, relationship, history, and operational integration layer for the MSB Production Database. Shared schema boundaries, permanent-key rules, audit behavior, procedures, triggers, and database-wide engineering contracts belong here.

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
- shared PostgreSQL procedures and triggers
- database-wide integrity and history rules

## Boundaries

Business-specific procedures, triggers, Directus flows, and application behavior should be documented with the subsystem that owns the business process. This area owns only genuinely shared database behavior.

## Related Systems

- [LOR2DB Ingest](../02_LOR2DB_Ingest/README.md)
- [People and Identity](../03_People_and_Identity/README.md)
- [Production Database Architecture](../README.md)

## Resume Development

Before changing shared database contracts, inspect the current PostgreSQL implementation and the responsible subsystem documentation. Do not infer current behavior from legacy architecture documents alone.
