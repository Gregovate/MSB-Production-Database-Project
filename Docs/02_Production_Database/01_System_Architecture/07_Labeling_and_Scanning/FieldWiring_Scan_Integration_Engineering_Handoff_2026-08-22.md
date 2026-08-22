# FieldWiring Scan Integration Engineering Handoff — 2026-08-22

| Document control | Value |
|---|---|
| Status | CURRENT ENGINEERING HANDOFF — live scan runtime recovered; no scan change deployed yet |
| Current revision | 2026-08-22 |
| Production scan host | `msb-prod-db` / `192.168.5.9` |
| Production scan runtime | `/opt/directus/extensions/directus-extension-scan/` |
| FieldWiring public route | `https://my.sheboyganlights.org/fieldwiring/` |
| FieldWiring production state | OPERATIONAL / PostgreSQL-backed / read-only |
| Server runtime documentation | `Gregovate/MSB-Server-Management` |

## Purpose

This document is the current engineering handoff for adding **Field Wiring** to the existing permanent Display QR workflow without changing the physical QR identity or making existing scan functions dependent on FieldWiring.

It records the live production scan implementation recovered on 2026-08-22, the verified FieldWiring deep-link contract, the required failure boundary, the source-control recovery gap, and the exact point where implementation should resume.

This is also the first deliberate additive integration onto the existing scan platform. The design must remain compatible with later Setup/Deployment scanning work, including high-volume Container and Storage Location scanning, without prematurely redesigning the production scan runtime during the FieldWiring change.

## Current Production Baseline

### FieldWiring

FieldWiring is production-operational at:

```text
https://my.sheboyganlights.org/fieldwiring/
```

Accepted production state:

- live read-only PostgreSQL backend;
- persistent Google `Display Folders` filesystem operational;
- systemd-hosted backend operational on `192.168.5.9:8790`;
- protected Synology reverse proxy operational;
- desktop and phone acceptance passed;
- Display search repaired and production-tested;
- FormView remains fallback/reference.

The scan-hub integration is the remaining FieldWiring deployment milestone.

### Display scan runtime

The current Display scan system is a Directus endpoint extension deployed at:

```text
/opt/directus/extensions/directus-extension-scan/
```

Verified live runtime files on 2026-08-22:

```text
package.json

dist/
    index.js
    index-copy original-no-camera-scanning.js
```

Current `dist/index.js` SHA-256:

```text
824aa56857c3d52c3ba9186c4721313e2172dc24ec32653045bb7bf3b008d7af
```

The older `index-copy original-no-camera-scanning.js` predates camera-scanning support and is **not** a valid rollback copy for the current accepted production system.

Server deployment/recovery facts are owned by `Gregovate/MSB-Server-Management` and must remain synchronized with this application/business handoff.

## Recovered Scan Architecture

The extension is one Directus endpoint module. It handles scan-page HTML, camera/manual input, Display and Container lookup routes, and downstream redirects directly in the deployed JavaScript.

Verified current routes include:

```text
/scan/
/scan/DISP/:key
/scan/CONT/:key
/scan/DISP/:key/test
/scan/DISP/:key/container
/scan/DISP/:key/work-orders
```

### `/scan/`

The scan landing page provides:

- camera scanning;
- QR support;
- 1-D barcode support through `html5-qrcode`;
- manual entry;
- URL handling;
- client-side routing to the extension endpoints.

The extension does not implement its own authentication. It relies on the existing protected Directus/application session. Camera access requires HTTPS.

### Display identity resolution

`/scan/DISP/:key` uses the route key directly against:

```text
ref.display.display_id
```

The permanent Production Database `display_id` is therefore already the resolved identity at the Display hub.

There is no need for FieldWiring to introduce another QR identity, LOR UUID translation, Stage key, Scene UUID, Google Drive path, or controller address into the scan contract.

### Display action menu

The Display hub currently queries the resolved Display and then renders its actions directly in server-generated HTML.

Current actions are:

- **Open Display Record**;
- Testing action/status;
- **Open Container**;
- **Open Work Orders** when active Work Orders exist.

