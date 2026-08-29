# MSB Label Creation and Printing

| Document control | Value |
|---|---|
| Status | CURRENT ENGINEERING REFERENCE — SETUP HARDENING IN PROGRESS |
| Revision | 2026-08-28 |
| Owner | Labeling and Scanning subsystem |
| Purpose | Define current label creation/printing behavior and the accepted Setup-hardening direction without overstating unaccepted printer work. |

## 1. Purpose

This document defines the engineering requirements and current implementation boundary for creating and printing asset and controlled operational labels for MSB operations.

It covers:

- which records/workflows currently receive labels;
- how labels are requested and generated;
- quantity rules;
- template selection;
- print-job tracking;
- duplicate prevention;
- reprints and failure recovery; and
- printer integration.

Operator instructions remain in the separate Operational SOP tree. Brother/Windows runtime implementation belongs to the separate `MSB_LabelPrintService` repository.

## 2. Current Production Scope

Current production LabelPrintService v3.4 prints:

- Display labels; and
- Container labels.

Storage Location/rack labels are **not** a current production printing capability. Location test templates exist, but the final Location label, accepted `LOC:` scan route behavior, QL-820NWB readiness/media-out behavior, and extended-range scanner acceptance are still pending.

Controller labeling remains part of the Controller Inventory subsystem and uses the shared identity/label conventions where applicable.

FieldWiring also requires a future **Channel / Plug label class**. Those are configuration/hookup labels derived from current wiring Channel Names; they are not permanent asset-identity labels.

See [FieldWiring Channel / Plug Label Printing Requirements](../09_Wiring_System/FieldWiring_Channel_Plug_Label_Printing_Requirements.md).

## 3. Current Operator Request Path

The current production request path is intentionally simple:

```text
Directus
    -> operator filters/selects Display or Container rows
    -> sets Print Label = true
    -> saves

PostgreSQL
    -> ref.display.print_label / ref.container.print_label

LabelPrintService v3.4
    -> polls PostgreSQL every 15 seconds
    -> performs current safety checks
    -> creates snapshot batch
    -> renders/prints through Brother b-PAC
    -> verifies the Windows print queue
    -> finalizes the batch and clears only successfully processed flags
```

There is no database trigger that starts printing. The polling LabelPrintService is the execution mechanism.

For Setup preparation, the existing boolean request path remains accepted. A future dedicated Label Printing application may improve selection/status UX, but it is not required before the current print system is hardened.

## 4. Core Requirements

The label system must support selected-item and batch printing, durable labels, intentional reprints, clear failure handling, and a simple volunteer-facing workflow.

Manual CSV export, hand-keying label text into printer software, selecting Windows printers, selecting `.lbx` files, or understanding PRINT-SERVER paths are not normal operator responsibilities.

The operator should identify the required label format/size. LabelPrintService is responsible for determining how that approved format is physically rendered and whether the required printer/media is ready.

## 5. Printer Hardware Boundary

### Current production printer

The established production printer for laminated Display and Container labels is the Brother PT-P950NW using laminated P-touch media.

Confirmed Display sizes required for Setup are:

- 36 mm laminated — current standard Display identity label; and
- 24 mm laminated — narrower Display identity label for Displays that require the smaller format.

Existing Displays will use 36 mm unless deliberately assigned the 24 mm format after the Display relationship is implemented.

### QL-820NWB

A Brother QL-820NWB is available and can receive print jobs, but it is **not yet an accepted production Location-label path**.

Before Location printing becomes production scope, engineering must establish:

- the final Location label design;
- the final Location media;
- QL-820NWB readiness/status behavior;
- paper/media-out behavior;
- the final Location payload and `/scan/LOC/:key` behavior; and
- physical range acceptance with the extended-range scanner.

Do not assume a QL printer can print laminated P-touch labels. Display/Container laminated media requirements must never be silently routed to a QL-820NWB.

## 6. Machine-Readable Identity

Canonical permanent identities are based on the `TYPE:KEY` convention:

```text
DISP:<display_id>
CONT:<container_id>
LOC:<location_code>
```

Existing physically deployed Display and Container labels currently encode full scan URLs such as:

```text
https://db.sheboyganlights.org/scan/DISP/323
https://db.sheboyganlights.org/scan/CONT/216
```

Those labels remain supported physical artifacts and are not candidates for mass replacement merely to shorten their payload.

Current Scan input accepts both the deployed full URLs and compact forms such as:

```text
DISP:323
CONT:216
```

Bluetooth HID testing established that transmitting the full URL character-by-character to the Android tablet is materially slower than transmitting the compact token. The Setup-hardening work may therefore move **new/replacement** Display and Container labels to compact payloads after regression/physical acceptance while preserving old full-URL compatibility indefinitely.

Storage Location labels have not yet been deployed, so they do not inherit a full-URL compatibility population.

