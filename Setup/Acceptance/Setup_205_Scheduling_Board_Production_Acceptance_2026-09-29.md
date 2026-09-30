# Setup #205 Scheduling Board / Captain Dispatch Production Acceptance — 2026-09-29

## Status

**PRODUCTION ACCEPTED**

Owning issue: **#205 — Setup #122 rolling Scheduling Board with dynamic crews and short-horizon replanning**

Commanding Setup issue: **#122**

## Accepted application identity

```text
Production Setup SHA = 9a614c1fa2eea0b425b03bdb4ac3e1790634c760
Production version   = V0.3.21-scheduling-gates
Production mode      = postgres
```

This is the browser-accepted application target. Later deployment-tooling or closeout/documentation commits do not redefine the deployed application identity.

## Production deployment boundary

Authority:

`Gregovate/MSB-Server-Management/docs/server/Setup_Source_Only_Application_Deployment_Runbook.md`

Deployment was **source-only**:

- no PostgreSQL migration;
- no Setup data mutation by deployment;
- no environment change;
- no systemd unit change;
- no proxy/firewall change;
- only `/opt/msb-setup` advanced to the exact accepted SHA;
- only `msb-setup.service` was restarted.

The prior live / rollback SHA was:

`3cedba88283e4766932ae7905034856a2b9baa00`

## Final Production deployment evidence

Successful report:

`/home/msbadmin/setup-deployment-reports/Setup_205_Work_Order_Gate_UX_Source_Only_Production_Deploy_20260929T200651.txt`

Final evidence:

```text
LIVE SETUP REGRESSION: PASS

Fingerprint before source deployment:
c9e8395208bc2829dfa6cf4225a0ef1a

Fingerprint after source deployment:
c9e8395208bc2829dfa6cf4225a0ef1a

2026 Setup Session count after: 1

SETUP_205_WORK_ORDER_GATE_UX_SOURCE_ONLY_PRODUCTION_DEPLOYMENT_PASS

Prior / rollback SHA:
3cedba88283e4766932ae7905034856a2b9baa00

Deployed exact SHA:
9a614c1fa2eea0b425b03bdb4ac3e1790634c760

Final Setup health:
{"data_mode":"postgres","status":"ok","version":"V0.3.21-scheduling-gates"}

Exit status: 0
```

The deployment left the real 2026 Setup Session intact.

## Acceptance history

Final exact candidate regression:

```text
586 passed in 1.34s
```

Final reusable disposable acceptance passed on the accepted application candidate with Production unchanged.

Final disposable browser acceptance proved:

- signed-in scheduled Captains default to their own current Perform Work assignments;
- Perform Work is the Captain-facing current-priority/dispatch view;
- Planned labor / Actual labor / Variance KPI cards are visible;
- broader `All scheduled work` remains an explicit operator choice;
- season-only WO 372 is schedulable Setup Work;
- linked Work Order completion can complete/satisfy the annual Setup item;
- annual placement remains:
  - after `Layout / Erect Frame / Strap Down`;
  - before `Install Skins and Bungees`;
- Work Order completion can therefore release downstream Skins without duplicate completion reporting.

Final disposable-browser clean-exit report:

`/home/msbadmin/setup-acceptance-reports/Setup_Disposable_Browser_Preview_20260929T193517.txt`

Final browser Flask log:

`/tmp/Setup_Disposable_Browser_Preview_Flask_20260929T193517.log`

## First Production deployment attempt

The first source-only attempt advanced the accepted application and passed all substantive live gates, including:

- detached exact-target regression;
- V0.3.21 health;
- accepted browser assets;
- live #205 source contract;
- unauthenticated API negative path;
- live 586-test regression;
- unchanged Setup fingerprint;
- retained 2026 Session count.

It then failed because the deployment runner referenced `SESSION_2026_BEFORE` before that shell variable had been assigned on the normal execution path.

Fail-closed rollback returned Production to `3cedba88283e4766932ae7905034856a2b9baa00` with unchanged data and healthy V0.3.20 runtime.

The deployment-tooling-only defect was corrected, the runner was repinned, and the second source-only attempt completed successfully. No application acceptance was invalidated by that tooling correction.

## Accepted operator behavior

### Rolling schedule

The annual Scheduling Board remains the near-term planning authority.

Operators may:

- schedule only the next few days;
- use dynamic Crew A/B/C/D lanes;
- schedule Morning / Afternoon / All Day work;
- reorder/move future unworked assignments;
- preserve worked historical assignments;
- schedule later continuation work when a task remains incomplete;
- keep annual planned order separate from day/crew assignment.

### Season-only task identity

Season-only annual tasks remain permanently annual-only in the season where they were created.

They do **not**:

- write to `ref.setup_task`;
- auto-promote into reusable Catalog tasks;
- seed later Sessions.

If a recurring need is discovered later, a Manager creates a separate reusable Catalog task with its own identity.

### Work Order behavior

`Setup Work` and `Wait / Gate` are distinct:

- **Setup Work** is schedulable crew work.
- **Wait / Gate** is not schedulable and exists only to block downstream work until an outside condition is satisfied.

A linked Work Order may be:

- context/reference only; or
- configured so Work Order completion also completes/satisfies the annual Setup item.

This allows real repair work to remain schedulable while keeping Work Order lifecycle authority in the Work Order system.

### Labor visibility

Derived display values are now surfaced without schema changes:

- planned labor = planned crew × expected duration;
- actual labor = actual crew × actual elapsed duration;
- Perform Work shows Planned / Actual / Variance;
- missing plan inputs remain explicit rather than fabricating a precise value.

### Captain dispatch

For a signed-in Captain who has scheduled assignments:

- Perform Work defaults to that Captain's own current assignments;
- current schedule ordering is their current operational priority;
- broader views remain available by explicit selection;
- stale persisted `All scheduled work` preference no longer overrides the fresh Captain default.

Future Captain self-claim of TBD work is deliberately deferred until after launch stabilization.

## Handoff to #206

#205 no longer owns Pick List/material movement implementation.

Issue #206 must consume the now-live scheduling/annual truth from Production SHA:

`9a614c1fa2eea0b425b03bdb4ac3e1790634c760`

Before continuing material-frontier or scan/movement acceptance, #206 must deliberately refresh/reconcile its branch against this accepted #205 application state.

Key #206 implications:

- scheduled work is the strongest near-term demand signal;
- same-day downstream material visibility remains valid;
- unscheduled downstream material must not be presented as though the downstream task itself owns the precursor's Day/shift/crew assignment;
- annual season-only Work Order tasks and annual readiness/hold context are now available to the scheduling graph;
- schedule intent remains separate from physical pick/movement truth;
- #206 remains responsible for Pick List/material readiness, physical movement state, Scan handoff, and park-location behavior.

Do not move those responsibilities back into #205.

## Closeout

#205 is Production accepted.

Remaining launch-critical Setup work continues under #122 and #206, with Scan/GIS work retained under their existing owning issues.
