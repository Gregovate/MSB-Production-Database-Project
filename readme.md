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

```text
Authoritative LOR previews
    -> LOR2DB/01_Ingest/parse_props_v7_scene_parser.py
    -> lor_output_v7_scene.db
    -> LOR2DB/01_Ingest/postgres_run_ingest_v7.ps1
    -> LOR2DB/01_Ingest/postgres_ingest_from_lor_sqlite_v7.py
    -> immutable lor_snap snapshot
    -> LOR2DB reconciliation and operator decisions
    -> controlled P1-P4 promotion
    -> validation and immutable HTML report
```

The parser and PostgreSQL snapshot ingest remain manual. Operators never enter or select an `import_run_id`; LOR2DB captures the latest completed ingest at reconciliation start and preserves it for the entire run.

## Documentation entry points

- [Documentation portal](Docs/README.md)
- [Project overview](Docs/00_Project_Overview/README.md)
- [LOR system documentation](Docs/01_LOR_System/README.md)
- [Production database documentation](Docs/02_Production_Database/README.md)
- [LOR subsystem](LOR/README.md)
- [PostgreSQL database subsystem](Database/README.md)
- [LOR2DB subsystem](LOR2DB/README.md)
- [Documentation standards and maintenance](System_Documentation/README.md)

Selected operator manuals are linked from the Production Committee landing page. Backend engineering documents remain authoritative here even when they are not exposed on that page.

---

Engineering Innovations, LLC — Greg Liebig
Making Spirits Bright Production Team, Sheboygan, Wisconsin