The Testing button is state-aware and may be enabled or disabled based on current season/container test-session state.

### Existing downstream independence

The existing Test, Container, and Work Order routes each perform their own required database lookup after navigation.

FieldWiring must not be inserted into those routes or become a prerequisite for them.

Required failure boundary:

> If FieldWiring is unavailable, Display Record, Testing, Container, Work Order, and other existing scan functions remain usable.

## Verified FieldWiring Display Contract

The originally conceptual route:

```text
/fieldwiring/?display_id=<display_id>
```

is **not** the current direct-entry contract.

The FieldWiring landing page does not consume `display_id` from its own query string. The wiring page does.

Current direct Display route:

```text
/fieldwiring/wiring.html?display_id=<permanent display_id>
```

The wiring page forwards `display_id` to the FieldWiring API. The backend then resolves the current Display context from PostgreSQL and derives the applicable Stage/Preview/Scene context.

FieldWiring deliberately validates any supplied context against the Display-resolved context, so the scan hub should pass **only** the permanent Display ID.

Do not pass:

- Stage ID/key;
- Preview UUID/name;
- Scene UUID/name;
- LOR Prop UUID;
- controller address;
- Google Drive path;
- FieldWiring import/snapshot ID.

## Approved Additive Integration Shape

The smallest safe change to the current Display hub is one additional independent action:

```text
Field Wiring
    -> /fieldwiring/wiring.html?display_id=<display.display_id>
```

The scan hub should not perform a FieldWiring health/API call merely to render this button.

The Field Wiring action should be generated only from the already-resolved `display.display_id`.

No schema change is required for this integration.

No FieldWiring backend change is required merely to support this link.

No physical QR change is required.

## Source-Control Recovery Gap

The deployed `package.json` declares:

```text
source: src/index.js
path:   dist/index.js
```

but the live production extension contains no `src/` directory.

This means the current accepted scan implementation is effectively a built-only server artifact.

Because Setup/Deployment is expected to add substantial Container/Location scanning later, continuing to evolve the scan platform only through manual `/opt/.../dist/index.js` edits would create an unacceptable recovery/documentation risk.

### Required direction

Recover the current accepted scan implementation into a Git-controlled application source/deployment boundary before substantial scan-platform expansion.

The application/business source belongs with the Production Database project because it implements Production Database asset identity and workflow routing. `MSB-Server-Management` owns the deployed path, Directus reload/recovery procedure, runtime hashes, and rollback.

### FieldWiring scope rule

Do **not** use this source-recovery requirement as an excuse to redesign the entire scan extension before adding Field Wiring.

The FieldWiring integration should remain a minimal additive change after the current implementation is safely preserved/recovered.

Broader internal scan-platform structure should be derived from the actual Setup/Deployment workflow rather than invented prematurely.

## Future Setup/Deployment Compatibility

FieldWiring is the first new controlled task integration, but upcoming Setup/Deployment work is expected to require much heavier scanning.

Likely durable identities remain:

```text
DISP:<permanent display_id>
CONT:<permanent container_id>
LOC:<operational storage/location code>
```

Physical labels must remain durable asset/location identifiers. They must not encode annual setup dates, loads, Stage assignments, application-specific URLs, or transient workflow state.

Future Setup work may require scan-session behavior such as:

```text
Container -> Location
Location -> Container
```

plus pull/staging/load/delivery confirmations.

Those workflows are **not** being implemented as part of the FieldWiring action. The current requirement is to preserve a scan architecture that can accept them additively later.

After FieldWiring Scan Integration closes, Setup/Deployment engineering should reconstruct the real setup-day process before deciding whether the current one-file route implementation should be refactored into shared asset resolvers, action definitions, scan-session state, or transaction handlers.

## Implementation Safety Gate

Before changing production:

