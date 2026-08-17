# Folder Alignment — Engineering Design

## Purpose

Folder Alignment is a read-only LOR-side data extraction/alignment tool used to compare the current V7 LOR parser snapshot with the actual engineering-document structure on the Google Shared Drive.

It supports two related jobs:

1. resolve the current Stage / Sub-stage / Scene / Display scope from LOR/parser evidence; and
2. provide a worklist for reconciling historical documentation into the current Google Drive structure.

Folder Alignment itself does not create, move, rename, or delete folders or documents.

A separate narrow updater may add an approved missing `PreviewBackground` folder to an already-existing deterministically resolved scope. That updater does not change Folder Alignment's read-only contract.

---

# System Boundary

```text
LOR preview files
    -> repeatable parser run and review in the LOR2DB website
    -> lor_output_v7_scene.db
    -> run_folder_check.ps1
    -> Folder Alignment
    -> read-only Documentation Alignment Worklist
```

PostgreSQL and LOR2DB are not working data sources for Folder Alignment. The current V7 parser SQLite output is deliberately used so LOR organization and document alignment can be inspected repeatedly before PostgreSQL ingest.

The website is the normal parser entry point. The repository-root
`run_parse_props.ps1` launcher is an engineering/recovery fallback only; either
entry point must produce the same validated SQLite contract before Folder
Alignment is run.

The parser snapshot provenance in `parser_run` identifies the exact Preview folder used to build the current SQLite snapshot.

---

# Status of the Naming Rules

The Scene naming/resolution rules in this document are the current
project-specific Folder Alignment contract.

They are applied against the current parser snapshot and Google Drive tree.
They classify LOR Scene-name hooks for documentation lookup; they do not change
parser extraction behavior and are not parser-owned physical identity rules.
Conflicts are reported instead of guessed.

The Google Drive root-folder structure documented below is the current target structure for this alignment work.

---

# Parser Evidence vs Folder Alignment Classification

The V7 parser preserves:

- raw LOR Scene `Name`;
- parser-derived Stage token in `scenes.StageID`;
- descriptive `SceneSection`;
- `Scene.BackgroundFile`;
- Scene membership.

The parser does not currently classify a Scene row as a filesystem Stage, Sub-stage, Scene, or Display folder.

`SceneSection` is descriptive only and must not be used as authoritative folder identity.

---

# Deterministic Scene-Name Classification

## Stage root

```text
NN-Name-XY
```

Example:

```text
07-Whoville-WV
```

Classification:

```text
STAGE_ROOT
```

## Sub-stage root

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

The Sub-stage remains physically nested beneath its owning top-level Stage but uses the same root structure as a Stage and Scene.

## Scene

```text
NN-Name
NNa-Name
```

with no trailing two-letter Stage/Sub-stage suffix.

Classification:

```text
SCENE
```

The Stage/Sub-stage token identifies the owning root and the raw Scene name is the expected child folder name.

## Unprefixed Scene name

An unprefixed non-`Root` Scene name is treated as Display/group evidence rather than a new Stage/Scene documentation root.

Classification:

```text
DISPLAY_OR_GROUP
```

## Reserved `Root`

For a Background Preview that already has a definitive `previews.StageID`:

```text
Scene Name: Root
```

means:

> use the owning Preview's Stage root.

`Root` is a scope marker, not a physical child folder.

Bare `Root` must not be used to assign a Stage inside a multi-Stage Master Musical Preview.

---

# Preview-Type Resolution Rules

## Background Preview

A Background Preview's `previews.StageID` is definitive parent Stage evidence.

Resolution order:

1. identify owning Stage from `previews.StageID`;
2. `Root` resolves directly to the Stage root;
3. deterministic Stage/Sub-stage/Scene naming forms may resolve subordinate scopes;
4. an unprefixed non-`Root` Scene name is Display/group evidence.

## Master Musical Preview

The annual Master Musical Preview name is provenance, not per-Scene Stage identity.

Resolution evidence is:

1. `Scene.BackgroundFile`, when valid, provides explicit filesystem evidence;
2. otherwise deterministic raw Scene naming identifies Stage/Sub-stage/Scene/Display-group scope;
3. parser-derived `SceneStageID` is supporting Stage-token evidence but is not itself proof of a folder type.

---

# BackgroundFile and PreviewBackground

`Scene.BackgroundFile` is the stored LOR path to a background image. A valid current path is useful filesystem evidence, but arbitrary loose image locations are fragile.

The current Drive contract provides a stable asset folder named:

```text
PreviewBackground
```

at every scope that may independently own a Preview/Scene background:

```text
Stage\PreviewBackground\
Sub-stage\PreviewBackground\
Scene\PreviewBackground\
Display\PreviewBackground\
```

The long-term intent is for LOR background images to use these stable scope-local locations where practical.

`PreviewBackground` is not a documentation type. Its presence on a Display does not make the Display a full Stage/Scene documentation scope.

---

# Standard Stage / Sub-stage / Scene Root

Stage, Sub-stage, and Scene use one identical root structure:

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

There is no generic `Procedures\SourceDocs` root contract. Setup and Takedown each own their own `SourceDocs` folder.

Current approved field-facing files belong directly in the applicable procedure branch. `Archive`, `images`, and `SourceDocs` are support/source areas.

