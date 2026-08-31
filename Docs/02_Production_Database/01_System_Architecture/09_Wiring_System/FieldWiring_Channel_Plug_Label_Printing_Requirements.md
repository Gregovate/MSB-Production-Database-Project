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

In this example, the Stage short code and UID-channel portion are intentionally embedded in the LOR name for preview authoring/context. Printing that whole string on the physical wiring label would unnecessarily bind the field label to a particular Stage/controller/address context.

The intended direction is therefore:

```text
current approved FieldWiring row
    -> resolve structured plug/output identifier + useful field metadata
    -> operator selects plug/lead labels
    -> FieldWiring creates controlled print request
    -> existing LabelPrintService
    -> Brother label printer
```

Normal operators must not be required to retype or manually strip the LOR source name.

## Authoring Name Versus Printed Wiring Label Contract

The LOR Channel Name is source evidence and may include preview-authoring scaffolding. It must not be blindly copied to the physical label.

For wiring labels:

- Stage short codes embedded only for preview organization are **not** intended physical-label content;
- controller UID/channel or equivalent controller-binding prefixes embedded only for preview organization are **not** intended physical-label content;
- the physical label should emphasize the applicable **plug/output identifier** used by the installer and the useful connection metadata;
- controller, Stage, network, UID/channel, universe, and other resolved wiring context remains available from the FieldWiring system and may be shown in the pre-print review without being printed on the label;
- the LabelPrintService must not attempt to infer correctness by blindly trimming arbitrary prefixes from a raw Channel Name string; and
- if the structured plug/output identifier and printable metadata cannot be resolved unambiguously from the approved wiring model, the print request should be blocked/reviewed rather than falling back to the entire raw LOR Channel Name.

For example, where structured FieldWiring data establishes that `P1` is the field plug and `Caroler Mouth Open 2` is the useful connection metadata, those are appropriate label inputs. The authoring prefix `TC 7B-09` should not be printed merely because it exists in the LOR Channel Name.

This is a data-contract boundary, not a cosmetic string-shortening rule.

## Label Class Boundary

A FieldWiring plug/lead label is a **configuration / hookup label**, not a permanent asset-identity label.

Unlike a Display, Container, or future Controller QR/identity label, a plug/lead assignment or descriptive metadata may change when the approved wiring topology changes.

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

`objChannel` is the visually dominant plug/output field. `objLine1` / `objLine2` are supporting printable metadata. The exact structured FieldWiring source fields supplying those objects must be resolved before Wiring printing is implemented.

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
3. FieldWiring resolves the structured plug/output identifier and printable metadata.
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

- printable plug/output identifier sourced from the current approved structured wiring data;
- printable metadata sourced from the current approved structured wiring data;
- no normal hand-keying or manual prefix stripping of label text;
- raw LOR Channel Name retained as source evidence where useful, but not assumed to be the literal physical-label text;
- Stage/Sub-stage/Scene and Background/Musical context visible before printing;
- physical controller/group and Output/Plug context visible when known;
- controller-bound authoring prefixes excluded from physical labels when structured wiring data makes them unnecessary;
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

The essential physical-label content is the **field plug/output identifier plus useful connection metadata**, resolved from the approved wiring model.

The raw LOR Channel Name may contain additional Stage/controller/address scaffolding needed only for preview authoring and therefore must not be treated as the label specification.

A 12 mm label has limited real estate. The visually dominant field should be the installer-facing plug/output value, with one or two lines of concise connection metadata as supported by the tested template.

Additional context such as Stage, controller identity, UID/channel, Display, network, universe, or source Preview can remain visible in the FieldWiring browser/pre-print review and available through the wiring system rather than being permanently printed on every lead.

The final source-field mapping and representative short/long metadata cases must be validated before production approval.

## Relationship to FieldWiring Physical Presentation

Label printing must use the same physical interpretation presented to the installer while avoiding unnecessary controller binding on the physical lead.

Examples:

```text
Traditional A/C
    resolved physical field plug/output + connection metadata
    -> print installer-facing plug/output and metadata
    -> do not print preview-only Stage + UID/channel prefix merely because it is embedded in LOR Channel Name

Pixie
    resolved field pigtail/plug + connection metadata
    -> print installer-facing plug/output and metadata
    -> controller assignment/context remains available in FieldWiring

E1.31
    resolved physical connection/output when accepted
    -> print installer-facing connection identifier and metadata
    -> universe/controller context remains available in FieldWiring unless specifically approved as label content
```

Raw LOR Unit IDs, DMX/E1.31 universes, compatibility-view `Controller` values, or Stage short codes must not be substituted into the physical label merely because they are easy to extract from the preview.

## Implementation Boundary

FieldWiring should resolve and request the semantic label content; **MSB_LabelPrintService remains responsible for printer-specific rendering and printer communication**.

This means:

```text
FieldWiring / wiring model
    -> decides WHAT plug/output + metadata should be printed

LabelPrintService
    -> decides HOW those supplied fields are rendered on the 12 mm template
```

LabelPrintService must not become a second wiring parser whose correctness depends on reverse-engineering naming prefixes from LOR Channel Name text.

FieldWiring must not create a second independent Brother printer integration if the existing LabelPrintService can be extended to support this label class.

The future implementation work should be coordinated with the Labeling and Scanning / LabelPrintService workstream.

## Acceptance Requirements

Before FieldWiring channel/plug label printing is considered production-ready, test at minimum:

1. the dedicated 12 mm FieldWiring one-line and two-line templates;
2. representative short and long printable metadata;
3. a representative LOR name containing Stage + UID/channel authoring scaffolding and prove that scaffolding is omitted from the physical label;
4. one-label printing;
5. multi-label batch printing;
6. exact structured plug/output and metadata transfer with no re-keying;
7. pre-print review showing both printable fields and supporting controller/Stage context;
8. correct 12 mm media/cartridge preflight;
9. intentional reprint of one selected label;
10. partial-batch failure and targeted retry;
11. accidental duplicate-print protection;
12. changed structured wiring metadata / replacement-label workflow;
13. requester and source-provenance tracking;
14. physical verification that printed labels correspond to the selected plugs/outputs; and
15. proof that LabelPrintService does not rely on a fragile hard-coded parser for Stage/UID/channel prefixes.

## Related Documents

- [FieldWiring Field Presentation Requirements](FieldWiring_Field_Presentation_Requirements.md)
- [FieldWiring Physical Controller / Output Presentation Contract](FieldWiring_Physical_Controller_Output_Presentation_Contract.md)
- [Label Creation and Printing](../07_Labeling_and_Scanning/Label_Creation_and_Printing.md)
- [Labeling and Scanning](../07_Labeling_and_Scanning/README.md)
- [Label Printing Operational SOPs](../../02_Operational_SOPs/Label_Printing/README.md)
