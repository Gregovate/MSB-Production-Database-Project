# Folder Alignment — Engineering Design

## Purpose

Folder Alignment is a read-only LOR-side data extraction/alignment tool used to compare the current Stage / Scene / Display structure produced by the LOR parser with the actual folder structure on the Google Shared Drive.

Its purpose is broader than Display-name reconciliation. It must also validate the standardized helper-folder structure that applications rely upon for wiring, procedures, and photos.

The tool does not create, move, rename, or delete folders. All filesystem changes remain human decisions.

## System boundary

Folder Alignment belongs to the LOR data-extraction side of the system.

```text
LOR preview files
    -> LOR parser
    -> lor_output_v7_scene.db
    -> Folder Alignment
    -> read-only alignment report
```

PostgreSQL and LOR2DB are not data sources for this tool. Folder Alignment uses the current SQLite parser output so the report reflects the current LOR state even when that SQLite snapshot has not yet been ingested into PostgreSQL.

## Data sources

### LOR-side source

Primary source:

`G:\Shared drives\MSB Database\database\lor_output_v7_scene.db`

The tool reads the current parser output for:

- Stage identity
- Scene identity and Stage membership
- Display identity
- Display Scene membership
- Device type
- Preview/background wiring context where applicable

### Google Drive source

Primary folder root:

`G:\Shared drives\Display Folders`

The Shared Drive is the existing engineering-document repository. Its historical structure is evidence for reconciliation, but current application-facing helper folders follow the documented Google Drive contract.

## Scope

### Displays included

For the current alignment project, only Displays whose LOR `DeviceType` is `LOR` are included in Display matching.

DMX devices and `DeviceType = None` records are excluded from Display-folder matching.

### Entities and structures compared

The report compares or audits:

1. Stage folders
2. Scene folders
3. standardized helper folders
4. existing Display/shared-documentation folders
5. LOR Display identities against plausible historical Drive candidates

## Authority rules

### 1. LOR determines current Stage / Scene organization

The parser-derived LOR structure is authoritative for current Stage and Scene relationships.

The Google Drive may contain legacy names and legacy locations accumulated over many years. Existing Drive structure is evidence for matching, not authority over current Stage / Scene organization.

### 2. Two-digit Stage ID is the strongest existing Drive anchor

The two-digit Stage ID is expected to be highly reliable in existing Google Drive Stage folders.

The two-letter Stage code used in Display names is sparse or absent in many historical Google Drive folders and must not be required for matching an existing folder.

Therefore:

- 2-digit Stage ID = strong structural match
- 2-letter Stage code = optional/weak evidence when searching historical Display folders

### 3. Scene structure comes from LOR

Scenes are comparatively new and may not yet exist as folders on the Shared Drive.

When LOR identifies a Scene, Folder Alignment should report whether the corresponding Scene folder exists in the correct Stage location. A missing Scene may receive a `CREATE_SCENE_FOLDER` recommendation because the Scene structure itself is current LOR-derived organization.

### 4. Display identity does not imply one Display folder

The current LOR Display name remains the authoritative Display identity used for matching.

However, the tool must **not** assume a one-to-one relationship between a LOR Display and a Google Drive folder.

Valid documentation relationships include:

- one Display with one dedicated folder;
- multiple Displays sharing one documentation folder;
- a Display documented entirely at Stage or Scene scope and requiring no dedicated folder.

Therefore an unmatched LOR Display is not automatically a folder-creation requirement.

### 5. Historical Drive path is evidence, not identity

Existing Drive folders may be moved, renamed, or reorganized. A full mounted-drive path must not be treated as stable Display identity.

The report should preserve the full current path for human review while keeping the LOR identity and recommended current Stage/Scene structure separate.

## Standard helper-folder contract

The standardized helper folders are application-facing filesystem contracts and require deterministic auditing separate from fuzzy Display matching.

For each applicable Stage and Scene, the standard structure is:

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

### Wiring helper audit

