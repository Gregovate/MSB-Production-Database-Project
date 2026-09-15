# Setup T-Post Requirement Reconciliation — 2026-09-14

| Document Control | Value |
|---|---|
| Document Type | Engineering reconciliation record |
| System | Production Database — Setup and Deployment |
| Issues | #167 / #184 |
| Status | CURRENT RECONCILIATION — partial preload approved only where task scope is supported |
| Owner | MSB Production Database engineering |
| Last Reviewed | 2026-09-14 |

## Purpose

Record the current evidence and implementation boundary for Setup T-Post requirements so later work does not reconstruct or simplify the problem incorrectly.

T-Posts are Extra Materials. They are reusable bulk stock and are physically inventoried separately from Kit Boxes. Current shared-stock Containers are:

- Container 36 — `T-Posts - Used For Panels`;
- Container 118 — `T-posts - Too small for panels` / shortened-stock candidate.

A T-Post requirement is a reusable task / installation-scope fact. The physical stock Container is a separate source/allocation fact. Physical on-hand inventory is a third fact.

## 2026 Requirement Ownership Rule

Do **not** add `tpost_qty` / `tpost_length` columns back to `ref.display` and do not put ordinary panel T-Posts into Kit inventory.

A universal `2 posts per Display` calculation is not valid. Adjacent panels can share supports, some installations need extra supports, and several procedures describe task/layout-specific patterns. Therefore:

```text
verified / reviewed installation requirement
    > explicit scoped procedure requirement
    > comparison / gap evidence
```

`ref.display.frame_id -> ref.frame` remains useful as a comparison signal and future rule input, but frame geometry alone must not silently create accepted quantities. If future automation needs shared-support derivation, introduce an explicit installation/support-group concept rather than assuming every Display is independent.

Legacy 5.5-ft evidence is normalized to the nominal 6-ft operational class for 2026 reconciliation while retaining original provenance. Full-foot distinctions (5 / 6 / 7 / 8 ft) remain operationally significant.

## Current Explicit Preload Set

The following rows are supported well enough to preload as reviewable reusable-task requirements. All remain non-verified until Manager review.

| Stage | Task ID | Reusable task | Requirement | Review state | Expected source | Evidence / qualification |
|---|---:|---|---|---|---|---|
| 01 | 1 | Setup Front Entrance Arch | 2 T-Posts, length unresolved | NEEDS_REVIEW | C036 candidate | Procedure consistently requires 2 tie-down posts, but source text conflicts between 5 ft and 6 ft. Preserve quantity; do not choose length. |
| 01 | 65 | Setup Front Entrance Signs | 5 x 5-ft + 3 x 6-ft | UNVERIFIED | C036 | Current procedure subsection explicitly identifies this Front Entrance panel subset. Do not infer the broader document totals into this task. |
| 03 | 200 | Install Welcome to Rotary Making Spirits Bright Panels | 6 x 5-ft | UNVERIFIED | C036 | Procedure explicitly states six 5-ft T-Posts. |
| 08 | 16 | Install Notes and Conductor | 20 EA, length unresolved | UNVERIFIED | C036 | 18 Note-panel posts + 2 Conductor posts. Already represented by migration 044. |
| 09 | 109 | Setup Panels | 6 x 5-ft + 8 x 6-ft + 4 x 8-ft | UNVERIFIED | C036 | Global Warming / Heat Mister procedure explicitly gives the three size totals. |
| 11 | 112 | Setup Panels | 1 x 5-ft + 18 x 6-ft + 5 x 7-ft + 5 x 8-ft | NEEDS_REVIEW | C036 | Sledders is an intentional terrain/layout exception. Top material totals are explicit; detail still contains a question on a six-post 6-ft subgroup. Preserve as review-required exception, never as a normal frame rule. |
| 16 | 132 | Setup Northern Lights | 64 shortened T-Posts, exact length unresolved | NEEDS_REVIEW | C118 candidate | Procedure explicitly requires 64 shortened posts for 66 light positions. C118 is the current short-stock Container; keep source reviewable until field confirmation. |

This set adds twelve specification rows in addition to the already existing Elf Choir unresolved-length row in migration 044.

