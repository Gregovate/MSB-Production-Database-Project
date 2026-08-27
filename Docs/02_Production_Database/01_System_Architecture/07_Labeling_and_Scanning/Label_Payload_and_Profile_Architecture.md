# Label Payload and Profile Architecture

| Document control | Value |
|---|---|
| Status | DRAFT — ENGINEERING RECONNAISSANCE BASELINE |
| Revision | 2026-08-27 |
| Owner | MSB Production Database engineering |
| Scope | Label payload generation, scan compatibility, label-profile boundary, and LabelPrintService integration |

## Purpose

This document records the reconciled current state of MSB label payload generation and defines the proposed engineering boundary for future label-profile work.

This is a reconnaissance and contract-definition document. It does **not** authorize a PostgreSQL schema change, QR payload migration, Scan resolver redesign, production-template replacement, or LabelPrintService code change.

## Reconciled Repository Baselines

The baseline for this work is:

```text
MSB-Production-Database-Project
main = e448f7b6fef8381522bd74e9c6ff1d9162ab8613

MSB_LabelPrintService
main = d624420a1a7309fe12a608dd202b106bfe24ac9b
```

Future implementation work for this contract must begin from the then-current `main`, re-verify these findings, and preserve unrelated branch work rather than merging branches solely to simplify history.

### Scanner documentation branch

Scanner/Android findings are currently carried on:

```text
docs/controller-inventory-v1-review
```

The branch is diverged from Production Database `main` and contains both the updated scanner document and unrelated Controller Inventory work. It must **not** be merged wholesale for this label/scan project.

The relevant scanner evidence includes commit:

```text
ff948db76ded0d95718cf3dd19415e968458ca04
```

The field findings from that branch are incorporated into this architecture contract where they affect payload compatibility. Scanner-hardware documentation should be selectively reconciled onto a current branch rather than importing unrelated Controller Inventory files.

### LabelPrintService runtime-hardening branch

Issue `MSB_LabelPrintService#14` and draft PR `#15` remain separate runtime-hardening work.

Current branch:

```text
agent/runtime-preflight-hardening
```

At this reconciliation point it is based on current LabelPrintService `main`; its remaining branch delta is configuration/recovery documentation. PR #15 explicitly remains incomplete because service-code preflight/write-path changes and acceptance testing are still pending.

QR/profile work must not weaken or bypass that project's FAILED-batch, queue, spooler-verification, or no-double-print safety behavior.

## Identity Contract Versus Physical Payload

The existing [Asset Identity and Scan Payload Standard](Asset_Identity_and_Scan_Payload_Standard.md) remains authoritative for durable identity.

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

The canonical identity and the literal bytes printed inside a barcode/QR are related but are **not the same architectural layer**.

A physical label may carry a transport form that resolves to the same canonical identity. Existing Display and Container labels are the important deployed example.

## Existing Physical Compatibility Contract

Already-printed Display and Container labels encode full scan URLs such as:

```text
https://db.sheboyganlights.org/scan/DISP/323
https://db.sheboyganlights.org/scan/CONT/216
```

These are deployed physical artifacts and must remain supported.

They must not be mass-reprinted merely to shorten Bluetooth HID input or to align the literal QR content with the canonical `TYPE:KEY` representation.

Current scanner field testing established that the full URLs are decoded correctly but are slow for repetitive Bluetooth HID use because the Zebra scanner transmits the value as keyboard characters. That is an input-performance problem, not an identity-resolution failure.

A scanner-side shortening rule such as Zebra ADF/123Scan may eventually transform an existing URL into `DISP:323` or `CONT:216` before HID transmission, but that remains a scanner-configuration acceptance item and must not become the business identity authority.

## Current Scan Input Behavior

Current Git-controlled Scan source is:

```text
Scan/directus-extension-scan/src/index.js
```

The `/scan/` page accepts either:

- a full `http://` or `https://` URL; or
- a canonical-looking `TYPE:KEY` token.

For a full URL, client logic extracts the URL pathname and navigates to it.

