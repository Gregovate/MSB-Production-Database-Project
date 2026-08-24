# Deployed Display Scan Runtime Boundary

| Document control | Value |
|---|---|
| Status | CURRENT PRODUCTION DEPENDENCY — Procedure source candidate ready; production deployment pending |
| Current revision | 2026-08-23 |
| Owner | MSB Database Administrator |
| Production host | `msb-prod-db` |
| Production runtime path | `/opt/directus/extensions/directus-extension-scan/` |
| Server runtime documentation | `Gregovate/MSB-Server-Management` |

## Purpose

This document records the cross-repository boundary for the **existing deployed Display QR lookup** that the Production Database, Testing, Work Orders, FieldWiring, Procedures, and future Setup/Deployment scan workflows build upon.

The scan capability predates the current source-control/documentation structure. Its current production behavior and runtime were reconstructed on 2026-08-22, then the accepted camera-enabled application source was recovered into Git and the FieldWiring integration was deployed and accepted. Future work must extend this documented system rather than re-engineering it from memory or from a live-only artifact.

## Verified Current Runtime

The current Display QR lookup is implemented as a Directus endpoint extension on the Production Database server:

```text
msb-prod-db
    -> /opt/directus/extensions/directus-extension-scan/
        -> package.json
        -> dist/index.js
```

Directus executes:

```text
dist/index.js
```

The current accepted production SHA-256 after FieldWiring integration and the Directus public-origin correction is:

```text
b4f6c27f4880a8eaf8a90d8d55c7939c5bd190645dca9329344a86c3175cb20f
```

That hash remains the accepted **live production baseline** until the Procedure-enabled candidate is actually deployed and accepted through the Server Management safety gate.

The accepted application/business source is version-controlled under:

```text
Scan/directus-extension-scan/
    package.json
    src/index.js
    dist/index.js
```

The live deployment does not need to contain the development `src/` tree. Application source belongs in the Production Database repository; live deployment/recovery belongs in Server Management.

The older file historically named:

```text
dist/index-copy original-no-camera-scanning.js
```

predates camera scanning and is **not** a valid rollback artifact for the current accepted system.

