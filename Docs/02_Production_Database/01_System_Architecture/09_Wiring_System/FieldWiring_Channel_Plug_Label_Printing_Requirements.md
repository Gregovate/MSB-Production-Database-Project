# FieldWiring Channel / Plug Label Printing Requirements

| Document control | Value |
|---|---|
| Status | DRAFT — future integration requirement |
| Sub-project | FieldWiring |
| Current revision | 2026-08-31 |
| Owner | MSB Database Administrator |
| Code/schema change status | DOCUMENTATION ONLY |

## Purpose

FieldWiring will eventually need to generate and reprint physical plug/lead labels from current wiring data without requiring operators to hand-key or manually reinterpret LOR Channel Names in Brother label software.

This is a cross-system integration requirement between FieldWiring and the existing Labeling / LabelPrintService subsystem. It does not authorize a new printer implementation inside FieldWiring.

## Why This Is Needed

FieldWiring has the current approved wiring rows, controller/output context, LOR Channel Name evidence, Display, network, and snapshot provenance needed to create a controlled label request.

However, the literal LOR **Channel Name is not automatically print-ready label text**.

Some LOR Channel Names intentionally contain authoring-only context that helps keep channels straight inside the preview. A representative pattern is:

```text
TC 7B-09 Caroler P1 Mouth Open 2
```

In this example:

- `TC` is Stage/authoring context;
- `7B` is controller UID/address context;
- `09` identifies controller channel/output 9;
- `P1` is a field plug identifier embedded in the descriptive portion; and
- the remaining words are useful field metadata.

The Stage short code and controller UID are intentionally embedded in the LOR name for preview authoring/context. Printing those values on the physical wiring line would unnecessarily bind the lead label to a particular Stage/controller identity.

The controller channel/output number itself is different: it is intentionally printed as a large standalone integer, normally `1` through `16`, and does not by itself identify a specific controller.

The intended direction is therefore:

```text
current approved FieldWiring row
    -> resolve controller physical channel/output number
    -> resolve field plug identifier + useful field metadata
    -> operator selects plug/lead labels
    -> FieldWiring creates controlled print request
    -> existing LabelPrintService
    -> Brother label printer
```

Normal operators must not be required to retype or manually strip the LOR source name.

## Authoring Name Versus Printed Wiring Label Contract

The LOR Channel Name is source evidence and may include preview-authoring scaffolding. It must not be blindly copied to the physical label.

For wiring labels:

- `objChannel` is the physical controller channel/output number, normally an integer from `1` through `16`;
- `objChannel` is intentionally the visually dominant field on the label;
- Stage short codes embedded only for preview organization are **not** intended physical-label text;
- controller UID/address prefixes embedded only for preview organization are **not** intended physical-label text;
- the descriptive wiring line should retain the applicable **field plug identifier** and useful connection metadata;
- controller identity, Stage, network, UID/address, universe, and other resolved wiring context remains available from the FieldWiring system and may be shown in the pre-print review without being printed on the label;
- the LabelPrintService must not attempt to infer correctness by blindly trimming arbitrary prefixes from a raw Channel Name string; and
- if the controller channel/output, field plug, and printable metadata cannot be resolved unambiguously from the approved wiring model, the print request should be blocked/reviewed rather than falling back to the entire raw LOR Channel Name.

For the representative source name:

```text
TC 7B-09 Caroler P1 Mouth Open 2
```

the intended semantic label inputs are conceptually:

```text
objChannel = 9
printable descriptive text = field plug P1 + useful Caroler/Mouth Open 2 metadata
```

The exact ordering/splitting of the descriptive text is a rendering decision to be validated against the 12 mm templates. The authoring-only `TC` and controller UID `7B` must not be printed merely because they exist in the LOR Channel Name.

This is a data-contract boundary, not a cosmetic string-shortening rule.

## Label Class Boundary

A FieldWiring plug/lead label is a **configuration / hookup label**, not a permanent asset-identity label.

Unlike a Display, Container, or future Controller QR/identity label, a plug/lead assignment or descriptive metadata may change when the approved LOR wiring topology changes.

Therefore:

