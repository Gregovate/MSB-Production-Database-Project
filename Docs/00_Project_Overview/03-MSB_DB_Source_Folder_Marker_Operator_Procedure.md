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
MSB Production Database or an MSB database-backed application.
```

Keep this opening text unchanged.

The remainder of the file is personalized for the folder type and may include local notes.

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

If another helper folder becomes a database/application source in the future, add the marker only after the governing engineering/operator documentation has been updated.

---

## PreviewBackground Marker

The `PreviewBackground` marker explains that the folder contains current background images used by Light-O-Rama Previews/Scenes and as navigation/context evidence by MSB database-backed applications.

The marker should remind maintainers that referenced background images must not be casually renamed, moved, or deleted because LOR may store the file path as a `BackgroundFile` pointer.

A normal marker includes:

- the standard opening text;
- `FOLDER PURPOSE — PREVIEW BACKGROUND`;
- a short explanation of LOR/Scene background use;
- a warning not to rename/move referenced material without deliberate alignment work;
- a link to the Google Drive Document Organization Procedure; and
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
- a link to the Google Drive Document Organization Procedure; and
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
- a link to the Google Drive Document Organization Procedure; and
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

---

## Using the Scaffold

When creating a new controlled Stage/Sub-stage/Scene structure from the approved scaffold:

1. Keep the marker files already present in `PreviewBackground`, `Procedures`, and `Wiring`.
2. Do not place the marker in `Photos`.
3. Review the personalized text for the helper folder.
4. Add local notes only when useful.
5. Keep the standard opening text and standard rules intact.
6. Do not rename the Stage/Scene folder merely to make the marker or database integration easier.

During legacy Folder Alignment work, do not mass-add markers to every folder merely because its name resembles a standard helper folder. First confirm the current Stage/Scene ownership and intended helper-folder role. The marker should identify a reviewed source folder, not create authority by itself.

---

## More Information

Main operator procedure:

https://github.com/Gregovate/MSB-Production-Database-Project/blob/main/Docs/00_Project_Overview/01-Google_Drive_Document_Organization_Procedure.md

Related engineering contracts:

- [Google Drive Folder Structure](00-Google_Drive.md)
- [Google Drive Path Resolution Contract](02-Google_Drive_Path_Resolution_Contract.md)
- [FieldWiring Drive Context Resolver Engineering Design](../02_Production_Database/01_System_Architecture/09_Wiring_System/FieldWiring_Drive_Context_Resolver_Engineering_Design.md)

---

## Simple Rule

> If `_MSB-DB-Source-Folder_READ-ME-FIRST-AND-DO-NOT-DELETE.txt` is present, open it before changing that helper folder. The file explains why the folder is used by the MSB database system, what belongs there, and any local notes that may affect cleanup or application behavior.
