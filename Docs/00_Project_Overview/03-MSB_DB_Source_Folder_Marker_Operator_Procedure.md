# MSB Database Source Folder Marker — Operator Procedure

## Purpose

Use this procedure when working with the standardized Stage / Sub-stage / Scene Google Drive scaffold used by the MSB Production Database and database-backed applications.

The marker file makes it obvious to a person browsing Google Drive that a specific helper folder is used as an application/database source location. It does this without renaming the existing Stage, Scene, or helper-folder structure.

The marker is human-readable guidance and also establishes the visible boundary between folders that current database-backed applications may consider and the many legacy or general engineering folders/files that may still exist around them. It does **not** replace Production Database identity, LOR Preview/Scene relationships, or the controlled Drive path-resolution rules.

---

## Standard File Name

Use this exact file name:

```text
_MSB-DB-Source-Folder_READ-ME-FIRST-AND-DO-NOT-DELETE.txt
```

Do not shorten, rename, or delete the marker file after it has been placed in a controlled source folder.

The file name is intentionally explicit so a non-technical person can understand that the file should be opened before changing the folder and should not be deleted.

---

## Standard Opening Text

Every marker file begins with:

```text
MSB DATABASE SOURCE FOLDER
READ ME — DO NOT DELETE

This file identifies this folder as a source location used by the
MSB Production Database or an MSB database-backed application
```

Keep this opening text unchanged.

The remainder of the file is personalized for the folder type and may include local notes.

---

## Protected Stage / Scene Root and Legacy Material

The Stage, Sub-stage, and Scene folder names are part of the current MSB/LOR/Google Drive alignment contract.

**Do not rename a current Stage, Sub-stage, or Scene folder as part of cleanup unless an approved alignment change specifically requires it.** A rename can invalidate LOR `BackgroundFile` pointers, current database folder-path evidence, operator expectations, or application resolution.

The same protection applies to the current marked database-source helper folders beneath those roots:

```text
PreviewBackground
Procedures
Wiring
```

Do not rename those helper folders. Their names are part of the application-facing filesystem contract.

Existing Stage and Scene roots are not expected to already be clean. Many contain legacy folders and loose engineering files accumulated over years. Those items may remain in place while Folder Alignment work proceeds.

Do **not** move, rename, or delete those legacy items merely to make the root look like the current scaffold. Preserve uncertain material until its purpose and correct destination are understood.

For current database-backed application discovery, the important boundary is the marker:

> Only content located within an approved helper folder containing `_MSB-DB-Source-Folder_READ-ME-FIRST-AND-DO-NOT-DELETE.txt` is considered part of the current database/application source structure.

Loose files and unmarked legacy folders elsewhere under a Stage or Scene root are **not** current application-source content simply because they are physically nearby.

This lets cleanup happen gradually:

```text
existing Stage / Scene root
    |
    +-- marked PreviewBackground  -> current DB/application source
    +-- marked Procedures         -> current DB/application source
    +-- marked Wiring             -> current DB/application source
    +-- Photos                     -> general documentation, not DB source currently
    +-- legacy folders/files       -> preserve; ignore for application discovery
```

As a legacy item is reviewed and deliberately moved into an approved marked source structure, it can become part of the current controlled application source. Until then, applications must ignore it rather than infer its meaning from name or proximity.

---

## Folders Marked in the Current Scaffold

The current Stage / Sub-stage / Scene scaffold places the marker at the root of these database/application source folders:

```text
<Stage, Sub-stage, or Scene>/
├── PreviewBackground/
│   └── _MSB-DB-Source-Folder_READ-ME-FIRST-AND-DO-NOT-DELETE.txt
│
├── Procedures/
│   └── _MSB-DB-Source-Folder_READ-ME-FIRST-AND-DO-NOT-DELETE.txt
│
├── Wiring/
│   └── _MSB-DB-Source-Folder_READ-ME-FIRST-AND-DO-NOT-DELETE.txt
│
└── Photos/
    └── no database-source marker at this time
```

The marker belongs at the **root of the source helper folder**. It does not belong at the Stage/Scene root merely because that Stage or Scene contains database-linked material.

Do not add the marker to `Photos` at this time. The current Production Database/application contract does not use the Stage/Scene `Photos` helper as a database source folder.

Do not add extra copies inside `BackgroundStage`, `MusicalStage`, `Setup`, `Takedown`, `SourceDocs`, `Archive`, `images`, or other child folders unless a future approved application contract specifically makes that child folder a separately controlled database source.

