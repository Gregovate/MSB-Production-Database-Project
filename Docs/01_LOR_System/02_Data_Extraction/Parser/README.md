# LOR Parser and Compatibility Tools

This directory owns the current V7 `.lorprev` parser, complete XML version
checker, and restricted Windows-side operator runner. LOR2DB exposes these
tools for operator convenience but does not own their XML interpretation.

## Files

| File | Purpose |
|---|---|
| `parse_props_v7_scene_parser.py` | Canonical V7 parser; atomically publishes only a fully validated SQLite snapshot |
| `lor_version_checker.py` | Parser-independent complete XML manifest; approved-version maintenance classification and strict New LOR compatibility comparison |
| `lor_operator_runner.py` | Restricted Windows/G-drive API, single-operation lock, durable read-only parser and ingest console records, digest-locked PostgreSQL ingest, candidate stale-manifest guard, approved-version structural guard, and same-parser SQLite output comparison used by the authenticated LOR2DB website |
| `test_lor_version_checker.py` | Regression tests for Scene count/structure, unused fields, ChannelGrid, and other delimiter-position changes |
| `test_lor_version_checker_maintenance.py` | Regression tests proving same-version display additions/removals and authored value diversity remain nonblocking |
| `test_lor_version_checker_motion_fx.py` | Regression tests proving same-version Motion FX row maintenance remains nonblocking |
| `test_lor_operator_runner.py` | Regression tests for version-scoped paths, stale manifests, SQLite output comparison, Revision handling, and approval history |
| `test_parse_props_console_encoding.py` | Regression test preventing Windows console/log encoding from aborting parser execution |
| `test_parse_props_atomic_publish.py` | Regression tests for transient Windows file-lock retry and fail-closed atomic publication |

The repository-root `run_lor_runner.ps1` is the canonical deployment and
runtime launcher. It owns DPAPI secret storage, the logged-in-user Scheduled
Task, authenticated status checks, and SSH pairing to the Linux API. Do not
assemble runner environment variables or tokens manually.

## Operating Boundary

Use the main LOR2DB parser page for normal repeatable production SQLite builds.
Use the separate guided version-check page only when evaluating a different LOR
software version. Direct command-line execution remains supported for
engineering and recovery. Parser execution never starts PostgreSQL ingest.

The runner accepts only one state-changing or parser request at a time. A
second request is rejected instead of queued. Each browser parser attempt
records its terminal status and complete console output in the version review
tree; the API returns a bounded read-only copy for diagnosis. Restarting the
runner changes any stale `RUNNING` marker to `INTERRUPTED` rather than leaving
the website in a false running state.

An approved Current LOR folder may receive ordinary preview-authoring edits and
be parsed repeatedly. Adding/removing Displays or Scenes, changing nullable
attribute values, using different integer/decimal authoring values, changing
non-parser delimiter payloads, and adding/removing Motion FX rows remain
inventoried as informational evidence. They do not block the approved-version
parser run. Newly encountered XML vocabulary remains blocking because it can
indicate a parser contract change. A New LOR candidate remains fully strict:
changing any reviewed candidate file after Version Check invalidates that check
and requires it to be rerun.

The current Office Desktop runner task uses the logged-in Greg account because
that Windows session owns the mapped `G:` drive. Screen locking does not stop
the task. Closing its interactive runner window, logging out, or rebooting can
leave the website runner unavailable without affecting PostgreSQL or an
already committed snapshot.

That Office Desktop deployment is temporary/test infrastructure. The approved
permanent host is `PRINT-SERVER` (`192.168.5.56`) under a separate unattended
Scheduled Task. The transfer is not yet deployed. Before cutover, the
`PRINT-SERVER\Print Service` task context must have durable headless access to
the approved preview/state/output paths, and the runner launcher must support
the accepted at-startup noninteractive task model. Do not disable the Office
Desktop listener or re-pair Linux until the controlled transfer acceptance
gates pass.

See:

- [Parser architecture](../LOR_Preview_Parser_Architecture.md)
- [XML structure specification](../LOR_Preview_File_Structure_Specification.md)
- [Version compatibility procedure](../LOR_Preview_Version_Compatibility_Review.md)
- [Approved-version maintenance rule](../LOR_Approved_Version_Maintenance_Compatibility_Rule_2026-08-25.md)
- [SQLite output contract](../LOR_SQLite_Output_Database_Structure.md)
- [LOR2DB ingest handoff](../../../../LOR2DB/01_Ingest/README.md)
- [Runner host transition, operations, and disaster recovery](../../../../LOR2DB/Application/Office_PC_Runner_Operations_and_Disaster_Recovery.md)
