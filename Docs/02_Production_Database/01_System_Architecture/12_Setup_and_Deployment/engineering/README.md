# Setup and Deployment Engineering

| Document Control | Value |
|---|---|
| Document Type | Engineering Handoff Portal |
| System | Production Database — Setup and Deployment |
| Audience | Greg, maintainers, database administrators, future engineering sessions |
| Status | CURRENT HANDOFF — Production catalog reconstruction accepted; live PostgreSQL catalog is the working baseline |
| Owner | MSB Production Database engineering |
| Last Reviewed | 2026-09-09 |

This is the engineering starting point for Setup Session architecture, database behavior, application contracts, deployment state, task development, and resume information.

The operator-facing instructions are separate under [`../operatorSOP/`](../operatorSOP/README.md).

## Current State

Production deployment is operational and accepted.

```text
public application             = https://my.sheboyganlights.org/setup/
application version            = V0.3.4-shared-season-guard-review
current deployed Setup SHA     = 5a8a317357ffa5d77c38bc4df63fe6c7b451dbaf
2025 Setup Session             = HISTORICAL_VERIFICATION
2026 Setup Sessions            = 0
active reusable Setup tasks    = 185
total reusable task rows       = 187
reusable dependencies          = 0
effort LIGHT                   = 8
effort MODERATE                = 12
effort HEAVY                   = 4
effort unreviewed              = 161
Production Setup fingerprint   = f0b98ac75e297a08eabc3df040708c08
```

Accepted runtime state includes:

```text
/opt/msb-setup                 = permanent detached worktree
msb-setup.service              = active / enabled
msb-setup-google-links.service = active / enabled
listener                       = 192.168.5.9:8794
UFW                            = 8794/tcp from Synology 192.168.5.4 only
Synology /setup/ route         = active
Cloudflare-authenticated view  = PASS
protected no-identity path     = HTTP 401 PASS
live Setup regression          = 134 passed
```

The 185-task reusable catalog reconstruction is accepted in Production. The dependency set is intentionally zero pending the reviewed predecessor/readiness pass.

## Current Task Development Authority

The one-time large reconstruction import is complete.

The current **Production PostgreSQL reusable catalog** is now the working task baseline. Continue adding, correcting, moving, and enriching reusable tasks against current PostgreSQL data through governed Setup application/database commands.

Historical sources remain evidence:

- the reviewed one-list reconstruction workbook;
- 2025 Setup notes/spreadsheets; and
- the recovered 2022 Project schedule.

They are not a parallel ongoing master task list.

Immediate live finding after catalog deployment:

- transport-only `Bring Frosty to park` was correctly excluded as logistics;
- physical reusable `Set Up Frosty` was not created and is therefore missing from the current catalog;
- Frosty setup must precede the applicable Stars setup work during the predecessor pass.

This is the expected post-import workflow: correct the current PostgreSQL catalog rather than reopening the workbook as the master.

## Start Here

- [Setup Session Production Engineering Handoff — 2026-09-07](Setup_Session_Production_Engineering_Handoff_2026-09-07.md) — original database/application/runtime deployment baseline and rollback context. Treat its task counts/SHA as dated acceptance history, not current state.
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

The current Setup work is coordinated through:

```text
#122  Setup Session engineering / planning / Pick List / movement umbrella
#125  Production foundation / application lineage and eventual merge/closeout
#133  Stage-level ↔ Scene drag/drop usability follow-up
#130  global People / Capability / Qualification catalog consumed by Setup
#132  Captain work-report duration / multi-day effort capture
#113  shared Scan application readiness / identity capture integration
```

PR #125 remains open/draft because the Setup subsystem is not yet ready for final lineage normalization/merge even though the current Production runtime and catalog are accepted.

## Known Boundaries / Open Work

Still unresolved or intentionally separate:

- live reusable-catalog corrections as real task knowledge is found, beginning with missing `Set Up Frosty`;
- reviewed predecessor/readiness pass across the current catalog;
- classification of sequencing evidence into hard predecessor versus preferred order versus readiness condition;
- cross-Stage candidate planning surface and short-horizon scheduling workflow;
- Morning / Afternoon / All Day scheduling, parallel crews, and multi-day carry-forward behavior;
- controlled reassign/merge when a 2025 annual item belongs to a different reusable task;
- authoritative Controller context from FieldWiring / Controller Inventory;
- Pick List generation and tablet workflow;
- mixed-stage Container annual mobilization/unload-group state and ordered-access rules;
- Container/Display movement/scanning writes and park-location execution evidence; and
- future People capability/qualification integration for crew suitability.

Issue #133 is useful but non-blocking because task scope can already be changed through governed task controls.

No 2026 Setup Session should be created until the current catalog and predecessor/readiness model are useful enough for planning.

## Critical Runtime Permission Boundary

`msbadmin` is the SSH administrator but does not have the `msb-docs-read` traversal permissions used by the `fieldwiring` runtime account on `/mnt/msb-display-folders` and `/mnt/msb-setup-google-links`.

Runtime-path validation must run as `fieldwiring`. Server-side detail and recovery procedure belong in `Gregovate/MSB-Server-Management`.

## Resume Development

Before changing this subsystem:

1. read the Production Database Project Rules;
2. inspect the current Production PostgreSQL reusable catalog first; do not reconstruct the active task list from chat memory or old spreadsheets;
3. review Issue #122 and PR #125 for the newest accepted findings and closeout state;
4. preserve the annual-2025-versus-reusable-task boundary;
5. classify predecessor evidence carefully rather than recreating a rigid historical sequence;
6. use Issue #130 / People and Identity for global capability/qualification work;
7. use Issue #113 / Labeling and Scanning for shared scan capture/resolution contracts;
8. use `Gregovate/MSB-Server-Management` for current runtime/service/proxy/deployment facts; and
9. keep operator docs and engineering docs synchronized when accepted behavior changes.

Current resume point:

```text
Production runtime                    = ACCEPTED
Production reusable catalog           = 185 active tasks
current task working source           = PostgreSQL
reusable dependency set               = intentionally empty / rebuild next
2026 Setup Session                    = NOT CREATED
Pick List                             = NOT YET PRODUCTION WORKFLOW
movement/location writes              = NOT YET PRODUCTION WORKFLOW
PR #125                               = OPEN DRAFT / lineage closeout pending
```

## Related Systems

- [Setup and Deployment operator portal](../README.md)
- [Operator procedures](../operatorSOP/README.md)
- [Detailed Manager Review Guide](../../../02_Operational_SOPs/Setup/Setup_Session_Manager_Review_Guide.md)
- [Labeling and Scanning](../../07_Labeling_and_Scanning/README.md)
- [Wiring System](../../09_Wiring_System/README.md)