For `TYPE:KEY`, client logic constructs:

```text
/scan/<TYPE>/<KEY>
```

Current source includes Display and Container server routes. The scanner investigation also proved that `LOC:RB07-B-01` is recognized by the client and navigates to `/scan/LOC/RB07-B-01`, but the deployed server does not currently implement `/scan/LOC/:key` and returns `ROUTE_NOT_FOUND`.

Therefore:

```text
LOC token recognition / client routing -> present
LOC end-to-end server workflow         -> not yet implemented/accepted
```

Production Storage Location labels must not be printed merely because client parsing recognizes `LOC:`. The intended Location scan behavior must be implemented and accepted first.

## Current QR Generation — Display

The current production path is:

```text
ref.display.print_label = true
    -> LabelPrintService creates ops.display_label_batch
    -> sql/display_snapshot.sql executes in PostgreSQL
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

The complete URL is therefore currently constructed by a SQL expression executed in PostgreSQL at batch-snapshot time. It is not generated by the Scan resolver and is not generated by the LBX template.

Display human-readable text is independently snapshot as `line1` and `line2`.

## Current QR Generation — Container

The current production path is equivalent but separate:

```text
ref.container.print_label = true
    -> LabelPrintService creates ops.container_label_batch
    -> sql/container_snapshot.sql executes in PostgreSQL
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

Display and Container URL construction therefore do **not** currently share a common QR/payload helper. The two service-owned SQL snapshot files duplicate the URL convention.

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

The human-readable and machine-readable fields are already independent. This is an important existing capability and should be preserved.

The current `.lbx` templates therefore consume named objects; they do not need to own the semantic construction of the payload.

## Current Storage Location Print State

Location/rack test templates exist in the LabelPrintService repository, including QL-820NWB experiments, but current v3.4 production polling/configuration processes **Displays and Containers only**.

There is no accepted production Location batch/snapshot/render path in current `main`.

Storage Location labels have not yet been printed, so there is no deployed Location-label full-URL compatibility population.

This leaves the future Location label free to use the compact canonical payload direction, subject to end-to-end Location scan acceptance and physical range testing.

## Current Template and Printer Assignment State

Current LabelPrintService configuration has one Windows printer name and explicit template paths for:

- Display;
- Container vertical;
- Container horizontal.

The runtime code selects these configuration values directly.

This is workable for the existing single-printer/small-template set, but it does not scale cleanly to:

- current 36 mm Display labels;
- future narrower Display labels;
- 12 mm FieldWiring labels;
- larger QL-820NWB Location/rack labels;
- future symbology or rendering variants.

No governed `label_profile` or `printer_role` entity was found in the current Production Database repository during this reconciliation.

Raw local template filenames, Windows printer queue names, or `C:\...` runtime paths must not be added directly to `ref.display` as the solution.

## Proposed Governed Label-Profile Boundary

A governed label-profile model is the appropriate direction, but its final DDL is **not approved by this document**.

The likely Production Database concept is a governed profile entity, for example `ref.label_profile`, with a stable database key and an application-facing profile key. Existing/future business entities may reference the governed profile rather than storing printer implementation details.

Conceptually a profile needs to describe the **logical output contract**, not the local Windows runtime:

- label class/purpose;
- media family or nominal width;
- layout role/version;
- machine-readable symbology policy;
- machine-payload policy where multiple compatibility modes are intentionally supported;
- human-text layout policy;
- logical printer capability role;
- active/default state.

The eventual DDL, key type, defaulting rules, assignment location, and history behavior must be reviewed against current Production Database governance before implementation.

### Runtime mapping remains outside asset tables

LabelPrintService should map the governed logical profile to machine-specific facts such as:

- actual `.lbx` file path;
- actual Windows printer queue;
- exact media dimensions;
- b-PAC object names;
- native-barcode versus raster-image renderer;
- printer-specific preflight requirements.

This preserves a clean boundary:

```text
Production Database profile
    = what label contract is required

LabelPrintService runtime mapping
    = how this Windows print host renders that contract
```

