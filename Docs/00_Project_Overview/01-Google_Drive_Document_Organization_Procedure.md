# Google Drive Document Organization Procedure

## Purpose

Use this procedure when organizing MSB engineering documents in the Google Shared Drive named **Display Folders**.

The goal is to put current, usable information in predictable Stage/Scene locations so volunteers and future MSB applications can find it without relying on tribal knowledge.

The Shared Drive remains the permanent home for the field-facing engineering documents. The current Folder Alignment worklist is the roadmap for reconciling historical material into that structure.

---

# Start With the Current Documentation Alignment Worklist

Do not begin by browsing the Shared Drive and guessing where historical material belongs.

Before organizing a Stage, run the current Folder Alignment workflow and use the resulting **Documentation Alignment Worklist**.

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

The report is read-only. It does not move, rename, create, or delete Google Drive folders or documents.

---

# Standard Stage / Scene Documentation Structure

The established Stage/Scene structure remains authoritative.

```text
<Stage or Scene>
├── Wiring
│   ├── BackgroundStage
│   │   └── SourceDocs
│   └── MusicalStage
│       └── SourceDocs
│
├── Procedures
│   ├── Setup
│   ├── Takedown
│   ├── Maintenance
│   ├── Operations
│   └── SourceDocs
│
└── Photos
    ├── Current
    ├── Setup
    ├── Takedown
    ├── Reference
    └── Historical
```

Do not redesign the Stage/Scene hierarchy while performing document cleanup.

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

Eric is reviewing the legacy material and determining the correct current Stage or Scene based on the real field organization and the Folder Alignment worklist.

When the ownership of a legacy Setup document is understood, move the original legacy Google Doc into the applicable Stage/Scene Setup archive:

```text
<Stage or Scene>\
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

Once the legacy document is located under a Stage/Scene `Procedures\Setup\Archive` folder, Folder Alignment no longer needs to infer ownership from a fuzzy historical filename. The current folder location is stronger evidence of where that legacy procedure belongs.

## What remains in `000-Instructions`

As reviewed legacy files are moved out of the central `000-Instructions\0 - Setup Procedures` backlog, the number of unresolved historical Setup documents should steadily decrease.

At the same time, the applicable Stage/Scene `Procedures\Setup\Archive` folders should become populated with the legacy documents that have been deliberately assigned there.

The Folder Alignment worklist should therefore support both sides of the migration:

- remaining legacy Setup files still under `000-Instructions`;
- human-audited legacy Setup files now under the correct Stage/Scene `Procedures\Setup\Archive` location.

Do not automatically move a document merely because its name resembles a Display, Stage, or Scene name.

---

# Procedure Audit and Reformatting — Next Step

Moving a legacy Google Doc into `Procedures\Setup\Archive` does **not** make it the current field instruction.

It means only that its Stage/Scene ownership has been reviewed and accepted.

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

The controlled Stage Setup Instruction template is maintained in the Production Database repository under:

```text
System_Documentation\Templates\Stage_Setup_Instruction_Template.md
```

The exact contributor workflow and final template formatting are controlled separately. Do not invent historical revision numbers or approvals while converting legacy documents.

---

# Current Setup Publication Location

The current field-facing Setup document belongs in the applicable Stage or Scene:

```text
<Stage or Scene>\Procedures\Setup
```

Example target state:

```text
01-Front Entrance-FE\
    Procedures\
        Setup\
            Archive\
                01 - Front Arch.gdoc
            Front Entrance Setup.pdf
```

`Archive` contains superseded or historical source material and must not be treated as current field authority.

Current PDFs or other approved rendered field documents belong in the normal `Procedures\Setup` presentation area.

Do not delete the archived legacy Google Doc merely because a current PDF has been produced. The archive preserves the historical source and migration evidence.

---

# Future Setup Application Discovery

The Setup application should use the same general location-resolution principle already proven by FormView for Wiring:

```text
structured Stage / Scene identity
        +
standardized Google Drive documentation location
        ↓
field-facing presentation
```

For Setup, once the correct Stage or Scene is resolved, the application can locate the current field documents under:

```text
<Stage or Scene>\Procedures\Setup
```

Archive content must be excluded from normal field presentation.

Normal field users should not need to know the Google Drive hierarchy. The long-term presentation path remains:

```text
Display QR
    ↓