## 7. Quantity Rules

- Containers: 2 labels by default so identification remains visible regardless of storage orientation.
- Displays: 1 label by default.
- Storage Locations: future production rule expected to be 1 label by default, subject to final design acceptance.
- Controllers: quantity and final layout belong to the Controller Inventory subsystem.
- FieldWiring Channel / Plug labels: quantity comes from the selected physical hookup/lead set; no hard-coded global quantity rule is established yet.

The implementation should enforce established quantity rules rather than relying on operators to remember them.

## 8. Label Content

Each permanent asset label should contain a human-readable identifier and the appropriate machine-readable barcode or QR code, with sufficient contrast, size, and durability for its operating environment.

Display human-readable line splitting remains independent of the QR payload.

FieldWiring Channel / Plug labels use the current approved **Channel Name** as the essential printed text. Their 12 mm template, text fitting, and physical acceptance remain future FieldWiring/LabelPrintService work.

Normal operators must not be required to retype controlled label content.

## 9. Governed Label Template Selection

Setup hardening requires the Production Database to distinguish at least the two Display label formats without exposing Windows printer details to the operator.

The accepted database direction is a new governed lookup:

```text
ref.label_template
```

with initial logical formats:

```text
DISPLAY_36MM
DISPLAY_24MM
```

A reviewed install candidate exists at:

```text
Database/Basic_Query_Tools_Dev/Create-LabelTemplate.sql
```

That candidate creates the new table and initial Display rows only. It does **not** alter the existing `ref.display` table and is not evidence that the table has already been deployed.

Before adding the eventual `ref.display.label_template_id` relationship, engineering must inspect the live production `ref.display` definition, constraints, triggers, grants, dependencies, and Directus metadata in accordance with the Production Schema Authority rule.

After that relationship is implemented, the intended data transition is:

```text
all existing Displays -> DISPLAY_36MM
selected smaller-label Displays -> changed deliberately to DISPLAY_24MM
```

The normal Directus presentation should describe the choice in operator terms such as **Label Size**, not require the operator to choose a Windows printer or `.lbx` file.

## 10. Template Location Contract

The Production Database may store the controlled template implementation **relative to the configured PRINT-SERVER template root**.

Example:

```text
pt_p950nw/QR_display_labels_2_line_24mm.lbx
```

The Production Database must not store the Beelink installation root as though it were asset data.

The current PRINT-SERVER machine-local deployment root is:

```text
C:\MSB_LabelService
```

and `config.local.ini` owns the template root:

```text
C:\MSB_LabelService\templates
```

The intended final physical layout is:

```text
C:\MSB_LabelService\templates\
    pt_p950nw\
    ql_820nwb\
```

The current root-level legacy template copies remain in place during transition so v3.4 is not broken before the revised runtime is accepted.

Changing the entire installation root later should require a machine-local configuration change, not edits to every PostgreSQL template row and not a Python source-code change.

The authoritative PRINT-SERVER deployment/configuration procedure belongs in the LabelPrintService runtime runbook.

## 11. Template and Printer Responsibility

The user selects/request the required label format; the user does not select the printer.

The responsibility boundary is:

```text
Production Database
    -> which governed label template/size is required
    -> relative template implementation path

LabelPrintService / PRINT-SERVER
    -> configured local template root
    -> actual Windows printer queue(s)
    -> actual media currently loaded
    -> b-PAC rendering
    -> physical preflight and spooler verification
```

The current Setup requirement does not need a database printer-inventory framework. If multiple physical printers can later satisfy the same governed label template, LabelPrintService may choose among configured compatible runtime printers without changing what the operator selects on the Display.

If a future printer requires a different physical implementation file for the same logical label, that runtime mapping must be reviewed at that time rather than forcing printer choice into normal Display data now.

## 12. Batch Printing and Compatibility

The system must support single-item and multi-item batches.

Because the existing Directus boolean workflow allows multiple Displays to be flagged before a polling cycle, pending work must be resolved by effective label template/media **before** an execution batch is created.

A single execution batch must not mix incompatible 24 mm and 36 mm Display requirements.

Rows not included in a successfully completed compatible batch must remain requested; unrelated `print_label` flags must not be cleared.

## 13. Print Tracking

Printing must remain auditable. Existing Display/Container snapshot batch tables preserve the print set and requester context.

The effective label-template identity should be snapshotted with future template-aware execution so later changes to a Display's default size cannot alter the historical meaning of an already-created print batch.

Do not claim item-level physical completion beyond what the current b-PAC/spooler evidence can actually prove.

## 14. Fail-Safe Preflight

The Setup-critical safety rule is:

> **If full deterministic preflight does not pass, no execution batch may be created.**

The current v3.4 preflight is incomplete. A 2026-08-27 production failure proved that a batch can currently be committed before a missing runtime CSV path is discovered.

