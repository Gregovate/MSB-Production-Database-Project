# Setup #206 Post-Launch Material Authority Checkpoint — 2026-09-28

| Field | Value |
|---|---|
| Commanding issue | #122 |
| Owning implementation issue | #206 |
| Existing source-maintenance authority | #198 |
| General Container expected-content owner | #230 |
| Draft PR | #252 |
| Working branch | `agent/setup-206-tablet-material-audit` |
| Branch implementation state captured before this checkpoint commit | `94a413fb47287d3828aee789ffcafe2cd677e675` |
| Branch base / current main at checkpoint | `dfdad20328c825862d3c6d29b35bb43370d25e7c` |
| Branch status at checkpoint | 0 behind main; mergeable; draft |
| Production mutation authorized | **NO** |

## Purpose

This file is the durable continuation point for the post-launch #206 material-authority correction.

**Do not restart this work from the original Pick List problem statement.**
Continue from this checkpoint and PR #252.

The work grew from two post-launch findings:

1. the Rolling Pick List was unusable on the 10-inch Hotwav because the tablet breakpoint forced a wide desktop table; and
2. picker-facing unsourced Extra Material warnings exposed deeper first-season material-authority cleanup.

The operator intentionally wants to perform this cleanup during 2026 Setup while the physical material is being handled. The 2027 inventory program remains future work; the 2026 system must provide a safe place to correct authority now.

---

## Settled Operator Decisions

### Rolling Pick List

```text
Rolling Pick List
    = actionable physical picks only
```

Unsourced/reconstructed material authority does **not** belong on the picker surface.

### Extra Material requirement

A new reusable-task Extra Material requirement is not valid operational authority unless its physical source is known.

```text
New task Extra Material
    -> source Container REQUIRED at creation
    -> task requirement + source allocation saved atomically
```

Do **not** allow future source-less task Extra Material creation.

### Mistakes

A mistaken/redundant reusable-task Extra Material requirement must be **hard deleted**.

```text
mistake
    -> delete it
    -> do not preserve an inactive task-requirement tombstone
    -> do not carry the mistake into future Sessions/audits
```

The Extra Material catalog identity, real Displays, Container expected contents that have independent authority, and physical inventory history are separate facts.

### Bidirectional task / Kit authority

The same existing source-allocation relationship is the bridge:

```text
ref.setup_task_extra_material
    -> ref.setup_task_extra_material_source
        -> ref.container
```

Task-side workflow:

```text
Setup task
    -> Add Extra Material
    -> choose source Container
    -> save requirement + source together
    -> ensure matching Container expected-content row exists
```

Kit-side workflow:

```text
Kit Inventory item
    -> Used by task(s)
    -> links back to exact reusable task requirement

no task-source relationship
    -> NO TASK USE / orphan review
```

For shared Kits this is important because it identifies which Kit material is used by which task.

Do not create a second task/Kit usage table.

---

## Current Concrete Reconciliation Cases

### Church RGB Plywood — redundant procedure-derived Extra Material

Production facts established by operator:

- Display 314 — `CH-RGBTree-BasePlywood-01`
- Display 315 — `CH-RGBTree-BasePlywood-02`
- both are first-class LOR/Display identities;
- both are stored in Container 131 — Antenna Trailer;
- they are already included in Church RGB Display material resolution;
- task #73 also has reconstructed Extra Material requirement #15:
  - material = Plywood
  - quantity = 2 SHEET
  - size = 3/4 in x 4 ft x 8 ft
  - source = none

Interpretation:

The plywood appeared in the old procedure because there was previously no first-class tracking path. It is now modeled correctly as Displays. The Extra Material requirement is redundant and should be deleted as a reconstruction mistake, not assigned another source.

### Northern Lights T-Posts — source authority stranded on old requirement

Production query established:

- old requirement #36 / task #132 — Setup Northern Lights:
  - requirement inactive;
  - 66 EA, 3 FT, VERIFIED;
  - four active source rows remain:
    - C16 = 16
    - C17 = 16
    - C18 = 18
    - C19 = 16
  - total = 66;
- active requirement #52 / task #140 — Layout Light Locations and install 66 T-Posts:
  - active;
  - 66 EA, 3 FT;
  - no active source rows;
- Kit/Container expected-content authority already represents those T-Posts on the Northern Lights Containers.

Interpretation:

The work/material requirement moved from old task #132 to current task #140, but the source links remained on the obsolete requirement. Correct repair is to **reassign the existing source rows to requirement #52**, not create duplicate source rows or duplicate Kit contents.

