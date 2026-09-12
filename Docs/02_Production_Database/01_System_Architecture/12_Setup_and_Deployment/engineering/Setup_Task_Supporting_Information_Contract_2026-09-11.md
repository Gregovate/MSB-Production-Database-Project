# Setup Task Supporting Information Contract — 2026-09-11

| Document Control | Value |
|---|---|
| Document Type | Engineering Operating-Model Contract |
| System | Production Database — Setup and Deployment |
| Status | CURRENT DESIGN CONTRACT — operator-confirmed; implementation incomplete |
| Owner | MSB Production Database engineering |
| Last Reviewed | 2026-09-12 |
| Related Work | #122, #132, #141, #145, #167, #169, #171, #172, #175 |

## Purpose

Preserve the operator-confirmed model for the information that must support reusable Setup tasks and annual field execution without forcing every procedure step, material detail, or field discovery into an independent scheduled task.

This document exists so future engineering can resume from the repository instead of reconstructing these decisions from chat history or scattered issue comments.

## 2026 Launch Control and Sequence

The 2025 Setup Session is intentionally the **sandbox / proving ground** while reusable Catalog, task ownership, material, and field-execution behavior are corrected. Preserve its historical data and use it to prove the reusable system. Do not create the real 2026 Setup Session merely to make current screens look complete.

The operational launch point is **Issue #122 / creation and scheduling of the real 2026 Setup Session by September 30, 2026**.

The accepted pre-launch dependency order is:

```text
#169  Persistent active-task identity while editing
   -> error-prevention control while Catalog work is underway
   -> selected task name must remain visible while long task detail scrolls

#145  Reusable Catalog cleanup / correct schedulable work packages
   -> remove reconstruction mistakes and incorrect task boundaries
   -> preserve meaningful reusable work packages
   -> hard gate before real 2026 Session creation

#141  Task-specific Display ownership/material subdivision
   -> preserve the accepted Stage/Scene resolver as the source set
   -> each resolved Display has exactly one effective Setup-task owner
   -> Managers can reassign a Display to another real schedulable task
   -> do not replace the working resolver with a second Display-membership system
   -> Containers remain non-exclusive and may support several tasks

#167  Extra Materials / KITs / material sources
   -> normalized Extra Material identities and task requirements
   -> existing ref.container KIT/support relationships
   -> expected sources/contents without requiring full 2027 KIT inventory

#122  SEPTEMBER 30 SCHEDULING LAUNCH GATE
   -> create the real 2026 Setup Session only after the reusable/task/material foundation is accepted
   -> support 2026 scheduling
   -> explain what Displays, Containers/KITs, Extra Materials, and constrained Resources need to be brought to the park and when
```

After the September 30 scheduling launch, a second **field-start gate** applies before crews rely on the system for physical Setup:

```text
#132       Production Crew governed work/progress/completion reporting
#113/#88   Scan + Location/movement execution needed by Setup
#171       GIS/layout + targeted underground-locate workflow
#175       offline/print Setup field packet + Work Order correction fallback
```

These field-start items do not all necessarily block creating/scheduling the 2026 Session, but the required portions must be accepted before real crews depend on them in the park.

### Preservation rule

Current accepted Production behavior wins over stale issue prose or older design discussion. Future implementation must preserve at least:

- V0.3.7 dirty-edit/client-build protections;
- V0.3.8 compact task-detail behavior;
- V0.3.9 prerequisite behavior;
- V0.3.10 Resource Catalog behavior;
- the working Stage/Scene Display resolver;
- 2025 historical/sandbox boundaries;
- current Display/Container authority; and
- the prohibition on creating the real 2026 Session before the accepted gates pass.

## Core Principle — Task Granularity

A reusable Setup task is a **meaningful operational control point**, not a transcription of every instruction step.

Each scheduled/annual task creates real operator burden because somebody must understand it, schedule it, report progress, and explicitly complete it. Create or retain an independently tracked task when its completion materially changes operational state, for example when it:

- unlocks a hard predecessor;
- represents a meaningful handoff or independently staffed work package;
- changes readiness for later work;
- releases or consumes a materially different set of Displays, Containers, KITs, Extra Materials, or Equipment;
- has useful independent progress/history; or
- represents a meaningful completion/verification point.

Detailed work steps that do not need independent planning/completion remain in the Procedure.

Conceptually:

```text
SCHEDULE / TASK
    -> meaningful work package / control point

SUPPORTING INFORMATION
    -> Displays / Containers
    -> Extra Materials
    -> KIT/support Containers
    -> expected material sources
    -> Equipment / Resources
    -> prerequisites / readiness
    -> expected crew / effort
    -> spatial/GIS context
    -> staged-release timing

PROCEDURE
    -> detailed how-to steps that do not need separate annual completion
```

Issue #169 is part of this cleanup safety boundary. While Managers are reviewing/creating reusable tasks, the active task identity must remain visible so scrolling a long detail screen does not cause an edit to be made against the wrong task.

## Authority Hierarchy

The system must distinguish evidence, default rules, exceptions, and verified results.

Accepted precedence:

```text
VERIFIED / ACCEPTED RESULT
    -> authoritative current reusable/operational fact

otherwise
    -> explicit scoped override / exception, when one exists
    -> otherwise derived/default rule
    -> legacy Procedure evidence supports, seeds, or challenges the suggestion
```

Legacy procedures are valuable evidence but are not guaranteed to be 100 percent accurate. They may be used to recover quantities, specifications, KIT references, source clues, crew/effort clues, special cases, and unresolved questions.

Current LOR / Production Display identity and membership supersede obsolete legacy Display naming/membership.

## Current Procedure-Reconciliation Evidence Baseline

The current September 12 extraction/reconciliation workbook represents:

```text
36 legacy Setup PDFs
95 machine-normalized material candidates
507 raw material evidence rows
19 reconciliation issues after crew review
3 remaining stage gaps: 12, 21, 25
crew extraction complete for all 36 procedures
```

The `95` candidate count is **not** the number of real canonical Extra Materials. The candidate list contains parser/free-text fragmentation, spelling variants, unit variations, equipment mixed with supplies, and incorrect size assumptions. Treat the evidence rows as provenance and the candidate list as a reconciliation worklist, not as a Production catalog.

Task-split review and duration extraction are not complete for all 36 procedures. Do not promote `PENDING` task-split/duration fields into accepted reusable truth.

## Display Ownership Across Reusable Tasks — Issue #141

The accepted Stage/Scene resolver remains the authoritative source set for current Displays. Do not replace it.

For a simple Stage/Scene with one material-bearing task, the current behavior can remain effectively unchanged.

For a Stage/Scene with several independently schedulable Setup tasks, add an assignment layer **after** resolution:

```text
current Stage/Scene LOR resolver
    -> resolved current Displays
    -> each Display assigned to exactly ONE effective reusable Setup task
```

Required rules:

- one current Display may belong to only one effective Setup task within the applicable Setup scope;
- a Manager may move/drag a Display from one task to another when the real schedulable work package requires it;
- moving the Display changes its effective task owner; it must not remain duplicated across both tasks;
- coverage validation must expose a resolved Display that is not owned by any applicable material task;
- the assignment layer must not become a competing source of Stage/Scene membership; LOR remains authority for which Displays exist in the scope;
- accepted current resolver behavior must remain intact for scopes that do not need subdivision.

Containers deliberately do **not** follow the one-owner rule. A physical Container/KIT may support several tasks at the same time or remain present across several sequential tasks.

## Display-Derived Support Rules

Do not duplicate data on every Display when an existing authoritative physical characteristic can generate a useful default.

Production already carries `ref.display.frame_id -> ref.frame.w_ft / h_ft` coverage. Panel orientation is represented by distinct frame definitions such as `4w x 8h` versus `8w x 4h`.

For T-post support, the accepted concept is:

```text
Display frame geometry / orientation
    -> normal T-post suggestion
    -> explicit Stage / Scene / task / Display override where field conditions require it
    -> verified result becomes authoritative
```

Operational rules confirmed during procedure reconciliation include:

- tall panels normally need taller T-posts;
- shorter panels can normally use medium/shorter T-posts;
- T-post length is materially significant and must not be flattened into generic `T-Post`;
- `Y-Post` in legacy/free-text evidence is a spelling/naming error for T-Post, not a separate material family;
- standard panel spacer references around 21/22 inches are the same normal spacer class for current planning purposes;
- custom/fitted spacers remain distinct and should normally be expected in the applicable Display/Stage KIT when that is the real field arrangement;
- terrain/layout can intentionally override the normal frame-derived support suggestion; and
- Sledders is a known exception where varied T-post lengths intentionally build a visual hill over uneven terrain and therefore must not be used to infer a normal frame rule.

Do not seed frame-to-T-post mappings unless actual evidence supports the mapping.

## Extra Material Catalog — Canonical Identity Versus Procedure Wording

Extra Materials are non-LOR physical supplies/support items needed to perform Setup work. The Production catalog must not be generated by accepting procedure free text as identity.

The model must separate a stable **material family** from meaningful variant/specification attributes.

Examples of accepted normalization direction:

- `21 inch spacer` and `22 inch spacer` -> one standard panel spacer class while preserving the original procedure wording as evidence;
- custom/fitted spacers -> separate display/stage-specific variants, normally expected in the associated KIT where appropriate;
- `Bungee`, `Ball Bungee`, and spelling variants -> normalize to **Ball Bungee** unless evidence establishes a materially different item;
- Ball Bungees may have only a small number of real size variants; do not manufacture catalog identities from every wording variation;
- D-Rings have accepted size families of **1/4 inch** and **5/16 inch**; different lengths/configurations may still matter when verified;
- a parsed `3/8 inch D-Ring/D-clip` is not accepted merely because extraction produced it;
- extension cord identity must use **wire gauge (AWG) + length** where known; color is not a reliable gauge/identity attribute because cord colors vary;
- carabiners have two operational sizes; reconcile exact verified sizes rather than leaving vague duplicate free-text names;
- 3-way taps are one common material type unless later evidence establishes a real variant;
- generic `hardware`, `misc hardware`, unidentified support pieces, clips, etc. remain unresolved evidence until identified; do not create accepted catalog rows named only `Hardware`;
- feet/inches wording is provenance, not identity fragmentation. Store dimensions in a normalized comparison unit and render an operator-friendly form.

The requirement answers:

> What does this work require, in what quantity/specification?

The requirement remains independent from where the material happens to be stored.

## Resource Catalog Versus Extra Materials

The existing Resource Catalog owns reusable Setup resources such as:

- Locator;
- sledgehammers;
- post pounders;
- post pullers;
- ladders;
- Boom Lifts;
- SkyTrak;
- Tool Cat;
- trailers;
- trucks/vehicles; and
- similar reusable tools/equipment/transport assets.

Do **not** duplicate an existing Resource as an Extra Material simply because a procedure mentions it or because it lives inside a KIT.

A resource may have an expected storage/source relationship to a KIT without changing catalog ownership. Example: a scaffold wrench can remain a Resource/Tool while the applicable KIT records that the wrench is expected to be physically present there.

Task requirement and physical source are separate facts.

The scheduler may later need available-capacity information for scarce Resources. Example: if MSB owns one Locator and two Locate tasks each require one Locator, those tasks cannot be scheduled concurrently. Consumable stock does not create the same scheduling semantics merely because two tasks use it.

## Reusable Versus Consumable Extra Materials

Extra Materials need a lifecycle distinction between reusable and consumable items.

Examples:

```text
REUSABLE
    T-posts
    spacers
    D-rings
    carabiners
    Ball Bungees
    extension cords
    3-way taps

CONSUMABLE
    zip ties
    electrical tape
    marking paint
```

For a consumable, the task requirement normally represents what must be available for that Setup work, not an inventory quantity expected to return after Takedown.

Zip ties are used during Setup and cut off during Takedown. **Length and minimum required quantity** are therefore materially important attributes. Do not model returned piece count as if zip ties were durable hardware.

## Marking Paint

Marking paint is a consumable Extra Material used by layout/locate work.

Accepted canonical family/variant direction:

```text
Marking Paint
Lifecycle: CONSUMABLE
Can type: inverted / wand-compatible

RED
    purpose: underground high-voltage marking

BLUE
    purpose: underground network marking

WHITE
    purpose: Display location / layout datum/reference marking
```

Color is operationally meaningful here, not cosmetic.

Marking-paint task requirements should carry minimum quantity by variant where known.

Marking paint should remain consumable material demand rather than being turned into a scarce scheduling Resource merely because it is used by the same Locate/Layout task as the Locator.

## KIT / Support Containers

KITs are existing physical `ref.container` records. Do not create a competing KIT identity catalog.

The leading reusable assignment contract remains:

```text
reusable Setup task -> ref.setup_task_container_support -> ref.container
```

This relationship is many-to-many:

- one task may depend on multiple KIT/support Containers;
- one KIT may support multiple tasks;
- one KIT may support tasks in more than one Stage/Scene.

A KIT does **not** belong to one task merely because that task first needs something from it.

Physical Container presence is more important than trying to identify which dependent task is consuming the box at a specific instant.

A KIT may contain objects owned by different authoritative subsystems, for example:

- Extra Materials;
- Resource Catalog tools such as a scaffold wrench;
- WiFi hotspots/network devices;
- cameras;
- smaller controllers; and
- other future auditable inventory classes.

Do not force all heterogeneous Container contents into the Extra Material catalog merely to create a 2026 expected-content list.

## KIT Lifecycle Across Delayed Steps

A KIT may remain deployed through several Setup steps and may remain at the park until the entire dependent Stage/Scene work is complete.

Conceptually:

```text
NEEDED
    -> DEPLOYED
    -> IN USE
    -> READY TO RETURN
    -> RETURNED
```

`READY TO RETURN` must not be inferred because one dependent task completed.

For a shared KIT, return eligibility occurs only when **all applicable annual dependants** are complete or otherwise explicitly released.

Returning a KIT home must not itself mark unrelated dependent work complete.

## Requirement Versus Source Versus Actual Inventory

These are different facts and must not be collapsed:

```text
WHAT IS REQUIRED
vs.
WHERE IT IS EXPECTED TO COME FROM
vs.
WHAT IS PHYSICALLY PRESENT NOW
```

A single requirement may be split across sources.

Example:

```text
Requirement: 20 standard spacers
Expected source allocation:
    16 from KIT C060
    4 from shared spacer stock
```

If field validation finds only 14 in C060, that verified observation must be preserved and the resulting shortfall exposed without changing the underlying task requirement of 20.

For 2026, expected source may legitimately be an existing `ref.container` or a current physical storage location/rack when that is the real arrangement. Do not invent a new source catalog before current Production source identities are inventoried.

## KIT Expected Contents and 2027 Auditability

Existing KIT-content information is imperfect but operationally useful and should be imported/reviewed rather than discarded until perfect.

For 2026:

- preserve expected KIT contents/source relationships;
- preserve expected quantity/specification where known;
- permit Production Crew to validate/report what is physically found;
- expose shortages/conflicts instead of blocking Setup because inventory is imperfect; and
- do not require a complete item-by-item KIT inventory before Setup can operate.

For 2027, the model must support auditable physical KIT inventory without redesigning the requirement/catalog foundation. Future inventory must be able to preserve who validated/changed what, when, source/evidence, and historical count/validation events rather than only one mutable quantity.

## Staged Material Release — Issue #141 Boundary

Issue #167 establishes **what** is needed and **where** it is normally expected to come from.

Issue #141 owns the remaining question of **when** that requirement should become actionable/pickable during multi-step Setup.

The Pick List must not interpret Stage membership as `pick everything now`.

The desired flow is:

```text
near-term scheduled / selected meaningful work
    -> Display owner task + Extra Material requirements + KIT/support requirements
    -> release/pick timing
    -> current source / KIT / Container state
    -> logistics action
```

Material may deliberately remain in the workshop until a later task needs it.

Magic Igloo remains the representative case: temperature-sensitive skins may need to remain warm until the frame is ready even though other material for the same Stage is needed earlier.