---

# Standard Display Root

An existing Display folder uses the smaller standard structure:

```text
<Display>\
├── PreviewBackground\
└── Photos\
    ├── Current\
    └── Historical\
```

A Display does not automatically receive `Procedures` or `Wiring`.

A Display may exist directly beneath a Stage or beneath a Scene/Sub-stage. Its parent scope is used for shared procedure/wiring discovery.

Not every LOR Display requires a Google Drive Display folder. Folder Alignment and update tools must never create a Display parent folder merely because a parser Display exists.

---

# Legacy Structure Migration

Older folder structures may still exist, including examples such as:

```text
Photos\Setup
Photos\Takedown
Photos\Reference
Procedures\Maintenance
Procedures\Operations
Procedures\SourceDocs
```

These may contain useful historical material.

Migration rule:

> Add the current canonical structure where safe; preserve existing material until its contents have been reviewed.

Folder Alignment reports differences. It does not clean up old structures automatically.

---

# PreviewBackground Additive Updater

The narrow updater is:

```text
Docs/01_LOR_System/02_Data_Extraction/Folder_Alignment/update_previewbackground_folders.py
```

Windows launcher:

```powershell
.\run_previewbackground_update.ps1
```

Linux launcher:

```bash
bash ./run_previewbackground_update.sh ...
```

Default mode is dry-run.

```powershell
.\run_previewbackground_update.ps1
```

Apply mode requires explicit operator intent:

```powershell
.\run_previewbackground_update.ps1 --apply
```

The updater may only create:

```text
<already-existing resolved scope>\PreviewBackground
```

The updater must never:

- create the parent Stage/Sub-stage/Scene/Display folder;
- move files/folders;
- rename files/folders;
- delete files/folders;
- overwrite an existing item;
- replace a non-folder item named `PreviewBackground`;
- use fuzzy matching when multiple Display-folder candidates exist.

Display folders are eligible only when an already-existing folder can be uniquely resolved to a current parser Display using exact normalized naming behavior. Zero matches are left alone; multiple matches are reported/skipped.

The updater writes a timestamped CSV audit log to the Folder Alignment output directory.

---

# Legacy Setup Migration Contract

The central historical Setup backlog remains:

```text
G:\Shared drives\Display Folders\000-Instructions\0 - Setup Procedures
```

Historical filename matching is discovery evidence only.

When a human reviewer establishes ownership of a legacy Setup document, the original source may be moved into:

```text
<Stage / Sub-stage / Scene>\Procedures\Setup\Archive\<legacy document>.gdoc
```

That human-audited location is stronger ownership evidence than a fuzzy filename match.

A legacy `.gdoc` in `Archive` is historical source material, not the current field instruction.

---

# Folder Alignment Report Model

The report is a worklist and validator.

It should make visible:

- raw LOR Scene name;
- Preview context;
- parser Stage evidence;
- deterministic classification;
- resolved Stage/Sub-stage/Scene path;
- BackgroundFile evidence;
- naming/path conflicts;
- current standard-folder status;
- legacy Setup migration status;
- unresolved exceptions.

Display diagnostics may remain optional in the normal report, but Display scope still matters to `PreviewBackground` and Display photo validation.

---

# Safety Rules

Folder Alignment must:

- remain read-only;
- use the current V7 parser SQLite snapshot;
- preserve parser-run provenance;
- preserve top-level Stage vs nested Sub-stage/Scene distinction;
- use raw Scene `Name`, Preview context, Stage tokens, and explicit path evidence rather than `SceneSection` as folder identity;
- recognize `Root` as a Stage-root marker for Background Previews;
- not invent parent scope when evidence is ambiguous;
- preserve legacy material;
- report uncertainty rather than silently guessing;
- not alter PostgreSQL or parser behavior during Folder Alignment testing.

The separate PreviewBackground updater must remain additive-only under the restrictions defined above.

---

# Regression Fixtures

Testing should include:

- Background Preview + Scene `Root` -> owning Stage root; no `Root` child folder;
- `07-Whoville-WV` -> Stage root;
- `07a-Who Forest-WF` -> Sub-stage root;
- `13-Christmas Story` -> Scene beneath Stage 13;
- unprefixed Display/group name -> not a structured Stage/Scene root;
- Stage-level Display -> existing Display may receive `PreviewBackground` and `Photos`, but not Stage/Scene `Procedures`/`Wiring`;
- Scene-level Display -> same Display root contract beneath the Scene;
- explicit BackgroundFile vs deterministic-name conflict -> report for review;
- existing legacy helper folders -> preserve contents; do not auto-delete.

---

# Implementation Sequencing

Current order of work:

1. run current V7 parser repeatedly while LOR Preview/Scene naming and paths are corrected;
2. run Folder Alignment and inspect deterministic scope behavior;
3. use the PreviewBackground updater in dry-run mode;
4. review proposed additions;
5. apply only missing `PreviewBackground` folders to already-existing resolved scopes;
6. continue placing stable background images and finishing LOR `BackgroundFile` paths;
7. later validate/add the rest of the current Stage/Scene and Display folder structure without deleting existing historical material;
8. only after naming behavior is proven, update parser documentation and broader naming contracts as appropriate.
