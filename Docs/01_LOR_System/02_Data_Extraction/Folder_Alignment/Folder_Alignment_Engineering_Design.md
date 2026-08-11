# Folder Alignment — Engineering Design

## Purpose

Folder Alignment is a read-only LOR-side data extraction/alignment tool used to compare the current LOR parser snapshot with the actual engineering-document structure on the Google Shared Drive.

It is intended to answer three different questions without changing the filesystem:

1. What top-level Stage does current LOR data belong to?
2. What Stage, Sub-stage, or Background Scene documentation scope should be used for helper folders such as `Procedures`, `Wiring`, and `Photos`?
3. Which historical Display/shared-documentation folders plausibly correspond to current LOR Display identities?

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

### Google Drive source

Primary root:

```text
G:\Shared drives\Display Folders
```

The Shared Drive is the permanent engineering-document repository. Historical nesting is evidence, not automatically the expected hierarchy.

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

Example:

```text
13-Winter Wonderland-WW\Christmas Story
```

A missing Background Scene folder is not automatically safe to create. If the relationship is not established strongly enough, Folder Alignment must report a review condition rather than inventing hierarchy.

---

## 3. Master Musical Preview Scenes are interpreted differently

The annual Master Musical Preview contains many Scenes in one shared Preview. Its Preview name is provenance, not a Stage identifier for each Scene.

For Master Musical Preview Scenes:

1. If the Scene name directly matches an existing Stage folder identity, that Stage is used.
2. Otherwise the Scene `BackgroundFile` path may identify the Stage and a more specific documentation root.
3. Parser-derived Scene Stage identity remains a fallback for Stage membership.
4. The Scene name itself must not automatically become a child Drive folder.

This distinction is required because some Master Musical Scenes exist primarily to make sequencing easier.

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

A temporary background image is acceptable as an authoring placeholder when its path intentionally establishes the correct documentation root. Replacing the image later does not change the model as long as the new background remains under the intended root.

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

Not every helper subfolder must exist merely because it is standardized; the report should identify current structure and useful gaps without implying unsafe automatic creation.

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

For field documentation, Setup is normally inherited from the applicable Stage, Scene, or Sub-stage documentation scope.

Display-specific drawings, fabrication records, maintenance notes, or other engineering records may still justify a dedicated Display folder, but that is a separate documentation decision.

An unmatched LOR Display is always a review item, not an automatic folder-creation requirement.

---

# Legacy Instruction Discovery

Older Stage structures may contain a historical instruction folder named:

```text
000-Instructions
```

Folder Alignment treats this as a legacy source/review location, not the current published destination.

The scanner normalizes the folder name so typical punctuation/case variations of `000-Instructions` are recognized.

The current report must explicitly state whether the recursive legacy scan found any such folders. If found, their paths are listed for review. If none are found in the included documentation scopes, the report must say so rather than silently omitting the feature.

Generic folders named only `Instructions` are not automatically treated as equivalent to `000-Instructions`; they require separate human review because older Stage trees contain many historically ambiguous folders.

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

A historical folder may represent:

- one physical Display;
- several Displays sharing documentation;
- a Scene/Sub-stage grouping;
- archive/history;
- application-generated material;
- source material; or
- an unknown grouping requiring review.

Depth alone is never sufficient to classify a folder.

Once a recognized helper branch such as `Wiring`, `Procedures`, or `Photos` is entered, that branch is excluded from Display fuzzy matching.

---

# Matching Philosophy

> Matching may be forgiving. Recommendations must be authoritative.

Loose matching may be used to discover plausible historical candidates inside the already-resolved top-level Stage.

Possible evidence includes:

- correct two-digit Stage context;
- normalized words despite punctuation/case differences;
- omitted two-letter Display Stage prefix;
- Scene/Sub-stage context;
- recursive path context; and
- strong name similarity.

Cross-Stage fuzzy matching must not be used when a reliable Stage can be resolved.

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
- legacy `000-Instructions` source locations;
- Display/shared-folder reconciliation; and
- review conditions.

Master Musical group rows must not imply that every musical Scene should become a Drive Scene folder.

Background Scene rows may represent real nested documentation scopes when an existing relationship is established.

---

# Safety Rules

Folder Alignment must:

- remain read-only;
- never create, move, rename, or delete Google Drive folders;
- use current parser SQLite output rather than PostgreSQL as its working source;
- preserve the distinction between top-level Stage and nested documentation root;
- use Master Musical `BackgroundFile` as explicit filesystem evidence when available;
- not equate every Master Musical Scene with a Drive Scene folder;
- not equate every LOR Display with a dedicated Drive folder;
- not create or recommend individual Display Setup folders by default;
- keep helper-folder descendants out of Display candidate matching;
- preserve historical current paths in the report; and
- report uncertainty instead of inventing structure.

---

# Regression Fixtures

Changes to the resolver should be checked against these real structures:

### Stage 02 — Triangle

Fred's Stars can be a Master Musical Scene while its `BackgroundFile` points to:

```text
02-Triangle-TR\Wiring\MusicalStage
```

Expected result: top-level Stage and documentation root are both Stage 02.

### Stage 05 — Festive Trees

A Master Musical Scene whose name is the actual Stage identity must resolve directly to the Stage root without producing a duplicate:

```text
05-Festive Trees-FT\05-Festive Trees-FT
```

### Stage 07 — Whoville

Master Musical groups such as Who Characters and Who Spiral Tree may resolve to the Stage root through their background paths.

Who Forest is a formal nested Sub-stage:

```text
07-Whoville-WV\07a-Who Forest-WF
```

Its `BackgroundFile` must preserve that nested documentation root while top-level Stage identity remains 07 Whoville.

### Stage 13 — Winter Wonderland

Background Scenes and historical shared groupings such as Christmas Story, Christmas Vacation, and Polar Express must remain intelligible and must not be flattened solely because Musical Preview behavior differs.

### Stage 18 — Dancing Forest

Many legitimate LOR Displays have no expectation of one folder per Display. The tool must not turn unmatched Displays into automatic folder creation requests.

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
8. recursively scan for legacy `000-Instructions` folders and explicitly report whether any were found;
9. recursively inventory historical non-helper folders for Display/shared-document matching;
10. report unmatched Displays as review items rather than automatic creation requirements; and
11. remain completely read-only.
