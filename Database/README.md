# PostgreSQL production database

The `msb` PostgreSQL database is the authority for all current production systems. The legacy migration phase is complete; new work should be organized by the production subsystem it serves rather than treated as another database migration.

## Contents

| Path | Purpose |
|---|---|
| [`Schema_Snapshots/`](Schema_Snapshots/README.md) | Canonical dated schema-only PostgreSQL exports used for current implementation reference and field-name verification |
| `Basic_Query_Tools/` | Database inspection, verification, maintenance, and current operational SQL |
| `ERD/` | PostgreSQL entity-relationship design |
| `EngineeringTools/` | Repository-only backend engineering utilities |

The newest schema snapshot must remain directly under `Schema_Snapshots/`. Older snapshots are retained under `Schema_Snapshots/archive/`. Repository cleanup must not remove the only current schema snapshot without first establishing its replacement.

LOR snapshot ingest enters PostgreSQL through [LOR2DB](../LOR2DB/README.md). LOR-specific reconciliation and promotion belongs to `LOR2DB/`, not this general database folder.

Completed work-order migration DDL is retained under `archive/completed_migrations/work_orders/`. It is historical implementation evidence, not an active migration queue.

## Documentation

- [Production database documentation](../Docs/02_Production_Database/README.md)
- [System architecture](../Docs/02_Production_Database/01_System_Architecture/README.md)
- [Database Foundation](../Docs/02_Production_Database/01_System_Architecture/01_Database_Foundation/README.md)
- [Operational SOPs](../Docs/02_Production_Database/02_Operational_SOPs/README.md)
