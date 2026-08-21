# LOR Preview Authoring

This area contains the user-facing rules and procedures for creating and maintaining Light-O-Rama previews that can be safely used by the MSB production workflow.

## Start Here

| I want to... | Go to |
|---|---|
| Understand required display and channel naming | [Naming Conventions](A_Naming_Conventions.md) |
| Build or update a preview | [Building Preview How-To](B_Building_Preview_Howto.md) |
| Build or update the Master Musical Preview | [Master Musical Preview How-To](E_Master_Musical_Preview_Howto.md) |
| Create a new Scene/Sub-stage documentation folder | [Stage / Sub-stage / Scene Folder Scaffold](../../00_Project_Overview/04-Stage_Substage_Scene_Folder_Scaffold.md) |
| Create and organize Stage wiring background images | [Create Wiring Backgrounds for Stage Previews](D_Create_Wiring_Backgrounds..md) |
| Review the February 2026 origin of the LOR-to-database naming contract | [Historical LOR Naming Data Contract](C_LOR_Naming_Data_Contract.md) |
| Import the current approved preview set | [Preview Import Workflow](Preview_Import_Workflow.md) |

The historical naming contract is preserved here because it records the early engineering decisions that connected LOR Comment naming, stage codes, parser output, and Production Database ingestion. It is not the current authoring authority; current naming rules are maintained in [Naming Conventions](A_Naming_Conventions.md).

## Important Boundary

Preview Authoring explains how to create and maintain previews. The controlled process for comparing programmer copies and protecting the approved preview set is documented separately under [Preview Merger](../03_Preview_Merger/README.md).

Parser engineering and `.lorprev` structure are documented separately under [Data Extraction](../02_Data_Extraction/README.md).

The [Master Musical Preview How-To](E_Master_Musical_Preview_Howto.md) documents how musical Scene names and Scene background-image paths provide Stage/documentation context without requiring every musical Scene to become a Google Drive folder.

When a Scene really does require its own Google Drive documentation scope, create it from the complete [Stage / Sub-stage / Scene Folder Scaffold](../../00_Project_Overview/04-Stage_Substage_Scene_Folder_Scaffold.md) rather than creating a partial one-off folder. New authoring uses the marked `PreviewBackground`, `Procedures`, and `Wiring` source structure; `SourceDocs` is not a normal Scene background or field-presentation endpoint.

Detailed FieldWiring implementation and wiring-system engineering remain separate from these operator procedures.

## Related Systems

- [Google Drive Document Organization](../../00_Project_Overview/01-Google_Drive_Document_Organization_Procedure.md)
- [MSB Database Source Folder Marker](../../00_Project_Overview/03-MSB_DB_Source_Folder_Marker_Operator_Procedure.md)
- [Preview Merger](../03_Preview_Merger/README.md)
- [LOR Data Extraction](../02_Data_Extraction/README.md)
- [Wiring System Engineering](../../02_Production_Database/01_System_Architecture/09_Wiring_System/README.md)
- [LOR2DB Ingest](../../../LOR2DB/01_Ingest/README.md)
