# Setup Session Application

Status: **PROTOTYPE — 2025 HISTORICAL VERIFICATION UI; NO DATABASE WRITES**

This folder is the first browser-native Setup Session application prototype.

It exists to validate the Setup task model and field workflow with usable screens and provisional data before PostgreSQL DDL is approved.

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

Do not treat the provisional task rows in this prototype as approved production truth.

## Application direction

The Setup application follows the current MSB browser-native pattern used by FieldWiring / Controller Inventory:

- browser-native HTML/CSS/JavaScript UI;
- future Flask backend;
- PostgreSQL remains authoritative;
- Cloudflare Access identifies the signed-in user;
- Directus remains role/policy authority where reused;
- Manager/Admin writes must go through a governed server-side write boundary;
- no broad writable browser PostgreSQL role.

The prototype is intentionally static so task concepts and movement behavior can be validated before schema or write APIs are locked.

## First prototype scope

The prototype includes:

- `2025 — Historical Verification` season context;
- reusable task review with plain-English predecessor names;
- explicit separation between reusable definition and 2025 historical actual;
- verification states: `UNVERIFIED`, `VERIFIED`, `NEEDS CORRECTION`;
- provisional Magic Igloo phased work;
- reusable Arch Trailer unload tasks;
- Container 34 shared-load simulation across Racing Arches, Polar Bear Playground, Icicle Tunnel, Stars, Candyland, and Food Collection;
- bulk unload behavior where only Displays still traveling with the Container follow later Container movement;
- local browser persistence for prototype edits only.

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

## Running locally

The prototype has no backend dependency. Serve this directory with any static web server, for example:

```powershell
cd Setup\Application
python -m http.server 8780
```

Then open:

```text
http://localhost:8780/
```

## Production boundary

This prototype does not:

- create or alter PostgreSQL tables;
- create a Setup Session in production;
- write movement history;
- replace the current Scan application;
- establish final authorization behavior;
- approve reconstructed 2025 task order, dependencies, dates, or actuals.

Production schema and write APIs remain gated on validation through this UI and the authoritative Setup/Deployment documentation under:

`Docs/02_Production_Database/01_System_Architecture/12_Setup_and_Deployment`
