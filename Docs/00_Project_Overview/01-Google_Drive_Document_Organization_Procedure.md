# Google Drive Document Organization Procedure

## Purpose

Use this procedure when organizing MSB engineering documents in the Google Shared Drive named **Display Folders**.

The goal is to put current, usable information in predictable Stage/Sub-stage/Scene locations so volunteers and future MSB applications can find it without relying on tribal knowledge.

The Shared Drive remains the permanent home for the field-facing engineering documents. The current Folder Alignment worklist is the roadmap for reconciling historical material into that structure.

Provides a consistent location for `PreviewBackground` at the Stage/Scene/Display levels used to build the previews in Light O Rama. **DO NOT MOVE, RENAME, DELETE these folders or any files in them. It will break Light O Rama Preview Editor!!**

---

# Start With the Current Documentation Alignment Worklist

Do not begin by browsing the Shared Drive and guessing where historical material belongs.

Before organizing a Stage, run the current Folder Alignment workflow and use the resulting **Documentation Alignment Worklist**.

Normal workflow:

```text
Current LOR previews
        ↓
Run and review the parser in LOR2DB
        ↓
current V7 parser SQLite snapshot
        ↓
run_folder_check.ps1
        ↓
Documentation Alignment Worklist
        ↓
human review and document alignment
```

The report is read-only. It does not move, rename, create, or delete Google Drive folders or documents.

---

# Standard Stage / Sub-stage / Scene Documentation Structure

The established Stage/Sub-stage/Scene structure defined in [Google Drive Folder Structure](00-Google_Drive.md) remains authoritative.

Folder and Scene naming used by Folder Alignment and documentation lookup must also follow the current
[Folder Alignment Engineering Design](../01_LOR_System/02_Data_Extraction/Folder_Alignment/Folder_Alignment_Engineering_Design.md).

The Photos Folder are to be used for general documentation `Not for Instructions!` These folders appear in the Stage and Scene Folders

Images needed for `Setup` or `Takedown` must be placed in the `images` folder under the respective procedure location `Not under the Stage or Scene Photos Folders!`

```text
<Stage, Sub-stage, or Scene>
├── PreviewBackground
│   └── archive
│
├── Photos
│   ├── Current
│   └── Historical
│
├── Procedures
│   ├── Inspection
│   ├── Setup
│   │   ├── Archive
│   │   ├── images
│   │   └── SourceDocs
│   └── Takedown
│       ├── Archive
│       ├── images
│       └── SourceDocs
│
└── Wiring
    ├── BackgroundStage
    │   └── SourceDocs
    └── MusicalStage
        └── SourceDocs
```

`Procedures\Inspection` is intentionally unstructured.

## Protected Names and the Database-Source Boundary

The current Stage, Sub-stage, and Scene folder names are part of the LOR/Production Database/Google Drive alignment. **Do not rename them during ordinary cleanup.** Renaming a current structured root can break stored LOR `BackgroundFile` pointers, database path evidence, and application resolution.

The following helper-folder names are also protected because they are part of the application-facing contract:

```text
PreviewBackground
Procedures
Wiring
```

Do not rename those helper folders.

Each active database/application source helper folder contains:

```text
_MSB-DB-Source-Folder_READ-ME-FIRST-AND-DO-NOT-DELETE.txt
```

The marker defines the current application-source boundary. For current database-backed discovery, **only content inside approved marked source folders is considered**. Loose files and unmarked legacy folders elsewhere under a Stage or Scene are not current application-source content merely because they are physically nearby.

This rule is intentionally compatible with gradual cleanup. Existing Stage and Scene folders contain many years of loose files, legacy folders, and other engineering material. Do not move, rename, or delete that material just to make the root look like the current scaffold. Preserve it until its purpose and correct destination are understood.

Conceptually:

```text
Stage / Scene root
├── PreviewBackground/   <- marked current DB/application source
├── Procedures/          <- marked current DB/application source
├── Wiring/              <- marked current DB/application source
├── Photos/              <- general documentation; not DB source currently
├── legacy folder(s)     <- preserve; ignored by application discovery
└── loose legacy files   <- preserve; ignored by application discovery
```

As legacy material is reviewed, it may be deliberately moved into the appropriate marked source structure. Until then, applications must ignore it rather than guess based on filename, folder name, or proximity.

