# MSB Database Source Folder Marker — Operator Procedure

## Purpose

Use this procedure when working with the Stage / Sub-stage / Scene Google Drive structure used by the MSB Production Database and database-backed applications.

The marker file has two related uses:

1. at a **Stage / Sub-stage / Scene root**, it identifies and protects the aligned structural scope; and
2. inside approved helper folders such as `PreviewBackground`, `Procedures`, and `Wiring`, it identifies the folders whose contents may be used by database-backed applications.

This allows legacy folders and loose files to remain in place while cleanup proceeds gradually without letting applications mistake nearby historical material for current controlled content.

The marker supports human understanding and application validation. It does **not** replace Production Database identity, current LOR relationships, Scene/Preview path evidence, or the Google Drive path-resolution contract.

---

## Standard File Name

Use this exact file name everywhere:

```text
_MSB-DB-Source-Folder_READ-ME-FIRST-AND-DO-NOT-DELETE.txt
```

Do not shorten, rename, or delete it.

---

## Standard Opening Text

Every marker begins with:

```text
MSB DATABASE SOURCE FOLDER
READ ME — DO NOT DELETE

This file identifies this folder as a source location used by the
MSB Production Database or an MSB database-backed application
```

Keep this opening text unchanged. The rest of the file is personalized for the folder type and may include local notes.

---

# Stage / Sub-stage / Scene Root Marker

Every current Stage, formal Sub-stage, and Scene folder must contain the marker directly in its root.

Example:

```text
15-Church-Bells-CH/
├── _MSB-DB-Source-Folder_READ-ME-FIRST-AND-DO-NOT-DELETE.txt
├── PreviewBackground/
├── Procedures/
├── Wiring/
├── Photos/
├── legacy folders/
└── loose legacy files
```

The root marker has a different purpose from a helper-folder marker.

It means:

> This folder is an aligned Stage / Sub-stage / Scene structural scope used by the MSB system. Do not rename or move it without an approved alignment change.

The root marker does **not** mean that every file or folder inside the root is current application source content.

## Protect the root name

Do not rename or move a current Stage, Sub-stage, or Scene folder merely as part of cleanup. Its current name and hierarchy may be referenced by:

- LOR `BackgroundFile` paths;
- current database folder-path evidence;
- Folder Alignment;
- FieldWiring and future database-backed applications; and
- operator procedures and expectations.

If a true alignment correction requires a rename, make it as a deliberate coordinated change rather than an incidental cleanup action.

## Legacy material may remain

Existing Stage and Scene roots are not expected to be clean. They may contain many years of loose files, drawings, images, old folders, and other engineering material.

Do not delete, rename, or reorganize uncertain legacy material merely to make the root match the current scaffold.

Preserve it until its purpose and correct destination are understood.

---

# Marked Application-Source Folders

Within a Stage / Sub-stage / Scene root, the current database/application source folders are:

```text
PreviewBackground
Procedures
Wiring
```

Each of those folders also contains the same marker file:

```text
<Stage / Sub-stage / Scene>/
├── _MSB-DB-Source-Folder_READ-ME-FIRST-AND-DO-NOT-DELETE.txt   <- structural root marker
│
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

Do not rename the marked `PreviewBackground`, `Procedures`, or `Wiring` folders. Their names are part of the application-facing filesystem contract.

`Photos` remains general documentation and is not currently an application-source folder.

Do not add extra markers inside `BackgroundStage`, `MusicalStage`, `Setup`, `Takedown`, `SourceDocs`, `Archive`, `images`, or other child folders unless a future approved contract specifically makes that child folder its own marked source root.

`PreviewBackground` may also legitimately exist beneath a Display/shared folder and may carry its own marker because LOR can reference that folder directly.

---

# Application Discovery Boundary

For normal database-backed application discovery:

> Loose files and unmarked legacy folders are ignored. Current application content is discovered only through approved marked source folders.

This is the key rule that allows gradual cleanup.

Example:

```text
existing Stage / Scene root
    |
    +-- root marker                -> confirms/protects structured scope
    +-- marked PreviewBackground  -> current application source
    +-- marked Procedures         -> current application source
    +-- marked Wiring             -> current application source
    +-- Photos                    -> general documentation only
    +-- loose legacy files        -> preserve; ignore for application discovery
    +-- legacy folders            -> preserve; ignore for application discovery
