# LOR2DB Reporting

The LOR2DB Reporting subsystem provides permanent reconciliation reports for each completed production import.

These reports document the approved LOR preview source, the reconciliation process, validation results, and the approved production changes.

## Start Here

| I want to... | Go to |
|---|---|
| View the latest reconciliation report | [Open LOR2DB](https://my.sheboyganlights.org/lor2db/) and open the current report |
| Browse previous reconciliation reports | [Open the report archive](https://my.sheboyganlights.org/lor2db/reports/) |
| Understand the information contained in a reconciliation report | Review the report overview below |

Cloudflare authentication is required to access the LOR2DB application and report archive.

## Using the Reconciliation Report

The reconciliation report is the official record of each completed production reconciliation.

In addition to documenting the reconciliation process, it identifies the approved LOR preview source used for that production import and records the revision of every preview included in the reconciliation.

### Approved Preview Source

![Report Section 3 – Source Folder](../../Docs/images/LOR-recon-01.jpg)

Section 3 of every reconciliation report identifies the **Source folder** used for that reconciliation.

Use this location whenever you need the current approved LOR preview files.

**Important**

- Import previews from the Source folder shown in the latest reconciliation report.
- Do **not** edit, overwrite, or save files in that folder.
- Make changes only in your own working copy.
- The Source folder contains the approved production preview set.

The Preview Merger system is currently under development. Until it becomes part of the production workflow, the latest reconciliation report remains the authoritative reference for the approved production preview source.

## Report Overview

The reconciliation report records the complete production reconciliation, including:

- Source preview information
- Imported preview revisions
- Reconciliation decisions
- Production changes
- Validation results
- Final reconciliation status

### Report Header

![Report Header](../../Docs/images/LOR-recon-02.jpg)

The report begins with a summary of the reconciliation run, source information, and overall completion status.

### Preview Revisions

![Preview Revisions](../../Docs/images/LOR-recon-03.jpg)

This section lists the approved preview revisions that were included in the production reconciliation.

Use this information to verify that you are working from the current approved revision of a preview.

### Production Changes

![Production Changes](../../Docs/images/LOR-recon-04.jpg)

Displays the approved production changes resulting from the reconciliation.

### Validation Results

![Validation Results](../../Docs/images/LOR-recon-05.jpg)

Documents the validation checks completed before reconciliation was finalized.

### Completed Report

![Completed Report](../../Docs/images/LOR-recon-06.jpg)

Each completed reconciliation report is retained as a permanent historical record and remains available through the report archive.

## Related LOR2DB Areas

- [LOR2DB Portal](../README.md)
- [Reconciliation](../Reconciliation/README.md)
- [Application](../Application/README.md)
