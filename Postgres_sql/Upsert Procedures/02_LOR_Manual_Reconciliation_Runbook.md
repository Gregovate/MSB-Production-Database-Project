# LOR Manual Reconciliation Runbook

| Document control | Value |
|---|---|
| Status | ACTIVE — manual workflow until the operator application is deployed and validated |
| Owner | GAL |
| Initial release / current revision | 2026-08-04 / 2026-08-05 |

The reusable screen and its secured backend are defined in
`tools/lor_preflight/`. This runbook remains authoritative until that backend is
deployed and production validated with Run 4.

## Purpose and Safety Boundary

This is the executable manual procedure for reconciling one completed V7 LOR snapshot. The operator never supplies an `import_run_id`; Start captures the latest eligible completed ingest once. Retain the returned `lor_reconciliation_run_id` and substitute it for `:run_id` below.

- Review queries are read-only.
- Start and decision functions write reconciliation working/audit state only.
- **Finish is the production-write boundary. It runs P1, P3, P2, and P4 atomically.**
- Never run P1–P4 directly or manually edit run status, counters, captured ingest, actions, results, or report fields.
- On any unexpected result or error, stop. Do not blindly retry a write command.

## 1. Pre-Start Check — Read Only

```sql
SELECT
    ir.import_run_id,
    ir.parser_version,
    ir.parser_completed_at,
    ir.ingest_completed_at,
    r.lor_reconciliation_run_id,
    r.status AS reconciliation_status
FROM lor_snap.import_run AS ir
LEFT JOIN ops.lor_reconciliation_run AS r
  ON r.import_run_id = ir.import_run_id
WHERE ir.ingest_completed_at IS NOT NULL
ORDER BY ir.import_run_id DESC
LIMIT 5;
```

Stop if the expected ingest is not the newest eligible completed ingest, its provenance/counts were not validated, or an unexplained reconciliation is unfinished.

## 2. Start — Reconciliation State Write Only

Run once and record the returned run number:

```sql
SELECT ops.f_start_lor_reconciliation(
    'Manual reconciliation via SQL client'
) AS reconciliation_run;
```

Verify the captured ingest and frozen state:

```sql
SELECT
    lor_reconciliation_run_id AS reconciliation_run,
    import_run_id AS captured_ingest,
    status,
    structural_failure_count,
    unresolved_count,
    deferred_count,
    blocked_count,
    validation_state,
    failure_message
FROM ops.lor_reconciliation_run
WHERE lor_reconciliation_run_id = :run_id;
```

Stop if the captured ingest is not the one checked in Step 1, structural failures are nonzero, or a failure message exists.

## 3. Review — Read Only

```sql
SELECT *
FROM ops.v_lor_reconciliation_run_review
WHERE lor_reconciliation_run_id = :run_id;

SELECT
    lor_reconciliation_group_id AS group_id,
    entity_type,
    logical_group_key,
    group_kind,
    member_count,
    effective_resolution_state,
    allowed_action_types,
    effective_action_type,
    effective_reason,
    operator_message
FROM ops.v_lor_reconciliation_group_review
WHERE lor_reconciliation_run_id = :run_id
  AND effective_resolution_state IN ('UNRESOLVED', 'DEFERRED', 'BLOCKED')
ORDER BY entity_type, logical_group_key;
```

Review evidence from the view matching each entity type:

```sql
SELECT * FROM ops.v_lor_reconciliation_operator_display_review
WHERE lor_reconciliation_run_id = :run_id
ORDER BY lor_reconciliation_group_id, lor_reconciliation_display_candidate_id;

SELECT * FROM ops.v_lor_reconciliation_operator_stage_review
WHERE lor_reconciliation_run_id = :run_id
ORDER BY lor_reconciliation_group_id, lor_reconciliation_stage_candidate_id;

SELECT * FROM ops.v_lor_reconciliation_operator_scene_review
WHERE lor_reconciliation_run_id = :run_id
ORDER BY lor_reconciliation_group_id, preview_id, scene_id;

SELECT * FROM ops.v_lor_reconciliation_operator_scene_display_review
WHERE lor_reconciliation_run_id = :run_id
ORDER BY lor_reconciliation_group_id, preview_id, scene_id, source_prop_id;
```

