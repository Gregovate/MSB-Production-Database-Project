# FieldWiring Server Deployment and Scan Integration Plan — 2026-08-21

| Document control | Value |
|---|---|
| Status | PLANNED NEXT MILESTONE — application release candidate accepted on laptop |
| Sub-project | FieldWiring |
| Production backend host | `msb-prod-db` / `192.168.5.9` |
| Public site | `https://my.sheboyganlights.org/` |
| Existing Display scan runtime | Directus extension under `/opt/directus/extensions/directus-extension-scan/` |
| Server-management repository | `Gregovate/MSB-Server-Management` |
| Owner | MSB Database Administrator |

## Purpose

This document defines the next controlled milestone: move FieldWiring off the development laptop, publish it behind the existing protected MSB web boundary, and connect it to the already-deployed Display QR task hub without creating a second scan identity or public application path.

This is a deployment plan, not proof that the deployment is complete.

## Existing Verified Infrastructure Pattern

The existing LOR Preflight application establishes a proven MSB browser-application pattern:

```text
browser
  -> protected my.sheboyganlights.org origin on Synology Web Station
  -> same-origin reverse-proxy path
  -> internal Gunicorn service on msb-prod-db
  -> PostgreSQL
```

The current LOR Preflight deployment uses:

```text
backend host       msb-prod-db / 192.168.5.9
backend install    /opt/lor-preflight
systemd service    lor-preflight-api.service
backend process    Gunicorn
public frontend    Synology Web Station
public protection  existing my.sheboyganlights.org authentication boundary
```

FieldWiring should follow this established split rather than creating a new Docker stack, hostname, certificate, or unrelated nginx path unless live inspection proves a different approach is necessary.

Runtime administration, backups, service management, Synology proxy configuration, and recovery procedures belong in `Gregovate/MSB-Server-Management`.

## Proposed FieldWiring Deployment Shape

Subject to live port/path verification, the target shape is:

```text
my.sheboyganlights.org/fieldwiring/
  -> Synology Web Station / protected origin
  -> same-origin proxy to FieldWiring backend on msb-prod-db
  -> read-only PostgreSQL Production Database
  -> guarded read-only Display Folders image source
```

The exact internal port must be selected only after checking active listeners on `msb-prod-db`. Do not reuse `8784` because it belongs to LOR Preflight.

Suggested server installation boundary:

```text
/opt/fieldwiring/
```

Suggested service name:

```text
fieldwiring.service
```

These names are reasonable conventions, not yet installed facts.

## Deployment Responsibilities

### MSB Production Database repository

Owns:

- FieldWiring application source;
- data contracts and presentation logic;
- read-only database query behavior;
- scan-to-FieldWiring application contract;
- application tests;
- production application configuration examples that contain no secrets.

### MSB-Server-Management repository

Must record the actual deployed runtime once installed, including:

- installation directory;
- OS user/service account;
- virtual environment and dependency installation;
- systemd unit;
- internal bind address/port;
- environment-file path;
- least-privilege PostgreSQL credential source;
- Display Folders mount/sync path;
- Synology reverse-proxy stanza;
- Cloudflare/authentication assumptions;
- backup/recovery procedure;
- update/restart/rollback commands;
- health checks.

Do not copy secrets into either Git repository.

## Production Data Mode

Production must use live PostgreSQL:

```text
FIELDWIRING_DATABASE_DSN=<dedicated least-privilege read-only DSN>
```

Do not deploy `FIELDWIRING_DEV_SNAPSHOT` in production.

The production database role must be able to SELECT the current relations FieldWiring consumes, including the established current LOR snapshot views, Display/Stage reference data, occurrence/reconciliation context, and the current DMX source-detail view.

The role must not receive write or DDL rights merely to simplify application deployment.

## Display Folders / Image Deployment Boundary

This is the principal infrastructure item to solve before server acceptance.

Current laptop acceptance uses:

```text
G:\Shared drives\Display Folders
```

The Linux production host will not have a Windows `G:` drive.

The deployed app needs a **read-only server-visible copy or mount of the current Display Folders source tree** with the existing source-folder markers and published Wiring/PreviewBackground content intact.

Potential mechanisms must be selected from the real infrastructure, for example a controlled network mount or a reliable synchronized read-only tree. Do not choose the mechanism from this document alone.

Acceptance requirements for the server image source:

1. current Stage/Scene source-folder markers are visible;
2. `Wiring/BackgroundStage`, `Wiring/MusicalStage`, and `PreviewBackground` branches retain their current structure;
3. the FieldWiring service account can read published image files but does not need write access;
4. `SourceDocs` remains excluded from application delivery;
5. stored Windows `folder_path` / `BackgroundFile` evidence can be translated deterministically to the server-visible Display Folders root;
6. Scene-specific resolution still does not borrow a parent Stage wiring image.

A server deployment that shows wiring data but silently loses all images is not full acceptance.

## Public Route

Preferred public application route:

```text
https://my.sheboyganlights.org/fieldwiring/
```

Reasons:

- uses the existing protected field/application origin;
- avoids creating another hostname or certificate;
- gives the existing Display scan hub a stable downstream task destination;
- matches the deployment model already proven by LOR Preflight.

The backend should receive requests only through the intended internal/public boundary. Do not expose a new unauthenticated internet listener directly from `msb-prod-db`.

## Same-Origin Browser Requirement

