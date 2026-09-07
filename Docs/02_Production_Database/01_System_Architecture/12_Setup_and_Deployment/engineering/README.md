# Setup and Deployment Engineering

| Document Control | Value |
|---|---|
| Document Type | Engineering Handoff Portal |
| System | Production Database — Setup and Deployment |
| Audience | Greg, maintainers, database administrators, future engineering sessions |
| Status | CURRENT HANDOFF — permanent Setup application deployment in progress |
| Owner | MSB Production Database engineering |
| Last Reviewed | 2026-09-07 |

This is the engineering starting point for Setup Session architecture, database behavior, application contracts, deployment state, and resume information.

The operator-facing instructions are separate under [`../operatorSOP/`](../operatorSOP/README.md).

## Current State

The V0.3.4 Production database promotion is accepted.

```text
2025 Setup Session          = HISTORICAL_VERIFICATION
2025 annual tasks           = 57
2025 UNVERIFIED tasks       = 57
2026 Setup Sessions         = 0
Setup work days             = 0
Setup movement events       = 0
active reusable Setup tasks = 57
```

The permanent protected application/service route is still being deployed. Intended public entry point:

```text
https://my.sheboyganlights.org/setup/
```

## Start Here

- [Setup Session Production Engineering Handoff — 2026-09-07](Setup_Session_Production_Engineering_Handoff_2026-09-07.md) — current database/application/runtime boundary and exact resume point.
- [Internal Web Backbone Handoff](Internal_Web_Backbone_Handoff.md) — source-subsystem contract for intranet navigation/search/application entry points.

## Authoritative Implementation Sources

Application/runtime source:

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

The Production Database owns Setup application/business/database behavior. `Gregovate/MSB-Server-Management` owns deployed service, listener, firewall, reverse-proxy, restart/recovery, and host permission facts.

## Existing Engineering Evidence

The dated engineering and historical evidence already stored directly in `12_Setup_and_Deployment/` remains valid supporting material. It is not being mass-moved during this conversion because that would create unnecessary inbound-link risk.

Important current planning/reconnaissance documents include:

- [`../11_Setup_Session_2026_Planning_Direction_2026-09-04.md`](../11_Setup_Session_2026_Planning_Direction_2026-09-04.md)
- [`../Reusable_Setup_Work_Plan_and_Scheduler_Requirements_2026-09-06.md`](../Reusable_Setup_Work_Plan_and_Scheduler_Requirements_2026-09-06.md)
- [`../Setup_Session_Engineering_Reconnaissance_2026-09-03.md`](../Setup_Session_Engineering_Reconnaissance_2026-09-03.md)
- [`../Historical_Setup_Planning_Evidence_2024.md`](../Historical_Setup_Planning_Evidence_2024.md)
- [`../Container_Stage_Relationship_Reconnaissance_2026-09-03.md`](../Container_Stage_Relationship_Reconnaissance_2026-09-03.md)

Older Procedure/shared-field-context acceptance records in the parent folder remain historical engineering evidence and should not be exposed as normal operator task choices.

## Critical Runtime Permission Boundary

`msbadmin` is the SSH administrator but does not have the `msb-docs-read` traversal permissions used by the `fieldwiring` runtime account on `/mnt/msb-display-folders`.

Setup/Procedure filesystem validation must run under the runtime account. The permanent server-side rule and recovery detail belong in `Gregovate/MSB-Server-Management`; this subsystem records the dependency so future application work does not misdiagnose the permission boundary as an application defect.

## Resume Development

Current resume point:

```text
V0.3.4 database promotion             = ACCEPTED
Production Database branch            = agent/setup-session-production-foundation
accepted database/app source SHA      = 2b94e0ecb21fde88ce20acc24855fc1c84d21eb6
PR                                     = #125 draft, updated with live DB state
old disposable Setup preview          = identified on 127.0.0.1:8794
permanent Setup service               = not yet installed
public /setup/ route                  = not yet installed
```

Next work must use Server Management runtime authority for service/permission/proxy deployment, then return here to record live application acceptance and merge readiness.

## Related Systems

- [Setup and Deployment operator portal](../README.md)
- [Operator procedures](../operatorSOP/README.md)
- [Labeling and Scanning](../../07_Labeling_and_Scanning/README.md)
- [Wiring System](../../09_Wiring_System/README.md)
