# Setup and Deployment Engineering

| Document Control | Value |
|---|---|
| Document Type | Engineering Handoff Portal |
| System | Production Database — Setup and Deployment |
| Audience | Greg, maintainers, database administrators, future engineering sessions |
| Status | CURRENT HANDOFF — V0.3.9 accepted in Production; broader Setup work remains active |
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
55478f98f760473b65b5d700a84c868285022ab7
```

Implementation repository lineage:

```text
Issue #151
PR #164
main merge commit = ebade21e15a9ac62728dca0655476a619b47516d
```

Current Setup health:

```text
V0.3.9-predecessor-drag
```

Current annual context:

```text
2025 Setup Session  = HISTORICAL_VERIFICATION
2026 Setup Sessions = 0
```

The current PostgreSQL reusable Catalog is the working task baseline. Do not use older fixed counts such as 57 or the earlier 185-task reconstruction snapshot as current authority; live Catalog cleanup and task development continued after those dated baselines.

V0.3.9 Production acceptance on 2026-09-11 proved:

```text
focused exact-candidate regression            = 63 passed
live deployed focused regression              = 63 passed
Production fingerprint before migration       = 9510360aa7de2da59d1ed8a9ad9d69f7
Production fingerprint after migration/deploy = 9510360aa7de2da59d1ed8a9ad9d69f7
existing dependency rows                      = 17
legacy dependency audit fingerprint before    = 26b170fba3500ea2647967e87aa02a1c
legacy dependency audit fingerprint after     = 26b170fba3500ea2647967e87aa02a1c
protected health                              = V0.3.9-predecessor-drag
protected Production browser acceptance       = PASS
```

Migration 026 added persistent prerequisite review/display order without rewriting existing dependency audit evidence and without granting broad dependency-table DML to `fieldwiring_app`.

The immediately prior accepted runtime was:

```text
2eee967b6c5359c0e2e2d876a2fe44af8359315c
V0.3.8-task-detail-compact
```

V0.3.9 preserves the accepted V0.3.7 dirty-edit/client-build safety and V0.3.8 compact task-detail layout while adding the accepted prerequisite interaction and canonical editor.

See the current [Setup Session Production Engineering Handoff — 2026-09-11](Setup_Session_Production_Engineering_Handoff_2026-09-11.md) and [V0.3.9 Prerequisite Production Acceptance](../../../../../Setup/Acceptance/Setup_Predecessor_V039_Production_Acceptance_2026-09-11.md).

## Current Accepted Task-Detail Presentation

At laptop/desktop width the accepted task-detail layout remains:

```text
LEFT                               RIGHT
Reusable Task Definition            Annual Historical Actual
Material / Logistics                Captains / Knowledge Owners
```

The reusable definition itself uses a compact two-column desktop grid. Material / Logistics retains all four essential counts and the existing full detail dialog. Prerequisites and Equipment / Resources remain below the rail block and are reachable with materially less scrolling.

Physical mobile-device acceptance was not performed for V0.3.8; responsive stacking is contract-covered and was checked using a narrowed desktop browser proxy only.

Cross-application palette and dark-mode white-logo consistency remain separate work in Issue #159.

## Current Accepted Prerequisite Model

Keep separate:

```text
HARD PREDECESSOR
PREFERRED ORDER
READINESS CONDITION
```

A hard predecessor is another reusable Setup task that must complete first. A preferred order is only the normal sequence. A readiness condition is an outside/site condition and must not be fabricated as a Setup task merely to create a blocker.

Accepted V0.3.9 prerequisite behavior:

```text
Shift held before left-button-down on dependent A
    -> drag A onto prerequisite B
    -> release
    -> create A depends on B
    -> neither task moves