The revised preflight must check the complete pending compatible workload before batch creation, including at minimum:

- selected template exists;
- b-PAC can open the template;
- required template objects are present;
- correct printer can be selected;
- required media is loaded and usable;
- required SQL files exist/readable;
- runtime CSV/output locations are available and writable;
- print queue is safe;
- required runtime/log/state paths are valid; and
- no existing active/failed work blocks safe execution.

A failed preflight must cause:

```text
NO new batch header
NO new batch items
NO print_label clearing
NO print-history success mutation
NO DBA cleanup requirement
```

Full preflight runs once for the compatible pending workload immediately before batch creation; it is not intended to repeat every stable path/template check before every physical label.

## 15. PRINT-SERVER Operator Feedback — Setup Direction

The existing boolean workflow has no useful return path to the Directus operator when physical action is required at the printer desk.

For Setup, the accepted lightweight direction is a **single-instance PRINT-SERVER tray/status UI** rather than a full Label Printing application.

This is a planned/under-development behavior and must not be documented as deployed until office acceptance passes.

Intended behavior:

- print engine auto-starts once and remains independent of the status UI;
- one singleton status UI normally lives only in the Windows system tray;
- routine successful jobs do not open new windows;
- there are no per-job status windows;
- only an actionable condition restores/shows the one status window and brings it to attention;
- examples include wrong media, no media, printer unavailable, missing template/runtime dependency, or service problem;
- closing the visible status window hides it to the tray rather than stopping the print engine;
- after the condition is corrected, the same request can continue automatically if the safety gates permit it; and
- normal users should not require or be encouraged to use a desktop **Start Print Server** shortcut.

Progress wording must not imply per-label physical verification that the current system cannot prove. Safe messages include **Submitting item 4 of 12**, **Waiting for Windows print queue**, and **Batch completed**.

Physical tray behavior, b-PAC interaction, media-change detection, and printer-dependent acceptance remain pending until testing can be performed on PRINT-SERVER at the office.

## 16. Duplicate Prevention and Reprints

Accidental duplicate printing must remain prevented. Intentional reprints remain possible.

The current FAILED-batch/no-double-print protections must not be weakened while preflight is moved earlier.

A previously printed label does not prove that a valid physical label is still present on the asset or lead.

If an interruption occurs after physical execution begins and the service cannot prove which individual labels completed, it must not silently guess. That limitation is separate from preventable preflight failures.

## 17. Engineering Boundary

### Labeling and Scanning

Owns/governs:

- label identity and payload contract;
- deployed-label compatibility;
- logical label-template requirements;
- operator-facing label-size meaning;
- scanner/scan compatibility.

### Production Database

Owns:

- authoritative Display/Container/Location identity and records;
- `ref.label_template` implementation when deployed;
- eventual governed relationship from Display to template after live-schema review;
- database-side request/batch/history/audit state.

### LabelPrintService / PRINT-SERVER

Owns:

- `C:\MSB_LabelService` deployment;
- machine-local configuration;
- `.lbx` files and printer-specific template folders;
- actual Windows printer queues;
- b-PAC rendering;
- printer/media/runtime preflight;
- tray/status UI implementation;
- spooler verification and service-specific recovery.

## 18. Current Implementation and Acceptance Boundary

The controlled implementation work is tracked under LabelPrintService Issue #14.

Repository preparation and non-hardware tests may be completed remotely. Printer-dependent acceptance is explicitly deferred until onsite access to PRINT-SERVER and the physical printers is available.

Until those tests pass:

- current v3.4 remains the accepted production runtime;
- root-level legacy templates remain available so current configured paths do not break;
- the tray/status UI is a design/implementation candidate, not a production fact;
- 24 mm automatic template/media selection is not yet a production fact; and
- compact new/replacement QR printing is not yet a production fact.

## Related Documentation

- [`Label_Payload_and_Profile_Architecture.md`](Label_Payload_and_Profile_Architecture.md)
- [`Scanner_Hardware_and_Tablet_Integration.md`](Scanner_Hardware_and_Tablet_Integration.md)
- [`Asset_Identity_and_Scan_Payload_Standard.md`](Asset_Identity_and_Scan_Payload_Standard.md)
- [FieldWiring Channel / Plug Label Printing Requirements](../09_Wiring_System/FieldWiring_Channel_Plug_Label_Printing_Requirements.md)
- [Operational Label Printing SOPs](../../02_Operational_SOPs/Label_Printing/)
- [MSB LabelPrintService](https://github.com/Gregovate/MSB_LabelPrintService)

## Revision History

| Date | Change |
|---|---|
| 2026-08-28 | Reconciled current Directus boolean/polling workflow, corrected Location printing from claimed current capability to gated future work, recorded 24/36 mm Display template requirement, `ref.label_template` candidate, relative-path/runtime-root contract, fail-before-batch preflight, and tray-only normal status UI direction. |
