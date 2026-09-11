# Setup and Deployment Engineering

| Document Control | Value |
|---|---|
| Document Type | Engineering Handoff Portal |
| System | Production Database — Setup and Deployment |
| Audience | Greg, maintainers, database administrators, future engineering sessions |
| Status | CURRENT HANDOFF — Stage/Scene material and presentation accepted in Production; broader Setup work remains active |
| Owner | MSB Production Database engineering |
| Last Reviewed | 2026-09-11 |

This is the engineering starting point for Setup Session architecture, database behavior, application contracts, Production state, reconstruction rules, planning behavior, Pick List direction, and resume information.

The operator-facing instructions are separate under [`../operatorSOP/`](../operatorSOP/README.md).

## Current Production State

Protected application:

```text
https://my.sheboyganlights.org/setup/
```

Current accepted application/database target:

```text
9791a6b5a9739c1107746ecbe3cf3ebb558f38bd
```

Repository normalization merge:

```text
PR #144
main merge commit = 96613aae4e5084dab2f735bc3dbcc8e13433109e
```

Current Setup health:

```text
V0.3.5-stage-scene-material-review
```

Current annual context:

```text
2025 Setup Session  = HISTORICAL_VERIFICATION
2026 Setup Sessions = 0
```

The current PostgreSQL reusable Catalog is the working task baseline. Do not use older fixed counts such as 57 or the earlier 185-task reconstruction snapshot as current authority; live Catalog cleanup and task development continued after those dated baselines.

Production acceptance on 2026-09-11 proved:

```text
exact candidate Setup/Application regression = 154 passed
migration 025                                = applied / least-privilege PASS
protected direct no-identity path            = HTTP 401 PASS
Production business fingerprint              = 798e59ae47a5e313d45cd23e9fdc3c4a
business fingerprint changed by deployment   = NO
```

Rollback archive:

```text
/home/msbadmin/backups/setup-stage-scene-material/msb_pre_setup_stage_scene_material_20260911T000157.dump
```

Deployment report:

```text
/home/msbadmin/setup-acceptance-reports/Setup_Stage_Scene_Production_Deployment_20260911T000157.txt
```

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

See [Setup Stage / Scene Material Resolution Contract — 2026-09-10](Setup_Stage_Scene_Material_Resolution_Contract_2026-09-10.md).

## Current Accepted Planning / Execution Presentation

**Plan / Schedule** and **Perform Work** now support Stage-oriented presentation:

```text
Stage
    Stage-level / General
    Scene — <real Scene>
```

Stage view is presentation only; it does not rewrite annual planned order.

Switching to **Planned order** returns to the existing annual planning sequence/reorder behavior.

The shared **Find task or Stage** search now applies to:

- Reusable Task Catalog;
- Plan / Schedule; and
- Perform Work.

## Start Here

- [Setup Stage / Scene Material Resolution Contract — 2026-09-10](Setup_Stage_Scene_Material_Resolution_Contract_2026-09-10.md) — current accepted material/source-classification authority.
- [Setup Stage / Scene Production Acceptance — 2026-09-11](../../../../../Setup/Acceptance/Setup_Stage_Scene_Production_Acceptance_2026-09-11.md) — exact Production deployment, browser review, rollback, regression, and fingerprint evidence.
- [Setup Data Consumption and Authorization Contract — 2026-09-10](Setup_Data_Consumption_and_Authorization_Contract_2026-09-10.md) — Setup capability, Person mapping, application-role, governed write, and grant boundaries.
- [Setup Predecessor and Readiness Contract — 2026-09-09](Setup_Predecessor_and_Readiness_Contract_2026-09-09.md) — hard predecessor vs preferred order vs external/site readiness.
- [Setup Reconstruction Migration and Acceptance History — 2026-09-07 to 09](Setup_Reconstruction_Migration_and_Acceptance_History_2026-09-07_to_09.md) — historical migration/disposable/browser lessons and reconstruction findings.
- [Setup Planning Operating Model — 2026-09-08](Setup_Planning_Operating_Model_2026-09-08.md) — rolling-horizon planning direction.
- [Setup Planning Candidate Work View — 2026-09-09](Setup_Planning_Candidate_Work_View_2026-09-09.md) — cross-Stage candidate planning direction.
- [Setup Pick List Tablet Workflow — 2026-09-09](Setup_Pick_List_Tablet_Workflow_2026-09-09.md) — Pick List direction; not yet Production-operational.
- [Setup Session Production Engineering Handoff — 2026-09-07](Setup_Session_Production_Engineering_Handoff_2026-09-07.md) — original foundation/runtime baseline; historical for current deployment SHA/version.

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