See [MSB Database Source Folder Marker — Operator Procedure](03-MSB_DB_Source_Folder_Marker_Operator_Procedure.md) for marker use, local notes, and the automated population utility.

## When a Scene Should Be Used

A Scene should be created when a group of Displays is installed and wired as one physical unit and therefore shares a common wiring harness or common field setup.

This creates one meaningful documentation scope for both Wiring and Setup.

Examples include a group of Displays that:

- use one common wiring harness;
- are installed together as one field assembly;
- share one wiring diagram;
- share common Setup or Takedown instructions; or
- need to be treated as one recognizable field area even though they contain
  multiple individual Displays.

When such a Scene is created, its name must begin with the owning Stage ID:

    NN-Scene Name

or, when owned by a Sub-stage:

    NNa-Scene Name

Example:

    01-Entrance Arch

The corresponding Google Drive Scene folder uses the same Stage-prefixed name and receives the standard Stage/Sub-stage/Scene documentation structure.

A child folder without the Stage/Sub-stage ID prefix remains a Display or shared Display/group folder. It is not a Scene documentation scope and does not receive the standard Procedures and Wiring trees.

## Procedure Lookup

Procedure lookup uses the same Stage/Sub-stage/Scene hierarchy.

For a Display contained in a defined Scene:

    Display
        -> owning Scene
        -> owning Sub-stage, when applicable
        -> owning Stage

The Scene is therefore the preferred location for procedures that apply to the group as a whole.

If a Display is not contained in a defined Scene, procedure lookup falls back to the applicable Stage or Sub-stage.

An unprefixed Display/group folder must not be promoted to a Scene merely because an LOR BackgroundFile path passes through that folder.

Display folders use a smaller standard structure. The minimum folders are:

```text
<Display>
├── PreviewBackground
│   ├── preview development
│   ├── channel assignments
│   └── archive
├── design archive
└── Photos
    ├── Current
    └── Historical
```

A Display may exist directly under a Stage or under a Scene/Sub-stage. A Display does not automatically receive `Procedures` or `Wiring` folders. Use the Display Name to name the folder. Do not use the 2 letter prefix. Use the name only from the Comment field in the preview editor. This will make moving displays easier in the future.

Do not redesign the Stage/Sub-stage/Scene hierarchy while performing document cleanup.

Not every LOR Display needs its own Google Drive folder, and not every Display needs its own Setup procedure. Shared Stage or Scene instructions should remain shared rather than being duplicated under every Display.

---

# Legacy Setup Alignment Workflow

## Central legacy source

Historical Setup documents are currently being reconciled from the central legacy repository:

```text
G:\Shared drives\Display Folders\000-Instructions\0 - Setup Procedures
```

The Folder Alignment report inventories this source so the remaining backlog can be seen while work progresses.

A filename or fuzzy name match is **not** final ownership authority.

## Human ownership decision

Eric is reviewing the legacy material and determining the correct current Stage, Sub-stage, or Scene based on the real field organization and the Folder Alignment worklist.

When the ownership of a legacy Setup document is understood, move the original legacy Google Doc into the applicable Stage/Sub-stage/Scene Setup archive:

```text
<Stage, Sub-stage, or Scene>\
    Procedures\
        Setup\
            Archive\
                <legacy document>.gdoc
```

Example:

```text
01-Front Entrance-FE\
    Procedures\
        Setup\
            Archive\
                01 - Front Arch.gdoc
```

This move is important because it records a **human-audited ownership decision**.

If a stage has the old 2 digit StageID be sure to update it to the current stage and remove the spaces that surrround the -

Example:

```text
 25 - Magic Igloo.gdoc Gets changed to 26-Magic Igloo.gdoc
```

Once the legacy document is located under a Stage/Sub-stage/Scene `Procedures\Setup\Archive` folder, Folder Alignment no longer needs to infer ownership from a fuzzy historical filename. The current folder location is stronger evidence of where that legacy procedure belongs.

## What remains in `000-Instructions`

As reviewed legacy files are moved out of the central `000-Instructions\0 - Setup Procedures` backlog, the number of unresolved historical Setup documents should steadily decrease.

At the same time, the applicable Stage/Sub-stage/Scene `Procedures\Setup\Archive` folders should become populated with the legacy documents that have been deliberately assigned there.

The Folder Alignment worklist should therefore support both sides of the migration:

