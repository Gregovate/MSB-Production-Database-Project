# FieldWiring Channel / Plug Label Printing Requirements

| Document control | Value |
|---|---|
| Status | DRAFT — future integration requirement |
| Sub-project | FieldWiring |
| Current revision | 2026-08-19 |
| Owner | MSB Database Administrator |
| Code/schema change status | DOCUMENTATION ONLY |

## Purpose

FieldWiring will eventually need to generate and reprint physical plug/lead labels from current wiring data without requiring operators to hand-key LOR Channel Names into Brother label software.

This is a cross-system integration requirement between FieldWiring and the existing Labeling / LabelPrintService subsystem. It does not authorize a new printer implementation inside FieldWiring.

## Why This Is Needed

The field wiring model now uses the LOR **Channel Name** as the human-readable identifier for many physical plugs/leads.

Hand-entering those names into printer software would be slow and error-prone. FieldWiring already has the current approved wiring rows, controller/output context, Channel Name, Display, network, and snapshot provenance needed to create a controlled label request.

The intended direction is therefore:

```text
current approved FieldWiring row
    -> operator selects plug/lead labels
    -> FieldWiring creates controlled print request
    -> existing LabelPrintService
    -> Brother label printer
```

The Channel Name must come from the current authoritative wiring data. Normal operators must not be required to retype it.

## Label Class Boundary

A FieldWiring plug/lead label is a **configuration / hookup label**, not a permanent asset-identity label.

Unlike a Display, Container, or future Controller QR/identity label, a plug/lead Channel Name may change when the approved LOR wiring topology changes.

Therefore:

- the printed text is derived from the current approved wiring state;
- print history must retain enough source provenance to identify which wiring build produced the label;
- a later Channel Name change may require a controlled replacement/reprint; and
- the plug/lead label must not be used as the permanent identity key for the controller, Display, or wiring relationship.

## Known Printer / Service Context

The established printer system is the existing **MSB_LabelPrintService** using the Brother P-Touch PT-P950NW network label printer.

The Production Database labeling design already requires centrally controlled templates, duplicate prevention, intentional reprints, print tracking, and per-item failure handling.

The current LabelPrintService repository presently contains Display and Container LBX templates. A dedicated FieldWiring plug/channel template has **not** yet been established.

The field team has specified **1/2-inch laminated label stock** for these plug/lead labels.

Template dimensions, text wrapping/truncation rules, font sizing, cutter behavior, and long Channel Name handling must be tested specifically for this stock before production use.

## Cartridge / Media Preflight

FieldWiring must not assume that the printer has the correct tape cartridge merely because a print request was accepted.

The current LabelPrintService engineering TODO documents that tape-out detection is not reliable: b-PAC and the Windows spooler may report success even when usable tape is not actually available.

For FieldWiring label printing, a production-ready preflight must therefore establish how to verify at least:

```text
correct printer available
correct 1/2-inch media/cartridge loaded
required FieldWiring template available
printer/service ready
```

If reliable automatic cartridge-width / media detection cannot be proven, the workflow must require an explicit operator confirmation before the batch is released.

A software "success" response alone must not be treated as proof that the physical labels printed correctly.

## Controlled Print Workflow

The normal workflow should be approximately:

```text
1. Operator opens resolved FieldWiring context.
2. Operator selects one or more physical plug/output labels.
3. FieldWiring shows a pre-print review.
4. Operator confirms label count and exact Channel Name text.
5. Printer/media/template preflight passes or operator confirms required media.
6. FieldWiring submits a controlled request to LabelPrintService.
7. LabelPrintService renders and prints the batch.
8. Per-label / per-item result is retained.
9. Operator can reprint only failed/damaged/missing labels when needed.
```

The pre-print review should make the source context obvious enough to catch a wrong Stage/Scene/Background/Musical selection before tape is consumed.

## Checks and Balances

At minimum, the integration must provide:

- exact Channel Name sourced from the current approved wiring data;
- no normal hand-keying of label text;
- Stage/Sub-stage/Scene and Background/Musical context visible before printing;
- physical controller/group and Output/Plug context visible when known;
- requested label count visible before printing;
- centrally controlled FieldWiring label template;
- required 1/2-inch media/cartridge check or explicit confirmation;
- protection against accidental duplicate batch printing;
- intentional reprint capability;
- a required or selected reprint reason;
- targeted reprint of selected/failed labels rather than the whole prior batch;
- per-item print result where technically possible;
- requester / timestamp tracking;
- wiring snapshot / Preview provenance sufficient to identify the source data; and
- no silent rewriting of the Channel Name merely to make it fit a label.

Useful reprint reasons include:

```text
damaged label
lost label
bad application
printer failure / partial batch
incorrect media
changed approved Channel Name
operator test
other controlled reason
```

## Label Content — Initial Direction

The essential printed content is the current **Channel Name**, because that is the identifier the field team has chosen for the plug/lead.

A 1/2-inch label has limited real estate. Additional information such as controller/group, physical Output number, Display name, or network should not be assumed to fit on the same label until an actual template is tested.

The application may show all of that supporting context in the browser pre-print review even when only the Channel Name is printed.

The final template must be validated against representative short and long Channel Names before production approval.

## Relationship to FieldWiring Physical Presentation

Label printing must use the same physical interpretation presented to the installer.

Examples:

```text
Traditional A/C
    physical Output 7
    -> print the current Channel Name for that field lead

Pixie
    physical Output 1-16
    -> print the current Channel Name associated with the selected pigtail/field lead

E1.31
    physical controller/output when known
    -> print the applicable field connection / Channel Name only after the physical mapping is accepted
```

Raw LOR Unit IDs, DMX/E1.31 universes, and compatibility-view `Controller` values must not be substituted for the chosen Channel Name merely because they are easier to print.

## Implementation Boundary

FieldWiring should request labels; **MSB_LabelPrintService remains responsible for printer-specific rendering and printer communication**.

FieldWiring must not create a second independent Brother printer integration if the existing LabelPrintService can be extended to support this label class.

The future implementation work should be coordinated with the Labeling and Scanning / LabelPrintService workstream.

## Acceptance Requirements

Before FieldWiring channel/plug label printing is considered production-ready, test at minimum:

1. a dedicated 1/2-inch FieldWiring LBX/template;
2. representative short and long Channel Names;
3. one-label printing;
4. multi-label batch printing;
5. exact text transfer from current FieldWiring data with no re-keying;
6. pre-print review of context, count, and label text;
7. correct-media/cartridge preflight or explicit confirmation;
8. intentional reprint of one selected label;
9. partial-batch failure and targeted retry;
10. accidental duplicate-print protection;
11. changed Channel Name / replacement-label workflow;
12. requester and source-provenance tracking; and
13. physical verification that printed labels correspond to the selected plugs/outputs.

## Related Documents

- [FieldWiring Field Presentation Requirements](FieldWiring_Field_Presentation_Requirements.md)
- [FieldWiring Physical Controller / Output Presentation Contract](FieldWiring_Physical_Controller_Output_Presentation_Contract.md)
- [Label Creation and Printing](../07_Labeling_and_Scanning/Label_Creation_and_Printing.md)
- [Labeling and Scanning](../07_Labeling_and_Scanning/README.md)
- [Label Printing Operational SOPs](../../02_Operational_SOPs/Label_Printing/README.md)
