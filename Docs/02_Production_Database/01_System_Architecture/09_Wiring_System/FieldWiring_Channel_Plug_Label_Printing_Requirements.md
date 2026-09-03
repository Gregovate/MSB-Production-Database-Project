# FieldWiring Channel / Plug Label Printing Requirements

| Document control | Value |
|---|---|
| Status | DRAFT — accepted request/content direction; implementation pending |
| Sub-project | FieldWiring |
| Current revision | 2026-09-03 |
| Owner | MSB Database Administrator |
| Code/schema change status | DOCUMENTATION ONLY |

## Purpose

FieldWiring needs to generate and reprint physical wire/lead labels from current approved wiring data without requiring operators to hand-key or manually reinterpret LOR wiring names in Brother label software.

This is a cross-system integration requirement between FieldWiring, the Production Database, the Labeling and Scanning contract, and the existing LabelPrintService subsystem. It does not authorize a new printer implementation inside FieldWiring.

The physical printing implementation remains owned by `Gregovate/MSB_LabelPrintService`.

## Accepted System Boundary

```text
FieldWiring / Production Database
    -> operator selects current wiring outputs/leads
    -> governed request state
    -> requester attribution / audit
    -> current wiring provenance
    -> normalized channel_name content

Labeling and Scanning contract
    -> logical label family / payload rules

MSB_LabelPrintService V4
    -> polling / request consumption
    -> runtime profile mapping
    -> split normalized channel_name into print lines
    -> Brother template / media / b-PAC
    -> physical printing
    -> successful-print finalization
```

FieldWiring and Production Database must not store Brother `.lbx` paths, Windows printer queue names, PRINT-SERVER filesystem paths, or b-PAC implementation details in wiring, Display, Controller, or request records.

## Authoritative Wiring Source

LOR/V7 remains authoritative for current show wiring topology.

The current FieldWiring wiring path uses the parser-produced Field Wiring / field-lead interpretation, including the same parser logic used to combine Props/SubProps into the wiring view.

For wire labels, the current resolved `channel_name` carried by the FieldWiring row is the authoritative human wiring-name source. FieldWiring must not create a second independent interpretation of the raw Prop/SubProp source merely for printing.

Permanent identities remain:

```text
Display     ref.display.display_id
Controller  ref.controller.controller_id
```

Network, UID, universe, channel, and output data are current wiring/configuration context and are not permanent asset identity.

## Accepted Channel-Name Normalization Rule

The label starts from the current approved FieldWiring `channel_name`.

Before the description is handed to LabelPrintService, remove only the technical prefix at the beginning of the Channel Name:

```text
<Stage/area short code> + <UID-channel prefix>
```

The remainder of the current `channel_name` is the label description.

Example:

```text
source channel_name
TC 7B-10 Caroler P2 Mouth Closed 1

physical output
10

normalized label description
Caroler P2 Mouth Closed 1
```

The accepted rule is deliberately narrow:

- remove the leading short code used for preview/wiring organization;
- remove the leading UID-channel token used for LOR addressing;
- retain the remainder of `channel_name` exactly as the descriptive wiring data;
- do not independently strip later tokens such as `P1`, `P2`, or other text merely because they resemble routing or authoring context;
- do not hand-key or manually rewrite the description in the normal operator workflow; and
- if the expected leading technical prefix cannot be resolved under the accepted wiring/parser rules, block/review that label instead of silently guessing.

This normalization belongs with the FieldWiring/Production Database semantic request side because it depends on the accepted wiring interpretation. LabelPrintService must not become a second parser that tries to infer which leading tokens are LOR wiring scaffolding.

## Print-Line Split Boundary

FieldWiring supplies the normalized descriptive `channel_name` content and the resolved physical output.

LabelPrintService V4 owns the physical rendering split into the two label text lines.

Conceptually:

```text
FieldWiring request
    physical_output = 10
    label_description = Caroler P2 Mouth Closed 1

LabelPrintService V4
    -> formats physical output for the approved template
    -> splits label_description into objLine1 / objLine2
    -> repeats the same logical content on both halves of the fold-around label
```

The Production Database request must not encode Brother object names or duplicate left/right template fields merely because the physical template repeats them.

## Label Class Boundary

A FieldWiring wire/lead label is a **configuration / hookup label**, not a permanent asset-identity label.

Descriptive wiring metadata may change when the approved LOR wiring topology changes. Therefore:

- the printed content is derived from current approved structured wiring state;
- print history must retain enough source provenance to identify which wiring build produced the label;
- later wiring changes may require a controlled replacement/reprint; and
- the wire label must not be used as the permanent identity key for the Controller, Display, or wiring relationship.

## Accepted Label Unit and Quantity

