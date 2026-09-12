# Setup and Deployment Engineering

| Document Control | Value |
|---|---|
| Document Type | Engineering Handoff Portal |
| System | Production Database — Setup and Deployment |
| Audience | Greg, maintainers, database administrators, future engineering sessions |
| Status | CURRENT HANDOFF — V0.3.11 accepted in Production; 2026 launch preparation active |
| Owner | MSB Production Database engineering |
| Last Reviewed | 2026-09-12 |

This is the engineering starting point for Setup Session architecture, database behavior, application contracts, Production state, reconstruction rules, planning behavior, Pick List direction, and resume information.

The operator-facing instructions are separate under [`../operatorSOP/`](../operatorSOP/README.md).

## Current Production State

Protected application:

```text
https://my.sheboyganlights.org/setup/
```

Current exact accepted/deployed application target:

```text
28ad2d28addd47f8f086ed3b2e53468b453dbe13
```

Current Setup health:

```text
V0.3.11-active-task-context
```

Current annual context:

```text
2025 Setup Session  = HISTORICAL_VERIFICATION / SANDBOX
2026 Setup Sessions = 0
```

The 2025 season is intentionally being used as the proving ground while reusable tasks, task material ownership, Extra Materials/KITs, and field execution behavior are corrected. Preserve historical 2025 evidence. Do not create the real 2026 Setup Session before the launch gates below pass.

V0.3.11 persistent active-task context is accepted in Production. V0.3.10 Resource Catalog behavior remains accepted beneath it and must be preserved.

## 2026 Launch Sequence

The launch target is **real 2026 Setup Session creation and scheduling by September 30, 2026 under Issue #122**.

Issue #169 is complete and no longer a remaining launch gate. Its accepted V0.3.11 header context is now part of the Production safety baseline used during Catalog cleanup.

The remaining pre-launch dependency order is:

```text
#145  Reusable Catalog cleanup / correct schedulable work packages
   -> remove reconstruction mistakes and bad task boundaries
   -> hard gate before real 2026 Session creation

#141  Task-specific Display ownership/material subdivision
   -> preserve the accepted Stage/Scene resolver
   -> each resolved Display has exactly one effective Setup-task owner
   -> Manager can move/drag Displays between real schedulable tasks
   -> Containers remain non-exclusive and may support several tasks

#167  Extra Materials / KITs / material sources
   -> normalized Extra Material catalog and task requirements
   -> existing ref.container KIT/support relationships
   -> expected sources/contents without requiring full 2027 KIT inventory

#122  SEPTEMBER 30 SCHEDULING LAUNCH GATE
   -> disposable proof first
   -> then create real 2026 Setup Session
   -> schedule 2026 work
   -> explain what Displays, Containers/KITs, Extra Materials, and constrained Resources need to be brought to the park and when
```

Before physical Setup work begins, the field-execution gate also requires the necessary portions of:

```text
#132       Production Crew governed work/progress/completion reporting
#113/#88   Scan + Location/movement execution needed by Setup
#171       GIS/layout + targeted underground-locate workflow
#175       offline/print Setup field packet + Work Order correction fallback
```

These are not all necessarily blockers to creating/scheduling the 2026 Session on September 30, but required field behavior must be accepted before crews depend on the system in the park.

### Preservation rule

Current accepted Production behavior wins over stale issue prose or earlier design discussion. Preserve:

- V0.3.7 dirty-edit/client-build protections;
- V0.3.8 compact task-detail behavior;
- V0.3.9 prerequisite behavior;
- V0.3.10 Resource Catalog behavior;
- V0.3.11 persistent active-task context;
- the working Stage/Scene Display resolver;
- 2025 historical/sandbox boundaries;
- current Display/Container authority; and
- no real 2026 Session until the accepted gates pass.

## Current Accepted Task-Detail Presentation

At laptop/desktop width the accepted task-detail layout remains:

