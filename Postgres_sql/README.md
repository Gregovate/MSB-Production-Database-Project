# PostgreSQL Database Pipeline

`Postgres_sql/` is the authoritative project area for PostgreSQL database work in the MSB Production Database repository. It contains the database foundation that receives an ingested LOR snapshot, validates it, reconciles it against permanent records, and promotes approved changes into production schemas.

The parser and SQLite-to-PostgreSQL ingester are stored elsewhere in this repository, but they are the required upstream half of this same pipeline.

## Position in the Complete Pipeline

```text
LOR .lorprev XML
    -> parse_props_v7_scene_parser.py
    -> lor_output_v7_scene.db
    -> postgres_run_ingest_v7.ps1
    -> postgres_ingest_from_lor_sqlite_v7.py
    -> lor_snap immutable import run
    -> PostgreSQL validation and reconciliation
    -> ordered P1/P2/future P3 promotion
    -> ref and related production tables
```

The `Postgres_sql` portion begins when the ingester writes a complete snapshot into `lor_snap` under a new `import_run_id`. It does not begin with the upsert procedures: the snapshot schema, import-run model, validation, reconciliation, promotion procedures, and verification together form the PostgreSQL pipeline.

## PostgreSQL Pipeline Stages

### 1. Receive an immutable LOR snapshot

`postgres_run_ingest_v7.ps1` launches `postgres_ingest_from_lor_sqlite_v7.py` from the repository root. The ingester copies the rebuilt SQLite data into `lor_snap` in one transaction.

The ingest contract is:

- create one new `lor_snap.import_run` row;
- attach the resulting `import_run_id` to every imported snapshot row;
- load the supported preview, prop, subprop, channel, scene, and scene-membership tables;
- roll back the entire ingest if any required load fails;
- never update or delete an earlier import run;
- perform no production identity decisions during ingestion.

An ingested snapshot is historical source evidence. It is not automatically approved production state.

### 2. Select and verify the exact import run

All validation and promotion work must be tied to an explicit `import_run_id`. The selected run must be checked for expected table population, structural integrity, and scene-aware relationships before production procedures execute.

Using “latest” implicitly is unsafe when a newer test or failed workflow may exist. New scene-aware procedures should accept the approved run explicitly.

### 3. Reconcile snapshot evidence with permanent identities

Reconciliation compares the selected immutable LOR snapshot with PostgreSQL-owned production records.

This boundary protects facts with different owners:

| Data | Authority |
|---|---|
| LOR props, subprops, DMX channels, wiring, preview membership, and scene membership | LOR snapshot |
| Permanent display identity (`ref.display.display_id`) | PostgreSQL |
| Current LOR UUID association (`ref.display.lor_prop_id`) | Controlled reconciliation |
| Display operational status and other PostgreSQL-owned business data | PostgreSQL |

Deterministic matches may be promoted under the approved procedure design. Ambiguous identity changes, destructive status conflicts, exclusions, and LOR-side corrections must be classified and withheld or explicitly resolved. Reconciliation must never guess which permanent display a changed LOR prop represents.

### 4. Promote in controlled dependency order

The intended production sequence is:

1. **P1 — stages:** establish or update stage references required by downstream records while preserving existing permanent stage identity and PostgreSQL-owned fields.
2. **P2 — displays:** associate validated LOR display evidence with permanent `ref.display` identities without destructive replacement of production records.
3. **P3 — scenes:** future scene-reference promotion after stage and display identities exist and have passed reconciliation.

Procedure source and supporting documents are under `Upsert Procedures/`. A script's presence in the repository does not prove that its database definition is deployed or approved.

### 5. Verify production results and preserve evidence

After promotion, verification must confirm:

- the procedures used the explicitly approved import run;
- permanent IDs were preserved;
- expected inserts and controlled updates occurred;
- unresolved or quarantined records were not silently promoted;
- no unintended deletes or status changes occurred;
- stage, display, and scene dependencies remain valid;
- parser output, ingest summary, reconciliation results, procedure output, and verification evidence are retained as required.

## V7 Reconciliation Development

The `Upsert Procedures/reconciliation/` folder is specifically for the development work required to validate the scene-aware V7 path from LOR 6.6.4 XML through PostgreSQL.

Its purpose is to prove that:

- the scene-aware parser output is represented correctly after ingest;
- the new snapshot tables and relationships are complete and internally consistent;
- stage and display candidates are derived from the correct preview or scene evidence;
- existing permanent production identities will not be replaced, duplicated, or incorrectly reassigned;
- malformed, ambiguous, or unresolved evidence is blocked or quarantined before it can damage production records;
- revised procedures behave correctly before they are deployed.

This work is not the routine operator pipeline and does not make every file in that folder production-ready. See the [reconciliation README](./Upsert%20Procedures/reconciliation/README.md).

## Folder Roles

| Folder | Responsibility |
|---|---|
| `Basic_Query_Tools/` | Reusable inspection, diagnostic, validation, administrative, and compatibility-view SQL. |
| `ERD/` | PostgreSQL entity-relationship design files. |
| `Upsert Procedures/` | Production import/promotion procedure source, pipeline design, and operating documentation. |
| `Upsert Procedures/reconciliation/` | V7 development, investigation, reconciliation design, and validation evidence; not automatically deployable. |
| `WorkOrderDDL/` | Work-order schema DDL and prechecks. |
| `schema/` | PostgreSQL schema exports and backups maintained as repository artifacts. |

New PostgreSQL DDL, procedures, functions, views, triggers, constraints, validation SQL, and database design documentation must be created under `Postgres_sql/` in the appropriate subfolder. Documentation elsewhere may explain database behavior, but active PostgreSQL project files belong here.

## Primary Pipeline Documents

- [Production import and reconciliation procedure](./Upsert%20Procedures/00_LOR_Production_Import_and_Reconciliation_Procedure.md)
- [Production promotion pipeline design](./Upsert%20Procedures/01_LOR_Production_Promotion_Pipeline_Design.md)
- [Reconciliation development workspace](./Upsert%20Procedures/reconciliation/README.md)
- [LOR display reconciliation SQL design](./Upsert%20Procedures/reconciliation/LOR_Display_Reconciliation_SQL_Design.md)
