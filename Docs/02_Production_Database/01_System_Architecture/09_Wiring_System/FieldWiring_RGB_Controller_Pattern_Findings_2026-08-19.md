# FieldWiring RGB Controller Pattern Findings — 2026-08-19

| Item | Value |
|---|---|
| Status | ENGINEERING FINDINGS — current V7 snapshot evidence |
| Sub-project | FieldWiring |
| Scope | RGB/Pixie physical-output interpretation |
| Controller Inventory | Current source artifact not yet available for inspection |
| Schema status | No schema change authorized |

## Purpose

This document records additional real MSB RGB/Pixie patterns found while validating the FieldWiring physical-controller/output presentation contract.

The goal is to distinguish what current LOR/V7 topology already proves from what must wait for the physical Controller Inventory source.

These findings supplement [FieldWiring Physical Controller / Output Presentation Contract](FieldWiring_Physical_Controller_Output_Presentation_Contract.md).

## Who Forest — Eight Distinct Pixie 8 Address Blocks

The current Master Musical Scene `07a-Who Forest-WF` contains eight RGB Tree Props. Each Tree is `string_type = RGB`, uses `parm1 = 8`, and occupies its own non-overlapping eight-Unit-ID block on `Aux I`:

```text
WF-Tree-01 -> 50-57
WF-Tree-02 -> 58-5F
WF-Tree-03 -> 60-67
WF-Tree-04 -> 68-6F
WF-Tree-05 -> 70-77
WF-Tree-06 -> 78-7F
WF-Tree-07 -> 80-87
WF-Tree-08 -> 88-8F
```

The field-lead rows expose eight logical output rows per Tree, all beginning at circuit/channel 1. This is a clean topology shape for eight distinct Pixie 8 controller blocks.

Each Tree also has a corresponding RGB Star using the second half of the last Unit ID in that Tree's block:

```text
WF-TreeStar-01 -> 57, circuits 151-300
WF-TreeStar-02 -> 5F, circuits 151-300
WF-TreeStar-03 -> 67, circuits 151-300
WF-TreeStar-04 -> 6F, circuits 151-300
WF-TreeStar-05 -> 77, circuits 151-300
WF-TreeStar-06 -> 7F, circuits 151-300
WF-TreeStar-07 -> 87, circuits 151-300
WF-TreeStar-08 -> 8F, circuits 151-300
```

This keeps each Star inside the same non-overlapping address block as its corresponding Tree. The exact physical string/port connection of the Star should remain a field/controller-inventory detail unless separately documented, but the current addressing clearly preserves eight separate controller blocks.

### FieldWiring implication

For normal field presentation, the raw Unit IDs should not be shown as eight separate physical controllers inside each Tree. The Tree should be presented as one Pixie 8-style physical controller context with numbered Outputs 1-8 when the physical mapping is accepted.

The eight Tree address blocks are already separated well enough in LOR that FieldWiring does not need duplicate-address detection to discover that eight controller instances are present.

## Santa's Workshop — Two Distinct Pixie 8 Address Blocks

The current Master Musical Scene `19-Santa's Workshop-SW` contains two RGB Tree Props on `Aux D`:

```text
SW-TreeRGB-LH -> 10-17
SW-TreeRGB-RH -> 18-1F
```

Both are `string_type = RGB` and carry `parm1 = 8`, producing eight logical output rows per Tree.

The corresponding Stars use the second half of the last Unit ID in each block:

```text
SW-StarRGB-LH -> 17, circuits 151-300
SW-StarRGB-RH -> 1F, circuits 151-300
```

This is a clean current topology shape for two distinct Pixie 8 controller blocks:

```text
Left controller block  -> 10-17
Right controller block -> 18-1F
```

### FieldWiring implication

FieldWiring can treat these as two separate Pixie 8-style controller contexts for operator presentation once the physical mapping is accepted. The operator should work in physical Output 1-8 terms rather than raw Unit IDs `10-17` / `18-1F`.

The raw Unit-ID blocks remain available in engineering details.

## Pattern Classes Now Observed

Current MSB examples now demonstrate several distinct valid RGB controller patterns:

```text
1. One RGB Prop spans one controller's outputs
   Church Tree: one Pixie 16, 30-3F

2. One RGB Display spans a small controller block
   Church Crosses: Pixie 2 patterns

3. Multiple physical controllers intentionally repeat one address block
   Church Candy Canes: two Pixie 4 controllers, both 21-24
   Candyland Candy Canes: three Pixie 4 controllers, each 21-24 after live correction

4. Multiple physical controllers use clean non-overlapping address blocks
   Who Forest: eight Pixie 8 blocks
   Santa's Workshop: two Pixie 8 blocks
```

FieldWiring therefore cannot use one universal `Controller = Unit ID` rule for RGB. It must interpret the physical-output pattern while preserving LOR as the topology authority.

## Controller Inventory Boundary

The current Controller Inventory source has not yet been inspected in this workstream.

Until that source is available:

- do not design the final controller PostgreSQL schema;
- do not invent permanent controller identities;
- do not make LOR Unit ID/range the controller primary identity;
- continue using accepted current topology patterns for FieldWiring prototypes where the physical interpretation is clear; and
- keep raw LOR addressing available for engineering traceability.

Controller Inventory will ultimately replace temporary controller-group descriptions with permanent physical controller identities, models, output counts, labels, and deployment relationships.

## Acceptance Use

These cases should be retained as FieldWiring controller/output presentation tests:

- `07a-Who Forest-WF` — eight independent Pixie 8-style address blocks;
- `19-Santa's Workshop-SW` — two independent Pixie 8-style address blocks;
- Church Tree — Pixie 16 output derivation;
- Church Crosses — Pixie 2 output derivation;
- Church Candy Canes — repeated-address Pixie 4 grouping; and
- Candyland Candy Canes — three repeated-address Pixie 4 groups after the live LOR correction.