Production Database Display identity
    ↓
Stage / Scene relationships
    ↓
applicable current Setup document
    ↓
my.sheboyganlights.org
```

The durable database/document-ID relationship is a separate engineering problem. Do not make the QR code depend directly on a Google Drive path.

---

# How to Work One Stage

1. Run or open the current Documentation Alignment Worklist.
2. Select one Stage.
3. Confirm the Stage/Scene organization shown by the current Folder Alignment data.
4. Review the remaining legacy Setup files reported from `000-Instructions\0 - Setup Procedures`.
5. Human-review the legacy file and determine its correct Stage or Scene ownership.
6. If ownership is understood, move the original legacy `.gdoc` into that Stage/Scene `Procedures\Setup\Archive` folder.
7. If ownership is uncertain, leave the file in the central legacy source and flag it for review.
8. Continue until the Stage/Scene legacy material has been reconciled.
9. Re-run Folder Alignment when a fresh snapshot of migration progress is needed.
10. In the procedure-audit phase, process each archived legacy document through the controlled Setup Instruction template.
11. After review/approval, publish the current field PDF in the applicable `Procedures\Setup` folder.
12. Keep the superseded source in `Archive`.

---

# Where Other Engineering Material Belongs

The central historical Setup tree may contain drawings, photographs, references, and other engineering material in addition to actual Setup instructions.

Do not assume every file historically stored under `0 - Setup Procedures` must become a Setup Instruction.

During human review:

- actual legacy Setup instructions may move to `Procedures\Setup\Archive`;
- Display-specific drawings or fabrication material should remain with the responsible Display engineering records;
- photos should use the appropriate Stage/Scene/Display photo location when understood;
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

The existing FormView architecture remains the precedent for resolving standardized field documentation from structured Stage/LOR context.

---

# Important Rules

1. Use the current Documentation Alignment Worklist as the migration roadmap.
2. Keep the established Stage/Scene folder structure.
3. Treat the central `000-Instructions\0 - Setup Procedures` tree as the unresolved legacy backlog.
4. A human-audited move into `Procedures\Setup\Archive` establishes the accepted Stage/Scene ownership of that legacy document.
5. Do not rely on fuzzy filename matching once the document has been human-assigned to an Archive location.
6. Do not publish an archived legacy `.gdoc` as though it were the current field instruction.
7. Audit and reformat the legacy procedure using the controlled Setup Instruction template before publishing a current version.
8. Keep the current field PDF or other approved presentation directly available from `Procedures\Setup`.
9. Exclude `Archive` material from normal field-user navigation.
10. Do not delete useful historical engineering material merely to make the folder tree look clean.
11. Do not assume every Display requires a Setup procedure.
12. Do not assume every file in the legacy Setup repository is actually a procedure.
13. When uncertain, preserve the material and flag it for review instead of guessing.

---

# Completion Goal

The migration phase is progressing correctly when:

- the unresolved central legacy Setup backlog becomes smaller;
- reviewed legacy procedures appear under the correct Stage/Scene `Procedures\Setup\Archive` folders;
- Folder Alignment can verify those human-audited locations without fuzzy ownership inference;
- audited current field PDFs begin appearing in the corresponding `Procedures\Setup` folders; and
- archive documents remain preserved but are excluded from normal field presentation.

The end goal is simple: a volunteer should eventually be able to scan a Display QR code and reach the current Setup information that applies to that Display's Stage/Scene without needing to know where someone stored the document years ago.

---

## Related Documents

- [Google Drive Folder Structure](00-Google_Drive.md) — engineering architecture and folder-location contract.
- [LOR System Documentation](../01_LOR_System/README.md) — LOR-side system documentation.
- [FormView](../01_LOR_System/04_FormView/README.md) — proven field-wiring application and location-resolution precedent.
- [Stage Setup Documentation Standard](../../System_Documentation/Project_Rules/Stage_Setup_Documentation_Standard.md) — governance for controlled field-facing Setup Instructions.
- [Stage Setup Instruction Template](../../System_Documentation/Templates/Stage_Setup_Instruction_Template.md) — controlled draft formatting structure for current Setup Instructions.
