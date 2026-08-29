# Label Payload and Profile Architecture

| Document control | Value |
|---|---|
| Status | DRAFT — ENGINEERING RECONNAISSANCE BASELINE |
| Revision | 2026-08-27 |
| Owner | Labeling and Scanning subsystem |
| Scope | Label payload generation, scan compatibility, label-profile boundary, and LabelPrintService integration |

## Purpose

This document records the reconciled current state of MSB label payload generation and defines the proposed engineering boundary for future label-profile work.

This is a reconnaissance and contract-definition document. It does **not** authorize a PostgreSQL schema change, QR payload migration, Scan resolver redesign, production-template replacement, or LabelPrintService code change.

## Mandatory System Boundary

Read [Labeling and Scanning — Subsystem and Repository Boundary](Subsystem_and_Repository_Boundary.md) before changing this system.

The controlling rule is:

**Repository location is not subsystem ownership.**

Three separate engineering boundaries are involved:

```text
Labeling and Scanning subsystem
    = cross-system label / QR / barcode / scanner / scan contract

MSB Production Database
    = authoritative database records and database-hosted implementation

MSB Label Print Service / PRINT-SERVER
    = external physical-printing runtime and Brother implementation
```

The Labeling and Scanning documentation currently lives inside `Gregovate/MSB-Production-Database-Project`, but the subsystem is not synonymous with the database project.

## Reconciled Repository Baselines

The baseline for this work is:

```text
MSB-Production-Database-Project
main = e448f7b6fef8381522bd74e9c6ff1d9162ab8613

MSB_LabelPrintService
main = d624420a1a7309fe12a608dd202b106bfe24ac9b
```

Future implementation work must begin from the then-current `main` of each affected repository and re-verify the relevant contract. Do not merge unrelated branch work merely to simplify history.

### Scanner documentation branch

Scanner/Android findings were recorded on:

```text
docs/controller-inventory-v1-review
```

That branch diverged from Production Database `main` and mixed scanner documentation with unrelated Controller Inventory work.

The relevant scanner evidence commit is:

```text
ff948db76ded0d95718cf3dd19415e968458ca04
```

That commit changed only `Scanner_Hardware_and_Tablet_Integration.md`, so the scanner document was selectively reconciled onto this current branch without merging unrelated Controller Inventory files.

### LabelPrintService runtime-hardening branch

Issue `MSB_LabelPrintService#14` and draft PR `#15` remain separate LabelPrintService runtime-hardening work.

Current branch:

```text
agent/runtime-preflight-hardening
```

Its executable preflight/write-path work and controlled acceptance remain unfinished. QR/profile work must not weaken or bypass the final accepted FAILED-batch, queue, spooler-verification, or no-double-print protections.

## Identity Contract Versus Physical Payload

The existing [Asset Identity and Scan Payload Standard](Asset_Identity_and_Scan_Payload_Standard.md) remains authoritative for durable Labeling and Scanning identity/payload rules.

Canonical identities are:

```text
DISP:<display_id>
CONT:<container_id>
LOC:<location_code>
```

Examples:

```text
DISP:323
CONT:216
LOC:RB07-B-01
```

The canonical identity and the literal bytes printed inside a barcode/QR are related but are not the same architectural layer.

The Production Database provides the authoritative underlying keys and records. Labeling and Scanning governs how those durable identities are represented and resolved through physical labels and scan workflows.

## Existing Physical Compatibility Contract

Already-printed Display and Container labels encode full scan URLs such as:

```text
https://db.sheboyganlights.org/scan/DISP/323
https://db.sheboyganlights.org/scan/CONT/216
```

These are deployed physical artifacts and must remain supported.

They must not be mass-reprinted merely to shorten Bluetooth HID input or to align the literal QR content with the canonical `TYPE:KEY` representation.

Scanner field testing established that full URLs decode correctly but are slow for repetitive Bluetooth HID use because the Zebra scanner transmits the value as keyboard characters. That is an input-performance problem, not an identity-resolution failure.

