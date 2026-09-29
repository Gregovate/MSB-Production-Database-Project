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


---

## Continuation Checkpoint — Regression Hardening Complete

| Field | Value |
|---|---|
| Implementation head before this checkpoint update | `f4194700881a6143caf120652519ea13d4663097` |
| Branch | `agent/setup-206-tablet-material-audit` |
| Main comparison | 64 ahead / 0 behind |
| PR state | open, draft, mergeable |
| Production mutation authorized | **NO** |

### Additional regression findings corrected

#### 1. Kit orphan-prevention had leaked into non-Kit Container maintenance

Corrected at `3cc5dbb286e10f1b74831476dec0b450bcf80ab4`.

The generic Container expected-content POST now preserves the existing non-Kit path used by T-Post/shared-stock and #230. Only Kit Boxes require an active reusable-task Extra Material requirement when creating new expected contents.

A regression contract now preserves that boundary.

#### 2. Historical source candidates were matched too broadly

Corrected at `8c5e995e737240e2ec3977a1273bd541b393e422`.

Historical source reassignment candidates now require the same:

- Extra Material identity;
- quantity UOM;
- size;
- length value;
- length unit;
- color; and
- Stage context.

This prevents a prior source for a different physical material variant from being offered merely because it shares the same catalog family and Stage.

A contract assertion now preserves the specification match.

#### 3. Delete Mistake operator text contradicted migration 063

Corrected at `f4194700881a6143caf120652519ea13d4663097`.

The browser previously claimed Container expected contents were never removed by hard delete. Migration 063 intentionally removes a matching expected-content row only when it becomes unused and has no physical inventory history.

The UI now states that behavior accurately and reports:

- deleted task-source link count; and
- deleted unused/un-inventoried Container expected-content row count.

The Extra Material catalog identity, Displays, and inventory history remain preserved.

A contract assertion now prevents the false wording from returning.

### Current acceptance gate

Static implementation/contract review is complete enough to move to executable regression.

Accepted repository runbooks use:

```text
python -m pytest -q -p no:cacheprovider Setup/Application
```

No GitHub Actions status exists for this PR, and this ChatGPT tool environment does not provide the governed MSB server/disposable PostgreSQL runtime needed to execute that regression or migration 063 safely.

Next executable steps, in order:

1. full exact-candidate `Setup/Application` regression;
2. governed current-Production disposable clone;
3. apply migration 063 only to that disposable clone;
4. run `Setup/Acceptance/setup_206_extra_material_lifecycle_disposable_validation.sql`;
5. disposable browser review of the already-recorded Church RGB, Northern Lights, source-required creation, Kit reverse-use/orphan, and picker-only cases;
6. checkpoint exact results before any Production deployment decision.

Do not restart implementation from the original #206 prompt. Continue from this checkpoint and the current PR head.

No Production data mutation has been authorized or performed.


---

## Continuation Checkpoint — Full Setup/Application Regression PASS

| Field | Value |
|---|---|
| Exact tested candidate | `938d83327ef6f35a3bd3e270a4f2c602c3d83537` |
| Test environment | Office Windows checkout, active project virtual environment |
| Command | `python -m pytest -q -p no:cacheprovider Setup/Application` |
| Result | **560 passed in 5.63s** |
| Failures / errors | **0** |
| Production mutation authorized | **NO** |

The full Setup/Application regression gate is closed for the exact candidate above.

Do not return to implementation reconnaissance or repeat the contract-test buildout unless a later disposable/database/browser gate identifies a specific defect.

### Next gate

Proceed in this order:

1. create/use the governed disposable current-Production PostgreSQL clone under the accepted Setup disposable runbook;
2. apply candidate migration `Setup/Database/063_harden_setup_extra_material_requirement_lifecycle.sql` to the disposable clone only;
3. run `Setup/Acceptance/setup_206_extra_material_lifecycle_disposable_validation.sql`;
4. require the marker `SETUP_206_EXTRA_MATERIAL_LIFECYCLE_DISPOSABLE_VALIDATION_PASS`;
5. then perform disposable browser review for the recorded Church RGB, Northern Lights, source-required creation, Kit task-use/orphan prevention, and picker-only Pick List cases;
6. checkpoint exact disposable/browser results before any Production decision.

No Production mutation has been authorized or performed.


---

## Continuation Checkpoint — Disposable Browser Review Findings

| Field | Value |
|---|---|
| Exact browser-review candidate | `f11db3e44c2911367749fd4ba8bfbb1c70d6fcd7` |
| Disposable browser result | **CLEAN EXIT** |
| Production mutation by preview | **NO** |
| Branch implementation state | **STOPPED — findings captured; no further recon authorized in this checkpoint** |

### Browser-review acceptance status

The disposable browser review found multiple real defects and data-reconciliation cases. Therefore candidate `f11db3e44c2911367749fd4ba8bfbb1c70d6fcd7` is **not accepted for Production**.

Do not resume implementation from the original #206 problem statement. Continue from the findings below.

### 1. Requirement hard-delete refresh defect

Observed on Church RGB Plywood:

- **Delete Mistake** successfully removed the Plywood requirement from the upper **Extra Materials Required by This Task** table.
- The lower **Expected Source Containers** section retained the deleted requirement until the task/page was reloaded.
- After reload, Plywood disappeared correctly.

Code cause established during review:

- task requirement module refreshes its own state with `loadTaskMaterials()`;
- source module owns separate cached requirement state loaded by `loadTaskSources()`;
- delete path does not trigger source-module refresh.

Required correction:

- hard-delete must refresh both task-requirement and source sections.

### 2. Church RGB / C145 material truth established

Task #73 — `Setup Church RGB (John's) Tree` — has physical Kit C145 assigned.

Operator confirmed these task materials are physically sourced from C145:

- Cribbing / Shim — Qty 3;
- Ratchet Strap — Qty 3;
- T-Post — Qty 2 minimum / NEEDS_REVIEW;
- Turnbuckle — Qty 3 / verification candidate.

After reload, all four source allocations persisted and showed balanced.

Known cleanup:

- **Plywood must not remain in C145 expected contents.**
- Church RGB plywood is already represented by first-class Display identities stored in Container 131.
- The task-level Plywood requirement was deleted as duplicate reconstruction authority.
- The remaining C145 Plywood expected-content row is reconstruction garbage and should be removed separately.

Turnbuckle:

- operator intentionally removed Turnbuckle from C145 expected contents in the disposable browser as a test;
- operator believes Ratchet Straps may have replaced Turnbuckles for the same guying/tensioning purpose;
- Turnbuckle remains a **verification/reconciliation candidate**, not established truth.

### 3. Source/content divergence allowed

The Turnbuckle removal test exposed an integrity gap:

```text
active task requirement
    -> active source C145
but
C145 expected contents
    -> matching material removed
```

The system still showed the task/source allocation as balanced.

Required correction:

- removing Kit expected content with active dependent task-source relationships must not silently create contradictory authority;
- block or require explicit governed reconciliation;
- surface exact dependent task requirement(s);
- preserve inventory history separately.

### 4. Kit reverse "Used by task(s)" projection is too strict

C145 showed legitimate task use as `NO TASK USE` for some materials despite real task/source authority.

Current reverse projection requires exact equality of:

- material identity;
- UOM;
- size_text;
- length_value;
- length_unit;
- color.

Reconstructed task and Container rows can describe the same physical item with different legacy/spec text.

Observed examples:

- Ratchet Strap — real task #73 source relationship but `NO TASK USE`;
- T-Post — real task #73 source relationship but `NO TASK USE`.

Required correction:

- do not infer **no use** from failure of exact-spec reverse matching;
- preserve exact relationship identity while allowing a review state for mismatched reconstructed specs.

Suggested operator-facing states:

- `LINKED TO TASK`;
- `TASK LINK NEEDS REVIEW`;
- `NO TASK LINK RECORDED`;
- explicit `SHARED / STOCK` where governed disposition exists.

### 5. "NO TASK USE" wording is misleading

Church Tree Kit C145 is clearly useful and assigned to task #73.

`NO TASK USE` overstates the evidence when the actual condition is only that no exact reverse material/spec match was resolved.

This is both:

- a projection/reconciliation problem; and
- an operator wording problem.

### 6. Kit "Task use" picker exposes requirement implementation instead of operator workflow

In **Add Expected Extra Material**, the Task use dropdown currently loads every active task Extra Material requirement globally.

That makes the same reusable task appear repeatedly for unrelated materials.

Observed example for task #73:

- Cribbing / Shim;
- Ratchet Strap;
- T-Post;
- Turnbuckle;

all appear as separate `#73 Setup Church RGB...` choices.

The API already supports filtering source options by `setup_extra_material_id`.

Required UX:

1. choose material first;
2. show only active task requirements for that material;
3. show each task once unless multiple real variants of the same material require disambiguation;
4. when variants exist, show the spec/variant;
5. continue submitting the exact `setup_task_extra_material_id`;
6. do not offer an exact task-requirement + Kit relationship as a new choice when it is already linked.

### 7. Northern Lights prior reconciliation assumption is invalid

Prior checkpoint assumption:

- active requirement #52 on task #140 was correct;
- historical C16/C17/C18/C19 sources from inactive #36 should be moved to #52.

**This is wrong. Do not perform that repair.**

Operator-established reusable workflow:

```text
#140 Layout Light Locations
    layout/mark locations only
    no Display/Container material
    no T-Post installation

#132 Setup Northern Lights
    install T-Posts and lights together
    66 Displays
    Containers C16/C17/C18/C19
```

Current Catalog evidence:

#### Task #140

- reusable ID 140;
- annual task ID 333;
- current name incorrectly says `Layout Light Locations and install 66 T-Posts`;
- Material = NO;
- 0 Displays / 0 Containers;
- completion point incorrectly says `T-Posts are installed`;
- active T-Post requirement #52:
  - 66 EA;
  - 3 FT;
  - NEEDS_REVIEW;
  - no source.

This requirement is misplaced reconstruction authority.

#### Task #132

- reusable ID 132;
- annual task ID 387;
- `Setup Northern Lights`;
- Material = YES;
- resolves 66 Displays;
- Containers 16,17,18,19;
- currently 0 active Extra Material requirements.

Historical requirement #36 on #132 already has source allocations:

- C16 = 16;
- C17 = 16;
- C18 = 18;
- C19 = 16;
- total = 66.

Correct reconciliation direction:

1. correct task #140 reusable wording to layout-only semantics;
2. hard-delete mistaken active requirement #52 on #140;
3. **restore/reactivate existing requirement #36 on #132**;
4. preserve its existing C16/C17/C18/C19 source rows;
5. do not duplicate source rows;
6. preserve #132 Display/Container material resolution.

### 8. Material Audit needs restore/reactivate path

Current historical-source review assumes the current active requirement is the destination.

Northern Lights proves the inactive historical requirement can be correct while the active reconstructed requirement is wrong.

Required correction surface must distinguish at least:

- **Restore prior requirement**; versus
- **Move/reassign historical source to current requirement**.

Do not make activity state itself determine authority.

### 9. Reusable Catalog and live Setup Session must coexist during first-season cleanup

Northern Lights is direct evidence that reusable Catalog mistakes are being discovered while 2026 Setup is live.

Required operational principle:

- reusable task knowledge must remain correctable during live annual execution;
- annual/live Session state must remain usable;
- correcting reusable knowledge must not force bad reconstruction forward;
- Catalog and annual execution are related but separate authority layers.

### 10. Northern Lights procedure split confirms task boundary

Operator produced separate draft procedures:

- `16-Northern Lights-NL Layout Procedure.pdf`;
- `16-Northern Lights-NL Setup Procedure.pdf`.

Layout procedure:

- marks light locations only;
- does not install T-Posts or lights.

Setup procedure:

- begins with placing/pounding shortened T-Posts;
- then installs one light per post;
- continues with power/network/bull-line work.

The old **Display Materials** section in the Setup Procedure should be removed because it duplicates/stales database material authority.

Preserve procedural instructions describing **how/where** bull line, network cable, posts, lights, etc. are used.

### 11. Procedure/database authority boundary

Use:

```text
Layout procedure
    = where/how to mark locations

Setup procedure
    = how to perform physical installation

Database
    = material identity, quantities, Containers, sources, Displays, inventory
```

Do not retain procedure material inventories as competing durable authority.

### STOP POINT

The operator explicitly stopped further reconnaissance after these findings.

Do not:

- continue browser reconnaissance;
- mutate Production for these material corrections;
- implement fixes until work is explicitly resumed;
- restart #206 from the original prompt.

When work resumes, begin from this checkpoint and the recorded #206 / PR #252 findings, then implement the corrections as one controlled candidate cycle and rerun:

1. full Setup/Application regression;
2. disposable current-Production clone acceptance;
3. exact-candidate disposable browser review;
4. operator acceptance;
5. separate Production deployment decision.


---

## Continuation Checkpoint — Corrected Candidate Ready for Retest

| Field | Value |
|---|---|
| Implementation head before checkpoint | `a7a15f1fd1dac6f249f2d1950f653ea9ec8cd5e1` |
| Branch | `agent/setup-206-tablet-material-audit` |
| PR | #252 |
| Main comparison before checkpoint | 73 ahead / 0 behind |
| Mergeable | true |
| Production mutation authorized | **NO** |

This checkpoint resumes from the prior disposable-browser STOP findings. It is a new controlled candidate cycle, not a restart of #206.

### Corrections implemented

#### 1. Requirement/source panel synchronization

Requirement save and **Delete Mistake** now refresh:

- **Extra Materials Required by This Task**; and
- **Expected Source Containers**.

The source module exports a bounded refresh hook used by the requirement module after mutations.

This addresses the Church Plywood stale-source-panel finding.

#### 2. Kit reverse task-use semantics

Kit Inventory no longer equates an exact-spec mismatch with "no task use."

Reverse projection now first uses stable:

- source Container;
- active task requirement;
- active reusable task; and
- Extra Material identity.

Each resolved task/source link is then classified:

- `LINKED_TO_TASK` when material specification matches exactly;
- `TASK_LINK_NEEDS_REVIEW` when a real task/source link exists but reconstructed UOM/size/length/color does not match the Kit row exactly;
- `NO_TASK_LINK_RECORDED` only when no active task/source relationship exists.

Operator wording changed accordingly.

This addresses the Church Ratchet Strap/T-Post false `NO TASK USE` finding.

#### 3. Material-first Kit task picker

**Add Expected Extra Material** now uses:

```text
choose Item
    -> fetch active requirements for that material only
    -> choose reusable task
    -> preserve exact setup_task_extra_material_id underneath
```

Behavior:

- unrelated material requirements are no longer shown;
- a task appears once when it has one requirement for that material;
- multiple variants on the same task show variant/spec detail;
- exact requirements already linked to the selected Kit are labeled **Already linked to this Kit** and disabled for new creation.

The existing API's `setup_extra_material_id` filter is reused; no new relationship table was added.

#### 4. Prevent source/content divergence

Removing/deactivating an expected Container material now checks for active task/source dependencies using stable material identity.

If an active reusable task still says the Container is a source for that material, removal returns HTTP 409 and names the dependent task(s).

Operator must reconcile/remove the task source first.

This addresses the disposable Turnbuckle contradiction:

```text
task -> source C145
while
C145 expected content removed
```

