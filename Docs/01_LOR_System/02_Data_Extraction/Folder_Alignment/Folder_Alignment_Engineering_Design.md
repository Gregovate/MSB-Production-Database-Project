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

---

## How to Run

From the repository root in the project virtual environment:

```powershell
.\run_parse_props.ps1
.\run_folder_check.ps1
```

Default SQLite source:

```text
G:\Shared drives\MSB Database\database\lor_output_v7_scene.db
```

Default Drive root:

```text
G:\Shared drives\Display Folders
```

The repository-root launcher is the operator entry point. Versioned Python files under `Folder_Alignment` are implementation/test artifacts and should not normally be run directly.

---

# Stage / Scene Resolution Contract

## Top-level Stage

The root documentation identity is always the top-level Stage under `Display Folders`.

Example:

```text
07-Whoville-WV
```

A nested Sub-stage such as:

```text
07-Whoville-WV\07a-Who Forest-WF
```

still belongs to top-level Stage 07.

The tool must preserve both concepts when they differ:

```text
Top-level Stage:       07-Whoville-WV
Documentation root:    07-Whoville-WV\07a-Who Forest-WF
```

## Background Preview behavior

Background Previews may use Scenes as real physical/documentation groupings, but a Scene-name match alone is not sufficient to create a Scene documentation scope.

A Background Scene that is actually a current Display must not be promoted into a fake Scene helper scope or be used to imply a Display-specific `Procedures\Setup` folder.

## Master Musical Preview behavior

The annual Master Musical Preview name is provenance, not per-Scene Stage identity.

For Master Musical Scenes:

1. direct Stage identity may resolve the top-level Stage;
2. `Scene.BackgroundFile` may resolve the Stage and a more-specific documentation root;
3. parser-derived Scene Stage identity remains fallback evidence;
4. the Scene name itself must not automatically become a child Drive folder.

## BackgroundFile as filesystem evidence

For an applicable Master Musical Scene, the documentation root may be derived from the path immediately above `\Wiring\`.

Example — Stage root:

```text
G:\Shared drives\Display Folders\02-Triangle-TR\Wiring\MusicalStage\...
```

Example — nested Sub-stage:

```text
G:\Shared drives\Display Folders\07-Whoville-WV\07a-Who Forest-WF\Wiring\MusicalStage\...
```

The stored path is the important filesystem evidence; the background image filename itself is not identity.

---

# Standard Documentation Scope

Standard helpers belong at an applicable Stage / Scene / Sub-stage documentation root:

```text
Wiring/
├── BackgroundStage/
│   └── SourceDocs/
└── MusicalStage/
    └── SourceDocs/

Procedures/
├── Setup/
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

Not every Display requires an individual documentation folder, and a LOR Display never implies a required `Display\Procedures\Setup` path by itself.

Setup is normally inherited from the applicable Stage / Scene / Sub-stage documentation scope.

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

This is the desired migration direction.

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

The current Setup publication area is therefore:

```text
<Stage or Scene>\Procedures\Setup
```

while historical/superseded sources belong under:

```text
<Stage or Scene>\Procedures\Setup\Archive
```

Folder Alignment should distinguish current published files from Archive material.

The exact controlled template, revision rules, durable Google document identifier, PDF publication workflow, and database relationship are governed outside this LOR-side alignment tool.

---

# Future Folder Alignment Report Model

The report is a **worklist and validator**, not a migration script.

For Setup documentation it should eventually show, per resolved Stage/Scene documentation scope:

- Stage;
- Scene / Sub-stage where applicable;
- resolved documentation root;
- `Procedures\Setup` location;
- current field-facing Setup files found directly in the current presentation area;
- legacy `.gdoc` files found under `Procedures\Setup\Archive`;
- remaining central legacy Setup files still under `000-Instructions\0 - Setup Procedures`;
- migration status;
- duplicate/ambiguous current-document warnings;
- future durable document-ID status when that contract is engineered;
- future PDF/current-publication status when that contract is engineered.

Useful migration-oriented states may include:

```text
LEGACY_UNRESOLVED
LEGACY_ALIGNED_ARCHIVE
CURRENT_SETUP_FOUND
NO_CURRENT_SETUP
DUPLICATE_CURRENT_REVIEW
MISSING_DURABLE_ID
```

Names are illustrative until implementation is reviewed. The important behavior is deterministic reporting based on the human-audited Archive location rather than continuing to depend on fuzzy legacy-name inference after migration.

---

# Historical Engineering Discovery

The central historical procedure repository can contain material that is not actually a Setup procedure, including drawings, photographs, reference files, and other engineering records.

Folder Alignment must not convert historical category membership into current document classification automatically.

During human review:

- legitimate legacy Setup instructions can be moved to `Procedures\Setup\Archive`;
- Display-specific engineering records can remain with the responsible Display documentation;
- photos and reference material can be relocated only when their ownership/purpose is understood;
- uncertain material remains preserved for review.

Historical location is evidence, not final classification authority.

---

# Matching Philosophy

> Matching may be forgiving. Recommendations must be authoritative.

Loose matching is useful while discovering plausible historical relationships inside the correct Stage.

Once a human-audited migration has placed a document under a Stage/Scene `Procedures\Setup\Archive`, the filesystem location becomes authoritative migration evidence and the tool should stop trying to re-infer ownership from the legacy filename.

---

# Safety Rules

Folder Alignment must:

- remain read-only;
- never create, move, rename, or delete Google Drive folders/documents;
- use the current V7 parser SQLite snapshot as its LOR-side working source;
- preserve the distinction between top-level Stage and nested documentation root;
- preserve Background vs Master Musical Scene semantics;
- never infer a Display-specific Setup folder merely because a Display exists;
- preserve original legacy paths while they remain in the unresolved central backlog;
- recognize `Procedures\Setup\Archive` as human-audited legacy ownership evidence;
- keep Archive material out of current field-document counts/presentation;
- report uncertainty rather than inventing structure;
- not alter PostgreSQL schema or document identity contracts.

---

# Regression Fixtures

Changes should continue to be checked against:

- Stage 01 Front Entrance — Background group names can be current Displays and must not become fake Scene Setup scopes; human-audited legacy Setup files should eventually appear in `Procedures\Setup\Archive`.
- Stage 02 Triangle — Fred's Stars resolves to Stage root from its Master Musical wiring path.
- Stage 05 Festive Trees — exact Stage identity must not create a duplicate nested Stage folder.
- Stage 07 Whoville — Who Characters/Who Spiral Tree may resolve to Stage root while Who Forest preserves `07-Whoville-WV\07a-Who Forest-WF` as a nested documentation root.
- Stage 13 Winter Wonderland — real Background Scene/shared groupings must remain intelligible.
- Stage 18 Dancing Forest — many LOR Displays legitimately share Stage-level documentation and do not require one folder/procedure per Display.

---

# Implementation Sequencing

## Current behavior to preserve

- V7 parser Stage/Scene resolution;
- `BackgroundFile` documentation-root resolution;
- recursive Shared Drive inventory;
- central `000-Instructions` visibility;
- conservative review-only historical matching;
- read-only operation.

## Next report change after review

Add deterministic scanning of:

```text
<resolved Stage/Scene>\Procedures\Setup\Archive
```

so the report can show which legacy documents have already been human-aligned and which remain in the central backlog.

Do not automatically move any files.

## Later work

Only after the human migration/audit workflow is established should Folder Alignment be extended to validate current Setup PDFs, per-instruction asset packaging, durable Google document IDs, or database/intranet integration.