If one physical KIT contains both an early-needed item and a later-sensitive item, that is a real **source/release conflict** to expose. Operators may deliberately choose early staging when it is the best logistics decision, but that must be an informed choice rather than a default caused by missing information.

## Staging Is a Logistics Choice, Not a Reusable Task

Historic `Staging to Park` behavior largely compensated for incomplete information by moving material early so crews would not be stopped later.

The future system should derive logistics demand from actual upcoming work and trusted Production data.

Conceptually:

```text
scheduled / selected work
    -> Displays / Containers
    -> KITs / Extra Materials
    -> Equipment / constrained Resources
    -> staged-release rules
    -> Pick List / logistics
```

Early staging remains permissible when it reduces trips or otherwise makes operational sense. It is not the automatic answer to uncertainty.

## Ground Penetration / Locate Readiness

Underground locating is not a mandatory task for every Stage or every Setup area.

Operator-confirmed rule:

> Locate/clear underground infrastructure only where planned ground penetration has a plausible chance of intersecting buried network/power infrastructure or where the risk is unresolved.

The desired future decision uses the existing park spatial information:

```text
planned Display / stake / anchor / rebar footprint
    + known buried power/network reference tracks
    -> plausible conflict / unresolved risk?

NO
    -> no locate requirement

YES / UNCERTAIN
    -> locate/clear affected area before ground penetration
```

The existing external GIS/GPS information is not yet integrated into the new Setup system. Issue #171 owns this 2026 improvement. Site Infrastructure / GIS owns reference spatial data/calculation; Setup owns the readiness/business decision.

`No locate required` is a derived/reviewed readiness fact, not another annual task someone must manually complete.

## Production Crew Execution Boundary

Production Crew are trusted operational users. Within governed application commands, ordinary field work must allow them to:

- perform assigned work;
- report progress/work performed;
- explicitly complete operational tasks;
- validate what is physically present;
- report shortages, discrepancies, damage, incorrect data, and other issues;
- record testing/verification results where the owning subsystem permits it; and
- confirm movement/scanning actions appropriate to their work.

Managers retain business-decision authority to create/change reusable task definitions, prerequisites, catalogs/default rules, durable KIT/material assignments, and similar reusable configuration.

Administrators retain the smaller set of system/annual-structure authority where required.

The current Directus environment has **no Captain/Supervisor role**. `CAPTAIN` / `ALTERNATE` are Setup task-leadership assignments, not Directus authorization classes. Do not invent a Captain/Supervisor Directus role as part of the current work.

The current Setup implementation that limits progress/completion to Manager or assigned Captain/Alternate is therefore an authorization gap to correct under Issue #132.

## Field Corrections, Work Orders, and Continuous Improvement

Concrete field conditions that are **wrong and need somebody to act later** may go directly into the existing Work Order system from the current Setup context.

This reflects current successful field use: Work Orders already provide a useful Manager-visible actionable list for findings such as missing Displays that are not represented correctly in LOR/Production data.

Examples appropriate for a direct Work Order include:

- expected Display/material missing from the recorded Container;
- wrong Container assignment requiring follow-up;
- expected KIT content missing;
- an item found in a KIT but not represented in expected contents;
- procedure content missing/wrong;
- reusable requirement/default wrong and needing Manager correction;
- damaged/broken physical item;
- missing item requiring fabrication/replacement/procurement; and
- other concrete wrong/missing conditions that need action.

Creating the Work Order does **not** automatically mutate canonical LOR, Setup, Container, KIT, material, procedure, or other authoritative data. The Work Order is the actionable follow-up record; the Manager determines the final correction.

The connected Production Crew field action should be low friction, conceptually:

```text
Report Problem / Create Work Order
```

Pre-populate context already known by the application when available:

- Setup session / annual task;
- reusable task;
- Stage / Sub-stage / Scene;
- Container/KIT ID;
- Display/material/resource/controller identity;
- procedure/publication identity/revision;
- authenticated requester;
- timestamp.

The reporter should mainly supply **what is wrong / missing / needed**.

The Work Order should enter the shared Manager-visible queue rather than require one specific Manager to be available.

