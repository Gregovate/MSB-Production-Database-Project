# LOR2DB Reconciliation

This directory contains the documentation for reviewing completed LOR snapshots, promoting approved changes into the MSB production database, validating the results, and publishing reconciliation reports.

It is part of the **LOR2DB technical workflow**. Operational Directus SOPs are maintained separately under `docs/02_Production_Database/02_Operational_SOPs/`.

## Start Here

| I want to... | Go to |
|---|---|
| Run the normal production reconciliation workflow | [00_LOR_Production_Import_and_Reconciliation_Procedure.md](00_LOR_Production_Import_and_Reconciliation_Procedure.md) |
| Understand how the production workflow is organized | [01_LOR_Production_Promotion_Pipeline_Design.md](01_LOR_Production_Promotion_Pipeline_Design.md) |
| Recover when the normal application cannot be used | [02_LOR_Manual_Reconciliation_Runbook.md](02_LOR_Manual_Reconciliation_Runbook.md) |
| View the reconciliation engineering documentation | [reconciliation/README.md](reconciliation/README.md) |

For normal operation, begin with the Production Import and Reconciliation Procedure. The secured LOR2DB application is the normal operator interface. The manual reconciliation procedure is intended only for controlled recovery situations.

## Folder Guide

| Folder | What it contains |
|---|---|
| [reconciliation/README.md](reconciliation/README.md) | Reconciliation engineering documentation, SQL procedures, migrations, validation, operator queries, and historical implementation records. |
| [archive/](archive/) | Historical material retained for reference. Not part of the current production workflow. |

## Current Production Workflow

Normal production work should always follow the controlled reconciliation procedure.

The current reconciliation engine, production procedures, migrations, validation scripts, and supporting engineering documentation are maintained under [reconciliation/README.md](reconciliation/README.md).

Older SQL and utility files located directly in this directory remain for historical reference or development history and are not part of the normal production workflow.

## Related LOR2DB Areas

Return to the [LOR2DB portal](../README.md) to access the secured application, reconciliation reports, and other LOR2DB subsystems.
