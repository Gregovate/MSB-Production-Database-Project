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
├── Procedures/
│   ├── _MSB-DB-Source-Folder_READ-ME-FIRST-AND-DO-NOT-DELETE.txt
│   ├── Inspection/
│   ├── Setup/
│   │   ├── Archive/
│   │   ├── images/
│   │   └── SourceDocs/
│   ├── Takedown/
│   │   ├── Archive/
│   │   ├── images/
│   │   └── SourceDocs/
│   └── SourceDocs/
│
├── Wiring/
│   ├── _MSB-DB-Source-Folder_READ-ME-FIRST-AND-DO-NOT-DELETE.txt
│   ├── BackgroundStage/
│   │   └── SourceDocs/
│   └── MusicalStage/
│       └── SourceDocs/
│
└── Photos/
    ├── Current/
    ├── Historical/
    ├── Reference/
    ├── Setup/
    └── Takedown/
```

`desktop.ini` or other Windows-generated metadata is not part of the controlled scaffold contract and does not need to be copied deliberately.

---

# Marker Placement

The standard marker filename is:

```text
_MSB-DB-Source-Folder_READ-ME-FIRST-AND-DO-NOT-DELETE.txt
```

A marker is required in:

1. the Stage / Sub-stage / Scene root;
2. `PreviewBackground`;
3. `Procedures`; and
4. `Wiring`.

Do **not** place a database-source marker in `Photos` at this time.

The root marker protects and identifies the aligned structural scope. The helper-folder markers identify the current database/application source folders.

Use the personalized marker text for each location. Local notes may be added in the marker's `LOCAL NOTES` section when useful.

See [MSB Database Source Folder Marker — Operator Procedure](03-MSB_DB_Source_Folder_Marker_Operator_Procedure.md).

---

# New Folder vs. Existing Legacy Folder

A **new** Stage/Sub-stage/Scene folder should start with the controlled scaffold above and should not accumulate unrelated loose files at its root.

An **existing** Stage/Sub-stage/Scene root may already contain years of loose files and legacy folders. Do not reorganize those merely to make the old folder look like a new scaffold.

For existing folders:

- preserve the aligned root name;
- preserve the marked helper-folder names;
- use marked `PreviewBackground`, `Procedures`, and `Wiring` as the current application-source boundary;
- preserve unrelated legacy material until it can be reviewed; and
- allow applications to ignore unmarked legacy material.

This is what allows gradual cleanup without breaking LOR paths or current database-backed applications.

---

# Source Folder Rules

## PreviewBackground

Use `PreviewBackground` for current images intentionally used as LOR Preview/Scene background references.

For **new authoring**, choose the Scene/Preview `BackgroundFile` from an approved marked source location. Do not create new LOR references into loose legacy material when a controlled source folder is available.

## Wiring

Published FieldWiring images belong directly in the applicable branch:

```text
Wiring\BackgroundStage
Wiring\MusicalStage
```

`SourceDocs` is working/source material and is not normal field-facing content.

**Do not point a new Scene background into `SourceDocs`.** Existing legacy pointers may remain temporarily while alignment work continues, but new authoring should use `PreviewBackground` or a directly published Wiring image.

## Procedures

Published field procedure material belongs in the approved procedure branch. `Archive` and `SourceDocs` are not normal field-facing content.

## Photos

`Photos` remains general documentation and is not currently a Production Database/application source folder.

---

# New Scene Folder Checklist

When a new Scene documentation folder is approved:

- [ ] Confirm the Scene represents a real physical/documentation scope, not merely sequencing convenience.
- [ ] Confirm the owning Stage or Sub-stage.
- [ ] Name the folder using the current `NN-Scene Name` / `NNa-Scene Name` rule.
- [ ] Create the complete scaffold, not only the one helper folder needed today.
- [ ] Add the structural root marker.
- [ ] Add the personalized markers to `PreviewBackground`, `Procedures`, and `Wiring`.
- [ ] Do not mark `Photos`.
- [ ] Do not rename the standard helper folders.
- [ ] Put new LOR background references only in approved marked source locations.
- [ ] Never use `SourceDocs` as a normal field-document or new LOR background endpoint.
- [ ] Add local notes to a marker when a known exception or pending alignment item should be visible to future maintainers.
- [ ] When the approved LOR Scene structure changes, allow the normal parser/snapshot workflow to pick up the change; creating the Drive folder does not itself update the Production Database.

---

# Simple Rule

> If a new Stage, Sub-stage, or Scene documentation folder is needed, create it from the complete scaffold immediately. Do not invent a partial folder structure and plan to fix it later.

---

## Related Documents

- [Google Drive Folder Structure](00-Google_Drive.md)
- [Google Drive Document Organization Procedure](01-Google_Drive_Document_Organization_Procedure.md)
- [Google Drive Path Resolution Contract](02-Google_Drive_Path_Resolution_Contract.md)
- [MSB Database Source Folder Marker — Operator Procedure](03-MSB_DB_Source_Folder_Marker_Operator_Procedure.md)
- [Building the Master Musical Preview](../01_LOR_System/01_Preview_Authoring/E_Master_Musical_Preview_Howto.md)
