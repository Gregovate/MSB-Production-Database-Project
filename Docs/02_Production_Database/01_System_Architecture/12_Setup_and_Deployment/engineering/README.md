# Setup and Deployment Engineering

| Document Control | Value |
|---|---|
| Document Type | Engineering Handoff Portal |
| System | Production Database — Setup and Deployment |
| Audience | Greg, maintainers, database administrators, future engineering sessions |
| Status | CURRENT HANDOFF — 2025 reconstruction active; correction/reconciliation package accepted in Production |
| Owner | MSB Production Database engineering |
| Last Reviewed | 2026-09-09 |

This is the engineering starting point for Setup Session architecture, database behavior, application contracts, Production state, reconstruction rules, planning behavior, Pick List direction, and resume information.

The operator-facing instructions are separate under [`../operatorSOP/`](../operatorSOP/README.md).

## Current Production State

The protected Setup application is operational at:

```text
https://my.sheboyganlights.org/setup/
```

The 2025 Setup Session remains the real Production-backed Historical Review / Training environment. No 2026 Setup Session has been created.

The operator-approved training/reconstruction correction package is now accepted in Production.

```text
accepted application/database target = aaf7de1c1d457b3dfaafe061f084a044cdf2abb7
migrations 019-022                = Production accepted
Production deployment result         = PASS
Production governed Setup fingerprint = unchanged across deployment
```

Production corrections now include:

- reconstruction-safe deletion of mistaken provisional historical tasks;
- Captain / Alternate / Advisor management using `ref.person` identity;
- reusable-task match/reconciliation state for annual 2025 items;
- active-person enforcement for new Captain/knowledge-owner assignments;
- improved Catalog return navigation;
- compact Material / Logistics summary with detailed dialog;
- clarified reusable-task match wording; and
- accepted Captain type-ahead behavior.

The broad Setup subsystem remains open for real 2025 evaluation. Production availability and this accepted package do not mean every 2026 planning, Pick List, movement, search, Scene-classification, or historical-reconstruction need is complete.

## Start Here

