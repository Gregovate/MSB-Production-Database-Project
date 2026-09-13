# Setup Session Production Engineering Handoff — 2026-09-12

| Document Control | Value |
|---|---|
| Document Type | Engineering Handoff |
| System | Production Database — Setup Session |
| Status | CURRENT HANDOFF — V0.3.13 accepted in Production |
| Owner | MSB Production Database engineering |
| Last Reviewed | 2026-09-12 |

## Purpose

Preserve the current accepted Setup Session Production state and resume point after Issue #141 so future work starts from repository evidence.

## Current Production Runtime

```text
protected application = https://my.sheboyganlights.org/setup/
live /opt/msb-setup SHA = 3fb975ca355711cece564cfd874cf8d7514310bf
version = V0.3.13-assignment-layer
service = msb-setup.service
listener = 192.168.5.9:8794
2025 Setup Session = HISTORICAL_VERIFICATION / SANDBOX
2026 Setup Sessions = 0
```

Server/runtime authority remains `Gregovate/MSB-Server-Management`.

## Accepted Assignment Layer

Issue #141 is accepted in Production.

- LOR remains the current Stage/real-Scene Display source authority.
- One material-bearing task in a scope continues to work implicitly.
- Multiple material-bearing tasks in the same scope use explicit Display Ownership.
- Each current resolved Display has one effective reusable Setup-task owner.
- Managers can multi-select Displays and move them between eligible material tasks.
- Large ownership boards include **Move selected to** so drag is not the only path.
- Display assignment does not rewrite LOR membership or the Display's current Container.
- Physical Kit Boxes are explicitly assigned many-to-many to reusable tasks.
- Existing SUPPORT / REQUIRED_CONTAINER relationships remain separate from KIT.
- The same physical Kit Box may support several reusable tasks.
- No 2026 Setup Session was created.

Final real Production browser acceptance passed on Candyland with **Coverage complete**.

## Accepted Source and Migration Chain

```text
initial V0.3.13 candidate/deployment = 48f0a44ca20296f7d211df240f0af7c324ad44e1
migrations = 028 -> 029 -> 030
current source-only correction = 3fb975ca355711cece564cfd874cf8d7514310bf
```

The source-only correction addressed large-board scrolling/stuck drag behavior and removed engineering Issue wording from the operator-facing assignment dialog.

## Preservation Baseline

Preserve V0.3.7 dirty-edit/client-build protections, V0.3.8 compact task detail, V0.3.9 prerequisite behavior, V0.3.10 Resource Catalog behavior, V0.3.11 active-task identity, V0.3.13 assignment behavior, the Stage/Scene resolver, current Display/Container authority, and 2025 historical boundaries.

## Remaining Pre-Launch Sequence

```text
#167 Extra Materials / KIT contents / material-source foundation
  -> #145 FINAL reusable-Catalog acceptance + disposable 2026 seed proof
  -> #122 real 2026 Setup Session + scheduling / Pick List launch gate
```

#145 remains the final Catalog content/seed acceptance gate. #167 may legitimately refine reusable task boundaries before that final gate.

## Runtime / Rollback Boundary

Current source-only rollback:

```text
return /opt/msb-setup to 48f0a44ca20296f7d211df240f0af7c324ad44e1
restart only msb-setup.service
```

No PostgreSQL restore belongs to that UI rollback.

The migration-bearing deployment backup/report and stale-fingerprint stop are recorded in `Setup/Acceptance/Setup_Assignment_Layer_V0313_Production_Acceptance_2026-09-12.md`.

## Engineering Resume

Next Setup work is Issue #167 unless a separate explicit Production defect takes priority.

Before changing Setup:

1. refresh remote `main`;
2. read Project Rules;
3. read the Setup engineering README and this handoff;
4. read the Supporting Information Contract;
5. preserve V0.3.7 through V0.3.13;
6. use 2025 as the proving ground;
7. follow `#167 -> #145 FINAL -> #122`; and
8. use Server Management for runtime/deployment authority.

## Related Current Evidence

- `Setup/Acceptance/Setup_Assignment_Layer_V0313_Production_Acceptance_2026-09-12.md`
- `Setup/Acceptance/Setup_Active_Task_Context_V0311_Production_Acceptance_2026-09-12.md`
- `Setup_Task_Supporting_Information_Contract_2026-09-11.md`