Detailed Directus/runtime administration, current hashes, rollback copies, restart, verification, and Synology `/scan/` proxy requirements are owned by [MSB-Server-Management](https://github.com/Gregovate/MSB-Server-Management/blob/main/docs/directus/Display_Scan_Extension_Deployment_and_Recovery.md).

## Current Route Inventory

Verified production routes include:

```text
/scan/
/scan/DISP/:key
/scan/CONT/:key
/scan/DISP/:key/test
/scan/DISP/:key/container
/scan/DISP/:key/work-orders
```

The Procedure source candidate does **not** add or replace a Scan route. It adds a Display-hub link to the already-deployed protected Procedure application.

The scan landing page supports camera scanning, QR codes, 1-D barcodes, manual entry, and URL handling.

## Display Identity Resolution

`/scan/DISP/:key` uses the route key directly against:

```text
ref.display.display_id
```

The Display hub therefore already resolves the permanent Production Database Display identity before presenting task choices.

The physical Display QR must continue to represent the durable Display identity rather than an application-specific destination.

## Current Display Hub Behavior

The currently accepted production hub independently presents or resolves:

- the Directus Display record;
- the current Display Testing record/status when applicable;
- the assigned Container;
- active Work Orders; and
- the accepted Field Wiring action.

The Procedure-enabled source candidate adds one independent **Procedures** action without changing those existing actions.

Testing, Container, Work Order, FieldWiring, and Procedure remain separate downstream actions. A failure in one downstream application must not make the basic Display hub or unrelated actions unavailable.

## Authentication and Public-Origin Boundary

The scan extension does not implement a separate authentication mechanism. It relies on the existing protected application boundary.

Current public origins are intentionally separate:

```text
Scan application         https://my.sheboyganlights.org/scan/
FieldWiring              https://my.sheboyganlights.org/fieldwiring/
Procedure                https://my.sheboyganlights.org/procedures/
Directus administration  https://db.sheboyganlights.org/
```

Directus-facing scan destinations must continue to use the established `db.sheboyganlights.org` origin rather than assuming the Scan page shares the Directus origin.

Authentication implementation, Cloudflare policy administration, Directus service operation, and server deployment mechanics are infrastructure/runtime concerns. Individual downstream field applications must not silently invent competing authentication behavior.

## FieldWiring Integration — Accepted Production

FieldWiring is the first controlled additive Display integration and is now production-operational from the Display hub.

Accepted direction:

```text
Existing Display QR
    -> existing protected Directus scan endpoint
        -> permanent display_id resolved
            -> existing Display scan hub
                -> Field Wiring action
                    -> /fieldwiring/wiring.html?display_id=<display_id>
                        -> FieldWiring resolves current Stage/Preview/Scene from PostgreSQL
```

The accepted FieldWiring direct-entry contract is:

```text
/fieldwiring/wiring.html?display_id=<permanent display_id>
```

The scan hub passes only the permanent `display_id`.

Do not pass or encode:

- LOR Prop UUID;
- Preview UUID/name;
- Scene UUID/name;
- Stage ID/key;
- Google Drive path;
- controller address;
- FieldWiring snapshot/import ID.

FieldWiring remains a downstream consumer. A FieldWiring outage must not disable Display, Testing, Container, Work Order, or other existing scan actions.

See [FieldWiring Scan Integration Engineering Handoff — 2026-08-22](FieldWiring_Scan_Integration_Engineering_Handoff_2026-08-22.md) for the accepted implementation and production evidence.

## Procedure Display Scan Integration — Source Candidate Ready

The standalone Procedure application is production-operational at:

```text
https://my.sheboyganlights.org/procedures/
```

Procedure already accepts permanent Display identity as an application entry input and already owns its Setup/Takedown/Inspection task-selection UI.

The agreed Display Scan UX is one additive **Procedures** button:

```text
Existing Display QR
    -> /scan/DISP/:key
        -> permanent display_id resolved
            -> existing Display scan hub
                -> Procedures
                    -> /procedures/?display_id=<permanent display_id>
                        -> existing Procedure page
                            -> operator chooses Setup, Takedown, or Inspection
```

The Scan hub passes only the permanent `display_id`. It does not duplicate Setup/Takedown/Inspection buttons and does not call the Procedure API merely to determine whether the button should render.

Git-controlled candidate source is on:

```text
branch: agent/procedure-scan-action
implementation commit: 333f7c20a26e8ed2a0460ddbf309c167bffa2992
```

Both candidate files intentionally use the same Git blob:

```text
Scan/directus-extension-scan/src/index.js
Scan/directus-extension-scan/dist/index.js
Git blob: b3fd0e992b22407784e9da0dbc21d371c0d4a483
```

Compared with the current `main` baseline, each file has exactly one added line: the Procedures link. No existing Scan route or database query is changed.

This is **not yet production acceptance**. The current live artifact remains the accepted hash `b4f6c27f4880a8eaf8a90d8d55c7939c5bd190645dca9329344a86c3175cb20f` until the Server Management deployment gate verifies the live baseline, creates a new rollback, stages and syntax-checks the candidate, restarts Directus, and completes regression acceptance.

The Procedure follow-on preserves the architectural rules proven by FieldWiring:

- no physical QR change;
- no second Display resolver;
- no Stage/Scene/Google path encoded in the scan link;
- no Procedure schema or generic document registry merely for scan integration;
- no Procedure health/API call required just to render the Display hub; and
- existing Display, Testing, Container, Work Order, and FieldWiring actions remain independently usable if Procedure is unavailable.

## Future Setup/Deployment Scan Platform Boundary

The scan extension is expected to become more important during Setup/Deployment, where Container and Storage Location scanning may be frequent.

Durable labels should remain asset/location identifiers such as:

```text
DISP:<display_id>
CONT:<container_id>
LOC:<location_code>
```

Annual setup dates, load numbers, transient movement state, application-specific routes, and other workflow state must not become physical label identity.

The broader Setup/Deployment workflow remains separate from Procedure document lookup. Reconstruct the actual pull/stage/load/delivery process before deciding what shared scan-session/application structure, transaction semantics, or schema changes are justified.

## Cross-Repository Ownership

### MSB Production Database repository

Owns:

- permanent Display/Container/Location identity and relationships;
- scan payload/business contracts;
- Git-controlled scan application source under `Scan/directus-extension-scan/`;
- Testing, Work Order, Container, FieldWiring, Procedure, and Setup/Deployment integration behavior;
- shared field-context resolution and downstream application contracts.

### MSB-Server-Management

Owns:

- deployed `/opt/directus/extensions/directus-extension-scan/` runtime record;
- Directus container/image/mount relationship;
- runtime hashes;
- deployment/restart/recovery procedure;
- backup/rollback procedure and artifacts;
- Synology/WebStation `/scan/` reverse-proxy routing;
- established Directus public-origin runtime; and
- FieldWiring/Procedure service and proxy infrastructure.

A server path does not transfer business-rule authority to the Server Management repository.

## Current Stop Point

As of 2026-08-23:

- current scan application source is recovered in Git;
- FieldWiring Scan Integration is accepted production work;
- current accepted live scan artifact hash is `b4f6c27f4880a8eaf8a90d8d55c7939c5bd190645dca9329344a86c3175cb20f`;
- the Directus public-origin correction is accepted production behavior;
- the `/scan/` Synology route is production-operational;
- standalone Procedure field access is production-operational;
- the Procedure Display Scan UX is now settled as one **Procedures** button that passes only permanent `display_id` and leaves Setup/Takedown/Inspection selection inside the existing Procedure application;
- the Git-controlled Procedure-enabled Scan source candidate is implemented on `agent/procedure-scan-action`, with implementation commit `333f7c20a26e8ed2a0460ddbf309c167bffa2992`;
- production deployment and regression acceptance of that candidate are still pending through the current Server Management runbook;
- the broader Container/Location Setup/Deployment workflow remains separate engineering scope; and
- no schema or physical QR change is part of this bounded integration.

Before deploying the candidate, read the current Server Management [Display Scan Extension Deployment and Recovery](https://github.com/Gregovate/MSB-Server-Management/blob/main/docs/directus/Display_Scan_Extension_Deployment_and_Recovery.md) runbook. Do not rediscover the Directus extension path, current runtime hash, restart procedure, `/scan/` proxy, or rollback process from scratch unless the documented runtime is proven wrong.

## Related Documents

- [Labeling and Scanning](README.md)
- [FieldWiring Scan Integration Engineering Handoff](FieldWiring_Scan_Integration_Engineering_Handoff_2026-08-22.md)
- [Asset Identity and Scan Payload Standard](Asset_Identity_and_Scan_Payload_Standard.md)
- [Field Context Resolution Contract](Field_Context_Resolution_Contract.md)
- [Wiring System](../09_Wiring_System/README.md)
- [Setup and Deployment](../12_Setup_and_Deployment/README.md)
- [Procedure Application](../../../../../Procedures/Application/README.md)
- [MSB Server Management — Display Scan Extension Deployment and Recovery](https://github.com/Gregovate/MSB-Server-Management/blob/main/docs/directus/Display_Scan_Extension_Deployment_and_Recovery.md)
