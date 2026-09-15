# Setup Kit Inventory / Extra Materials / T-Post Production Acceptance — 2026-09-15

| Document Control | Value |
|---|---|
| Document Type | Production Acceptance Record |
| System | Production Database — Setup and Deployment |
| Issues | #184 durable subsystem; #167 one-time reconstruction |
| Status | ACCEPTED PRODUCTION |
| Production version | V0.3.13-assignment-layer |
| Final live Setup SHA | `1e0e2d2c3ffbcafc2ffef2bb4a98c81d600e8b1b` |

## Accepted Capability

Production now has the durable Setup Extra Material / Kit Inventory / T-Post subsystem:

- normalized Extra Material catalog;
- reusable task Extra Material requirements;
- expected source allocation;
- expected Container / Kit Extra Material contents;
- durable Unverified Items / Remainders;
- append-only physical inventory event history and balance;
- standalone Kit Inventory covering physical Kit Boxes;
- current task-to-Kit assignment visibility using existing `ref.setup_task_container_support` / `relationship_type='KIT'`;
- current Display contents shown separately through `ref.display.container_id`;
- standalone T-Post Inventory distinguishing shared/bulk stock from T-Posts intentionally stored with Kits/Displays;
- Manager maintenance of reusable definitions and authorized inventory-operator physical count/adjustment workflow.

The subsystem preserves the separation between task requirement, expected source/content, physical storage, physical count, and Display/Container membership.

## #184 Durable Foundation Deployment

Accepted deployed application target:

```text
9761cf91596a35c732acec3ed7872271f7f16d2a
```

Production migrations:

```text
032_add_setup_extra_material_schema.sql
033_add_setup_extra_material_manager_commands.sql
034_add_setup_extra_material_container_commands.sql
035_add_setup_extra_material_inventory_commands.sql
036_seed_setup_extra_material_catalog.sql
037_harden_setup_extra_material_duplicate_rows.sql
```

Operator-visible browser review accepted the compact Kit Inventory design before Production approval.

Governed deployment evidence:

```text
Production fingerprint before = adc431f96b5622e125bf44d96e3d7807
Production fingerprint after  = adc431f96b5622e125bf44d96e3d7807
result = PASS
rollback = /home/msbadmin/backups/setup-184/msb-pre-setup-184-kit-inventory-20260915T001407.dump
report = /home/msbadmin/setup-deployment-reports/Setup_184_Durable_Kit_Inventory_Production_Deploy_20260915T001407.txt
```

No 2026 Setup Session was created and no physical counts were fabricated by the foundation deployment.

## #167 Disposable Acceptance

The reconstruction branch was rebuilt cleanly on accepted #184 `main`. Shared #184 acceptance-harness files were restored from current `main`; the final reconstruction diff remained the intended #167-specific migrations/validations/docs.

Accepted exact data candidate:

```text
1e0e2d2c3ffbcafc2ffef2bb4a98c81d600e8b1b
```

Disposable current-Production-clone run applied only:

```text
038
043
044
045
046
047
048
```

Final disposable evidence:

```text
SETUP_REUSABLE_DISPOSABLE_ACCEPTANCE_PASS
Production Setup fingerprint before = 6b7e34a06ca82a2b9a2eb04a41b1e130
Production Setup fingerprint after  = 6b7e34a06ca82a2b9a2eb04a41b1e130
live Setup SHA before/after = 9761cf91596a35c732acec3ed7872271f7f16d2a
report = /home/msbadmin/setup-acceptance-reports/Setup_Disposable_Acceptance_20260915T003934.txt
exit status = 0
```

## #167 Production Migration

The Production migration used the Server Management Production Database Change Deployment Runbook pattern: one SCP bundle plus one foreground SSH bounded runner, exact-candidate detached regression, validated full rollback archive, targeted table pre-image, Setup-service write freeze, exact migrations/validations, post-state invariants, and fail-closed rollback.

One first Production attempt reached successful database validation but then failed on a harness typo checking `/tpost-inventory/` instead of the real `/t-post-inventory/`. The runner restored `/opt/msb-setup` and the targeted #167 tables. Post-rollback evidence showed zero #167 markers and zero 2026 Sessions. The harness was corrected and contract-tested before rerun.

Final successful Production proof:

```text
298 passed in 0.68s
LIVE SETUP REGRESSION: PASS
FINAL LIVE SHA: 1e0e2d2c3ffbcafc2ffef2bb4a98c81d600e8b1b
2026 Setup Sessions: 0
Physical inventory history unchanged: 0 row(s)
Protected Setup core fingerprint unchanged: adc431f96b5622e125bf44d96e3d7807
SETUP_167_PRODUCTION_RECONSTRUCTION_PASS
exit status: 0
```

Retained recovery/evidence:

```text
full rollback = /home/msbadmin/backups/setup-167/msb-pre-setup-167-reconstruction-20260915T005504.dump
targeted pre-image = /home/msbadmin/backups/setup-167/msb-pre-setup-167-target-tables-20260915T005504.dump
report = /home/msbadmin/setup-deployment-reports/Setup_167_Kit_Inventory_Reconstruction_Production_Migrate_20260915T005504.txt
```

## Reconstructed Data Boundary

Procedure-derived data is intentionally reviewable:

- unknown/conflicting values remain `UNVERIFIED` or `NEEDS_REVIEW`;
- expected Kit contents are not physical counts;
- Remainders preserve unresolved evidence instead of inventing structured truth;
- current Production task-to-Kit assignments remain authoritative and were not replaced by reconstruction;
- physical inventory history remained empty after reconstruction;
- no real 2026 Setup Session was created.

T-Post requirement truth belongs to reusable task/installation scope. Physical storage may be shared/bulk or intentionally with a Kit/Display where evidence supports that physical arrangement. Storage location does not create task requirement ownership.

## Final Disposition

```text
#184 durable subsystem = ACCEPTED PRODUCTION
#167 one-time reconstruction = ACCEPTED PRODUCTION / COMPLETE
next Setup launch gate = #145 FINAL reusable-Catalog acceptance + disposable 2026 seed proof
then = #122 real 2026 Session / scheduling / Pick List launch
```