## Deliberately Deferred / Do Not Guess

### Stage 00 — HWY 42

Procedure says **20 x 5-ft T-Posts**, but current Setup has multiple physical-installation tasks including task 66 (`Setup HWY42 MSB and Rotary Signs`), task 195 (`Setup HWY42 Traffic Signs`), and special task 204 for the 30-minute sign. The procedure does not provide a safe current-task split. Preserve 20 x 5 ft as installation-scope evidence until the task allocation is reviewed.

### Front Entrance / Triangle / Volunteer Path combined procedure

The broad procedure contains 11 x 5-ft, 5 x 6-ft Y-Posts, and 8 x 7-ft posts across several modern scopes. Only the explicit Front Entrance subsection (5 x 5-ft + 3 x 6-ft) is preloaded to task 65. Do not derive the remainder by subtraction. Volunteer Path's historical C072 `50 extra T-Posts` is old stock evidence, not a proven task requirement or current stock source.

### Winter Wonderland

The top material list says 10 x 5-ft, 1 x 6-ft, and 9 x 8-ft, but detailed rows conflict: Krank's VW detail uses a 7-ft center post where the summary describes an 8-ft post, and Flick detail uses 5 ft where the summary says 6 ft. Current work is also split among several reusable Scene tasks. Preserve the detailed evidence but do not load a Stage-total requirement into one task.

### Polar Express / Christmas Vacation

Procedure says 13 x 5-ft + 9 x 7-ft, while the Hose section separately calls for 3 T-Posts and does not establish whether those three are included in the summary totals. Current reusable tasks split Polar Express from Condor/Hose/Eddie. Resolve the task split and inclusion question before preload.

### Traditional Christmas / Frying Santa

Procedure provides useful detailed rows and a top summary of 6 x 6-ft + 16 x 7-ft, plus 2 small Nutcracker posts. Current Setup divides work among task 136 (`Setup Panels`), task 143 (`Deer 1 & 2 panels`), and other Frying-Santa scope. Map individual procedure rows to current work packages before importing.

### Candyland

Procedure instructs one T-Post at every flagged LED-candy-cane location, but the currently reviewed source does not state a final explicit total. Do not infer the count from geometry alone.

### Church RGB Tree

Kit evidence says 3 T-Posts, while the procedure has 2 definite rear guy-wire posts and describes a possible additional front support. Preserve this as a minimum/conditional reconciliation item rather than silently asserting three required posts.

### Santa's Station

Procedure revisions contain changing post evidence (older 5-ft/6-ft counts versus a newer nine-post 6-ft section) and multiple current Setup scopes. Resolve revision/task ownership before preload.

## Why Frame Geometry Is Not the 2026 Quantity Authority

The archived pre-Production matrix contained 137 post-bearing Display rows and 256 historical posts, but comparison to current procedures shows that a naive per-Display rule is unreliable:

- HWY 42: naive 22 vs procedure 20;
- Welcome Area: naive 12 vs procedure 6;
- Elf Choir: naive 18 vs procedure 20;
- Global Warming: naive/archive 16 vs procedure 18;
- Northern Lights: archived Display matrix 0 vs procedure 64 shortened posts;
- Traditional Christmas: naive 32 / archived 30 vs procedure evidence 24;
- Santa's Station: naive 16 / archived 13 vs procedure 9 in the captured scope.

Frame geometry remains valuable for detecting omissions, validating lengths, and eventually supporting a more formal installation-support model. It must not overwrite reviewed task requirements.

## Implementation Boundary

For 2026:

1. store explicit task/installation requirements in `ref.setup_task_extra_material`;
2. store expected source allocation in `ref.setup_task_extra_material_source`;
3. use Container 36 for normal panel stock where supported;
4. use Container 118 only for reviewed shortened-stock allocation;
5. keep physical counts in the append-only inventory ledger;
6. keep unresolved/conflicting task scopes visibly deferred rather than inventing rows;
7. do not create individual identities for physical T-Posts;
8. do not make a Kit assignment imply T-Post source or quantity.

The reusable task UI must expose these task-level requirements independently from Kit contents and physical inventory.