The physical labeling rule is:

> **Each Display receives one wire label for each physical controller output used by that Display.**

A wire-label request item therefore represents one selected Display/output relationship from the current FieldWiring result.

### Shared output/channel behavior

If two Displays share the same programmed channel/output, they remain separate physical Displays and each receives its own wire label using that Display's own current `channel_name`.

Example conceptually:

```text
Controller output X
    Display A -> one label using Display A channel_name
    Display B -> one label using Display B channel_name
```

FieldWiring must not deduplicate the two labels merely because their current technical channel/output relationship is shared.

### Traditional / Pixie output behavior

For normal A/C and Pixie relationships, each Display receives one label per resolved physical output used by that Display.

### E1.31 / DMX physical-output behavior

E1.31/DMX-controlled hardware also receives one label per physical controller output.

Examples of the accepted quantity rule include:

```text
Pixie4D -> 4 physical output labels when all 4 outputs are used by the selected Display/controller relationship
Pixie2D -> 2 physical output labels when both outputs are used by the selected Display/controller relationship
```

The count comes from the resolved physical controller/output relationship presented by FieldWiring, not from raw universe count, raw DMX channel count, or a generic compatibility-view `Controller` value.

## Logical Label Family

The accepted logical Production Database / LabelPrintService family for this label class is:

```text
WIRING_12MM_HORIZONTAL
```

This identifies the governed 12 mm horizontal Wiring label family without encoding printer-specific implementation.

LabelPrintService V4 owns the runtime mapping from that logical family to the approved Brother printer, 12 mm laminated media, fold-around template, and physical object bindings.

## Approved Physical Format

The current V4 physical format is the double-sided fold-around 12 mm Wiring label.

One logical label contains:

```text
physical output number
normalized FieldWiring description
```

The same logical data is rendered on both halves so the label remains readable after it is folded around the wire/lead.

The double-sided physical format does **not** mean two requested labels. One selected Display/output relationship normally produces one physical fold-around label.

## Operator Selection Workflow

The normal FieldWiring workflow should be:

```text
1. Operator opens current resolved FieldWiring context.
2. FieldWiring presents the current Display/controller/output relationships.
3. Operator selects individual Display/output labels or a useful group of those labels.
4. FieldWiring shows the exact selected Displays, physical outputs, and normalized label descriptions.
5. Operator confirms the selected label count.
6. Production Database creates governed request state with requester/audit/provenance.
7. LabelPrintService V4 later consumes the governed pending request.
8. LabelPrintService performs printer/media/template preflight, rendering, and physical printing.
9. Successful print state is finalized without clearing unrelated pending requests.
```

Convenience selection such as all outputs for one Display or Controller may be provided, but the underlying request quantity remains one item per Display/output relationship.

The browser must not make hand-entered label text the authority.

## Request Identity and Snapshot Requirement

The current FieldWiring compatibility row does not itself provide a permanent asset-style row identity. A governed wire-label request must therefore snapshot enough information to remain unambiguous even after later LOR changes.

At minimum preserve as applicable:

```text
request / request-item identity
permanent display_id
permanent controller_id when resolved
physical output
normalized label description
raw/current channel_name as source evidence
current Stage / Sub-stage / Scene context
Preview identity / revision
LOR import_run_id / parser provenance
current network / UID / universe / channel context needed for engineering traceability
logical label family
requester / requested timestamp
```

Network, UID, universe, and channel values are frozen provenance/context, not permanent identity.

Historical request content must not be rewritten merely because a later LOR import changes the current wiring.

## Pending, Duplicate, Cancel, and Reprint Behavior

The request workflow must prevent accidental duplicate physical printing while still allowing intentional replacement labels.

Accepted direction:

- one selected Display/output relationship creates one normal pending request item;
- an equivalent request already pending must not create another accidental duplicate;
- a pending item may be cancelled before the downstream print service has claimed/frozen it for execution;
- completed history remains immutable;
- an intentional reprint is a new controlled request linked to prior print history where practical;
- the reprint reason must be retained; and
- failed/uncertain print execution must not be blindly resubmitted in a way that can double-print an uncertain boundary label.

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

## Authorization Boundary

Wire-label request authorization is limited to authenticated users in these accepted Directus roles:

```text
Production Crew
Manager
Administrator
```

The privilege model is intentionally graduated:

```text
Production Crew
    -> select/request/cancel wire-label printing as allowed by the request workflow
    -> no broader wiring or Controller configuration editing

Manager
    -> wire-label request rights
    -> additional Manager-level operational rights defined by the responsible subsystem contracts

Administrator
    -> highest existing administrative rights under the current authorization model
```

The wire-label implementation must **not** grant any of these roles new rights through this workflow to change:

