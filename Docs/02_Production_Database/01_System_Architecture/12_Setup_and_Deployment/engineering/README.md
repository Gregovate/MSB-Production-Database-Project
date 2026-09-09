# Setup and Deployment Engineering

| Document Control | Value |
|---|---|
| Document Type | Engineering Handoff Portal |
| System | Production Database — Setup and Deployment |
| Audience | Greg, maintainers, database administrators, future engineering sessions |
| Status | CURRENT HANDOFF — reusable catalog reconstruction accepted in Production; live PostgreSQL catalog is now the working baseline |
| Owner | MSB Production Database engineering |
| Last Reviewed | 2026-09-09 |

This is the engineering starting point for Setup Session architecture, database behavior, application contracts, Production state, task development, planning behavior, Pick List direction, and resume information.

The operator-facing instructions are separate under [`../operatorSOP/`](../operatorSOP/README.md).

## Current Production State

The protected Setup application is operational at:

```text
https://my.sheboyganlights.org/setup/
```

The 2025 Setup Session remains the real Production-backed Historical Review / Training environment. No 2026 Setup Session has been created.

The training/reconstruction correction package and the reviewed reusable-catalog reconstruction are accepted in Production.

```text
current deployed Setup SHA              = 5a8a317357ffa5d77c38bc4df63fe6c7b451dbaf
migrations 019-022                      = Production accepted
migrations 023-024                      = Production accepted
active reusable tasks                   = 185
total reusable task rows                = 187
reusable dependencies                   = 0
2026 Setup Sessions                     = 0
Production governed Setup fingerprint   = f0b98ac75e297a08eabc3df040708c08
```

The two non-active reusable rows are retired identities preserved for history. The zero dependency count is intentional: migration 024 reset the untrusted predecessor set so the next pass can rebuild hard predecessors separately from preferred order and readiness conditions.

The current PostgreSQL data is now the authoritative **working task baseline**. The large one-list workbook and 2022/2025 schedules remain historical/reconstruction evidence, but future task development should not maintain another spreadsheet as a parallel master. Continue adding, correcting, moving, and enriching reusable tasks against the current Production catalog, using historical evidence only to support those changes.

Known immediate catalog finding after deployment:

- physical `Set Up Frosty` is missing; transport-only `Bring Frosty to park` was correctly excluded from reusable work, but the physical setup task was never created;
- Frosty setup must precede the applicable Stars setup work;
- this belongs in the live catalog correction + predecessor pass, not in another bulk reconstruction import.

Production corrections already include:

- reconstruction-safe deletion of mistaken provisional historical tasks;
- Captain / Alternate / Advisor management using `ref.person` identity;
- reusable-task match/reconciliation state for annual 2025 items;
- active-person enforcement for new Captain/knowledge-owner assignments;
- reusable Stage/Scene organization and catalog order controls;
- compact Material / Logistics context;
- Physical Effort metadata (`LIGHT`, `MODERATE`, `HEAVY`, or unreviewed);
- the normalized 185-task reusable catalog;
- normalized `Locate Power & Network` and `Layout Panels` naming; and
- retirement of provisional reusable tasks 40 and 58 without fabricating 2025 annual rows.

The broader Setup subsystem remains open for real evaluation. Production availability and the accepted catalog do not mean 2026 planning, Pick List, movement, or predecessor/readiness work is complete.

## Start Here

