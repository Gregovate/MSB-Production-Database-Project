# LOR2DB

LOR2DB moves approved Light-O-Rama preview changes into the MSB production database through a controlled review, reconciliation, validation, and reporting process.

## Start Here

**Running the production workflow:** [Open LOR2DB](https://my.sheboyganlights.org/lor2db/)

Cloudflare authentication is required, just as it is for [my.sheboyganlights.org](https://my.sheboyganlights.org/).

![LOR2DB landing page](../Docs/images/lor2db_landing_page.jpg)

The landing page shows the current LOR snapshot, reconciliation status, and the report for the current reconciliation run. Use **Report archive** to view all completed reconciliation reports, newest first.

**Completed reconciliation reports:** [Open the report archive](https://my.sheboyganlights.org/lor2db/reports/)

For procedures, recovery, and reconciliation details, go to [Reconciliation](Reconciliation/).

## What Do You Need To Do?

- [Run or understand reconciliation](Reconciliation/)
- [Work on the LOR2DB application](Application/)
- [Work on reconciliation reporting](Reporting/)

## Folder Guide

| Folder | What it contains |
|---|---|
| [Application](Application/) | LOR2DB browser application, secured API, deployment files, and application tests |
| [Reconciliation](Reconciliation/) | Production workflow, reconciliation procedures, recovery runbook, promotion logic, SQL implementation, and validation |
| [Reporting](Reporting/) | Reconciliation report publishing code and tests |

The detailed technical documentation remains in these subsystem folders. This README is only the LOR2DB navigation portal.
