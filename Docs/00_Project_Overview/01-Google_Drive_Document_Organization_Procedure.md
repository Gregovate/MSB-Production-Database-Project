# Organize and Publish MSB Display Folder Documentation

| Document Control | Value |
|---|---|
| Document Type | Operational SOP |
| System | Google Shared Drive — Display Folders / Folder Alignment |
| Task | Organize current and legacy Stage, Scene, Wiring, and Procedure documentation |
| Audience | Production documentation maintainers and Folder Alignment reviewers |
| Status | CURRENT |
| Owner | Production documentation owner / administrator |
| Last Reviewed | 2026-08-23 |
| Keywords | Google Drive, Display Folders, Folder Alignment, Setup, Takedown, Wiring, PreviewBackground, Archive, SourceDocs |

## Purpose

Use this procedure when organizing engineering and field documentation in the Google Shared Drive named **Display Folders**.

The goal is to put current material in the correct Stage, Sub-stage, Scene, or Display location so volunteers can find it and the new **Field Wiring** and **Procedures** systems can present the correct current files.

This is an operator procedure. The technical rules used by the applications are documented separately in [Google Drive Path Resolution Contract](02-Google_Drive_Path_Resolution_Contract.md).

## Before You Start

- Use the current **Documentation Alignment Worklist** from Folder Alignment.
- Work on one Stage at a time.
- Do not rename an aligned Stage, Sub-stage, or Scene as ordinary cleanup.
- Do not move or delete an image currently used by Light-O-Rama unless the LOR reference has been reviewed and intentionally changed.
- Preserve legacy material whose purpose or ownership is still uncertain.

## Standard Stage / Sub-stage / Scene Structure

A current Stage, formal Sub-stage, or Scene uses this structure:

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

Do not create old helper folders such as `Photos\Setup`, `Photos\Takedown`, or `Photos\Reference` in a new Stage/Scene structure.

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

Not every Display needs its own Google Drive folder. Do not create a new Display folder merely because a Display exists in LOR or the Production Database.

When a Display folder does exist, use the Display name without adding the Stage's two-letter suffix merely to make the folder look like a Stage.

## Important Folder Rules

### `PreviewBackground`

Use `PreviewBackground` for current images intentionally used as LOR Preview or Scene backgrounds.

**Do not casually rename, move, or delete a current background image.** LOR may point directly to that file.

When adding a new background, use the approved `PreviewBackground` location rather than a loose legacy image when practical.

### `Photos`

Use `Photos\Current` and `Photos\Historical` for general documentation photos.

Do **not** use the general `Photos` folders for images that are part of a Setup or Takedown instruction.

Setup instruction images belong in:

```text
Procedures\Setup\images
```

Takedown instruction images belong in:

```text
Procedures\Takedown\images
```

### `Procedures`

Current field documents belong directly in the applicable task folder:

```text
Procedures\Inspection
Procedures\Setup
Procedures\Takedown
```

Examples:

```text
15-Church-Bells-CH\Procedures\Setup\Church Setup.pdf
15-Church-Bells-CH\Procedures\Takedown\Church Takedown.pdf
```

Do **not** put a current published Setup or Takedown PDF in `Archive` or `SourceDocs`.

Files in those support folders are not current field instructions and should not be expected to appear in the normal Procedures system.

Use:

```text
Procedures\Setup\Archive
Procedures\Takedown\Archive
```

for historical or superseded source material.

Use:

```text
Procedures\Setup\SourceDocs
Procedures\Takedown\SourceDocs
```

for editable working/source material that is not ready for field use.

### `Wiring`

Keep Wiring separate from Setup/Takedown procedures.

Current published wiring images belong directly in the applicable branch:

```text
Wiring\BackgroundStage
Wiring\MusicalStage
```

Working/source material belongs in that branch's `SourceDocs` folder.

Example:

```text
15-Church-Bells-CH\Wiring\BackgroundStage\Church Background Wiring.png
```

Do **not** place the current field wiring image inside `SourceDocs`. Field Wiring is intended to present the published image from the normal wiring branch.

## Marker Files

Controlled Stage/Scene and application folders require the standard marker file.

Use the separate [MSB Database Source Folder Marker — Operator Procedure](03-MSB_DB_Source_Folder_Marker_Operator_Procedure.md) for exact marker placement and verification.

Do not guess by adding marker files to every child folder.

## How to Work One Stage

1. Open the current **Documentation Alignment Worklist**.
2. Select one Stage.
3. Confirm the Stage folder name matches the current aligned Stage name.
4. Review any Sub-stage or Scene folders identified for that Stage.
5. Preserve existing loose files and legacy folders unless their purpose and destination are understood.
6. Compare the current Stage/Sub-stage/Scene structure with the standard structure above.
7. Use the marker procedure to verify the required marker files.
8. Review current Wiring files and place published field images in the correct `BackgroundStage` or `MusicalStage` folder.
9. Review current Setup, Takedown, and Inspection documents and place the current published files directly in the correct Procedure task folder.
10. Keep source files in `SourceDocs` and older/superseded material in `Archive`.
11. Keep instruction-specific images in the applicable Procedure `images` folder rather than the general `Photos` folder.
12. Leave uncertain material where it is and flag it for review instead of guessing.
13. Re-run Folder Alignment when you need an updated worklist showing the remaining alignment work.

