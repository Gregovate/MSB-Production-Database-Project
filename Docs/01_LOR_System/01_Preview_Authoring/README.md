# LOR Preview Authoring

This area is for people who create, edit, and maintain Light-O-Rama (LOR) Previews for MSB.

You do **not** need to understand the parser, Python, SQLite, PostgreSQL, or database design to use these procedures.

## Start Here

| I need to... | Use this document |
|---|---|
| Name Displays and channels correctly | [Prop and Display Naming Conventions](A_Naming_Conventions.md) |
| Build or update a Preview | [Building a Preview](B_Building_Preview_Howto.md) |
| Build or update the Master Musical Preview | [Building the Master Musical Preview](E_Master_Musical_Preview_Howto.md) |
| Create a new Scene/Sub-stage documentation folder | [Stage / Sub-stage / Scene Folder Scaffold](../../00_Project_Overview/04-Stage_Substage_Scene_Folder_Scaffold.md) |
| Create or update field wiring images | [Create Wiring Backgrounds](D_Create_Wiring_Backgrounds..md) |
| Get the current approved Preview before editing | [Preview Import Workflow](Preview_Import_Workflow.md) |

## Important Rules

- Work from your own copy of a Preview.
- Do not overwrite the approved master Preview files.
- When your work is finished, export your candidate Preview to:

```text
G:\Shared drives\MSB Database\UserPreviewStaging\<username>
```

- `UserPreviewStaging` is a handoff location. It is **not** the approved master.
- Use the existing Google Drive Stage/Scene/Display organization. Do not invent a new folder structure from inside LOR.
- New Stage/Sub-stage/Scene documentation folders must use the complete controlled scaffold.
- Folders used by FieldWiring or the future Procedure system must have the required `_MSB-DB-Source-Folder_READ-ME-FIRST-AND-DO-NOT-DELETE.txt` marker.
- Do not use `SourceDocs` as a normal LOR background or field-document location.

## How to Read These Documents

Text shown like `PreviewBackground`, `BackgroundFile`, or `UserPreviewStaging` means an exact folder name, field name, filename, or value that you may need to recognize or use.

## Operator Documentation vs Engineering Documentation

The documents in this folder explain how to **use** the Preview system.

The technical documents that explain how the parser, Folder Alignment, FieldWiring, FormView, and databases work are kept separately. Preview authors should not need those engineering details to complete normal work.

## Related Operator Information

- [Google Drive Document Organization](../../00_Project_Overview/01-Google_Drive_Document_Organization_Procedure.md)
- [MSB Source Folder Marker](../../00_Project_Overview/03-MSB_DB_Source_Folder_Marker_Operator_Procedure.md)
- [Stage / Sub-stage / Scene Folder Scaffold](../../00_Project_Overview/04-Stage_Substage_Scene_Folder_Scaffold.md)

## Related Engineering

- [LOR Data Extraction / Parser](../02_Data_Extraction/README.md)
- [Preview Merger](../03_Preview_Merger/README.md)
- [FormView](../04_FormView/README.md)
- [FieldWiring Engineering](../../02_Production_Database/01_System_Architecture/09_Wiring_System/README.md)
- [LOR2DB](../../../LOR2DB/README.md)

## Historical Reference

- [Historical LOR Naming Data Contract](C_LOR_Naming_Data_Contract.md) — engineering history only; not current operator instructions.

## Revision History

- 2026-08-22 — Rewritten as a plain-language operator portal while preserving the current Scene scaffold, marker, Preview staging, and FieldWiring boundaries.