- remaining legacy Setup files still under `000-Instructions`;
- human-audited legacy Setup files now under the correct Stage/Sub-stage/Scene `Procedures\Setup\Archive` location.

Do not automatically move a document merely because its name resembles a Display, Stage, Sub-stage, or Scene name.

---

# Procedure Audit and Reformatting — Next Step

Moving a legacy Google Doc into `Procedures\Setup\Archive` does **not** make it the current field instruction.

It means only that its Stage/Sub-stage/Scene ownership has been reviewed and accepted.

The next phase is to audit each archived legacy Setup procedure and convert useful current information into the controlled Stage Setup Instruction format.

The intended workflow is:

```text
legacy .gdoc in Procedures\Setup\Archive
        ↓
review content
        ↓
apply the approved Stage Setup Instruction template
        ↓
field review / approval
        ↓
publish current field PDF
        ↓
place current PDF in Procedures\Setup
```

The controlled Stage Setup Instruction template is maintained in the `Shared Drives/Display Folders` under:

```text
System_Documentation\Templates\Stage_Setup_Instruction_Template.md
```

The exact contributor workflow and final template formatting are controlled separately. Do not invent historical revision numbers or approvals while converting legacy documents.

---

# Current Setup Publication Location

The current field-facing Setup document belongs in the applicable Stage, Sub-stage, or Scene:

```text
<Stage, Sub-stage, or Scene>\Procedures\Setup
```

Example target state:

```text
01-Front Entrance-FE\
    Procedures\
        Setup\
            Archive\
                01 - Front Arch.gdoc
            images\
            SourceDocs\
            Front Entrance Setup.pdf
```

`Archive` contains superseded or historical source material and must not be treated as current field authority.

`images` contains image assets used by the Setup instructions.

`SourceDocs` contains Setup working/source material and is not intended for direct field presentation.

Current PDFs or other approved rendered field documents belong in the normal `Procedures\Setup` presentation area.

Do not delete the archived legacy Google Doc merely because a current PDF has been produced. The archive preserves the historical source and migration evidence.

---

# Future Setup Application Discovery

The Setup application should use the same general location-resolution principle already proven by FormView for Wiring:

```text
structured Stage / Sub-stage / Scene identity
        +
standardized Google Drive documentation location
        ↓
field-facing presentation
```

For Setup, once the correct Stage, Sub-stage, or Scene is resolved, the application can locate the current field documents under:

```text
<Stage, Sub-stage, or Scene>\Procedures\Setup
```

The `Procedures` source root must be an approved marked database-source folder before the application treats its content as current application-source material.

Archive and SourceDocs content must be excluded from normal field presentation.

Normal field users should not need to know the Google Drive hierarchy. The long-term presentation path remains:

```text
Display QR
    ↓
Production Database Display identity
    ↓
Stage / Sub-stage / Scene relationships
    ↓
applicable current Setup document
    ↓
my.sheboyganlights.org
```

The durable database/document-ID relationship is a separate engineering problem. Do not make the QR code depend directly on a Google Drive path.

---

# How to Work One Stage

1. Run or open the current Documentation Alignment Worklist.
2. Select one Stage and preserve its current aligned Stage folder name.
3. Preserve the marked `PreviewBackground`, `Procedures`, and `Wiring` helper-folder names.
4. Treat material outside the marked source folders as legacy/general engineering material unless and until it is deliberately aligned.
5. Review the remaining legacy Setup files reported from `000-Instructions\0 - Setup Procedures`.
6. Human-review the legacy file and determine its correct Stage, Sub-stage, or Scene ownership.
7. If ownership is understood, move the original legacy `.gdoc` into that Stage/Sub-stage/Scene `Procedures\Setup\Archive` folder.
8. If ownership is uncertain, leave the file in the central legacy source and flag it for review.
9. Do not clean unrelated loose Stage/Scene files or legacy folders merely because they are outside the marked source structure.
10. Continue until the Stage/Sub-stage/Scene legacy material has been reconciled.
11. Re-run Folder Alignment when a fresh snapshot of migration progress is needed.
12. In the procedure-audit phase, process each archived legacy document through the controlled Setup Instruction template.
13. After review/approval, publish the current field PDF in the applicable `Procedures\Setup` folder.
14. Keep the superseded source in `Archive`.

---

# Where Other Engineering Material Belongs

The central historical Setup tree may contain drawings, photographs, references, and other engineering material in addition to actual Setup instructions.

