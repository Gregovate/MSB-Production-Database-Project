# Google Drive Document Organization Procedure

## Purpose

Use this procedure when organizing MSB engineering documents in the Google Shared Drive named **Display Folders**.

The goal is to put current, usable information in predictable Stage, Sub-stage, Scene, and Display locations so volunteers and future MSB applications can find it without relying on tribal knowledge.

The Shared Drive remains the permanent home for field-facing engineering documents. Folder Alignment remains the read-only worklist/validator used to reconcile current LOR structure with the Drive.

---

# Start With the Current Documentation Alignment Worklist

Before organizing a Stage, run the current Folder Alignment workflow and use the resulting Documentation Alignment Worklist.

Normal workflow:

```text
Current LOR previews
        ↓
run_parse_props.ps1
        ↓
current V7 parser SQLite snapshot
        ↓
run_folder_check.ps1
        ↓
Documentation Alignment Worklist
        ↓
human review and document alignment
```

Folder Alignment is read-only. It does not move, rename, create, or delete Google Drive folders or documents.

---

# Current Folder Contracts

## Stage / Sub-stage / Scene

Stage, Sub-stage, and Scene roots use one identical structure:

```text
<Stage / Sub-stage / Scene>\
│
├── PreviewBackground\
│
├── Photos\
│   ├── Current\
│   └── Historical\
│
├── Procedures\
│   ├── Inspection\
│   │
│   ├── Setup\
│   │   ├── Archive\
│   │   ├── images\
│   │   └── SourceDocs\
│   │
│   └── Takedown\
│       ├── Archive\
│       ├── images\
│       └── SourceDocs\
│
└── Wiring\
    ├── BackgroundStage\
    │   └── SourceDocs\
    └── MusicalStage\
        └── SourceDocs\
```

`Procedures\Inspection` is intentionally unstructured.

Do not create a generic `Procedures\SourceDocs` folder under the Procedures root. Setup and Takedown each own their own `SourceDocs` location.

## Display

A Display folder uses a smaller structure:

```text
<Display>\
├── PreviewBackground\
└── Photos\
    ├── Current\
    └── Historical\
```

A Display does not automatically receive `Procedures` or `Wiring` folders.

A Display may exist directly under a Stage or under a Scene/Sub-stage. Its parent documentation scope is used for shared Procedures/Wiring discovery.

---

# PreviewBackground

`PreviewBackground` is the stable location for images intentionally referenced by LOR as Preview/Scene background files.

It is expected at all four scope types:

```text
Stage\PreviewBackground\
Sub-stage\PreviewBackground\
Scene\PreviewBackground\
Display\PreviewBackground\
```

This prevents LOR `BackgroundFile` paths from depending on arbitrary loose image files that may later be renamed, deleted, or moved.

The folder may contain one or more images as required by LOR authoring. The presence of `PreviewBackground` on a Display does not make the Display a full Stage/Scene documentation root.

---

# Additive PreviewBackground Update Tool

A separate updater exists because Folder Alignment must remain read-only.

Windows launcher:

```powershell
.\run_previewbackground_update.ps1
```

The default run is a **dry-run**. It reports which missing `PreviewBackground` folders would be added but makes no Drive changes.

After reviewing the dry-run output:

```powershell
.\run_previewbackground_update.ps1 --apply
```

The updater is intentionally narrow. It may only create:

```text
<existing resolved scope>\PreviewBackground
```

It must never:

- create a Stage, Sub-stage, Scene, or Display parent folder;
- move files or folders;
- rename files or folders;
- delete files or folders;
- overwrite an existing item;
- treat a non-folder item named `PreviewBackground` as safe to replace.

Only already-existing scopes resolved from the current V7 parser snapshot and current Drive tree are eligible.

The updater writes a CSV audit log to the Folder Alignment report output directory.

---

# Legacy Tree Migration Safety

The Google Drive tree contains older standardized structures and historical material. The current structure is different from some earlier folder conventions.

Do **not** delete old folders simply because they are no longer part of the current contract.

Examples that may still exist include:

```text
Photos\Setup
Photos\Takedown
Photos\Reference
Procedures\Maintenance
Procedures\Operations
Procedures\SourceDocs
```

These may contain useful files. Until reviewed, they remain historical evidence.

The migration rule is:

> Add the current canonical structure where safe; preserve existing material until its contents have been reviewed.

The current `PreviewBackground` updater follows that rule by creating only the missing approved folder and leaving all existing content untouched.

---

# Legacy Setup Alignment Workflow

## Central legacy source

Historical Setup documents are currently being reconciled from:

```text
G:\Shared drives\Display Folders\000-Instructions\0 - Setup Procedures
```

Folder Alignment inventories this source so the remaining backlog can be seen while work progresses.

A filename or fuzzy name match is not final ownership authority.

## Human ownership decision

When the ownership of a legacy Setup document is understood, move the original legacy Google Doc into the applicable Stage/Sub-stage/Scene Setup archive:

```text
<Stage / Sub-stage / Scene>\
    Procedures\
        Setup\
            Archive\
                <legacy document>.gdoc
```

This move records a human-audited ownership decision.

