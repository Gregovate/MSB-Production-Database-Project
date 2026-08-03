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
   - Returns aggregate identity-classification and projected-change counts.
   - Separately counts exact identity matches that still project a production
     field change.

4. `04_latest_ingest_p2_action_report.sql`
   - Returns only display candidates requiring a production action, operator decision, source correction, or defer decision.
   - Excludes unchanged exact matches and nonphysical rows from detail.
   - Includes exact identity matches with projected changes for approval or
     `DEFER`.
   - Includes scoped `source_prop_id` evidence separately from the unscoped
     `lor_prop_id` proposed for production.

5. `05_latest_ingest_integrity_checks.sql`
   - Checks duplicate production display names.
   - Checks duplicate production LOR UUID links.
   - Checks `raw_prop_id` completeness in props, subprops, and scene memberships.
   - Verifies each scene membership's scoped row and `raw_prop_id` agree.
   - Detects one `raw_prop_id` associated with multiple nonblank LOR comments,
     including hidden and SPARE rows.
   - Reports SPARE rows whose required LOR Comment is missing or invalid.

6. `06_latest_ingest_scene_preflight.sql`
   - Resolves current scene identity and stage evidence without production writes.

7. `07_latest_ingest_scene_display_preflight.sql`
   - Resolves scene membership to permanent `ref.display.display_id` through
     unscoped `raw_prop_id` while retaining scoped `prop_id` as source evidence.

8. `08_latest_ingest_p2_display_identity_gate.sql`
   - Summarizes identity classifications and projected changes; exact identity
     does not hide a proposed production update.

9. `09_current_p2_projected_write_validation.sql`
   - Projects permitted P2 changes without executing them.
   - Rechecks the exact captured source row and uses `raw_prop_id` for the
     proposed `ref.display.lor_prop_id` association.
   - Does not compare or project `ref.display.color`.

## Supporting Files

- `0011_create_lor_display_reconciliation_preflight_v7.sql`
  - Current read-only display reconciliation views and summary function.

- `0012_create_lor_scene_production_tables.sql`
  - Proposed scene-related production objects under review.

- `0013_expose_current_raw_prop_identity.sql`
  - Adds `raw_prop_id` to the current props and subprops view interfaces.
  - Replaces views only and performs no snapshot or production-data writes.

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