FieldWiring frontend/API/image requests should remain on the protected `my.sheboyganlights.org` origin.

If the Synology serves static FieldWiring files separately from the backend, its nginx/Web Station configuration should proxy the FieldWiring API/image paths to the internal Gunicorn service, following the same principle used by LOR Preflight.

If the full Flask application is proxied as one path, verify that relative static/API links continue to work under the `/fieldwiring/` prefix before accepting that arrangement.

Do not hard-code the laptop URL `http://127.0.0.1:8790/` into scan links or production documentation.

## Existing Display Scan Hub

The current production QR route already exists:

```text
/scan/
/scan/DISP/:key
/scan/DISP/:key/test
/scan/DISP/:key/container
/scan/DISP/:key/work-orders
```

Runtime:

```text
msb-prod-db
/opt/directus/extensions/directus-extension-scan/
```

The hub resolves permanent `ref.display.display_id` before showing task choices.

FieldWiring must use that resolved identity.

## Required Scan Change

Add one task/action to the existing Display scan hub:

```text
Field Wiring
```

Conceptual destination:

```text
https://my.sheboyganlights.org/fieldwiring/?display_id=<permanent display_id>
```

The exact final route may differ if the production FieldWiring route uses a dedicated Display endpoint, but the only identity passed from the QR hub should be the already-resolved permanent `display_id`.

Do not place any of the following into the physical QR or scan-hub link as identity:

- LOR Prop UUID;
- Preview UUID/name;
- Scene UUID/name;
- Stage ID/key;
- Google Drive path;
- controller address;
- FieldWiring snapshot ID.

FieldWiring resolves current context from the Production Database at request time.

## Scan Runtime Change Safety

Before editing the Directus scan extension:

1. inspect and back up the live `/opt/directus/extensions/directus-extension-scan/` implementation;
2. preserve the existing routes and Testing/Container/Work Order actions;
3. record the baseline in `MSB-Server-Management` if not already complete;
4. make the smallest additive Field Wiring change;
5. rebuild/reload the extension using the established Directus procedure;
6. verify all existing scan destinations still work;
7. verify the new Field Wiring action resolves the same `display_id` into FieldWiring.

The scan hub should not become dependent on FieldWiring availability for its other functions. If FieldWiring is down, Testing/Container/Work Order navigation must remain usable.

## Initial Server Acceptance Sequence

### Gate 1 — Backend install

- deploy code from merged `main` to a controlled `/opt/fieldwiring` location;
- create isolated Python virtual environment;
- install runtime requirements only;
- configure read-only PostgreSQL credentials outside Git;
- start backend through systemd/Gunicorn;
- verify `/api/health` or equivalent internal health response.

### Gate 2 — Live PostgreSQL

Validate representative real contexts directly against production PostgreSQL:

- Church A/C + Pixie;
- Mega Tree / Mega Ball E1.31;
- Mega Star E1.31;
- Northern Lights DMX/DumbRGB;
- one no-image/context-image case.

Confirm current Run/provenance appears correctly and no SQLite development snapshot is being used.

### Gate 3 — server image source

Prove the server can resolve the same marked current wiring/context images accepted on the laptop.

### Gate 4 — protected public route

Publish through `my.sheboyganlights.org` and verify authentication/proxy behavior from a normal browser.

### Gate 5 — tablet/phone testing

Test real devices on the field network/public protected route:

- portrait and landscape;
- controller-card collapse/expand;
- long-list scrolling;
- image Show/Hide;
- context-only image warning;
- touch targets;
- no horizontal layout failures that hide critical fields;
- Print/Save PDF where supported.

The desktop/laptop image/hookup split presets are intentionally hidden on narrow/mobile layouts; mobile uses page scrolling.

### Gate 6 — Display scan hub

Add Field Wiring to the existing hub and test with a real Display QR.

### Gate 7 — fallback

Confirm FormView remains available as the transitional fallback/reference during field acceptance.

## Rollback

Server deployment must support a simple rollback:

- stop/disable the FieldWiring service;
- remove/disable only the FieldWiring reverse-proxy/public route;
- remove the Field Wiring action from the scan hub if necessary;
- leave existing Display QR routes and other scan actions unchanged;
- leave PostgreSQL/LOR data untouched;
- keep FormView available.

No rollback should require changing physical Display labels.

## Relationship to Merge

Merging FieldWiring into `main` is appropriate before server deployment once the branch is updated from current `main` and final tests pass.

The merge means the application and documented data contracts are accepted into the main Production Database codebase. It does **not** claim that:

- FieldWiring is already deployed;
- the scan hub is already modified;
- tablet/phone field acceptance is complete;
- FormView can be retired.

Those are separate deployment/acceptance milestones and should be documented as completed only after real server/device verification.

## Related Documents

- [FieldWiring Release Candidate Handoff and Development Runbook](FieldWiring_Release_Candidate_Handoff_and_Development_Runbook_2026-08-21.md)
- [Wiring System](README.md)
- [Deployed Display Scan Runtime Boundary](../07_Labeling_and_Scanning/Deployed_Display_Scan_Runtime_Boundary.md)
- [Shared Field Context Resolution Contract](../07_Labeling_and_Scanning/Field_Context_Resolution_Contract.md)
- [FieldWiring Drive Context Resolver Engineering Design](FieldWiring_Drive_Context_Resolver_Engineering_Design.md)
- [MSB-Server-Management](https://github.com/Gregovate/MSB-Server-Management)
