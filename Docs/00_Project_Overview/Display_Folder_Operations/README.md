# Display Folder Operations

This is the operator starting point for maintaining the Google Shared Drive **Display Folders** structure used by Folder Alignment, Field Wiring, Preview Authoring, and the Procedures system.

Use this page to choose the task you are doing. You do not need to understand the database, resolver, or application architecture to follow these procedures.

## Start Here

If you are repairing or organizing an existing Stage/Scene, begin with:

- [Organize and Publish MSB Display Folder Documentation](../01-Google_Drive_Document_Organization_Procedure.md)

## What Do You Need To Do?

- [Run Folder Alignment and open the Documentation Alignment Worklist](Run_Folder_Alignment.md)
- [Repair or organize an existing Stage / Scene documentation folder](../01-Google_Drive_Document_Organization_Procedure.md)
- [Add or verify MSB marker files](../03-MSB_DB_Source_Folder_Marker_Operator_Procedure.md)
- [Create a new Stage / Sub-stage / Scene documentation folder](../04-Stage_Substage_Scene_Folder_Scaffold.md)
- [Align a legacy Setup document to the correct Stage / Scene](Align_Legacy_Setup_Documents.md)
- [Publish a current Setup instruction](Publish_Current_Setup_Instruction.md)
- [Create or update a field wiring diagram](../../01_LOR_System/01_Preview_Authoring/D_Create_Wiring_Backgrounds..md)

## Current Field Systems

After publishing or repairing current material, verify it in the system that uses it:

- **Field Wiring:** `https://my.sheboyganlights.org/fieldwiring/`
- **Procedures:** `https://my.sheboyganlights.org/procedures/`

The normal team workflow should use those field systems to find current Wiring and Setup/Takedown/Inspection material. GitHub is the controlled source for these maintenance procedures, not the normal field-user experience.

## Simple Folder Placement Guide

| Material | Current published location | Working/history location |
|---|---|---|
| Setup PDF | `Procedures\Setup` | `SourceDocs` / `Archive` |
| Setup instruction images | `Procedures\Setup\images` | — |
| Takedown PDF | `Procedures\Takedown` | `SourceDocs` / `Archive` |
| Takedown instruction images | `Procedures\Takedown\images` | — |
| Inspection material | `Procedures\Inspection` | as reviewed for that workflow |
| Background/static wiring image | `Wiring\BackgroundStage` | `Wiring\BackgroundStage\SourceDocs` |
| Musical wiring image | `Wiring\MusicalStage` | `Wiring\MusicalStage\SourceDocs` |
| General current photos | `Photos\Current` | `Photos\Historical` |
| LOR Preview background | `PreviewBackground` or approved published Wiring image | `PreviewBackground\archive` as applicable |

Putting a current field document in `Archive` or `SourceDocs` can prevent the field application from presenting it as current material.

## Engineering References

These are for maintainers who need to understand or change how the system works. They are **not required reading for ordinary document-maintenance tasks**.

- [Google Drive Folder Structure — Engineering Overview](../00-Google_Drive.md)
- [Google Drive Path Resolution Contract](../02-Google_Drive_Path_Resolution_Contract.md)
- [Folder Alignment Engineering Design](../../01_LOR_System/02_Data_Extraction/Folder_Alignment/Folder_Alignment_Engineering_Design.md)
- [FieldWiring Engineering](../../02_Production_Database/01_System_Architecture/09_Wiring_System/README.md)
- [Setup and Deployment Engineering](../../02_Production_Database/01_System_Architecture/12_Setup_and_Deployment/README.md)

## If You Are Unsure

Do not guess by moving, renaming, deleting, or creating a folder based only on a similar filename.

Use the Folder Alignment worklist, preserve uncertain legacy material, and flag the item for review.
