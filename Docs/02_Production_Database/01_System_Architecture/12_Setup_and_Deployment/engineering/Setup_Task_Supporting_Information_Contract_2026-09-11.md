# Setup Task Supporting Information Contract — 2026-09-11

| Document Control | Value |
|---|---|
| Document Type | Engineering Operating-Model Contract |
| System | Production Database — Setup and Deployment |
| Status | CURRENT DESIGN CONTRACT — operator-confirmed; implementation incomplete |
| Owner | MSB Production Database engineering |
| Last Reviewed | 2026-09-11 |
| Related Work | #122, #132, #141, #145, #167, #171, #172 |

## Purpose

Preserve the operator-confirmed model for the information that must support reusable Setup tasks and annual field execution without forcing every procedure step, material detail, or field discovery into an independent scheduled task.

This document exists so future engineering can resume from the repository instead of reconstructing these decisions from chat history.

## Core Principle

A reusable Setup task is a **meaningful operational control point**, not a transcription of every instruction step.

Each scheduled/annual task creates real operator burden because somebody must understand it, schedule it when appropriate, report progress, and explicitly complete it. Create or retain an independently tracked task when its completion materially changes operational state, for example when it:

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

Legacy procedures are valuable evidence but are not guaranteed to be 100 percent accurate. They may be used to recover quantities, specifications, KIT references, source clues, special cases, and unresolved questions.

Current LOR / Production Display identity and membership supersede obsolete legacy Display naming/membership.

## Display-Derived Support Rules

Do not duplicate data on every Display when an existing authoritative physical characteristic can generate a useful default.

Production already carries extensive `ref.display.frame_id -> ref.frame.w_ft / h_ft` coverage. Panel orientation is represented by distinct frame definitions such as `4w x 8h` versus `8w x 4h`.

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
- standard panel spacer references around 21/22 inches are the same normal spacer class for this purpose;
- terrain/layout can intentionally override the normal frame-derived support suggestion;
- Sledders is a known example where varied T-post lengths intentionally build a visual hill over uneven terrain and therefore must not be used to infer a normal frame rule.

The 2026 objective is a useful default close enough for planning, with field verification/overrides improving the reusable truth over time.

## Extra Materials

Extra Materials are non-LOR physical items needed to perform Setup work, for example:

- T-posts by meaningful length;
- standard and custom spacers;
- bungees by materially different size/type;
- extension cords where they are not already represented by another authoritative subsystem;
- rebar spikes;
- post bases;
- short pipe / dedicated hardware;
- consumable or reusable support material not represented by current LOR Display membership.

The requirement answers:

> What does this work require, in what quantity/specification?

The requirement must remain independent from where the material happens to be stored.

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

Example:

```text
KIT X expected contents
    -> skins
    -> long bungees
    -> mats
    -> camera/finish hardware

Task B — install skins
    -> requires some contents from KIT X

Task C — finish / cameras / mats
    -> requires other contents from KIT X
```

The Pick List/logistics layer must deduplicate the physical KIT while preserving every task/Stage/Scene reason that still depends on it.

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

## KIT Expected Contents and 2027 Auditability

KIT contents contain valuable Extra Material inventory. Existing information is imperfect but useful and should be imported/reviewed rather than discarded until perfect.

For 2026:

- preserve expected KIT contents/source relationships;
- preserve expected quantity/specification where known;
- permit Production Crew to validate/report what is physically found;
- expose shortages/conflicts instead of blocking Setup because inventory is imperfect.

For 2027, the model must support auditable physical KIT inventory without redesigning the requirement/catalog foundation. Future inventory must be able to preserve who validated/changed what, when, source/evidence, and historical count/validation events rather than only one mutable quantity.

## Staged Material Release — Issue #141 Boundary

Issue #167 establishes **what** is needed and **where** it is normally expected to come from.

Issue #141 owns the remaining question of **when** that requirement should become actionable/pickable during multi-step Setup.

The Pick List must not interpret Stage membership as `pick everything now`.

The desired flow is:

```text
near-term scheduled / selected meaningful work
    -> material requirements for that work
    -> release/pick timing
    -> current source / KIT / Container state
    -> logistics action
```

Material may deliberately remain in the workshop until a later task needs it.

Magic Igloo remains the representative case: temperature-sensitive skins may need to remain warm until the frame is ready even though other material for the same Stage is needed earlier.

If one physical KIT contains both an early-needed item and a later-sensitive item, that is a real **source/release conflict** to expose. The system should not silently move the whole box early merely because it is easier. Operators may deliberately choose early staging when it is the best logistics decision, but that should be an informed choice rather than the default caused by missing information.

## Staging Is a Logistics Choice, Not a Reusable Task

Historic `Staging to Park` behavior largely compensated for incomplete information by moving material early so crews would not be stopped later.

The future system should derive logistics demand from actual upcoming work and trusted Production data.

Conceptually:

```text
scheduled / selected work
    -> Displays / Containers
    -> KITs / Extra Materials
    -> Equipment
    -> staged-release rules
    -> Pick List / logistics
```