`PreviewBackground` may legitimately exist at Stage, Sub-stage, Scene, Display, or shared-documentation scope. A `PreviewBackground` folder under a current Stage tree is therefore a valid marker target even when the immediate parent is an unprefixed Display/shared folder.

If another helper folder becomes a database/application source in the future, add the marker only after the governing engineering/operator documentation and the population utility have been updated.

---

## Automated Population Utility

Use the repository utility to populate the marker into the **existing** Google Drive structure:

```text
Utilities\populate_msb_db_source_folder_markers.ps1
```

The utility is intentionally conservative.

It:

- scans top-level Stage folders beneath `G:\Shared drives\Display Folders`;
- identifies existing `PreviewBackground`, `Procedures`, and `Wiring` source folders;
- creates only the approved marker `.txt` file;
- never creates, renames, moves, or deletes folders;
- never places the marker in `Photos`;
- does not recurse into `SourceDocs`, `Archive`, `Photos`, `PreviewBackground`, `Procedures`, or `Wiring` branches;
- does not overwrite an existing exact marker file, so local notes are preserved; and
- stops for review when a differently named `_MSB-DB-Source-Folder*.txt` marker already exists.

The utility does not clean loose Stage/Scene files or legacy folders. Its only purpose is to identify the approved source folders already present in the current structure.

### Preview first

The default run is **preview only** and makes no Drive changes:

```powershell
.\Utilities\populate_msb_db_source_folder_markers.ps1
```

The script prints the planned targets and writes a CSV report to the current user's Desktop.

For a first controlled test, limit the preview to one Stage:

```powershell
.\Utilities\populate_msb_db_source_folder_markers.ps1 -StageFilter '15-*'
```

Review the listed `PreviewBackground`, `Procedures`, and `Wiring` targets before applying the change.

### Apply to one Stage

After the preview is correct:

```powershell
.\Utilities\populate_msb_db_source_folder_markers.ps1 -StageFilter '15-*' -Apply
```

### Apply to all current Stage trees

After the all-Stage preview has been reviewed:

```powershell
.\Utilities\populate_msb_db_source_folder_markers.ps1 -Apply
```

The script creates only missing exact marker files. If the exact marker is already present, it reports `SKIPPED_EXISTING` and leaves the file untouched.

This is important because the existing file may contain useful `LOCAL NOTES` that must not be lost.

A result of `REVIEW_EXISTING_MARKER` means another `_MSB-DB-Source-Folder*.txt` file already exists with a different filename. Review that folder manually rather than allowing the utility to create a duplicate marker.

The generated CSV report records the Stage, source-folder type, relative path, marker path, action, and explanation.

---

## PreviewBackground Marker

The `PreviewBackground` marker explains that the folder contains current background images used by Light-O-Rama Previews/Scenes and as navigation/context evidence by MSB database-backed applications.

The marker should remind maintainers that referenced background images must not be casually renamed, moved, or deleted because LOR may store the file path as a `BackgroundFile` pointer.

A normal marker includes:

- the standard opening text;
- `FOLDER PURPOSE — PREVIEW BACKGROUND`;
- a short explanation of LOR/Scene background use;
- a warning not to rename/move referenced material without deliberate alignment work;
- links to the marker and Google Drive organization procedures; and
- an optional local-notes section.

---

## Procedures Marker

The `Procedures` marker explains that the folder is the controlled source root for field procedures associated with the Stage, Sub-stage, or Scene.

The marker should explain that database-backed applications may use approved procedure branches to locate field instructions and that `Archive` and `SourceDocs` material is not normal field-facing content.

A normal marker includes:

- the standard opening text;
- `FOLDER PURPOSE — PROCEDURES`;
- a short explanation of field-procedure discovery;
- the current publication/source-material boundary;
- links to the marker and Google Drive organization procedures; and
- an optional local-notes section.

---

## Wiring Marker

The `Wiring` marker explains that the folder is the controlled source root for published field wiring information associated with the Stage, Sub-stage, or Scene.

The marker should explain the current published branches:

```text
Wiring/BackgroundStage
Wiring/MusicalStage
```

It must also state that `SourceDocs` contains working/source material and is not normal field-facing content. FieldWiring and related field applications must not descend into or present `SourceDocs` material.

A normal marker includes:

- the standard opening text;
- `FOLDER PURPOSE — WIRING`;
- a short explanation of Background/Static and Musical published wiring branches;
- the `SourceDocs` exclusion rule;
- links to the marker and Google Drive organization procedures; and
- an optional local-notes section.

---

## Local Notes Are Allowed

Each marker contains a `LOCAL NOTES (optional)` section.

Use that section for short, factual human-readable information such as:

- known legacy exceptions;
- pending folder-alignment cleanup;
- a known Scene/background pointer that still needs correction;
- why a particular Stage/Scene currently falls back to another documentation scope; or
- other information a future maintainer should know before changing the folder.

Example:

```text
LOCAL NOTES (optional)

Notes:
2026-08-19 GL — Musical Scene pointer still uses the old folder suffix.
Do not remove the current folder until the next LOR/parser alignment run is complete.
```

Do not use the notes section for passwords, credentials, API keys, private personal information, or application configuration secrets.

Do not delete or rewrite the standard purpose/rule text above the notes merely to make the marker shorter.

The automated population utility never overwrites the exact marker filename. This is deliberate so notes added by operators remain intact.

---

## Application Behavior

The marker file itself is **not field content**.

Database-backed applications must not list or present this `.txt` marker as a Wiring image, Setup instruction, Takedown instruction, or other field document.

Applications use permanent/current Production Database and LOR relationships to resolve the applicable Stage/Sub-stage/Scene context. After that context is resolved, applications must restrict filesystem discovery to the approved marked source folders.

The marker therefore does not replace identity authority, but it does define whether a helper folder participates in the current application-source contract.

An unmarked sibling folder, loose file, legacy engineering folder, or nearby historical document must not be considered merely because it is under the correct Stage or Scene.

A missing marker on a folder that is expected to be an active application source is an alignment/review condition. It does not authorize the application to search neighboring legacy material for a substitute.

Applications must continue to honor task-specific child rules inside a marked source folder. For example:

- `Wiring` may expose only the approved published `BackgroundStage` or `MusicalStage` branch;
- `SourceDocs` remains excluded;
- procedure `Archive` and source branches remain excluded from normal field presentation; and
- the marker `.txt` itself is never field content.

---

## Using the Scaffold and Cleaning Legacy Material

When creating a new controlled Stage/Sub-stage/Scene structure from the approved scaffold:

1. Keep the Stage/Sub-stage/Scene folder name unchanged once it is aligned and in use.
2. Keep the marker files already present in `PreviewBackground`, `Procedures`, and `Wiring`.
3. Do not rename those marked helper folders.
4. Do not place the marker in `Photos`.
5. Review the personalized text for the helper folder.
6. Add local notes only when useful.
7. Keep the standard opening text and standard rules intact.

For existing Stage and Scene trees, do **not** try to make the root match the clean scaffold in one pass. Existing loose files and legacy folders may remain where they are until they are reviewed.

During Folder Alignment work:

1. preserve the current Stage/Sub-stage/Scene root name;
2. preserve the marked `PreviewBackground`, `Procedures`, and `Wiring` folder names;
3. treat those marked folders as the current application-source boundary;
4. ignore other root-level material for database/application discovery;
5. review legacy material deliberately;
6. move or reorganize it only when its purpose and destination are known; and
7. once appropriate content has been deliberately placed into a marked source structure, the application can discover it through the normal contract.

The marker lets the Drive support a clean current application contract while historical cleanup continues over time.

---

## More Information

Main Google Drive organization procedure:

https://github.com/Gregovate/MSB-Production-Database-Project/blob/main/Docs/00_Project_Overview/01-Google_Drive_Document_Organization_Procedure.md

Related engineering contracts:

- [Google Drive Folder Structure](00-Google_Drive.md)
- [Google Drive Path Resolution Contract](02-Google_Drive_Path_Resolution_Contract.md)
- [FieldWiring Drive Context Resolver Engineering Design](../02_Production_Database/01_System_Architecture/09_Wiring_System/FieldWiring_Drive_Context_Resolver_Engineering_Design.md)

---

## Simple Rule

> Do not rename the Stage/Scene or marked source folders. If `_MSB-DB-Source-Folder_READ-ME-FIRST-AND-DO-NOT-DELETE.txt` is present, that helper folder is part of the current database/application source structure. Other legacy folders and loose files may remain in place during cleanup, but applications must ignore them until they are deliberately aligned into the marked structure.