```text
channel numbers
channel_name values
LOR UID/address values
```

Those facts remain controlled by the authoritative LOR/V7 wiring path and its existing engineering workflows.

The browser application role must not receive broad table DML merely to support wire-label requests. Reuse the existing protected-browser pattern:

```text
Cloudflare-authenticated operator
    -> server-side role/capability validation
    -> narrow SECURITY DEFINER PostgreSQL command
    -> fieldwiring_app EXECUTE only
```

No direct broad INSERT/UPDATE/DELETE grant to `fieldwiring_app` is authorized by this requirement.

## Requester / Audit Behavior

The governed request must capture the human requester at request creation rather than requiring LabelPrintService to infer the actor later from mutable Display or Controller rows.

At minimum retain:

```text
requested_by
requested_by_person_id
requested_at
```

Normal MSB audit fields and actor resolution rules apply to writable request records/functions.

## Printer / Media Preflight Boundary

FieldWiring does not perform Brother/printer readiness checks.

LabelPrintService V4 owns central preflight for the `WIRING_12MM_HORIZONTAL` family, including the required printer, correct 12 mm laminated media, template availability, printer readiness, and no-double-print safeguards.

A FieldWiring request becoming pending is not proof that the physical label printed.

## Checks and Balances

At minimum, the integration must provide:

- one request item per selected Display/physical-output relationship;
- separate labels for separate Displays even when they share a channel/output;
- E1.31/DMX quantity based on resolved physical controller outputs;
- current `channel_name` as the descriptive source;
- removal of only the accepted leading short-code + UID-channel prefix;
- no normal hand-keying of wire-label text;
- V4-owned split of the normalized description into physical print lines;
- visible selected label count before request submission;
- logical family `WIRING_12MM_HORIZONTAL`;
- requester / timestamp tracking;
- wiring snapshot / Preview provenance sufficient to identify the source data;
- accidental duplicate prevention;
- intentional targeted reprint capability;
- per-item result where technically possible;
- no new browser rights to alter channel numbers, Channel Names, or UIDs; and
- no Brother template/path/printer implementation in FieldWiring.

## Implementation Boundary

FieldWiring / Production Database owns the semantic request:

```text
which Display/output relationships were selected
resolved physical output
normalized channel_name description
requester / audit
current wiring provenance
logical label family
```

LabelPrintService V4 owns the physical execution:

```text
polling / claiming pending work
runtime family mapping
line1 / line2 split
output formatting
fold-around template rendering
12 mm media / printer preflight
b-PAC / spooler / printer behavior
physical printing
successful-print finalization
```

FieldWiring must not create a second independent Brother printer stack or polling mechanism.

## Acceptance Requirements

Before FieldWiring wire-label requesting is considered production-ready, test at minimum:

1. one normal Display/output selection;
2. one Display using multiple outputs and prove one label per output;
3. two Displays sharing one programmed channel/output and prove each receives a separate label using its own `channel_name`;
4. a representative raw `channel_name` with leading short code + UID-channel prefix and prove only that prefix is removed;
5. a representative value containing `P1`, `P2`, or similar text after the prefix and prove that text is retained;
6. V4 line splitting of the normalized description without FieldWiring pre-splitting the Brother object fields;
7. Pixie4D physical-output quantity;
8. Pixie2D physical-output quantity;
9. representative E1.31/DMX physical-output selection without substituting universe/channel count for physical output count;
10. individual-label selection;
11. multi-label selection for one Display;
12. useful grouped selection while retaining one request item per Display/output;
13. accidental duplicate request protection;
14. cancellation while still pending;
15. intentional targeted reprint with reason;
16. requester and source-provenance tracking;
17. Production Crew can request labels but cannot change channel number/name/UID through this workflow;
18. Manager and Administrator authorization remains consistent with their existing increasing rights;
19. `fieldwiring_app` has no broad table DML for the workflow;
20. correct `WIRING_12MM_HORIZONTAL` handoff to LabelPrintService; and
21. no FieldWiring dependency on Brother `.lbx` path, Windows printer queue, PRINT-SERVER filesystem layout, or b-PAC internals.

## Related Documents

- [FieldWiring Field Presentation Requirements](FieldWiring_Field_Presentation_Requirements.md)
- [FieldWiring Physical Controller / Output Presentation Contract](FieldWiring_Physical_Controller_Output_Presentation_Contract.md)
- [Label Creation and Printing](../07_Labeling_and_Scanning/Label_Creation_and_Printing.md)
- [Labeling and Scanning](../07_Labeling_and_Scanning/README.md)
- [Label Printing Operational SOPs](../../02_Operational_SOPs/Label_Printing/README.md)