```

A legacy LOR `BackgroundFile` pointer may still pass through or point to legacy material outside the marked source folders. The resolver may use such path text as navigation evidence when permitted by the path-resolution contract, but that legacy file does **not** become published application content merely because LOR points to it.

After the correct Stage / Sub-stage / Scene is resolved, the application must return to the approved marked source structure for published content.

---

# Folder-Specific Marker Purpose

## Stage / Sub-stage / Scene root

The root marker should:

- identify the folder as an aligned structural scope;
- state the folder name;
- say **do not rename or move**;
- explain that loose legacy content may remain;
- explain that loose/unmarked content is not automatically application source content; and
- provide a local-notes section.

## PreviewBackground

The marker should explain that the folder contains current LOR Preview/Scene background images and path/context evidence.

Referenced images must not be casually renamed, moved, or deleted without deliberately updating the LOR reference and alignment.

## Procedures

The marker should explain that this is the controlled source root for field procedures.

`Archive` and `SourceDocs` remain excluded from normal field presentation.

## Wiring

The marker should explain the current published branches:

```text
Wiring/BackgroundStage
Wiring/MusicalStage
```

`SourceDocs` is working/source material and is a hard exclusion boundary for FieldWiring and other normal field applications.

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

The population utility never overwrites an existing exact marker so local notes are preserved.

---

# Automated Population Utility

Use:

```text
Utilities\populate_msb_db_source_folder_markers.ps1
```

The utility is preview-only by default.

It now targets:

- each detected Stage root;
- each detected formal Sub-stage root;
- each detected Scene root;
- existing `PreviewBackground` folders;
- existing `Procedures` folders at Stage/Sub-stage/Scene scope; and
- existing `Wiring` folders at Stage/Sub-stage/Scene scope.

It does not create, rename, move, or delete folders. It does not mark `Photos`. It does not overwrite an existing exact marker.

### Preview

```powershell
.\Utilities\populate_msb_db_source_folder_markers.ps1
```

### Preview one Stage

```powershell
.\Utilities\populate_msb_db_source_folder_markers.ps1 -StageFilter '15-*'
```

### Apply

```powershell
.\Utilities\populate_msb_db_source_folder_markers.ps1 -Apply
```

Because the helper-folder markers have already been populated in much of the current structure, a later run may show many `SKIPPED_EXISTING` helper markers and new `WOULD_CREATE` / `CREATED` entries for Stage/Sub-stage/Scene roots. That is expected.

Review any `REVIEW_EXISTING_MARKER` result manually.

---

# Application Behavior

The marker `.txt` file itself is never field content and must not be listed as a Wiring image, Setup/Takedown/Inspection instruction, or other published document.

Applications should use the markers in two different ways:

1. **structural root marker** — supporting confirmation that the resolved Stage/Sub-stage/Scene is an aligned controlled scope;
2. **helper-folder marker** — confirmation that the helper folder participates in the current database/application source contract.

The marker does not replace database/LOR identity authority.

Inside marked source folders, task-specific exclusions still apply. Examples:

- FieldWiring exposes only the applicable published `BackgroundStage` or `MusicalStage` branch;
- `SourceDocs` is excluded;
- Procedure `Archive` and source branches are excluded from normal field presentation; and
- the marker file itself is ignored as content.

A missing expected marker is an alignment/review condition. It does not authorize an application to search neighboring legacy material for a substitute.

---

# Simple Rule

> Keep the marker in every Stage, Sub-stage, and Scene root, and in every approved database/application source helper folder. Do not rename those structural roots or marked helper folders. Preserve other legacy material during cleanup, but applications ignore it until it is deliberately aligned into the marked source structure.

---

## More Information

- [Google Drive Folder Structure](00-Google_Drive.md)
- [Google Drive Document Organization Procedure](01-Google_Drive_Document_Organization_Procedure.md)
- [Google Drive Path Resolution Contract](02-Google_Drive_Path_Resolution_Contract.md)
- [FieldWiring Drive Context Resolver Engineering Design](../02_Production_Database/01_System_Architecture/09_Wiring_System/FieldWiring_Drive_Context_Resolver_Engineering_Design.md)
