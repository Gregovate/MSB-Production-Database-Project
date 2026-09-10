# Setup Predecessor and Readiness Contract — 2026-09-09

| Document Control | Value |
|---|---|
| Document Type | Engineering Contract / Live Review Finding |
| System | Production Database — Setup and Deployment |
| Status | CURRENT DESIGN AUTHORITY — structured readiness implementation pending |
| Owner | MSB Production Database engineering |
| Related Work | Issue #122; PR #125; PR #138 |

## Purpose

Preserve the operator-confirmed distinction between reusable task predecessors, preferred order, and external/site readiness so future Setup work does not reconstruct these rules from chat or historical task order.

The 2025 reconstruction intentionally reset reusable dependencies to zero because the imported predecessor set was not trustworthy. The next dependency pass must rebuild only reviewed relationships.

## Three Different Concepts

### Hard predecessor

A hard predecessor is another reusable Setup task that must be complete before the dependent task can proceed.

Stage 00 example:

```text
Lay Cords #67
    hard predecessor -> Setup HWY42 Traffic Signs #195
    hard predecessor -> Setup HWY42 MSB and Rotary Signs #66
```

These are real Setup tasks and belong in the governed reusable dependency relationship.

### Preferred order

Preferred order means one task is normally better to do before another, but field conditions may justify changing the sequence.

Do not convert historical sequence into a hard dependency unless the earlier task is truly required.

### Readiness condition

A readiness condition is **not a Setup task**. It represents an external/site condition MSB does not perform or does not want to treat as Setup work.

Examples:

- mowing/mulching complete in the applicable work area;
- leaves cleared in the applicable work area;
- outside construction/road work clear;
- access available;
- another site condition controlled by an external party.

Do not fabricate `Grass Cutting Complete` or similar Setup tasks merely to create a blocker. Such a fake task would create misleading completion/reporting history for work MSB did not perform.

## Structured Readiness Is Required

The current free-form `readiness_note` is not sufficient as the long-term control mechanism.

It can describe a condition, but free text cannot reliably answer:

- which tasks share the same condition;
- whether that condition is currently satisfied;
- which work is blocked by it; or
- when one readiness change should release several tasks.

The required design is a **structured reusable readiness condition** that can be linked to one or more reusable tasks, with separate annual/current readiness state.

Conceptually:

```text
Reusable readiness condition
    "Mowing/mulching complete — Stage 00 HWY42 work area"

linked tasks
    -> Lay Cords
    -> Network hookup
    -> Testing

annual/current state
    -> NOT READY / READY
    -> optional actor/time/note as appropriate
```

This is a condition record, not a Setup task. It should not appear as completed Setup work, consume crew time, or appear in Setup task completion reports.

Exact table/function names remain implementation design work; do not invent Production schema merely from this conceptual contract.

## Area-Specific Grass / Mulch Rule

Grass cutting and mulching readiness is **area-specific**, not park-wide.

Stage 00 can be ready while another part of the park is still being cut or mulched.

For the Stage 00 HWY42 area, the condition must be satisfied before the affected work proceeds, including:

```text
Lay Cords
Network hookup
Testing
```

The condition is tied to that physical work area. Other Stage/Scene/Sub-stage areas need their own readiness state as applicable.

Do not use one global park-wide `Grass Cutting Complete` flag if areas can become ready independently.

## Relationship to Scheduling

A task can have all hard predecessors complete but remain unavailable because a readiness condition is not satisfied.

Conceptually:

```text
hard predecessors complete
    + linked readiness conditions READY
    + crew/equipment/weather practical
    -> task can be AVAILABLE / READY TO SCHEDULE
```

Readiness does not imply predecessor completion, and predecessor completion does not imply readiness.

Weather can influence day-to-day planning separately; do not automatically turn every weather note into a durable readiness condition without an accepted rule.

## Efficient Predecessor Editing

The current prerequisite selector/button is too cumbersome for the large 2025 review pass.

Operator-confirmed desired interaction:

```text
Shift-drag the later/dependent task onto its predecessor
    -> create dependency: dragged task depends on target task
    -> neither task moves
```

Requirements:

- ordinary unmodified drag preserves existing reorder and Stage/Scene movement behavior;
- Shift-drag is visually distinct from normal drag;
- use the existing governed `ref.set_setup_task_dependency(...)` write path;
- database circular-dependency protection remains authoritative;
- show explicit success/failure feedback; and
- modifier-drag applies only to task predecessors, not readiness conditions.

## Reconstruction Rule

Classify sequencing evidence as one of:

```text
HARD PREDECESSOR
PREFERRED ORDER
READINESS CONDITION
```

Examples:

```text
HWY42 signs must be installed before affected cord work
    -> HARD PREDECESSOR

Mowing/mulching complete in the HWY42 work area
    -> READINESS CONDITION

A task is normally done earlier for convenience but can safely move
    -> PREFERRED ORDER
```

## 2026 Session Gate

**Do not create the 2026 Setup Session until the reconstructed 2025 Setup plan is complete.**

Before propagation, known hard predecessors and structured area-specific readiness must be represented well enough that the future planner does not rely on a free-text note and operator memory for critical blockers.

## Implementation Gate

Before Production implementation:

1. preserve current normal drag/reorder/scope behavior;
2. keep readiness conditions separate from reusable task dependencies;
3. support one readiness condition gating multiple tasks;
4. support independent readiness by work area;
5. prove the Stage 00 HWY42 condition blocks Lay Cords, Network hookup, and Testing until READY;
6. ensure readiness conditions do not appear as completed Setup work or crew/reporting tasks;
7. prove Shift-drag creates only the intended directed task dependency and does not move either task;
8. prove unmodified drag remains unchanged; and
9. perform protected browser validation before Production acceptance.

## Related Durable Sources

- [Setup Planning Operating Model](Setup_Planning_Operating_Model_2026-09-08.md)
- [Setup Task Material Resolver Contract](Setup_Task_Material_Resolver_Contract_2026-09-09.md)
- [Setup engineering portal](README.md)
- GitHub Issue #122