Only use an action listed in that group's `allowed_action_types`. Never infer permanent identity from UUID alone.

## 4. Record Decisions — Reconciliation Audit Write Only

Generic action template (including `DEFER`, `CORRECT_SOURCE_REQUIRED`, or `RESTORE_TO_LOR_REQUIRED` when offered):

```sql
SELECT ops.f_record_lor_reconciliation_action(
    :run_id,
    :group_id,
    'ACTION_FROM_ALLOWED_LIST',
    'Specific operator reason and supporting evidence.',
    NULL,
    'Manual reconciliation via SQL client'
) AS action_id;
```

Eligible multi-preview stage preservation:

```sql
SELECT ops.f_record_lor_stage_preserve_metadata_action(
    :run_id,
    :group_id,
    'Legitimate multi-preview stage; preserve permanent metadata and approve all frozen bindings.',
    'Manual reconciliation via SQL client'
) AS action_id;
```

For display reassociation, first retrieve exact candidate IDs and possible permanent identities:

```sql
SELECT
    lor_reconciliation_display_candidate_id AS candidate_id,
    candidate_key,
    current_display_name,
    proposed_display_name,
    display_id,
    uuid_display_id,
    name_display_id,
    preview_name,
    operator_message
FROM ops.lor_reconciliation_display_candidate
WHERE lor_reconciliation_run_id = :run_id
  AND lor_reconciliation_group_id = :group_id
ORDER BY lor_reconciliation_display_candidate_id;
```

Then map every candidate exactly once to a different established `display_id`:

```sql
SELECT ops.f_record_lor_reconciliation_action(
    :run_id,
    :group_id,
    'REASSOCIATE_DISPLAY',
    'Specific reason identifying each selected permanent display.',
    '{"CANDIDATE_ID_1":"DISPLAY_ID_1","CANDIDATE_ID_2":"DISPLAY_ID_2"}'::jsonb,
    'Manual reconciliation via SQL client'
) AS action_id;
```

Stop if the complete atomic mapping is uncertain.

## 5. Recheck After Decisions — Read Only

```sql
SELECT
    lor_reconciliation_group_id AS group_id,
    entity_type,
    logical_group_key,
    effective_resolution_state,
    effective_action_type,
    effective_reason,
    acted_at,
    acted_by_application
FROM ops.v_lor_reconciliation_group_review
WHERE lor_reconciliation_run_id = :run_id
ORDER BY entity_type, logical_group_key;

SELECT
    lor_reconciliation_run_id AS reconciliation_run,
    import_run_id AS captured_ingest,
    status,
    structural_failure_count,
    unresolved_count,
    deferred_count,
    blocked_count,
    validation_state,
    failure_message
FROM ops.lor_reconciliation_run
WHERE lor_reconciliation_run_id = :run_id;
```

`READY_TO_FINISH` means every decision-required group has an action. Deferred or source-correction groups remain exceptions and will be left unchanged.

## 6. Pre-Finish Gate — Read Only

```sql
SELECT
    lor_reconciliation_run_id AS reconciliation_run,
    import_run_id AS captured_ingest,
    status,
    structural_failure_count,
    unresolved_count,
    deferred_count,
    blocked_count,
    validation_state,
    failure_message
FROM ops.lor_reconciliation_run
WHERE lor_reconciliation_run_id = :run_id;

SELECT
    lor_reconciliation_group_id AS group_id,
    entity_type,
    logical_group_key,
    effective_resolution_state,
    effective_action_type,
    effective_reason,
    operator_message
FROM ops.v_lor_reconciliation_group_review
WHERE lor_reconciliation_run_id = :run_id
  AND effective_resolution_state IN ('UNRESOLVED', 'DEFERRED', 'BLOCKED')
ORDER BY entity_type, logical_group_key;

SELECT count(*) AS committed_production_results_before_finish
FROM ops.lor_reconciliation_result
WHERE lor_reconciliation_run_id = :run_id
  AND committed
  AND result_class IN ('ADDED', 'UPDATED', 'REASSOCIATED', 'STATUS_CHANGED');
```

Required: `READY_TO_FINISH`, zero structural failures, zero unresolved groups, every remaining exception intentional, and zero committed production results.

## 7. Finish — Production Write Boundary

