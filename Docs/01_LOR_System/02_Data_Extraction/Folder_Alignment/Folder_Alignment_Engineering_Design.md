# Folder Alignment — Engineering Design

## Purpose

Folder Alignment is a read-only LOR-side data extraction/alignment tool used to compare the current LOR parser snapshot with the actual engineering-document structure on the Google Shared Drive.

It is intended to answer four different questions without changing the filesystem:

1. What top-level Stage does current LOR data belong to?
2. What Stage, Sub-stage, or Background Scene documentation scope should be used for helper folders such as `Procedures`, `Wiring`, and `Photos`?
3. Which historical Display/shared-documentation folders plausibly correspond to current LOR Display identities?
4. Which legacy procedure documents already exist in the central `000-Instructions` repository and appear to belong to each Stage?

The tool does not create, move, rename, or delete folders. All filesystem changes remain human decisions.

---

## System Boundary

Folder Alignment belongs to the LOR data-extraction side of the system.

```text
LOR preview files
    -> run_parse_props.ps1
    -> lor_output_v7_scene.db
    -> run_folder_check.ps1
    -> Folder Alignment
    -> read-only Documentation Alignment Worklist
```

PostgreSQL and LOR2DB are not data sources for this tool. The current parser SQLite output is deliberately used so Preview and filesystem changes can be inspected repeatedly before any PostgreSQL ingest is accepted.

---

## How to Run Folder Alignment

Run from the repository root in the project virtual environment:

```powershell
.\run_parse_props.ps1
.\run_folder_check.ps1
```

`run_parse_props.ps1` refreshes the current parser SQLite snapshot.

`run_folder_check.ps1` runs the current read-only Folder Alignment implementation and opens the report folder when the run succeeds.

Default SQLite source:

```text
G:\Shared drives\MSB Database\database\lor_output_v7_scene.db
```

Default Drive root:

```text
G:\Shared drives\Display Folders
```

Default report folder:

```text
G:\Shared drives\MSB Database\Database Previews V6.6.4\reports\google-drive-alignment
```

The Folder Alignment launcher is the operator entry point. Versioned Python files under `Folder_Alignment` are implementation/test artifacts and should not be run directly unless specifically debugging the tool.

---

## Data Sources

### LOR-side source

The parser SQLite snapshot provides:

- Preview identity and Preview name;
- Stage ID fields;
- Scene name and parser-derived Scene Stage identity;
- Scene `BackgroundFile` paths;
- Display identity;
- Display Scene membership;
- Device type; and
- parser provenance.

Only `DeviceType = 'LOR'` Displays are included in Display-folder reconciliation.

### Google Drive engineering source

Primary root:

```text
G:\Shared drives\Display Folders
```

The Shared Drive is the permanent engineering-document repository. Historical nesting is evidence, not automatically the expected hierarchy.

### Central legacy procedure source

Folder Alignment also recognizes a central historical procedure repository when a single top-level folder named `000-Instructions` exists directly beneath `Display Folders`:

```text
G:\Shared drives\Display Folders\000-Instructions
```

This source is distinct from legacy `000-Instructions` or generic `Instructions` folders found inside individual Stage trees.

The central repository is scanned recursively. Historical category folders may include structures such as:

```text
000-Instructions
├── 0 - Setup Procedures
├── 1 - Takedown Procedures
├── 2 - Testing & Repair Procedures
└── other historical categories
```

A central legacy file is associated to a Stage only when its filename begins with a two-digit Stage number. For example, a filename beginning with `07` is reported as legacy material associated with Stage 07.

This filename association is discovery evidence only. It is not permission to move, rename, replace, or publish the file automatically.

The report must preserve:

- the original file name;
- the full original path;
- the central legacy category;
- the Stage association derived from the leading two-digit filename prefix; and
- files that cannot be associated to a Stage.

The existence of historical material moved from categories such as `0 - Setup Procedures` into Stage engineering folders is evidence that this central repository was part of the previous documentation workflow and should be treated as an explicit migration/review source.

---

# Core Resolution Model

