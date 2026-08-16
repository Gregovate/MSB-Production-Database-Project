# LOR Parser and Compatibility Tools

This directory owns the current V7 `.lorprev` parser, complete XML version
checker, and restricted Windows-side operator runner. LOR2DB exposes these
tools for operator convenience but does not own their XML interpretation.

## Files

| File | Purpose |
|---|---|
| `parse_props_v7_scene_parser.py` | Canonical V7 parser; atomically publishes only a fully validated SQLite snapshot |
| `lor_version_checker.py` | Parser-independent complete XML manifest and Current/New LOR compatibility comparison |
| `lor_operator_runner.py` | Restricted Windows/G-drive API, single-operation lock, durable read-only parser and ingest console records, digest-locked PostgreSQL ingest, candidate stale-manifest guard, approved-version structural guard, and same-parser SQLite output comparison used by the authenticated LOR2DB website |
| `test_lor_version_checker.py` | Regression tests for Scene count/structure, unused fields, ChannelGrid, and other delimiter-position changes |
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
be parsed repeatedly. Each run rebuilds the live manifest and rejects only a
parser-breaking XML contract change relative to the approved LOR manifest. A
New LOR candidate remains stricter: changing any reviewed candidate file after
Version Check invalidates that check and requires it to be rerun.

The production runner task uses the logged-in Greg account because that Windows
session owns the mapped `G:` drive. Screen locking does not stop the task. After
a reboot, the runner remains unavailable until Greg signs in and Google Drive
restores `G:`; the website reports the runner as unavailable without affecting
command-line parser use or PostgreSQL.

See:

- [Parser architecture](../LOR_Preview_Parser_Architecture.md)
- [XML structure specification](../LOR_Preview_File_Structure_Specification.md)
- [Version compatibility procedure](../LOR_Preview_Version_Compatibility_Review.md)
- [SQLite output contract](../LOR_SQLite_Output_Database_Structure.md)
- [LOR2DB ingest handoff](../../../../LOR2DB/01_Ingest/README.md)
