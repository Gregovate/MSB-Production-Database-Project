# MSB Production Database Project

This repository is the source of truth for the Making Spirits Bright production systems: the Light-O-Rama input system, the authoritative PostgreSQL production database, and the LOR2DB reconciliation application.

V7 is the current supported breakpoint. Superseded V6, spreadsheet, Excel-report, and completed migration material is retained under `archive/` and is not part of production operation.

## System map

| Path | System | Status |
|---|---|---|
| `LOR/` | LOR-side applications and tools, including Preview Merger and FormView | Production support; FormView is transitional |
| `Database/` | PostgreSQL schema, queries, database tools, and engineering resources | Production authority |
| `LOR2DB/` | V7 ingest, reconciliation, operator application, promotion, validation, and reporting | Production |
| `Docs/` | Authoritative system definitions, engineering documents, and operator procedures | Current documentation |
| `Utilities/` | Current cross-system utilities | Active support |
| `System_Documentation/` | Documentation standards, maintenance rules, and automation planning | Documentation control |
| `archive/` | Superseded workflows, completed migrations, old versions, and historical evidence | Nonproduction |

## Production LOR-to-database flow

The normal production workflow is operated from the secured
[LOR2DB website](https://my.sheboyganlights.org/lor2db/). The parser remains a
separate, repeatable approval step: operators may correct previews and run it
as many times as necessary before approving one exact SQLite output for ingest.
The browser then performs the fixed digest-locked PostgreSQL ingest, displays
its console output, and enables reconciliation only after ingest succeeds.

```text
Authoritative LOR previews
    -> Run parser in LOR2DB
    -> Docs/01_LOR_System/02_Data_Extraction/Parser/parse_props_v7_scene_parser.py
    -> lor_output_v7_scene.db

       STOP / REVIEW CHECKPOINT
       Review the parser console, counts, reports, digest, and SQLite snapshot.
       Correct LOR source data and rerun the parser as many times as needed.

    -> Confirm "Parser output looks correct — ready for ingest"
    -> Ingest to PostgreSQL in LOR2DB
    -> LOR2DB/01_Ingest/postgres_ingest_from_lor_sqlite_v7.py
    -> immutable lor_snap snapshot
    -> Start reconciliation in LOR2DB
    -> operator decisions and final application review
    -> controlled P1-P4 promotion
    -> validation and immutable HTML report
```

Running the parser never starts ingest automatically. Running ingest never
starts reconciliation automatically. Each boundary requires a separate,
explicit operator action in the browser.

The repository-root `run_parse_props.ps1` and `run_ingest.ps1` launchers remain
available only for controlled engineering or recovery use. The root
`run_lor_runner.ps1` manages the restricted Windows runner service; normal
operators do not use it to perform a production data update.

Operators never enter or select an `import_run_id`; LOR2DB captures the latest completed ingest at reconciliation start and preserves it for the entire run.

## Documentation entry points

- [Documentation portal](Docs/README.md)
- [Project overview](Docs/00_Project_Overview/README.md)
- [LOR system documentation](Docs/01_LOR_System/README.md)
- [Production database documentation](Docs/02_Production_Database/README.md)
- [LOR subsystem](LOR/README.md)
- [PostgreSQL database subsystem](Database/README.md)
- [LOR2DB subsystem](LOR2DB/README.md)
- [Office PC runner operations and disaster recovery](LOR2DB/Application/Office_PC_Runner_Operations_and_Disaster_Recovery.md)
- [Documentation standards and maintenance](System_Documentation/README.md)

Selected operator manuals are linked from the Production Committee landing page. Backend engineering documents remain authoritative here even when they are not exposed on that page.

---

Engineering Innovations, LLC — Greg Liebig
Making Spirits Bright Production Team, Sheboygan, Wisconsin