FormView established the proven wiring-directory contract. The active wiring context resolves to either:

```text
<Stage or Scene>\Wiring\BackgroundStage
<Stage or Scene>\Wiring\MusicalStage
```

The report should show whether these helper paths exist.

`SourceDocs` is working/source material and must not be treated as a published image directory.

### Procedure helper audit

The report should validate:

```text
<Stage or Scene>\Procedures\Setup
<Stage or Scene>\Procedures\Takedown
<Stage or Scene>\Procedures\Maintenance
<Stage or Scene>\Procedures\Operations
<Stage or Scene>\Procedures\SourceDocs
```

There may be multiple published documents in any operational procedure folder. The report should be able to count/list those documents without assuming one file per Stage or Scene.

`SourceDocs` must be excluded from normal field-document presentation.

### Photo helper audit

The report should validate:

```text
<Stage or Scene>\Photos\Current
<Stage or Scene>\Photos\Setup
<Stage or Scene>\Photos\Takedown
<Stage or Scene>\Photos\Reference
<Stage or Scene>\Photos\Historical
```

### Helper branches are not Display candidates

Once a Stage/Scene helper branch is recognized as `Wiring`, `Procedures`, or `Photos`, the entire branch must be excluded from Display-folder fuzzy matching.

This is a structural exclusion, not merely a folder-name blacklist.

## FormView precedent and future document linking

FormView is the proven predecessor for filesystem-assisted field documentation.

Its reusable architecture is:

```text
structured LOR context
        +
standardized Google Drive helper location
        -> field-oriented presentation
```

The future Internet-accessible applications at `my.sheboyganlights.org` should retain this location-contract principle while removing FormView's mapped-drive/direct-SQLite dependency.

Folder Alignment therefore helps establish whether the filesystem is ready for reliable document discovery.

## QR access implication

A physical Display QR code represents stable Display identity. It must not depend on a current Google Drive path.

The future application can resolve:

```text
Display QR
    -> Display identity
    -> current Stage
    -> applicable Scene/Substage when relevant
    -> standardized helper locations / indexed documents
```

For Stage-oriented Setup procedures, any Display in the Stage should provide access to the same applicable Stage procedure list.

For Wiring, Background/Static and Musical contexts remain distinct. The future field UI should present those choices in plain language rather than requiring the volunteer to understand LOR Preview terminology.

## Matching philosophy

### Loose discovery, strict recommendation

The central rule is:

> Matching may be forgiving. Recommendations must be authoritative.

Existing non-helper Drive folders may be matched using relaxed comparison rules so historical naming drift does not cause every folder to appear missing.

Possible matching evidence includes:

- correct 2-digit Stage folder
- equivalent words despite spaces, hyphens, underscores, punctuation, or case
- Display name text with the two-letter Stage prefix omitted
- Scene context
- recursive historical path context
- partial but strong name similarity within the already-correct Stage

The tool must avoid broad cross-Stage fuzzy matching when a reliable Stage ID is available.

## Recursive historical discovery

Historical Display documentation may exist at arbitrary depth below a Stage.

The tool should recursively inventory non-helper portions of the Stage tree while retaining the full relative path for every candidate.

A folder may represent:

- a dedicated physical Display folder;
- a shared documentation grouping;
- a historical/archive grouping;
- application/tool output;
- supporting/source material;
- an unknown item requiring review.

Arbitrary depth alone must not be used to classify a folder as a Display.

Strong matches at child level can provide evidence that a parent is a shared documentation grouping. For example, several LOR Displays matching separate children beneath one historical parent can justify flagging that parent as a likely shared group rather than forcing the parent to match one Display.

## Recommended hierarchy

### Stage-level Display

If LOR does not assign a Display to a Scene, its current organizational context is the Stage.

This does **not** automatically mean a dedicated Display folder must be created directly under the Stage.

### Scene-level Display

If LOR assigns a Display to one Scene, its current organizational context is:

```text
<Stage Folder>\<LOR Scene Name>
```

