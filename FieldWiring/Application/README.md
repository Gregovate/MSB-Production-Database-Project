# FieldWiring Application

Status: **development — renderer integration milestone**

This folder contains the browser-based FieldWiring application.

## Current milestone

V0.2.0 preserves the accepted Browser Lookup V3 behavior from V0.1.0 and connects a resolved Display / Stage / Scene context to the accepted Church V7 FieldWiring workspace.

The application now supports:

- find a current wiring-bearing Display by Display Name, permanent `display_id`, or `DISP:<id>`;
- exclude current LOR `DeviceType=None` Displays from FieldWiring search results;
- browse Stage -> current Stage/Scene wiring contexts;
- open the resolved context in the FieldWiring renderer;
- use `lor_snap.preview_wiring_fieldlead_v6` semantics as the normal field-hookup source;
- retain permanent `display_id` and current Preview/Scene identity through the renderer handoff;
- show all current field-lead relationships in a resolved Scene package rather than reducing the result to the trigger Display;
- apply the already-reviewed Traditional LOR and Pixie field-presentation rules without inventing permanent Controller Inventory identity;
- present published same-scope wiring images with the accepted Church V7 image controls;
- never borrow a parent Stage wiring image for a resolved Scene;
- distinguish a same-scope `PreviewBackground` image as **CONTEXT IMAGE — NOT WIRING** when no published wiring image exists;
- show `NO WIRING IMAGE AVAILABLE` when the resolved scope has no published wiring drawing;
- support multiple published images with Previous / Next and Page X/Y;
- provide Show / Hide, Fit Width, Fit All, image-only zoom, and the accepted draggable desktop image/table divider;
- start the image pane collapsed on narrow/mobile layouts;
- expose raw addressing under **Engineering details** rather than making it the primary technician instruction;
- provide a print / Save PDF presentation with centralized MSB print branding, snapshot provenance, generation time, and an end-of-local-day expiration;
- use the existing `webassets.sheboyganlights.org` branding assets instead of copying logo files into this project.

The default FieldWiring timezone is `America/Chicago`; deployment may override it with `FIELDWIRING_TIMEZONE` if required.

## Authority boundary

Production data authority remains:

```text
LOR -> LOR2DB -> PostgreSQL Production Database -> FieldWiring
```

FieldWiring is read-only. It does not change:

- PostgreSQL rows or schema;
- LOR previews or wiring topology;
- Directus;
- the deployed `/scan/DISP/<display_id>` QR endpoint;
- Google Drive folders/files; or
- FormView.

The renderer does not create a second wiring store. Normal hookup rows continue to use the accepted current `lor_snap.preview_wiring_fieldlead_v6` derivation plus permanent Production Database Display/Scene identity.

## Data modes

### Production

Set:

```text
FIELDWIRING_DATABASE_DSN=<least-privilege PostgreSQL DSN>
```

Production mode opens every database session read-only.

The production role/grants are **not created by this application milestone**. They must be verified/approved before deployment.

### Explicit development snapshot

For local acceptance testing only:

```text
FIELDWIRING_DEV_SNAPSHOT=C:\path\to\fieldwiring_snapshot.db
```

The SQLite export is opened with `mode=ro`. It is a development fixture only and must never become FieldWiring's operational source of truth.

### Drive root

The server-side image resolver defaults to:

```text
G:\Shared drives\Display Folders
```

For development/testing it may be overridden with:

```text
FIELDWIRING_DRIVE_ROOT=<mapped or local test Display Folders root>
```

The browser never receives a `G:` path. Published images are served through the read-only FieldWiring image endpoint, and `SourceDocs` is rejected as application content.

## Run locally

```powershell
$env:FIELDWIRING_DEV_SNAPSHOT = 'C:\path\to\fieldwiring_snapshot.db'
$env:FIELDWIRING_DRIVE_ROOT = 'G:\Shared drives\Display Folders'
python .\FieldWiring\Application\backend.py
```

Then open:

```text
http://127.0.0.1:8790/
```

## Existing QR dependency

The deployed Display QR lookup already resolves permanent `display_id` through the existing scan application.

The renderer can accept `display_id` as its durable trigger identity. FieldWiring does not create a second QR identity or replace the working scan application. Joining the deployed scan task menu to the FieldWiring route remains a later integration step after browser acceptance.

## Acceptance status

This milestone is the real application integration of the previously accepted lookup and Church V7 renderer contracts. It does **not** claim live PostgreSQL/Drive acceptance merely because fixture tests pass.

Next acceptance sequence:

1. run the application against the current read-only FieldWiring development snapshot and mapped Display Folders;
2. validate Church as the first real integrated A/C + Pixie case against the accepted Church V7 baseline;
3. validate Stage 21 Polar Bears as the first multi-image Scene/package case;
4. continue through the already documented device-family acceptance set;
5. preserve FormView as the fallback/reference until FieldWiring is explicitly accepted.