## 1. The root is always the top-level Stage

Every documentation relationship ultimately belongs to one top-level Stage folder under `Display Folders`.

The top-level Stage is identified primarily by the existing two-digit Stage ID folder.

Example:

```text
07-Whoville-WV
```

A nested Sub-stage such as:

```text
07-Whoville-WV\07a-Who Forest-WF
```

is still part of top-level Stage 07.

The tool must preserve both concepts when they differ:

```text
Top-level Stage:       07-Whoville-WV
Documentation root:    07-Whoville-WV\07a-Who Forest-WF
```

---

## 2. Background Previews may use Scenes as real documentation grouping

Background Previews can use Scenes to divide a Stage into meaningful physical/documentation groupings.

If a Background Preview Scene has a strong existing folder match under the resolved Stage, that folder may be used as the Scene documentation root.

A missing Background Scene folder is not automatically safe to create. If the relationship is not established strongly enough, Folder Alignment must report a review condition rather than inventing hierarchy.

---

## 3. Master Musical Preview Scenes are interpreted differently

The annual Master Musical Preview contains many Scenes in one shared Preview. Its Preview name is provenance, not a Stage identifier for each Scene.

For Master Musical Preview Scenes:

1. If the Scene name directly matches an existing Stage folder identity, that Stage is used.
2. Otherwise the Scene `BackgroundFile` path may identify the Stage and a more specific documentation root.
3. Parser-derived Scene Stage identity remains a fallback for Stage membership.
4. The Scene name itself must not automatically become a child Drive folder.

Some Master Musical Scenes exist primarily to make sequencing easier.

---

## 4. BackgroundFile is an explicit filesystem anchor

