# Setup Session Production Engineering Handoff — 2026-09-12

| Document Control | Value |
|---|---|
| Document Type | Engineering Handoff |
| System | Production Database — Setup Session |
| Status | CURRENT HANDOFF — V0.3.13 accepted; #184 durable Kit/Extra Material foundation in acceptance |
| Owner | MSB Production Database engineering |
| Last Reviewed | 2026-09-14 |

## Purpose

Preserve the current accepted Setup Session Production state and current launch/acceptance sequence after Issue #141, the corrective Issue #152 resource-write repair, and the #167/#184 durable-vs-reconstruction split.

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

- LOR remains authority for current Stage/real-Scene Display membership.
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
assignment migrations = 028 -> 029 -> 030
current source-only correction = 3fb975ca355711cece564cfd874cf8d7514310bf
resource upsert repair migration = 031_fix_setup_task_resource_upsert.sql
```

The source-only correction addressed large-board scrolling/stuck drag behavior and removed engineering Issue wording from the operator-facing assignment dialog.

Migration 031 is a database-only forward repair for the governed task-resource command. It corrected a migration-027 PL/pgSQL `ON CONFLICT` ambiguity by restoring the named primary-key constraint target while preserving current Resource Catalog behavior, authorization, and least privilege.

Production acceptance for migration 031 passed with unchanged governed Setup fingerprint, unchanged live application SHA/version, and real protected-route `SkyTrak` assignment persistence after task reopen.

See `Setup/Acceptance/Setup_Resource_Upsert_Repair_Production_Acceptance_2026-09-13.md`.

## Preservation Baseline

Preserve V0.3.7 dirty-edit/client-build protections, V0.3.8 compact task detail, V0.3.9 prerequisite behavior, V0.3.10 Resource Catalog behavior, the migration-031 task-resource write correction, V0.3.11 active-task identity, V0.3.13 assignment behavior, the Stage/Scene resolver, current Display/Container authority, and 2025 historical boundaries.

The task Equipment / Resource write hold imposed during the #152 defect is removed. Normal authorized Add/Update/Remove Resource operations are accepted again.

## Durable Inventory Ownership — #184 vs #167

The earlier combined Extra Material / procedure-reconstruction work has been split permanently.

Issue #184 owns the durable Production subsystem:

```text
normalized Extra Material catalog
reusable Setup task Extra Material requirements
expected Container / Kit Extra Material contents
source allocation
Remainders / Unverified Items
append-only physical inventory history
Kit Inventory application
Kit -> reusable Setup task visibility
Assigned / Unassigned Kit review
separate T-Post inventory
Manager / Production Crew maintenance authority
```

The existing task -> Kit authority remains:

```text
ref.setup_task_container_support
relationship_type = 'KIT'
```

#184 must not create a second task-to-Kit relationship or add reconstruction-only procedure evidence runtime.

Issue #167 now owns only the one-time legacy-procedure / normalization reconstruction and migration into the accepted #184 structures. Its migration does not create physical inventory-count events, a new task -> Kit relationship, a real 2026 Setup Session, or a permanent reconstruction runtime dependency.

The frozen stacked #167 candidate has already passed disposable acceptance against the current #184 schema candidate:

```text
PR #187 candidate = 3c80d421c27223cefadf19280559dd0ff0bf18e8
result = DISPOSABLE_SETUP_167_EXTRA_MATERIAL_ACCEPTANCE_PASS
Production Setup fingerprint before = 7024080ae1982ae3fa3d1ebf44bd3d71
Production Setup fingerprint after  = 7024080ae1982ae3fa3d1ebf44bd3d71
report = /home/msbadmin/setup-acceptance-reports/Setup_167_Extra_Material_Disposable_20260914T043106.txt
```

That proof establishes that the planned durable #184 model can receive normalized task requirements, normalized Kit expected contents, UNVERIFIED migrated inventory state, durable Kit Remainders, and separate T-Post source rows for Containers 36 and 118. Historical C072 T-Post evidence remains a Remainder rather than current active Kit inventory.

Do not modify the frozen #167 reconstruction while #184 is being accepted unless an actual #184 schema incompatibility is discovered.

## Independent Follow-Up Findings

The #152 repair exposed two independent future items that do not block current Production operation:

- Production Database #181 — improve resource-search typo tolerance and match ranking; and
- Server Management #37 — governed Setup maintenance mode, protected maintenance page, and technical write-freeze procedure.

## Remaining Pre-Launch Sequence

The controlling sequence is now:

```text
#184 durable Extra Material / Kit Inventory / T-Post Production foundation
  -> #167 one-time reconstruction migration retargeted to accepted #184/main
  -> #145 FINAL reusable-Catalog acceptance + disposable 2026 seed proof
  -> #122 real 2026 Setup Session + scheduling / Pick List launch gate
```

#184 must first pass exact-candidate Setup/Application regression, disposable current-Production PostgreSQL acceptance, and exact-candidate browser/operator review. Only after those pass may a separate explicit Production deployment approval be requested.

After #184 is accepted and deployed, PR #187 is retargeted from the #184 branch to `main`, its migration-only disposable acceptance is rerun against the actually installed #184 schema, the reconstructed Kit/Remainder/T-Post data is reviewed through the durable UI, and the one-time #167 Production migration receives its own explicit approval gate.

#145 remains the final Catalog content/seed acceptance gate. #122 remains the real annual Setup Session / scheduling / Pick List launch gate.

## Runtime / Rollback Boundary

Current source-only rollback for the large-scope UI correction:

```text
return /opt/msb-setup to 48f0a44ca20296f7d211df240f0af7c324ad44e1
restart only msb-setup.service
```

No PostgreSQL restore belongs to that source-only rollback.

The #141 migration-bearing deployment has separate rollback evidence in `Setup/Acceptance/Setup_Assignment_Layer_V0313_Production_Acceptance_2026-09-12.md`.

The #152 migration-031 repair has separate governed database rollback evidence in `Setup/Acceptance/Setup_Resource_Upsert_Repair_Production_Acceptance_2026-09-13.md`. Do not restore that archive merely to undo an application/UI problem or without reconciling legitimate post-repair Production work.

#184 is both migration-bearing and user-facing. Production mutation must therefore remain behind the Server Management Production Database change runbook and the exact-candidate browser-review gate. The permanent Setup runtime remains `/opt/msb-setup` / `msb-setup.service`; do not substitute the source-only runbook for the database-migration portion of #184.

## Engineering Resume

Current controlling Setup implementation work is Issue #184 / PR #185.

Before changing Setup:

1. refresh remote `main` and the #184 branch;
2. read Project Rules;
3. read the Setup engineering README and this handoff;
4. read the Supporting Information Contract;
5. preserve V0.3.7 through V0.3.13 plus migration 031;
6. keep 2025 as the proving ground and create no real 2026 Setup Session;
7. follow `#184 -> #167 one-time migration -> #145 FINAL -> #122`;
8. keep #167 reconstruction frozen unless #184 exposes a concrete incompatibility; and
9. use Server Management for disposable acceptance, browser review, and Production deployment authority.

## Related Current Evidence

- `Setup/Acceptance/Setup_Resource_Upsert_Repair_Production_Acceptance_2026-09-13.md`
- `Setup/Acceptance/Setup_Assignment_Layer_V0313_Production_Acceptance_2026-09-12.md`
- `Setup/Acceptance/Setup_Active_Task_Context_V0311_Production_Acceptance_2026-09-12.md`
- `Setup_Task_Supporting_Information_Contract_2026-09-11.md`