```text
LEFT                               RIGHT
Reusable Task Definition            Annual Historical Actual
Material / Logistics                Captains / Knowledge Owners
```

The reusable definition uses a compact two-column desktop grid. Material / Logistics retains the accepted counts and detail dialog. Prerequisites and Equipment / Resources remain below the rail block.

V0.3.11 adds the accepted Issue #169 edit-safety control: when the review view has a selected task, the current Stage/task identity is mirrored into the already-sticky global Setup header under **ACTIVE TASK**. The identity remains visible while long detail is scrolled and updates immediately when another task is selected. Catalog/Movement views do not retain stale task context. The feature is presentation-only and does not own API writes, navigation, authorization, or dirty-edit behavior.

Cross-application palette/dark-mode consistency remains separate work in Issue #159.

## Current Accepted Prerequisite Model

Keep separate:

```text
HARD PREDECESSOR
PREFERRED ORDER
READINESS CONDITION
```

Accepted prerequisite behavior remains the V0.3.9 model:

```text
Shift held before left-button-down on dependent A
    -> drag A onto prerequisite B
    -> release
    -> create A depends on B
    -> neither task moves
```

Ordinary drag without Shift preserves normal reusable-task reorder and Stage/real-Scene movement. Task detail has one canonical prerequisite list with Up, Down, Remove, and Add prerequisite. Circular-dependency protection remains database-authoritative.

See [Setup Predecessor and Readiness Contract — 2026-09-09](Setup_Predecessor_and_Readiness_Contract_2026-09-09.md).

## Current Accepted Resource Catalog Model

V0.3.10 provides the governed reusable Resource Catalog and remains part of the V0.3.11 baseline.

The normal task-resource workflow is:

```text
search existing resource
    -> choose resource
    -> set quantity / Required-vs-Preferred / task notes
    -> add or update task relationship
```

The Resource Catalog owns reusable tools/equipment/vehicles/trailers such as the Locator, sledgehammers, post pounders, post pullers, ladders, Boom Lifts, SkyTrak, Tool Cat, trailers, trucks/vehicles, and similar reusable resources.

Do not duplicate an existing Resource as an Extra Material merely because it is mentioned in a procedure or physically stored in a KIT. A KIT may record an expected Resource such as a scaffold wrench while the Resource identity remains in the Resource Catalog.

## Current Accepted Material Model

Reusable task scope remains:

```text
Park Infrastructure / no LOR Stage
Stage-level / General
real Scene
```

Material applicability remains a separate reusable-task fact:

```text
[ ] Uses Display / Container Material
```

Accepted resolver behavior remains:

```text
material disabled
    -> no LOR-derived Display/Container material

material enabled + real Scene
    -> exact current Scene Display membership

material enabled + Stage
    -> current Stage-level LOR Display groups
    -> true child Scenes excluded

resolved Displays
    -> current ref.display.container_id
    -> deduplicated Containers
```

**Do not redesign or replace this resolver.**

Issue #141 owns the assignment layer after resolution for complex multi-step scopes: each resolved Display must have exactly one effective Setup-task owner, while Containers remain non-exclusive and may support several tasks.

Issue #167 owns Extra Materials, KIT assignments, expected contents, and material-source relationships. Do not collapse those facts into LOR Display membership.

The current detailed operating model is preserved in [Setup Task Supporting Information Contract — 2026-09-11](Setup_Task_Supporting_Information_Contract_2026-09-11.md). Future work must start there rather than reconstructing the decisions from chat or issue comments.

See [Setup Stage / Scene Material Resolution Contract — 2026-09-10](Setup_Stage_Scene_Material_Resolution_Contract_2026-09-10.md).

## Current Procedure-Reconciliation Evidence

The September 12 procedure workbook currently represents:

```text
36 legacy Setup PDFs
95 machine-normalized material candidates
507 raw material evidence rows
19 reconciliation issues after crew review
3 remaining stage gaps: 12, 21, 25
crew extraction complete for all 36 procedures
```