A scanner-side shortening rule such as Zebra ADF/123Scan may eventually transform an existing URL into `DISP:323` or `CONT:216` before HID transmission. Scanner formatting is an optimization at the input boundary; it must not become the only authority for the underlying identity rule.

## Current Scan Input Behavior

Current Git-controlled Scan source is stored in the Production Database repository at:

```text
Scan/directus-extension-scan/src/index.js
```

Its repository location is implementation placement. Its payload-normalization behavior is part of the Labeling and Scanning subsystem contract.

The `/scan/` page accepts either:

- a full `http://` or `https://` URL; or
- a canonical-looking `TYPE:KEY` token.

For a full URL, client logic extracts the URL pathname and navigates to it.

For `TYPE:KEY`, client logic constructs:

```text
/scan/<TYPE>/<KEY>
```

Current source includes Display and Container server routes.

The scanner investigation also proved that:

```text
LOC:RB07-B-01
```

is recognized by the client and navigates to:

```text
/scan/LOC/RB07-B-01
```

but the deployed server does not currently implement `/scan/LOC/:key` and returns `ROUTE_NOT_FOUND`.

Therefore:

```text
LOC token recognition / client routing -> present
LOC end-to-end server workflow         -> not yet implemented/accepted
```

Production Storage Location labels must not be printed merely because client parsing recognizes `LOC:`. The intended Location scan behavior must be implemented and accepted first as a Labeling and Scanning change, with any database implementation handled in the Production Database boundary.

## Current QR Generation — Display

The current production path is:

```text
Production Database record/request state
    -> ref.display.print_label = true
        -> LabelPrintService creates ops.display_label_batch
            -> LabelPrintService-owned sql/display_snapshot.sql executes in PostgreSQL
                -> snapshot SELECT constructs qr_url
                    -> ops.display_label_batch_item.qr_url
                        -> sql/display_export.sql
                            -> service row / debug CSV
                                -> Brother b-PAC
                                    -> LBX objQr.Text
                                        -> physical QR
```

Current URL construction is in `MSB_LabelPrintService/sql/display_snapshot.sql`:

```sql
'https://db.sheboyganlights.org/scan/DISP/' || d.display_id AS qr_url
```

The complete URL is therefore currently constructed by a LabelPrintService-owned SQL expression executed against PostgreSQL at batch-snapshot time.

It is not generated by the Scan resolver and is not generated by the LBX template.

Display human-readable text is independently snapshot as `line1` and `line2`.

## Current QR Generation — Container

The current production path is equivalent but separate:

```text
Production Database record/request state
    -> ref.container.print_label = true
        -> LabelPrintService creates ops.container_label_batch
            -> LabelPrintService-owned sql/container_snapshot.sql executes in PostgreSQL
                -> snapshot SELECT constructs qr_url
                    -> ops.container_label_batch_item.qr_url
                        -> orientation-specific export
                            -> service row / debug CSV
                                -> Brother b-PAC
                                    -> LBX objQr.Text
                                        -> physical QR
```

Current URL construction is:

```sql
'https://db.sheboyganlights.org/scan/CONT/' || c.container_id AS qr_url
```

The visible Container label is separately snapshot as a human value such as `C216`.

Display and Container URL construction therefore do not currently share a common QR/payload helper. Two separate LabelPrintService snapshot SQL files duplicate the URL convention.

That duplication is an implementation detail. Any future change to the logical payload convention must first be reviewed as a Labeling and Scanning contract change.

## What the Brother Print Service Receives

Current `label_poll_service_v3.py` does not derive the asset identity or build the browser URL during rendering.

It receives batch-export rows containing already-computed fields.

For Displays it assigns:

```text
objLine1.Text <- line1
objLine2.Text <- line2, when the object exists
objQr.Text    <- qr_url
```

For Containers it assigns:

```text
objContainerLabel.Text <- container_label
objQr.Text              <- qr_url
```

Human-readable and machine-readable fields are already independent. This is an important existing capability and should be preserved.

The current `.lbx` templates consume named objects; they do not need to own semantic construction of the payload.

