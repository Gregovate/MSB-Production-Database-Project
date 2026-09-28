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