The `95` material candidates are not accepted catalog identities. Free-text extraction has produced duplicate/spelling/unit/specification fragmentation and has mixed Resources with Extra Materials. The raw evidence remains provenance; normalization/review produces reusable truth.

Task-split and duration review are not complete across all procedures. Do not convert `PENDING` evidence into accepted task definitions.

## Current Planning / Execution Direction

Setup is not intended to be a rigid season-long calendar scheduler.

Accepted operating direction:

```text
preferred order / hard predecessors
    + readiness
    + volunteers/equipment
    + weather/site conditions
    + prior progress
    -> candidate work
    -> operator chooses next practical work
    -> short-horizon schedule
    -> Pick List demand
    -> perform / record / replan
```

Every reusable/annual task creates human completion/reporting burden. The reusable Catalog should therefore track meaningful operational control points, not every instruction step.

There is currently no accepted Production Pick List generator/tablet workflow. That is part of the #122 September 30 launch gate after #145/#141/#167 establish trustworthy demand.

## Extra Materials / KIT / Source Direction

Issue #167 owns **what** non-LOR material is required and **where** it is expected to come from.

The Production catalog must normalize free-text procedure evidence rather than accept every extracted phrase as a material identity. Current accepted direction includes:

- 21-inch and 22-inch standard panel spacers are one normal spacer class;
- custom/fitted spacers remain distinct and may be expected in the applicable KIT;
- Ball Bungee spelling/name variants normalize to one family unless evidence proves real variants;
- D-Rings use verified 1/4-inch and 5/16-inch size families;
- Y-Post is a T-Post naming error;
- extension cords require gauge (AWG) plus length where known; color is not reliable identity;
- carabiners have two operational sizes and need verified specification;
- 3-way taps are one common type unless real variant evidence appears;
- unidentified `hardware` remains unresolved evidence until identified;
- zip ties are consumables; length and minimum quantity matter;
- marking paint is consumable, inverted/wand-compatible, with operational color meaning: red underground high voltage, blue underground network, white Display locations/layout datum points.

The model must distinguish:

```text
WHAT IS REQUIRED
vs.
WHERE IT IS EXPECTED TO COME FROM
vs.
WHAT IS PHYSICALLY PRESENT NOW
```

KITs remain existing `ref.container` identities. Reuse/harden `ref.setup_task_container_support` for reusable task -> KIT/support relationships unless Production evidence proves it insufficient.

A KIT may support several tasks and several scopes. Presence of the Container is more important than declaring one task to be its exclusive consumer.

Full heterogeneous item-by-item KIT inventory remains a 2027 goal. 2026 must support useful expected contents/sources without requiring that inventory to be complete.

## Staged Release — #141 Boundary

Issue #141 owns **when** Display/material demand becomes actionable for multi-step work.

The Pick List must not interpret Stage membership as `pick everything now`.

Desired flow:

```text
scheduled / selected work
    -> Display owner task + Extra Material requirements + KIT/support requirements
    -> release/pick timing
    -> current source / Container state
    -> logistics action
```

Magic Igloo remains the representative case: temperature-sensitive skins may deliberately remain warm until the frame is ready.

## GIS / Locate Readiness Gap

Issue #171 owns the 2026 integration of existing park GIS/GPS reference data for layout and targeted underground locate decisions.

The accepted rule is not `locate every Stage`:

> Locate/clear underground infrastructure only where planned ground penetration has a plausible chance of intersecting buried network/power infrastructure or where risk remains unresolved.

`No locate required` is a derived/reviewed readiness fact, not another annual task somebody must complete.

Site Infrastructure / GIS owns spatial reference/evidence; Setup owns whether work is ready to proceed.

## Data / Authorization Boundary

Cloudflare authentication, Setup capability, Person identity mapping, and PostgreSQL grants remain separate layers:

```text
Cloudflare Access authenticated email
  -> Setup backend capability lookup
  -> Directus / ref.person identity
  -> narrow PostgreSQL SECURITY DEFINER command
```