`Gregovate/MSB-Server-Management` owns deployed service, listener, firewall, reverse-proxy, restart/recovery, host permissions, and Production deployment runbooks/runtime facts.

## Current Repository / Issue Structure

The accepted Stage/Scene material/presentation implementation is merged through PR #144.

Primary active work now is issue-driven rather than continuing the old nested PR stack:

```text
#122  Setup Session engineering / planning / Pick List / live reconstruction umbrella
#145  reusable Catalog cleanup gate before creating the 2026 Setup Session
#130  global People / Capability / Qualification work consumed by Setup
#132  Captain work-report duration / multi-day effort capture
#113  shared Scan application readiness / identity capture integration
```

Earlier Setup PRs #123/#124/#125/#134/#136/#137/#138/#139 are historical/superseded lineages and should not be treated as the current development authority once their unique accepted content is preserved in `main` and their closeout comments are recorded.

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

Structured readiness remains pending; the current free-text readiness note is descriptive only.

## Pick List Current Boundary

There is currently **no Production Pick List generator/report** and no accepted Setup tablet Pick List workflow.

The intended direction remains:

```text
selected Setup work
    -> resolved Displays
    -> current Containers
    -> deduplicate
    -> explain why each Container is required
```

Do not infer task scope from Container storage. Shared/mixed-stage Containers are normal.

## Data / Authorization Boundary

Cloudflare authentication, Setup capability, Person identity mapping, and PostgreSQL grants are separate layers.

Characteristic write failure:

```text
Authenticated Setup operator is not mapped to an MSB person
```

is a Person/Directus identity-link problem, not justification for broad Setup table DML.

Migration 025 added only the `ref.display_status` SELECT needed by automatic material resolution plus governed material setter EXECUTE; broad `ref.setup_task` DML remains forbidden for `fieldwiring_app`.

See [Setup Data Consumption and Authorization Contract](Setup_Data_Consumption_and_Authorization_Contract_2026-09-10.md).

## Known Limitations / Open Work

Current significant remaining work includes:

- reusable Catalog cleanup before 2026 propagation;
- continued correction of task boundaries exposed by live review;
- structured readiness and efficient predecessor entry;
- cross-Stage candidate planning surface / short-horizon scheduler workflow;
- authoritative Controller context from FieldWiring / Controller Inventory;
- Pick List generation and tablet workflow;
- mixed-stage Container annual mobilization/unload-group state and ordered-access rules;
- Container/Display movement/scanning writes; and
- park-location execution evidence.

## Resume Development

Before changing this subsystem:

1. read the Production Database Project Rules;
2. read this engineering portal;
3. read the Stage/Scene material-resolution contract before changing material or Scene classification;
4. review Issue #145 before creating or simulating 2026 annual state;
5. preserve annual 2025 facts separately from reusable future knowledge;
6. use the predecessor/readiness contract before rebuilding dependencies;
7. use the Pick List contract before implementing logistics/pick behavior;
8. use issue #130 / People and Identity for global capability/qualification work;
9. use issue #113 / Labeling and Scanning for shared scan capture/resolution behavior;
10. use `Gregovate/MSB-Server-Management` for current runtime/deployment authority; and
11. update controlled docs and this README handoff whenever accepted behavior or the next resume point changes.

## Related Systems

- [Setup and Deployment operator portal](../README.md)
- [Operator procedures](../operatorSOP/README.md)
- [Detailed Manager Review Guide](../../../02_Operational_SOPs/Setup/Setup_Session_Manager_Review_Guide.md)
- [People and Identity](../../03_People_and_Identity/README.md)
- [Labeling and Scanning](../../07_Labeling_and_Scanning/README.md)
- [Wiring System](../../09_Wiring_System/README.md)