Physical inventory history remains separate.

#### 5. Historical requirement restore path

Material Audit historical-source review no longer assumes the current active reconstructed requirement is correct.

For a matching inactive historical requirement, Manager now gets distinct actions:

- **Restore prior requirement #N**; or
- **Move Cxx to current requirement**.

Restore:

- reactivates the exact existing `setup_task_extra_material_id`;
- reuses the existing governed `ref.set_setup_task_extra_material(...)` command;
- does not recreate or move its existing source rows;
- leaves competing current requirements for separate review/delete.

This is the required Northern Lights path for restoring requirement #36 on task #132 while leaving C16/C17/C18/C19 attached.

#### 6. Browser cache isolation

Corrected browser assets were repinned to `2026-09-28.2` where required so the next disposable browser cannot reuse the previous preview's JavaScript.

### Northern Lights retest target

Fresh current-Production clone should include the operator's Production task-name correction.

In the new disposable browser:

1. Material Audit should show the Northern Lights historical relationship without assuming #52 is authoritative.
2. Use **Restore prior requirement #36** for task #132.
3. Verify requirement #36 becomes active on **Setup Northern Lights** with existing C16/C17/C18/C19 source rows still attached.
4. Review task #140 separately and hard-delete mistaken requirement #52.
5. Confirm no source rows were duplicated or moved.
6. Confirm #132 continues to resolve the 66 Displays / Containers 16,17,18,19.

No Production material mutation is part of this test.

### Church retest target

On fresh disposable C145 / task #73:

1. remove known-bad Plywood expected content separately;
2. verify requirement hard-delete/source-panel refresh no longer needs a page reload;
3. verify Ratchet Strap/T-Post show **TASK LINK NEEDS REVIEW** rather than **NO TASK USE** when specs differ;
4. verify Cribbing/Shim exact link remains **LINKED TO TASK**;
5. verify Turnbuckle expected-content removal is blocked while its active task-source link remains;
6. reconcile/remove the task source first if testing intentional Turnbuckle removal;
7. verify Add Expected Material picker is material-first and does not show unrelated #73 requirements.

### Required gate sequence from this checkpoint

1. update office checkout to this exact branch head;
2. run full `python -m pytest -q -p no:cacheprovider Setup/Application`;
3. if green, run reusable disposable acceptance with migration 063 + lifecycle validation;
4. if green, start a fresh disposable browser preview from the same exact SHA;
5. perform the Northern Lights and Church checks above;
6. checkpoint results before any Production deployment decision.

Do not reuse the previous disposable clone or preview.
Do not mutate Production material authority during this test cycle.


---

## Continuation Checkpoint — Corrected Candidate Regression PASS

| Field | Value |
|---|---|
| Exact tested implementation candidate | `1e2200fbb68f9d5334881f391c76ed5297e7128d` |
| Full regression command | `python -m pytest -q -p no:cacheprovider Setup/Application` |
| Result | **565 passed in 0.98s** |
| Failures / errors | **0** |
| Branch | `agent/setup-206-tablet-material-audit` |
| Main comparison before checkpoint | 75 ahead / 0 behind |
| PR | #252 — draft / mergeable=true |
| Production material mutation authorized | **NO** |

This closes the full Setup/Application regression gate for the corrected post-browser candidate.

The implementation under test includes:

- synchronized requirement/source-panel refresh after requirement mutations;
- Kit reverse-use states that distinguish exact link, spec-review link, and no recorded link;
- material-first Kit task selection with already-linked requirements disabled;
- fail-closed expected-content removal when active task/source authority depends on the material;
- governed historical requirement restore path distinct from moving historical sources;
- updated browser asset pins for a fresh preview.

### Next gate

Use the reusable disposable acceptance harness on the exact checkpoint SHA created after this section is committed.

Supply:

- migration `Setup/Database/063_harden_setup_extra_material_requirement_lifecycle.sql`;
- validation `Setup/Acceptance/setup_206_extra_material_lifecycle_disposable_validation.sql`.

The harness must:

1. rerun the full Setup/Application regression on the exact checkpoint SHA;
2. create a fresh current-Production disposable clone;
3. apply migration 063 only to that disposable clone;
4. run the lifecycle validation;
5. prove Production fingerprint and live Setup SHA remain unchanged.

If green, start a fresh disposable browser preview from the same exact SHA.

Do not reuse the prior disposable clone or browser session.


---

## Continuation Checkpoint — Historical Discovery + Pick List Human ID

Implementation head before this documentation checkpoint:
`b4b4c38a3ab7b8f37c52e1ce570d1220204b4ac9`

### Browser blocker corrected

The prior disposable browser proved Northern Lights historical requirement #36 was hidden because historical candidate discovery still required an exact match on UOM/size/length/unit/color.

The correction now separates **discovery** from **action eligibility**:

- inactive historical requirements are discovered by same Extra Material identity + same Stage;
- their own historical specification is returned with source context;
- each historical candidate is labeled **EXACT SPEC MATCH** or **SPEC MISMATCH — REVIEW**;
- **Restore prior requirement** remains available for the historical requirement;
- **Move Cxx to current requirement** is offered only for an exact specification match;
- repository-side source reassignment also fails closed when attempting to move an existing source between mismatched requirements.

Northern Lights expected browser result:

- #52 on task #140 can discover inactive #36 on task #132;
- #36 appears with C16/C17/C18/C19;
- operator can restore #36 without moving those sources;
- mismatched-spec sources cannot be moved to #52.

### Pick List human-readable Container identity

Machine and human identity are intentionally separate:

```text
scan / QR route
    CONT/<container_id>

human-readable Pick List identity
    C###  (zero-padded to 3 digits)
```

Examples:

- Container 30 -> `C030`;
- Container 7 -> `C007`;
- Container 145 -> `C145`.

Display identity behavior is unchanged.

The Pick List QR payload remains:

`https://db.sheboyganlights.org/scan/CONT/<id>`

Only the operator-facing identity text changed.

The Pick List JavaScript asset pin was advanced to `2026-09-28.2`.

### Next gate

Run full Setup/Application regression on the exact checkpoint SHA created by this documentation commit before launching another disposable acceptance/browser cycle.


---

## Continuation Checkpoint — Historical Discovery / Pick List Regression PASS

| Field | Value |
|---|---|
| Exact tested implementation candidate | `08cac444c6d8d7baef953f432b914af35a3558a7` |
| Full regression command | `python -m pytest -q -p no:cacheprovider Setup/Application` |
| Result | **566 passed in 1.11s** |
| Failures / errors | **0** |
| Branch | `agent/setup-206-tablet-material-audit` |
| PR | #252 — draft / mergeable=true |
| Main comparison before checkpoint | 79 ahead / 0 behind |
| Production material mutation authorized | **NO** |

The tested candidate includes:

- broader same-material / same-Stage historical requirement discovery;
- historical candidate exact-spec vs spec-mismatch classification;
- restore-prior action available independently of source movement;
- source movement blocked in both UI and repository layer when requirement specs differ;
- Pick List human-readable Container IDs normalized to `C###`;
- scan/QR Container route preserved as `CONT/<id>`.

### Next gate

Run reusable disposable acceptance against the exact documentation checkpoint SHA created after this section is committed.

Use:

- migration `Setup/Database/063_harden_setup_extra_material_requirement_lifecycle.sql`;
- validation `Setup/Acceptance/setup_206_extra_material_lifecycle_disposable_validation.sql`.

If green, launch a fresh disposable browser preview from the same SHA and retest:

1. Northern Lights historical requirement #36 visibility and restore;
2. C16/C17/C18/C19 source preservation;
3. #52 remaining separate on task #140 until intentionally deleted;
4. Pick List human-readable Container identity (for example C030) while QR remains CONT route.


