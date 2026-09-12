# Setup and Deployment Engineering

| Document Control | Value |
|---|---|
| Document Type | Engineering Handoff Portal |
| System | Production Database — Setup and Deployment |
| Audience | Greg, maintainers, database administrators, future engineering sessions |
| Status | CURRENT HANDOFF — V0.3.10 accepted in Production; broader Setup work remains active |
| Owner | MSB Production Database engineering |
| Last Reviewed | 2026-09-11 |

This is the engineering starting point for Setup Session architecture, database behavior, application contracts, Production state, reconstruction rules, planning behavior, Pick List direction, and resume information.

The operator-facing instructions are separate under [`../operatorSOP/`](../operatorSOP/README.md).

## Current Production State

Protected application:

```text
https://my.sheboyganlights.org/setup/
```

Current exact accepted/deployed application target:

```text
c2a1820627f1a036d634241cc6aecd1a926a1479
```

Current Setup health:

```text
V0.3.10-resource-catalog
```

Implementation lineage:

```text
Issue #152
PR #168
main merge commit = cc4b5767605373504fd993698ce735514bec0d37
```

Current annual context:

```text
2025 Setup Session  = HISTORICAL_VERIFICATION
2026 Setup Sessions = 0
```

The current PostgreSQL reusable Catalog is the working task baseline. Do not use older fixed task counts as current authority; live Catalog cleanup and task development continue.

V0.3.10 Production acceptance on 2026-09-11 proved:

```text
migration 027                               = PASS
stable Production fingerprint               = 7c21041caecac6eb77660238ba3c8cf9
resource rows at deployment                 = 12
task-resource relationships at deployment  = 32
normalized duplicate resource groups        = 0
corrected test-only derivative              = 209 passed
live focused regression                     = 29 passed / 1 known stale assertion deselected
protected negative path                     = HTTP 401 PASS
protected health                            = V0.3.10-resource-catalog
protected Production browser acceptance     = PASS
legitimate catalog correction               = PASS
existing task-resource relationship intact  = PASS
```

Migration 027 added governed reusable resource-catalog management without granting broad resource/task-resource DML to `fieldwiring_app`.

Validated rollback archive:

```text
/home/msbadmin/backups/setup-152/msb-pre-setup-152-20260911T170411.dump
SHA256 = b60857bf12eae68922cc309b795e920b3b2aaccd5a928b775527057450a7aa15
```

See the current [Setup Session Production Engineering Handoff — 2026-09-11](Setup_Session_Production_Engineering_Handoff_2026-09-11.md) and [V0.3.10 Resource Catalog Production Acceptance](../../../../../Setup/Acceptance/Setup_Resource_Catalog_V0310_Production_Acceptance_2026-09-11.md).

## Current Accepted Task-Detail Presentation

At laptop/desktop width the accepted task-detail layout remains:

```text
LEFT                               RIGHT
Reusable Task Definition            Annual Historical Actual
Material / Logistics                Captains / Knowledge Owners
```

The reusable definition itself uses a compact two-column desktop grid. Material / Logistics retains all four essential counts and the existing full detail dialog. Prerequisites and Equipment / Resources remain below the rail block.

Cross-application palette/dark-mode consistency remains separate work in Issue #159. Keeping the active task name visible while scrolling long task detail is tracked separately in Issue #169.

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

Ordinary drag without Shift preserves normal reusable-task reorder and Stage/real-Scene movement. Task detail has one canonical prerequisite list with **Up**, **Down**, and **Remove**, plus manual **Add prerequisite**. Up/Down is presentation order only.

Circular-dependency protection remains database-authoritative. Structured outside/site readiness remains separate from hard task prerequisites.

See [Setup Predecessor and Readiness Contract — 2026-09-09](Setup_Predecessor_and_Readiness_Contract_2026-09-09.md).

## Current Accepted Resource Catalog Model

The normal task-resource workflow is intentionally compact and name-oriented:

```text
search existing resource
    -> choose resource
    -> set quantity / Required-vs-Preferred / task notes
    -> add or update task relationship
```

The normal picker sorts primarily by meaningful `resource_name`, then type/ID. This is the accepted refinement from the original #152 wording. `display_order` remains a governed optional catalog field but is not required for ordinary picker usability.

**Manage Resource Catalog** is the reusable catalog-maintenance surface. It supports:

- search across active and inactive entries;
- in-place rename/correction while preserving `setup_resource_id`;
- type, catalog notes, active state, and optional display-order editing;
- default Name sort plus alternate review sorts;
- normalized exact duplicate blocking; and
- likely-match suggestions before new-resource creation.

Task-specific quantity, Required-vs-Preferred, and task notes remain separate from catalog identity/type/notes/order.

Inactive resources remain discoverable for review. New inactive assignments are blocked, while existing inactive relationships remain visible/removable.

## Current Accepted Material Model

Reusable task scope remains:

```text
Park Infrastructure / no LOR Stage
Stage-level / General
real Scene
```

Material applicability is a separate reusable-task fact:

```text
[ ] Uses Display / Container Material
```

Accepted behavior:

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

The accepted resolver provides Stage/Scene material context, not task-specific staged release timing. Issue #141 remains responsible for task-specific material subdivision/Pick List timing.

Issue #167 separately owns Extra Materials, KIT assignments, and material-source tracking. Do not collapse those facts into LOR Display membership or assume every Extra Material lives in a KIT.

The operator-confirmed working model for those relationships, default/verified authority, KIT lifecycle, staged release, Production Crew execution boundary, targeted locates, and field exceptions is now preserved in the [Setup Task Supporting Information Contract — 2026-09-11](Setup_Task_Supporting_Information_Contract_2026-09-11.md). Future work must start there rather than reconstructing those decisions from chat or issue comments.

See [Setup Stage / Scene Material Resolution Contract — 2026-09-10](Setup_Stage_Scene_Material_Resolution_Contract_2026-09-10.md).

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

Every reusable/annual task creates human completion/reporting burden. The reusable Catalog should therefore track meaningful operational control points, not every instruction step. Detailed procedure steps remain in the procedure unless independent planning/completion has operational value.

**Plan / Schedule** and **Perform Work** support Stage-oriented presentation, but Plan / Schedule has not yet had the same cleanup/review pass as the reusable Catalog.

There is currently no accepted Production Pick List generator/tablet workflow.

## GIS / Locate Readiness Gap

The current external park GIS/GPS source set contains useful placement tracks plus power/network spatial information, but that information is not yet integrated into the new Setup system.

The accepted field rule is **not** `locate every Stage`. Locate/clearance is required only where planned ground penetration has a plausible chance of intersecting buried infrastructure or where the risk remains unresolved.

Issue #171 owns the independently actionable 2026 work to integrate enough of that spatial knowledge to support layout and targeted locate/readiness decisions. Site Infrastructure / GIS owns spatial reference/evidence; Setup owns whether planned work is ready to proceed.

`No locate required` is a derived/reviewed readiness fact, not another annual task that someone must manually complete.

## Continuous-Improvement / Field-Observation Gap

The new Production data is intended to be trusted during field work rather than re-verified through redundant Setup tasks. When reality disagrees with the system, Production Crew need a durable way to report the exception immediately.

Issue #172 owns the missing cross-system **field observation -> triage -> actionable item** bridge. It must support Setup, Testing, Work Orders, inventory/KIT validation, GIS, scanning/movement, and other trusted Production Crew workflows without turning every observation into a Work Order or requiring the reporter to know which subsystem owns the final correction.

The target seasonal loop is:

```text
perform real work
    -> validate authoritative state through use
    -> report exceptions / improvement opportunities
    -> triage to the responsible system/owner
    -> correct data/process/system
    -> preserve verified result
    -> next season starts smarter
```

## Current Editable Procedure Source Rule