- the printed text is derived from the current approved structured wiring state;
- print history must retain enough source provenance to identify which wiring build produced the label;
- a later plug/output or metadata change may require a controlled replacement/reprint; and
- the plug/lead label must not be used as the permanent identity key for the controller, Display, or wiring relationship.

## Known Printer / Service Context

The established printer system is the existing **MSB_LabelPrintService** using the Brother P-Touch PT-P950NW network label printer.

The Production Database labeling design already requires centrally controlled templates, duplicate prevention, intentional reprints, print tracking, and per-item failure handling.

The LabelPrintService v4 workstream now includes dedicated 12 mm FieldWiring templates:

```text
wiring_label_1_line_horz_12mm.lbx
wiring_label_2_line_horz_12mm.lbx
```

The current object contract is:

```text
one-line: objChannel, objLine1
two-line: objChannel, objLine1, objLine2
```

`objChannel` is the visually dominant physical controller channel/output number, normally `1` through `16`.

`objLine1` / `objLine2` contain the field plug identifier and useful connection metadata, with preview-only Stage/controller-UID scaffolding removed by the structured wiring model before the print request reaches LabelPrintService.

The exact structured FieldWiring source fields supplying those objects must be resolved before Wiring printing is implemented.

The field team has specified **1/2-inch / 12 mm laminated label stock** for these plug/lead labels.

Text wrapping/splitting rules, font sizing, cutter behavior, and representative long metadata handling must be tested specifically for this stock before production use.

## Cartridge / Media Preflight

FieldWiring must not assume that the printer has the correct tape cartridge merely because a print request was accepted.

The LabelPrintService v4 preflight work has established Brother SNMP evidence for 12 mm, 24 mm, and 36 mm laminated tape, including no-media, cover-open, and end-of-media states. Wiring printing must use that central printer/media preflight rather than creating a FieldWiring-specific printer check.

For FieldWiring label printing, a production-ready preflight must verify at least:

```text
correct printer available
correct 12 mm laminated media loaded
required FieldWiring template available
printer/service ready
```

A software submission response alone must not be treated as proof that the physical labels printed correctly.

## Controlled Print Workflow

The normal workflow should be approximately:

```text
1. Operator opens resolved FieldWiring context.
2. Operator selects one or more physical plug/output labels.
3. FieldWiring resolves controller channel/output number, field plug identifier, and printable metadata.
4. FieldWiring shows a pre-print review of exactly what will be printed plus the supporting Stage/controller/network context.
5. Operator confirms label count and printable text.
6. Printer/media/template preflight passes.
7. FieldWiring submits a controlled request to LabelPrintService.
8. LabelPrintService renders and prints the batch.
9. Per-label / per-item result is retained.
10. Operator can reprint only failed/damaged/missing labels when needed.
```

The pre-print review should make the source context obvious enough to catch a wrong Stage/Scene/Background/Musical selection before tape is consumed, even when those context fields are intentionally omitted from the physical label.

## Checks and Balances

At minimum, the integration must provide:

- controller physical channel/output number sourced from the current approved structured wiring data;
- field plug identifier sourced from the current approved structured wiring data;
- printable metadata sourced from the current approved structured wiring data;
- no normal hand-keying or manual prefix stripping of label text;
- raw LOR Channel Name retained as source evidence where useful, but not assumed to be the literal physical-label text;
- Stage/Sub-stage/Scene and Background/Musical context visible before printing;
- physical controller/group and Output/Plug context visible when known;
- Stage and controller-UID authoring prefixes excluded from the descriptive physical label text;
- requested label count visible before printing;
- centrally controlled FieldWiring label template;
- required 12 mm media/cartridge preflight;
- protection against accidental duplicate batch printing;
- intentional reprint capability;
- a required or selected reprint reason;
- targeted reprint of selected/failed labels rather than the whole prior batch;
- per-item print result where technically possible;
- requester / timestamp tracking;
- wiring snapshot / Preview provenance sufficient to identify the source data; and
- no fragile LabelPrintService-only string parser that silently guesses which parts of an arbitrary LOR Channel Name are Stage/address scaffolding.

Useful reprint reasons include:

```text
damaged label
lost label
bad application
printer failure / partial batch
incorrect media
changed approved wiring metadata
operator test
other controlled reason
```