---

## Continuation Checkpoint — Governed Restore Boundary Fix

| Field | Value |
|---|---|
| Implementation head before documentation checkpoint | `4ad0766b4c3fdf79a9342cc20bc9e8ecee98d8c7` |
| Branch | `agent/setup-206-tablet-material-audit` |
| PR | #252 — draft / mergeable=true |
| Main comparison before checkpoint | 82 ahead / 0 behind |
| Production mutation authorized | **NO** |

### Browser evidence from prior candidate

Exact prior browser candidate:
`dc6d14507a805311d35077fce481a226fccd79f3`

Confirmed passes:

- Rolling Pick List no longer exposes Material data exceptions;
- human-readable Container identity is `C###`;
- QR/scan route remains `CONT/<id>`;
- Northern Lights historical discovery surfaces requirement #36 on task #132 with C16/C17/C18/C19;
- spec mismatch is shown as review state;
- moving historical sources to mismatched current #52 is blocked.

Restore attempt then failed with:

`permission denied for table setup_task_extra_material`

Cause: application repository performed direct `SELECT ... FOR UPDATE` against the table before invoking the governed command.

### Correction implemented

New migration:

`Setup/Database/064_add_setup_extra_material_requirement_restore.sql`

It creates governed SECURITY DEFINER command:

`ref.restore_setup_task_extra_material(text,bigint,bigint)`

The command:

- resolves the exact inactive historical requirement under Manager authority;
- takes the required row lock inside the governed function;
- reactivates the exact existing requirement through the accepted `ref.set_setup_task_extra_material(...)` command;
- preserves the existing requirement ID;
- preserves all existing source rows;
- returns material/task/source-count evidence;
- grants only EXECUTE to `fieldwiring_app`;
- does not grant direct UPDATE or row-lock authority on the table.

Application repository restore now calls only the governed restore function. It performs no direct table lock/read for restoration.

### Restore UX correction

Primary Manager wording now uses physical/operator concepts rather than internal IDs.

Example:

`Restore T-Post to Setup Northern Lights`

Confirmation includes the existing source Container labels, for example:

`Existing source Containers C016, C017, C018, C019 will remain attached.`

Historical source labels also use zero-padded `C###` Container identity.

Restore result/error feedback is rendered adjacent to the restore action at the current scroll position. On success the button changes to `Restored`; the audit is not auto-rerun, so the operator can read the confirmation before navigating to the task or rerunning the audit.

Internal requirement/task IDs remain available only as hidden command identity / engineering evidence.

### Disposable validation extended

`setup_206_extra_material_lifecycle_disposable_validation.sql` now also proves:

1. a disposable requirement can be made inactive;
2. governed restore reactivates the exact same requirement ID;
3. its existing source row remains active and attached;
4. `fieldwiring_app` can execute the restore function;
5. `fieldwiring_app` still does not have direct UPDATE privilege on `ref.setup_task_extra_material`.

### Next gate

Run full Setup/Application regression on the exact documentation checkpoint SHA produced after this section.

If green, disposable acceptance must include both migrations in order:

1. `Setup/Database/063_harden_setup_extra_material_requirement_lifecycle.sql`
2. `Setup/Database/064_add_setup_extra_material_requirement_restore.sql`

Use the updated `Setup/Acceptance/setup_206_extra_material_lifecycle_disposable_validation.sql`.

If acceptance is green, start a fresh disposable browser preview from the same exact SHA with both migrations applied and retest Northern Lights restore.


---

## Continuation Checkpoint — Governed Restore Regression PASS

| Field | Value |
|---|---|
| Exact tested implementation candidate | `22f5174f994b747b36ae40f70d8e4731e25ae914` |
| Full regression command | `python -m pytest -q -p no:cacheprovider Setup/Application` |
| Result | **568 passed in 1.08s** |
| Failures / errors | **0** |
| Branch | `agent/setup-206-tablet-material-audit` |
| PR | #252 — draft / mergeable=true |
| Main comparison before checkpoint | 84 ahead / 0 behind |
| Production mutation authorized | **NO** |

The tested candidate includes the governed historical restore command, operator-facing restore wording/local feedback, prior historical-discovery corrections, and Pick List C### human-readable identity behavior.

### Next gate

Run reusable disposable acceptance against the exact documentation checkpoint SHA created after this section is committed.

Apply migrations in order:

1. `Setup/Database/063_harden_setup_extra_material_requirement_lifecycle.sql`
2. `Setup/Database/064_add_setup_extra_material_requirement_restore.sql`

Use validation:

`Setup/Acceptance/setup_206_extra_material_lifecycle_disposable_validation.sql`

The validation now covers both hard-delete and governed restore lifecycle behavior, including preserved requirement/source identity and no direct application-role UPDATE privilege.

If green, launch a fresh disposable browser preview from the same exact SHA with both migrations applied and retest Northern Lights restore.


---

## Continuation Checkpoint — Kit UI Clarity + Operator SOP

| Field | Value |
|---|---|
| Implementation head before documentation checkpoint | `91223e581cf488b02c882e74db46534db626b292` |
| Branch | `agent/setup-206-tablet-material-audit` |
| PR | #252 — draft / mergeable=true |
| Main comparison before checkpoint | 99 ahead / 0 behind |
| Production mutation authorized | **NO** |

### Prior exact-candidate browser review

Exact reviewed candidate:
`6dc0a85dbc7737b22eba6d4d775049c3906778e9`

The disposable browser exited cleanly after confirming:

- Pick List material exceptions are absent;
- Pick List Container human-readable IDs use `C###`;
- Northern Lights historical authority can be discovered, restored, and reconciled safely;
- restored Northern Lights T-Post authority preserved C016/C017/C018/C019 without duplicate source rows;
- mistaken Layout Light Locations T-Post authority can be hard-deleted and both task material panels refresh immediately;
- task-level cleanup correctly removes resolved/deleted rows from Material Audit;
- Church source correction works, but Kit Inventory exposed remaining UX clarity problems.

### Kit Inventory UI corrections

#### Expected-content maintenance action

Row action changed:

`Edit` -> `Edit / Remove`

The action now has a stronger filled/background treatment, accent border, and bold text so it is visually discoverable beside `Count / Adjust`.

The Kit screen now explicitly explains:

- **Edit / Remove** changes expected Kit contents;
- **Count / Adjust** records physical on-hand;
- do not use a physical count to remove an item that should not belong in the Kit.

#### Task-link wording

Operator feedback proved `TASK LINK NEEDS REVIEW` was misleading when the source link itself was valid but task-vs-Kit descriptions/specifications differed.

Operator-facing state is now:

`LINKED TO TASK — DETAILS DIFFER`

Supporting text:

`Source relationship is recorded. Task and Kit descriptions/specifications do not match exactly.`

The underlying internal link-state value remains unchanged; only the operator semantics are corrected.

#### Table layout

The **Used by task(s)** column was widened and action-column width made explicit. Detail mismatch copy can wrap without colliding with the adjacent Verification column.

#### Source Container search

Task Extra Material source search now accepts:

- raw numeric ID such as `145`;
- unpadded human label such as `C145` / `c145`;
- padded physical-label identity such as `C030`;
- description, type, and location as before.

Source labels now use zero-padded `C###` human-readable identity.

### Dedicated operator SOP

New procedure:

`Docs/02_Production_Database/01_System_Architecture/12_Setup_and_Deployment/operatorSOP/Extra_Materials_and_Kit_Inventory.md`

The procedure teaches four separate questions:

1. **What does the task need?** — Extra Materials.
2. **Where should the crew find it?** — Expected Source Containers.
3. **What should normally be in this Kit?** — Kit expected contents / Edit / Remove.
4. **What is physically on hand right now?** — Count / Adjust.

