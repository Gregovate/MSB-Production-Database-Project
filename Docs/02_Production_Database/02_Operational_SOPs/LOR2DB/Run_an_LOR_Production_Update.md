# Run an LOR Production Update

[↑ LOR2DB Procedures](README.md)

| Document Control | Value |
|---|---|
| Document Type | Operational SOP |
| System | Production Database — LOR2DB |
| Task | Parse approved LOR previews, ingest the reviewed snapshot, and reconcile production |
| Audience | Authorized LOR2DB operators |
| Status | CURRENT |
| Owner | MSB Database Administrator |
| Last Reviewed | 2026-08-17 |
| Keywords | LOR2DB, parser, SQLite, ingest, reconciliation, production report |

## Revision History

| Date | Change |
|---|---|
| 2026-08-17 | Initial controlled browser procedure aligned to the deployed parser-to-report workflow validated by ingest 48 and reconciliation Run 7. |

## Purpose

Use this procedure after approved preview files have changed and those changes
must be reviewed and applied to the Production Database.

This procedure deliberately keeps three approvals separate:

1. build and review the SQLite parser output;
2. ingest that exact output into PostgreSQL; and
3. reconcile and apply approved production changes.

## Before You Start

- Use an account authorized for LOR2DB.
- Confirm the approved preview folder shown by LOR2DB is the intended source.
- Make preview corrections in Light-O-Rama or the approved preview source—not
  by manually editing SQLite or PostgreSQL.
- Use **Check new version** instead if you are evaluating a different
  Light-O-Rama software version.

## Procedure

1. Open [LOR2DB](https://my.sheboyganlights.org/lor2db/).
2. Confirm the **Approved LOR version** and **Preview source folder**.
3. Select **Run parser**.
4. Review the parser console, validation status, counts, reports, SQLite path,
   and SQLite SHA-256.
5. If anything is wrong, correct the source previews and select **Run parser**
   again. Repeat this step as many times as necessary. Each run rebuilds and
   replaces the SQLite output; it does not ingest PostgreSQL.
6. When the displayed output looks correct, select
   **Parser output looks correct — ready for ingest**.
7. Select **Ingest to PostgreSQL**. The ingest is locked to the exact SQLite
   SHA-256 that you approved.
8. Review the PostgreSQL ingest console. Continue only when the page reports
   that the ingest completed and shows its PostgreSQL import run.
9. Select **Start reconciliation**.
10. Review every item requiring a decision. Use the complete evidence shown on
    screen, choose the appropriate decision, optionally add a useful audit
    comment, and select **Save decision**.
11. When all decisions are saved, select **Continue to final review**.
12. Verify the actions listed under **Final application review**. Select
    **Back to review** if anything is incorrect.
13. When the listed actions are correct, select **Proceed**, enter a concise
    reason, and select **Proceed with production update**.
14. Confirm the reconciliation completed, validation passed, and the immutable
    final report opens.

## Expected Result

- The parser result is `PASSED`.
- PostgreSQL contains one completed snapshot for the approved SQLite digest.
- Reconciliation is terminal and validation is `PASSED`.
- The report archive contains the immutable reconciliation report.
- The dashboard no longer shows an unfinished run.

## If Something Is Wrong

- **Parser output is wrong:** correct the preview source and rerun the parser.
  Do not ingest it.
- **Runner unavailable:** confirm the Office PC is signed in, Google Drive has
  restored `G:`, and the managed runner reports healthy. Do not substitute an
  unreviewed file or path.
- **Ingest fails before commit:** do not start reconciliation. Preserve the
  console output and resolve the failure before retrying.
- **Ingest console reports a failure after showing a completed import:** return
  to the dashboard or refresh the parser page. Digest-idempotent recovery must
  reuse the committed import instead of creating another snapshot.
- **A reconciliation choice is missing:** do not force a different action.
  Preserve the evidence and escalate the database rule or grant problem.
- **You are not ready to apply production changes:** select **Back to review**.
- **Cancellation is required:** select **Cancel reconciliation**, enter the
  reason, and verify the terminal cancellation proof and report before closing
  the browser. A cancelled run does not change production and its disposable
  snapshot cannot be reused.
- **The application is unavailable:** stop normal operation. Use the manual
  runbook only as a controlled engineering/recovery procedure.

## Related Documents

- [LOR2DB technical portal](../../../../LOR2DB/README.md)
- [LOR Production Import and Reconciliation Procedure](../../../../LOR2DB/02_Reconciliation/00_LOR_Production_Import_and_Reconciliation_Procedure.md)
- [Manual Reconciliation Runbook — fallback only](../../../../LOR2DB/02_Reconciliation/02_LOR_Manual_Reconciliation_Runbook.md)
- [LOR Preview Version Compatibility Review](../../../01_LOR_System/02_Data_Extraction/LOR_Preview_Version_Compatibility_Review.md)
- [Office PC Runner Operations and Disaster Recovery](../../../../LOR2DB/Application/Office_PC_Runner_Operations_and_Disaster_Recovery.md)

---

[↑ LOR2DB Procedures](README.md)
