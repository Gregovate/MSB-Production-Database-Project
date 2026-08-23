# Stage / Sub-stage / Scene Folder Scaffold

## Purpose

Use this scaffold whenever a new **Stage, formal Sub-stage, or Scene documentation folder** is created in the Google Shared Drive `Display Folders` repository.

New Stages are expected to be uncommon. New **Scene** folders are more likely as the physical/documentation organization is refined, so Scene creation is the most common use of this scaffold.

The scaffold provides a complete controlled starting structure so a newly created Scene does not begin as another one-off legacy folder.

It does not require existing legacy Stage/Scene roots to be cleaned up immediately. Existing loose files and legacy folders may remain while Folder Alignment work proceeds.

---

# Before Creating a Scene Folder

Do **not** create a Google Drive Scene folder merely because a Scene exists in Light-O-Rama.

Create a Scene folder when the Scene represents a real shared physical/documentation scope, for example when a group of Displays:

- is installed as one recognizable field assembly;
- shares a wiring harness or wiring drawing;
- shares Setup or Takedown instructions;
- owns a meaningful common Preview background; or
- otherwise needs its own durable documentation scope beneath the Stage/Sub-stage.

If the LOR Scene exists only for sequencing clarity, keep its documentation at the applicable Stage or Sub-stage instead of creating an unnecessary folder.

---

# Scene Folder Naming

