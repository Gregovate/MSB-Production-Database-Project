# Google Drive / Display Folder Operations

This is the operator starting point for maintaining the Google Shared Drive **Display Folders** structure used by Folder Alignment, Field Wiring, Preview Authoring, and the Procedures system.

Use this page to choose the task you are doing. You do not need to understand the database, resolver, or application architecture to follow these procedures.

## Start Here

If you are repairing or organizing an existing Stage/Scene, start with:

- [Repair or Organize an Existing Stage / Scene](operatorSOP/Repair_Existing_Stage_Scene.md)

## What Do You Need To Do?

- [Run Folder Alignment](../../01_LOR_System/02_Data_Extraction/Folder_Alignment/operatorSOP/Run_Folder_Alignment.md)
- [Review the Folder Alignment Worklist](../../01_LOR_System/02_Data_Extraction/Folder_Alignment/operatorSOP/Review_Folder_Alignment_Worklist.md)
- [Repair or organize an existing Stage / Scene](operatorSOP/Repair_Existing_Stage_Scene.md)
- [Add or verify MSB marker files](operatorSOP/Add_Verify_Marker_Files.md)
- [Create a new Stage / Sub-stage / Scene documentation folder](operatorSOP/Create_Stage_Substage_Scene_Folder.md)
- [Align a legacy Setup document to the correct Stage / Scene](operatorSOP/Align_Legacy_Setup_Documents.md)
- [Publish a current Setup instruction](operatorSOP/Publish_Current_Setup_Instruction.md)
- [Create or update a field wiring diagram](../../01_LOR_System/01_Preview_Authoring/D_Create_Wiring_Backgrounds..md)

For the procedure index, see [Google Drive Operator Procedures](operatorSOP/README.md).

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
| LOR Preview background | `PreviewBackground` or an approved published Wiring image | `PreviewBackground\archive` as applicable |

Putting a current field document in `Archive` or `SourceDocs` can prevent the field application from presenting it as current material.

## Engineering

Engineering documentation is intentionally separate from the operator procedures.

Start here only when you need to understand, troubleshoot, validate, or change how the Google Drive integrations work:

- [Google Drive Engineering](engineering/README.md)

## If You Are Unsure

Do not guess by moving, renaming, deleting, or creating a folder based only on a similar filename.

Use the Folder Alignment worklist, preserve uncertain legacy material, and flag the item for review.
