# LOR2DB

LOR2DB moves approved Light-O-Rama preview changes into the MSB production database through a controlled review, reconciliation, validation, and reporting process.

## Start Here

**Running the production workflow:** [Open LOR2DB](https://my.sheboyganlights.org/lor2db/)

Cloudflare authentication is required, just as it is for [my.sheboyganlights.org](https://my.sheboyganlights.org/).

![LOR2DB landing page](../Docs/images/lor2db_landing_page.jpg)

The landing page shows the current LOR snapshot, reconciliation status, and the report for the current reconciliation run. Use **Report archive** to view all completed reconciliation reports, newest first.

**Completed reconciliation reports:** [Open the report archive](https://my.sheboyganlights.org/lor2db/reports/)

For production reconciliation procedures and recovery guidance, go to [Reconciliation](Reconciliation/README.md).

## What Do You Need To Do?

- [Run or understand reconciliation](Reconciliation/README.md)
- [Work on the LOR2DB application](Application/README.md)
- [View and understand reconciliation reports](Reporting/README.md)

## Folder Guide

| Folder | What it contains |
|---|---|
| [Application](Application/README.md) | Engineering documentation for the LOR2DB browser application, secured API, deployment, and testing |
| [Reconciliation](Reconciliation/README.md) | Production reconciliation procedures, recovery guidance, and supporting engineering documentation |
| [Reporting](Reporting/README.md) | How to view, use, and understand production reconciliation reports |

The detailed technical documentation remains in these subsystem folders. This README is only the LOR2DB navigation portal.
