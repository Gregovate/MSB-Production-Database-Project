# Folder Alignment — Engineering Design

## Purpose

Folder Alignment is a read-only LOR-side data extraction/alignment tool used to compare the current Stage / Scene / Display structure produced by the LOR parser with the actual folder structure on the Google Shared Drive.

Its purpose is to show where the Shared Drive no longer matches the current LOR structure and to recommend the folder name and location that should be used to bring the Drive back into alignment.

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

### Google Drive source

Primary folder root:

`G:\Shared drives\Display Folders`

The Shared Drive is treated as the existing physical/document repository that must be reconciled to the current LOR-derived structure.

## Scope

### Displays included

For the current alignment project, only Displays whose LOR `DeviceType` is `LOR` are included.

DMX devices and `DeviceType = None` records are excluded from this report.

### Entities compared

The report compares:

1. Stage folders
2. Scene folders
3. Display folders

## Authority rules

### 1. LOR determines the recommended structure

The parser-derived LOR structure is authoritative for the recommendation produced by this tool.

The Google Drive structure may contain legacy names and legacy locations accumulated over many years. Existing Drive structure is evidence for matching, but it does not override the current LOR recommendation.

### 2. Two-digit Stage ID is the strongest existing Drive anchor

The two-digit Stage ID is expected to be highly reliable in existing Google Drive Stage folders.

Examples:

- `04-Food Collection`
- `13-Winter Wonderland`

The two-letter Stage code used in Display names is expected to be sparse or absent in historical Google Drive folders and must not be required for matching an existing folder.

Therefore:

- 2-digit Stage ID = strong structural match
- 2-letter Stage code = optional/weak evidence when searching existing Drive folders

### 3. Scene structure comes from LOR

Scenes are comparatively new and may not yet exist as folders on the Shared Drive.

A missing Scene folder is therefore not automatically an anomaly in the historical Drive structure. When LOR identifies a Scene, Folder Alignment should recommend creating the Scene folder in the correct Stage location when no suitable folder exists.

Scene folder names and Stage placement must be driven by the current parser-derived LOR Scene structure.

### 4. Display identity comes from the LOR Display name

The recommended Display folder name is the current LOR Display name derived from the authoritative LOR Comment / Display identity field.

Existing Google Drive Display folder names may use older conventions, spaces, punctuation, omitted Stage codes, or other historical variations.

The current Google Drive name may therefore be loosely matched, but the recommendation must use the current LOR Display name.

## Matching philosophy

### Loose discovery, strict recommendation

The central rule is:

> Matching may be forgiving. Recommendations must be authoritative.

Existing Drive folders may be matched using relaxed comparison rules so that historical naming drift does not cause every folder to appear missing.

Possible matching evidence includes:

- correct 2-digit Stage folder
- equivalent words despite spaces, hyphens, underscores, punctuation, or case
- Display name text with the two-letter Stage prefix omitted
- Scene location
- partial but strong name similarity within the already-correct Stage

The tool should avoid broad cross-Stage fuzzy matching when a reliable Stage ID is available.

## Recommended hierarchy

### Stage-level Display

If LOR does not assign a Display to a Scene, the recommended location is directly under its Stage folder.

```text
<Stage Folder>\<LOR Display Name>
```

### Scene-level Display

If LOR assigns a Display to one Scene, the recommended location is:

```text
<Stage Folder>\<LOR Scene Name>\<LOR Display Name>
```

### Multiple Scene membership

If a Display appears in multiple LOR Scenes, the tool must not invent a single folder destination. It should flag the item for review unless a separate documented rule is adopted later.

## Report requirements

For each included LOR Display, the report should show at minimum:

- Stage ID
- Stage folder
- Scene, when applicable
- LOR Display name
- current Google Drive candidate folder, when found
- recommended folder name
- recommended location
- match/action status
- explanatory note

The report should also identify Scene folders that LOR expects but that do not yet exist on the Shared Drive.

## Recommended action statuses

The report should use action-oriented statuses such as:

- `MATCH`
- `LIKELY_MATCH_RENAME`
- `LIKELY_MATCH_MOVE`
- `LIKELY_MATCH_MOVE_AND_RENAME`
- `NO_MATCH_CREATE`
- `SCENE_CREATE`
- `MULTIPLE_CANDIDATES_REVIEW`
- `MULTIPLE_SCENES_REVIEW`
- `BLOCKED`

These statuses are recommendations only. The tool remains read-only.

## Folder naming contract issue

The system currently contains two historical naming conventions:

1. the current LOR Display naming/identity contract
2. the historical Google Drive folder naming convention

This split is undesirable but must be handled safely during cleanup.

Folder Alignment exists in part to reconcile those two representations without assuming the historical Drive convention is authoritative.

The long-term folder naming contract should be documented separately once the cleanup project establishes a stable standard.

## Safety rules

Folder Alignment must:

- remain read-only
- never create folders automatically
- never rename folders automatically
- never move folders automatically
- never delete folders automatically
- never use PostgreSQL state as a substitute for the current SQLite parser output
- never treat a loose match as authority for a rename without showing the recommended LOR-derived name and location

## Current implementation direction

The next implementation revision should:

1. move under `Docs/01_LOR_System/02_Data_Extraction/Folder_Alignment/`
2. read `lor_output_v7_scene.db` directly
3. include only `DeviceType = 'LOR'` Displays
4. anchor Stage discovery primarily on the 2-digit Stage ID
5. loosely match historical Drive Display names inside the correct Stage
6. recommend Scene creation from current LOR Scene structure where needed
7. report the exact recommended Display folder name from LOR
8. report the exact recommended folder location from parser-derived Stage/Scene membership
9. remain completely read-only