It explicitly states:

- Procedure mention alone is not Extra Material authority;
- PPE such as hearing protection/ear plugs, fall protection, gloves, and safety glasses remain PPE/procedure information rather than Display/Kit Extra Material;
- tools, fuel, and normal crew supplies are not promoted to Extra Material merely because a procedure names them;
- unknown quantities/specs must not be guessed;
- the same reusable physical item may support more than one task/step without multiplying stock or Pick List demand.

Examples include Church Plywood, Church Cribbing/Shim with unknown quantity, Northern Lights historical restore, and Magic Igloo shared ratchet straps.

The SOP is linked from:

- Setup Operator Procedure Index;
- Setup Operator Instructions portal;
- Setup Manager Review Guide;
- Setup and Deployment portal.

### Next gate

Run the full Setup/Application regression on the exact documentation checkpoint SHA created after this section is committed.

Because candidate bytes changed after browser review, prior disposable acceptance/browser acceptance do not carry forward. If regression is green, rerun disposable acceptance with migrations 063 and 064 and the #206 lifecycle validation, then run one focused fresh browser review of the Kit UI/source-search changes.


---

## Continuation Checkpoint — Kit UI/SOP Regression PASS

| Field | Value |
|---|---|
| Exact tested implementation candidate | `6cdd9fc30ec276743e2931ad2edbdf555c3906e9` |
| Full regression command | `python -m pytest -q -p no:cacheprovider Setup/Application` |
| Result | **572 passed in 1.15s** |
| Failures / errors | **0** |
| Branch | `agent/setup-206-tablet-material-audit` |
| PR | #252 — draft / mergeable=true |
| Main comparison before checkpoint | 100 ahead / 0 behind |
| Production mutation authorized | **NO** |

The tested candidate includes:

- stronger **Edit / Remove** expected-content action;
- clearer separation from **Count / Adjust**;
- `LINKED TO TASK — DETAILS DIFFER` operator wording;
- table layout correction preventing task-link status from colliding with Verification;
- C-prefixed / zero-padded Container source search;
- C### human-readable source labels;
- dedicated Extra Materials and Kit Inventory operator SOP and portal/index links.

### Next gate

Run reusable disposable acceptance against the exact documentation checkpoint SHA created after this section is committed.

Apply migrations in order:

1. `Setup/Database/063_harden_setup_extra_material_requirement_lifecycle.sql`
2. `Setup/Database/064_add_setup_extra_material_requirement_restore.sql`

Use validation:

`Setup/Acceptance/setup_206_extra_material_lifecycle_disposable_validation.sql`

If green, run one focused fresh disposable browser review of:

1. C145 row actions — **Edit / Remove** visually distinct from **Count / Adjust**;
2. task-link mismatch wording — **LINKED TO TASK — DETAILS DIFFER** with no overlap into Verification;
3. source search accepting `145`, `C145`, `c145`, and padded IDs such as `C030`;
4. operator SOP links resolving from the Setup documentation/index.

No Production deployment until this focused browser review is accepted.


---

## Continuation Checkpoint — Browser Return-Path Cache Fix

| Field | Value |
|---|---|
| Implementation head before documentation checkpoint | `9bcd30a2521ebfd14cf25d2498aa5650ff35e550` |
| Branch | `agent/setup-206-tablet-material-audit` |
| Production mutation authorized | **NO** |

### Focused browser result on prior candidate

Prior exact browser candidate:

`8a13328f531e5644be82053b4e0fa855cea4641c`

Accepted in browser:

- C145 **Edit / Remove** is visually distinct from **Count / Adjust** in light and dark modes;
- stale Plywood expected content can be removed correctly;
- Pick List still renders with human-readable `C###` Container IDs;
- Kit Inventory opens correctly;
- Material Audit restore/reassignment behavior for Northern Lights remains correct;
- Expected Source Container search accepts `145`, `C145`, `c145`, and padded identities such as `C030`.

Release blocker found:

- returning from Kit Inventory to Reusable Task Catalog could render incorrectly until `Ctrl+Shift+R`.

### Correction

The candidate had changed the bridge file:

`Setup/Application/setup_extra_materials.js`

so it loaded:

`setup_task_extra_material_sources.js?v=2026-09-28.3`

but `Setup/Application/production.html` still referenced the bridge itself as:

`setup_extra_materials.js?v=2026-09-28.2`

The Production shell pin is now bumped to:

`setup_extra_materials.js?v=2026-09-28.3`

A regression contract now requires both the outer bridge pin and the inner source-editor pin to remain aligned at the current candidate version.

### Next gate

Run the full `Setup/Application` regression on the exact documentation checkpoint SHA created after this section is committed.

If green:

1. rerun reusable disposable acceptance with migrations 063 and 064 plus the #206 lifecycle validation;
2. run a focused fresh browser check of **Kit Inventory -> Back to Setup Session -> Reusable Task Catalog** without hard refresh;
3. confirm no stale/malformed rendering occurs.

No Production deployment until that return-path browser check passes.


---

## Continuation Checkpoint — Browser Return-Path Regression PASS

| Field | Value |
|---|---|
| Exact tested implementation candidate | `e009eba6bfe2c6cab235ef6e4fc39797c7680faf` |
| Full regression command | `python -m pytest -q -p no:cacheprovider Setup/Application` |
| Result | **573 passed in 1.07s** |
| Failures / errors | **0** |
| Branch | `agent/setup-206-tablet-material-audit` |
| PR | #252 — draft / mergeable=true |
| Main comparison before checkpoint | 104 ahead / 0 behind |
| Production mutation authorized | **NO** |

This validates the candidate that:

- bumps the Production shell pin for `setup_extra_materials.js` to `v=2026-09-28.3`;
- keeps the inner `setup_task_extra_material_sources.js` pin at `v=2026-09-28.3`;
- adds a regression contract requiring the two cache-bust boundaries to stay aligned.

### Next gate

Run reusable disposable acceptance against the exact documentation checkpoint SHA created after this section is committed.

Apply migrations in order:

1. `Setup/Database/063_harden_setup_extra_material_requirement_lifecycle.sql`
2. `Setup/Database/064_add_setup_extra_material_requirement_restore.sql`

Use validation:

`Setup/Acceptance/setup_206_extra_material_lifecycle_disposable_validation.sql`

If green, run one final focused browser check:

1. open Kit Inventory;
2. use **Back to Setup Session**;
3. open/confirm Reusable Task Catalog;
4. verify the page renders correctly **without** `Ctrl+Shift+R`.

No Production deployment until that return-path check passes.


---

## Continuation Checkpoint — V0.3.20 Material Authority

| Field | Value |
|---|---|
| Implementation head before documentation checkpoint | `a8a918cb77d283a74aaa6d7665deca45a8259142` |
| Candidate version | `V0.3.20-material-authority` |
| Branch | `agent/setup-206-tablet-material-audit` |
| PR | #252 — draft / mergeable=true |
| Main comparison before checkpoint | 106 ahead / 0 behind |
| Production mutation authorized | **NO** |

### Prior gate

The immediately preceding candidate `18be2b59fcab521be3cc8c71798c6d2a22e53c95` completed reusable disposable acceptance with a clean exit.

Before the final browser return-path test, operator review identified that the candidate still reported/displayed the existing Production client line `V0.3.19-pick-list`.

That is not acceptable for this release because the candidate now contains a materially different Setup client/runtime boundary, including:

- post-launch #206 material-authority cleanup;
- governed Extra Material lifecycle and historical restore;
- task/source/Kit reconciliation;
- Material Audit correction behavior;
- Kit Inventory expected-content maintenance;
- human-readable Container source search;
- operator material/Kit procedures;
- Pick List material-surface corrections.

