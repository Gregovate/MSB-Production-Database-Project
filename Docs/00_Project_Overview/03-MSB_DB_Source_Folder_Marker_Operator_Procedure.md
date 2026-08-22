# MSB Database Source Folder Marker — Operator Procedure

## Purpose

Use this procedure when working with Google Drive folders that are part of the new FieldWiring system or the future Setup/Takedown/Inspection system.

The marker file tells people and applications that a folder is part of the controlled MSB field-document system.

## Standard File Name

Use this exact file name:

```text
_MSB-DB-Source-Folder_READ-ME-FIRST-AND-DO-NOT-DELETE.txt
```

Do not shorten, rename, move, or delete the marker.

---

# Simple Rule

> **Every folder that the new FieldWiring system or future Procedure system uses must contain the marker.**

The marker is not limited to only the top-level `PreviewBackground`, `Procedures`, or `Wiring` folders.

If the application follows a folder as part of its controlled path, that folder must be marked.

Working/archive folders that the field applications are specifically forbidden to use are excluded.

---

# Current Required Marker Locations

## Stage / Sub-stage / Scene roots

Every current Stage, formal Sub-stage, and Scene documentation root used by the field systems must contain the marker directly in the root.

Example:

```text
15-Church-Bells-CH\
├── _MSB-DB-Source-Folder_READ-ME-FIRST-AND-DO-NOT-DELETE.txt
├── PreviewBackground\
├── Procedures\
├── Wiring\
└── Photos\
```

The root marker identifies and protects the structured Stage/Sub-stage/Scene location.

Do not rename or move a marked Stage/Sub-stage/Scene root as ordinary cleanup.

---

## Preview backgrounds

Any `PreviewBackground` folder used as a current LOR/application source must contain the marker.

This includes an applicable Stage, Sub-stage, Scene, Display, or shared-group `PreviewBackground` folder.

```text
PreviewBackground\
├── _MSB-DB-Source-Folder_READ-ME-FIRST-AND-DO-NOT-DELETE.txt
└── current background images
```

Referenced background images must not be casually renamed, moved, or deleted because LOR may point directly to them.

---

## FieldWiring folders

Every folder used in the published FieldWiring path must be marked.

Current wiring paths include:

```text
Wiring\
├── _MSB-DB-Source-Folder_READ-ME-FIRST-AND-DO-NOT-DELETE.txt
│
├── BackgroundStage\
│   ├── _MSB-DB-Source-Folder_READ-ME-FIRST-AND-DO-NOT-DELETE.txt
│   ├── published wiring images
│   └── SourceDocs\
│
└── MusicalStage\
    ├── _MSB-DB-Source-Folder_READ-ME-FIRST-AND-DO-NOT-DELETE.txt
    ├── published wiring images
    └── SourceDocs\
```

The marker in `Wiring` identifies the controlled Wiring source root.

The marker in `BackgroundStage` or `MusicalStage` identifies the actual published branch used by FieldWiring.

### `SourceDocs` is excluded

Do **not** treat `SourceDocs` as a field-application source folder.

It contains working/source material and is specifically excluded from FieldWiring. It does not require a field-source marker unless a future approved design changes that rule.

---

## Procedure folders

The future Procedure system follows the same rule: every folder used by the application must be marked.

Current controlled procedure paths include:

```text
Procedures\
├── _MSB-DB-Source-Folder_READ-ME-FIRST-AND-DO-NOT-DELETE.txt
│
├── Inspection\
│   └── _MSB-DB-Source-Folder_READ-ME-FIRST-AND-DO-NOT-DELETE.txt
│
├── Setup\
│   ├── _MSB-DB-Source-Folder_READ-ME-FIRST-AND-DO-NOT-DELETE.txt
│   ├── Archive\
│   ├── images\
│   └── SourceDocs\
│
└── Takedown\
    ├── _MSB-DB-Source-Folder_READ-ME-FIRST-AND-DO-NOT-DELETE.txt
    ├── Archive\
    ├── images\
    └── SourceDocs\
```

`Procedures`, `Inspection`, `Setup`, and `Takedown` are controlled application folders and must be marked.

### Procedure image folders

If the field Procedure system directly reads an `images` folder as part of published field content, that `images` folder must also contain the marker before it is used by the application.

This follows the same rule: **if the application uses the folder, mark it.**

### Archive and SourceDocs are excluded

`Archive` and `SourceDocs` are not normal field-presentation folders.

Do not mark them as field-application source folders unless a later approved design intentionally changes their role.

---

# Photos

`Photos` is general engineering documentation and is not currently part of the FieldWiring or Procedure application path.

Do not add a field-source marker to `Photos` merely because the folder exists.

If a future field application begins using `Photos` directly, update the governing documentation first and then mark the applicable folder before the application consumes it.

---

# What the Marker Means

The marker means:

> This folder is part of the controlled MSB field-document/application structure. Do not casually rename, move, delete, or repurpose it.

The marker does **not** mean that the folder name itself is permanent Production Database identity.

The Production Database and current LOR relationships still provide the durable identities and relationships used by the applications.

---

# Local Notes Are Allowed

Each marker may contain a `LOCAL NOTES` section.

Use it for short factual information such as:

- a known legacy exception;
- pending Folder Alignment work;
- a stale LOR background pointer that still needs correction;
- a missing field image;
- a temporary migration condition; or
- another warning a future maintainer should see before changing the folder.

Do not place passwords, credentials, API keys, or private personal information in a marker.

---

# Existing Automated Marker Utility — Important

The existing marker-population utility was written around an earlier, narrower marker rule.

Do **not** assume that running the current utility proves the complete FieldWiring/future-Procedure marker structure is correct.

The utility must be reviewed and updated separately so its targets match this current rule before it is used as the authority for full marker population.

Until that engineering work is complete, visually verify the required markers when creating or reviewing a new controlled Stage/Sub-stage/Scene structure.

---

# Before You Finish

For a Stage/Sub-stage/Scene used by the field systems, verify:

- [ ] the Stage/Sub-stage/Scene root is marked;
- [ ] every active `PreviewBackground` source folder is marked;
- [ ] `Wiring` is marked;
- [ ] each active published `BackgroundStage` / `MusicalStage` branch is marked;
- [ ] `Procedures` is marked;
- [ ] active `Inspection`, `Setup`, and `Takedown` branches are marked;
- [ ] any additional folder directly consumed by the field application is marked;
- [ ] `SourceDocs` and `Archive` remain excluded from normal field presentation; and
- [ ] marker files have not been renamed or deleted.

## Related Documents

- [Google Drive Folder Structure](00-Google_Drive.md)
- [Google Drive Document Organization Procedure](01-Google_Drive_Document_Organization_Procedure.md)
- [Google Drive Path Resolution Contract](02-Google_Drive_Path_Resolution_Contract.md)
- [Stage / Sub-stage / Scene Folder Scaffold](04-Stage_Substage_Scene_Folder_Scaffold.md)
- [FieldWiring Engineering](../02_Production_Database/01_System_Architecture/09_Wiring_System/README.md)