---

## PR #252 — Implemented So Far

### 1. Pick List tablet correction

Current candidate removes the forced tablet desktop width and changes the Pick List to a responsive card/grid at tablet widths.

Preserve:

- large Container / Display identity;
- large Home Location;
- Destination;
- Pick By;
- Needed For;
- QR;
- reason rows below each physical item.

Desktop and print layouts have explicit resets.

### 2. Pick List material exceptions removed

Picker-facing:

- `Material data exceptions` panel removed;
- material-exception summary count removed.

The material-readiness backend may still detect unresolved authority for engineering/audit purposes, but the picker is not asked to resolve it.

### 3. Material Completeness Audit — Extra Material Source Coverage

PR #252 adds one audit row per active underlying `setup_task_extra_material_id`, not per scheduled occurrence.

Columns include:

- Stage / Scene;
- reusable task;
- Extra Material;
- required quantity / UOM / specification;
- verification state;
- source status;
- correction actions.

Unsourced material requirements count in the top-level unresolved result.

Current source classifications include:

- `SOURCE_ASSIGNED`;
- `HISTORICAL_SOURCE_REVIEW`;
- `RECONSTRUCTION_REVIEW`;
- `NO_ACTIVE_SOURCE`.

### 4. Historical source reassignment

The audit reads active source rows attached to inactive requirements for the same material / Stage context.

The candidate exposes the existing source-row identity and supports **Reassign Cxx** by PATCHing the existing #198 source row to the current requirement.

This reuses:

`ref.set_setup_task_extra_material_source(...)`

It does not create a second source table or source write command.

### 5. Requirement review / reconstruction cleanup

Audit correction provides both:

- **Review Requirement**
- **Resolve Source**

Reconstruction/preload rows are not assumed to need a source. They may instead be mistakes/redundancies that need deletion.

### 6. Task-side source visibility

The reusable task Extra Material table now displays actual source Containers directly on each requirement row and exposes **Add Source / Review Sources** via the existing #198 source editor.

The old instruction that sources are merely “maintained separately below” is being removed.

### 7. Source-required creation

Current branch application/API/repository work requires a source Container for new task Extra Material creation.

The current implementation performs, in one database transaction:

1. create task Extra Material requirement via existing governed requirement command;
2. create source allocation via existing governed source command;
3. ensure matching Container expected-content authority exists;
4. commit only when the whole operation succeeds.

If source/container expected-content creation fails, the requirement creation rolls back.

### 8. Hard delete of mistakes

New migration candidate:

`Setup/Database/063_harden_setup_extra_material_requirement_lifecycle.sql`

adds governed command:

`ref.delete_setup_task_extra_material(text,bigint,bigint)`

Intent:

- hard-delete mistaken task requirement;
- remove task-source rows tied to that mistaken requirement;
- do not turn the mistake into an inactive task requirement;
- preserve unrelated catalog / Display / inventory authority.

Disposable validation candidate:

`Setup/Acceptance/setup_206_extra_material_lifecycle_disposable_validation.sql`

### 9. Kit Inventory reverse usage

Current branch Kit Inventory work adds **Used by task(s)** projection using existing source rows.

Expected Container content rows expose:

- exact reusable task(s) using the material;
- exact task requirement identity;
- Stage;
- source expected quantity.

Rows with no active task use show:

`NO TASK USE`

New Kit expected-content creation requires selecting the active task requirement that uses it. This is intended to prevent new orphan Kit contents.

---

## Durable Data Model — Preserve

Do not replace these:

```text
ref.setup_extra_material
ref.setup_task_extra_material
ref.setup_task_extra_material_source
ref.setup_container_extra_material
ops.setup_extra_material_inventory_event
```

Semantics:

```text
setup_extra_material
    = normalized material family

setup_task_extra_material
    = reusable task demand

setup_task_extra_material_source
    = task demand -> physical source Container

setup_container_extra_material
    = Container expected contents

setup_extra_material_inventory_event
    = physical count / movement/change history
```

These are related but not interchangeable facts.

---

## Ownership Boundaries

### #122

Commanding Setup integration authority.

### #206

Owns:

- Pick List material-readiness consumption;
- this post-launch tablet correction;
- Material Audit source-coverage integration;
- current first-season material-authority reconciliation workflow.

### #198

Owns accepted Expected Source Container maintenance behavior.

Reuse its source API / governed command.

### #230