## Legacy Setup Procedure Alignment

Historical Setup documents are being reconciled from:

```text
G:\Shared drives\Display Folders\000-Instructions\0 - Setup Procedures
```

A similar filename is **not enough** to decide ownership.

A person who understands the real Stage/Scene organization must decide where the legacy document belongs.

When ownership is understood, move the original legacy Google Doc into the applicable Setup archive:

```text
<Stage, Sub-stage, or Scene>\Procedures\Setup\Archive\<legacy document>.gdoc
```

Example:

```text
01-Front Entrance-FE\Procedures\Setup\Archive\01 - Front Arch.gdoc
```

If an old document uses an obsolete Stage number, correct the filename only when the correct current Stage is known.

Example:

```text
25 - Magic Igloo.gdoc
```

may become:

```text
26-Magic Igloo.gdoc
```

when the reviewed current Stage is 26.

If ownership is uncertain, leave the file in the legacy source and flag it for review.

Moving a legacy document into `Archive` does **not** make it a current field instruction.

## Publishing a Current Setup Instruction

After a legacy Setup instruction has been reviewed and rewritten using the approved Stage Setup Instruction format:

1. Keep the reviewed legacy source in `Procedures\Setup\Archive`.
2. Keep editable current working/source material in `Procedures\Setup\SourceDocs` when applicable.
3. Keep Setup-specific instruction images in `Procedures\Setup\images`.
4. Place the approved current field PDF directly in `Procedures\Setup`.
5. Verify that the required Stage/Scene and `Procedures` marker files are present using the marker procedure.
6. Open the **Procedures** system and verify that the current PDF can be found for the intended Stage/Scene.

Example target state:

```text
01-Front Entrance-FE\
└── Procedures\
    └── Setup\
        ├── Archive\
        │   └── 01 - Front Arch.gdoc
        ├── images\
        ├── SourceDocs\
        └── Front Entrance Setup.pdf
```

## Creating a New Scene Documentation Folder

Do not create a Scene folder merely because a Scene exists in LOR.

Create one when the Scene is a real shared documentation/field scope, such as a group of Displays that:

- is installed as one assembly;
- shares a wiring harness or wiring drawing;
- shares Setup or Takedown instructions; or
- needs its own common field documentation.

Use [Stage / Sub-stage / Scene Folder Scaffold](04-Stage_Substage_Scene_Folder_Scaffold.md) when creating the folder.

## Expected Result

When a Stage has been aligned correctly:

- current field documents are in the correct published folders;
- source and historical material is separated from current field material;
- Setup/Takedown instruction images are in their task-local `images` folders;
- published Wiring images are in the correct Wiring branch;
- required marker files are present only where required;
- unresolved legacy material has been preserved rather than guessed at;
- Folder Alignment shows fewer unresolved items after the next report run; and
- current Setup/Wiring documents can be found through the intended field system.

## If Something Is Wrong

- **Unsure where a legacy document belongs:** leave it in place and flag it for human review.
- **Unsure whether a folder is a Scene or Display/group:** do not rename or restructure it based on guesswork; review the Folder Alignment worklist and engineering documentation.
- **Current Setup PDF does not appear in Procedures:** first verify that it is directly in the intended `Procedures\Setup` folder and that required markers are present.
- **Current Wiring image does not appear in Field Wiring:** first verify that it is directly in the correct `Wiring\BackgroundStage` or `Wiring\MusicalStage` branch and not inside `SourceDocs`.
- **LOR background breaks after a move:** stop moving files and restore/review the referenced background path before further cleanup.

## Related Documents

### Operator / Contributor

- [MSB Database Source Folder Marker — Operator Procedure](03-MSB_DB_Source_Folder_Marker_Operator_Procedure.md)
- [Stage / Sub-stage / Scene Folder Scaffold](04-Stage_Substage_Scene_Folder_Scaffold.md)
- [Stage Setup Documentation Standard](../../System_Documentation/Project_Rules/Stage_Setup_Documentation_Standard.md)

### Related Engineering

- [Google Drive Folder Structure — Engineering Overview](00-Google_Drive.md)
- [Google Drive Path Resolution Contract](02-Google_Drive_Path_Resolution_Contract.md)
- [Folder Alignment Engineering Design](../01_LOR_System/02_Data_Extraction/Folder_Alignment/Folder_Alignment_Engineering_Design.md)
- [FieldWiring Engineering](../02_Production_Database/01_System_Architecture/09_Wiring_System/README.md)
- [Setup and Deployment Engineering](../02_Production_Database/01_System_Architecture/12_Setup_and_Deployment/README.md)