### Version correction

The candidate now advances to:

`V0.3.20-material-authority`

Updated boundaries:

- `production_backend.py` -> `PRODUCTION_VERSION = "V0.3.20-material-authority"`;
- `setup_catalog_dirty_guard.js` -> `CLIENT_BUILD = 'V0.3.20-material-authority'`;
- visible badge -> `Client V0.3.20`;
- `production.html` cache-bust pin for `setup_catalog_dirty_guard.js` -> `v=2026-09-28.1`;
- current runtime/client contract tests updated to require V0.3.20.

Historical Production deployment scripts/acceptance records for V0.3.19 remain historical evidence and are intentionally not rewritten.

The Setup README / engineering live-runtime documentation continues to identify **current live Production** as V0.3.19 until an authorized V0.3.20 Production deployment actually occurs.

### Gate reset

Changing the server/client build boundary invalidates the prior exact-candidate acceptance for release purposes.

Next:

1. full `Setup/Application` regression on the documentation checkpoint SHA created after this section;
2. reusable disposable acceptance with migrations 063 + 064 and #206 lifecycle validation;
3. focused browser review:
   - header visibly shows **Client V0.3.20**;
   - Kit Inventory -> Back to Setup Session -> Reusable Task Catalog renders correctly without `Ctrl+Shift+R`;
   - server/client build guard remains matched and writes are not blocked.

No Production deployment before those gates pass.


---

## THREAD RECOVERY CHECKPOINT — V0.3.20 Gate Reset

This section is intentionally self-contained so #206 can resume safely if the current chat/thread ends.

| Field | Value |
|---|---|
| Branch before this documentation checkpoint | `agent/setup-206-tablet-material-audit` |
| Exact implementation head | `2bd4c45ad19554092202f60fd6ffb7efc960fb78` |
| Candidate client/server version | `V0.3.20-material-authority` |
| PR | #252 — DRAFT |
| Production deployment authorized | **NO** |
| Current live Production version | `V0.3.19-pick-list` |
| Current live Setup SHA (last documented) | `fc0b76d57826eebf04b81c99cbb904109162cd87` |

### Why V0.3.20 exists

The #206 post-launch candidate is materially beyond the original V0.3.19 Pick List release. It now includes governed material lifecycle and historical restore, task/source/Kit reconciliation, Material Audit correction behavior, Kit Inventory expected-content maintenance, Container source search improvements, Pick List cleanup, and operator procedures.

The candidate therefore advances to:

`V0.3.20-material-authority`

The visible client badge must show:

`Client V0.3.20`

Server `/api/health` must report:

`V0.3.20-material-authority`

### Accepted browser findings before V0.3.20 version bump

On exact candidate `8a13328f531e5644be82053b4e0fa855cea4641c`:

- C145 stale Plywood expected content could be removed correctly.
- **Edit / Remove** and **Count / Adjust** were clear in both light and dark mode.
- Pick List rendered correctly with human-readable `C###` Container IDs.
- Kit Inventory opened correctly.
- Expected Source Container search accepted `145`, `C145`, `c145`, and padded `C030`.
- Material Audit restored Northern Lights T-Post authority to the correct Northern Lights task.
- A browser return-path defect remained: Kit Inventory -> Setup -> Reusable Task Catalog sometimes required `Ctrl+Shift+R`.

### Return-path cache correction

The return-path issue was traced to a stale outer bridge asset pin:

- inner source editor had advanced to `setup_task_extra_material_sources.js?v=2026-09-28.3`;
- outer Production shell still loaded `setup_extra_materials.js?v=2026-09-28.2`.

The candidate was corrected so `production.html` loads:

`setup_extra_materials.js?v=2026-09-28.3`

A regression contract now requires the outer and inner cache-bust boundaries to stay aligned.

Regression for that cache-fix candidate:

`573 passed in 1.07s`

Reusable disposable acceptance after that regression:

`SETUP REUSABLE DISPOSABLE ACCEPTANCE: CLEAN EXIT`

### V0.3.20 regression attempt — current stop point

After advancing the client/server build to `V0.3.20-material-authority`, the full Setup/Application regression was run.

Result:

`572 passed, 1 failed in 1.14s`

The **only failure** is:

`Setup/Application/test_setup_222_performance_trace_contract.py::test_setup_performance_trace_version_is_distinct`

The failing assertion is stale test authority:

`assert 'PRODUCTION_VERSION = "V0.3.19-pick-list"' in text`

The implementation correctly contains:

`PRODUCTION_VERSION = "V0.3.20-material-authority"`

This is a **test-only contract correction**, not an application behavior change. Issue #222 performance tracing itself is not being redesigned here.

### Exact next actions

1. Update only the stale #222 version assertion to require `V0.3.20-material-authority`.
2. Rerun the entire `Setup/Application` regression.
3. If green, write a PASS checkpoint.
4. Rerun reusable disposable acceptance with:
   - `063_harden_setup_extra_material_requirement_lifecycle.sql`
   - `064_add_setup_extra_material_requirement_restore.sql`
   - `setup_206_extra_material_lifecycle_disposable_validation.sql`
5. Run the final focused disposable browser check:
   - header shows **Client V0.3.20**;
   - Kit Inventory -> Back to Setup Session -> Reusable Task Catalog renders correctly **without Ctrl+Shift+R**;
   - server/client build guard is matched and Manager writes remain enabled.
6. Only after those gates pass should Production deployment tooling/review begin.

### Do not lose these release requirements

Before Production:

- do not revert the clearer **Edit / Remove** button or merge it with **Count / Adjust**;
- keep `LINKED TO TASK — DETAILS DIFFER` instead of misleading `TASK LINK NEEDS REVIEW`;
- keep source search compatible with numeric, C-prefixed, and padded Container IDs;
- keep the dedicated **Extra Materials and Kit Inventory** operator SOP and links;
- keep task requirement, source Container, expected Kit content, and physical inventory as separate operator concepts;
- do not fabricate unknown quantities or treat Procedure/PPE mentions as automatic Extra Material authority;
- do not use the old V0.3.19 #206 Production deploy runner unchanged for this V0.3.20/migrations 063+064 release.


### V0.3.20 stale #222 contract corrected

Test-only correction applied at implementation commit:

`621cb13f9876c36014b73b6ad5002b30a507ac92`

Changed only:

`Setup/Application/test_setup_222_performance_trace_contract.py`

Old stale assertion:

`PRODUCTION_VERSION = "V0.3.19-pick-list"`

New assertion:

`PRODUCTION_VERSION = "V0.3.20-material-authority"`

No #222 performance-trace runtime behavior was changed.

**Next action:** run the full `Setup/Application` regression on the documentation checkpoint SHA containing this note.


---

## Continuation Checkpoint — V0.3.20 Full Regression PASS

| Field | Value |
|---|---|
| Exact tested implementation candidate | `431fde764fa8da859f35b1df0e314cb002d66db6` |
| Candidate version | `V0.3.20-material-authority` |
| Full regression command | `python -m pytest -q -p no:cacheprovider Setup/Application` |
| Result | **573 passed in 0.99s** |
| Failures / errors | **0** |
| Branch | `agent/setup-206-tablet-material-audit` |
| PR | #252 — draft / mergeable=true |
| Main comparison before checkpoint | 110 ahead / 0 behind |
| Production mutation authorized | **NO** |

This confirms the V0.3.20 server/client version boundary and the corrected #222 version contract are green with the full Setup/Application regression.

### Next gate

Run reusable disposable acceptance against the exact documentation checkpoint SHA created after this section is committed.

Apply migrations in order:

1. `Setup/Database/063_harden_setup_extra_material_requirement_lifecycle.sql`
2. `Setup/Database/064_add_setup_extra_material_requirement_restore.sql`

