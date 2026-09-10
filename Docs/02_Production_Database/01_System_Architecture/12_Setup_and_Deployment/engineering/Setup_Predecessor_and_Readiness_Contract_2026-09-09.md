# Setup Predecessor and Readiness Contract — 2026-09-09

| Document Control | Value |
|---|---|
| Document Type | Engineering Contract / Live Review Finding |
| System | Production Database — Setup and Deployment |
| Status | CURRENT DESIGN AUTHORITY — structured readiness implementation pending |
| Owner | MSB Production Database engineering |
| Related Work | Issue #122; PR #125; PR #138 |

## Purpose

Preserve the operator-confirmed distinction between reusable task predecessors, preferred order, and annual/site readiness so future Setup work does not reconstruct these rules from chat or historical task order.

The 2025 reconstruction intentionally reset reusable dependencies to zero because the imported predecessor set was not trustworthy. The next dependency pass must rebuild only reviewed relationships.

## Three Different Concepts

### 1. Hard predecessor

A hard predecessor is another reusable Setup task that must be complete before the dependent task can proceed.

Example established during Stage 00 review:

```text
Lay Cords #67
    hard predecessor -> Setup HWY42 Traffic Signs #195
    hard predecessor -> Setup HWY42 MSB and Rotary Signs #66
```

These are real Setup tasks. They belong in the governed reusable dependency relationship and should be evaluated by task completion state.

### 2. Preferred order

Preferred order means one task is normally better to do before another, but field conditions may justify changing the sequence.

Do not turn a historical sequence into a hard dependency merely because the work happened in that order once.

Preferred order belongs in reusable planning/order behavior, not in the hard dependency table unless the prerequisite is truly required.

### 3. Readiness condition

A readiness condition is not another Setup task. It is an external/site/operational condition that must be satisfied before the work is practical.

Examples include:

- mowing/mulching complete in the task's work area;
- leaves cleared in the task's work area;
- access available;
- construction/road work clear;
- weather appropriate for the work;
- required site condition or external dependency satisfied.

Do not fabricate fake Setup tasks such as a single park-wide `Grass Cutting Complete` task merely to express readiness.

## Area-Specific Grass / Mulch Rule

Grass cutting and mulching are **area-specific**, not a single park-wide prerequisite.

Stage 00 may be ready for cord work while another part of the park is still being cut or mulched.

For `Lay Cords #67`, the reusable readiness rule is conceptually:

```text
mowing/mulching complete in the Stage 00 HWY 42 cord-laying area
```

The condition applies to the task/work area, not to the entire park and not to an arbitrary calendar date.

This means the future planner must be capable of representing independent readiness by task/work area.

## Current Production UI Boundary

The current reusable task field `readiness_note` is free-form text.

It is useful now for recording the reusable rule, but it **does not currently block a task from becoming available/schedulable**.

Therefore the current operating workaround is:

```text
reusable task
    -> record normal readiness rule in readiness_note
    -> operator must still apply judgment manually
```

That is not the finished scheduling model.

The future annual Setup Session needs structured readiness state so the reusable task can say **what condition is normally required** and the annual session can say **whether that condition is satisfied this year / right now**.

Conceptual direction:

```text
Reusable task knowledge
    readiness requirement = mowing/mulching complete in this work area

Annual Setup state
    NOT READY / READY
    actor / time / note as appropriate
```

Exact schema and UI controls remain implementation work. Do not invent an unreviewed global readiness table or boolean merely from this document.

## Relationship to Scheduling

A task may have all hard predecessors complete and still be `NOT READY` because the site condition is not satisfied.

Conversely, a readiness condition becoming true does not imply that all task predecessors are complete.

Conceptually:

```text
hard predecessors complete
    + annual readiness satisfied
    + crew/equipment/weather practical
    -> candidate work can be AVAILABLE / READY TO SCHEDULE
```

Preferred order influences which available work is normally chosen next but should not falsely block other valid work.

## Efficient Predecessor Editing

The current prerequisite selector/button is too cumbersome for the large 2025 review pass.

Operator-confirmed desired interaction:

```text
Shift-drag the later/dependent task onto its predecessor
    -> create dependency: dragged task depends on target task
    -> neither task moves
```

Requirements:

- ordinary unmodified drag must preserve existing reorder and Stage/Scene movement behavior;
- Shift-drag must be explicit and visually distinct from normal drag;
- use the existing governed `ref.set_setup_task_dependency(...)` command path;
- circular-dependency protection remains database-governed;
- show explicit confirmation/result so an ambiguous drop never silently creates a dependency;
- do not use modifier-drag for readiness conditions, because readiness is not another reusable task.

Alt-drag was discussed as an alternative modifier, but Shift-drag is the current preferred direction.

## Reconstruction Rule

When reviewing 2022/2025 evidence, classify each sequencing relationship as exactly one of:

```text
HARD PREDECESSOR
PREFERRED ORDER
READINESS CONDITION
```

Do not force all three into the same dependency mechanism.

Examples:

```text
Signs physically must be installed before cords can be laid there
    -> HARD PREDECESSOR

Crew normally does one small job before another for efficiency
    -> PREFERRED ORDER

Mowing/mulching must be complete in the cord-laying area
    -> READINESS CONDITION
```

## 2026 Session Gate

The operator decision remains: **do not create the 2026 Setup Session until the reconstructed 2025 plan is complete.**

Before propagation, the predecessor/readiness pass must be useful enough that known required task dependencies and area-specific readiness are not lost or converted into a misleading rigid schedule.

## Implementation Gate

Before Production implementation of structured readiness or modifier-drag dependency editing:

1. preserve current normal drag/reorder/scope behavior;
2. inventory the reusable tasks being reviewed for hard predecessors;
3. keep readiness conditions distinct from task dependencies;
4. use representative cases including Stage 00 cord laying and at least one weather/access readiness case;
5. prove circular dependency rejection remains intact;
6. prove Shift-drag creates only the intended directed dependency and does not move either task;
7. prove unmodified drag remains unchanged;
8. design annual readiness state separately from the reusable readiness rule; and
9. perform protected browser validation before Production acceptance.

## Related Durable Sources

- [Setup Planning Operating Model](Setup_Planning_Operating_Model_2026-09-08.md)
- [Setup Task Material Resolver Contract](Setup_Task_Material_Resolver_Contract_2026-09-09.md)
- [Setup engineering portal](README.md)
- GitHub Issue #122
