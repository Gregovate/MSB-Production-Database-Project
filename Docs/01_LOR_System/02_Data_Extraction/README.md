# LOR Data Extraction Engineering

This area documents how Light-O-Rama preview files are structured, how the MSB parser interprets them, and how new Light-O-Rama versions must be reviewed before entering the production workflow.

The current parser and ingest programs are maintained under `LOR2DB/01_Ingest/`.

## Start Here

| I want to... | Go to |
|---|---|
| Understand the engineering logic behind the current V7 parser | [LOR Preview Parser Architecture](LOR_Preview_Parser_Architecture.md) |
| Understand the `.lorprev` structure the parser depends on | [LOR Preview File Structure Specification](LOR_Preview_File_Structure_Specification.md) |
| Evaluate a new Light-O-Rama version such as 6.6.8 | [LOR Preview Version Compatibility Review](LOR_Preview_Version_Compatibility_Review.md) |
| Review or run the current parser/ingest implementation | [LOR2DB Ingest](../../../LOR2DB/01_Ingest/README.md) |

## Engineering Boundary

The parser converts approved `.lorprev` files into the scene-aware SQLite snapshot used by LOR2DB ingest.

```text
.lorprev files
      |
      v
V7 preview parser
      |
      v
lor_output_v7_scene.db
      |
      v
LOR2DB PostgreSQL ingest
```

The parser owns interpretation of Light-O-Rama preview structure. PostgreSQL ingest consumes the completed SQLite snapshot and should not reinterpret the source XML.

## Current Baseline

The current functional parser is `parse_props_v7_scene_parser.py` V7.0.7 and was developed against the known-good Light-O-Rama 6.6.4 preview format.

Light-O-Rama 6.6.8 must be reviewed using the compatibility procedure before it replaces that baseline.

## Historical Documentation

The former V6 quickstart, processing rules, troubleshooting guide, SQLite cheat sheet, comparison logic, and import instructions are retained under:

`archive/v6/Docs/01_LOR_System/02_Data_Extraction/`

Those files are historical reference only. Do not use archived V6 operating instructions for the current production workflow.