## Current Storage Location Print State

Location/rack test templates exist in the LabelPrintService repository, including QL-820NWB experiments, but current v3.4 production polling/configuration processes Displays and Containers only.

There is no accepted production Location batch/snapshot/render path in current LabelPrintService `main`.

Storage Location labels have not yet been printed, so there is no deployed Location-label full-URL compatibility population.

That leaves future Location labels free to use the compact canonical payload direction, subject to:

- Labeling and Scanning contract approval;
- accepted `/scan/LOC/:key` behavior;
- database implementation where required;
- LabelPrintService implementation;
- physical range testing.

## Current Template and Printer Assignment State

Current LabelPrintService configuration has one Windows printer name and explicit template paths for:

- Display;
- Container vertical;
- Container horizontal.

The runtime code selects these configuration values directly.

That works for the current production footprint but does not scale cleanly to:

- current 36 mm Display labels;
- future narrower Display labels;
- future 12 mm FieldWiring labels;
- larger QL-820NWB Location/rack labels;
- future symbology or rendering variants.

No governed `label_profile` or `printer_role` entity was found in the current Production Database implementation during this reconciliation.

Raw local template filenames, Windows printer queue names, or `C:\...` runtime paths must not be added directly to `ref.display` as the solution.

## Proposed Governed Label-Profile Boundary

A governed label-profile model is the appropriate direction, but its final DDL is not approved by this document.

The ownership is deliberately split.

### Labeling and Scanning responsibility

Labeling and Scanning defines the logical profile contract, including concepts such as:

- label class/purpose;
- media family or nominal width;
- layout role/version;
- machine-readable symbology policy;
- machine-payload policy where multiple compatibility modes are intentionally supported;
- human-text layout policy;
- logical printer capability role;
- active/default behavior at the contract level.

### Production Database implementation responsibility

If PostgreSQL is the approved implementation location, the Production Database may store a governed profile entity, for example conceptually:

```text
ref.label_profile
```

and references/default assignments from Display, Container, Location, Wiring, or other governed entities/workflows.

The eventual DDL, key type, FK structure, audit fields, defaulting rules, assignment location, and history behavior are Production Database implementation/governance concerns and require separate review.

A PostgreSQL table implementing the contract does not transfer ownership of the overall label-profile system from Labeling and Scanning to the database project.

### LabelPrintService runtime responsibility

LabelPrintService maps the approved logical profile to machine-specific facts such as:

- actual `.lbx` file path;
- actual Windows printer queue;
- exact media dimensions;
- b-PAC object names;
- native-barcode versus raster-image renderer;
- printer-specific preflight requirements.

The boundary is:

```text
Labeling and Scanning profile contract
    = what the logical label must be and do

Production Database implementation
    = stores governed profile identity/assignment and request state

LabelPrintService runtime mapping
    = how PRINT-SERVER physically renders that approved profile
```

## Existing Display Default Direction

Existing Displays should use the current 36 mm PT-P950NW two-line logical profile by default unless deliberately assigned another approved profile.

Future narrower Display labels can use a separate governed profile without adding raw template paths to each Display row.

Future FieldWiring 12 mm labels and QL-820NWB Location/rack labels should likewise be separate governed logical profiles/capability roles rather than new hard-coded branches scattered through the service.

The exact profile keys/names are intentionally not standardized here before contract, schema, and runtime review.

## Print Snapshot Requirement for Profiles

When profiles are implemented, a print batch should snapshot enough resolved information to reproduce what was requested even if the asset's default profile changes later.

At minimum the batch contract should preserve:

- effective logical profile identity;
- actual human-readable text submitted;
- actual machine-readable payload submitted;
- other profile/version information necessary to identify what was requested.

This extends the existing snapshot-batch principle and must not bypass current duplicate-prevention and FAILED-batch protections.

## Responsibility Summary

### Labeling and Scanning owns/governs

- label/scan identity and payload conventions;
- deployed-label compatibility requirements;
- QR/barcode logical requirements;
- logical label-profile contract;
- scan input normalization expectations;
- scanner/tablet acceptance requirements;
- cross-system integration behavior among database, Scan, and print service.

