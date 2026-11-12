# FieldWiring Scan Integration Engineering Handoff — 2026-08-22

| Document control | Value |
|---|---|
| Status | ACCEPTED PRODUCTION — Field Wiring action and corrected Directus routing operational |
| Current revision | 2026-08-22 local / 2026-08-23 UTC |
| Production scan host | `msb-prod-db` / `192.168.5.9` |
| Production scan runtime | `/opt/directus/extensions/directus-extension-scan/` |
| Public scan route | `https://my.sheboyganlights.org/scan/` |
| Directus public origin | `https://db.sheboyganlights.org/` |
| FieldWiring public route | `https://my.sheboyganlights.org/fieldwiring/` |
| Application source branch | `agent/fieldwiring-server-deployment-reconnaissance` |
| Server runtime branch | `agent/scan-fieldwiring-runtime-integration` |

## Purpose

This document is the accepted engineering handoff for adding **Field Wiring** to the existing permanent Display QR/scan workflow without changing physical Display identity and without making existing scan functions dependent on FieldWiring.

The integration is production-operational. During acceptance, publication of `/scan/` through the protected `my.sheboyganlights.org` origin exposed an older same-origin assumption in the recovered Directus scan extension. That defect was corrected before final acceptance so Directus-facing actions now use the existing Directus public origin `https://db.sheboyganlights.org/` while Scan and FieldWiring remain on `my.sheboyganlights.org`.

The current scan application source is recovered into Git so future Setup/Deployment scan work no longer has to start from an undocumented live-only artifact.

## Accepted Production Result

The Display scan hub includes one independent action:

```text
Field Wiring
    -> /fieldwiring/wiring.html?display_id=<permanent display_id>
```

The action uses only the already-resolved permanent `ref.display.display_id`.

No schema change was required.

No physical QR change was required.

No FieldWiring backend change was required merely to support the link.

Existing Testing, Container, Work Order, and Directus Display destinations remain separate from FieldWiring. The scan hub does not call FieldWiring merely to render the action.

## Application Source Recovery

The accepted March 2026 camera-enabled Directus scan implementation was recovered from the live server before modification.

Git-controlled application source now exists at:

```text
Scan/directus-extension-scan/
    package.json
    src/index.js
    dist/index.js
```

Relevant recovery/integration commits on this branch:

```text
d579dd1  Recover accepted Directus scan extension source
7fdb1b9  Complete Directus scan extension recovery baseline
5f24474  Add FieldWiring action to display scan hub
35158f7  Fix Scan Directus links for public routing
```

The application/business source belongs to the Production Database repository because it contains MSB-specific Display, Testing, Container, Work Order, and FieldWiring behavior. The fact that Directus hosts the endpoint does not transfer application ownership to Server Management.

## Production Artifact Identity

Accepted pre-change production `dist/index.js` SHA-256:

```text
824aa56857c3d52c3ba9186c4721313e2172dc24ec32653045bb7bf3b008d7af
```

First FieldWiring-enabled artifact SHA-256:

```text
e17ea51ec1f1993440719cb3ca35eb84c7250eb4f3d0a25784d0a42ef2114df0
```

That artifact correctly added FieldWiring, but public acceptance exposed the legacy Directus same-origin link defect described below.

**Current accepted production `dist/index.js` SHA-256:**

```text
b4f6c27f4880a8eaf8a90d8d55c7939c5bd190645dca9329344a86c3175cb20f
```

The older live file named:

```text
dist/index-copy original-no-camera-scanning.js
```

remains historical only and is **not** a valid rollback artifact for the current camera-enabled scan system.

Verified rollback copies created during this work are recorded by MSB-Server-Management:

```text
/home/msbadmin/backups/directus-scan/pre-fieldwiring-20260823T011615Z/index.js
    SHA-256 824aa56857c3d52c3ba9186c4721313e2172dc24ec32653045bb7bf3b008d7af

/home/msbadmin/backups/directus-scan/pre-directus-link-fix-20260823T015833Z/index.js
    SHA-256 e17ea51ec1f1993440719cb3ca35eb84c7250eb4f3d0a25784d0a42ef2114df0
```

## Scan Architecture

The Directus endpoint extension continues to provide:

```text
/scan/
/scan/DISP/:key
/scan/CONT/:key
/scan/DISP/:key/test
/scan/DISP/:key/container
/scan/DISP/:key/work-orders
```

The landing page supports camera scanning, QR codes, 1-D barcodes through `html5-qrcode`, manual entry, and URL handling.

`/scan/DISP/:key` resolves the route key directly against:

```text
ref.display.display_id
```

Therefore the Display hub already has the permanent identity FieldWiring requires. No LOR UUID, Stage key, Scene UUID, controller address, or Google Drive path belongs in the scan handoff.

## FieldWiring Deep-Link Contract

The accepted direct Display route is:

```text
/fieldwiring/wiring.html?display_id=<permanent display_id>
```

The older conceptual route:

```text
/fieldwiring/?display_id=<display_id>
```

is not the direct wiring-entry contract.

FieldWiring receives the permanent Display ID, resolves current Stage/Preview/Scene context from PostgreSQL, and owns its own wiring-availability behavior.

## Public Routing and Directus-Origin Correction

### Publishing `/scan/`

During initial production acceptance, the Directus endpoint was healthy internally but the public `/scan/` path returned the Synology/WebStation 404 page.

Isolation proved:

```text
msb-prod-db Directus http://127.0.0.1:8055/scan/       -> HTTP 200
Synology direct https://my.sheboyganlights.org/scan/   -> HTTP 404
Synology direct /fieldwiring/                           -> HTTP 200
```

The missing layer was the Synology nginx/WebStation route. Server Management added an explicit protected-site proxy preserving the `/scan/...` path to Directus on `192.168.5.9:8055`.

Accepted public behavior after reload:

```text
/scan/  -> HTTP 200
/scan   -> HTTP 301 -> /scan/
```

### Legacy same-origin defect discovered during acceptance

After `/scan/` was published on `my.sheboyganlights.org`, **Open Display Record** returned a Synology 404. The recovered March extension used root-relative Directus admin destinations such as:

```text
/admin/content/display/<id>
/admin/content/container/<id>
/admin/content/display_test_session/<id>
/admin/content/work_order/<id>
```

Those links had worked when Scan and Directus shared one origin. On the new public Scan origin they incorrectly resolved under `my.sheboyganlights.org`.

Reconnaissance confirmed an existing full Directus reverse proxy already exists at:

```text
https://db.sheboyganlights.org/
    -> 192.168.5.9:8055
```

The application correction in commit `35158f7` changed the six Directus-facing destinations to the existing public Directus origin, for example:

```text
https://db.sheboyganlights.org/admin/content/display/<id>
```

This correction covers:

- Display Record;
- Container Record from a Container scan;
- Display Test Session redirect;
- Display-to-Container redirect;
- one active Work Order direct redirect;
- multiple active Work Order selection links.

No `/admin/` proxy was added to `my.sheboyganlights.org`. Scan remains on `my.sheboyganlights.org`, FieldWiring remains on `my.sheboyganlights.org`, and Directus administration remains on `db.sheboyganlights.org`.

The exact nginx configuration paths, backups, and reload evidence are owned by `Gregovate/MSB-Server-Management`.

## Production Acceptance Evidence

Final accepted checks completed during the deployment and corrective retest:

| Test | Result |
|---|---|
| Directus JavaScript syntax check | PASS |
| Directus restart | PASS |
| Extension load | PASS — `directus-extension-scan` loaded |
| Internal `/scan/` | PASS — HTTP 200 |
| Public Synology `/scan/` | PASS — HTTP 200 |
| Public `/scan` no-slash redirect | PASS — HTTP 301 to `/scan/` |
| Manual `DISP:141` navigation | PASS — `TC-ChristmasHippo` |
| Open Display Record | PASS — correct `TC-ChristmasHippo` record opened on `db.sheboyganlights.org` |
| Assigned Container | PASS — correct assigned Container opened from `DISP:141` |
| Testing redirect | PASS — `QV-SHRStocking` current Display Test Session opened in Directus; Display Test Session ID `1860`, Test Session ID `687` |
| Work Orders = 0 | PASS — disabled/no-open-work state preserved |
| Field Wiring action rendered | PASS |
| Permanent `display_id` handoff | PASS |
| FieldWiring resolution | PASS — `TC-ChristmasHippo` resolved to current Background/Static context and field-hookup data |
| Phone camera initialization | PASS — live camera preview and Stop Camera control displayed |
| Final live artifact hash | PASS — `b4f6c27f...175cb20f` |

