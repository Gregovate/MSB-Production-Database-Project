# FieldWiring Application

Status: **development — browser lookup milestone**

This folder contains the first implementation of the browser-based FieldWiring application.

## Current milestone

V0.1.0 implements the accepted Browser Lookup V3 behavior:

- find a current wiring-bearing Display by Display Name, permanent `display_id`, or `DISP:<id>`;
- exclude current LOR `DeviceType=None` Displays from FieldWiring search results;
- browse Stage -> current Stage/Scene wiring contexts;
- show technician-facing `Display`, `Stage`, `Scene / Area`, and `Wiring` fields;
- keep permanent IDs, LOR Device Type, Preview identity, and Scene identity under **Technical details**;
- support browser/device light and dark mode through CSS;
- use the existing `webassets.sheboyganlights.org` MSB branding assets instead of copying logos into this project.

The FieldWiring hookup renderer is deliberately **not connected yet** in this milestone. The accepted Church V7 renderer remains the presentation baseline for that next step.

## Authority boundary

Production data authority remains:

```text
LOR -> LOR2DB -> PostgreSQL Production Database -> FieldWiring
```

The application is read-only for this milestone.

It does not change:

- PostgreSQL rows or schema;
- LOR previews or wiring topology;
- Directus;
- the deployed `/scan/DISP/<display_id>` QR endpoint;
- Google Drive folders/files; or
- FormView.

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

## Run locally

```powershell
$env:FIELDWIRING_DEV_SNAPSHOT = 'C:\path\to\fieldwiring_snapshot.db'
python .\FieldWiring\Application\backend.py
```

Then open:

```text
http://127.0.0.1:8790/
```

## Existing QR dependency

The deployed Display QR lookup already resolves permanent `display_id` through the Directus scan extension on `msb-prod-db`.

FieldWiring will later accept that same resolved `display_id`; it will not create a second QR identity or replace the working scan application.

Server deployment/Directus runtime ownership is documented in the separate `MSB-Server-Management` project.

## Next milestone

Connect the resolved browser/QR context to the generic FieldWiring renderer using the accepted Church V7 workspace as the presentation baseline, then validate Polar Bears as the multi-image case.
