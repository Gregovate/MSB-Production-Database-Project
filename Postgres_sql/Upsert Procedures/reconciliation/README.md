# V7 Reconciliation Development Workspace

This folder contains the design and read-only validation work required to protect production `ref` data before the scene-aware LOR snapshot is promoted through P1 and P2.

The parser and PostgreSQL ingest populate `lor_snap`. The files in this folder begin with the latest completed ingest already present in `lor_snap` and evaluate the consequences of applying that snapshot to production identities and relationships.

## Current Latest-Ingest Preflight Suite

Run these files individually in numeric order. Each file returns one exportable result set and selects the latest ingest automatically. No operator supplies or hard-codes an `import_run_id`.

1. `01_latest_ingest_context.sql`
   - Captures the latest ingest.
   - Returns its timestamp and snapshot row counts.

2. `02_latest_ingest_p1_stage_preflight.sql`
   - Evaluates preview and populated-scene stage evidence.
   - Compares the latest LOR stage evidence with `ref.stage`.
   - Does not call or modify P1.

3. `03_latest_ingest_p2_summary.sql`
   - Returns aggregate display-classification counts.
   - Counts exact matches but does not report them individually.

4. `04_latest_ingest_p2_action_report.sql`
   - Returns only display candidates requiring a production action, operator decision, source correction, or defer decision.
   - Excludes exact matches, nonphysical rows, and expected preview relocation rows from the detailed action list.

5. `05_latest_ingest_integrity_checks.sql`
   - Checks duplicate production display names.
   - Checks duplicate production LOR UUID links.
   - Reports SPARE rows whose required LOR Comment is missing or invalid.

## Supporting Files

- `00_create_lor_display_reconciliation_preflight.sql`
  - Current prototype object-creation SQL for the display reconciliation views and summary function.
  - Must be reviewed and revised before it becomes an approved production definition.

- `02_create_lor_scene_production_tables.sql`
  - Proposed scene-related production objects under review.

- `LOR_Display_Reconciliation_SQL_Design.md`
  - Current design authority for the preflight, identity-preservation, operator-decision, defer, and reporting model.

## Safety Boundary

All numbered latest-ingest preflight scripts are read-only:

- They do not call P1 or P2.
- They do not insert, update, or delete production data.
- They do not require an operator-selected run number.
- They do not authorize production promotion.

P1 and P2 remain disabled until the latest-ingest preflight classifications and proposed changes are validated against production data.

Run-specific reconciliation scripts are not retained in this folder. One-time historical decisions belong in the database audit history or Git history, not in the current operator testing suite.