- [Setup Planning Operating Model — 2026-09-08](Setup_Planning_Operating_Model_2026-09-08.md) — operator-confirmed planning model: short planning horizon, preferred-order scheduling, Needs Scheduling queue, Sunday avoidance, weather constraints, grass-cutting dependency for cords, multi-day tasks, crew/hour interpretation, mixed-stage Container mobilization, and Rick spreadsheet evidence rules.
- [Setup Planning Candidate Work View — 2026-09-09](Setup_Planning_Candidate_Work_View_2026-09-09.md) — operator-confirmed missing planning surface between reusable Stage-organized tasks and the short-range schedule: cross-Stage Available/Blocked/In-Progress candidates, operator choice of what can/should happen next, and Arch Trailer unload/access order.
- [Setup Pick List Tablet Workflow — 2026-09-09](Setup_Pick_List_Tablet_Workflow_2026-09-09.md) — standalone Setup Pick List direction: tablet-first workflow, scan integration, task-to-Container resolver, mixed-stage Container behavior, and explicit statement that Pick List generation is not yet implemented.
- [2025 Live Review Work Ledger — 2026-09-08](Setup_2025_Live_Review_Work_Ledger_2026-09-08.md) — reconstruction/reconciliation work ledger, Rick-note interpretation rules, candidate lineage, unresolved findings, and historical acceptance context. Some candidate/deployment status inside this dated ledger predates the accepted 019-022 Production promotion; use this README and current issue/PR evidence for latest Production state.
- [Setup Training Browser Acceptance — 2026-09-08](Setup_Training_Browser_Acceptance_2026-09-08.md) — accepted browser-review evidence for the correction/reconciliation package.
- [Setup Session Production Engineering Handoff — 2026-09-07](Setup_Session_Production_Engineering_Handoff_2026-09-07.md) — original Production foundation/runtime baseline and rollback context.
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
#122  Setup Session engineering / planning / Pick List / live reconstruction umbrella
#125  Production foundation / application / correction lineage
#130  global People / Capability / Qualification catalog exposed by Captain review
#132  Captain work-report duration / multi-day effort capture
#113  shared Scan application readiness / identity capture integration
```

The People/Skills work belongs to **03 — People and Identity**. Setup consumes that global identity/capability model; Setup must not create a second person/skill catalog.

## Current Reconstruction Source Rules

Rick Hoffmann's 2025 spreadsheets are mixed evidence, not normalized task definitions.

Current reconstruction review window:

```text
2025-09-30 through Thanksgiving 2025
```

Use evidence in three buckets:

```text
1. 2025 annual historical fact
2. reusable Setup knowledge
3. ambiguous/question — do not guess
```

Crew names do not automatically create Captains. Daily recorded hours do not automatically equal task duration. Multi-task work days require conservative interpretation.

The 2022 Project schedule is also historical planning evidence for task decomposition, relative order, predecessors, rough duration, named crews, and equipment. It is not a rigid future schedule.

See the [Setup Planning Operating Model](Setup_Planning_Operating_Model_2026-09-08.md) for the durable interpretation and planning rules.

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
- 2025/2022 historical evidence should improve reusable crew ranges, expected effort, prerequisites, readiness rules, and missing task steps only where evidence supports them.

See [Setup Planning Candidate Work View](Setup_Planning_Candidate_Work_View_2026-09-09.md) for the missing planning layer and the operator-confirmed Arch Trailer unload/access order.

## Pick List Current Boundary

There is currently **no Production Pick List generator/report** and no accepted Setup tablet Pick List workflow.

The intended direction is a standalone **Pick List** section inside Setup, usable on a tablet and integrated with the shared scanning identity layer for `CONT`, `DISP`, and accepted `LOC` workflows.

Setup owns the Pick List business workflow. Issue #113 / Scan owns identity capture/resolution and supported Zebra/camera/manual input behavior.

See [Setup Pick List Tablet Workflow](Setup_Pick_List_Tablet_Workflow_2026-09-09.md).

## Known Boundaries / Open Work

Still unresolved or intentionally separate:

- controlled reassign/merge when a 2025 annual item belongs to a **different** reusable task;
- many missing reusable task steps exposed by Rick's 2025 notes and the recovered 2022 schedule;
- continued 2025 crew-size / expected-duration reconstruction;
- task/Stage search;
- cross-Stage candidate planning surface and candidate-to-work-day workflow;
- classification of historical predecessors into hard predecessor versus preferred order versus readiness condition;
- true Setup Scene versus LOR display-group classification using shared Folder Alignment classification;
- authoritative Controller context in Material / Logistics from FieldWiring / Controller Inventory;
- Pick List generation and tablet workflow;
- mixed-stage Container annual mobilization/unload-group state and ordered-access rules;
- Container/Display movement/scanning writes; and
- future People capability/qualification integration for crew suitability.

Detailed KIT contents remain outside the current 2026 MVP, but an existing KIT Container can be a real physical Setup dependency.

## Critical Runtime Permission Boundary

`msbadmin` is the SSH administrator but runtime-path validation must use the `fieldwiring` service identity for paths and the shared Python environment that depend on runtime group permissions.

Server-side detail and recovery procedure belong in `Gregovate/MSB-Server-Management`.

## Resume Development

Before changing this subsystem:

1. read the Production Database Project Rules;
2. read this engineering portal;
3. read the [Setup Planning Operating Model](Setup_Planning_Operating_Model_2026-09-08.md);
4. read the [Setup Planning Candidate Work View](Setup_Planning_Candidate_Work_View_2026-09-09.md) before implementing scheduling/planning UI;
5. read the [Setup Pick List Tablet Workflow](Setup_Pick_List_Tablet_Workflow_2026-09-09.md) before implementing staging/logistics/pick behavior;
6. review issue #122 and PR #125 for newest live-reconstruction findings;
7. use the [2025 Live Review Work Ledger](Setup_2025_Live_Review_Work_Ledger_2026-09-08.md) for historical reconstruction rules and lineage, but do not treat its older candidate status as current Production state;
8. preserve annual 2025 facts separately from reusable future knowledge;
9. do not infer exact duration, Captain, crew, or completion from shorthand evidence;
10. use issue #130 / 03 People and Identity for global skill/qualification work;
11. use issue #113 / Labeling and Scanning for shared scan capture/resolution contracts rather than duplicating scanner-specific logic in Setup;
12. use `Gregovate/MSB-Server-Management` for runtime/deployment authority; and
13. keep operator docs, engineering docs, and Internal Web Backbone navigation synchronized when accepted behavior changes.

## Related Systems

- [Setup and Deployment operator portal](../README.md)
- [Operator procedures](../operatorSOP/README.md)
- [Detailed Manager Review Guide](../../../02_Operational_SOPs/Setup/Setup_Session_Manager_Review_Guide.md)
- [People and Identity](../../03_People_and_Identity/README.md)
- [Labeling and Scanning](../../07_Labeling_and_Scanning/README.md)
- [Wiring System](../../09_Wiring_System/README.md)
