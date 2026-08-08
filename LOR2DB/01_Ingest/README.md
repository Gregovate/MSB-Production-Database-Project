# LOR2DB Ingest

LOR2DB Ingest contains the parser and PostgreSQL ingest programs that turn the approved LOR preview set into a committed PostgreSQL snapshot for reconciliation.

In this documentation, **ingest** refers to the parser and import programs that prepare a snapshot for LOR2DB reconciliation.

## Start Here

The normal sequence is:

1. Run `parse_props_v7_scene_parser.py` against the approved preview set.
2. Review the parser result and generated SQLite snapshot.
3. Run `postgres_run_ingest_v7.ps1` to load the snapshot into PostgreSQL.
4. Continue to [LOR2DB Reconciliation](../02_Reconciliation/README.md).

The exact engineering rules behind the parser are documented under [LOR Data Extraction](../../Docs/01_LOR_System/02_Data_Extraction/README.md). This README does not duplicate those rules.

## Files

| File | Purpose |
|---|---|
| `parse_props_v7_scene_parser.py` | Parses approved `.lorprev` files and creates the V7 scene-aware SQLite output database |
| `postgres_run_ingest_v7.ps1` | Operator entry point for the PostgreSQL ingest step |
| `postgres_ingest_from_lor_sqlite_v7.py` | Loads the parser output into the PostgreSQL snapshot schema |
| `requirements.txt` | Python dependencies required by the ingest programs |

## Related Systems

| System | Relationship |
|---|---|
| [LOR Data Extraction](../../Docs/01_LOR_System/02_Data_Extraction/README.md) | Engineering specifications for `.lorprev` structure, parser behavior, SQLite output, and LOR-version compatibility |
| [Preview Merger](../../Docs/01_LOR_System/03_Preview_Merger/README.md) | Protects the approved preview set before parsing |
| [LOR2DB Reconciliation](../02_Reconciliation/README.md) | Reviews the committed PostgreSQL snapshot and controls production promotion |
| [LOR2DB Reporting](../03_Reporting/README.md) | Publishes the permanent evidence for completed reconciliation runs |

## Related Documents

- [LOR Preview Parser Architecture](../../Docs/01_LOR_System/02_Data_Extraction/LOR_Preview_Parser_Architecture.md)
- [LOR Preview File Structure Specification](../../Docs/01_LOR_System/02_Data_Extraction/LOR_Preview_File_Structure_Specification.md)
- [LOR SQLite Output Database Structure](../../Docs/01_LOR_System/02_Data_Extraction/LOR_SQLite_Output_Database_Structure.md)
- [LOR Preview Version Compatibility Review](../../Docs/01_LOR_System/02_Data_Extraction/LOR_Preview_Version_Compatibility_Review.md)