Use validation:

`Setup/Acceptance/setup_206_extra_material_lifecycle_disposable_validation.sql`

If clean, run the final focused disposable browser review:

1. header visibly shows **Client V0.3.20**;
2. open Kit Inventory;
3. use **Back to Setup Session**;
4. open/confirm Reusable Task Catalog;
5. page renders correctly without `Ctrl+Shift+R`;
6. server/client build guard is matched and Manager writes are not blocked.

No Production deployment until this final browser gate passes.


---

## PRE-PRODUCTION RELEASE CHECKPOINT — V0.3.20 Material Authority

This is the final acceptance checkpoint before any Production deployment work.

| Field | Value |
|---|---|
| Exact browser-accepted candidate | `947b86a9598584717167cce094cd78d99e9a71e7` |
| Candidate version | `V0.3.20-material-authority` |
| Branch | `agent/setup-206-tablet-material-audit` |
| PR | #252 — DRAFT / mergeable=false |
| Main comparison before checkpoint | 111 ahead / 0 behind |
| Production mutation authorized | **NO — deployment gate only** |
| Current live Production version | `V0.3.19-pick-list` |
| Current live Setup SHA | `fc0b76d57826eebf04b81c99cbb904109162cd87` |

### Full regression

Exact tested implementation:

`431fde764fa8da859f35b1df0e314cb002d66db6`

Result:

`573 passed in 0.99s`

The later documentation-only checkpoint did not alter application/test behavior.

### Reusable disposable acceptance

Exact release candidate:

`947b86a9598584717167cce094cd78d99e9a71e7`

Result:

`SETUP_REUSABLE_DISPOSABLE_ACCEPTANCE_PASS`

Production Setup fingerprint:

- before: `214f843b88a630e03330ac8f378cf0c8`
- after:  `214f843b88a630e03330ac8f378cf0c8`
- **PASS: unchanged**

Live Setup checkout:

- before: `fc0b76d57826eebf04b81c99cbb904109162cd87`
- after:  `fc0b76d57826eebf04b81c99cbb904109162cd87`
- **PASS: unchanged**

Retained report:

`/home/msbadmin/setup-acceptance-reports/Setup_Disposable_Acceptance_20260929T002753.txt`

Exit status: `0`

### Final disposable browser acceptance

Exact release candidate:

`947b86a9598584717167cce094cd78d99e9a71e7`

Operator acceptance:

- visible header shows **Client V0.3.20**;
- Kit Inventory opens;
- **Back to Setup Session** returns cleanly;
- Reusable Task Catalog renders correctly without `Ctrl+Shift+R`;
- no client/server build mismatch blocks Manager actions;
- C145 **Edit / Remove** vs **Count / Adjust** is clear in light/dark mode;
- source search accepts numeric, C-prefixed, lower-case C-prefixed, and padded C### identity forms;
- Material Audit historical restore/reassignment behavior remains correct.

Browser preview cleanup:

`SETUP_REUSABLE_DISPOSABLE_BROWSER_PREVIEW_CLEAN_EXIT`

Production Setup fingerprint:

- before: `214f843b88a630e03330ac8f378cf0c8`
- after:  `214f843b88a630e03330ac8f378cf0c8`
- **PASS: unchanged**

Live Setup checkout:

- before: `fc0b76d57826eebf04b81c99cbb904109162cd87`
- after:  `fc0b76d57826eebf04b81c99cbb904109162cd87`
- **PASS: unchanged**

Retained browser evidence:

- Flask log: `/tmp/Setup_Disposable_Browser_Preview_Flask_20260929T003037.log`
- report: `/home/msbadmin/setup-acceptance-reports/Setup_Disposable_Browser_Preview_20260929T003037.txt`
- exit status: `0`

### Accepted release behavior

Preserve all of the following in Production deployment:

- `V0.3.20-material-authority` server/client build identity;
- Rolling Pick List contains physical actionable picks only;
- no Manager material-diagnostic exception panel on Pick List;
- human-readable Container IDs use `C###`;
- task Extra Material requirement and source Container remain separate facts;
- expected Kit contents and physical inventory remain separate facts;
- **Edit / Remove** is visually distinct from **Count / Adjust**;
- `LINKED TO TASK — DETAILS DIFFER` does not imply a broken source relationship;
- governed historical requirement restore preserves exact requirement/source authority;
- mistaken reusable-task Extra Material remains hard-delete behavior;
- expected-content removal remains dependency guarded;
- source Container search accepts `145`, `C145`, `c145`, and padded labels such as `C030`;
- new Extra Materials and Kit Inventory operator SOP remains linked from Setup operator/manager documentation;
- unknown quantities/specs are not fabricated;
- Procedure/PPE/tool mentions are not automatically promoted into Extra Material authority.

### Production deployment boundary

Do **not** reuse the older V0.3.19 Pick List deployment runner unchanged.

This release requires:

- source/application target corresponding to the accepted V0.3.20 candidate;
- migration 063:
  `Setup/Database/063_harden_setup_extra_material_requirement_lifecycle.sql`;
- migration 064:
  `Setup/Database/064_add_setup_extra_material_requirement_restore.sql`;
- current Production live-state preflight against V0.3.19 / `fc0b76d...`;
- governed rollback/archive handling under MSB-Server-Management authority;
- post-deployment server/client V0.3.20 verification;
- retained Production acceptance evidence.

The next action is **Production deployment engineering/preflight**, not direct ad-hoc mutation.


---

## POST-PRODUCTION BADGE FIX CHECKPOINT — V0.3.20 healthy badge

| Field | Value |
|---|---|
| Production application before badge-only correction | `947b86a9598584717167cce094cd78d99e9a71e7` |
| Production version | `V0.3.20-material-authority` |
| Migration state | 063 + 064 installed |
| Core fingerprint after deployment | `214f843b88a630e03330ac8f378cf0c8` |
| Material fingerprint after deployment | `07aab8c3e63914a3f8d7363e689e580f` |
| Badge-fix implementation head before this checkpoint | `0f442bdb52f276ab01c1909cbe1bb0259c3bb62d` |
| Database mutation required for badge fix | **NO** |

### Production deployment result

The bounded V0.3.20 material-authority Production deployment passed with:

- unchanged core Setup fingerprint;
- unchanged material-authority fingerprint;
- one 2026 Setup Session before/after;
- rollback archive retained at
  `/home/msbadmin/backups/setup-206-material-authority/msb-pre-setup-206-material-authority-20260929T004607.dump`;
- rollback SHA256
  `af2611564c034773e206e68c8cb26bb19813af21a25d1aa40e3b96638be0f6fb`;
- deployment report
  `/home/msbadmin/setup-deployment-reports/Setup_206_Material_Authority_Production_Deploy_20260929T004607.txt`;
- exit status 0.

### Post-deploy badge defect

Operator testing showed:

- Pick List is the corrected/new Production behavior;
- Material Audit is correct;
- public `/setup/api/health` reports
  `V0.3.20-material-authority`;
- a second laptop also displayed **Client V0.3.19**.

The public `setup_catalog_dirty_guard.js` itself proved the cause:

```js
const CLIENT_BUILD = 'V0.3.20-material-authority';
...
badge.textContent = 'Client V0.3.20';
...
badge.textContent = ok ? 'Client V0.3.19' : 'CLIENT / SERVER MISMATCH';
```

So this was **not** a Synology/Cloudflare cache defect. The healthy server/client match callback overwrote the correct V0.3.20 label with stale V0.3.19 display text.

### Correction

Current source-only candidate:

- changes the healthy badge result to **Client V0.3.20**;
- keeps server/client build identity `V0.3.20-material-authority`;
- bumps `setup_catalog_dirty_guard.js` asset pin from
  `v=2026-09-28.1` to `v=2026-09-29.1`;