Do not grant broad Setup table DML to solve identity/capability problems.

Current role direction:

```text
Production Crew
    -> perform legitimate operational work
    -> report progress/completion
    -> validate physical state
    -> report concrete problems/corrections

Manager
    -> all operational capability as applicable
    -> maintain reusable definitions / catalogs / defaults / durable assignments

Administrator
    -> Manager capability plus limited system/annual-structure authority
```

There is no Captain/Supervisor Directus role. Setup CAPTAIN/ALTERNATE assignments are leadership/context, not authorization classes. Issue #132 owns correcting the current progress/completion authorization boundary and adding per-work-period duration reporting.

See [Setup Data Consumption and Authorization Contract](Setup_Data_Consumption_and_Authorization_Contract_2026-09-10.md).

## Field Correction / Work Order Boundary

Concrete wrong/missing conditions that need somebody to act later may go directly into the existing Work Order system from the current Setup context. Work Orders already provide a useful Manager-visible action list for real field discoveries, including data/LOR discrepancies as well as physical repair needs.

A connected Production Crew action should be low-friction, conceptually:

```text
Report Problem / Create Work Order
```

The application should pre-populate known task/session/Stage/Scene/Container/Display/material/resource/controller/procedure/requester/time context. Creating the Work Order must not itself mutate canonical data.

Issue #172 remains for broader observations/improvement ideas or cases where owner/action is genuinely unclear. Do not build a second competing correction queue for ordinary concrete corrections.

Issue #175 owns the offline/unregistered-worker fallback: a self-contained printable Setup PDF with embedded images, visible Generated/Expires timestamps, exact task/scope/source identity, and an obvious handwritten correction area. Returned paper can later be entered into the same Work Order correction path.

## Reusable Catalog / Annual Session Boundary

A valid reusable task can exist without a 2025 annual row. Annual Session creation seeds every active reusable task into the new Session.

Therefore, after accepted #169 task-context safety:

```text
#145 active reusable Catalog cleanup
    -> #141 Display-to-task ownership
    -> #167 Extra Materials / KIT / source foundation
    -> disposable 2026 creation/scheduling proof
    -> #122 real 2026 Session creation by September 30
```

Do not force new reusable tasks into 2025 merely to make the 2025 Plan appear complete.

## Current Repository / Issue Structure

Recent accepted Production work:

```text
#154  dirty-edit / Mark Verified safety              CLOSED / V0.3.7 accepted
#153  compact task-detail / Material layout          CLOSED / V0.3.8 accepted
#151  Shift+left-drag predecessor creation           CLOSED / V0.3.9 accepted
#152  reusable resource catalog management           CLOSED / V0.3.10 accepted
#169  persistent active-task identity / edit-safety  CLOSED / V0.3.11 accepted
#161  Archive -> SourceDocs Google Doc documentation CLOSED / completed
```

### Remaining pre-September-30 launch path

```text
#145  reusable Catalog cleanup
#141  one-Display-to-one-Setup-task ownership / staged subdivision
#167  Extra Materials / KIT / material-source foundation
#122  real 2026 Session + scheduling / Pick List launch gate
```

### Before physical Setup starts

```text
#132       Production Crew work reporting / duration / authorization
#113/#88   Scan + Location/movement execution
#171       GIS/layout + targeted locate
#175       offline/print field packet + Work Order correction fallback
```

### Important but not current launch-path blockers unless they expose a specific defect

```text
#172  broader field observation / continuous-improvement intake
#166  one-sudo browser-preview harness hardening
#159  shared light/dark palette
#140  shared semantic CSS token system
#174  project-wide chat-only knowledge recovery audit
```

## Start Here

