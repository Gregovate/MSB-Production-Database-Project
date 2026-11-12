# Create a New Stage / Sub-stage / Scene Documentation Folder

| Document Control | Value |
|---|---|
| Document Type | Operational SOP |
| System | Google Shared Drive — Display Folders |
| Task | Create the standard documentation scaffold for a new Stage, Sub-stage, or Scene |
| Audience | Production documentation maintainers and Folder Alignment reviewers |
| Status | CURRENT |
| Owner | Production documentation owner / administrator |
| Last Reviewed | 2026-08-23 |
| Keywords | Stage folder, Scene folder, Sub-stage, scaffold, Google Drive, Display Folders, Wiring, Procedures, PreviewBackground |

[↑ Google Drive / Display Folder Operations](../README.md)

## Purpose

Use this procedure when creating a new **Stage, formal Sub-stage, or Scene documentation folder** in the Google Shared Drive named **Display Folders**.

New Stages are uncommon. New Scene folders are more likely as the physical/documentation organization is refined.

## Before You Start

Do **not** create a Scene folder merely because a Scene exists in Light-O-Rama.

Create a Scene documentation folder when the Scene represents a real shared field/documentation scope, for example when a group of Displays:

- is installed as one recognizable assembly;
- shares a wiring harness or wiring drawing;
- shares Setup or Takedown instructions;
- owns a meaningful common Preview background; or
- otherwise needs its own durable shared documentation location.

If the LOR Scene exists only for sequencing convenience, keep its documentation at the applicable Stage or Sub-stage instead of creating another folder.

If you are unsure whether a new Scene folder is justified, stop and review the Folder Alignment worklist before creating it.

## Folder Naming

Scene directly under a Stage:

```text
NN-Scene Name
```

Scene owned by a Sub-stage:

```text
NNa-Scene Name
```

Examples:

```text
13-Christmas Story
21-Sliding Penguins
07a-Who Forest North
```

Do not add the Stage's trailing two-letter Stage code to an ordinary Scene name merely to make it resemble the Stage root.

Once an aligned Stage/Sub-stage/Scene folder is in use, do not rename or move it as ordinary cleanup.

## Create This Folder Structure

```text
<Stage / Sub-stage / Scene>/
│
├── _MSB-DB-Source-Folder_READ-ME-FIRST-AND-DO-NOT-DELETE.txt
│
├── PreviewBackground/
│   ├── _MSB-DB-Source-Folder_READ-ME-FIRST-AND-DO-NOT-DELETE.txt
│   └── archive/
│
├── Photos/
│   ├── Current/
│   └── Historical/
│
├── Procedures/
│   ├── _MSB-DB-Source-Folder_READ-ME-FIRST-AND-DO-NOT-DELETE.txt
│   │
│   ├── Inspection/
│   │
│   ├── Setup/
│   │   ├── Archive/
│   │   ├── images/
│   │   └── SourceDocs/
│   │
│   └── Takedown/
│       ├── Archive/
│       ├── images/
│       └── SourceDocs/
│
└── Wiring/
    ├── _MSB-DB-Source-Folder_READ-ME-FIRST-AND-DO-NOT-DELETE.txt
    │
    ├── BackgroundStage/
    │   └── SourceDocs/
    │
    └── MusicalStage/
        └── SourceDocs/
```

`Procedures\Inspection` is intentionally unstructured.

There is no general `Procedures\SourceDocs` folder. Setup and Takedown each have their own `SourceDocs` folder.

Do not deliberately create `desktop.ini` or other Windows-generated metadata as part of the scaffold.

## Marker Locations

```text
Stage / Sub-stage / Scene root       YES
PreviewBackground                    YES when used as a current controlled source
Procedures                           YES
Procedures\Inspection               NO
Procedures\Setup                    NO
Procedures\Takedown                 NO
Procedures\Setup\images             NO
Procedures\Takedown\images          NO
Wiring                               YES
Wiring\BackgroundStage              NO
Wiring\MusicalStage                 NO
Archive                              NO
SourceDocs                           NO
Photos                               NO
```

Use [Add and Verify MSB Display Folder Marker Files](Add_Verify_Marker_Files.md) when you need the full marker checklist.

## Folder Use

### `PreviewBackground`

