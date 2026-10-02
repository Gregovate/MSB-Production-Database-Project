# Setup #205 V0.3.34 Scheduling Readiness Fixes Production Acceptance — 2026-10-01

## Status

**PRODUCTION ACCEPTED**

Owning issue: **#205 — Setup #122 rolling Scheduling Board**  
Commanding Setup issue: **#122**

## Accepted application identity

```text
Production Setup SHA = e103eedbf8caaf580ce6fe5df392fbd68c0cb7f4
Production version   = V0.3.34-scheduling-readiness-fixes
Production mode      = postgres
```

Repository identity:

```text
application PR #281 merge = 8e0e40f73038d16452034d7b2c44846b89bdaed8
deployment tooling PR #283 merge / main = 64de3d2cfac17ad8688a47a3fd6d227d47e7745c
migration = Setup/Database/067_fix_setup_annual_hold_command.sql
migration blob = ee2e9417efc22a9821258df0522a7f518117b5e8
validation = Setup/Acceptance/setup_205_annual_hold_disposable_validation.sql
validation blob = 6348a824e0393af954c92087b34acbb2767ec64f
```

## Accepted scope

This bounded post-launch #205 release corrected three launch-critical Scheduling Board defects:

- inline **Mark Ready / Mark Not Ready** was restored to the existing governed readiness command after the newer Annual Readiness path had accidentally rerouted it through an application-side row lock;
- the full **Annual Readiness** note/state editor now uses governed SECURITY DEFINER command `ops.set_setup_annual_hold(text,bigint,boolean,text)`, keeping `fieldwiring_app` without broad UPDATE on `ops.setup_session_task`;
- duplicate readiness wording was removed from task cards so the dedicated Readiness row is the single visible readiness statement;
- the persistent informational Production banner was removed while actionable save/error feedback remains available;
- Plan / Schedule now uses available desktop width and shifts additional wide-screen space toward the Scheduling Board / AM / PM lanes while preserving the existing <=1100px stacked layout.

## Root cause of readiness regression

The operator correctly reported that Mark Ready had worked before this defect.

The prior inline action called:

```text
PATCH /api/setup/scheduling-board/season-tasks/<id>/readiness
    -> SetupSchedulingBoardRepository.set_readiness()
    -> ops.set_setup_annual_task_readiness(...)
```

That path uses the existing governed SECURITY DEFINER command and requires no broad table UPDATE privilege.

The later Annual Readiness implementation rerouted the inline action through `/annual-hold`. Its repository implementation issued direct `SELECT ... FOR UPDATE` against `ops.setup_session_task`. Because `fieldwiring_app` intentionally lacks broad UPDATE on that table, PostgreSQL rejected the row lock.

V0.3.34 restores quick readiness to the original governed path and confines the new annual note/state workflow to the new governed migration-067 command.

## Pre-Production acceptance

Exact candidate:

`e103eedbf8caaf580ce6fe5df392fbd68c0cb7f4`

Full Setup/Application regression:

```text
654 passed in 1.85s
```

Reusable current-Production disposable acceptance:

```text
SETUP REUSABLE DISPOSABLE ACCEPTANCE: CLEAN EXIT
```

Final disposable browser review:

```text
Operator disposition = PASS
SETUP REUSABLE DISPOSABLE BROWSER PREVIEW: CLEAN EXIT
```

Browser acceptance covered:

- Mark Ready / Mark Not Ready;
- Annual Readiness save;
- single readiness presentation;
- removal of the persistent Production banner;
- wide-screen Scheduling Board expansion.

## Production deployment

Deployment followed the current Server Management Production Database Change Deployment Runbook using the established bounded Setup write-freeze pattern while durable Server Management #37 remains separate work.

Final wrapper result:

```text
SETUP #205 V0.3.34 SETUP/POSTGRESQL PRODUCTION DEPLOYMENT WRAPPER: PASS
exit status = 0
```

Production invariants:

```text
Frozen Setup fingerprint = 9951600040f7b01c75b8c104b4ddeb8c
Final Setup fingerprint  = 9951600040f7b01c75b8c104b4ddeb8c
PASS: governed Setup business rows unchanged

2026 Setup Session count before = 1
2026 Setup Session count after  = 1
PASS: 2026 Setup Session count unchanged
```

Rollback/evidence:

```text
rollback archive = /home/msbadmin/backups/setup-205/msb-pre-setup-205-v034-20261002T005512.dump
rollback SHA256 = 7d2017c6f55993b7464d10ccbd3b80f0fe85ff1fac866f6521d63e50b1e01f66
deployment report = /home/msbadmin/setup-deployment-reports/Setup_205_V034_Production_Deploy_20261002T005512.txt
```

## Security / authority boundary

Migration 067 adds only the narrow governed annual-hold command.

The accepted contract preserves:

- EXECUTE for `fieldwiring_app` on the governed readiness commands;
- no broad INSERT / UPDATE / DELETE on `ops.setup_session_task`;
- annual readiness edit blocked once actual/progress history exists;
- actor attribution through the existing Setup management actor boundary.

## Repository closeout

The accepted application SHA is contained in merged `main`.

The Production Deployment Change Log, Setup acceptance index, current Setup engineering handoff, and Internal Web Backbone handoff are updated as part of this release closeout.

Remaining separate work includes Server Management #37 maintenance/write-freeze infrastructure and #222 performance follow-up; neither is part of this accepted V0.3.34 release.

---