- extends the dirty-guard regression contract to require the healthy V0.3.20 badge and reject `Client V0.3.19`.

No database/schema/migration behavior changes.

### Next gate

1. run full `Setup/Application` regression on the exact documentation checkpoint SHA created after this section;
2. if green, run an exact-candidate disposable browser preview with **no new migration** and confirm:
   - header shows **Client V0.3.20** after normal reload/navigation;
   - no client/server mismatch warning;
3. deploy as a bounded **source-only** Setup application correction under the Server Management source-only runbook;
4. verify the real protected Production route with a normal reload.

Server Management issue #51 should be updated to record that the apparent cache problem was actually caused by application badge logic; no nginx/Cloudflare mutation is indicated by current evidence.


---

## POST-PRODUCTION BADGE FIX REGRESSION PASS

| Field | Value |
|---|---|
| Exact tested badge-fix candidate | `b19d59997972d1e13c94e0d060396e70df62bf07` |
| Regression command | `python -m pytest -q -p no:cacheprovider Setup/Application` |
| Result | **573 passed in 1.13s** |
| Failures / errors | **0** |
| Production database migration required | **NO** |
| Current Production DB migration state | 063 + 064 already installed |
| Current Production application before source-only follow-up | `947b86a9598584717167cce094cd78d99e9a71e7` / `V0.3.20-material-authority` |

The badge-only correction is green.

It changes only:

- healthy client-build badge text from stale **Client V0.3.19** to **Client V0.3.20**;
- dirty-guard asset cache token to `setup_catalog_dirty_guard.js?v=2026-09-29.1`;
- regression contracts proving a healthy V0.3.20 match cannot render V0.3.19.

No schema, data, migration, Material Audit, Pick List, Kit Inventory, or source-allocation behavior changes.

### Next gate

Run a focused reusable disposable browser preview on the exact documentation checkpoint SHA created after this section, with **no migrations**.

Acceptance:

1. header shows **Client V0.3.20** after initial load;
2. wait for the client/server health check to complete — badge remains **Client V0.3.20**;
3. navigate Setup tabs / return to the Catalog — badge remains V0.3.20;
4. normal browser reload (Ctrl+R) — badge returns as **Client V0.3.20**;
5. no client/server mismatch warning;
6. clean browser-preview exit with Production fingerprint/live SHA unchanged.

If accepted, deploy as a bounded **source-only** Setup application correction using the Server Management source-only deployment runbook. Do not rerun migrations 063/064.


---

## POST-PRODUCTION BADGE FIX BROWSER PASS

| Field | Value |
|---|---|
| Exact preview candidate | `a1f82e4f530a6d3048540537dbf295e7942ce915` |
| Production application during preview | `947b86a9598584717167cce094cd78d99e9a71e7` |
| Production version | `V0.3.20-material-authority` |
| Preview result | **PASS / CLEAN EXIT** |
| Production mutation during preview | **NONE** |

Operator confirmed the disposable browser stayed at **Client V0.3.20**.

Preview cleanup evidence:

```text
SETUP_REUSABLE_DISPOSABLE_BROWSER_PREVIEW_CLEAN_EXIT
Production Setup fingerprint before: 214f843b88a630e03330ac8f378cf0c8
Production Setup fingerprint after:  214f843b88a630e03330ac8f378cf0c8
PASS: Production Setup fingerprint unchanged
Live Setup SHA before: 947b86a9598584717167cce094cd78d99e9a71e7
Live Setup SHA after:  947b86a9598584717167cce094cd78d99e9a71e7
PASS: live Setup checkout unchanged
Preview Flask log: /tmp/Setup_Disposable_Browser_Preview_Flask_20260929T010157.log
Preview report: /home/msbadmin/setup-acceptance-reports/Setup_Disposable_Browser_Preview_20260929T010157.txt
Exit status: 0
```

The V0.3.20 badge defect is therefore corrected in the source-only candidate and independently browser accepted.

### Additional operator UX findings while reviewing Church Tree material

Two non-database UI clarifications remain before the source-only follow-up is frozen:

1. Kit Inventory should present the valid relationship primarily as **LINKED TO TASK**. A task-vs-Kit variant mismatch is subordinate detail, not a broken material/source relationship. Current reverse projection already requires the same `setup_extra_material_id`.
2. **Add Source** should not present an already-active source Container as though it can be added again. Existing source facts are changed through **Change**.

Do not alter database authority or collapse the three separate quantities:

```text
task requirement quantity
source allocation quantity
Kit expected quantity
```

---

## POST-PRODUCTION MATERIAL UX FOLLOW-UP CHECKPOINT

| Field | Value |
|---|---|
| Implementation head before documentation checkpoint | b73e2152912de5fe8382fd59746fbd71bc981be8 |
| Branch | agent/setup-206-tablet-material-audit |
| PR | #252 — DRAFT / mergeable=true |
| Main comparison before checkpoint | 127 ahead / 0 behind |
| Production application currently live | 947b86a9598584717167cce094cd78d99e9a71e7 |
| Production version | V0.3.20-material-authority |
| Database migration state | 063 + 064 installed |
| Database mutation required for this follow-up | **NO** |

### Badge-fix browser gate

The prior badge-only candidate completed disposable browser review with CLEAN EXIT.

Production Setup fingerprint remained 214f843b88a630e03330ac8f378cf0c8 and live Setup remained 947b86a9598584717167cce094cd78d99e9a71e7.

Badge-fix preview evidence:
- /tmp/Setup_Disposable_Browser_Preview_Flask_20260929T010157.log
- /home/msbadmin/setup-acceptance-reports/Setup_Disposable_Browser_Preview_20260929T010157.txt

### Material UX findings accepted from operator review

The same normalized Extra Material catalog identity is already required before Kit reverse task usage is shown. A variant mismatch must not visually imply that the task/source relationship is broken.

Operator-facing Kit state is now:

LINKED TO TASK
Task / Kit spec differs. Material identity and source relationship are already linked.

The prior LINKED TO TASK — DETAILS DIFFER warning and duplicated DETAILS DIFFER suffix are removed. The subordinate spec-difference note is visually de-emphasized.

### Already-linked source behavior

When adding a source to a task requirement:
- Containers already active as sources for that same requirement remain visible for context;
- those options are disabled;
- the option label says **Already linked — use Change**;
- the currently edited source remains selectable in Change Source mode;
- the API duplicate-source guard remains as fail-closed protection.

This addresses the Church Turnbuckle confusion where C145 already existed as source Qty 3 but still appeared selectable through Add Source.

### Asset pins refreshed

- setup_catalog_dirty_guard.js?v=2026-09-29.1
- setup_extra_materials.js?v=2026-09-29.1
- setup_task_extra_material_sources.js?v=2026-09-29.1
- setup_kit_inventory.css?v=2026-09-29.1
- setup_kit_inventory.js?v=2026-09-29.1

### Quantity semantics remain unchanged

Do not collapse task requirement quantity, source allocation quantity, Kit expected quantity, or physical on-hand quantity.

For the reviewed Church Turnbuckle example: task requirement quantity may be blank; C145 source allocation Qty 3 can still be recorded; Kit expected quantity can independently remain unverified; physical on-hand remains uncounted until physically counted.

### Next gate

Run the full Setup/Application regression on the exact documentation checkpoint SHA created after this section.

If green, run one final source-only disposable browser review of:
1. Client V0.3.20 badge remains correct;
2. Kit Inventory shows LINKED TO TASK with subordinate spec note;
3. Add Source shows an already-linked C145 as disabled / Already linked — use Change;
4. Change continues to edit the existing source;
5. clean preview exit with Production fingerprint/live SHA unchanged.

No migrations are required.
