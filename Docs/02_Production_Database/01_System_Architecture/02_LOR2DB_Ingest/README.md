# LOR2DB Ingest

This subsystem documents how authoritative LOR preview data enters the Production Database architecture.

## Current State

LOR2DB is a separate implementation project area. Its ingest pipeline parses the authoritative LOR preview set, creates scene-aware snapshots, and loads PostgreSQL snapshot data used by reconciliation and downstream operational systems.

This architecture folder does not duplicate the LOR2DB implementation documentation.

## Design Intent

LOR remains authoritative for show topology and wiring configuration. LOR2DB is the controlled data bridge from LOR into PostgreSQL.

Data flow:

`LOR -> Office PC parser/runner -> SQLite snapshot -> PostgreSQL ingest -> reconciliation -> operational/reference data`

The authenticated browser does not execute Windows/G-drive work on the Linux
web server. The Linux LOR2DB API calls a restricted listener on the designated
Office PC for version checking, repeatable parser runs, and digest-locked
ingest. That listener depends on the correct Windows account being logged in,
the mapped `G:` drive, account-bound DPAPI credentials, its Scheduled Task,
private-LAN firewall access from the database server, and the Linux pairing
configuration.

If the listener is unavailable, new version checks, parser runs, and browser
ingests stop. Existing PostgreSQL data, reports, and an already-started
reconciliation do not depend on that listener. The controlled installation,
restart, and replacement-PC procedure is the [Office PC Runner Operations and
Disaster Recovery runbook](../../../../LOR2DB/Application/Office_PC_Runner_Operations_and_Disaster_Recovery.md).

## Authoritative Sources

- [LOR2DB project](../../../../LOR2DB/README.md)
- [LOR2DB ingest](../../../../LOR2DB/01_Ingest/README.md)
- [LOR2DB reconciliation](../../../../LOR2DB/02_Reconciliation/README.md)
- [Office PC runner operations and disaster recovery](../../../../LOR2DB/Application/Office_PC_Runner_Operations_and_Disaster_Recovery.md)

## Boundaries

This subsystem owns the Production Database architectural dependency on LOR2DB. Parser code, ingest scripts, reconciliation implementation, validation, and reporting remain documented with the LOR2DB project.

LOR2DB does not transfer topology-authoring authority from LOR to PostgreSQL.

## Related Systems

- [Database Foundation](../01_Database_Foundation/README.md)
- [Production Database Architecture](../README.md)

## Resume Development

For ingest or reconciliation work, begin with the current LOR2DB README and implementation documentation. Update this handoff only when the Production Database dependency or system boundary changes.
