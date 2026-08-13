# Folder Alignment — Engineering Design

## Purpose

Folder Alignment is a read-only LOR-side data extraction/alignment tool used to compare the current V7 LOR parser snapshot with the actual engineering-document structure on the Google Shared Drive.

It supports two related jobs:

1. resolve the current Stage / Scene / Sub-stage documentation scope from LOR/parser evidence; and
2. provide a worklist for reconciling historical documentation into the established Google Drive structure.

Folder Alignment does not create, move, rename, or delete folders or documents. Human review remains authoritative for migration decisions.

---

## System Boundary

```text
LOR preview files
    -> run_parse_props.ps1
    -> lor_output_v7_scene.db
    -> run_folder_check.ps1
    -> Folder Alignment
    -> read-only Documentation Alignment Worklist
```

PostgreSQL and LOR2DB are not working data sources for Folder Alignment. The current V7 parser SQLite output is deliberately used so LOR organization and document alignment can be inspected repeatedly before any PostgreSQL ingest or downstream document-index work.

The parser snapshot provenance in `parser_run` identifies the exact production Preview folder used to build the current SQLite snapshot. Folder Alignment must preserve that provenance and must not guess which versioned production Preview folder produced the database.

---

## Validation Status of the Naming Rules

The naming/resolution rules in the next section are a **provisional Folder Alignment contract under validation**.

They are being tested first in this read-only alignment tool against the current production parser snapshot and current Google Drive tree.

Until testing is accepted:

- do not change parser extraction behavior solely to implement these rules;
- do not update the parser architecture to claim these classifications are parser-owned behavior;
- do not promote these rules into a broader project naming standard;
- do not move Google Drive content automatically.

If the test proves the contract, corresponding parser documentation and applicable naming standards may then be updated through normal change control.

---

# Stage / Scene / Display Resolution Contract — Provisional

## Parser evidence vs Folder Alignment classification

The V7 parser preserves the raw LOR Scene `Name`, derives a Stage token into `scenes.StageID`, derives descriptive text into `SceneSection`, preserves `Scene.BackgroundFile`, and records Scene membership.

The parser does **not** currently classify a Scene row as a filesystem Stage, Sub-stage, Scene, or Display folder.

Folder Alignment performs that downstream documentation-scope classification without changing parser data.

`SceneSection` is descriptive only. It must not be treated as an authoritative folder identity.

## Top-level Stage and Sub-stage

The root documentation identity is a Stage or parser-recognized Sub-stage.

The parser already supports Stage tokens in the established forms:

```text
NN
NNa
```

Examples:

```text
07
07a
```

A Sub-stage may have its own documentation root while still belonging beneath a top-level Stage.

Example:

```text
07-Whoville-WV\07a-Who Forest-WF
```

The tool must preserve both concepts when they differ:

```text
Top-level Stage:       07-Whoville-WV
Documentation root:    07-Whoville-WV\07a-Who Forest-WF
```

## Provisional deterministic Scene-name classification

For Folder Alignment testing, the raw LOR Scene `Name` is classified using the following convention.

### Stage root

```text
NN-Name-XY
```

where `NN` is the Stage token and `XY` is the established two-letter Stage suffix.

Example:

```text
07-Whoville-WV
```

Classification:

```text
STAGE_ROOT
```

The expected Drive location is the top-level Stage folder matching that identity.

### Sub-stage root

```text
NNa-Name-XY
```

Example:

```text
07a-Who Forest-WF
```

Classification:

```text
SUB_STAGE_ROOT
```

The expected Drive location is the established Sub-stage root beneath its owning top-level Stage.

### Scene under a Stage or Sub-stage

```text
NN-Name
NNa-Name
```

with no trailing two-letter Stage/Sub-stage suffix.

Examples:

```text
13-Christmas Story
30-Santa's Station Entrance
```

Classification:

```text
SCENE
```

The Stage token identifies the owning Stage/Sub-stage root. The raw Scene name is the expected child Scene folder name.

### Unprefixed Scene name

A Scene name with no parser-recognized `NN` or `NNa` prefix is not a Stage/Scene documentation folder by default.

Example:

```text
Abominable
```

Classification for Folder Alignment:

```text
DISPLAY_OR_GROUP
```

