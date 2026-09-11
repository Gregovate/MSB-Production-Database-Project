# Setup Predecessor and Readiness Contract — 2026-09-09

| Document Control | Value |
|---|---|
| Document Type | Engineering Contract / Live Review Finding |
| System | Production Database — Setup and Deployment |
| Status | CURRENT DESIGN AUTHORITY — task predecessor interaction accepted in V0.3.9; structured readiness pending |
| Owner | MSB Production Database engineering |
| Related Work | Issue #122; Issue #145; Issue #151 |

## Purpose

Preserve the operator-confirmed distinction between reusable task predecessors, preferred order, and external/site readiness so future Setup work does not reconstruct these rules from chat or historical task order.

The 2025 reconstruction intentionally reset reusable dependencies because the imported predecessor set was not trustworthy. Dependency relationships must be rebuilt from reviewed operational knowledge.

Issue #151 completed the Production interaction for efficient prerequisite entry and persistent prerequisite review/display order. Structured readiness remains separate future work.

## Three Different Concepts

### Hard predecessor

A hard predecessor is another reusable Setup task that must be complete before the dependent task can proceed.

Stage 00 example:

```text
Lay Cords
    hard predecessor -> Setup HWY42 Traffic Signs
    hard predecessor -> Setup HWY42 MSB and Rotary Signs
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
- access available; or
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

## Accepted Efficient Predecessor Editing — V0.3.9

The prior prerequisite selector/button workflow was too cumbersome for the large review pass. Issue #151 established the accepted Production interaction.

### Shift-drag direction

```text
hold Shift before left-button-down on the later/dependent task A
    -> drag A onto prerequisite task B
    -> release over B
    -> create A depends on B
    -> neither task moves
```

The gesture is implemented with a custom pointer-driven interaction rather than relying on native HTML5 modifier-drag semantics. The native Shift+HTML5 drag attempt was rejected during browser review because Shift prevented the expected `dragstart` behavior on the actual Windows/browser client.

Accepted requirements:

- Shift must be held before left-button-down on the dependent task;
- the target is visibly distinguished as the intended prerequisite;
- neither task moves during the dependency gesture;
- explicit success/failure feedback names the dependency direction;
- multiple prerequisites may be stacked on one dependent task;
- repeating an existing dependency remains idempotent and does not create duplicate state;
- database circular-dependency protection remains authoritative;
- releasing over empty Stage/Scene space cancels the dependency gesture without moving the task; and
- modifier-drag applies only to task predecessors, not readiness conditions.

### Ordinary drag remains movement/reorder/scope

Unmodified left-drag preserves the existing reusable-task reorder and Stage/real-Scene movement behavior.

The modifier is the switch:

```text
left-drag          -> normal move/reorder/scope behavior
Shift + left-drag  -> create predecessor relationship; do not move either task
```

This distinction passed both disposable browser review and real protected Production browser acceptance.

## Canonical Prerequisite Editor

Task detail contains one canonical prerequisite list. Each current prerequisite appears once with:

- position;
- **Up**;
- **Down**; and
- **Remove**.

A separate manual **Add prerequisite** form remains available as a fallback/precision entry method. Already-assigned prerequisites are excluded from the available Add choices for that task.

After add/remove/reorder, the application reloads authoritative dependency state so task detail and the Catalog `Requires` line redraw from the same relationship rows.

This avoids the earlier review defect where prerequisite state could be duplicated in the UI or become visually stale between detail and Catalog views.

## Persistent Prerequisite Review Order

Migration 026 is the accepted Production schema authority for prerequisite review/display order:

```text
Setup/Database/026_add_setup_dependency_order.sql
```

It adds:

```text
ref.setup_task_dependency.sort_order integer NOT NULL DEFAULT 100
ref.reorder_setup_task_dependencies(text,bigint,bigint[])
```

Ordering semantics are deliberately narrow:

```text
prerequisite Up/Down = review/display order only
```

It does **not** mean:

```text
prerequisite 1 depends on prerequisite 2
```

Every listed prerequisite remains independently required by the dependent task.

Existing dependency rows received the constant schema default without a mass UPDATE, preserving their existing note/audit actor/timestamp evidence. While existing rows share the initial default, prerequisite task Catalog order remains the deterministic tie-break until a Manager intentionally reorders the list.

The first intentional Manager reorder writes 10/20/30/... through the governed command. New dependencies append after the current list.

`fieldwiring_app` receives EXECUTE on the narrow governed reorder function and retains no broad INSERT/UPDATE/DELETE privilege on `ref.setup_task_dependency`.

## Governed Write Boundary

Task dependency creation/removal continues through:

```text
ref.set_setup_task_dependency(text,bigint,bigint,text,boolean)
```

Reordering uses:

```text
ref.reorder_setup_task_dependencies(text,bigint,bigint[])
```

Do not add direct browser/application table DML for prerequisite maintenance.

Circular-dependency protection remains in the governed dependency command and is authoritative even if the browser also performs earlier UX validation.

## Production Acceptance Evidence

Issue #151 accepted runtime:

```text
SHA     = 55478f98f760473b65b5d700a84c868285022ab7
version = V0.3.9-predecessor-drag
PR      = #164
merge   = ebade21e15a9ac62728dca0655476a619b47516d
```

Migration 026 Production validation proved:

```text
existing dependency rows              = 17
initial sort_order range               = 100 / 100
legacy dependency audit fingerprint    = 26b170fba3500ea2647967e87aa02a1c before/after
governed Setup fingerprint             = 9510360aa7de2da59d1ed8a9ad9d69f7 before/after
reorder EXECUTE for fieldwiring_app    = PASS
broad dependency table DML             = NO
```

Focused exact-candidate and live deployed regressions both passed 63 tests. Final protected Production browser acceptance passed Shift-drag, canonical prerequisite presentation, manual Add behavior, and ordinary movement behavior.

See `Setup/Acceptance/Setup_Predecessor_V039_Production_Acceptance_2026-09-11.md`.

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

Use Shift-drag or the manual prerequisite editor only for the **HARD PREDECESSOR** case.

## 2026 Session Gate

**Do not create the 2026 Setup Session until the reconstructed reusable Catalog and predecessor/readiness model are ready enough for planning.**

This gate includes Issue #145: every active reusable task is seeded into a newly created annual Setup Session, so confirmed reconstruction duplicates must be removed or deactivated before 2026 creation.

Issue #151 completes efficient hard-predecessor editing; it does not complete structured readiness or the Catalog-cleanup gate.

## Remaining Implementation Gate — Structured Readiness

Before Production implementation of structured readiness:

1. keep readiness conditions separate from reusable task dependencies;
2. support one readiness condition gating multiple tasks;
3. support independent readiness by work area;
4. prove the Stage 00 HWY42 condition blocks affected work until READY;
5. ensure readiness conditions do not appear as completed Setup work or crew/reporting tasks; and
6. perform protected browser validation before Production acceptance.

Do not reopen the accepted V0.3.9 predecessor interaction merely because structured readiness remains unfinished.

## Related Durable Sources

- [Setup V0.3.9 Prerequisite Production Acceptance](../../../../../Setup/Acceptance/Setup_Predecessor_V039_Production_Acceptance_2026-09-11.md)
- [Setup Planning Operating Model](Setup_Planning_Operating_Model_2026-09-08.md)
- [Setup Stage / Scene Material Resolution Contract](Setup_Stage_Scene_Material_Resolution_Contract_2026-09-10.md)
- [Setup engineering portal](README.md)
- GitHub Issue #122
- GitHub Issue #145
- GitHub Issue #151
