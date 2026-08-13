# LOR Parser and Compatibility Tools

This directory owns the current V7 `.lorprev` parser, complete XML version
checker, and restricted Windows-side operator runner. LOR2DB exposes these
tools for operator convenience but does not own their XML interpretation.

## Files

| File | Purpose |
|---|---|
| `parse_props_v7_scene_parser.py` | Canonical V7 parser; atomically publishes only a fully validated SQLite snapshot |
| `lor_version_checker.py` | Parser-independent complete XML manifest and Current/New LOR compatibility comparison |
| `lor_operator_runner.py` | Restricted Windows/G-drive API used by the authenticated LOR2DB website |
| `test_lor_version_checker.py` | Regression tests for Scene count/structure, unused fields, ChannelGrid, and other delimiter-position changes |
| `test_lor_operator_runner.py` | Regression tests for version-scoped paths, approved-manifest retention, and approval history |
| `test_parse_props_console_encoding.py` | Regression test preventing Windows console/log encoding from aborting parser execution |
| `test_parse_props_atomic_publish.py` | Regression tests for transient Windows file-lock retry and fail-closed atomic publication |

## Operating Boundary

Use the LOR2DB website for normal version checks and parser runs. Direct command
line execution remains supported for engineering and recovery. Parser execution
never starts PostgreSQL ingest.

See:

- [Parser architecture](../LOR_Preview_Parser_Architecture.md)
- [XML structure specification](../LOR_Preview_File_Structure_Specification.md)
- [Version compatibility procedure](../LOR_Preview_Version_Compatibility_Review.md)
- [SQLite output contract](../LOR_SQLite_Output_Database_Structure.md)
- [LOR2DB ingest handoff](../../../../LOR2DB/01_Ingest/README.md)