Authorized Manager editable-source resolution remains:

```text
Procedures\Setup\SourceDocs first
-> Procedures\Setup\Archive only if no editable SourceDocs .gdoc exists
```

During migration of legacy Google Docs, the archived document remains historical evidence. Use Google Docs **File -> Make a copy** to create the current editable copy in `SourceDocs`; do not copy the Windows `.gdoc` shortcut file.

The approved field PDF remains directly in `Procedures\Setup`.

## Data / Authorization Boundary

Cloudflare authentication, Setup capability, Person identity mapping, and PostgreSQL grants are separate layers:

```text
Cloudflare Access authenticated email
  -> Setup backend capability lookup
  -> Directus / ref.person identity
  -> narrow PostgreSQL SECURITY DEFINER command
```

Do not grant broad Setup table DML to solve identity/capability problems.

Migration 027 preserves this boundary with narrow EXECUTE on governed resource commands and no broad `ref.setup_resource` UPDATE/DELETE or broad `ref.setup_task_resource` UPDATE.

Current operator direction also distinguishes **execution authority** from **business-definition authority**:

```text
Production Crew
    -> perform work
    -> report progress/completion
    -> validate physical state
    -> report issues/exceptions

Manager
    -> all operational capability as applicable
    -> maintain reusable definitions / catalogs / defaults / durable assignments

Administrator
    -> Manager capability plus limited system/annual-structure authority
```

There is currently no Captain/Supervisor Directus role. Setup `CAPTAIN` / `ALTERNATE` relationships are task-leadership assignments, not authorization classes. Do not invent a new Directus role merely to preserve the current Manager-or-Captain progress restriction. The current progress/completion authorization boundary requires correction under #132 / #172.

See [Setup Data Consumption and Authorization Contract](Setup_Data_Consumption_and_Authorization_Contract_2026-09-10.md).

## Reusable Catalog / Annual Session Boundary

A valid reusable task can exist without a 2025 annual row. Annual Session creation seeds **every active reusable task** into the new Session.

Therefore:

```text
active reusable Catalog cleanup
    -> prove intended task set
    -> disposable 2026 creation check
    -> only then authorize real 2026 Session creation
```

Issue #145 owns this gate. Do not create the real 2026 Setup Session before #145 acceptance.

## Current Repository / Issue Structure

Recent completed acceptance:

```text
#154  dirty-edit / Mark Verified safety              CLOSED / V0.3.7 accepted
#153  compact task-detail / Material layout          CLOSED / V0.3.8 accepted
#151  Shift+left-drag predecessor creation           CLOSED / V0.3.9 accepted
#152  reusable resource catalog management           V0.3.10 accepted / close after docs merge
#161  Archive -> SourceDocs Google Doc documentation CLOSED / completed
```

Primary remaining work includes:

```text
#122  Setup Session planning / Pick List / live reconstruction umbrella
#145  reusable Catalog cleanup gate before real 2026 Session creation
#167  Extra Materials / KIT assignments / material-source tracking
#141  task-specific staged material subdivision / Pick List release timing
#171  park GIS/layout + targeted underground-locate integration
#172  Production Crew field-observation / continuous-improvement intake + triage
#169  keep active task name visible while reviewing long task detail
#166  one-sudo browser-preview harness hardening
#159  shared light/dark palette and dark-mode white-logo consistency
#132  work-report duration / multi-day effort + execution authorization correction
#113  shared Scan application readiness / identity capture integration
```

Issue #130 global People/Capability/Qualification foundation is completed; subsystem-specific consumption remains separate integration work.

## Start Here