The operator accepted the corrected deployment after these checks.

### Explicitly deferred / not claimed as tested

The following were not exercised during this acceptance session and must not be retroactively marked PASS:

- physical QR decode, because no QR label was available at the test location;
- Work Orders = 1 positive redirect, because no open Work Orders were available;
- Work Orders > 1 selection page, because no open Work Orders were available;
- full Testing state matrix beyond the one positive redirect and disabled state observed;
- unassigned Container behavior;
- unknown Display behavior;
- FieldWiring-unavailable failure-boundary test;
- FieldWiring Display with no current wiring.

These remain regression cases for the next suitable scan acceptance session. They do not block acceptance of the corrected current production state.

## Failure Boundary

The required architecture remains:

> If FieldWiring is unavailable, Display Record, Testing, Container, Work Order, and other existing scan functions remain usable.

Do not add a FieldWiring health/API dependency to the Display hub merely to render the Field Wiring button.

## Repository Ownership

### MSB Production Database repository owns

- permanent Display/Container/Location identity contracts;
- scan payload rules;
- scan application/business source under `Scan/directus-extension-scan/`;
- Testing, Work Order, Container, FieldWiring, and future Setup/Deployment scan behavior;
- Directus application-destination contract using the established `db.sheboyganlights.org` origin;
- FieldWiring `display_id` deep-link contract;
- future scan-session/workflow business rules.

### MSB-Server-Management owns

- `/opt/directus/extensions/directus-extension-scan/` deployed runtime;
- Directus container/image/mount relationship;
- production runtime hashes;
- deployment/restart procedure;
- backup/rollback/recovery process;
- Synology/WebStation reverse-proxy route for `/scan/`;
- existing `db.sheboyganlights.org` -> Directus reverse proxy runtime;
- FieldWiring service/mount/proxy runtime.

A production application running on `msb-prod-db` does not automatically become Server Management source. Application behavior stays with its owning application/database repository; runtime hosting stays with Server Management.

## Future Setup/Deployment Compatibility

This integration intentionally did not redesign the scan platform.

Likely durable scan identities remain:

```text
DISP:<permanent display_id>
CONT:<permanent container_id>
LOC:<operational storage/location code>
```

Physical labels must remain durable asset/location identifiers and must not encode annual setup dates, loads, Stage assignments, application-specific URLs, or transient workflow state.

The next Setup/Deployment engineering work should reconstruct the real Container/Location setup workflow before deciding whether the current route implementation needs shared asset resolvers, scan-session state, transaction handlers, or other refactoring.

## Current Stop Point / Next Project

**FieldWiring Scan Integration is accepted production work after the Directus public-origin correction.**

No further Scan/FieldWiring code change is required to close this sub-project.

Remaining deferred regression cases can be exercised when appropriate without reopening the architecture unless they reveal a defect.

The FieldWiring marker-documentation correction was merged to `main` before the final FieldWiring/Scan integration merge, and the accepted production handoff reflects that reconciled contract.

The next major Production Database work may proceed to the separate Setup/Deployment engineering project using the established scan identity and repository ownership boundaries.

## Related Documents

- [Labeling and Scanning](README.md)
- [Deployed Display Scan Runtime Boundary](Deployed_Display_Scan_Runtime_Boundary.md)
- [Asset Identity and Scan Payload Standard](Asset_Identity_and_Scan_Payload_Standard.md)
- [Field Context Resolution Contract](Field_Context_Resolution_Contract.md)
- [Wiring System](../09_Wiring_System/README.md)
- [Setup and Deployment](../12_Setup_and_Deployment/README.md)
- [MSB-Server-Management — Display Scan Extension Deployment and Recovery](https://github.com/Gregovate/MSB-Server-Management/blob/agent/scan-fieldwiring-runtime-integration/docs/directus/Display_Scan_Extension_Deployment_and_Recovery.md)
- [MSB-Server-Management — Directus Restart Procedure](https://github.com/Gregovate/MSB-Server-Management/blob/agent/scan-fieldwiring-runtime-integration/docs/directus/Directus_Restart_Procedure.md)
