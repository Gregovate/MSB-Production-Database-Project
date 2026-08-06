# LOR2DB

LOR2DB is the PostgreSQL reconciliation side of the LOR import pipeline. It begins after a complete SQLite snapshot has been committed to `lor_snap` and ends after controlled promotion, validation, and immutable report publication.

| Path | Responsibility |
|---|---|
| `Application/` | Secured API, operator review UI, landing page, grants, and service examples |
| `Reconciliation/` | Controlled procedure, decision engine, migrations, P1-P4 promotion, validation, and recovery runbook |
| `Reporting/` | Immutable report publisher and tests |

Production application: `https://lortodb.sheboyganlights.org/lor2db/`

The browser application never accepts an operator-entered ingest ID and never exposes arbitrary SQL, credentials, commands, or direct P1-P4 execution.

Start with [the controlled production procedure](Reconciliation/00_LOR_Production_Import_and_Reconciliation_Procedure.md).