Owns general non-Kit Container expected-content Manager maintenance.

Do not change a Container type just to make it editable.

---

## Do Not Do

- do not fabricate source Containers to clear the audit;
- do not make Pick List display Manager material-authority errors again;
- do not infer that every reconstructed row needs a source;
- do not carry known mistakes forward as inactive task requirements;
- do not create a second source-allocation table;
- do not create a second task/Kit usage relationship;
- do not treat Display-modeled physical components as Extra Material merely because an old procedure names them;
- do not duplicate historical Northern Lights source rows when they can be reassigned;
- do not mutate Production until disposable migration/validation/browser acceptance is complete.

---

## Immediate Next Work — Continue Here

1. **Do not restart reconnaissance.** Use this checkpoint and current PR #252.
2. Finish contract tests for:
   - source-required task creation;
   - atomic requirement + source + matching Container expected-content creation;
   - hard-delete semantics;
   - no inactive requirement carry-forward;
   - Kit Inventory reverse `Used by task(s)`;
   - Kit Inventory prevention of orphan expected contents;
   - historical source-row reassignment;
   - reconstructed mistake delete path.
3. Run full `Setup/Application` regression.
4. Run migration 063 + lifecycle disposable validation on a disposable current-Production clone.
5. Browser review:
   - Church RGB Plywood can be hard deleted as a mistake;
   - Northern Lights C16/C17/C18/C19 sources can be reassigned from old #36 to current #52 without duplicate source rows;
   - adding a new task Extra Material requires a source Container;
   - task-side save ensures matching Container expected contents;
   - Kit Inventory shows Used by task(s);
   - Kit Inventory refuses new orphan expected content;
   - Pick List remains picker-actionable only.
6. Tablet Pick List real-device acceptance remains post-deploy unless a governed non-localhost preview mechanism is deliberately added; do not weaken the current SSH preview tunnel just for tablet access.

---

## Production State

No Production mutation is authorized or performed by PR #252 at this checkpoint.

The branch is an implementation candidate only.


---

## Continuation Checkpoint — Thread Rollover / Regression Review

| Field | Value |
|---|---|
| Implementation head before this checkpoint update | `3cc5dbb286e10f1b74831476dec0b450bcf80ab4` |
| Branch | `agent/setup-206-tablet-material-audit` |
| Main comparison at review | 61 ahead / 0 behind |
| Merge status | mergeable at review |
| Production mutation authorized | **NO** |

### Contract-test status correction

The earlier **Immediate Next Work** list said to finish the #206 lifecycle/source/Kit contract tests. Static recovery of the actual branch and recent commit history showed those contracts were already written before the first checkpoint:

- source-required task Extra Material creation;
- atomic requirement + source + matching Container expected-content creation;
- hard-delete semantics and no inactive tombstone;
- Kit Inventory reverse **Used by task(s)**;
- Kit orphan-prevention creation path;
- historical source-row reassignment through the accepted #198 command;
- reconstructed mistake review/delete path;
- bounded hard-delete/disposable proof.

Therefore, do **not** restart those tests as implementation work. The next gate is execution/regression plus disposable acceptance.

### Regression found and corrected during continuation

Static review found that the first orphan-prevention implementation put the task-requirement requirement on the generic:

`POST /api/setup/containers/<container_id>/extra-materials`

That accidentally made every Container behave like a Kit Box. It would break the accepted non-Kit expected-content path used by T-Post/shared-stock flows and would cross the #230 ownership boundary.

Correction committed at `3cc5dbb286e10f1b74831476dec0b450bcf80ab4`:

- resolve the target Container first;
- when `container_type_id != 2`, preserve the accepted generic `set_container_content(...)` behavior;
- when `container_type_id == 2`, require `setup_task_extra_material_id` and use the atomic Kit task/source/content path;
- add a regression contract proving existing T-Post/shared-stock bootstrap does not require a reusable-task requirement merely to establish non-Kit Container contents.

This is a scope correction, not a redesign.

### Next Gate

Continue from this checkpoint and the current PR head. Do not restart #206 implementation.

1. Run the full `Setup/Application` regression against the current branch.
2. Fix only failures attributable to this candidate.
3. Run migration 063 and `setup_206_extra_material_lifecycle_disposable_validation.sql` on a governed disposable current-Production clone.
4. Perform the browser review already listed above.
5. Write the next checkpoint with exact regression/acceptance results before any Production deployment decision.

No Production data mutation has been authorized or performed by this continuation.