Drawings, images, sketches for each individual display belong in the display folder preferably organized into sensible folders.

Do not assume every file historically stored under `0 - Setup Procedures` must become a Setup Instruction.

During human review:

- actual legacy Setup instructions may move to `Procedures\Setup\Archive`;
- Display-specific drawings or fabrication material should remain with the responsible Display engineering records;
- photos should use the appropriate Stage/Sub-stage/Scene/Display `Photos\Current` or `Photos\Historical` location when understood;
- uncertain material should remain in place until its purpose is known.

The old location is evidence, not final classification authority.

---

# Wiring Remains Separate

Do not reorganize Wiring as though it were a Setup procedure.

Wiring continues to use:

```text
Wiring\BackgroundStage
Wiring\MusicalStage
```

with working/source material under the corresponding `SourceDocs` location.

The `Wiring` root is a protected marked database-source folder. Do not rename it. FieldWiring should consider published wiring only through the marked `Wiring` source structure and must ignore unrelated loose Stage/Scene files and unmarked legacy folders.

The existing FormView architecture remains the precedent for resolving standardized field documentation from structured Stage/LOR context.

---

# Important Rules

1. Use the current Documentation Alignment Worklist as the migration roadmap.
2. Keep the established Stage/Sub-stage/Scene folder structure and do not rename an aligned Stage/Sub-stage/Scene root during ordinary cleanup.
3. Do not rename the marked `PreviewBackground`, `Procedures`, or `Wiring` helper folders.
4. Treat only approved marked source folders as current database/application source locations.
5. Preserve loose files and unmarked legacy folders until they have been deliberately reviewed; applications must ignore them for current discovery.
6. Treat the central `000-Instructions\0 - Setup Procedures` tree as the unresolved legacy backlog.
7. A human-audited move into `Procedures\Setup\Archive` establishes the accepted Stage/Sub-stage/Scene ownership of that legacy document.
8. Do not rely on fuzzy filename matching once the document has been human-assigned to an Archive location.
9. Do not publish an archived legacy `.gdoc` as though it were the current field instruction.
10. Audit and reformat the legacy procedure using the controlled Setup Instruction template before publishing a current version.
11. Keep the current field PDF or other approved presentation directly available from `Procedures\Setup`.
12. Exclude `Archive` and `SourceDocs` material from normal field-user navigation.
13. Do not delete useful historical engineering material merely to make the folder tree look clean.
14. Do not assume every Display requires a Setup procedure.
15. Do not assume every file in the legacy Setup repository is actually a procedure.
16. When uncertain, preserve the material and flag it for review instead of guessing.

---

# Completion Goal

The migration phase is progressing correctly when:

- the current aligned Stage/Sub-stage/Scene and marked source-folder names remain stable;
- applications can ignore unmarked legacy material and use only the controlled marked source structure;
- the unresolved central legacy Setup backlog becomes smaller;
- reviewed legacy procedures appear under the correct Stage/Sub-stage/Scene `Procedures\Setup\Archive` folders;
- Folder Alignment can verify those human-audited locations without fuzzy ownership inference;
- audited current field PDFs begin appearing in the corresponding `Procedures\Setup` folders; and
- archive documents remain preserved but are excluded from normal field presentation.

The end goal is simple: a volunteer should eventually be able to scan a Display QR code and reach the current Setup information that applies to that Display's Stage/Sub-stage/Scene without needing to know where someone stored the document years ago.

---

## Related Documents

- [Google Drive Folder Structure](00-Google_Drive.md) — engineering architecture and folder-location contract.
- [MSB Database Source Folder Marker — Operator Procedure](03-MSB_DB_Source_Folder_Marker_Operator_Procedure.md) — identifies the current database/application source boundary inside existing Stage/Scene trees.
- [LOR System Documentation](../01_LOR_System/README.md) — LOR-side system documentation.
- [FormView](../01_LOR_System/04_FormView/README.md) — proven field-wiring application and location-resolution precedent.
- [Stage Setup Documentation Standard](../../System_Documentation/Project_Rules/Stage_Setup_Documentation_Standard.md) — governance for controlled field-facing Setup Instructions.
- [Stage Setup Instruction Template](../../System_Documentation/Templates/Stage_Setup_Instruction_Template.md) — controlled draft formatting structure for current Setup Instructions.