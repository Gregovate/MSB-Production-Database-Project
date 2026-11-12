# FieldWiring RGB Controller Pattern Findings — 2026-08-19

| Item | Value |
|---|---|
| Status | ENGINEERING FINDINGS — V7 + controller-inventory evidence |
| Sub-project | FieldWiring |
| Scope | RGB/Pixie physical-output interpretation |
| Controller Inventory | 2025 source inspected; reconciliation required |
| Schema status | No schema change authorized |

## Purpose

This document records real MSB RGB/Pixie patterns used to validate the FieldWiring physical-controller/output presentation contract.

The 2025 controller inventory source has now been inspected in addition to current V7 topology.

See [Controller Inventory 2025 Source Audit — 2026-08-19](../08_Controller_Inventory/Controller_Inventory_2025_Source_Audit_2026-08-19.md).

## Who Forest — Eight Pixie 8 Controllers Confirmed by Two Sources

The current Master Musical Scene `07a-Who Forest-WF` contains eight RGB Tree Props, each occupying a non-overlapping eight-Unit-ID block:

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

The 2025 controller inventory independently records eight `Pixie8` physical controller rows at Tree 1 through Tree 8 with those same eight address ranges.

This is strong confirmation that FieldWiring may treat these as eight distinct Pixie 8 physical controller contexts and present Outputs 1-8 rather than exposing each Unit ID as a separate controller.

Each Tree also has a corresponding RGB Star inside the same LOR address block, using the second half of the final Unit ID in that block.

### Reconciliation item — Tree 4 network

The current V7 topology reviewed for Who Forest uses `Aux-I` for the Tree block.

The 2025 controller inventory records Tree 4 (`68-6F`) on `Aux-F` while Trees 1-3 and 5-8 are recorded on `Aux-I`.

Do not silently change either source. This is now a concrete source-reconciliation item.

## Santa's Workshop — Current Pixie 8 Topology Exists but 2025 Inventory Is Missing the Two Tree Controllers

The current Master Musical Scene `19-Santa's Workshop-SW` contains two RGB Tree Props:

```text
SW-TreeRGB-LH -> 10-17
SW-TreeRGB-RH -> 18-1F
```

Both are `string_type = RGB` and produce eight logical output rows per Tree, consistent with two Pixie 8 controller contexts.

The 2025 controller inventory does not contain matching `Pixie8` rows for these two Tree controllers.

It does contain other Santa's Workshop controller records, including two E1.31 `Pixicon-16` devices for the Gift Conveyor / Gift Bag and conveyor rollers.

Therefore FieldWiring can continue using the accepted V7 physical interpretation for the two Tree blocks, but the missing inventory rows must be resolved during controller-inventory reconciliation.

## Church and Candyland — Current RGB Controllers Are Newer/Absent from 2025 Inventory

Current reviewed FieldWiring patterns include:

```text
Church Tree
    one Pixie 16
    30-3F

Church Crosses
    Pixie 2 controllers

Church Candy Canes
    two Pixie 4 controllers
    repeated 21-24 blocks

Candyland Candy Canes
    three Pixie 4 controllers
    repeated 21-24 blocks
```

These current RGB controller patterns are not represented as corresponding physical Pixie rows in the 2025 inventory source.

This confirms that the 2025 inventory is valuable but incomplete relative to the current 2026 Preview topology.

## Pattern Classes Now Observed

Current MSB examples demonstrate several distinct valid RGB controller patterns:

```text
1. One RGB Prop spans one controller's outputs
   Church Tree: one Pixie 16, 30-3F

2. One RGB Display spans a small controller block
   Church Crosses: Pixie 2 patterns

3. Multiple physical controllers intentionally repeat one address block
   Church Candy Canes: two Pixie 4 controllers, both 21-24
   Candyland Candy Canes: three Pixie 4 controllers, each 21-24

4. Multiple physical controllers use clean non-overlapping address blocks
   Who Forest: eight Pixie 8 blocks, independently confirmed in 2025 inventory
   Santa's Workshop: two Pixie 8 blocks in current V7, missing from 2025 inventory
```

FieldWiring therefore cannot use one universal `Controller = Unit ID` rule for RGB.

It must interpret the physical-output pattern while preserving LOR as the topology authority and use controller inventory as physical-asset enrichment rather than as competing topology.

## Controller Inventory Boundary

The 2025 controller inventory has now been inspected, but it does not yet provide the permanent physical controller identity model FieldWiring ultimately needs.

The source uses deployment/addressing values such as single Unit IDs, ranges, paired IDs, `IP`, Display assignment, and Park Location. It also contains model naming variants and missing/currently stale rows.

Until reconciliation is complete:

- do not design the final controller PostgreSQL schema from the 2025 source alone;
- do not invent permanent controller identities;
- do not make LOR Unit ID/range the controller primary identity;
- continue using accepted current topology patterns for FieldWiring prototypes where the physical interpretation is clear;
- use inventory rows as corroborating physical/deployment evidence; and
- keep source conflicts visible for review.

## Acceptance Use

Retain these FieldWiring controller/output presentation tests:

- `07a-Who Forest-WF` — eight independent Pixie 8 physical controller contexts, confirmed by V7 + inventory;
- Who Forest Tree 4 — explicit inventory/V7 network reconciliation case;
- `19-Santa's Workshop-SW` — two independent Pixie 8 current V7 blocks missing from 2025 inventory;
- Church Tree — Pixie 16 output derivation;
- Church Crosses — Pixie 2 output derivation;
- Church Candy Canes — repeated-address Pixie 4 grouping; and
- Candyland Candy Canes — three repeated-address Pixie 4 groups after the live LOR correction.
