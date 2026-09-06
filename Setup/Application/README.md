# Setup Session Application

Status: **PROTOTYPE — 2025 HISTORICAL VERIFICATION UI; NO DATABASE OR DRIVE WRITES**

This folder contains the first browser-native Setup Session application prototype.

It exists to validate the Setup task model, 2025 historical reconstruction, Procedure knowledge, and field movement workflow with usable screens before PostgreSQL DDL or Google Drive write automation is approved.

## Why this prototype exists

The historical reconstruction spreadsheet is evidence, not a reliable review UI. Sorting changed the visible order and several right-side keys were difficult to interpret. The first validation target is therefore the application experience itself:

```text
reconstruction evidence
    -> provisional 2025 task data
        -> usable browser UI
            -> manager/team verification and correction
                -> approved reusable task catalog
                    -> Admin creates 2026 Setup Session
```

Do not treat provisional task rows as approved production truth.

## Application direction

The Setup application follows the current MSB browser-native pattern used by FieldWiring / Controller Inventory:

- browser-native HTML/CSS/JavaScript UI;
- Flask backend for controlled read/API work;
- PostgreSQL remains authoritative in production;
- Cloudflare Access identifies the signed-in user when deployed;
- Directus remains role/policy authority where reused;
- Manager/Admin writes must go through a governed server-side write boundary;
- no broad writable browser PostgreSQL role.

The current prototype backend does not write PostgreSQL or Google Drive.

## First prototype scope

The prototype includes:

- `2025 — Historical Verification` season context;
- reusable task review with plain-English predecessor names;
- explicit separation between reusable definition and 2025 historical actual;
- verification states: `UNVERIFIED`, `VERIFIED`, `NEEDS CORRECTION`;
- a broader provisional Setup task library across representative Stages instead of only Arch Trailer unload tasks;
- representative general/support work, Mega Cube, Whoville, Elf Choir, Stars, Icicle Tunnel, Candyland, Polar Bear Playground, Racing Arches, Magic Igloo, Food Collection, and Command Center tasks;
- provisional Magic Igloo phased work and common readiness/power-up tasks;
- reusable Arch Trailer unload tasks;
- Container 34 shared-load simulation across Racing Arches, Polar Bear Playground, Icicle Tunnel, Stars, Candyland, and Food Collection;
- bulk unload behavior where only Displays still traveling with the Container follow later Container movement;
- Setup Procedure review state on the task detail page;
- Manager-facing discovery of editable Google Doc sources plus the current published Setup PDF;
- local browser persistence for prototype task/instruction-review edits only.

## Manager Setup Procedure workflow

The Setup application uses the existing documented Procedure folder structure. It does not require a separate Setup-specific document layout and does not require the 2025 verification pass to reorganize existing files first.

Documented structure:

```text
<Stage / Sub-stage / Scene>\Procedures\Setup\
    <current field PDF>.pdf
    Archive\
    images\
    SourceDocs\
```

Normal roles remain:

```text
Procedures\Setup\SourceDocs
    = normal editable/source area

Procedures\Setup\Archive
    = legacy / historical / superseded material

Procedures\Setup
    = current published field PDF(s)
```

The Manager screen and production-crew Procedure screen intentionally have different visibility.

```text
Production crew
    -> current published PDF directly in Procedures\Setup

Authorized Manager
    -> open the applicable editable .gdoc source
    -> correct it during 2025 verification
    -> regenerate/export and replace the published PDF after a source change
```

### 2025 compatibility rule for existing Archive .gdoc files

Some current editable Google Docs were historically placed in `Procedures\Setup\Archive`. Correcting every folder before Setup Session verification would create unnecessary work and is **not** a prerequisite for the Setup system.

For the 2025 verification cycle, editable-source discovery therefore follows this compatibility rule:

```text
1. Prefer editable .gdoc file(s) in Procedures\Setup\SourceDocs.
2. If none exist there, use existing editable .gdoc file(s) in Procedures\Setup\Archive in place.
3. Do not move or rename the file merely to make Setup Session work.
4. Production crew still sees only the PDF directly in Procedures\Setup.
5. If the Manager edits the Google Doc, the published PDF must be replaced before the instruction is marked verified/current.
```