Once a legacy document is located under the correct `Procedures\Setup\Archive`, Folder Alignment should use that filesystem location as stronger evidence than a fuzzy historical filename.

Do not automatically move a document merely because its name resembles a Display, Stage, or Scene name.

---

# Procedure Audit and Publication

Moving a legacy Google Doc into `Procedures\Setup\Archive` does not make it the current field instruction.

The intended workflow is:

```text
legacy .gdoc in Procedures\Setup\Archive
        ↓
review content
        ↓
apply the controlled Stage Setup Instruction template
        ↓
field review / approval
        ↓
publish current field PDF
        ↓
place current PDF directly in Procedures\Setup
```

The controlled Stage Setup Instruction template is maintained under:

```text
System_Documentation\Templates\Stage_Setup_Instruction_Template.md
```

Do not invent historical revision numbers or approvals while converting legacy documents.

---

# Current Procedure Publication Locations

Current approved field-facing Setup material belongs directly in:

```text
<Stage / Sub-stage / Scene>\Procedures\Setup
```

Current approved field-facing Takedown material belongs directly in:

```text
<Stage / Sub-stage / Scene>\Procedures\Takedown
```

Within either branch:

```text
Archive\
images\
SourceDocs\
```

are support/source areas and must not be treated as the current field presentation set.

`Inspection` remains a direct unstructured procedure area:

```text
<Stage / Sub-stage / Scene>\Procedures\Inspection
```

---

# Photos

Current photo locations are deliberately simple.

At Stage/Sub-stage/Scene scope:

```text
Photos\Current
Photos\Historical
```

At Display scope:

```text
Photos\Current
Photos\Historical
```

Legacy Photo categories may remain until reviewed. Do not delete or move their contents automatically.

---

# Wiring Remains Separate

Wiring uses:

```text
Wiring\BackgroundStage
Wiring\MusicalStage
```

with working/source material under the corresponding `SourceDocs` folder.

Do not reorganize Wiring as though it were a Setup/Takedown procedure.

The existing FormView architecture remains the precedent for resolving standardized field documentation from structured Stage/LOR context.

---

# How to Work One Stage

1. Run the current V7 parser.
2. Run Folder Alignment and review the Stage/Scene classification.
3. If `PreviewBackground` folders need to be added, run `run_previewbackground_update.ps1` in dry-run mode.
4. Review every proposed `WOULD_CREATE` entry.
5. Run the updater with `--apply` only when the proposed scope list is correct.
6. Place/relocate LOR background images into the appropriate stable `PreviewBackground` locations as the Preview paths are completed.
7. Continue human review of legacy Setup files from `000-Instructions\0 - Setup Procedures`.
8. Move a legacy Setup document into the correct `Procedures\Setup\Archive` only when ownership is understood.
9. Preserve uncertain or old material until its purpose is known.
10. Re-run the parser and Folder Alignment whenever LOR Scene names, background paths, or Drive structure changes materially.

---

# Important Rules

1. Folder Alignment remains read-only.
2. `PreviewBackground` is standard at Stage, Sub-stage, Scene, and Display scope.
3. Stage, Sub-stage, and Scene use the same full root structure.
4. Display uses only `PreviewBackground` plus `Photos\Current` and `Photos\Historical` as the current standard structure.
5. `Inspection` remains unstructured.
6. Setup and Takedown each contain `Archive`, `images`, and `SourceDocs`.
7. Do not create a generic `Procedures\SourceDocs` root folder.
8. Do not delete legacy folders merely because the standard changed.
9. Do not move legacy content automatically.
10. Do not create a Display folder just because an LOR Display exists.
11. Use the current parser snapshot and current Drive tree for scope resolution.
12. When uncertain, preserve the material and flag it for review instead of guessing.

---

# Completion Goal

The migration is progressing correctly when:

- stable `PreviewBackground` locations exist where needed at Stage, Sub-stage, Scene, and existing Display scopes;
- LOR background paths increasingly point to those stable asset locations;
- Stage/Sub-stage/Scene roots converge on one standard structure;
- existing Display folders converge on the smaller Display structure;
- legacy folders/files remain protected until reviewed;
- reviewed Setup/Takedown source material is placed under the appropriate controlled branch; and
- applications can resolve current engineering information without depending on fragile ad-hoc paths.

---

## Related Documents

- [Google Drive Folder Structure](00-Google_Drive.md) — engineering architecture and folder-location contract.
- [Folder Alignment Engineering Design](../01_LOR_System/02_Data_Extraction/Folder_Alignment/Folder_Alignment_Engineering_Design.md) — parser/Drive resolution and validation behavior.
- [LOR System Documentation](../01_LOR_System/README.md) — LOR-side system documentation.
- [FormView](../01_LOR_System/04_FormView/README.md) — proven field-wiring application and location-resolution precedent.
- [Stage Setup Documentation Standard](../../System_Documentation/Project_Rules/Stage_Setup_Documentation_Standard.md) — governance for controlled field-facing Setup Instructions.
- [Stage Setup Instruction Template](../../System_Documentation/Templates/Stage_Setup_Instruction_Template.md) — controlled draft formatting structure for current Setup Instructions.