1. Preserve/recover the accepted current scan implementation in Git-controlled source or an explicitly controlled recovery artifact.
2. Verify the live `dist/index.js` SHA-256 still matches the accepted pre-change baseline.
3. Capture a new rollback copy of the current camera-enabled `dist/index.js`.
4. Record the backup path/hash in the Server Management change record.
5. Make only the Field Wiring additive action change.
6. Restart/reload Directus using the documented Server Management procedure.
7. Verify every existing scan route/function.
8. Verify the new Field Wiring route with a real permanent Display QR.
9. Confirm a FieldWiring outage does not disable existing scan functions.
10. Update both repository handoffs before considering the integration complete.

## Acceptance Matrix

At minimum verify:

| Test | Required result |
|---|---|
| `/scan/` | Opens normally |
| Camera scan | Existing camera behavior preserved |
| Manual `DISP:<id>` | Resolves same Display |
| Existing Display QR | Opens existing Display hub |
| Display Record | Still opens |
| Testing | Existing state/route behavior preserved |
| Assigned Container | Still opens |
| Unassigned Container | Existing no-container behavior preserved |
| Work Orders = 0 | Existing disabled/no-open-work behavior preserved |
| Work Orders = 1 | Existing direct-open behavior preserved |
| Work Orders > 1 | Existing selection behavior preserved |
| Unknown Display | Existing not-found behavior preserved |
| Field Wiring | Opens `/fieldwiring/wiring.html?display_id=<id>` |
| FieldWiring unavailable | Existing scan actions still operate |
| FieldWiring Display with no current wiring | FieldWiring owns and displays its own unavailable/error behavior; scan hub remains healthy |

## Repository Ownership

### MSB Production Database repository owns

- permanent Display/Container/Location identity contracts;
- scan payload rules;
- scan action/business behavior;
- Testing, Work Order, Container, FieldWiring, Setup/Deployment integration contracts;
- FieldWiring `display_id` deep-link contract;
- future scan-session/workflow business rules;
- Git-controlled scan application source when recovered.

### MSB-Server-Management owns

- `/opt/directus/extensions/directus-extension-scan/` runtime record;
- Directus container/image/mount relationship;
- runtime hashes;
- deployment/restart procedure;
- backup/rollback/recovery process;
- FieldWiring systemd/mount/proxy runtime;
- infrastructure changes required by an accepted scan integration.

Do not duplicate either repository's owned material into the other. Cross-link the responsible documents.

## Current Stop Point / Resume Development

As of this handoff:

- FieldWiring production deployment is accepted;
- Display and phone acceptance are complete;
- the current scan runtime has been reconstructed sufficiently for the FieldWiring action;
- current production `dist/index.js` and package hashes are recorded;
- the missing deployed `src/` source boundary is identified;
- no Field Wiring scan action has been deployed;
- no Directus restart has been performed for this integration;
- no schema change is required or approved.

Resume by preserving/recovering the accepted current scan implementation into the responsible Git-controlled source boundary, then make the minimal Field Wiring action change and run the acceptance matrix above.

After Scan Integration is accepted and both repository handoffs are closed, start the separate Setup/Deployment engineering work from its current README and reconstruct the actual Container/Location setup workflow before designing schema or scan-session behavior.

## Related Documents

- [Labeling and Scanning](README.md)
- [Deployed Display Scan Runtime Boundary](Deployed_Display_Scan_Runtime_Boundary.md)
- [Asset Identity and Scan Payload Standard](Asset_Identity_and_Scan_Payload_Standard.md)
- [Field Context Resolution Contract](Field_Context_Resolution_Contract.md)
- [Wiring System](../09_Wiring_System/README.md)
- [Setup and Deployment](../12_Setup_and_Deployment/README.md)
- [MSB-Server-Management — Display Scan Extension Deployment and Recovery](https://github.com/Gregovate/MSB-Server-Management/blob/agent/scan-fieldwiring-runtime-integration/docs/directus/Display_Scan_Extension_Deployment_and_Recovery.md)
- [MSB-Server-Management — FieldWiring Production Runtime](https://github.com/Gregovate/MSB-Server-Management/blob/agent/scan-fieldwiring-runtime-integration/docs/server/FieldWiring_Production_Runtime.md)