Display/group classifications remain useful for engineering validation but are suppressed from the normal Setup documentation worklist. They do not receive standardized Stage/Scene helper folders.

## Reserved `Root` Scene name for Background Previews

A Background Preview already has a definitive Stage identity from `previews.StageID`.

For a Background Preview, the reserved Scene name:

```text
Root
```

means:

> use the owning Preview's Stage documentation root.

`Root` is a scope marker, **not** a physical child folder name.

Therefore:

```text
Preview StageID: 06
Scene Name: Root
```

resolves to the Stage 06 root folder and must **not** create or expect:

```text
<Stage 06>\Root
```

Existing Background Preview Scene names such as `Scene 1` or `Background` may remain visible as migration/normalization findings until the LOR Previews are intentionally renamed. The long-term deterministic target is `Root`.

Bare `Root` is not sufficient to assign a Stage inside a multi-Stage Master Musical Preview and must not be used there as a substitute for Stage identity.

---

# Preview-Type Resolution Rules — Provisional

## Background Preview behavior

A Background Preview's `previews.StageID` is definitive parent Stage evidence.

Resolution order for the Folder Alignment test is:

1. identify the owning Stage from `previews.StageID`;
2. if Scene `Name = Root`, resolve directly to that Stage root;
3. if the Scene name follows a Stage/Sub-stage root naming form, classify it accordingly;
4. if the Scene name follows the `NN-Name` / `NNa-Name` Scene form, resolve it beneath the matching owning Stage/Sub-stage;
5. an unprefixed non-`Root` Scene name is a Display/group classification, not a new documentation root.

A Background Scene that is actually a current Display must not be promoted into a fake Scene helper scope or be used to imply a Display-specific `Procedures\Setup` folder.

## Master Musical Preview behavior

The annual Master Musical Preview name is provenance, not per-Scene Stage identity.

For Master Musical Scenes, the raw Scene name must explicitly carry enough identity to classify the intended documentation scope unless an authoritative filesystem path already establishes it.

Resolution evidence is:

1. `Scene.BackgroundFile`, when present and valid, is authoritative filesystem evidence for the documentation root;
2. otherwise the deterministic raw Scene-name classification above identifies Stage root, Sub-stage root, Scene, or Display/group;
3. parser-derived `SceneStageID` is supporting Stage-token evidence but is not itself proof that the Scene row is a Stage folder;
4. unprefixed names do not establish a Stage/Scene documentation root.

The Master Musical Preview's own Preview name must not be used as the per-Scene Stage identity.

## BackgroundFile as filesystem evidence

When a Scene `BackgroundFile` points into the established Shared Drive hierarchy, Folder Alignment derives the documentation root from the folder immediately above the recognized `\Wiring\` branch.

Example — Stage root:

```text
G:\Shared drives\Display Folders\02-Triangle-TR\Wiring\MusicalStage\...
```

Example — nested Sub-stage:

```text
G:\Shared drives\Display Folders\07-Whoville-WV\07a-Who Forest-WF\Wiring\MusicalStage\...
```

The stored path is the important filesystem evidence; the background image filename itself is not identity.

The derived path must resolve to a valid Stage/Sub-stage/Scene documentation root. A Display folder must not be promoted into a structured documentation root merely because an image path exists beneath it.

---

# Documentation Root and Calling-System Contract

Folder Alignment resolves a **documentation root** first.

Examples:

```text
G:\Shared drives\Display Folders\01-Front Entrance-FE
```

or:

```text
G:\Shared drives\Display Folders\07-Whoville-WV\07a-Who Forest-WF
```

A calling workflow then looks below that root for the branch it owns.

Examples:

```text
Setup workflow  -> <documentation root>\Procedures\Setup
Wiring workflow -> <documentation root>\Wiring
Photos workflow -> <documentation root>\Photos
```

The classification layer should not hard-code every consuming application's detailed file-selection behavior.

Whether a Scene consumer should present only Scene-local documents, inherit Stage documents, or present both is **not yet decided by this Folder Alignment contract**. Do not implement implicit fallback/inheritance until that user-facing behavior is separately reviewed.

---

# Standard Documentation Scope

Standard structured helper folders belong **only** at applicable Stage / Scene / Sub-stage documentation roots.

Display folders do not receive this standard helper structure.

The standard Stage/Scene/Sub-stage structure is:

```text
Wiring/
├── BackgroundStage/
│   └── SourceDocs/
└── MusicalStage/
    └── SourceDocs/