## Existing Display Default Direction

Existing Displays should default to the current 36 mm PT-P950NW two-line profile unless deliberately assigned another approved profile.

Future narrower Display labels can use a separate governed profile without adding raw template paths to each Display row.

Likewise, future FieldWiring 12 mm labels and QL-820NWB Location/rack labels should be separate profiles/capability roles rather than new hard-coded branches scattered through the service.

The exact profile keys/names are intentionally not standardized here before schema and runtime review.

## Print Snapshot Requirement for Profiles

When profiles are implemented, a print batch should snapshot enough resolved information to reproduce what was requested even if the asset's default profile changes later.

At minimum the batch contract should preserve the effective logical profile identity and the actual human/machine payload values that were submitted for that print attempt.

This extends the existing snapshot-batch principle; it must not bypass current duplicate-prevention and FAILED-batch protections.

## Proposed Responsibility Boundaries

### Production Database

Owns:

- permanent asset/location identity;
- canonical `TYPE:KEY` rules;
- governed logical label-profile assignment/defaults;
- print request and auditable batch contract;
- effective machine payload selected for a new print request.

Does not own:

- PRINT-SERVER local filesystem paths;
- Windows printer queue names;
- Brother COM object names.

### LabelPrintService

Owns:

- logical-profile-to-runtime mapping;
- templates and printer-specific rendering;
- b-PAC interaction;
- local image generation when an approved profile requires it;
- media/printer/runtime preflight;
- spooler verification;
- FAILED-batch/no-double-print safety behavior;
- service-specific logs and recovery.

It should not become a second authority for asset identity or browser business routing.

### Scan application

Owns:

- accepting supported physical/input transport forms;
- normalizing them into the same durable asset identity/path;
- routing the resolved identity into the appropriate task hub/workflow.

It must continue to accept the already-deployed full Display/Container URLs.

### Scanner

Owns capture and input transport only.

Scanner ADF may optimize what is typed over HID, but scanner formatting must not become the only place an asset identity or business rule exists.

## New Display/Container Payload Direction

The architecture permits a future transition of newly printed Display/Container labels from full URLs to compact canonical payloads without invalidating old labels.

However, this reconnaissance does **not** approve that transition yet.

Until a compact-payload printing and scan regression is explicitly accepted, new Display/Container prints should preserve the current full-URL production behavior. That avoids changing an established physical contract during unrelated profile work.

A later accepted profile/version may select canonical `DISP:<id>` or `CONT:<id>` for newly printed labels while the Scan application continues to accept old full URLs indefinitely.

## QR Density Analysis

The example deployed full URL:

```text
https://db.sheboyganlights.org/scan/DISP/323
```

is 44 ASCII bytes. The Container example with a three-digit ID is also 44 bytes.

The URL contains lowercase characters, so it cannot be represented entirely in QR alphanumeric mode. Using the QR Code Model 2 capacity rules, the minimum versions for the 44-byte URL are:

| Error correction | Minimum version | Modules |
|---|---:|---:|
| L | 3 | 29 x 29 |
| M | 4 | 33 x 33 |
| Q | 4 | 33 x 33 |
| H | 5 | 37 x 37 |

Therefore **QR Version 2 is not sufficient for the current full URL at any error-correction level**.

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

QR Code version/capacity and quiet-zone requirements should be verified against the current DENSO WAVE QR Code reference before final renderer acceptance:

- https://www.qrcode.com/en/about/version.html
- https://www.qrcode.com/en/howto/code.html

## Large Physical QR / Raster Rendering Feasibility

Current production LBX templates use a native Brother barcode/QR object populated through `objQr.Text`.

The observed Brother Editor behavior—changing QR version as the object is enlarged—makes it difficult to use a deliberately low-version QR rendered very large for distance scanning.

Brother b-PAC supports replacing an image/graphics object from application code. Brother's b-PAC FAQ documents `IObject::SetData()` for b-PAC 3.x, including an option to preserve aspect ratio; older b-PAC specifications document the equivalent `ReplaceImageFile()` behavior and support BMP among the accepted image formats.

