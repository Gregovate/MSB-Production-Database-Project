# Controller Inventory Stage-Wide Controller Context Requirement — 2026-08-30

| Document control | Value |
|---|---|
| Status | CURRENT PRE-DDL APPLICATION / WORKFLOW REQUIREMENT |
| Subsystem | Controller Inventory |
| Parent framework | [Controller Inventory Application, Backfill, and Operations Framework — 2026-08-30](Controller_Inventory_Application_Backfill_and_Operations_Framework_2026-08-30.md) |
| PostgreSQL DDL | NOT AUTHORIZED by this document |

## Purpose

This document corrects an important application-boundary assumption exposed by direct comparison with the current FieldWiring presentation for Stage 17 Candyland.

FieldWiring intentionally presents wiring by the selected LOR presentation context, including separate `Background / Static` and `Musical` views. That separation is necessary for field hookup because the operator is viewing the wiring relationships carried by a particular current LOR Preview/Scene context.

Controller Inventory has a different operational purpose. Its Stage/Display workbench must show the physical controller inventory for the Stage as a whole. It must therefore **not** inherit FieldWiring's Background/Static-versus-Musical split as a controller-inventory boundary.

## Accepted Requirement

When an operator selects a Stage in Controller Inventory, the application must assemble the Stage-wide set of current physical-controller contexts across all current approved LOR/V7 Preview/Scene wiring contexts that resolve to that Stage.

Conceptually:

```text
selected ref.stage.stage_id
    -> all current approved LOR/V7 Preview / Scene contexts for that Stage
    -> all controller-bearing wiring contexts represented in those sources
    -> family-specific physical-controller grouping / resolution
    -> deduplicate contexts that resolve to the same physical controller
    -> Stage-wide Controller Inventory workbench
```

The Stage-wide result is not simply the sum of FieldWiring presentation-group counts.

FieldWiring groups may include fixture/presentation constructs that are not separate Controller Inventory assets, and the same physical controller may appear in more than one LOR presentation context. Controller Inventory must classify and resolve physical assets rather than count presentation rows.

## Candyland Evidence

Current Stage 17 Candyland FieldWiring demonstrates the problem clearly.

The Musical view currently shows a substantially larger set of controller/presentation contexts, including examples such as:

```text
A/C controller Unit IDs 60, 61, 62
repeated Pixie4 groups 1, 2, 3
review-required Pixie grouping
DMX / DumbRGB presentation groups
Mega Ball E1.31 controller
Mega Star E1.31 Controller 1
Mega Star E1.31 Controller 2
additional controller groups below the visible viewport
```

The Background/Static view separately shows conventional controller contexts including Unit IDs 62, 63, and 64.

For Controller Inventory, Stage 17 must not require the user to toggle between those two FieldWiring modes to discover physical controllers. The Controller workbench must aggregate the controller-bearing evidence from both and present one Stage-wide physical inventory/coverage view.

## Required Application Behavior

The main Controller Inventory Stage/Display workbench should therefore look conceptually like:

```text
Stage: 17-Candyland-CL

CONTROLLER COVERAGE — ALL CURRENT STAGE CONTEXTS

Physical controller/context                Coverage
--------------------------------------------------
A/C controller context - Unit ID 60       Assigned / Missing / Review
A/C controller context - Unit ID 61       Assigned / Missing / Review
A/C controller context - Unit ID 62       Assigned / Missing / Review
A/C controller context - Unit ID 63       Assigned / Missing / Review
A/C controller context - Unit ID 64       Assigned / Missing / Review
Candy Canes 1-4 - Pixie4                  Assigned / Missing / Review
Candy Canes 5-8 - Pixie4                  Assigned / Missing / Review
Candy Canes 9-12 - Pixie4                 Assigned / Missing / Review
Mega Ball controller context              Assigned / Missing / Review
Mega Star controller context 1            Assigned / Missing / Review
Mega Star controller context 2            Assigned / Missing / Review
...
```

This is illustrative. The actual result must come from current approved LOR/V7 evidence plus accepted physical-controller grouping; it must not hard-code this list.

## Preview / Scene / Wiring Mode Remains Evidence, Not Inventory Ownership

Background/Static, Musical, Preview, and Scene information remains useful provenance and troubleshooting evidence.

For an individual controller or unresolved candidate, the application may expose technical details such as:

```text
Source evidence
    Preview: <name>
    Scene: <name, if applicable>
    wiring mode: Musical / Background-Static
    Network / UID / universe / output evidence
```

That source context helps explain why the physical-controller candidate exists and helps reconcile changes after a new LOR ingest.

It must not create separate permanent controller identities merely because the same physical asset participates in more than one Preview/Scene context.

## Deduplication Rule

The application must not assume:

```text
one FieldWiring presentation group = one physical controller
```

Instead:

```text
LOR presentation contexts
    -> controller-family interpretation
    -> accepted physical grouping
    -> permanent controller_id where assigned
```

Once a permanent `controller_id` is assigned, that controller should appear once in the Stage-wide inventory even if multiple current LOR contexts provide evidence for it.

Before backfill is complete, multiple source contexts believed to describe the same physical box may be presented as one proposed controller context only when the existing grouping evidence supports that conclusion. Otherwise preserve `REVIEW_REQUIRED` rather than silently collapsing them.

## Display Lookup Behavior

A Display lookup in the Controller application must likewise show **all permanent/current physical controllers serving that Display**, regardless of which LOR Preview/Scene or wiring mode exposes the relevant wiring relationship.

Example:

```text
FT-MegaStar
    -> physical controller 1
    -> physical controller 2
```

The user should not need to know which presentation context contains each relationship in order to see that the Display requires two physical controllers.

## DDL Consequence

This requirement means the first Controller Inventory DDL must not model current deployment as if one controller assignment belongs to exactly one LOR Preview, Scene, or wiring mode.

The durable physical relationships remain centered on permanent Production Database identities such as:

```text
controller_id
stage_id as current deployment/browse context when needed
display_id through the accepted many-to-many relationship
ref.location for current physical location
```

LOR Preview/Scene/mode belongs in the current reconciliation/resolution provenance needed to explain or validate the physical mapping, not in permanent physical-controller identity.

A future controller-to-current-LOR resolution structure may need to associate one physical `controller_id` with multiple current source contexts for the same approved snapshot. The exact table shape remains a Pre-DDL decision.

## FieldWiring Boundary

This requirement does not change FieldWiring.

FieldWiring should continue to present the selected current wiring context exactly as required for hookup work, including its Background/Static-versus-Musical distinction.

The separation is:

```text
FieldWiring
    -> what wiring applies in this selected LOR presentation context?

Controller Inventory
    -> what physical controllers belong to / serve this Stage or Display across all current contexts?
```

## Rule Established

> Controller Inventory Stage/Display browsing is Stage-wide physical inventory coverage. It aggregates controller-bearing evidence across all current approved LOR/V7 Preview/Scene/wiring contexts for the selected Stage, resolves/deduplicates those contexts into physical controller candidates or permanent controller IDs, and does not require the operator to reproduce FieldWiring's Background/Static-versus-Musical split. Presentation context remains reconciliation provenance and technical evidence, not physical inventory ownership.
