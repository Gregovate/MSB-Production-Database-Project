# Controller Label Print-Service Integration

| Document Control | Value |
|---|---|
| Document Type | Engineering integration contract |
| System | Controller Inventory / LabelPrintService |
| Status | DRAFT — database batch migration and V4 consumer require deployment acceptance |
| Owner | Production Database administrator / LabelPrintService maintainer |
| Last Reviewed | 2026-09-03 |
| Production Request Command | `ref.request_controller_label(text, bigint)` |
| Candidate Database Migration | `Controllers/Database/025_create_controller_label_print_batches.sql` |
| Downstream Issue | `Gregovate/MSB_LabelPrintService#14` |

## Purpose

This document defines the database half of permanent Controller label printing.
The Controller browser already creates an authorized request. The missing work
is the durable execution-batch contract and the LabelPrintService V4 consumer.

## Current Production Request

The deployed browser calls:

```sql
ref.request_controller_label(p_email, p_controller_id)
```

That command authorizes the current user and sets:

```text
ref.controller.print_label = true
```

Repeated requests are idempotent while the flag is already true. The browser
does not print and does not receive physical printer feedback.

## Permanent Identity and Payload

```text
Visible label text: CTRL:<controller_id>
Printed QR payload: https://db.sheboyganlights.org/scan/CTRL/<controller_id>
Physical family:    QR_24MM_HORIZONTAL
Printer/media:      PT-P950NW / 24 mm laminated tape
```

The full URL and compact `CTRL:` form both resolve to Controller Inventory.
Mutable Controller programming, Display assignments, firmware, and location are
not part of permanent label identity.

## Candidate Execution-Batch Schema

Migration `Controllers/Database/025_create_controller_label_print_batches.sql`
adds:

```text
ops.controller_label_batch
ops.controller_label_batch_item
```

The migration also:

- assigns existing Controllers to the governed `QR_24MM_HORIZONTAL` catalog row
  when `label_template_id` is null;
- sets that catalog ID as the default for newly created Controllers;
- grants `printservice` only the Controller read/finalization access needed by
  the polling service plus batch-table/sequence access;
- constrains frozen `line1` and `qr_url` values to the accepted Controller
  identity formats.

The batch item is the immutable physical render snapshot. It contains the exact
Controller ID, full QR URL, visible `CTRL:` text, and physical completion state.

## Required Transaction Boundary

The downstream service must follow this sequence:

1. read pending `ref.controller.print_label` rows;
2. validate every row resolves to `QR_24MM_HORIZONTAL`;
3. complete printer, media, template, runtime-path, and queue preflight;
4. lock the exact pending Controller rows and verify the workload did not change;
5. create and commit the batch header/items;
6. print the frozen rows;
7. after confirmed success, clear only Controller requests present in that batch
   and update their cached print summary;
8. mark a failed physical batch `FAILED` without clearing its requests.

A failed preflight creates no execution batch. A request that arrives after the
snapshot remains pending for a later batch.

## Activation Gate

Controller polling must remain disabled in LabelPrintService until all of the
following are true:

- migration `025` has been reviewed and installed;
- migration validation reports zero Controllers without an assigned template;
- `printservice` permission checks pass;
- the previously documented pending Controller `1001` request is inspected and
  deliberately cleared or selected as the controlled physical test;
- the V4 consumer is installed with its feature flag still off;
- 24 mm laminated tape is intentionally loaded for the controlled test.

Do not enable the consumer merely because the code exists in a draft branch.

## Ownership Boundary

The Production Database owns Controller identity, request state, label-family
assignment, execution-batch history, and targeted finalization. LabelPrintService
owns polling, local LBX selection, Brother preflight, b-PAC rendering, Windows
spooler observation, physical execution logs, and restart/no-double-print
behavior.

## Related Documents

- [Controller Inventory](README.md)
- [Label Payload and Profile Architecture](../07_Labeling_and_Scanning/Label_Payload_and_Profile_Architecture.md)
- [Controller Management Authentication / Authorization Contract](Controller_Management_Authentication_Authorization_Contract_2026-08-31.md)
