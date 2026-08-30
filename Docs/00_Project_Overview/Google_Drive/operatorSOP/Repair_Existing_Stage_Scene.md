# Repair or Organize an Existing Stage / Scene

| Document Control | Value |
|---|---|
| Document Type | Operational SOP |
| System | Google Shared Drive — Display Folders / Folder Alignment |
| Task | Repair and organize one existing Stage, Sub-stage, or Scene documentation folder |
| Audience | Production documentation maintainers and Folder Alignment reviewers |
| Status | CURRENT |
| Owner | Production documentation owner / administrator |
| Last Reviewed | 2026-08-30 |
| Keywords | Google Drive, Display Folders, Folder Alignment, Stage, Scene, Procedures, Wiring, PreviewBackground |

[↑ Google Drive / Display Folder Operations](../README.md)

## Purpose

Use this procedure when repairing or organizing **one existing Stage, formal Sub-stage, or Scene** in the Google Shared Drive named **Display Folders**.

This procedure is intentionally limited to the Stage/Scene cleanup task. Use the linked task procedures for running Folder Alignment, legacy Setup migration, publishing current Setup instructions, marker work, creating a new Scene, or building a wiring diagram.

## Before You Start

1. Run/open the current [Documentation Alignment Worklist](../../../01_LOR_System/02_Data_Extraction/Folder_Alignment/operatorSOP/Run_Folder_Alignment.md).
2. Pick one Stage.
3. Do not rename an aligned Stage/Sub-stage/Scene as ordinary cleanup.
4. If a governed Stage/Sub-stage root must be renamed or moved as part of an approved correction, identify every current LOR Preview/Scene background reference that points into the old location. Those LOR paths must be corrected too.
5. Do not move or delete a current LOR background image unless the LOR reference has been reviewed.
6. Preserve uncertain legacy material rather than guessing where it belongs.

## Standard Stage / Sub-stage / Scene Structure

```text
<Stage, Sub-stage, or Scene>
├── PreviewBackground
│   └── archive
│
├── Photos
│   ├── Current
│   └── Historical
│
├── Procedures
│   ├── Inspection
│   ├── Setup
│   │   ├── Archive
│   │   ├── images
│   │   └── SourceDocs
│   └── Takedown
│       ├── Archive
│       ├── images
│       └── SourceDocs
│
└── Wiring
    ├── BackgroundStage
    │   └── SourceDocs
    └── MusicalStage
        └── SourceDocs
```

`Procedures\Inspection` is intentionally unstructured.

## Standard Display Folder Structure

A Display folder is smaller and does **not** automatically receive `Procedures` or `Wiring`.

```text
<Display>
├── PreviewBackground
│   ├── preview development
│   ├── channel assignments
│   └── archive
├── design archive
└── Photos
    ├── Current
    └── Historical
```

Not every Display needs its own Google Drive folder. Do not create one merely because a Display exists in LOR or the Production Database.

## Repair One Existing Stage / Scene

1. Open the Stage from the current Folder Alignment worklist.
2. Confirm any formal Sub-stage or Scene folders already identified for that Stage.
3. Compare the existing folder with the standard structure above.
4. Preserve unrelated legacy folders and loose files until their purpose is understood.
5. Verify/add only the required marker files using [Add and Verify MSB Display Folder Marker Files](Add_Verify_Marker_Files.md).
6. Confirm `PreviewBackground` is used for current LOR background assets where applicable.
7. Confirm general photos are under `Photos\Current` or `Photos\Historical` when their meaning is understood.
8. Confirm current Setup/Takedown/Inspection documents are separated from `Archive` and `SourceDocs`.
9. Confirm current field wiring images are directly in the correct `Wiring\BackgroundStage` or `Wiring\MusicalStage` branch.
10. If a governed Stage/Sub-stage root or an LOR-referenced file moved, update the affected LOR Preview/Scene `BackgroundFile` reference to the exact corrected location and verify LOR opens the corrected background.
11. Do not clean unrelated historical material simply because it does not match the new scaffold.
12. Use the task-specific procedures below for any migration or publishing work.
13. Re-run Folder Alignment after enough changes have been made that a fresh worklist is useful.
14. After the LOR paths are correct, use the normal LOR2DB parser → approved ingest → reconciliation workflow. Reconciliation can then synchronize the existing Stage/Sub-stage `folder_path` in the Production Database from that frozen LOR path evidence.

