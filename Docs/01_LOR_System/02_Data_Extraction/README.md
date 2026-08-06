# V7 Data Extraction and Reconciliation

This directory is the current documentation entry point for LOR extraction.
The former V6 quickstart, processing rules, troubleshooting guide, SQLite
cheat sheet, comparison logic, and import instructions are preserved under
`archive/v6/Docs/01_LOR_System/02_Data_Extraction/`.

## Current workflow

1. Export the clean authoritative V7 preview set from the approved Master PC.
2. Run `LOR/ingest/parse_props_v7_scene_parser.py`.
3. Verify parser preflight and completion against `lor_output_v7_scene.db`.
4. Run the protected `LOR/ingest/postgres_run_ingest_v7.ps1` snapshot ingest.
5. Open `https://lortodb.sheboyganlights.org/lor2db/`.
6. Start or resume reconciliation for the snapshot detected by the page.
7. Review decisions, Finish, validate, and open the immutable report.

The exact production controls, stop conditions, Run 4 baseline, and future
feature boundary are maintained in:

`LOR2DB/Reconciliation/00_LOR_Production_Import_and_Reconciliation_Procedure.md`

The SQL-only fallback and recovery sequence is maintained in:

`LOR2DB/Reconciliation/02_LOR_Manual_Reconciliation_Runbook.md`

Do not enter or infer an `import_run_id`, run P1-P4 directly, or use archived V6
instructions to perform a current import.
