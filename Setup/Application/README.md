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
- PostgreSQL remains authoritative;
- Cloudflare Access identifies the signed-in user when deployed;
- Directus remains role/policy authority where reused;
- Manager/Admin writes must go through a governed server-side write boundary;
- no broad writable browser PostgreSQL role.

The current prototype backend is read-only.

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
- Setup Instruction review state on the task detail page;
- optional live read-only enumeration of current Setup PDFs, SourceDocs, and Archive files through the existing shared Procedure resolver;
- local browser persistence for prototype task/instruction-review edits only.

## Setup Instruction review / publication boundary

The current Google Drive / Procedure contract is preserved:

```text
Procedures\Setup\<current instruction>.pdf
    = current published field instruction

Procedures\Setup\SourceDocs\
    = editable working/source material

Procedures\Setup\Archive\
    = historical / superseded source evidence
```

For 2025 verification, the intended Manager workflow is:

```text
historical source in Archive
    -> review alongside reusable Setup task
        -> create/use editable working copy in SourceDocs
            -> revise and approve
                -> publish approved PDF directly in Procedures\Setup
```

The archived original should not be edited in place merely because it contains useful historical content. Preserve it as evidence and revise a working copy.

The prototype records Procedure verification/revision notes locally. When run through `backend.py` with the database and Display Folders configured, it also resolves the current Stage/Sub-stage through the same accepted shared field-context / Procedure stack used by the current Procedure application and shows:

- current published Setup PDF filename(s), with a protected read-only open link;
- direct files currently in `SourceDocs`;
- direct files currently in `Archive`;
- resolver warnings where applicable.

It still does **not** create a SourceDocs working copy or publish a PDF.

Only after this read-side review is accepted should a separate governed authoring/publication command path be designed.

The existing Procedure application and production Display Folders filesystem are read-only. A future Setup Manager authoring/publication path therefore requires its own governed write boundary. It must not broaden the existing read-only Procedure field application or silently make the shared production mount writable.

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

## Running locally — static mode

Static mode validates the task and movement UI but cannot show real Procedure files:

```powershell
cd Setup\Application
python -m http.server 8780
```

Then open:

```text
http://localhost:8780/
```

## Running locally — live read-only Procedure review

Run from the repository root or from `Setup\Application` after configuring a read-only database source and the Display Folders root.

The backend accepts Setup-specific environment variables and also reuses the existing Procedure/FieldWiring variable names when already configured:

```text
SETUP_DATABASE_DSN
SETUP_DEV_SNAPSHOT
SETUP_DRIVE_ROOT
```

Fallbacks accepted:

```text
PROCEDURE_DATABASE_DSN
PROCEDURE_DEV_SNAPSHOT
PROCEDURE_DRIVE_ROOT
FIELDWIRING_DATABASE_DSN
FIELDWIRING_DRIVE_ROOT
```

Example with a Windows Google Drive root:

```powershell
$env:SETUP_DRIVE_ROOT = 'G:\Shared drives\Display Folders'
$env:SETUP_DATABASE_DSN = '<existing read-only PostgreSQL DSN>'
python .\Setup\Application\backend.py
```

Then open:

```text
http://localhost:8780/
```

Do not place credentials in the repository.

After pulling a prototype update, use a hard refresh so the browser reloads the versioned CSS/JavaScript.

## Production boundary

This prototype does not:

- create or alter PostgreSQL tables;
- create a Setup Session in production;
- write movement history;
- modify Google Drive;
- edit an archived Google Doc;
- create a SourceDocs working copy;
- convert/publish a new PDF;
- replace the current Scan or Procedure applications;
- establish final authorization behavior;
- approve reconstructed 2025 task order, dependencies, dates, or actuals.

Production schema, Procedure publication writes, and final authorization remain gated on validation through this UI and the authoritative Setup/Deployment documentation under:

`Docs/02_Production_Database/01_System_Architecture/12_Setup_and_Deployment`
