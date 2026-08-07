# LOR2DB Reconciliation

This directory is the documentation and implementation portal for moving a completed LOR snapshot through reconciliation, controlled production promotion, validation, and reporting.

It belongs to the **LOR2DB technical workflow**. Operational Directus SOPs are documented separately under `docs/02_Production_Database/02_Operational_SOPs/` and are not maintained here.

## Start Here

| Path | Purpose |
|---|---|
| [00_LOR_Production_Import_and_Reconciliation_Procedure.md](00_LOR_Production_Import_and_Reconciliation_Procedure.md) | Controlled production procedure and operator-facing workflow |
| [01_LOR_Production_Promotion_Pipeline_Design.md](01_LOR_Production_Promotion_Pipeline_Design.md) | Production promotion architecture, sequencing, and safety boundaries |
| [02_LOR_Manual_Reconciliation_Runbook.md](02_LOR_Manual_Reconciliation_Runbook.md) | Controlled fallback and recovery procedure when the secured application cannot perform the normal workflow |
| [reconciliation/](reconciliation/) | Current reconciliation SQL design, procedures, migrations, validation, operator queries, and incident evidence |

For normal operation, begin with the controlled production procedure. The secured LOR2DB application is the normal operator interface; the manual runbook is retained for fallback and recovery.

## Directory Scope

The immediate contents of this directory cover the reconciliation layer between a committed `lor_snap` snapshot and durable production data. The current workflow includes:

- reconciliation start and frozen source evidence;
- stage, display, scene, and scene-membership review;
- persisted operator decisions;
- controlled P1-P4 production promotion;
- post-write validation;
- immutable reconciliation report publication;
- controlled cancellation and recovery.

Detailed SQL-engine documentation is intentionally kept one level lower in [reconciliation/](reconciliation/) so this page can remain a stable workflow portal rather than duplicate its indexes.

## Current vs. Historical Implementation Files

The current controlled reconciliation implementation is documented and indexed under [reconciliation/](reconciliation/). Its `current_procedures/`, `migrations/`, `validation/`, and `operator_queries/` folders define the maintained reconciliation engine and its audit history.

Other SQL or utility files located directly in this directory predate portions of the current persistent reconciliation workflow or served development/migration work. Their presence does **not** make them the current production execution path. In particular, operators must not bypass the controlled reconciliation workflow by manually running older P1/P2 files.

The `archive/` directory is historical material and is not part of the normal production procedure.

## Related LOR2DB Areas

Use the parent [LOR2DB portal](../README.md) to navigate to the secured application and report-publishing components. This page intentionally links primarily to its immediate children so deeper documentation can evolve without requiring repeated link maintenance here.
