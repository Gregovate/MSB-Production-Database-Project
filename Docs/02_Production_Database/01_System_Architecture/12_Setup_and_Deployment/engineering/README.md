# Setup and Deployment Engineering

| Document Control | Value |
|---|---|
| Document Type | Engineering Handoff Portal |
| System | Production Database — Setup and Deployment |
| Audience | Greg, maintainers, database administrators, future engineering sessions |
| Status | CURRENT HANDOFF — #184 durable inventory + #167 one-time reconstruction accepted in Production |
| Owner | MSB Production Database engineering |
| Last Reviewed | 2026-09-15 |

Operator-facing instructions are separate under [`../operatorSOP/`](../operatorSOP/README.md).

## Current Production State

```text
protected application = https://my.sheboyganlights.org/setup/
live /opt/msb-setup SHA = 1e0e2d2c3ffbcafc2ffef2bb4a98c81d600e8b1b
version = V0.3.13-assignment-layer
2025 Setup Session = HISTORICAL_VERIFICATION / SANDBOX
2026 Setup Sessions = 0
physical inventory events after reconstruction = 0
```

Current protected Setup core fingerprint after #167 Production acceptance:

```text
adc431f96b5622e125bf44d96e3d7807
```

## Accepted Assignment / Kit Relationship Contract

LOR remains authoritative for current Stage/real-Scene Display membership. Display Ownership provides one effective reusable task owner when a scope has several material-bearing tasks and never rewrites LOR or `ref.display.container_id`.

Physical Kit Boxes are existing `ref.container` rows. Reusable task -> Kit assignment remains many-to-many through:

```text
ref.setup_task_container_support
relationship_type = 'KIT'
```

The same Kit may support several reusable tasks. Existing SUPPORT / REQUIRED_CONTAINER semantics remain separate.

## Durable Extra Material / Inventory Contract — #184

Issue #184 / PR #185 is complete and merged. The permanent Production subsystem owns:

```text
ref.setup_extra_material                     normalized catalog
ref.setup_task_extra_material                reusable task requirement
ref.setup_task_extra_material_source         expected source allocation
ref.setup_container_extra_material           expected Container / Kit content
ref.setup_container_extra_material_review    Remainders / Unverified Items
ops.setup_extra_material_inventory_event     append-only physical event history
ops.setup_extra_material_inventory_balance   current physical balance view
```

Application surfaces:

```text
Reusable task detail: Extra Materials Required by This Task
/setup/kit-inventory/
/setup/t-post-inventory/
```

Permanent semantic separation:

```text
what task requires
!= what a Kit/Container should contain
!= where material is physically stored
!= what was physically counted
!= current Display -> Container membership
```

Manager-maintained expected definitions do not create inventory counts. Inventory events do not rewrite expected definitions. Physical T-Post storage may legitimately be shared/bulk or stored with a Kit/Display; storage does not assign task requirement ownership.

## Completed One-Time Reconstruction — #167

Issue #167 / PR #187 now owns historical closeout only. The accepted one-time candidate was:

```text
1e0e2d2c3ffbcafc2ffef2bb4a98c81d600e8b1b
```

Production one-time migrations:

```text
038
043
044
045
046
047
048
```

They loaded reviewed legacy-procedure/normalization evidence into the durable #184 structures without creating a 2026 Session, physical inventory events, or competing task-to-Kit relationships. Current Production Kit assignments were preserved unchanged. Unknown/conflicting values remain `UNVERIFIED` / `NEEDS_REVIEW` or durable Remainders.

Disposable acceptance:

```text
SETUP_REUSABLE_DISPOSABLE_ACCEPTANCE_PASS
Production fingerprint before/after = 6b7e34a06ca82a2b9a2eb04a41b1e130 unchanged
live Setup SHA before/after = 9761cf91596a35c732acec3ed7872271f7f16d2a unchanged
report = /home/msbadmin/setup-acceptance-reports/Setup_Disposable_Acceptance_20260915T003934.txt
```

Production acceptance:

```text
SETUP_167_PRODUCTION_RECONSTRUCTION_PASS
live regression = 298 passed
FINAL LIVE SHA = 1e0e2d2c3ffbcafc2ffef2bb4a98c81d600e8b1b
2026 Setup Sessions = 0
physical inventory events = 0
protected core fingerprint before/after = adc431f96b5622e125bf44d96e3d7807 unchanged
rollback archive = /home/msbadmin/backups/setup-167/msb-pre-setup-167-reconstruction-20260915T005504.dump
targeted pre-image = /home/msbadmin/backups/setup-167/msb-pre-setup-167-target-tables-20260915T005504.dump
report = /home/msbadmin/setup-deployment-reports/Setup_167_Kit_Inventory_Reconstruction_Production_Migrate_20260915T005504.txt
```

A prior Production attempt failed only because the deployment harness checked `/tpost-inventory/` instead of the real `/t-post-inventory/`. The fail-closed runner restored both the live checkout and the targeted tables; marker counts returned to zero. The harness is now contract-tested against that route typo.

## Preservation Baseline

Preserve:

```text
V0.3.7  dirty-edit/client-build safety
V0.3.8  compact task-detail layout
V0.3.9  Shift-drag prerequisite + canonical prerequisite editor
V0.3.10 reusable Resource Catalog
031      task-resource upsert named-constraint repair
V0.3.11 persistent active-task identity
V0.3.13 Display ownership + physical Kit Box assignment
#184     durable Extra Material / Kit Inventory / T-Post subsystem
#167     accepted one-time reconstructed data now resident in #184 structures
```

Also preserve the Stage/Scene resolver, 2025 historical/sandbox boundary, current Display/Container authority, narrow governed write commands, existing analytics integration/privacy boundary, and no real 2026 Session until launch gates pass.

## Remaining Launch Sequence

#184 and #167 are complete. The controlling sequence is now:

```text
#145 FINAL reusable-Catalog acceptance + disposable 2026 seed proof
  -> #122 real 2026 Setup Session + scheduling / Pick List launch gate
```

#145 is the final Catalog content/seed acceptance checkpoint after the task/material structure has been shaped. #122 owns the real annual Session, scheduling, Pick List, and operator-output launch gate.

## Runtime / Rollback

Server/runtime authority remains `Gregovate/MSB-Server-Management`.

The accepted #184 and #167 rollback archives are retained. Restoration is a governed database operation and must reconcile legitimate post-deployment work; do not use those archives as casual UI rollback points.

The live application remains at accepted data candidate `1e0e2d2...`. Later branch commits contain deployment harness corrections and documentation closeout only.

## Resume Checklist

Before the next Setup change:

1. refresh current remote `main` and record exact HEAD;
2. read Project Rules and this engineering portal;
3. read `Setup_Session_Production_Engineering_Handoff_2026-09-12.md`;
4. read `Setup_Task_Supporting_Information_Contract_2026-09-11.md`;
5. preserve accepted V0.3.7 through V0.3.13 plus #184/#167 inventory behavior/data;
6. keep 2025 as the proving ground until the remaining launch gates pass;
7. continue with `#145 FINAL -> #122`;
8. use `Gregovate/MSB-Server-Management` for runtime/deployment/browser-review authority; and
9. update controlled docs and acceptance evidence whenever accepted behavior or the resume point changes.

## Related Systems

- [Setup operator portal](../README.md)
- [Operator procedures](../operatorSOP/README.md)
- [Detailed Manager Review Guide](../../../02_Operational_SOPs/Setup/Setup_Session_Manager_Review_Guide.md)
- [Kit Inventory / T-Post Production Acceptance](../../../../../Setup/Acceptance/Setup_Kit_Inventory_TPost_Production_Acceptance_2026-09-15.md)
- [Setup Assignment Layer V0.3.13 Production Acceptance](../../../../../Setup/Acceptance/Setup_Assignment_Layer_V0313_Production_Acceptance_2026-09-12.md)