### Production Database owns/implements

- authoritative Display, Container, Location, and related records/keys;
- PostgreSQL schema and database relationships;
- print-request/batch/history/audit state stored in PostgreSQL;
- database-side implementation of an approved label-profile model;
- Git-controlled Scan source currently stored with the database project;
- database queries used by Scan and printing integrations.

It does not own PRINT-SERVER local paths, Brother templates, Windows printer names, or b-PAC implementation.

### LabelPrintService owns/implements

- logical-profile-to-runtime mapping;
- templates and printer-specific rendering;
- b-PAC interaction;
- local image generation when an approved profile requires it;
- media/printer/runtime preflight;
- spooler verification;
- FAILED-batch/no-double-print safety behavior;
- service-specific logs and recovery.

It must not become a second authority for asset identity, profile policy, or browser business routing.

### Scan implementation

The Scan application currently lives in the Production Database repository but implements Labeling and Scanning behavior.

It owns runtime behavior for:

- accepting supported physical/input transport forms;
- normalizing them to the same durable identity/path;
- routing resolved identities into appropriate task hubs/workflows.

It must continue to accept already-deployed full Display/Container URLs.

### Scanner

The scanner owns capture and input transport only.

Scanner ADF may optimize what is typed over HID, but scanner formatting must not become the only place an asset identity or business rule exists.

## New Display/Container Payload Direction

The Labeling and Scanning architecture permits a future transition of newly printed Display/Container labels from full URLs to compact canonical payloads without invalidating old labels.

This reconnaissance does not approve that transition yet.

Until compact-payload printing and scan regression are explicitly accepted, new Display/Container prints should preserve the current full-URL production behavior.

A later accepted logical profile/version may select canonical `DISP:<id>` or `CONT:<id>` for newly printed labels while Scan continues to accept old full URLs indefinitely.

## QR Density Analysis

The deployed example URL:

```text
https://db.sheboyganlights.org/scan/DISP/323
```

is 44 ASCII bytes.

The Container example with a three-digit ID is also 44 bytes.

The URL contains lowercase characters, so it cannot be represented entirely in QR alphanumeric mode. Using QR Code Model 2 byte capacities, the minimum versions for the 44-byte URL are:

| Error correction | Minimum version | Modules |
|---|---:|---:|
| L | 3 | 29 x 29 |
| M | 4 | 33 x 33 |
| Q | 4 | 33 x 33 |
| H | 5 | 37 x 37 |

Therefore QR Version 2 is not sufficient for the current full URL at any error-correction level.

By comparison:

```text
DISP:323  -> 8 alphanumeric characters
CONT:216  -> 8 alphanumeric characters
```

Both fit QR Version 1 even at error-correction level H.

```text
LOC:RB07-B-01 -> 13 alphanumeric characters
```

That fits Version 1 at L/M/Q; H requires Version 2.

This is one concrete reason compact canonical payloads are attractive for physically large, easy-to-acquire labels.

QR version/capacity and quiet-zone requirements must be verified against the current DENSO WAVE QR Code reference before final renderer acceptance.

## Large Physical QR / Raster Rendering Feasibility

Current production LBX templates use a native Brother barcode/QR object populated through `objQr.Text`.

The observed Brother Editor behavior—changing QR version as the object is enlarged—makes it difficult to use a deliberately low-version QR rendered very large for distance scanning.

Brother b-PAC supports application replacement of image/graphics objects. Brother documents `IObject::SetData()` for b-PAC 3.x, with older b-PAC specifications documenting the equivalent `ReplaceImageFile()` behavior and common lossless image formats including BMP.

That makes this LabelPrintService implementation direction technically feasible and worth an isolated proof-of-concept once the Labeling and Scanning logical profile is approved:

```text
approved machine payload
    -> LabelPrintService QR encoder
        -> explicit version + ECC + quiet zone
            -> lossless raster image
                -> named image object in LBX template
                    -> b-PAC image replacement
                        -> printer
```

