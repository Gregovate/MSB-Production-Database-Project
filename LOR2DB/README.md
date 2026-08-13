# LOR2DB

LOR2DB moves approved Light-O-Rama preview changes into the MSB production database through a controlled ingest, reconciliation, validation, and reporting process.

## Start Here

**Running the production workflow:** [Open LOR2DB](https://my.sheboyganlights.org/lor2db/)

Cloudflare authentication is required, just as it is for [my.sheboyganlights.org](https://my.sheboyganlights.org/).

![LOR2DB landing page](../Docs/images/lor2db_landing_page.jpg)

The landing page shows the approved/current and candidate LOR versions, XML
compatibility and parser controls, the current PostgreSQL snapshot,
reconciliation status, and the current reconciliation report. Use **Report
archive** to view all completed reconciliation reports, newest first.

**Completed reconciliation reports:** [Open the report archive](https://my.sheboyganlights.org/lor2db/reports/)

For production reconciliation procedures and recovery guidance, go to [Reconciliation](02_Reconciliation/README.md).

## What Do You Need To Do?

- [Run/check the parser and then perform the separate PostgreSQL ingest](01_Ingest/README.md)
- [Run or understand reconciliation](02_Reconciliation/README.md)
- [Work on the LOR2DB application](Application/README.md)
- [View and understand reconciliation reports](03_Reporting/README.md)

## Folder Guide

| Folder | What it contains |
|---|---|
| [01_Ingest](01_Ingest/README.md) | PostgreSQL snapshot ingest and the handoff from the validated V7 SQLite file |
| [02_Reconciliation](02_Reconciliation/README.md) | Production reconciliation procedures, recovery guidance, and supporting engineering documentation |
| [03_Reporting](03_Reporting/README.md) | How to view, use, and understand production reconciliation reports |
| [Application](Application/README.md) | Engineering documentation for the LOR2DB browser application, secured API, deployment, and testing |

The detailed technical documentation remains in these subsystem folders. This README is only the LOR2DB navigation portal.
