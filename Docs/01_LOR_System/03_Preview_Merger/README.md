# Preview Merger

The Preview Merger protects the controlled Light-O-Rama preview set when multiple programmers work from independent preview copies.

The system is being revised for the current **Master Musical Preview** workflow. The engineering architecture is current, but production apply remains under review.

## Start Here

- [Preview Merger Operator Procedure](Preview_Merger_Operator_Procedure.md) — current operator workflow and safety rules. **Production apply is not yet approved.**
- [Preview Merger Architecture](Preview_Merger_Architecture.md) — engineering design, historical rationale, audit requirements, and current PostgreSQL/LOR2DB boundary.

## What Do You Need To Do?

- [Review how preview changes should be handled](Preview_Merger_Operator_Procedure.md)
- [Understand why the Preview Merger exists and how it works](Preview_Merger_Architecture.md)
- [Review the Preview Merger implementation](../../../LOR/preview_merger/README.md)
- [Review LOR-version compatibility before using a new LOR release](../02_Data_Extraction/LOR_Preview_Version_Compatibility_Review.md)

## Current Status

The Preview Merger remains a required preview-integrity control, but the recovered implementation still contains V6-era assumptions and must be reviewed before production `--apply` use.

The current workflow has also been simplified: **Master Musical Preview** replaces the former model that maintained separate `RGB Plus Stage xx` previews for individual musical previews.

Historical V6 documents remain useful engineering evidence, especially for the reasons behind dry-run review, deterministic comparison, audit history, conflict detection, and idempotent apply. They are not current operator instructions.

## Related Systems

| System | Relationship |
|---|---|
| [LOR Preview Authoring](../01_Preview_Authoring/README.md) | Defines how preview content is authored before candidate files enter the merger workflow. |
| [LOR Data Extraction](../02_Data_Extraction/README.md) | Documents the `.lorprev` structure, parser architecture, SQLite output, and compatibility review. |
| [LOR2DB Ingest](../../../LOR2DB/01_Ingest/README.md) | Starts the production database workflow after the approved preview set has been parsed. |
| [Preview Merger implementation](../../../LOR/preview_merger/README.md) | Current software/development tree for the merger. |

## Related Documents

- [Preview Merger Operator Procedure](Preview_Merger_Operator_Procedure.md)
- [Preview Merger Architecture](Preview_Merger_Architecture.md)
- [LOR Preview Version Compatibility Review](../02_Data_Extraction/LOR_Preview_Version_Compatibility_Review.md)
