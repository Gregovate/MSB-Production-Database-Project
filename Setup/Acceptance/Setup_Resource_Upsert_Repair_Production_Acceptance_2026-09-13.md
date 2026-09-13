# Setup Resource Upsert Repair Production Acceptance — 2026-09-13

| Document control | Value |
|---|---|
| Status | ACCEPTED PRODUCTION |
| Application | Setup Session |
| Issue | #152 |
| Repair candidate | `931bd9b4779cc2cc8fd1f9deb3d6087dec0bf1d3` |
| Production migration | `Setup/Database/031_fix_setup_task_resource_upsert.sql` |
| Live application SHA | `3fb975ca355711cece564cfd874cf8d7514310bf` |
| Version | `V0.3.13-assignment-layer` |

## Defect and root cause

Real Elf Choir Catalog work exposed `column reference "setup_task_id" is ambiguous` while assigning the existing `SkyTrak` resource. Migration 027 had recreated `ref.set_setup_task_resource(...)` with a bare-column `ON CONFLICT` target even though migration 015 had already hardened the same PL/pgSQL command with the named primary-key constraint.

Migration 031 is the forward correction. It preserves current Resource Catalog semantics, function signature, inactive-resource behavior, actor/audit boundary, `SECURITY DEFINER`, narrow `fieldwiring_app` EXECUTE, and the absence of broad task-resource DML.

## Pre-Production acceptance

Exact candidate `931bd9b...` passed the full Setup application suite: `256 passed`.

Disposable current-Production-clone validation passed the complete `ADD -> UPDATE -> REMOVE -> RE-ADD` resource path. The disposable browser review then passed the same workflow interactively, including update and refresh persistence.

Evidence retained:

```text
/home/msbadmin/setup-acceptance-reports/Setup_Disposable_Acceptance_20260913T151309.txt
/home/msbadmin/setup-acceptance-reports/Setup_Disposable_Browser_Preview_20260913T151501.txt
```

## Production gate and rollback evidence

Immediately before Production mutation the known defect was still present, the application role had no broad task-resource DML, there were no active `fieldwiring_app` database sessions, and the governed Setup fingerprint was `fe7a36da08bbb4b17eec142bbbc1a7ee`.

The exact candidate passed a detached Production-runtime regression: `256 passed in 0.78s`.

Validated rollback archive:

```text
/home/msbadmin/backups/setup-152/msb-pre-setup-152-resource-fix-20260913T161606.dump
bytes  = 15828325
sha256 = 28ef952a2644e210b9c168eeca16138bed5b7f88e8a2c3fb4bd5daa26efa997a
archive validation = PASS
```

## Production result

Only migration 031 was applied.

Post-migration contract:

```text
named constraint target present = true
ambiguous bare target present   = false
fieldwiring_app EXECUTE         = true
broad INSERT                    = false
broad UPDATE                    = false
broad DELETE                    = false
```

The governed Setup fingerprint remained unchanged by the migration:

```text
before = fe7a36da08bbb4b17eec142bbbc1a7ee
after  = fe7a36da08bbb4b17eec142bbbc1a7ee
```

The live application remained unchanged and healthy at `3fb975ca355711cece564cfd874cf8d7514310bf`, `V0.3.13-assignment-layer`.

Production deployment report:

```text
/home/msbadmin/setup-deployment-reports/Setup_152_Resource_Fix_Production_Deploy_20260913T161831.txt
```

## Protected Production browser acceptance

After migration, the operator used the normal protected Setup route and made the legitimate Elf Choir `SkyTrak` assignment. The retained task state showed `SkyTrak`, `Qty 1`, `Required`. The task was saved, closed/reopened, and the assignment persisted. The prior ambiguity error did not recur.

Operator disposition: **PASS**. The temporary hold on task Equipment / Resource writes was removed.

## Corrective note to V0.3.10 acceptance

The original V0.3.10 Resource Catalog acceptance remains valid for catalog management, stable resource identity, search/catalog UI, authorization, and deployment facts. It did not sufficiently exercise a fresh task-resource upsert through the migration-027 conflict target to expose this PL/pgSQL ambiguity.

Migration 031 is the current accepted database contract for `ref.set_setup_task_resource(...)`.

## Independent follow-up

- Production Database #181 — resource search typo tolerance and match ranking.
- Server Management #37 — governed Setup maintenance mode, protected maintenance page, and write-freeze procedure.

Neither blocks #152 closeout.