Issue #172 remains useful for broader observations, improvement ideas, or cases where the correct action/owner is genuinely unclear. Do not build a second competing correction queue merely for Setup.

## Offline / Unregistered-Worker Fallback — Issue #175

Internet access is not reliable everywhere in the park, and not every helper will necessarily have an application account.

Paper remains a valid fallback intake mechanism, but it must not become a competing source of truth.

Issue #175 owns the Setup implementation of the existing shared field-publication/currentness contract:

- generate a self-contained printable/offline Setup field PDF;
- embed required procedure images;
- identify the exact resolved task/scope/source revision;
- show visible absolute `Generated` and `Expires` timestamps;
- include an obvious handwritten correction/problem area; and
- retain enough task/container/document context that returned paper can be reconciled unambiguously.

When a paper correction is returned, an authorized user can enter the actionable problem into the same Work Order path. The Work Order then becomes the durable follow-up record.

## Continuous-Improvement Principle

The desired seasonal loop is:

```text
Takedown / Testing / repair / Setup / operation
    -> validate authoritative state while doing real work
    -> report concrete corrections through Work Orders when action is needed
    -> use broader observation/triage only where appropriate
    -> correct the responsible system
    -> preserve verified results
    -> next season starts with better information
```

The objective is not to add more checkboxes. It is to make each season improve the next one and prevent known problems from falling back into tribal knowledge.

## 2026 Implementation Posture

The 2026 target is a solid, useful foundation, not false precision.

Use the best available procedures, Production data, derived rules, KIT/source information, and verified field evidence. Keep uncertainty visible. Prefer deterministic defaults plus explicit overrides over hundreds of manually duplicated fields.

Do not block useful 2026 operation on the future 2027 detailed KIT inventory.

Do not create the real 2026 Setup Session until the #169/#145/#141/#167 pre-launch foundation is accepted and the #122 disposable creation/scheduling proof passes.

## Resume Development

Before implementing this contract:

1. read the Production Database Project Rules;
2. refresh current `main` and read the current Setup engineering handoff/README;
3. preserve accepted V0.3.7 through V0.3.10 behavior;
4. treat 2025 as the sandbox/historical proving ground until the pre-launch gates pass;
5. read Issues #169, #145, #141, #167, and #122 before changing the reusable Catalog/task/material/scheduling path;
6. read Issues #132, #113/#88, #171, and #175 before field-start execution work;
7. read the current Production schema/migrations before asking the operator to rediscover schema facts;
8. use governed `SECURITY DEFINER` application commands and actor attribution rather than broad table DML; and
9. update this contract, the engineering README, related subsystem documentation, issues, and acceptance evidence whenever implementation establishes or corrects durable behavior.

## Related Durable Sources

- [Setup engineering portal](README.md)
- [Setup Planning Operating Model](Setup_Planning_Operating_Model_2026-09-08.md)
- [Setup Pick List Tablet Workflow](Setup_Pick_List_Tablet_Workflow_2026-09-09.md)
- [Setup Stage / Scene Material Resolution Contract](Setup_Stage_Scene_Material_Resolution_Contract_2026-09-10.md)
- [Setup Data Consumption and Authorization Contract](Setup_Data_Consumption_and_Authorization_Contract_2026-09-10.md)
- [Field Document Publication and Currentness Contract](../../07_Labeling_and_Scanning/Field_Document_Publication_and_Currentness_Contract.md)
- [Site Infrastructure / GIS](../../11_Site_Infrastructure_GIS/README.md)
- GitHub #122 — Setup Session umbrella / September 30 scheduling launch gate
- GitHub #132 — Production Crew work reporting / duration / execution authorization
- GitHub #141 — Display-to-task ownership / staged material release
- GitHub #145 — Catalog cleanup gate before 2026 Session creation
- GitHub #167 — Extra Materials / KIT / material source foundation
- GitHub #169 — persistent active-task identity while editing
- GitHub #171 — GIS/layout/targeted locate integration
- GitHub #172 — broader field observation / continuous-improvement triage
- GitHub #175 — offline/print Setup field packet + Work Order correction handoff