```

Ordinary drag without Shift preserves the existing reusable-task reorder and Stage/real-Scene movement behavior. Releasing a Shift-drag over empty Stage/Scene space cancels the prerequisite gesture without moving the task.

Task detail has one canonical prerequisite list with **Up**, **Down**, and **Remove**, plus a separate manual **Add prerequisite** form. Assigned prerequisites disappear from the Add choices. Add/remove/reorder refresh authoritative dependency state so task detail and the Catalog `Requires` line stay synchronized.

Migration 026 adds `ref.setup_task_dependency.sort_order` and `ref.reorder_setup_task_dependencies(text,bigint,bigint[])`.

Prerequisite Up/Down order is presentation/review order only. It does not create dependency relationships between the prerequisite tasks. Circular-dependency protection remains authoritative in the governed database command.

Structured readiness remains pending and is still separate from task prerequisites.

See [Setup Predecessor and Readiness Contract — 2026-09-09](Setup_Predecessor_and_Readiness_Contract_2026-09-09.md).

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
    -> exact current ref.lor_scene_display membership

material enabled + Stage
    -> current LOR groups classified as Stage-level
    -> true child Scenes excluded

resolved Displays
    -> current ref.display.container_id
    -> deduplicated Containers
```

There is no operator-facing LOR Preview/programming-group/material-source selector. Programming-only LOR groups remain valid LOR objects but do not automatically become Setup Scenes.

The UI color marker is presentation only. `requires_display_material` is authoritative.

### Important boundary — not yet task-specific staged material

The accepted resolver is intentionally a **Stage/real-Scene material-context resolver**, not a complete task-specific pick/release model.

When one Stage has several separate physical Setup tasks, multiple material-enabled Stage-level tasks can resolve the same Stage-level Displays/Containers even if only part of that material should leave storage for the current step.

Magic Igloo is the representative case:

```text
frame work
    -> may need frame material first

skin installation
    -> skins/bungees may need to remain warm in the workshop until later

lighting/camera/finish work
    -> later material may not be needed at the first step
```

The current checkbox answers whether the task uses Stage/Scene Display material and exposes that current context. It does not subdivide the Stage material by physical task step or release time.

Do not claim that resolved material means `pick this now`. Task-specific material subdivision, component/KIT representation, and staged Pick List timing remain open engineering work in Issue #141.

See [Setup Stage / Scene Material Resolution Contract — 2026-09-10](Setup_Stage_Scene_Material_Resolution_Contract_2026-09-10.md).

## Current Accepted Planning / Execution Presentation

**Plan / Schedule** and **Perform Work** support Stage-oriented presentation:

```text
Stage
    Stage-level / General
    Scene — <real Scene>
```

Stage view is presentation only; it does not rewrite annual planned order.

Switching to **Planned order** returns to the existing annual planning sequence/reorder behavior.

The shared **Find task or Stage** search applies to:

- Reusable Task Catalog;
- Plan / Schedule; and
- Perform Work.

## Current Editable Procedure Source Rule

Authorized Manager editable-source resolution is:

```text
Procedures\Setup\SourceDocs first
-> Procedures\Setup\Archive only if no editable SourceDocs .gdoc exists
```

During the 2026 migration, the archived Google Doc remains the historical original. Open it in Google Docs, use **File -> Make a copy**, save the new Google-native working copy into `SourceDocs`, and edit only the SourceDocs copy going forward. Do not treat copying the Windows `.gdoc` shortcut file as document migration.

The approved field PDF remains directly in `Procedures\Setup`.

This workflow is controlled in the Google Drive operator SOPs and was closed through Issue #161 / PR #162.

## Start Here