- [Setup Session Production Engineering Handoff — 2026-09-11](Setup_Session_Production_Engineering_Handoff_2026-09-11.md) — broader runtime/data boundary; use the V0.3.11 acceptance record below for the current deployed SHA/version.
- [Setup Active Task Context V0.3.11 Production Acceptance — 2026-09-12](../../../../../Setup/Acceptance/Setup_Active_Task_Context_V0311_Production_Acceptance_2026-09-12.md) — current exact deployed source, source-only deployment evidence, fingerprint, live regression, and protected browser acceptance.
- [Setup Task Supporting Information Contract — 2026-09-11](Setup_Task_Supporting_Information_Contract_2026-09-11.md) — current launch sequence, task ownership, Extra Materials/KIT/source rules, Production Crew boundary, Work Order correction path, and field-start gates.
- [Setup V0.3.10 Resource Catalog Production Acceptance — 2026-09-11](../../../../../Setup/Acceptance/Setup_Resource_Catalog_V0310_Production_Acceptance_2026-09-11.md) — accepted resource-catalog deployment and rollback evidence.
- [Setup V0.3.9 Prerequisite Production Acceptance — 2026-09-11](../../../../../Setup/Acceptance/Setup_Predecessor_V039_Production_Acceptance_2026-09-11.md).
- [Setup V0.3.8 Task Detail Production Acceptance — 2026-09-11](../../../../../Setup/Acceptance/Setup_Task_Detail_Production_Acceptance_2026-09-11.md).
- [Setup Stage / Scene Material Resolution Contract — 2026-09-10](Setup_Stage_Scene_Material_Resolution_Contract_2026-09-10.md).
- [Setup Data Consumption and Authorization Contract — 2026-09-10](Setup_Data_Consumption_and_Authorization_Contract_2026-09-10.md).
- [Setup Predecessor and Readiness Contract — 2026-09-09](Setup_Predecessor_and_Readiness_Contract_2026-09-09.md).
- [Setup Planning Operating Model — 2026-09-08](Setup_Planning_Operating_Model_2026-09-08.md).
- [Setup Pick List Tablet Workflow — 2026-09-09](Setup_Pick_List_Tablet_Workflow_2026-09-09.md) — direction only; not yet Production-operational.

## Authoritative Implementation Sources

Application source:

```text
Setup/Application/
```

Database migration source:

```text
Setup/Database/
```

Production acceptance/install material:

```text
Setup/Acceptance/
```

The Production Database repository owns Setup application/business/database behavior.

`Gregovate/MSB-Server-Management` owns deployed service, listener, firewall, reverse-proxy, restart/recovery, host permissions, browser-review runbook, and Production deployment runbooks/runtime facts.

## Resume Checklist

Before the next Setup change:

1. read the Production Database Project Rules;
2. refresh current remote `main` and record exact head;
3. read the current Production engineering handoff and this engineering portal;
4. read the [Setup Task Supporting Information Contract](Setup_Task_Supporting_Information_Contract_2026-09-11.md);
5. preserve accepted V0.3.7 through V0.3.11 behavior;
6. use 2025 as the sandbox/historical proving ground until the remaining pre-launch gates pass;
7. work the remaining pre-launch sequence #145 -> #141 -> #167 -> #122 rather than creating the real 2026 Session early;
8. use issue #113 / Labeling and Scanning for shared scan capture/resolution behavior;
9. use `Gregovate/MSB-Server-Management` for current runtime/deployment/browser-review authority; and
10. update controlled docs, acceptance evidence, and this README whenever accepted behavior or the resume point changes.

## Related Systems

- [Setup and Deployment operator portal](../README.md)
- [Operator procedures](../operatorSOP/README.md)
- [Detailed Manager Review Guide](../../../02_Operational_SOPs/Setup/Setup_Session_Manager_Review_Guide.md)
- [People and Identity](../../03_People_and_Identity/README.md)
- [Labeling and Scanning](../../07_Labeling_and_Scanning/README.md)
- [Site Infrastructure / GIS](../../11_Site_Infrastructure_GIS/README.md)
- [Wiring System](../../09_Wiring_System/README.md)