This is not yet production-approved.

Before adoption, verify on the actual PRINT-SERVER:

- installed b-PAC version and Python COM signature;
- image replacement behavior with the current SDK;
- QL-820NWB and PT-P950NW template/image handling as applicable;
- exact raster DPI/module scaling;
- required four-module quiet zone;
- error-correction choice for the physical environment;
- scan performance at actual forklift/rack distance;
- temporary image lifecycle and cleanup;
- preflight/failure behavior without weakening current batch safety.

## Documentation Conflicts Identified

Current documentation contains implementation-state conflicts that must remain visible until reconciled:

1. `Label_Creation_and_Printing.md` describes Storage Locations as part of current asset label scope, while LabelPrintService v3.4 current `main` only has production polling/render paths for Displays and Containers.
2. The previous current-main scanner hardware document predated the 2026-08-27 Android/Bluetooth field findings. Those findings have now been selectively reconciled onto this branch without the unrelated Controller Inventory work.
3. LabelPrintService root `readme.md` names an older production/main baseline even though repository `main` has advanced.
4. LabelPrintService engineering documentation contains historical manual-start/office-workstation assumptions superseded by current PRINT-SERVER runtime acceptance.
5. Template copies exist in multiple LabelPrintService locations. Issue #14 identifies `templates/pt_p950nw/` and `templates/ql_820nwb/` as the accepted source-layout direction while temporary duplicates remain for transition safety.
6. Earlier QR/profile wording blurred the Labeling and Scanning subsystem with the Production Database repository. [Subsystem and Repository Boundary](Subsystem_and_Repository_Boundary.md) is now the controlling clarification.

Do not delete historical/temporary copies merely to make the tree look cleaner. Reconcile authority and runtime paths first.

## Implementation Gates

Before production implementation from this architecture:

1. Read [Subsystem and Repository Boundary](Subsystem_and_Repository_Boundary.md) and identify which boundary owns each proposed change.
2. Re-verify every affected repository against then-current `main`.
3. Complete/close or deliberately coordinate with LabelPrintService Issue #14/PR #15 so profile work does not bypass runtime preflight hardening.
4. Verify the actual current PostgreSQL schema; do not derive new DDL from stale development DDL files.
5. Define and review the logical Labeling and Scanning label-profile contract.
6. Separately design the Production Database schema implementation for the approved profile contract.
7. Define the initial profile/default matrix for current Display, Container, future narrow Display, Wiring 12 mm, and Location/QL labels.
8. Implement and accept intended `/scan/LOC/:key` behavior before printing production Location labels.
9. If changing newly printed Display/Container payloads, run explicit old-full-URL plus new-canonical regression tests before approval.
10. Prove raster QR image replacement in a non-production LabelPrintService template/test path before adding it to production rendering.
11. Range-test the final Location/rack label with the accepted extended-range scanner from the actual forklift position.
12. Preserve all current batch failure, queue, spooler, and no-double-print safeguards.
13. Update documentation in each repository/boundary actually changed; do not leave a cross-system decision documented only in one implementation repository.

## Current Stop Point

The current state is architecture documented; implementation not started.

No production schema, QR payload, Scan route, LabelPrintService executable, printer configuration, or physical label population was changed by this reconciliation.

## Related Documents

- [Labeling and Scanning](README.md)
- [Labeling and Scanning — Subsystem and Repository Boundary](Subsystem_and_Repository_Boundary.md)
- [Asset Identity and Scan Payload Standard](Asset_Identity_and_Scan_Payload_Standard.md)
- [Label Creation and Printing](Label_Creation_and_Printing.md)
- [Scanner Hardware and Tablet Integration](Scanner_Hardware_and_Tablet_Integration.md)
- [Scan Workflows and Forklift Operations](Scan_Workflows_and_Forklift_Operations.md)
- [FieldWiring Channel / Plug Label Printing Requirements](../09_Wiring_System/FieldWiring_Channel_Plug_Label_Printing_Requirements.md)
