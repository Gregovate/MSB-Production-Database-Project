# Parser-controlled preview distribution

Issue #299 / PR #300. User decision: passed parser validation controls preview
publication; PostgreSQL ingest/reconciliation is a separate approval.

Catalog review binds the exact current export manifest, approved LOR version,
latest passed current parser activity, matching parser-result activity ID,
production SQLite SHA256, and SQLite provenance (parser binary hash, source
manifest, version, status/validation, run mode and folder). Evidence comes from
runner state, never the browser request. Both review and publication repeat the
checks. Controller/network/channel edits can therefore be distributed for
programming and testing before ingest. Only an authorized publisher can approve.

The publication retains the last reconciled database evidence and Run number as
historical context; parser_validation and distribution_authority explicitly record
the independent distribution authority. The existing schema-3 PC updater can
consume these exact accepted preview bytes. No programmer update or PostgreSQL
change is required to deploy this runner correction.

Successful current parser runs retain XML comparison evidence immediately.
The ingest-time dependency introduced by the rollover patch is removed.
Existing baseline/publication records are preserved; a fresh parser-validated
export may initialize a new evidence context after a database run rollover.
The web page labels parser-validated updates accurately without asserting that
controller changes are already ingested.

Validation: 8 parser-authority tests, 9 rollover tests, 89 catalog tests (3
fixture-dependent skips); JavaScript syntax check. Native Windows installer
preflight and live parser publication remain pending. No ingest or publication
performed by engineering.