- [Setup Session Production Engineering Handoff — 2026-09-11](Setup_Session_Production_Engineering_Handoff_2026-09-11.md) — current deployed SHA/version, recent runtime lineage, fingerprint evidence, migration 026, current boundaries, and resume point.
- [Setup V0.3.9 Prerequisite Production Acceptance — 2026-09-11](../../../../../Setup/Acceptance/Setup_Predecessor_V039_Production_Acceptance_2026-09-11.md) — exact migration, source deployment, rollback archive, regression, fingerprint, browser, and preview-lifecycle evidence.
- [Setup V0.3.8 Task Detail Production Acceptance — 2026-09-11](../../../../../Setup/Acceptance/Setup_Task_Detail_Production_Acceptance_2026-09-11.md) — prior compact task-detail acceptance.
- [Setup Stage / Scene Material Resolution Contract — 2026-09-10](Setup_Stage_Scene_Material_Resolution_Contract_2026-09-10.md) — current accepted material/source-classification authority.
- [Setup Stage / Scene Production Acceptance — 2026-09-11](../../../../../Setup/Acceptance/Setup_Stage_Scene_Production_Acceptance_2026-09-11.md) — V0.3.5 material/presentation database migration and acceptance history.
- [Setup Data Consumption and Authorization Contract — 2026-09-10](Setup_Data_Consumption_and_Authorization_Contract_2026-09-10.md) — Setup capability, Person mapping, application-role, governed write, and grant boundaries.
- [Setup Predecessor and Readiness Contract — 2026-09-09](Setup_Predecessor_and_Readiness_Contract_2026-09-09.md) — accepted predecessor interaction/order plus hard predecessor vs preferred order vs external/site readiness.
- [Setup Reconstruction Migration and Acceptance History — 2026-09-07 to 09](Setup_Reconstruction_Migration_and_Acceptance_History_2026-09-07_to_09.md) — historical migration/disposable/browser lessons and reconstruction findings.
- [Setup Planning Operating Model — 2026-09-08](Setup_Planning_Operating_Model_2026-09-08.md) — rolling-horizon planning direction.
- [Setup Planning Candidate Work View — 2026-09-09](Setup_Planning_Candidate_Work_View_2026-09-09.md) — cross-Stage candidate planning direction.
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

## Current Repository / Issue Structure

Recent completed acceptance:

```text
#154  dirty-edit / Mark Verified safety              CLOSED / V0.3.7 accepted
#153  compact task-detail / Material layout          CLOSED / V0.3.8 accepted
#151  Shift+left-drag predecessor creation           V0.3.9 accepted; closeout docs in progress
#161  Archive -> SourceDocs Google Doc documentation CLOSED / completed
```

Primary active work remains issue-driven:

```text
#122  Setup Session engineering / planning / Pick List / live reconstruction umbrella
#145  reusable Catalog cleanup gate before creating the 2026 Setup Session
#152  resource catalog sort order / existing-resource editing
#159  shared light/dark palette and dark-mode white-logo consistency
#141  task-specific staged material subdivision and Pick List release timing
#130  global People / Capability / Qualification work consumed by Setup
#132  Captain work-report duration / multi-day effort capture
#113  shared Scan application readiness / identity capture integration
```

Earlier Setup PRs #123/#124/#125/#134/#136/#137/#138/#139 are historical/superseded lineages and are not the current development authority.

## Reusable Catalog / Annual Session Boundary

The reusable Catalog and the selected annual Session are different things.

A valid reusable task can exist without a 2025 `ops.setup_session_task` row. That task will not appear in the 2025 Plan / Schedule view merely because it exists in the reusable Catalog.

Annual Session creation seeds **every active reusable task** into the new annual Session.

Therefore:

```text
active reusable Catalog cleanup
    -> prove intended task set
    -> disposable 2026 creation check
    -> only then authorize real 2026 Session creation
```

Do not force newer reusable tasks into 2025 merely to make the historical Plan look complete.

Issue #145 owns this gate.

## Reconstruction Source Rules

Historical spreadsheets, 2025 notes, and recovered schedules are evidence, not a parallel ongoing task master.

Use current PostgreSQL first:

```text
current reusable Catalog
    -> identify gap/correction
    -> verify practical task boundary and scope
    -> correct through governed Setup controls
```

Do not restart a bulk spreadsheet import merely because a task is missing or wrong.

Reconstruction mistakes may legitimately have no annual row. The governed reconstruction-safe delete path supports Catalog-only mistakes while failing closed when protected history exists.

## Current Planning Model

Setup is **not** a rigid season-long calendar scheduler.

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

Tasks can span multiple work periods. Stage organization is useful for presentation but is not a requirement to finish an entire Stage before another Stage can begin.

## Predecessor / Readiness Boundary

Keep separate:

```text
HARD PREDECESSOR
PREFERRED ORDER
READINESS CONDITION
```

A readiness condition can be an external/site condition such as mowing/mulching complete in a specific work area. Do not invent fake Setup tasks for outside work.

Structured readiness remains pending; the current free-text readiness note is descriptive only. Efficient task-predecessor entry is now Production-operational in V0.3.9.

## Pick List Current Boundary

There is currently **no Production Pick List generator/report** and no accepted Setup tablet Pick List workflow.

The intended direction remains:

```text
selected Setup work
    -> required material at the correct task/release step
    -> resolved Displays / other governed material units
    -> current Containers/storage
    -> deduplicate
    -> explain why each item/Container is required
```

The existing Stage/Scene material resolver provides useful context but does not yet provide the task-specific release step in the first arrow above. Issue #141 owns that unresolved material-subdivision/timing problem.

Do not infer task scope from Container storage. Shared/mixed-stage Containers are normal.

## Data / Authorization Boundary

Cloudflare authentication, Setup capability, Person identity mapping, and PostgreSQL grants are separate layers.

Characteristic write failure:

```text
Authenticated Setup operator is not mapped to an MSB person
```

is a Person/Directus identity-link problem, not justification for broad Setup table DML.

Migration 025 added only the `ref.display_status` SELECT needed by automatic material resolution plus governed material setter EXECUTE. Migration 026 adds only prerequisite presentation order plus narrow governed reorder EXECUTE. Broad direct Setup table DML remains forbidden for `fieldwiring_app`.

See [Setup Data Consumption and Authorization Contract](Setup_Data_Consumption_and_Authorization_Contract_2026-09-10.md).

## Known Limitations / Open Work

Current significant remaining work includes:

- reusable Catalog cleanup before 2026 propagation;
- continued correction of task boundaries exposed by live review;
- task-specific staged material subdivision / release timing for multi-step Stage work (Issue #141);
- structured readiness;
- resource catalog sort/existing-resource editing (Issue #152);
- cross-Stage candidate planning surface / short-horizon scheduler workflow;
- authoritative Controller context from FieldWiring / Controller Inventory;
- Pick List generation and tablet workflow;
- mixed-stage Container annual mobilization/unload-group state and ordered-access rules;
- Container/Display movement/scanning writes;
- park-location execution evidence; and
- cross-app palette/dark-mode logo normalization (Issue #159).

## Resume Development

Before changing this subsystem:

1. read the Production Database Project Rules;
2. read the current [2026-09-11 Production engineering handoff](Setup_Session_Production_Engineering_Handoff_2026-09-11.md);
3. read this engineering portal;
4. read the Stage/Scene material-resolution contract before changing material or Scene classification;
5. review Issue #141 before designing task-specific material groups, components/KITs, or Pick List release timing;
6. review Issue #145 before creating or simulating real 2026 annual state;
7. preserve annual 2025 facts separately from reusable future knowledge;
8. preserve the V0.3.7 dirty-edit/client-build protections, V0.3.8 compact layout, and V0.3.9 visible client/prerequisite behavior;
9. use the predecessor/readiness contract before changing dependency or readiness semantics;
10. use the Pick List contract before implementing logistics/pick behavior;
11. use issue #130 / People and Identity for global capability/qualification work;
12. use issue #113 / Labeling and Scanning for shared scan capture/resolution behavior;
13. use `Gregovate/MSB-Server-Management` for current runtime/deployment/browser-review authority; and
14. update controlled docs, acceptance evidence, and this README handoff whenever accepted behavior or the next resume point changes.

## Related Systems

- [Setup and Deployment operator portal](../README.md)
- [Operator procedures](../operatorSOP/README.md)
- [Detailed Manager Review Guide](../../../02_Operational_SOPs/Setup/Setup_Session_Manager_Review_Guide.md)
- [People and Identity](../../03_People_and_Identity/README.md)
- [Labeling and Scanning](../../07_Labeling_and_Scanning/README.md)
- [Wiring System](../../09_Wiring_System/README.md)