> **WARNING: This command atomically runs P1, P3, P2, and P4 against production, validates the result, and advances the run to `REPORTING`. Execute only after approving Step 6.**

```sql
CALL ops.p_finish_lor_reconciliation(
    :run_id,
    'Manual reconciliation via SQL client'
);
```

Run once. If it errors, preserve the full error and stop. Do not run individual promotion procedures.

## 8. Post-Finish Validation — Read Only

```sql
SELECT
    r.lor_reconciliation_run_id AS reconciliation_run,
    r.import_run_id AS captured_ingest,
    r.status,
    r.validation_state,
    r.unresolved_count,
    count(*) FILTER (WHERE gr.effective_resolution_state = 'UNRESOLVED')::integer AS effective_unresolved_count,
    r.deferred_count,
    count(*) FILTER (WHERE gr.effective_resolution_state = 'DEFERRED')::integer AS effective_deferred_count,
    r.blocked_count,
    count(*) FILTER (WHERE gr.effective_resolution_state = 'BLOCKED')::integer AS effective_blocked_count,
    r.failure_message
FROM ops.lor_reconciliation_run AS r
LEFT JOIN ops.v_lor_reconciliation_group_review AS gr
  ON gr.lor_reconciliation_run_id = r.lor_reconciliation_run_id
WHERE r.lor_reconciliation_run_id = :run_id
GROUP BY r.lor_reconciliation_run_id;

SELECT entity_type, result_class, reason_code, committed, count(*) AS result_count
FROM ops.lor_reconciliation_result
WHERE lor_reconciliation_run_id = :run_id
GROUP BY entity_type, result_class, reason_code, committed
ORDER BY entity_type, result_class, reason_code, committed;
```

Required: `REPORTING`, `PASSED`, no failure message, and stored counters equal effective counters. Do not publish otherwise.

## 9. Publish and Verify

From the repository root in Windows PowerShell:

```powershell
.\tools\publish_lor_reconciliation_report.ps1 `
    -ReconciliationRunId :run_id
```

Expected output begins with `REPORT_PATH=`. Then verify:

```sql
SELECT
    lor_reconciliation_run_id AS reconciliation_run,
    import_run_id AS captured_ingest,
    status,
    validation_state,
    report_path,
    report_url,
    report_published_at,
    report_sha256
FROM ops.lor_reconciliation_run
WHERE lor_reconciliation_run_id = :run_id;
```

The terminal status, `PASSED`, and all report fields must be populated. Never overwrite the registered report.

## 10. Evaluation Copies and Report Index

```powershell
# Render a completed run without changing its registered report or database state.
.\tools\publish_lor_reconciliation_report.ps1 `
    -ReconciliationRunId :run_id `
    -EvaluationCopy

# Rebuild reports/index.html without a database password.
.\tools\publish_lor_reconciliation_report.ps1 -RefreshIndex
```

## 11. Cancel Instead of Finish

Cancel only before promotion when the source snapshot is wrong. This deletes the captured snapshot but does not promote production data.

```sql
CALL ops.p_cancel_lor_reconciliation(
    :run_id,
    'Specific reason the captured source snapshot must be rejected.',
    'Manual reconciliation via SQL client'
);
```

The run advances to `REPORTING`; publish its cancellation report using Step 9. Correct the LOR source, parse, and ingest again. Never reconstruct the deleted snapshot manually.

## Recovery Rules

| State or failure | Required action |
|---|---|
| `FAILED` after Start | Inspect `failure_message`; diagnose before another Start. |
| `AWAITING_DECISIONS` | Resume Steps 3–5. |
| `READY_TO_FINISH` | Repeat Step 6 before Finish or Cancel. |
| Finish error | Verify rollback and diagnose; never call P1–P4 directly. |
| Stuck `PROMOTING` / `VALIDATING` | Investigate the transaction/session before retrying anything. |
| `REPORTING` + `PASSED` | Publish only; never rerun Finish. |
| Publisher error | Leave `REPORTING`; fix publication and retry only the publisher. |
| Terminal run | Never reopen; use `-EvaluationCopy` for revisions. |

## Related Documents

- `00_LOR_Production_Import_and_Reconciliation_Procedure.md`
- `01_LOR_Production_Promotion_Pipeline_Design.md`
- `reconciliation/LOR_Display_Reconciliation_SQL_Design.md`
