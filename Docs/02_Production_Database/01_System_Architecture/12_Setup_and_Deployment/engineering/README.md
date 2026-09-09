# Setup and Deployment Engineering

| Document Control | Value |
|---|---|
| Document Type | Engineering Handoff Portal |
| System | Production Database — Setup and Deployment |
| Audience | Greg, maintainers, database administrators, future engineering sessions |
| Status | CURRENT HANDOFF — 2025 reconstruction active; correction/reconciliation package accepted in Production |
| Owner | MSB Production Database engineering |
| Last Reviewed | 2026-09-08 |

This is the engineering starting point for Setup Session architecture, database behavior, application contracts, Production state, reconstruction rules, planning behavior, and resume information.

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

The broad Setup subsystem remains open for real 2025 evaluation. Production availability and this accepted package do not mean every 2026 planning, pick-list, movement, search, Scene-classification, or historical-reconstruction need is complete.

## Start Here

- [Setup Planning Operating Model — 2026-09-08](Setup_Planning_Operating_Model_2026-09-08.md) — operator-confirmed planning model: short planning horizon, order/crew-driven scheduling, Sunday avoidance, weather constraints, grass-cutting dependency for cords, multi-day tasks, crew/hour interpretation, missing-step reconstruction rules, and Rick spreadsheet evidence window.
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
#122  Setup Session engineering / planning / live reconstruction umbrella
#125  Production foundation / application / correction lineage
#130  global People / Capability / Qualification catalog exposed by Captain review
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

See the [Setup Planning Operating Model](Setup_Planning_Operating_Model_2026-09-08.md) for the durable interpretation and planning rules.

## Current Planning Model

Setup is **not** a rigid season-long calendar scheduler.

The accepted operating direction is:

```text
preferred task order / prerequisites
    + work ready now
    + volunteers available
    + weather / site conditions
    + prior-day progress
    -> plan only the next few work days
    -> revise as conditions change
```

Important current rules:

- avoid Sunday work whenever reasonably possible;
- avoid rain and high winds whenever reasonably possible;
- do not lay cords until grass cutting has stopped;
- tasks may span several work days;
- expected duration is a planning aid, not a one-day restriction;
- preferred order and prerequisites matter more than false long-range date precision; and
- 2025 historical notes should improve reusable crew ranges, expected effort, prerequisites, readiness rules, and missing task steps only where evidence supports them.

## Known Boundaries / Open Work

Still unresolved or intentionally separate:

- controlled reassign/merge when a 2025 annual item belongs to a **different** reusable task;
- many missing reusable task steps exposed by Rick's 2025 notes;
- continued 2025 crew-size / expected-duration reconstruction;
- task/Stage search;
- true Setup Scene versus LOR display-group classification using shared Folder Alignment classification;
- authoritative Controller context in Material / Logistics from FieldWiring / Controller Inventory;
- Pick List generation;
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
4. review issue #122 and PR #125 for newest live-reconstruction findings;
5. use the [2025 Live Review Work Ledger](Setup_2025_Live_Review_Work_Ledger_2026-09-08.md) for historical reconstruction rules and lineage, but do not treat its older candidate status as current Production state;
6. preserve annual 2025 facts separately from reusable future knowledge;
7. do not infer exact duration, Captain, crew, or completion from shorthand evidence;
8. use issue #130 / 03 People and Identity for global skill/qualification work;
9. use `Gregovate/MSB-Server-Management` for runtime/deployment authority; and
10. keep operator docs, engineering docs, and Internal Web Backbone navigation synchronized when accepted behavior changes.

## Related Systems

- [Setup and Deployment operator portal](../README.md)
- [Operator procedures](../operatorSOP/README.md)
- [Detailed Manager Review Guide](../../../02_Operational_SOPs/Setup/Setup_Session_Manager_Review_Guide.md)
- [People and Identity](../../03_People_and_Identity/README.md)
- [Labeling and Scanning](../../07_Labeling_and_Scanning/README.md)
- [Wiring System](../../09_Wiring_System/README.md)
