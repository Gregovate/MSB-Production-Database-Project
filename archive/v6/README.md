# LOR V6 Archive

This directory preserves the superseded V6 parser, operator instructions, setup
guides, original PostgreSQL ingest, changelog, and related planning material for
historical reference.

V6 is **not** the current production workflow. Do not run these instructions or
use `parse_props_v6.py` or `lor_output_v6.db` for a production import.

The current production workflow uses the V7 scene-aware parser and SQLite
snapshot, followed by the protected PostgreSQL ingest and reconciliation
process documented in:

`Postgres_sql/Upsert Procedures/00_LOR_Production_Import_and_Reconciliation_Procedure.md`

Historical filenames and commands are intentionally unchanged inside this
archive so the evidence remains understandable.