Use `PreviewBackground` for current images intentionally used as an LOR Preview or Scene background.

For new work, choose the background from this approved location when practical rather than creating a new LOR reference to a loose legacy image.

Do not point a new LOR background into `SourceDocs`.

### `Photos`

Use:

```text
Photos\Current
Photos\Historical
```

for general documentation photos.

Do not create the older `Photos\Setup`, `Photos\Takedown`, or `Photos\Reference` folders in a new scaffold.

Images used by Setup/Takedown instructions belong in the applicable Procedure `images` folder instead.

### `Procedures`

Put current published field procedures directly in:

```text
Procedures\Inspection
Procedures\Setup
Procedures\Takedown
```

Use the task-local `images` folder for instruction images.

Use `Archive` for historical/superseded material and `SourceDocs` for editable working/source files.

Do not put a current field PDF inside `Archive` or `SourceDocs`.

### `Wiring`

Put current published wiring images directly in:

```text
Wiring\BackgroundStage
Wiring\MusicalStage
```

Use the branch's `SourceDocs` folder for working/source material.

Do not put the current field wiring image inside `SourceDocs`.

## Procedure

1. Confirm that the new Stage, Sub-stage, or Scene represents a real documentation scope.
2. Confirm its owning Stage or Sub-stage.
3. Name the folder using the current naming rule.
4. Create the complete folder structure shown above.
5. Add the marker to the new Stage/Sub-stage/Scene root.
6. Add the marker to `Procedures`.
7. Add the marker to `Wiring`.
8. Add the marker to `PreviewBackground` when that folder is being used as a current controlled LOR/application source.
9. Do **not** add separate markers to the fixed child branches listed above.
10. Put new current files only in the correct published locations.
11. Keep working/source files in `SourceDocs` and historical material in `Archive`.
12. Verify the completed scaffold against the checklist below.
13. Allow the normal parser/Folder Alignment workflow to pick up any related LOR changes; creating the Google Drive folder does not by itself change LOR or the Production Database.

## New Folder Checklist

- [ ] The new scope is a real field/documentation scope, not only an LOR sequencing convenience.
- [ ] The owning Stage or Sub-stage is known.
- [ ] The folder uses the current `NN-Scene Name` or `NNa-Scene Name` rule when it is a Scene.
- [ ] The complete current scaffold has been created.
- [ ] The Stage/Sub-stage/Scene root marker is present.
- [ ] `Procedures` marker is present.
- [ ] `Wiring` marker is present.
- [ ] `PreviewBackground` marker is present when that folder is used as a current source.
- [ ] No extra markers were added to `Setup`, `Takedown`, `Inspection`, `images`, `BackgroundStage`, or `MusicalStage`.
- [ ] `Archive` and `SourceDocs` are not marked as current field content.
- [ ] No generic `Procedures\SourceDocs` folder was created.
- [ ] Old `Photos\Setup`, `Photos\Takedown`, and `Photos\Reference` folders were not recreated.
- [ ] Current Setup/Takedown PDFs will be placed directly in the task folder.
- [ ] Current wiring images will be placed directly in the correct Wiring branch.
- [ ] Working/source material will be kept in `SourceDocs`.

## Existing Legacy Folders

This scaffold is for a **new** controlled Stage/Sub-stage/Scene folder.

An existing folder may contain years of loose files and older folder names. Do not reorganize all of that material merely to make the old folder look like this scaffold.

For an existing folder, use [Repair or Organize an Existing Stage / Scene](Repair_Existing_Stage_Scene.md).

## Expected Result

The new Stage/Sub-stage/Scene starts with one complete, predictable documentation structure. Current published Procedure and Wiring files have clear destinations, source/history files have separate locations, and marker files appear only where required.

## If Something Is Wrong

- **Unsure whether this should be a Scene folder:** do not create it yet; review Folder Alignment and the physical field organization.
- **Folder was created with the wrong name:** stop before adding current files; correct the naming decision through the normal alignment process.
- **Extra markers were added to child folders:** review the marker procedure and remove/flag the extras only after confirming they are not required by another approved use.
- **Legacy files already exist in the proposed location:** do not overwrite or bulk-move them. Review the existing material first.

## Related Engineering

- [Google Drive Engineering](../engineering/README.md)
