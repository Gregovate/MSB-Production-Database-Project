# Setup Session Production Engineering Handoff — 2026-09-12

| Document Control | Value |
|---|---|
| Document Type | Engineering Handoff |
| System | Production Database — Setup Session |
| Status | CURRENT HANDOFF — V0.3.11 accepted in Production; 2026 launch preparation active |
| Owner | MSB Production Database engineering |
| Last Reviewed | 2026-09-12 |

## Purpose

Preserve the current accepted Setup Session Production state and resume point after Issue #169 so future work starts from repository evidence rather than reconstructing recent deployment and acceptance from chat or issue comments.

This handoff supersedes `Setup_Session_Production_Engineering_Handoff_2026-09-11.md` for current runtime/resume facts. The 2026-09-11 handoff remains historical evidence for the V0.3.10 baseline and surrounding system contracts.

## Current Production Runtime

```text
protected application = https://my.sheboyganlights.org/setup/
live /opt/msb-setup SHA = 28ad2d28addd47f8f086ed3b2e53468b453dbe13
version = V0.3.11-active-task-context
service = msb-setup.service active / enabled
listener = 192.168.5.9:8794
2025 Setup Session = HISTORICAL_VERIFICATION / SANDBOX
2026 Setup Sessions = 0
```

Server/runtime authority remains `Gregovate/MSB-Server-Management`.

## V0.3.11 Accepted Behavior

Issue #169 is complete. The selected reusable task identity is mirrored into the already-sticky global Setup header while the review view has a selected task.

Accepted behavior:

- **ACTIVE TASK** plus Stage/task identity remains visible through the full long-detail scroll;
- switching tasks updates that identity immediately;
- Catalog/Movement views do not keep stale active-task context;
- normal task-detail heading remains intact;
- V0.3.7 Save / Discard / Stay dirty-edit protections remain intact;
- V0.3.8 compact task-detail layout remains intact;
- V0.3.9 prerequisite behavior remains intact;
- V0.3.10 Resource Catalog behavior remains intact;
- existing Stage/Scene Display resolver remains intact;
- light/dark and narrowed/responsive browser behavior passed acceptance; and
- no schema/database change was introduced.

Implementation is presentation-only in `setup_active_task_context.js` / `.css` plus the V0.3.11 client/server build identity.

## V0.3.11 Production Evidence

Exact candidate/deployed runtime:

```text
28ad2d28addd47f8f086ed3b2e53468b453dbe13
```

Pre-production disposable browser review:

```text
Production fingerprint before = 86d6fcf3a2505ee9a1448167677a1264
Production fingerprint after  = 86d6fcf3a2505ee9a1448167677a1264
live Setup checkout unchanged = PASS
operator browser review = ACCEPTED FOR PRODUCTION DEPLOYMENT GATE
```

Production deployment:

```text
source-only deployment = PASS
health = V0.3.11-active-task-context
only msb-setup.service restarted
```

Post-deployment gate:

```text
LIVE_CHECKOUT=PASS
LIVE_HEALTH=PASS
PRODUCTION_FINGERPRINT=PASS
52 passed in 0.26s
LIVE_FOCUSED_REGRESSION=PASS
POST-DEPLOYMENT GATE PASSED
```

Real protected Production browser:

```text
PASS
```

See `Setup/Acceptance/Setup_Active_Task_Context_V0311_Production_Acceptance_2026-09-12.md` for complete evidence.

## Current Preservation Baseline

Future Setup changes must preserve:

```text
V0.3.7  dirty-edit/client-build protections
V0.3.8  compact task-detail layout
V0.3.9  Shift-drag prerequisite + canonical prerequisite editor
V0.3.10 reusable Resource Catalog behavior
V0.3.11 persistent active-task header context
```

Also preserve:

- current Stage/Scene Display resolver;
- 2025 historical/sandbox boundary;
- current Display/Container authority;
- current narrow authorization/write-command model; and
- no real 2026 Setup Session until the remaining launch gates pass.

## Remaining Pre-September-30 Launch Path

Issue #169 is no longer a blocker. Remaining sequence:

```text
#145  reusable Catalog cleanup / correct schedulable work packages
  -> #141 task-specific Display ownership/material subdivision
  -> #167 Extra Materials / KIT / material-source foundation
  -> disposable 2026 creation/scheduling proof
  -> #122 real 2026 Setup Session + scheduling / Pick List launch gate
```

Do not create the real 2026 Setup Session merely to exercise future workflow before these gates are satisfied.

## Field-Execution Gates Before Physical Setup

The required portions of these workstreams remain before crews depend on the system in the park:

```text
#132       Production Crew work/progress/duration/authorization
#113/#88   Scan + Location/movement execution
#171       GIS/layout + targeted underground-locate workflow
#175       offline/print field packet + Work Order correction fallback
```

## Current Material / Supporting Information Boundary

The current Stage/Scene Display resolver remains accepted and must not be replaced by #141 or #167 work.

Keep separate:

```text
resolved LOR Displays/Containers
vs.
which Setup task owns each Display in multi-step scopes (#141)
vs.
Extra Materials / KITs / expected source relationships (#167)
vs.
what is physically present now
```

The detailed current operating model remains in `Setup_Task_Supporting_Information_Contract_2026-09-11.md`.

## Runtime / Rollback Boundary

Current source-only rollback target for V0.3.11:

```text
c2a1820627f1a036d634241cc6aecd1a926a1479
V0.3.10-resource-catalog
```

V0.3.11 rollback is application-only and follows the Server Management source-only Setup deployment runbook. No PostgreSQL restore belongs to a V0.3.11 source rollback.

Migration 027 remains accepted database state beneath V0.3.11. Its separate validated archive/rollback evidence remains historical V0.3.10 material.

## Engineering Resume

Next Setup work should begin with Issue #145 unless another explicit Production defect takes priority.

Before changing Setup:

1. refresh current remote `main` and record exact HEAD;
2. read Project Rules and the current Setup engineering README;
3. read this handoff;
4. read the Setup Task Supporting Information Contract;
5. preserve V0.3.7 through V0.3.11 accepted behavior;
6. use 2025 as the proving ground until remaining launch gates pass;
7. follow the remaining sequence `#145 -> #141 -> #167 -> #122`;
8. use Server Management for runtime/browser-review/deployment authority; and
9. promote accepted discoveries and Production evidence into controlled documentation before closeout.

## Related Current Evidence

- `Setup/Acceptance/Setup_Active_Task_Context_V0311_Production_Acceptance_2026-09-12.md`
- `Setup/Acceptance/Setup_Resource_Catalog_V0310_Production_Acceptance_2026-09-11.md`
- `Setup/Acceptance/Setup_Predecessor_V039_Production_Acceptance_2026-09-11.md`
- `Setup/Acceptance/Setup_Task_Detail_Production_Acceptance_2026-09-11.md`
- `Setup_Task_Supporting_Information_Contract_2026-09-11.md`
- `Setup_Stage_Scene_Material_Resolution_Contract_2026-09-10.md`