Relevant Brother reference:

- https://support.brother.com/g/s/es/dev/en/bpac/faq/index.html

This makes the following architecture **technically feasible** and worth an isolated proof-of-concept:

```text
machine payload
    -> service QR encoder
        -> explicit version + ECC + quiet zone
            -> lossless raster image, preferably BMP for b-PAC compatibility
                -> named image object in LBX template
                    -> b-PAC SetData()/verified equivalent
                        -> printer
```

That would allow the physical image object to be enlarged without asking Brother's native QR object to recalculate the QR symbol version.

This is not yet a production-approved implementation. Before adoption, verify on the actual PRINT-SERVER:

- installed b-PAC version and Python COM signature;
- image replacement behavior with the current SDK;
- QL-820NWB and PT-P950NW template/image handling as applicable;
- exact raster DPI/module scaling;
- required four-module quiet zone;
- error-correction choice for the physical environment;
- scan performance at the actual forklift/rack distance;
- temporary image lifecycle and cleanup;
- preflight/failure behavior without weakening current batch safety.

## Documentation Conflicts Identified

Current documentation contains several implementation-state conflicts that must remain visible until reconciled:

1. `Label_Creation_and_Printing.md` describes Storage Locations as part of current asset label scope, but LabelPrintService v3.4 current `main` only has production polling/render paths for Displays and Containers.
2. The current-main scanner hardware document predates the 2026-08-27 Android/Bluetooth field findings, while the newer evidence is mixed into `docs/controller-inventory-v1-review` with unrelated Controller Inventory work.
3. LabelPrintService root `readme.md` still names an older production/main baseline even though repository `main` has advanced.
4. LabelPrintService engineering documentation includes historical manual-start/office-workstation assumptions superseded by current PRINT-SERVER runtime acceptance.
5. Template copies exist in multiple LabelPrintService locations. Issue #14 identifies `templates/pt_p950nw/` and `templates/ql_820nwb/` as the accepted source-layout direction, while duplicate documentation/template copies remain temporarily for transition safety.

Do not delete historical/temporary copies merely to make the tree look cleaner. Reconcile authority first and remove duplicates only after runtime path acceptance.

## Implementation Gates

Before any production implementation from this architecture:

1. Re-verify both repositories against then-current `main`.
2. Complete/close or deliberately coordinate with LabelPrintService Issue #14/PR #15 so profile work does not bypass runtime preflight hardening.
3. Verify the actual current PostgreSQL schema; do not derive new DDL from stale development DDL files.
4. Define and review the governed label-profile schema separately.
5. Decide the initial profile/default matrix for current Display, Container, future narrow Display, Wiring 12 mm, and Location/QL labels.
6. Implement/accept the intended `/scan/LOC/:key` workflow before printing production Location labels.
7. If changing newly printed Display/Container payloads, run explicit old-full-URL plus new-canonical regression tests before approval.
8. Prove raster QR image replacement in a non-production template/test path before adding it to production rendering.
9. Range-test the final Location/rack label with the accepted extended-range scanner from the actual forklift position.
10. Preserve all current batch failure, queue, spooler, and no-double-print safeguards.

## Current Stop Point

The current state is **architecture documented; implementation not started**.

No production schema, QR payload, Scan route, LabelPrintService executable, printer configuration, or physical label population was changed by this reconciliation.

## Related Documents

- [Labeling and Scanning](README.md)
- [Asset Identity and Scan Payload Standard](Asset_Identity_and_Scan_Payload_Standard.md)
- [Label Creation and Printing](Label_Creation_and_Printing.md)
- [Scanner Hardware and Tablet Integration](Scanner_Hardware_and_Tablet_Integration.md)
- [Scan Workflows and Forklift Operations](Scan_Workflows_and_Forklift_Operations.md)
- [FieldWiring Channel / Plug Label Printing Requirements](../09_Wiring_System/FieldWiring_Channel_Plug_Label_Printing_Requirements.md)
