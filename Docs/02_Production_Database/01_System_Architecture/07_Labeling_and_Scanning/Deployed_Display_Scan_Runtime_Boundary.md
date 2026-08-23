# Deployed Display Scan Runtime Boundary

| Document control | Value |
|---|---|
| Status | CURRENT PRODUCTION DEPENDENCY — runtime reconstructed and cross-repository recovery documented |
| Current revision | 2026-08-22 |
| Owner | MSB Database Administrator |
| Production host | `msb-prod-db` |
| Production runtime path | `/opt/directus/extensions/directus-extension-scan/` |
| Server runtime documentation | `Gregovate/MSB-Server-Management` |

## Purpose

This document records the cross-repository boundary for the **existing deployed Display QR lookup** that the Production Database, Testing, Work Orders, FieldWiring, and future Setup/Deployment scan workflows build upon.

The scan capability predates the current source-control/documentation structure. Its current production behavior and runtime were reconstructed on 2026-08-22 so future work can extend the existing system instead of re-engineering it from memory.

## Verified Current Runtime

The current Display QR lookup is implemented as a Directus endpoint extension on the Production Database server:

```text
msb-prod-db
    -> /opt/directus/extensions/directus-extension-scan/
        -> package.json
        -> dist/index.js
        -> dist/index-copy original-no-camera-scanning.js
```

Directus executes:

```text
dist/index.js
```

The current production SHA-256 recorded on 2026-08-22 is:

```text
824aa56857c3d52c3ba9186c4721313e2172dc24ec32653045bb7bf3b008d7af
```

`package.json` declares `src/index.js`, but no deployed `src/` directory exists. The production deployment is therefore currently a built-only runtime artifact and must be recovered into a controlled Git source/deployment boundary before the scan platform is expanded substantially.

The older file:

```text
dist/index-copy original-no-camera-scanning.js
```

predates camera scanning and is **not** a valid rollback artifact for the current accepted system.

Detailed Directus/runtime administration, hashes, restart, verification, and rollback requirements are owned by [MSB-Server-Management](https://github.com/Gregovate/MSB-Server-Management/blob/agent/scan-fieldwiring-runtime-integration/docs/directus/Display_Scan_Extension_Deployment_and_Recovery.md).

## Current Route Inventory

Verified routes include:

```text
/scan/
/scan/DISP/:key
/scan/CONT/:key
/scan/DISP/:key/test
/scan/DISP/:key/container
/scan/DISP/:key/work-orders
```

The scan landing page supports camera scanning, QR codes, 1-D barcodes, manual entry, and URL handling.

## Display Identity Resolution

`/scan/DISP/:key` uses the route key directly against:

```text
ref.display.display_id
```

The Display hub therefore already resolves the permanent Production Database Display identity before presenting task choices.

The physical Display QR must continue to represent the durable Display identity rather than an application-specific destination.

## Current Display Hub Behavior

The current hub independently presents or resolves:

- the Directus Display record;
- the current Display Testing record/status when applicable;
- the assigned Container;
- active Work Orders.

Testing, Container, and Work Order routes perform their own required database lookups after navigation. They do not depend on FieldWiring.

This independence is a required failure boundary for future integrations.

## Authentication Boundary

The scan extension does not implement authentication itself. It relies on the existing protected Directus/application session and the current protected `my.sheboyganlights.org` access boundary.

Authentication implementation, Cloudflare policy administration, Directus service operation, and server deployment mechanics are infrastructure/runtime concerns. Individual downstream field applications must not silently invent competing authentication behavior.

## FieldWiring Integration Rule

FieldWiring is the current additive Display integration.

Required direction:

```text
Existing Display QR
    -> existing authenticated Directus scan endpoint
        -> permanent display_id resolved
            -> existing Display scan hub
                -> Field Wiring action
                    -> /fieldwiring/wiring.html?display_id=<display_id>
                        -> FieldWiring resolves current Stage/Preview/Scene from PostgreSQL
```

The verified FieldWiring direct-entry contract is:

```text
/fieldwiring/wiring.html?display_id=<permanent display_id>
```

The scan hub should pass only the permanent `display_id`.

Do not pass or encode:

- LOR Prop UUID;
- Preview UUID/name;
- Scene UUID/name;
- Stage ID/key;
- Google Drive path;
- controller address;
- FieldWiring snapshot/import ID.

FieldWiring must remain a downstream consumer. A FieldWiring outage must not disable Display, Testing, Container, Work Order, or other existing scan actions.

See [FieldWiring Scan Integration Engineering Handoff — 2026-08-22](FieldWiring_Scan_Integration_Engineering_Handoff_2026-08-22.md) for the current implementation/acceptance plan.

## Future Scan Platform Boundary

The scan extension is expected to become more important during Setup/Deployment, where Container and Storage Location scanning may be frequent.

Durable labels should remain asset/location identifiers such as:

```text
DISP:<display_id>
CONT:<container_id>
LOC:<location_code>
```

Annual setup dates, load numbers, transient movement state, application-specific routes, and other workflow state must not become physical label identity.

FieldWiring is the first controlled additive integration. Do not redesign the whole scan system merely to add this action. After FieldWiring integration is accepted, the separate Setup/Deployment engineering work should reconstruct the actual pull/stage/load/delivery scan workflow and then determine what shared scan-session/application structure is justified.

## Cross-Repository Ownership

### MSB Production Database repository

Owns:

- permanent Display/Container/Location identity and relationships;
- scan payload/business contracts;
- Testing, Work Order, Container, FieldWiring, Setup/Deployment integration behavior;
- shared field-context resolution;
- the Git-controlled application source for Production Database scan behavior once recovered.

### MSB-Server-Management

Owns:

- deployed `/opt/directus/extensions/directus-extension-scan/` runtime record;
- Directus container/image/mount relationship;
- runtime hashes;
- deployment/restart/recovery procedure;
- backup/rollback procedure;
- FieldWiring service/mount/proxy infrastructure.

A server path does not transfer business-rule authority to the Server Management repository.

## Current Stop Point

As of 2026-08-22:

- current scan routes and Display action generation have been reconstructed;
- current production hashes are recorded;
- the missing deployed `src/` source boundary is identified;
- FieldWiring is production-operational independently;
- the correct FieldWiring `display_id` deep link is verified;
- no Field Wiring action has been deployed to `/scan/DISP/:key` yet;
- no scan-related Directus restart has occurred for this integration;
- no schema change is required or approved.

Resume with the [FieldWiring Scan Integration Engineering Handoff](FieldWiring_Scan_Integration_Engineering_Handoff_2026-08-22.md) and the corresponding Server Management runtime document rather than re-inspecting the system from scratch.

## Related Documents

- [Labeling and Scanning](README.md)
- [FieldWiring Scan Integration Engineering Handoff](FieldWiring_Scan_Integration_Engineering_Handoff_2026-08-22.md)
- [Asset Identity and Scan Payload Standard](Asset_Identity_and_Scan_Payload_Standard.md)
- [Field Context Resolution Contract](Field_Context_Resolution_Contract.md)
- [Wiring System](../09_Wiring_System/README.md)
- [Setup and Deployment](../12_Setup_and_Deployment/README.md)
- [MSB Server Management — Display Scan Extension Deployment and Recovery](https://github.com/Gregovate/MSB-Server-Management/blob/agent/scan-fieldwiring-runtime-integration/docs/directus/Display_Scan_Extension_Deployment_and_Recovery.md)
