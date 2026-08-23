# FieldWiring Scan Integration Engineering Handoff — 2026-08-22

| Document control | Value |
|---|---|
| Status | ACCEPTED PRODUCTION — Field Wiring action deployed and operational |
| Current revision | 2026-08-22 local / 2026-08-23 UTC |
| Production scan host | `msb-prod-db` / `192.168.5.9` |
| Production scan runtime | `/opt/directus/extensions/directus-extension-scan/` |
| Public scan route | `https://my.sheboyganlights.org/scan/` |
| FieldWiring public route | `https://my.sheboyganlights.org/fieldwiring/` |
| Application source branch | `agent/fieldwiring-server-deployment-reconnaissance` |
| Server runtime branch | `agent/scan-fieldwiring-runtime-integration` |

## Purpose

This document is the accepted engineering handoff for adding **Field Wiring** to the existing permanent Display QR/scan workflow without changing physical Display identity and without making existing scan functions dependent on FieldWiring.

The integration is complete and production-operational. The current scan application source has also been recovered into Git so future Setup/Deployment scan work no longer has to start from an undocumented live-only artifact.

## Accepted Production Result

The Display scan hub now includes one independent action:

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
```

The application/business source belongs to the Production Database repository because it contains MSB-specific Display, Testing, Container, Work Order, and FieldWiring behavior. The fact that Directus hosts the endpoint does not transfer application ownership to Server Management.

## Production Artifact Identity

Accepted pre-change production `dist/index.js` SHA-256:

```text
824aa56857c3d52c3ba9186c4721313e2172dc24ec32653045bb7bf3b008d7af
```

Accepted FieldWiring-enabled production `dist/index.js` SHA-256:

```text
e17ea51ec1f1993440719cb3ca35eb84c7250eb4f3d0a25784d0a42ef2114df0
```

The older live file named:

```text
dist/index-copy original-no-camera-scanning.js
```

remains historical only and is **not** a valid rollback artifact for the current camera-enabled scan system.

The verified pre-change rollback copy created for this deployment is recorded by MSB-Server-Management at:

```text
/home/msbadmin/backups/directus-scan/pre-fieldwiring-20260823T011615Z/index.js
```

Its SHA-256 is the accepted pre-change hash `824aa568...008d7af`.

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

## Public Routing Discovery and Correction

During production acceptance, the Directus endpoint was healthy internally but the public `/scan/` path returned the Synology/WebStation 404 page.

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

The exact nginx configuration path, backup, and reload evidence are owned by `Gregovate/MSB-Server-Management`.

## Production Acceptance Evidence

Accepted checks completed during the deployment:

| Test | Result |
|---|---|
| Directus JavaScript syntax check | PASS |
| Directus restart | PASS |
| Extension load | PASS — `directus-extension-scan` loaded |
| Internal `/scan/` | PASS — HTTP 200 |
| Public Synology `/scan/` | PASS — HTTP 200 |
| Public `/scan` no-slash redirect | PASS — HTTP 301 to `/scan/` |
| Manual Display navigation | PASS |
| Field Wiring action rendered | PASS |
| Permanent `display_id` handoff | PASS |
| FieldWiring resolution | PASS — `TC-ChristmasHippo` resolved to current Background/Static context and field-hookup data |
| Phone camera initialization | PASS — live camera preview and Stop Camera control displayed |
| Post-restart live artifact hash | PASS — `e17ea51e...2114df0` |

The operator accepted the deployment after these checks.

### Explicitly deferred / not claimed as tested

The following were not exercised during this acceptance session and must not be retroactively marked PASS:

- physical QR decode, because no QR label was available at the test location;
- full Display Record click-through regression;
- full Testing state matrix;
- assigned/unassigned Container matrix;
- Work Orders 0 / 1 / >1 matrix;
- unknown Display behavior;
- FieldWiring-unavailable failure-boundary test;
- FieldWiring Display with no current wiring.

These remain regression cases for the next suitable scan acceptance session. The FieldWiring code change itself was additive and did not alter the camera, Testing, Container, Work Order, or unknown-Display code paths.

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
- FieldWiring `display_id` deep-link contract;
- future scan-session/workflow business rules.

### MSB-Server-Management owns

- `/opt/directus/extensions/directus-extension-scan/` deployed runtime;
- Directus container/image/mount relationship;
- production runtime hashes;
- deployment/restart procedure;
- backup/rollback/recovery process;
- Synology/WebStation reverse-proxy route for `/scan/`;
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

**FieldWiring Scan Integration is accepted production work.**

No further Scan/FieldWiring code change is required to close this sub-project.

Remaining deferred regression cases can be exercised when appropriate without reopening the architecture unless they reveal a defect.

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
