# PostgreSQL production database

The `msb` PostgreSQL database is the authority for all current production systems. The legacy migration phase is complete; new work should be organized by the production subsystem it serves rather than treated as another database migration.

## Contents

| Path | Purpose |
|---|---|
| `schema/` | Authoritative schema exports and backups |
| `Basic_Query_Tools/` | Database inspection, verification, maintenance, and current operational SQL |
| `ERD/` | PostgreSQL entity-relationship design |
| `EngineeringTools/` | Repository-only backend engineering utilities |

LOR snapshot ingest enters PostgreSQL through `LOR/ingest/`. LOR-specific reconciliation and promotion belongs to `LOR2DB/`, not this general database folder.

Completed work-order migration DDL is retained under `archive/completed_migrations/work_orders/`. It is historical implementation evidence, not an active migration queue.

## Documentation

- [Production database documentation](../Docs/02_Production_Database/)
- [System architecture](../Docs/02_Production_Database/01_System_Architecture/)
- [Operational SOPs](../Docs/02_Production_Database/02_Operational_SOPs/)