## Database Path Handoff After a Folder Move

The Production Database and field applications do **not** recursively search the Google Drive to discover where a governed Stage/Sub-stage folder was moved.

For a Stage/Sub-stage root correction, the normal handoff is:

```text
correct the Google Drive root
    -> correct the current LOR BackgroundFile reference(s)
    -> run/review the normal parser
    -> ingest the approved SQLite
    -> run reconciliation
    -> P1 synchronizes ref.stage.folder_path when one matching governed root is proven
```

If the folder is moved but the current LOR references still point to the old location, the database may continue to hold the old locator until the LOR source is corrected and a new parser/ingest/reconciliation cycle is completed.

## Folder Placement Rules

| Material | Put current/published material here | Do not use as current publication |
|---|---|---|
| Setup instruction | `Procedures\Setup` | `Archive`, `SourceDocs` |
| Takedown instruction | `Procedures\Takedown` | `Archive`, `SourceDocs` |
| Inspection material | `Procedures\Inspection` | as governed by that task |
| Setup images | `Procedures\Setup\images` | general Stage `Photos` |
| Takedown images | `Procedures\Takedown\images` | general Stage `Photos` |
| Background/static wiring image | `Wiring\BackgroundStage` | `SourceDocs` |
| Musical wiring image | `Wiring\MusicalStage` | `SourceDocs` |
| General current photo | `Photos\Current` | Setup/Takedown `images` when it is instruction-specific |
| General historical photo | `Photos\Historical` | current field folders |

Putting a current field document in the wrong support folder can prevent the field system from presenting it as current material.

## Task-Specific Procedures

- [Run Folder Alignment](../../../01_LOR_System/02_Data_Extraction/Folder_Alignment/operatorSOP/Run_Folder_Alignment.md)
- [Align a Legacy Setup Document](Align_Legacy_Setup_Documents.md)
- [Publish a Current Setup Instruction](Publish_Current_Setup_Instruction.md)
- [Add and Verify MSB Display Folder Marker Files](Add_Verify_Marker_Files.md)
- [Create a New Stage / Sub-stage / Scene Documentation Folder](Create_Stage_Substage_Scene_Folder.md)
- [Create and Publish a Field Wiring Diagram](../../../01_LOR_System/01_Preview_Authoring/D_Create_Wiring_Backgrounds..md)

## Expected Result

The Stage/Sub-stage/Scene has the current controlled folder structure where needed, current field material is in the correct published locations, working/history material is separated, required markers are correct, and uncertain legacy material has been preserved for review.

When a governed Stage/Sub-stage root was moved or renamed, current LOR path references also point to the corrected location. After the next approved parser/ingest/reconciliation cycle, the Production Database `folder_path` is synchronized from that frozen LOR evidence without a Google Drive search.

## If Something Is Wrong

- **Unsure where a legacy Setup document belongs:** use the legacy alignment procedure; do not guess.
- **Unsure whether a folder is a Scene or Display/group:** stop and review Folder Alignment/current LOR evidence.
- **Current Setup PDF does not appear in Procedures:** use the Setup publishing procedure and verify placement/markers.
- **Current wiring image does not appear in Field Wiring:** use the wiring-diagram procedure and verify placement/markers.
- **LOR background breaks after a move:** stop moving files and repair/review the referenced background path before continuing.
- **Database/field applications still point to an old Stage/Sub-stage location:** confirm the current LOR `BackgroundFile` path is corrected, then run the normal parser, approved ingest, and reconciliation. Do not search the Drive tree as a database repair method.

## Related Engineering

These are not required to perform the normal cleanup task:

- [Google Drive Engineering](../engineering/README.md)
- [LOR2DB Stage Root Authority and Path Synchronization](../../../../LOR2DB/02_Reconciliation/reconciliation/Stage_Root_Authority_and_Path_Synchronization.md)
