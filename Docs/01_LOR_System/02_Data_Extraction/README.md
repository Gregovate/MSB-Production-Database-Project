# LOR Data Extraction Engineering

This area documents how Light-O-Rama preview files are structured, how the MSB parser interprets them, and how new Light-O-Rama versions must be reviewed before entering the production workflow.

The parser, XML compatibility checker, and Windows operator runner are owned
here under `Parser/`. LOR2DB exposes their operator controls and owns the
separate SQLite-to-PostgreSQL ingest.

## Start Here

| I want to... | Go to |
|---|---|
| Understand the engineering logic behind the current V7 parser | [LOR Preview Parser Architecture](LOR_Preview_Parser_Architecture.md) |
| Translate LOR XML names into the human-readable MSB names used in engineering and database work | [LOR XML to MSB Terminology Contract](LOR_XML_to_MSB_Terminology_Contract.md) |
| Understand the `.lorprev` structure the parser depends on | [LOR Preview File Structure Specification](LOR_Preview_File_Structure_Specification.md) |
| Evaluate and approve a new Light-O-Rama version | [LOR Preview Version Compatibility Review](LOR_Preview_Version_Compatibility_Review.md) |
| Review the current parser/checker implementation | [Parser](Parser/) |
| Install, restart, or recover the Office PC listener | [Office PC Runner Operations and Disaster Recovery](../../../LOR2DB/Application/Office_PC_Runner_Operations_and_Disaster_Recovery.md) |
| Review the separate PostgreSQL ingest | [LOR2DB Ingest](../../../LOR2DB/01_Ingest/README.md) |

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

The current functional parser is
`Parser/parse_props_v7_scene_parser.py` V7.0.11. The current approved LOR version
of record is 6.6.10. The approved version remains an operator-controlled record;
it is not a hard-coded parser assumption.

Every later Light-O-Rama version must pass the complete XML checker and the V7
parser validation run before it can replace that approved record.

## Historical Documentation

The former V6 quickstart, processing rules, troubleshooting guide, SQLite cheat sheet, comparison logic, and import instructions are retained under:

`archive/v6/Docs/01_LOR_System/02_Data_Extraction/`

Those files are historical reference only. Do not use archived V6 operating instructions for the current production workflow.
