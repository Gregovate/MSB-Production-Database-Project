# MSB Database Source Folder Marker — Operator Procedure

## Purpose

Use this procedure when working with the standardized Google Drive helper folders used by the MSB Production Database and database-backed applications.

The marker file identifies a **specific helper folder whose contents are used as a database/application source location**. It exists to make those folders obvious to people browsing Google Drive without renaming the established Stage, Sub-stage, Scene, Display, or helper-folder structure.

The marker is human-readable guidance and may also be used by applications as supporting confirmation. It does **not** replace Production Database identity, current LOR relationships, Scene/Preview path evidence, or the Google Drive path-resolution contract.

---

## Standard File Name

Use this exact file name:

```text
_MSB-DB-Source-Folder_READ-ME-FIRST-AND-DO-NOT-DELETE.txt
```

Do not shorten, rename, or delete the marker after it has been placed in an approved source folder.

---

## Standard Opening Text

Every marker begins with:

```text
MSB DATABASE SOURCE FOLDER
READ ME — DO NOT DELETE

This file identifies this folder as a source location used by the
MSB Production Database or an MSB database-backed application
```

Keep this opening text unchanged.

The rest of the marker is personalized for the folder type and may include local notes.

---

# Approved Marker Locations

The current approved database/application source folders are:

```text
PreviewBackground
Procedures
Wiring
```

The marker belongs at the **root of those source helper folders**.

Example:

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

## Stage / Sub-stage / Scene roots are NOT marker locations

Do **not** place the database-source marker directly in a Stage, Sub-stage, or Scene root merely because that scope contains database-linked material.

For example, this is **not** correct:

```text
15-Church-Bells-CH/
└── _MSB-DB-Source-Folder_READ-ME-FIRST-AND-DO-NOT-DELETE.txt   <- DO NOT PLACE HERE
```

The Stage/Scene root may contain many other engineering, historical, fabrication, photo, and legacy folders that are not database/application source folders. The marker is intentionally used only on the helper folders that participate in the current database/application source contract.

## Photos is not marked

Do not add the marker to `Photos` at this time. The current Production Database/application contract does not use the Stage/Scene `Photos` helper as a database source folder.

## Child folders are not separately marked by default

Do not add extra copies inside:

```text
BackgroundStage
MusicalStage
Setup
Takedown
Inspection
SourceDocs
Archive
images
```

unless a future approved application contract specifically makes that child folder its own separately controlled database source.

`PreviewBackground` may legitimately exist beneath a Display/shared folder and may carry its own marker because LOR may reference that folder directly.

If another helper folder becomes a database/application source in the future, update the governing documentation first and then add the marker to that helper folder.

---

# Folder-Specific Marker Content

## PreviewBackground

The marker explains that the folder contains current LOR Preview/Scene background images and path/context evidence used by database-backed applications.

Referenced images must not be casually renamed, moved, or deleted without deliberately updating the LOR reference and alignment.

## Procedures

The marker explains that the folder is the controlled source root for field procedures associated with the applicable Stage, Sub-stage, or Scene.

`Archive` and `SourceDocs` remain excluded from normal field presentation.

## Wiring

The marker explains that the folder is the controlled source root for published field wiring information.

Published field wiring branches are:

```text
Wiring\BackgroundStage
Wiring\MusicalStage
```

`SourceDocs` is working/source material and is a hard exclusion boundary for FieldWiring and normal field applications.

---

# Local Notes Are Allowed

Each marker contains a `LOCAL NOTES (optional)` section.

Use it for short factual information such as:

- pending Folder Alignment work;
- stale Scene/background pointers;
- known legacy exceptions;
- why a Scene currently falls back to a Stage/Substage source; or
- other information a future maintainer should know before changing the folder.

Example:

```text
LOCAL NOTES (optional)

Notes:
2026-08-19 GL — Musical Scene pointer still uses the old folder suffix.
Do not remove the current folder until the next LOR/parser alignment run is complete.
```

Do not place credentials, passwords, API keys, or private personal information in the marker.

The population utility never overwrites an existing exact marker, so local notes are preserved.

---

# Automated Population Utility

Use:

```text
Utilities\populate_msb_db_source_folder_markers.ps1
```

The utility is preview-only by default.

It targets only:

- existing `PreviewBackground` folders;
- existing `Procedures` folders at Stage/Sub-stage/Scene scope; and
- existing `Wiring` folders at Stage/Sub-stage/Scene scope.

It does **not** target Stage/Sub-stage/Scene roots and does not mark `Photos`.

It does not create, rename, move, or delete folders. It does not overwrite an existing exact marker.

### Preview all current Stages

```powershell
.\Utilities\populate_msb_db_source_folder_markers.ps1
```

### Preview one Stage

```powershell
.\Utilities\populate_msb_db_source_folder_markers.ps1 -StageFilter '15-*'
```

### Apply after review

```powershell
.\Utilities\populate_msb_db_source_folder_markers.ps1 -Apply
```

Review any `REVIEW_EXISTING_MARKER` result manually.

---

# Application Behavior

The marker `.txt` file itself is never field content and must not be listed as a Wiring image, Setup/Takedown/Inspection instruction, or other published document.

Applications may use the presence of the marker as supporting confirmation that an approved helper folder participates in the current database/application source contract.

The marker does not replace database/LOR identity authority.

Inside marked source folders, task-specific exclusions still apply. Examples:

- FieldWiring exposes only the applicable published `BackgroundStage` or `MusicalStage` branch;
- `SourceDocs` is excluded;
- Procedure `Archive` and source branches are excluded from normal field presentation; and
- the marker file itself is ignored as content.

A missing expected marker is an alignment/review condition. It does not authorize an application to search neighboring legacy material for a substitute.

---

# Simple Rule

> Put `_MSB-DB-Source-Folder_READ-ME-FIRST-AND-DO-NOT-DELETE.txt` only in the root of an approved database/application source helper folder. Today those are `PreviewBackground`, `Procedures`, and `Wiring`. Do not put it in the Stage/Scene root or `Photos`.

---

## More Information

- [Google Drive Folder Structure](00-Google_Drive.md)
- [Google Drive Document Organization Procedure](01-Google_Drive_Document_Organization_Procedure.md)
- [Google Drive Path Resolution Contract](02-Google_Drive_Path_Resolution_Contract.md)
- [FieldWiring Drive Context Resolver Engineering Design](../02_Production_Database/01_System_Architecture/09_Wiring_System/FieldWiring_Drive_Context_Resolver_Engineering_Design.md)