Procedures/
├── Setup/
│   ├── Archive/
│   └── images/
├── Takedown/
├── Maintenance/
├── Operations/
└── SourceDocs/

Photos/
├── Current/
├── Setup/
├── Takedown/
├── Reference/
└── Historical/
```

Current field-facing Setup PDFs belong directly in:

```text
<Stage or Scene>\Procedures\Setup
```

Legacy/superseded Setup source documents belong in:

```text
<Stage or Scene>\Procedures\Setup\Archive
```

Setup-supporting images belong in:

```text
<Stage or Scene>\Procedures\Setup\images
```

Display folders may exist directly beneath a Stage or beneath a real Scene/Sub-stage. Their presence does not make them documentation roots and does not imply standardized `Procedures`, `Wiring`, or `Photos` helpers.

---

# Legacy Setup Migration Contract

## Central unresolved backlog

The central historical Setup backlog is:

```text
G:\Shared drives\Display Folders\000-Instructions\0 - Setup Procedures
```

Folder Alignment may recursively inventory this source so the remaining migration backlog is visible.

Historical filenames that begin with a two-digit Stage number may be grouped into a Stage worklist for discovery. Loose name similarity may be useful for human review.

However:

> Filename prefixes and fuzzy name matches are discovery aids only. They are not the final ownership contract.

## Human-audited move establishes ownership

The authoritative migration step is performed by a human reviewer.

When Eric or another authorized reviewer determines that a legacy Setup document belongs to a specific Stage or Scene, the original `.gdoc` is moved into:

```text
<Stage or Scene>\Procedures\Setup\Archive\<legacy document>.gdoc
```

Example:

```text
01-Front Entrance-FE\
    Procedures\
        Setup\
            Archive\
                01 - Front Arch.gdoc
```

This location is stronger evidence than the historical filename because the move records a deliberate human audit of document ownership.

Once a legacy document appears under a resolved Stage/Scene `Procedures\Setup\Archive`, Folder Alignment should treat that location as the accepted ownership relationship and should not need fuzzy matching to decide which Stage/Scene owns that document.

## Migration progress model

Folder Alignment should eventually show both sides of the migration:

```text
UNRESOLVED LEGACY BACKLOG
000-Instructions\0 - Setup Procedures\...

        ↓ human review / move

HUMAN-ALIGNED LEGACY SOURCE
<Stage or Scene>\Procedures\Setup\Archive\...
```

As alignment proceeds:

- the central unresolved backlog decreases;
- Stage/Scene `Setup\Archive` locations become populated;
- more document ownership becomes deterministic from filesystem location;
- dependence on fuzzy matching decreases.

---

# Procedure Audit / Publication Contract

A legacy `.gdoc` under `Procedures\Setup\Archive` is **not** a current field instruction.

It is historical source material whose ownership has been established.

The next workflow is:

```text
legacy .gdoc in Setup\Archive
        ↓
audit content
        ↓
apply controlled Stage Setup Instruction template
        ↓
review / approval
        ↓
publish current field PDF
        ↓