## Label Content — Accepted Direction

The essential physical-label content is:

```text
large controller channel/output number
+ field plug identifier
+ useful connection metadata
```

The large controller channel/output number is normally `1` through `16`. It is intentionally printed and does not, by itself, identify a particular controller.

The raw LOR Channel Name may contain additional Stage/controller UID/address scaffolding needed only for preview authoring and therefore must not be treated as the label specification.

A 12 mm label has limited real estate. `objChannel` is the visually dominant field. `objLine1` / `objLine2` carry the field plug and concise connection metadata as supported by the tested template.

Additional context such as Stage, controller identity, UID/address, Display, network, universe, or source Preview can remain visible in the FieldWiring browser/pre-print review and available through the wiring system rather than being permanently printed on every lead.

The final source-field mapping and representative short/long metadata cases must be validated before production approval.

## Relationship to FieldWiring Physical Presentation

Label printing must use the same physical interpretation presented to the installer while avoiding unnecessary Stage/controller identity binding on the descriptive physical label text.

Examples:

```text
Traditional A/C
    physical controller channel/output 1-16 -> objChannel
    resolved field plug + connection metadata -> objLine1/objLine2
    Stage + controller UID/address remain wiring-system context

Pixie
    physical controller channel/output 1-16 -> objChannel
    resolved pigtail/plug + connection metadata -> objLine1/objLine2
    controller assignment/context remains available in FieldWiring

E1.31
    accepted physical controller output -> objChannel when that output contract is established
    resolved connection/plug metadata -> objLine1/objLine2
    universe/controller identity remains available in FieldWiring unless specifically approved as label text
```

Raw LOR Unit IDs, DMX/E1.31 universes, compatibility-view `Controller` values, or Stage short codes must not be substituted into the descriptive physical label text merely because they are easy to extract from the preview.

## Implementation Boundary

FieldWiring should resolve and request the semantic label content; **MSB_LabelPrintService remains responsible for printer-specific rendering and printer communication**.

This means:

```text
FieldWiring / wiring model
    -> supplies controller channel/output number
    -> supplies field plug + printable metadata

LabelPrintService
    -> places channel/output in objChannel
    -> decides HOW supplied plug/metadata is rendered in objLine1/objLine2
```

LabelPrintService must not become a second wiring parser whose correctness depends on reverse-engineering naming prefixes from LOR Channel Name text.

FieldWiring must not create a second independent Brother printer integration if the existing LabelPrintService can be extended to support this label class.

The future implementation work should be coordinated with the Labeling and Scanning / LabelPrintService workstream.

## Acceptance Requirements

Before FieldWiring channel/plug label printing is considered production-ready, test at minimum:

1. the dedicated 12 mm FieldWiring one-line and two-line templates;
2. representative controller channel/output values, including normal `1` through `16` values;
3. representative short and long printable plug/metadata text;
4. a representative LOR name containing Stage + UID/channel authoring scaffolding and prove Stage/UID scaffolding is omitted while the resolved channel/output number is retained in `objChannel`;
5. one-label printing;
6. multi-label batch printing;
7. exact structured channel/output, plug, and metadata transfer with no re-keying;
8. pre-print review showing both printable fields and supporting controller/Stage context;
9. correct 12 mm media/cartridge preflight;
10. intentional reprint of one selected label;
11. partial-batch failure and targeted retry;
12. accidental duplicate-print protection;
13. changed structured wiring metadata / replacement-label workflow;
14. requester and source-provenance tracking;
15. physical verification that printed labels correspond to the selected controller outputs/plugs; and
16. proof that LabelPrintService does not rely on a fragile hard-coded parser for Stage/UID/address prefixes.

## Related Documents

- [FieldWiring Field Presentation Requirements](FieldWiring_Field_Presentation_Requirements.md)
- [FieldWiring Physical Controller / Output Presentation Contract](FieldWiring_Physical_Controller_Output_Presentation_Contract.md)
- [Label Creation and Printing](../07_Labeling_and_Scanning/Label_Creation_and_Printing.md)
- [Labeling and Scanning](../07_Labeling_and_Scanning/README.md)
- [Label Printing Operational SOPs](../../02_Operational_SOPs/Label_Printing/README.md)