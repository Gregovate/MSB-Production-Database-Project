# LOR2DB

LOR2DB moves approved Light-O-Rama preview changes into the MSB production database through a controlled review, reconciliation, validation, and reporting process.

## Start Here

**Running the production workflow:** [Open LOR2DB](https://my.sheboyganlights.org/lor2db/)

Cloudflare authentication is required, just as it is for [my.sheboyganlights.org](https://my.sheboyganlights.org/).

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
