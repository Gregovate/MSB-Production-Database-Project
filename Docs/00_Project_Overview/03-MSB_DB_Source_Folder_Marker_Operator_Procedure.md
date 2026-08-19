# MSB Database Source Folder Marker — Operator Procedure

## Purpose

Use this procedure when working with the standardized Stage / Sub-stage / Scene Google Drive scaffold used by the MSB Production Database and database-backed applications.

The marker file makes it obvious to a person browsing Google Drive that a specific helper folder is used as an application/database source location. It does this without renaming the existing Stage, Scene, or helper-folder structure.

The marker is human-readable guidance and may also be used by applications as supporting confirmation. It does **not** replace Production Database identity, LOR Preview/Scene relationships, or the controlled Drive path-resolution rules.

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

## Structured Scope Root Rule — Folders Only

A Stage, Sub-stage, or Scene root is a **structural container**. Under the settled current scaffold, files do not belong directly in that root.

For example:

```text
15-Church-Bells-CH/
├── PreviewBackground/
├── Procedures/
├── Wiring/
├── Photos/
├── Scene / Sub-stage / Display folders as applicable
└── other approved folders as applicable
```

There should be **no loose files directly under the Stage, Sub-stage, or Scene root**.

This is why the database-source marker is not placed at the Stage/Scene root. It belongs inside the specific helper folder that is actually used as a database/application source.

Applications and resolver tools must therefore treat the structured root as a navigation/container level and must not search for or present loose files from that root as a fallback. Published or application-used content belongs in the applicable controlled child folder such as `PreviewBackground`, `Procedures`, or `Wiring`.

`Photos` remains a normal documentation helper folder but is not currently a Production Database/application source folder.

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
- never places a file directly in a Stage/Sub-stage/Scene root;
- never places the marker in `Photos`;
- does not recurse into `SourceDocs`, `Archive`, `Photos`, `PreviewBackground`, `Procedures`, or `Wiring` branches;
- does not overwrite an existing exact marker file, so local notes are preserved; and
- stops for review when a differently named `_MSB-DB-Source-Folder*.txt` marker already exists.

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

Applications may use the presence of the exact marker filename as supporting evidence that they have reached a controlled source folder, but the marker is not identity authority and must not replace:

- current Production Database Stage/Scene identity;
- current LOR Preview/Scene relationships;
- Scene `BackgroundFile` navigation evidence; or
- the controlled Google Drive path-resolution contract.

A missing marker on a legacy folder is a documentation/alignment condition. It does not authorize an application to guess the folder's role.

Applications must also preserve the structured-root rule: Stage/Sub-stage/Scene roots are navigation containers, not file-publishing locations. Do not introduce a fallback that searches loose files directly under those roots.

---

## Using the Scaffold

When creating a new controlled Stage/Sub-stage/Scene structure from the approved scaffold:

1. Keep the Stage/Sub-stage/Scene root free of loose files.
2. Keep the marker files already present in `PreviewBackground`, `Procedures`, and `Wiring`.
3. Do not place the marker in `Photos`.
4. Review the personalized text for the helper folder.
5. Add local notes only when useful.
6. Keep the standard opening text and standard rules intact.
7. Do not rename the Stage/Scene folder merely to make the marker or database integration easier.

For existing current Stage trees, use the automated utility in preview mode first. The marker identifies an existing database/application source folder; it must not be used as a reason to rename or restructure the surrounding Stage/Scene hierarchy.

During legacy Folder Alignment work, review unusual targets reported by the utility rather than assuming every legacy folder with a familiar name is already aligned. The marker documents a source-folder role; it does not create Stage/Scene identity authority by itself.

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

> If `_MSB-DB-Source-Folder_READ-ME-FIRST-AND-DO-NOT-DELETE.txt` is present, open it before changing that helper folder. The file explains why the folder is used by the MSB database system, what belongs there, and any local notes that may affect cleanup or application behavior.
