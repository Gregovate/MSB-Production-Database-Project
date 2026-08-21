# Deployed Display Scan Runtime Boundary

| Document control | Value |
|---|---|
| Status | VERIFIED CURRENT RUNTIME DEPENDENCY — implementation documentation still being recovered |
| Current revision | 2026-08-19 |
| Owner | MSB Database Administrator |
| Production host | `msb-prod-db` |
| Production runtime path | `/opt/directus/extensions/directus-extension-scan/` |
| Related server-management repository | `Gregovate/MSB-Server-Management` |

## Purpose

This document records the cross-repository boundary for the **existing deployed Display QR lookup** that the Production Database, Testing, Work Orders, and FieldWiring build upon.

This capability predates the current documentation structure and was deployed directly on the Production Database server before the server environment was being systematically captured in Git. The runtime has now been re-identified and must be treated as an existing production dependency rather than a future scan design.

## Verified Current Runtime

The current Display QR lookup is implemented as a Directus endpoint extension on the Production Database server:

```text
msb-prod-db
    -> /opt/directus/extensions/directus-extension-scan/
        -> dist/index.js
```

The deployed extension uses Directus' database connection to resolve a permanent Production Database Display identity and present the existing Display scan hub.

Current verified Display routes include:

```text
/scan/
/scan/DISP/:key
/scan/DISP/:key/test
/scan/DISP/:key/container
/scan/DISP/:key/work-orders
```

The Display hub currently resolves `ref.display.display_id` and provides working destinations for the Display record, current Testing record when applicable, assigned Container, and active Work Orders.

The physical Display QR therefore already supplies a stable entry point into Production Database identity and task navigation. FieldWiring must extend this existing result rather than creating another QR or Display lookup engine.

## Authentication Boundary

The deployed scan route is behind the existing protected database/application access boundary. A user who is not already authenticated is prompted through the current Cloudflare/Google authentication path before reaching the protected Directus-backed lookup.

Authentication implementation, Cloudflare policy administration, Directus service operation, and production-server deployment mechanics are infrastructure/runtime concerns and must not be reimplemented inside FieldWiring.

## Cross-Repository Ownership

### MSB Production Database repository

Owns:

- permanent Display identity and authoritative database relationships;
- the database contracts consumed by the scan endpoint;
- Testing and Work Order data behavior reached through the existing hub;
- the shared field-context contract used after a Display is resolved; and
- FieldWiring's downstream behavior after the operator selects Field Wiring.

### MSB-Server-Management repository / live SSH workspace

`Gregovate/MSB-Server-Management` documents and supports the Production Database server and explicitly uses SSH inspection of live `/opt/...` runtime directories as part of its engineering workflow.

It is the cross-reference for:

- the current `msb-prod-db` runtime environment;
- Directus server administration and restart/deployment procedures;
- inspection and recovery of the live scan extension under `/opt/directus/extensions`;
- Cloudflare/server runtime dependencies as they are documented; and
- backup/recovery and production-change procedures for the deployed server.

Repository: <https://github.com/Gregovate/MSB-Server-Management>

The existence of a file under `/opt/...` does not by itself transfer application/business ownership to Server Management. The Server Management project records and administers the deployed runtime; the responsible application/database repositories remain authoritative for their own business contracts.

## FieldWiring Integration Rule

FieldWiring must build on the existing resolved Display identity.

Required direction:

```text
Existing Display QR
    -> existing authenticated Directus scan endpoint
        -> permanent display_id resolved
            -> existing Display scan hub
                -> Field Wiring action
                    -> shared Stage/Sub-stage/Scene context resolution
                        -> current FieldWiring view
```

FieldWiring must not:

- create a second QR payload for the same Display;
- bypass the existing permanent `display_id` identity;
- encode Stage, Scene, Preview, Google Drive path, or FieldWiring-specific state in the physical QR;
- duplicate the existing Testing or Work Order scan logic; or
- make the live `/opt/directus/extensions` implementation an undocumented hidden dependency again.

## Documentation Rule Going Forward

Any Production Database feature that depends on a server-local runtime component must include an explicit cross-reference to the responsible Server Management documentation or deployed-runtime record.

Conversely, the Server Management project should document enough of the deployed scan extension, Directus service dependency, authentication boundary, backup/recovery path, and change/restart process to allow the runtime to be reconstructed without relying on personal memory.

Do not copy secrets or protected runtime configuration into either repository.

## Related Documents

- [Labeling and Scanning](README.md)
- [Asset Identity and Scan Payload Standard](Asset_Identity_and_Scan_Payload_Standard.md)
- [Field Context Resolution Contract](Field_Context_Resolution_Contract.md)
- [Wiring System](../09_Wiring_System/README.md)
- [Testing System](../05_Testing_System/README.md)
- [Work Orders](../06_Work_Orders/README.md)
- [MSB Server Management](https://github.com/Gregovate/MSB-Server-Management)
