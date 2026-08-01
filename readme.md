# MSB Production Database Project

This repository contains the software, PostgreSQL project files, and documentation used to convert Light-O-Rama (LOR) preview data into the Making Spirits Bright production database and support wiring, inventory, testing, and field operations.

The project evolved from a parser built for the wiring view into the authoritative LOR-to-production-database pipeline. Some components therefore remain in historically separate folders even though they are parts of one system.

## End-to-End LOR Data Pipeline

```text
LOR .lorprev XML files
        |
        v
Scene-aware Python parser
parsers/experimental/parse_props_v7_scene_parser.py
        |
        v
Rebuilt SQLite snapshot
lor_output_v7_scene.db
        |
        v
PowerShell ingest runner
postgres_run_ingest_v7.ps1
        |
        v
Python SQLite-to-PostgreSQL ingester
postgres_ingest_from_lor_sqlite_v7.py
        |
        v
Immutable PostgreSQL snapshot tables
lor_snap.* + import_run_id
        |
        v
Validation, reconciliation, and ordered promotion procedures
Postgres_sql/Upsert Procedures/
        |
        v
Permanent production records
ref.* and related production schemas
```

The parser and ingester are not separate projects. They are the upstream half of the MSB database import pipeline. The SQL under `Postgres_sql/` is the downstream database half.

## Current V7 Development Status

LOR 6.6.4 changed the preview structure used by this project. The Master Musical Preview no longer supplies a separate preview identity for every stage; scene metadata must now carry part of that stage context.

The scene-aware V7 parser and ingester are being validated before they replace the established production path. Development SQL used to prove that V7 snapshots can be reconciled without corrupting permanent production identities is kept under:

```text
Postgres_sql/Upsert Procedures/reconciliation/
```

That folder is a development and validation workspace. Its contents are not automatically approved production procedures.

## Authority and Safety Boundaries

- LOR preview files are authoritative for LOR wiring, props, subprops, channels, preview membership, and scene membership.
- The SQLite database is rebuilt from the selected LOR preview set and is a disposable validation artifact.
- Each PostgreSQL ingest creates a new append-only `lor_snap.import_run`; an ingest does not rewrite earlier snapshots.
- `lor_snap` is immutable source evidence, not the permanent business identity layer.
- Production identities such as `ref.display.display_id` must be preserved through controlled reconciliation and promotion.
- PostgreSQL-owned operational data must not be overwritten merely because an LOR snapshot changed.
- Parser success and ingest success do not by themselves authorize promotion into production reference tables.

## Repository Areas

| Path | Role |
|---|---|
| `parsers/production/` | Established production parsers retained for the current supported workflow. |
| `parsers/experimental/` | Parser development, including the LOR 6.6.4 scene-aware V7 parser. |
| `postgres_run_ingest_v7.ps1` | Secure operator-facing wrapper for the V7 SQLite-to-PostgreSQL ingest. |
| `postgres_ingest_from_lor_sqlite_v7.py` | Append-only V7 snapshot ingester for `lor_snap`. |
| `Postgres_sql/` | Authoritative location for PostgreSQL schema, validation, reconciliation, promotion, and production database work. |
| `Docs/` | System, integration, operations, and field documentation. |
| `formview/` | Existing field wiring-view application components. |

Do not relocate working parser or ingester files merely to make the folder tree look linear while V7 is under validation. The documentation defines the pipeline until a deliberate reorganization can be tested safely.

## Documentation

- [PostgreSQL pipeline and folder responsibilities](./Postgres_sql/README.md)
- [Documentation hub](./Docs/README.md)
- [Production import and reconciliation procedure](./Postgres_sql/Upsert%20Procedures/00_LOR_Production_Import_and_Reconciliation_Procedure.md)
- [Promotion pipeline design](./Postgres_sql/Upsert%20Procedures/01_LOR_Production_Promotion_Pipeline_Design.md)
- [V7 reconciliation development workspace](./Postgres_sql/Upsert%20Procedures/reconciliation/README.md)

---

Engineering Innovations, LLC — Greg Liebig

Making Spirits Bright Production Team, Sheboygan, Wisconsin