When a Master Musical Scene stores a `BackgroundFile` under the standardized Wiring hierarchy, Folder Alignment may derive the documentation root from the path immediately above `\Wiring\`.

Example — Stage-root documentation:

```text
G:\Shared drives\Display Folders\02-Triangle-TR\Wiring\MusicalStage\...
```

resolves as:

```text
Top-level Stage:    02-Triangle-TR
Documentation root: 02-Triangle-TR
```

Example — nested Sub-stage documentation:

```text
G:\Shared drives\Display Folders\07-Whoville-WV\07a-Who Forest-WF\Wiring\MusicalStage\WhoForest-Tagged.jpg
```

resolves as:

```text
Top-level Stage:    07-Whoville-WV
Documentation root: 07-Whoville-WV\07a-Who Forest-WF
```

The image content or filename is not the identity. The important information for Folder Alignment is the stored filesystem location.

A temporary background image is acceptable as an authoring placeholder when its path intentionally establishes the correct documentation root.

---

# Documentation Scope and Display Folders

## Stage / Scene / Sub-stage helper folders

Standard helper folders belong at an applicable documentation scope such as:

- top-level Stage;
- established Background Scene; or
- established nested Sub-stage/documentation root.

Standard structure:

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

---

## Displays do not require individual Setup folders

A LOR Display does not imply an individual `Procedures\Setup` folder.

Valid relationships include:

- many Displays using one Stage-wide Setup procedure;
- many Displays using one Scene or Sub-stage Setup procedure;
- one Display having Display-specific engineering records; or
- a Display having no dedicated folder at all.

Therefore Folder Alignment must not generate or recommend:

```text
<Display Folder>\Procedures\Setup
```

simply because the Display exists in LOR.

Setup is normally inherited from the applicable Stage, Scene, or Sub-stage documentation scope.

An unmatched LOR Display is a review item, not an automatic folder-creation requirement.

---

# Legacy Instruction Discovery

Folder Alignment performs two separate legacy searches.

## Local legacy search

Resolved Stage, Scene, and Sub-stage documentation scopes are searched recursively for folders named `000-Instructions` after normalization.

Generic folders named only `Instructions` are not automatically treated as equivalent because existing Stage trees contain historically ambiguous uses of that name.

## Central legacy repository search

A top-level `Display Folders\000-Instructions` repository is scanned recursively as a separate historical source.

Files beginning with a two-digit Stage number are grouped into that Stage's worklist while retaining their original category and path.

Files without a recognized Stage prefix remain visible as unassigned legacy material rather than being discarded or guessed.

Current published procedure destinations remain:

```text
Procedures\Setup
Procedures\Takedown
Procedures\Maintenance
Procedures\Operations
```

`SourceDocs` remains working/source material and is not a published field-document folder.

---

# Historical Drive Discovery

Historical Display documentation can exist at arbitrary depth beneath a Stage.

The matcher recursively inventories non-helper portions of each Stage tree and preserves the full current relative path for review.

Once a recognized helper branch such as `Wiring`, `Procedures`, or `Photos` is entered, that branch is excluded from Display fuzzy matching.

---

# Matching Philosophy

> Matching may be forgiving. Recommendations must be authoritative.

Loose matching may be used to discover plausible historical candidates inside the already-resolved top-level Stage. Cross-Stage fuzzy matching must not be used when a reliable Stage can be resolved.

---

# Report Model

The HTML report is a **Documentation Alignment Worklist**, not a migration script.

It should make these concepts distinct:

- top-level Stage;
- LOR grouping/Scene;
- resolved documentation root;
- resolution method;
- standard Setup destination;
- published Setup documents;
- local legacy instruction locations;
- central legacy procedure files grouped to Stage by filename prefix;
- central legacy files that could not be assigned to a Stage;
- Display/shared-folder reconciliation; and
- review conditions.

Master Musical group rows must not imply that every musical Scene should become a Drive Scene folder.

---

# Safety Rules

Folder Alignment must:

- remain read-only;
- never create, move, rename, or delete Google Drive folders or legacy files;
- use current parser SQLite output rather than PostgreSQL as its working source;
- preserve the distinction between top-level Stage and nested documentation root;
- use Master Musical `BackgroundFile` as explicit filesystem evidence when available;
- not equate every Master Musical Scene with a Drive Scene folder;
- not equate every LOR Display with a dedicated Drive folder;
- not create or recommend individual Display Setup folders by default;
- preserve original paths for all central and local legacy source material;
- treat leading Stage-number filenames as discovery evidence rather than automatic migration authority;
- keep helper-folder descendants out of Display candidate matching; and
- report uncertainty instead of inventing structure.

---

# Regression Fixtures

Changes to the resolver should be checked against these real structures:

- Stage 02 Triangle — Fred's Stars resolves to the Stage root from its Master Musical wiring path.
- Stage 05 Festive Trees — exact Stage identity must not create a duplicate nested Stage folder.
- Stage 07 Whoville — Who Characters/Who Spiral Tree can resolve to Stage root while Who Forest preserves `07-Whoville-WV\07a-Who Forest-WF` as its documentation root.
- Stage 13 Winter Wonderland — Background Scene/shared groupings must remain intelligible.
- Stage 18 Dancing Forest — many LOR Displays legitimately share Stage-level documentation; historical material includes evidence of files moved from `0 - Setup Procedures`.

---

# Current Implementation Direction

The current test implementation should:

1. read `lor_output_v7_scene.db` directly;
2. include only `DeviceType = 'LOR'` Displays in Display reconciliation;
3. inventory top-level Stage folders by reliable Stage ID;
4. distinguish Background Preview Scene behavior from Master Musical Preview Scene behavior;
5. use Master Musical `BackgroundFile` paths to recover documentation roots where available;
6. preserve nested Sub-stage roots beneath a top-level Stage;
7. use Stage/Scene/Sub-stage helper contexts for Setup/Wiring/Photos rather than Display helper folders;
8. recursively scan local legacy `000-Instructions` folders;
9. recursively scan the central top-level `000-Instructions` repository;
10. associate central legacy files to Stages only by a recognized leading two-digit filename prefix while preserving category and original path;
11. retain central legacy files without a Stage prefix as unassigned review material;
12. recursively inventory historical non-helper folders for Display/shared-document matching;
13. report unmatched Displays as review items rather than automatic creation requirements; and
14. remain completely read-only.