<Stage or Scene>\Procedures\Setup\<current PDF>
```

The exact controlled template, revision rules, durable Google document identifier, PDF publication workflow, and database relationship are governed outside this LOR-side alignment tool.

---

# Folder Alignment Report Model

The report is a **worklist and validator**, not a migration script.

The normal Setup-alignment report should focus on Stage / Sub-stage / Scene documentation scopes.

Display/group reconciliation is an optional engineering diagnostic and should be suppressed by default.

For Setup documentation the report should eventually show, per resolved Stage/Scene documentation scope:

- classification (`STAGE_ROOT`, `SUB_STAGE_ROOT`, `SCENE`);
- raw LOR Scene name and Preview context;
- parser Stage evidence;
- resolved top-level Stage;
- resolved documentation root;
- resolution reason/evidence (`BackgroundFile`, deterministic name contract, or `Root` marker);
- `Procedures\Setup` location;
- `Archive` status;
- `images` status;
- current field-facing Setup files found directly in the current presentation area;
- legacy `.gdoc` files found under `Procedures\Setup\Archive`;
- remaining central legacy Setup files still under `000-Instructions\0 - Setup Procedures`;
- migration status;
- unresolved/contract-violation warnings.

The report should make contract violations visible rather than silently falling back to fuzzy interpretation.

---

# Matching Philosophy

> Deterministic naming and explicit paths establish documentation scope. Fuzzy matching is limited to unresolved historical discovery.

Loose matching may remain useful while discovering plausible historical relationships inside the central legacy backlog.

It must not be used to classify current parser Scene rows as Stage/Scene/Display when the deterministic naming contract or explicit path provides the answer.

Once a human-audited migration has placed a document under a Stage/Scene `Procedures\Setup\Archive`, the filesystem location becomes authoritative migration evidence and the tool should stop trying to re-infer ownership from the legacy filename.

---

# Safety Rules

Folder Alignment must:

- remain read-only;
- never create, move, rename, or delete Google Drive folders/documents;
- use the current V7 parser SQLite snapshot as its LOR-side working source;
- preserve `parser_run.SourcePreviewFolder` as production-snapshot provenance;
- preserve the distinction between top-level Stage and nested documentation root;
- classify current Scene names deterministically under the provisional contract instead of inventing folder identity from `SceneSection`;
- recognize `Root` as a Stage-root scope marker for Background Previews, not a child folder;
- never infer a Display-specific Setup folder merely because a Display/group exists;
- apply standard helper-folder validation only to Stage / Sub-stage / Scene documentation roots;
- preserve original legacy paths while they remain in the unresolved central backlog;
- recognize `Procedures\Setup\Archive` as human-audited legacy ownership evidence;
- recognize `Procedures\Setup\images` as the Setup image-support location at Stage/Scene scope;
- keep Archive material out of current field-document counts/presentation;
- report uncertainty or naming-contract violations rather than inventing structure;
- not alter PostgreSQL schema or parser behavior as part of Folder Alignment testing.

---

# Regression Fixtures for the Provisional Contract

Testing must include at least:

- Background Preview with definitive Preview StageID and Scene `Root` -> resolves to Stage root; no `Root` child folder expected.
- Existing Background Preview still using `Scene 1` or `Background` -> reported as a normalization finding until intentionally renamed.
- `07-Whoville-WV` -> `STAGE_ROOT`.
- `07a-Who Forest-WF` -> `SUB_STAGE_ROOT`, nested under top-level Stage 07.
- `13-Christmas Story` -> `SCENE`, expected beneath Stage 13.
- unprefixed names such as `Abominable` -> `DISPLAY_OR_GROUP`, not a structured Setup scope.
- Stage 01 Front Entrance -> Display/group names must not become fake Scene Setup scopes.
- Stage 02 Triangle -> existing authoritative Musical `BackgroundFile` Stage-root evidence must continue to resolve correctly.
- Stage 07 Whoville -> authoritative paths and deterministic names must agree or produce a review finding.
- Stage 13 -> multiple `NN-Name` Scene names must resolve beneath the Stage 13 root without being mistaken for Stage roots.

---

# Implementation Sequencing

## Step 1 — current document change

This document records the provisional Folder Alignment naming/documentation-scope contract before implementation.

## Step 2 — alignment-tool test implementation

Implement the contract only in a new test version of Folder Alignment.

The test implementation must:

- remain read-only;
- not change the V7 parser;
- classify current Scene rows using raw `Name`, Preview context, and `BackgroundFile` evidence;
- suppress Display/group rows from the normal Setup worklist;
- report naming/path conflicts explicitly;
- validate `Procedures\Setup\Archive` and `Procedures\Setup\images` only at Stage/Scene/Sub-stage roots.

## Step 3 — validate against current production snapshot and Drive

Run against the current production SQLite snapshot and current Shared Drive tree. Review exceptions before accepting the contract.

## Step 4 — only after successful validation

If the contract is proven:

1. update parser documentation to explain the downstream naming semantics where appropriate without falsely claiming the parser performs classifications it does not perform;
2. review whether a broader naming-contract standard should be created or amended;
3. update operator documentation with the proven workflow;
4. only then treat the naming convention as established production governance.

Do not skip directly from proposed convention to parser/global-standard changes without the Folder Alignment validation step.