This compatibility rule does not redefine the documented folder meanings. It allows the Setup application to work against the current installed document estate without blocking on Folder Alignment cleanup.

The Manager task detail page therefore presents the Procedure workflow as actions, not as a folder-governance lesson:

```text
Editable procedure
    <source>.gdoc
    <full source path>
    [Open Editable Procedure]
    [Export Updated PDF]

Published field PDF
    <current>.pdf
    [Open Current PDF]

If the Google Doc is edited, replace the published PDF before marking the instruction verified.
```

The current prototype can open the Google Doc and request Google's PDF export when the mounted `.gdoc` shortcut exposes a resolvable Google document identity. It does not yet automate replacement of the PDF in Google Drive.

## Procedure resolution modes

### Production direction — shared field-context resolver

When a read-only database source is configured, the Setup prototype reuses the accepted shared Field Context / Procedure resolver. This remains the production direction.

### Local validation fallback — exact Stage key only

For local 2025 review, when no database DSN/snapshot is configured but `SETUP_DRIVE_ROOT` is available, the prototype may resolve the Stage folder directly by exact leading Stage key.

Example:

```text
stage_key = 04
    -> exactly one direct folder beginning 04-
    -> G:\Shared drives\Display Folders\04-Food Collection-FC
```

For Sub-stages, the prototype may inspect one nested folder level when the exact key is not a direct child.

This fallback:

- is prototype-only;
- requires exactly one matching folder;
- does not fuzzy-match Stage names;
- does not replace the universal resolver in production.

For Food Collection, the existing editable source currently being reviewed is:

```text
G:\Shared drives\Display Folders\04-Food Collection-FC\Procedures\Setup\Archive\04-Food Collection-FC.gdoc
```

The prototype uses that file in place under the 2025 compatibility rule; it does not require moving it to `SourceDocs`.

## Shared Container acceptance rule

For Container 34 / Arch Trailer:

```text
scan/move Container to destination
    -> all Displays still WITH_CONTAINER inherit that Setup location

execute reusable unload task
    -> expected Display group is unloaded at that location
    -> those Displays detach from Container movement

move Container again
    -> only Displays still WITH_CONTAINER follow it
```

Completing or correcting a Display/task may later reconcile missed movement evidence, but the system must never invent intermediate movement events that were not observed.

## Prototype-only data

The first screen intentionally uses known representative facts and clearly marks task details as provisional. It is not a replacement for the 2025 historical verification process.

Confirmed Container 34 Display grouping used for the movement acceptance case:

- Racing Arches — 48 Displays
- Icicle Tunnel — 36 Displays
- Stars — 24 Displays
- Food Collection — 8 Displays
- Polar Bear Playground — 3 Displays
- Candyland — 2 Displays

Total: 121 Displays.

The broader non-unload task rows are representative provisional review data derived from current Setup planning evidence. Managers/team leaders must verify task boundaries, order, prerequisites, crew, equipment, timing, material, and Procedure applicability in the UI.

## Running locally

Use the project virtual environment, then run the Flask prototype from the repository root:

```powershell
.\.venv\Scripts\Activate.ps1
$env:SETUP_DRIVE_ROOT = 'G:\Shared drives\Display Folders'
python .\Setup\Application\backend.py
```

Open:

```text
http://localhost:8780/
```

A database DSN is **not required** for the local exact-Stage-key prototype fallback. If `SETUP_DATABASE_DSN`, `PROCEDURE_DATABASE_DSN`, `FIELDWIRING_DATABASE_DSN`, or a configured development snapshot is present, the application uses the shared field-context resolver instead.

After pulling a prototype update, restart Flask when backend code changed and use a hard browser refresh so the versioned CSS/JavaScript reloads.

## Production boundary

This prototype does not:

- create or alter PostgreSQL tables;
- create a Setup Session in production;
- write movement history;
- modify Google Drive;
- automatically replace a published PDF;
- reorganize Procedure folders;
- replace the current Scan or Procedure applications;
- establish final authorization behavior;
- approve reconstructed 2025 task order, dependencies, dates, or actuals.

Production schema, Procedure publication writes, and final authorization remain gated on validation through this UI and the authoritative Setup/Deployment documentation under:

`Docs/02_Production_Database/01_System_Architecture/12_Setup_and_Deployment`