Use the current Google Drive path-resolution naming rules.

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
07a-<Scene Name>
```

Do not add the Stage's trailing two-letter folder code to an ordinary Scene name merely to make it resemble the Stage root.

Once an aligned Stage/Sub-stage/Scene folder is in use, do not rename or move it except as a deliberate coordinated alignment correction.

---

# Controlled Scaffold

Use this structure for every newly created Stage, Sub-stage, or Scene documentation root:

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

There is no generic `Procedures\SourceDocs` root contract. Setup and Takedown each own their own `SourceDocs` folder.

Legacy `Photos\Reference`, `Photos\Setup`, and `Photos\Takedown` folders may still exist in older Stage/Scene trees, but they are not part of the current canonical scaffold. Preserve legacy content until it is deliberately reviewed; do not create those legacy folders in new scopes.

`desktop.ini` or other Windows-generated metadata is not part of the controlled scaffold and does not need to be copied deliberately.

---

# Marker Placement Rule

The standard marker filename is:

```text
_MSB-DB-Source-Folder_READ-ME-FIRST-AND-DO-NOT-DELETE.txt
```

The current field-document applications use the same basic guard pattern:

> **mark the resolved structured scope, then mark the application subsystem root. The application selects controlled child branches by folder name without another marker layer.**

## FieldWiring

For FieldWiring, markers are required in:

1. the Stage / Sub-stage / Scene root;
2. `PreviewBackground` when it is a current controlled LOR/application source; and
3. `Wiring`.

`Wiring\BackgroundStage` and `Wiring\MusicalStage` are **not separately marked**. The marker on the `Wiring` root guards those published child branches.

## Procedure system

For the Procedure system, markers are required in:

1. the Stage / Sub-stage / Scene root; and
2. `Procedures`.

The controlled child branches are selected by folder name:

```text
Procedures\Inspection
Procedures\Setup
Procedures\Takedown
```

Those task branches do **not** require separate markers.

`Procedures\Setup\images` and `Procedures\Takedown\images` are supporting child folders beneath the marked `Procedures` root and do **not** require separate markers.

`SourceDocs` and `Archive` are working/history folders excluded from normal field presentation and are not field-application marker targets unless a future approved design changes their role.

`Photos` is not currently part of the FieldWiring/Procedure application source path and is not marked by this scaffold.

Earlier 2026-08-22 wording that required a marker in every Procedure task/image folder is superseded by this subsystem-root marker contract.

See [MSB Database Source Folder Marker — Operator Procedure](03-MSB_DB_Source_Folder_Marker_Operator_Procedure.md).

---

# New Folder vs. Existing Legacy Folder

A **new** Stage/Sub-stage/Scene folder should start with the controlled scaffold above and should not accumulate unrelated loose files at its root.

An **existing** Stage/Sub-stage/Scene root may already contain years of loose files and legacy folders. Do not reorganize those merely to make the old folder look like a new scaffold.

For existing folders:

- preserve the aligned root name;
- preserve the controlled field-application folder names;
- add/maintain only the markers required by the applicable application contract;
- preserve unrelated legacy material until it can be reviewed; and
- allow applications to ignore material outside the controlled source paths.

This allows gradual cleanup without breaking LOR paths or current field applications.

---

# Source Folder Rules

## PreviewBackground

Use `PreviewBackground` for current images intentionally used as LOR Preview/Scene background references.

For new authoring, choose the Scene/Preview `BackgroundFile` from an approved controlled location. Do not create new LOR references into loose legacy material when a controlled source folder is available.

A `PreviewBackground` used as a current controlled source carries its marker.

## Wiring

Published FieldWiring images belong directly in the applicable branch:

```text
Wiring\BackgroundStage
Wiring\MusicalStage
```

The `Wiring` root must be marked. The `BackgroundStage` and `MusicalStage` child branches do **not** require their own marker.

`SourceDocs` is working/source material and is not normal field-facing content.

Do not point a new Scene background into `SourceDocs`. Existing legacy pointers may remain temporarily while alignment work continues, but new authoring should use `PreviewBackground` or a directly published Wiring image.

## Procedures

Published field procedure material belongs directly in the applicable Procedure task branch:

```text
Procedures\Inspection
Procedures\Setup
Procedures\Takedown
```

The `Procedures` root must be marked. The `Inspection`, `Setup`, and `Takedown` child branches do **not** require their own markers.

Setup/Takedown `images` folders are supporting task-local asset folders and do **not** require separate markers.

`Archive` and `SourceDocs` are not normal field-facing content.

## Photos

`Photos` remains general documentation and is not currently a FieldWiring/Procedure application source folder.

The current canonical photo structure for a new Stage/Sub-stage/Scene is:

```text
Photos\Current
Photos\Historical
```

Do not recreate legacy `Photos\Setup`, `Photos\Takedown`, or `Photos\Reference` folders as part of a new scaffold.

---

# New Scene Folder Checklist

When a new Scene documentation folder is approved:

- [ ] Confirm the Scene represents a real physical/documentation scope, not merely sequencing convenience.
- [ ] Confirm the owning Stage or Sub-stage.
- [ ] Name the folder using the current `NN-Scene Name` / `NNa-Scene Name` rule.
- [ ] Create the complete current scaffold, not only the one helper folder needed today.
- [ ] Add the marker to the Scene root.
- [ ] Add the marker to `PreviewBackground` when it is a current controlled source.
- [ ] Add the marker to `Wiring`.
- [ ] Do **not** add separate FieldWiring markers to `Wiring\BackgroundStage` or `Wiring\MusicalStage`.
- [ ] Add the marker to `Procedures` when the Procedure subsystem is being prepared/used.
- [ ] Do **not** add separate markers to `Procedures\Inspection`, `Procedures\Setup`, `Procedures\Takedown`, or their `images` folders.
- [ ] Do not mark `SourceDocs` or `Archive` as normal field sources.
- [ ] Do not create a generic `Procedures\SourceDocs` folder.
- [ ] Do not recreate legacy `Photos\Setup`, `Photos\Takedown`, or `Photos\Reference` folders in new scopes.
- [ ] Do not rename the standard helper folders.
- [ ] Put new LOR background references only in approved controlled source locations.
- [ ] Never use `SourceDocs` as a normal field-document or new LOR background endpoint.
- [ ] Add local notes to a marker when a known exception or pending alignment item should be visible to future maintainers.
- [ ] When the approved LOR Scene structure changes, allow the normal parser/snapshot workflow to pick up the change; creating the Drive folder does not itself update the Production Database.

---

# Simple Rule

> Create the complete current Stage/Sub-stage/Scene scaffold immediately, then mark the structured scope and each application subsystem root that is actually consumed. `Wiring` guards `BackgroundStage` / `MusicalStage`; `Procedures` guards `Inspection` / `Setup` / `Takedown`. Do not add another marker layer to those fixed child branches.

---

## Related Documents

- [Google Drive Folder Structure](00-Google_Drive.md)
- [Google Drive Document Organization Procedure](01-Google_Drive_Document_Organization_Procedure.md)
- [Google Drive Path Resolution Contract](02-Google_Drive_Path_Resolution_Contract.md)
- [MSB Database Source Folder Marker — Operator Procedure](03-MSB_DB_Source_Folder_Marker_Operator_Procedure.md)
- [Folder Alignment Engineering Design](../01_LOR_System/02_Data_Extraction/Folder_Alignment/Folder_Alignment_Engineering_Design.md)
- [Procedure System Field Context Handoff](../02_Production_Database/01_System_Architecture/12_Setup_and_Deployment/00_Procedure_System_Field_Context_Handoff_2026-08-22.md)
- [Building the Master Musical Preview](../01_LOR_System/01_Preview_Authoring/E_Master_Musical_Preview_Howto.md)