- [Setup Catalog Reconstruction Import — 2026-09-09](Setup_Catalog_Reconstruction_Import_2026-09-09.md) — accepted historical record of migrations 023/024 and the one-time normalized catalog reconstruction. Do not treat it as the ongoing task master after Production acceptance.
- [Setup Planning Operating Model — 2026-09-08](Setup_Planning_Operating_Model_2026-09-08.md) — operator-confirmed planning model: short planning horizon, preferred-order scheduling, Needs Scheduling queue, Sunday avoidance, weather constraints, grass-cutting dependency for cords, multi-day tasks, crew/hour interpretation, mixed-stage Container mobilization, and historical evidence rules.
- [Setup Planning Candidate Work View — 2026-09-09](Setup_Planning_Candidate_Work_View_2026-09-09.md) — operator-confirmed planning surface between reusable Stage-organized tasks and the short-range schedule: cross-Stage Available/Blocked/In-Progress candidates, operator choice of what can/should happen next, and Arch Trailer unload/access order.
- [Setup Pick List Tablet Workflow — 2026-09-09](Setup_Pick_List_Tablet_Workflow_2026-09-09.md) — standalone Setup Pick List direction: tablet-first workflow, scan integration, task-to-Container resolver, mixed-stage Container behavior, and explicit statement that Pick List generation is not yet implemented.
- [2025 Live Review Work Ledger — 2026-09-08](Setup_2025_Live_Review_Work_Ledger_2026-09-08.md) — dated reconstruction/reconciliation evidence and decision history. Candidate/deployment status inside this dated ledger is historical; use this README and current Production data for current state.
- [Setup Training Browser Acceptance — 2026-09-08](Setup_Training_Browser_Acceptance_2026-09-08.md) — accepted browser-review evidence for the earlier correction/reconciliation package.
- [Setup Session Production Engineering Handoff — 2026-09-07](Setup_Session_Production_Engineering_Handoff_2026-09-07.md) — original Production foundation/runtime baseline and rollback context; retained as dated deployment history, not the latest runtime state.
- [Setup Internal Analytics and Visible Update Contract — 2026-09-07](Setup_Internal_Analytics_and_Version_Contract_2026-09-07.md) — GA4/privacy and visible revision contract.
- [Internal Web Backbone Handoff](Internal_Web_Backbone_Handoff.md) — source-subsystem contract for intranet navigation/search/application entry points.
- [Setup Session Shared Review and Season-Year Guard](../Setup_Session_Shared_Review_and_Season_Year_Guard_2026-09-07.md) — annual-vs-reusable data boundary and session-year enforcement.

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

The Production Database repository owns Setup application/business/database behavior. `Gregovate/MSB-Server-Management` owns deployed service, listener, firewall, reverse-proxy, restart/recovery, host permissions, and Production deployment runbooks.

## Current PR / Issue Structure

Primary current work remains:

```text
#122  Setup Session engineering / planning / Pick List / movement umbrella
#125  Production foundation / application lineage and eventual merge/closeout
#133  reusable task drag/drop between Stage-level and Scene scopes
#130  global People / Capability / Qualification catalog consumed by Setup
#132  Captain work-report duration / multi-day effort capture
#113  shared Scan application readiness / identity capture integration
```

The People/Skills work belongs to **03 — People and Identity**. Setup consumes that global identity/capability model; Setup must not create a second person/skill catalog.

## Current Task Development Source Rule

The one-time large reconstruction import is complete.

Use evidence in three buckets:

```text
1. annual historical fact
2. reusable Setup knowledge
3. ambiguous/question — do not guess
```

But the place where reusable tasks are now built and corrected is the current PostgreSQL catalog.

```text
current PostgreSQL reusable catalog
    -> identify missing/wrong task
    -> verify current Stage/Scene and practical task boundary
    -> correct/add reusable task in Production through governed application commands
    -> add reusable effort/resources/readiness/prerequisites when known
    -> preserve annual historical facts separately
```

Rick Hoffmann's 2025 spreadsheets, the reviewed one-list workbook, and the recovered 2022 Project schedule remain evidence. They are not normalized task definitions and are no longer a parallel authoritative task store.

Crew names do not automatically create Captains. Daily recorded hours do not automatically equal task duration. Multi-task work days require conservative interpretation.

## Current Planning Model

Setup is **not** a rigid season-long calendar scheduler.

The accepted operating direction is:

```text
preferred task order / prerequisites
    + work ready now
    + volunteers/equipment available
    + weather / site conditions
    + prior-day progress
    -> cross-Stage candidate planning view
    -> operator chooses what can/should happen next
    -> plan only the next few work days
    -> derive Pick List demand
    -> revise as conditions change
```

Important current rules:

- avoid Sunday work whenever reasonably possible;
- avoid rain and high winds whenever reasonably possible;
- do not lay cords until grass cutting has stopped;
- tasks may span several work days;
- expected duration is a planning aid, not a one-day restriction;
- preferred order and prerequisites matter more than false long-range date precision;
- the reusable task catalog may be organized by Stage for visualization, but Stage completion is not a scheduling gate;
- planning needs a separate cross-Stage candidate view showing Available / Blocked / In-Progress work before tasks receive dates;
- generic `Staging to Park` is obsolete as a reusable task;
- mixed-stage Containers/trailers must be detected from authoritative contents and mobilized when the first carried item is needed;
- Container-specific post-arrival behavior may be full unload, park/mobile storage, special transformation, or ordered partial unload and must not be guessed; and
- historical evidence should improve reusable crew ranges, expected effort, prerequisites, readiness rules, and missing task steps only where evidence supports them.