If the Display is known to require a dedicated folder, the recommended dedicated-folder location would be beneath that Scene. Until the documentation relationship is known, an unmatched Display remains a review item.

### Multiple Scene membership

If a Display appears in multiple LOR Scenes, the tool must not invent a single folder destination. It should flag the item for review unless a separate documented rule is adopted later.

## Report requirements

The report should contain separate sections/classes for deterministic helper-folder auditing and historical Display-folder reconciliation.

### Stage / Scene structure

Show at minimum:

- Stage ID
- Stage folder
- Scene name where applicable
- current path
- expected path
- status/action

### Helper-folder audit

Show at minimum:

- Stage / Scene scope
- helper class (`Wiring`, `Procedures`, `Photos`)
- expected helper path
- status
- published item count where useful
- note

For Procedures, the report should be capable of listing/counting published documents in Setup/Takedown/Maintenance/Operations folders.

### Display/shared-folder reconciliation

For each included LOR Display, show at minimum:

- Stage ID
- Scene, when applicable
- LOR Display name
- current Google Drive candidate folder/path when found
- match confidence/reason
- likely shared-group context when detected
- current organizational context
- status/action
- explanatory note

## Status philosophy

Helper-folder statuses can be deterministic, for example:

- `MATCH`
- `CREATE_SCENE_FOLDER`
- `HELPER_EXISTS`
- `HELPER_MISSING`
- `BLOCKED`

Display reconciliation must remain conservative, for example:

- `MATCH`
- `LIKELY_MATCH_RENAME`
- `LIKELY_MATCH_MOVE`
- `LIKELY_MATCH_MOVE_AND_RENAME`
- `LIKELY_SHARED_GROUP`
- `NO_FOLDER_MATCH`
- `REVIEW_FOLDER_NEED`
- `MULTIPLE_CANDIDATES_REVIEW`
- `MULTIPLE_SCENES_REVIEW`
- `BLOCKED`

`NO_FOLDER_MATCH` means only that no plausible existing Drive folder was found. It does **not** mean `CREATE`.

## Safety rules

Folder Alignment must:

- remain read-only
- never create folders automatically
- never rename folders automatically
- never move folders automatically
- never delete folders automatically
- never use PostgreSQL state as a substitute for the current SQLite parser output
- never use `previews.StageID` as authoritative Stage identity for Scene-assigned Musical Displays when parser-derived Scene Stage identity is available
- never treat a loose match as authority for a filesystem change
- never treat every `DeviceType = 'LOR'` Display as requiring an individual folder
- never treat helper-folder descendants as Display candidates
- preserve existing historical paths in the report for human review

## Regression fixtures

The following real Stage structures should be used as regression examples when changing the matcher:

- Stage 02 Triangle — nested historical grouping (`Claymation`) and deep archives
- Stage 07 Whoville — formal Substage and mixed historical folders
- Stage 13 Winter Wonderland — deep shared groupings such as Christmas Story / Christmas Vacation / Polar Express
- Stage 18 Dancing Forest — many legitimate LOR Displays with Stage-level documentation and no expectation of one folder per Display

A matching change that makes these examples less intelligible should be treated as a regression.

## Current implementation direction

The implementation should:

1. read `lor_output_v7_scene.db` directly
2. include only `DeviceType = 'LOR'` Displays in Display reconciliation
3. anchor Stage discovery primarily on the 2-digit Stage ID
4. use parser-derived Scene Stage identity for Scene-assigned Displays
5. inventory the historical non-helper tree recursively
6. structurally exclude `Wiring`, `Procedures`, and `Photos` helper branches from Display fuzzy matching
7. audit the standardized helper folders deterministically
8. count/list published procedure documents by operational procedure folder
9. loosely match historical Display/shared-documentation names only inside the correct Stage
10. identify likely shared documentation groupings when multiple Displays map into one historical branch
11. recommend Scene creation from current LOR Scene structure where needed
12. report unmatched Displays as review items rather than automatic folder creation
13. remain completely read-only
