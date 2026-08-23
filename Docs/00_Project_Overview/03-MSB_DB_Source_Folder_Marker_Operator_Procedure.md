# MSB Database Source Folder Marker — Operator Procedure

## Purpose

Use this procedure when working with Google Drive folders that are part of the current FieldWiring system or the future Setup/Takedown/Inspection system.

The marker file tells people and applications that a folder is part of a controlled MSB field-document structure. Marker placement is **application-specific**: FieldWiring and the future Procedure system do not use identical marker rules.

## Standard File Name

Use this exact file name:

```text
_MSB-DB-Source-Folder_READ-ME-FIRST-AND-DO-NOT-DELETE.txt
```

Do not shorten, rename, move, or delete an approved marker.

---

# Current FieldWiring Marker Rule

The accepted FieldWiring contract is:

```text
<Stage / Sub-stage / Scene root>     marker required
PreviewBackground                    marker required when used as a current controlled source
Wiring                               marker required
Wiring\BackgroundStage              NO separate marker
Wiring\MusicalStage                 NO separate marker
SourceDocs                           NO marker / excluded from field presentation
```

This is the production-aligned rule. Do not add child markers to `Wiring\BackgroundStage` or `Wiring\MusicalStage`, and do not remove the existing Stage/Sub-stage/Scene root marker or `Wiring` marker.

The current FieldWiring implementation matches this contract: it resolves the structured scope, checks the scope marker, and treats the marker on the `Wiring` root as the guard for the selected `BackgroundStage` or `MusicalStage` branch.

### Stage / Sub-stage / Scene roots

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

The root marker identifies and protects the structured Stage/Sub-stage/Scene scope.

Do not rename or move a marked Stage/Sub-stage/Scene root as ordinary cleanup.

### Preview backgrounds

Any `PreviewBackground` folder used as a current LOR/application source must contain the marker.

This includes an applicable Stage, Sub-stage, Scene, Display, or shared-group `PreviewBackground` folder.

```text
PreviewBackground\
├── _MSB-DB-Source-Folder_READ-ME-FIRST-AND-DO-NOT-DELETE.txt
└── current background images
```

Referenced background images must not be casually renamed, moved, or deleted because LOR may point directly to them.

### FieldWiring folders

The controlled Wiring structure is:

```text
Wiring\
├── _MSB-DB-Source-Folder_READ-ME-FIRST-AND-DO-NOT-DELETE.txt
│
├── BackgroundStage\
│   ├── published wiring images
│   └── SourceDocs\
│
└── MusicalStage\
    ├── published wiring images
    └── SourceDocs\
```

The marker in `Wiring` identifies the controlled Wiring source root. `BackgroundStage` and `MusicalStage` are child branches selected by wiring context and are **not separately marked**.

A missing child marker in `BackgroundStage` or `MusicalStage` is therefore **not** an implementation gap and is not a folder-alignment defect.

### `SourceDocs` is excluded

Do **not** treat `SourceDocs` as a field-application source folder.

It contains working/source material and is specifically excluded from FieldWiring. It does not require a field-source marker unless a future approved design deliberately changes that role.

---

# Future Procedure Marker Rule

The Procedure system has its own controlled path and may require markers deeper than FieldWiring.

Current planned Procedure locations are:

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
│   │   └── _MSB-DB-Source-Folder_READ-ME-FIRST-AND-DO-NOT-DELETE.txt
│   └── SourceDocs\
│
└── Takedown\
    ├── _MSB-DB-Source-Folder_READ-ME-FIRST-AND-DO-NOT-DELETE.txt
    ├── Archive\
    ├── images\
    │   └── _MSB-DB-Source-Folder_READ-ME-FIRST-AND-DO-NOT-DELETE.txt
    └── SourceDocs\
```

For the Procedure system, `Procedures`, `Inspection`, `Setup`, `Setup\images`, `Takedown`, and `Takedown\images` are planned controlled application folders and must be marked when that application contract is in use.

Do **not** copy the Procedure marker rule onto the FieldWiring `BackgroundStage` / `MusicalStage` child branches. The two applications have different folder guards.

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

> This folder is part of a controlled MSB field-document/application structure. Do not casually rename, move, delete, or repurpose it.

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

# Existing Marker Utilities — Important

Marker utilities must follow the application-specific rules above.

Do **not** use an older utility or checklist as authority for adding markers to `Wiring\BackgroundStage` or `Wiring\MusicalStage`.

The existing `remove_misplaced_msb_db_scope_root_markers.ps1` utility was created during an intermediate design that treated Stage/Sub-stage/Scene root markers as incorrect. **Do not run that utility under the current architecture.** Current field systems require the structural marker on those roots.

Do not run marker utilities merely to make production folders match superseded documentation. The production FieldWiring folders were already aligned to the accepted rule above.

---

# Before You Finish

For a Stage/Sub-stage/Scene used by FieldWiring, verify:

- [ ] the Stage/Sub-stage/Scene root is marked;
- [ ] every active `PreviewBackground` source folder is marked;
- [ ] `Wiring` is marked;
- [ ] `Wiring\BackgroundStage` and `Wiring\MusicalStage` do **not** require separate markers;
- [ ] `SourceDocs` remains excluded from normal field presentation; and
- [ ] approved marker files have not been renamed or deleted.

For future Procedure work, separately verify the Procedure-specific marker locations defined above.

## Related Documents

- [Google Drive Folder Structure](00-Google_Drive.md)
- [Google Drive Document Organization Procedure](01-Google_Drive_Document_Organization_Procedure.md)
- [Google Drive Path Resolution Contract](02-Google_Drive_Path_Resolution_Contract.md)
- [Stage / Sub-stage / Scene Folder Scaffold](04-Stage_Substage_Scene_Folder_Scaffold.md)
- [FieldWiring Engineering](../02_Production_Database/01_System_Architecture/09_Wiring_System/README.md)