## Pick List Current Boundary

There is currently **no Production Pick List generator/report** and no accepted Setup tablet Pick List workflow.

The intended direction is a standalone **Pick List** section inside Setup, usable on a tablet and integrated with the shared scanning identity layer for `CONT`, `DISP`, and accepted `LOC` workflows.

Setup owns the Pick List business workflow. Issue #113 / Scan owns identity capture/resolution and supported Zebra/camera/manual input behavior.

See [Setup Pick List Tablet Workflow](Setup_Pick_List_Tablet_Workflow_2026-09-09.md).

## Known Boundaries / Open Work

Still unresolved or intentionally separate:

- live catalog completion/correction as additional real task knowledge is found, beginning with missing `Set Up Frosty`;
- reviewed predecessor/readiness pass across the current reusable catalog; dependencies are intentionally zero until this is rebuilt;
- classification of historical sequencing into **hard predecessor**, **preferred order**, or **readiness condition**;
- cross-Stage candidate planning surface and candidate-to-work-day workflow;
- work-day scheduling UX for Morning / Afternoon / All Day, parallel crews, and repeat scheduling of multi-day tasks;
- controlled reassign/merge when a 2025 annual item belongs to a different reusable task;
- authoritative Controller context in Material / Logistics from FieldWiring / Controller Inventory;
- Pick List generation and tablet workflow;
- mixed-stage Container annual mobilization/unload-group state and ordered-access rules;
- Container/Display movement/scanning writes and park-location execution evidence; and
- future People capability/qualification integration for crew suitability.

Issue #133 separately tracks Stage-level ↔ Scene drag/drop. It is useful but not a blocker for live task correction because scope can already be changed through the existing governed task controls.

Detailed KIT contents remain outside the current 2026 MVP, but an existing KIT Container can be a real physical Setup dependency.

## 2026 Session Gate

Do **not** create the 2026 Setup Session yet.

Before 2026 creation, the current live catalog should be useful enough for planning and the predecessor/readiness pass should establish the dependency/readiness rules needed by the candidate planning view. Creating 2026 before that would copy an intentionally dependency-empty catalog into annual planning prematurely.

## Critical Runtime Permission Boundary

`msbadmin` is the SSH administrator but runtime-path validation must use the `fieldwiring` service identity for paths and the shared Python environment that depend on runtime group permissions.

Server-side detail and recovery procedure belong in `Gregovate/MSB-Server-Management`.

## Resume Development

Before changing this subsystem:

1. read the Production Database Project Rules;
2. read this engineering portal;
3. inspect the current PostgreSQL reusable task catalog first; do not reconstruct the active task list from old spreadsheets or chat memory;
4. use the [Setup Catalog Reconstruction Import](Setup_Catalog_Reconstruction_Import_2026-09-09.md) as the accepted import/deployment history, not as an ongoing task master;
5. read the [Setup Planning Operating Model](Setup_Planning_Operating_Model_2026-09-08.md);
6. read the [Setup Planning Candidate Work View](Setup_Planning_Candidate_Work_View_2026-09-09.md) before implementing scheduling/planning UI;
7. read the [Setup Pick List Tablet Workflow](Setup_Pick_List_Tablet_Workflow_2026-09-09.md) before implementing logistics/pick behavior;
8. review Issue #122 and PR #125 for newest live findings and merge/closeout state;
9. preserve annual 2025 facts separately from reusable future knowledge;
10. do not infer exact duration, Captain, crew, or completion from shorthand evidence;
11. use Issue #130 / 03 People and Identity for global skill/qualification work;
12. use Issue #113 / Labeling and Scanning for shared scan capture/resolution contracts rather than duplicating scanner-specific logic in Setup;
13. use `Gregovate/MSB-Server-Management` for runtime/deployment authority; and
14. keep operator docs, engineering docs, PR/issue status, and Internal Web Backbone navigation synchronized when accepted behavior changes.

## Related Systems

- [Setup and Deployment operator portal](../README.md)
- [Operator procedures](../operatorSOP/README.md)
- [Detailed Manager Review Guide](../../../02_Operational_SOPs/Setup/Setup_Session_Manager_Review_Guide.md)
- [People and Identity](../../03_People_and_Identity/README.md)
- [Labeling and Scanning](../../07_Labeling_and_Scanning/README.md)
- [Wiring System](../../09_Wiring_System/README.md)