Early staging remains permissible when it reduces trips or otherwise makes operational sense. It is not the automatic answer to uncertainty.

## Ground Penetration / Locate Readiness

Underground locating is not a mandatory task for every Stage or every setup area.

Operator-confirmed rule:

> Locate/clear underground infrastructure only where planned ground penetration has a plausible chance of intersecting buried network/power infrastructure or where the risk is unresolved.

Do not spend crew time locating areas where there is nothing underground to damage.

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

Managers retain the business-decision authority to create/change reusable task definitions, prerequisites, catalogs/default rules, durable KIT/material assignments, and similar reusable configuration.

Administrators retain the smaller set of system/annual-structure authority where required.

The current Directus environment has **no Captain/Supervisor role**. `CAPTAIN` / `ALTERNATE` are Setup task-leadership assignments, not Directus authorization classes. Do not invent a Captain/Supervisor Directus role as part of the current work.

The current Setup implementation that limits progress/completion to Manager or assigned Captain/Alternate is therefore an authorization gap to correct. Issue #132 carries the work-report implementation area; broader cross-system consistency is part of #172.

## Field Exceptions and Continuous Improvement

The system should trust cleaned authoritative Production data during work, while making exceptions easy to preserve and correct.

A Production Crew member who finds a problem should not need to know which subsystem owns the final correction and should not need Manager authority merely to report the observation.

Examples include:

- expected Display/material not found in the recorded Container;
- wrong Container assignment;
- KIT contents do not match expected contents;
- procedure incomplete/wrong;
- reusable requirement/default wrong;
- GIS/layout/underground route information wrong or missing;
- task/readiness rule causes avoidable work or delay;
- physical defect that should become a Work Order.

Issue #172 owns the cross-system **observation -> triage -> action** bridge.

Target concept:

```text
Production Crew observes problem / improvement opportunity
    -> record actor/time/context/evidence
    -> durable triage queue
    -> responsible owner classifies action
         -> Work Order / repair
         -> Production data correction
         -> Setup reusable-data correction
         -> Testing correction
         -> GIS correction
         -> engineering issue / future improvement
         -> informational / duplicate / no action
    -> preserve link to resulting action
```

Do not turn every field observation into a Work Order. Work Orders remain authoritative for repair work; GitHub issues remain engineering work items; controlled repository documentation remains the authority for durable architecture/operating knowledge.

## Continuous-Improvement Principle

The desired seasonal loop is:

```text
Takedown / Testing / repair / Setup / operation
    -> validate authoritative state while doing real work
    -> report exceptions immediately
    -> triage and correct the responsible system
    -> preserve verified results
    -> next season starts with better information
```

The objective is not to add more checkboxes. It is to make each season improve the next one and prevent known problems from falling back into tribal knowledge.

## 2026 Implementation Posture

The 2026 target is a solid, useful foundation, not false precision.

Use the best available procedures, Production data, derived rules, KIT/source information, and verified field evidence. Keep uncertainty visible. Prefer deterministic defaults plus explicit overrides over hundreds of manually duplicated fields.

Do not block useful 2026 operation on the future 2027 detailed KIT inventory.

Do not create the real 2026 Setup Session until Issue #145's Catalog-cleanup gate is accepted.

## Resume Development

Before implementing this contract:

1. read the Production Database Project Rules;
2. refresh current `main` and read the current Setup engineering handoff/README;
3. read Issues #141, #145, #167, #171, and #172 in full;
4. read the current Production schema snapshot before asking the operator to rediscover schema facts;
5. preserve V0.3.10 resource-catalog behavior;
6. inventory current data/relationships before approving new schema;
7. use governed `SECURITY DEFINER` application commands and actor attribution rather than broad table DML; and
8. update this contract, the engineering README, related subsystem documentation, issues, and acceptance evidence whenever implementation establishes or corrects durable behavior.

## Related Durable Sources

- [Setup engineering portal](README.md)
- [Setup Planning Operating Model](Setup_Planning_Operating_Model_2026-09-08.md)
- [Setup Pick List Tablet Workflow](Setup_Pick_List_Tablet_Workflow_2026-09-09.md)
- [Setup Stage / Scene Material Resolution Contract](Setup_Stage_Scene_Material_Resolution_Contract_2026-09-10.md)
- [Setup Data Consumption and Authorization Contract](Setup_Data_Consumption_and_Authorization_Contract_2026-09-10.md)
- [Site Infrastructure / GIS](../../11_Site_Infrastructure_GIS/README.md)
- GitHub #122 — Setup Session umbrella
- GitHub #132 — Setup work reporting
- GitHub #141 — staged material release / Pick List timing
- GitHub #145 — Catalog cleanup gate before 2026 Session creation
- GitHub #167 — Extra Materials / KIT / material source foundation
- GitHub #171 — GIS/layout/targeted locate integration
- GitHub #172 — field observation / continuous-improvement intake and triage