- [Setup Session Production Engineering Handoff — 2026-09-11](Setup_Session_Production_Engineering_Handoff_2026-09-11.md) — current deployed SHA/version, migration 027, runtime evidence, boundaries, and resume point.
- [Setup Task Supporting Information Contract — 2026-09-11](Setup_Task_Supporting_Information_Contract_2026-09-11.md) — operator-confirmed task/support-package model, Extra Materials/KIT/source relationships, staged-release boundary, task granularity, Production Crew execution boundary, targeted locate rule, and continuous-improvement handoff.
- [Setup V0.3.10 Resource Catalog Production Acceptance — 2026-09-11](../../../../../Setup/Acceptance/Setup_Resource_Catalog_V0310_Production_Acceptance_2026-09-11.md) — exact migration/source deployment, rollback archive, regression, fingerprint, authorization, and browser acceptance evidence.
- [Setup V0.3.9 Prerequisite Production Acceptance — 2026-09-11](../../../../../Setup/Acceptance/Setup_Predecessor_V039_Production_Acceptance_2026-09-11.md) — predecessor workflow acceptance history.
- [Setup V0.3.8 Task Detail Production Acceptance — 2026-09-11](../../../../../Setup/Acceptance/Setup_Task_Detail_Production_Acceptance_2026-09-11.md) — compact task-detail acceptance history.
- [Setup Stage / Scene Material Resolution Contract — 2026-09-10](Setup_Stage_Scene_Material_Resolution_Contract_2026-09-10.md) — accepted material/source-classification authority.
- [Setup Data Consumption and Authorization Contract — 2026-09-10](Setup_Data_Consumption_and_Authorization_Contract_2026-09-10.md) — capability, Person mapping, application-role, governed write, and grant boundaries.
- [Setup Predecessor and Readiness Contract — 2026-09-09](Setup_Predecessor_and_Readiness_Contract_2026-09-09.md) — predecessor interaction/order and hard predecessor vs preferred order vs external/site readiness.
- [Setup Planning Operating Model — 2026-09-08](Setup_Planning_Operating_Model_2026-09-08.md) — rolling-horizon planning direction.
- [Setup Pick List Tablet Workflow — 2026-09-09](Setup_Pick_List_Tablet_Workflow_2026-09-09.md) — Pick List direction; not yet Production-operational.
- [Setup Session Production Engineering Handoff — 2026-09-07](Setup_Session_Production_Engineering_Handoff_2026-09-07.md) — historical V0.3.4 foundation/runtime baseline; not current deployment authority.

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
2. read the current [2026-09-11 Production engineering handoff](Setup_Session_Production_Engineering_Handoff_2026-09-11.md);
3. read this engineering portal and the [Setup Task Supporting Information Contract](Setup_Task_Supporting_Information_Contract_2026-09-11.md);
4. preserve V0.3.7 dirty-edit/client-build protections, V0.3.8 compact layout, V0.3.9 prerequisite behavior, and V0.3.10 resource-catalog behavior;
5. review Issue #141 before designing task-specific staged material/Pick List release timing;
6. review Issue #167 before designing Extra Materials/KIT/source relationships;
7. review Issue #171 before designing Setup layout/ground-penetration locate behavior;
8. review Issue #172 before inventing any subsystem-specific field correction/improvement queue;
9. review Issue #145 before creating or simulating real 2026 annual state;
10. preserve annual 2025 facts separately from reusable future knowledge;
11. use issue #113 / Labeling and Scanning for shared scan capture/resolution behavior;
12. use `Gregovate/MSB-Server-Management` for current runtime/deployment/browser-review authority; and
13. update controlled docs, acceptance evidence, and this README whenever accepted behavior or the resume point changes.

## Related Systems

- [Setup and Deployment operator portal](../README.md)
- [Operator procedures](../operatorSOP/README.md)
- [Detailed Manager Review Guide](../../../02_Operational_SOPs/Setup/Setup_Session_Manager_Review_Guide.md)
- [People and Identity](../../03_People_and_Identity/README.md)
- [Labeling and Scanning](../../07_Labeling_and_Scanning/README.md)
- [Site Infrastructure / GIS](../../11_Site_Infrastructure_GIS/README.md)
- [Wiring System](../../09_Wiring_System/README.md)
