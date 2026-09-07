# Google Drive / Display Folder Operations

This is the operator starting point for maintaining the Google Shared Drive **Display Folders** structure used by Folder Alignment, Field Wiring, Preview Authoring, the Procedures system, and Setup Session field-document support.

Use this page to choose the task you are doing. You do not need to understand the database, resolver, or application architecture to follow these procedures.

## Start Here

If you are repairing or organizing an existing Stage/Scene, start with:

- [Repair or Organize an Existing Stage / Scene](operatorSOP/Repair_Existing_Stage_Scene.md)

If you are creating the non-LOR Procedure root for truly park-wide Setup work such as street-light work, site breakers, or other infrastructure tasks with no appropriate Stage/Scene owner, start with:

- [Create the Park Infrastructure Procedure Folder](operatorSOP/Create_Site_Infrastructure_Procedure_Folder.md)

The approved physical folder name is:

```text
G:\Shared drives\Display Folders\41 Park Infrastructure-PI
```

The leading `41` is only a human sort aid. The space after `41` is intentional and keeps this folder outside the active Folder Alignment top-level `NN-...` Stage candidate pattern.

`41 Park Infrastructure-PI` has no LOR Preview and does not create Stage 41.

Do not use this folder merely because a Stage has no wired inventory. For example, `40-CommandCenter` remains a legitimate Stage because it has its own current Stage/Preview context; its Setup tasks and Procedures belong under Stage 40 when that is the correct operational owner.

## What Do You Need To Do?

- [Run Folder Alignment](../../01_LOR_System/02_Data_Extraction/Folder_Alignment/operatorSOP/Run_Folder_Alignment.md)
- [Review the Folder Alignment Worklist](../../01_LOR_System/02_Data_Extraction/Folder_Alignment/operatorSOP/Review_Folder_Alignment_Worklist.md)
- [Repair or organize an existing Stage / Scene](operatorSOP/Repair_Existing_Stage_Scene.md)
- [Add or verify MSB marker files](operatorSOP/Add_Verify_Marker_Files.md)
- [Create a new Stage / Sub-stage / Scene documentation folder](operatorSOP/Create_Stage_Substage_Scene_Folder.md)
- [Create the `41 Park Infrastructure-PI` non-LOR Procedure folder](operatorSOP/Create_Site_Infrastructure_Procedure_Folder.md)
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
| Stage/Scene Setup PDF | `<scope>\Procedures\Setup` | `SourceDocs` / `Archive` |
| Park-wide / no-Stage Setup PDF | `41 Park Infrastructure-PI\Procedures\Setup` | `SourceDocs` / `Archive` |
| Setup instruction images | `Procedures\Setup\images` | — |
| Takedown PDF | `Procedures\Takedown` | `SourceDocs` / `Archive` |
| Takedown instruction images | `Procedures\Takedown\images` | — |
| Inspection material | `Procedures\Inspection` | as reviewed for that workflow |
| Background/static wiring image | `Wiring\BackgroundStage` | `Wiring\BackgroundStage\SourceDocs` |
| Musical wiring image | `Wiring\MusicalStage` | `Wiring\MusicalStage\SourceDocs` |
| General current photos | `Photos\Current` | `Photos\Historical` |
| LOR Preview background | `PreviewBackground` or an approved published Wiring image | `PreviewBackground\archive` as applicable |

Putting a current field document in `Archive` or `SourceDocs` can prevent the field application from presenting it as current material.

`41 Park Infrastructure-PI` is a controlled **non-LOR** Setup Procedure root. The numeric prefix exists only to keep the folder near the numbered park areas in normal sorting. It does not create LOR Stage 41, and `PI` is not an LOR Stage short code.

## Engineering

Engineering documentation is intentionally separate from the operator procedures.

Start here only when you need to understand, troubleshoot, validate, or change how the Google Drive integrations work:

- [Google Drive Engineering](engineering/README.md)
- [Folder Alignment Park Infrastructure non-LOR boundary](../../01_LOR_System/02_Data_Extraction/Folder_Alignment/engineering/Park_Infrastructure_Non_LOR_Root_2026-09-07.md)

## If You Are Unsure

Do not guess by moving, renaming, deleting, or creating a folder based only on a similar filename.

Use the Folder Alignment worklist for Stage/Scene material, preserve uncertain legacy material, and flag the item for review. For truly park-wide Setup work with no Stage/Scene owner, use the dedicated `41 Park Infrastructure-PI` Procedure-root procedure rather than forcing the work into LOR organization.
