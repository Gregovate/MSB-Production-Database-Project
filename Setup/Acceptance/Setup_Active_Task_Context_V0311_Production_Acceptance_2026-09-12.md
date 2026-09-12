# Setup Active Task Context V0.3.11 Production Acceptance — 2026-09-12

| Document control | Value |
|---|---|
| Status | ACCEPTED PRODUCTION |
| Application | Setup Session |
| Issue | #169 — Keep the active Setup task name visible while reviewing long task details |
| Implementation PR | #177 |
| Exact application candidate / deployed runtime | `28ad2d28addd47f8f086ed3b2e53468b453dbe13` |
| Version | `V0.3.11-active-task-context` |
| Prior accepted runtime | `c2a1820627f1a036d634241cc6aecd1a926a1479` / `V0.3.10-resource-catalog` |
| Database migration | None — source-only application change |
| Production date | 2026-09-12 |

## Purpose

Record the accepted Production result for Issue #169: the currently selected reusable Setup task identity remains visible while an operator scrolls through long task detail, reducing the risk of editing the wrong reusable task during Catalog cleanup.

## Accepted Operator Behavior

When a task is selected in the Setup review view, the existing selected Stage/task identity is mirrored into the already-sticky global Setup header.

Accepted behavior:

- the sticky header shows **ACTIVE TASK** plus the selected Stage/task identity;
- the identity remains visible while scrolling through the full long task-detail page;
- switching to another task updates the persistent identity immediately;
- the persistent identity is shown only while the review view has a selected task, so Catalog/Movement views do not retain stale task context;
- existing Setup/session/operator/client/theme context remains visible;
- existing light/dark theme tokens are reused;
- responsive wrapping remains intact;
- the normal task-detail heading remains unchanged;
- V0.3.7 Save / Discard / Stay dirty-edit protections remain unchanged;
- V0.3.8 compact task-detail layout remains unchanged;
- V0.3.9 prerequisite behavior remains unchanged;
- V0.3.10 Resource Catalog behavior remains unchanged; and
- the accepted Stage/Scene Display resolver remains unchanged.

The implementation is presentation-only. `setup_active_task_context.js` does not call Setup APIs and does not own save, navigation, authorization, or dirty-edit behavior.

## Pre-Production Browser Review

The exact application candidate was reviewed through the repository-owned disposable browser-review process using a current-Production PostgreSQL clone and a separate temporary non-Production listener.

Exact candidate:

```text
28ad2d28addd47f8f086ed3b2e53468b453dbe13
V0.3.11-active-task-context
```

Browser-review launcher:

```text
Setup/Acceptance/run_setup_active_task_context_browser_preview.ps1
```

The operator used temporary localhost port `8893`. The port is not part of the Production contract; the browser-review runbook requires an explicit verified-unused non-Production port.

Operator disposition:

```text
ACCEPTED FOR PRODUCTION DEPLOYMENT GATE
```

Observed acceptance included:

- active Stage/task identity stayed visible through long-page scrolling;
- task switching updated the persistent identity;
- Save / Discard / Stay dirty-navigation behavior remained correct;
- light and dark modes remained readable;
- narrowed/responsive presentation remained usable; and
- surrounding task-detail, Material / Logistics, prerequisite, Resource Catalog, Captain, and procedure behavior remained intact.

Preview teardown evidence:

```text
Production Setup fingerprint before = 86d6fcf3a2505ee9a1448167677a1264
Production Setup fingerprint after  = 86d6fcf3a2505ee9a1448167677a1264
Production fingerprint unchanged    = PASS

Live Setup before = c2a1820627f1a036d634241cc6aecd1a926a1479
Live Setup after  = c2a1820627f1a036d634241cc6aecd1a926a1479
Live checkout unchanged = PASS

Preview log    = /tmp/MSB_Setup_Source_Only_Preview_Flask_20260912T182654.log
Preview report = /tmp/MSB_Setup_Source_Only_Preview_20260912T182654.txt
```

## Production Deployment

The change met the source-only deployment boundary:

- no Setup database migration;
- no environment-file change;
- no systemd-unit change;
- no UFW/proxy/Cloudflare change;
- no mount change; and
- target was a forward descendant of the accepted V0.3.10 live SHA.

The permanent detached Setup checkout was advanced from:

```text
c2a1820627f1a036d634241cc6aecd1a926a1479
```

to the exact browser-accepted candidate:

```text
28ad2d28addd47f8f086ed3b2e53468b453dbe13
```

Only `msb-setup.service` was restarted for activation.

Immediate post-restart health:

```json
{"data_mode":"postgres","status":"ok","version":"V0.3.11-active-task-context"}
```

Production source deployment disposition:

```text
PASS
```

## Post-Deployment Server Gate

Exact deployed source:

```text
LIVE_SHA=28ad2d28addd47f8f086ed3b2e53468b453dbe13
LIVE_CHECKOUT=PASS
```

Service/health:

```text
msb-setup.service = active
LIVE_HEALTH=PASS
V0.3.11-active-task-context
```

The last known Production fingerprint immediately before deployment was the accepted preview after-check fingerprint. The deployment itself preserved it:

```text
PRE_DEPLOY_FINGERPRINT = 86d6fcf3a2505ee9a1448167677a1264
CURRENT_FINGERPRINT    = 86d6fcf3a2505ee9a1448167677a1264
PRODUCTION_FINGERPRINT = PASS
```

Focused live regression from the deployed checkout using the Production Python runtime:

```text
52 passed in 0.26s
LIVE_FOCUSED_REGRESSION=PASS
POST-DEPLOYMENT GATE PASSED
```

## Protected Production Browser Acceptance

The operator then reviewed the real protected route:

```text
https://my.sheboyganlights.org/setup/
```

The Production browser showed the selected task identity persistently in the global sticky header while the underlying detail was scrolled. The operator explicitly reported:

```text
PASS
```

The accepted Production presentation included a header context equivalent to:

```text
ACTIVE TASK  Stage 00 / Stage-level · Setup HWY42 MSB and Rotary Signs
```

This confirmed the actual Production browser/runtime interaction, not only the disposable preview.

## Rollback Boundary

Because #169 is source-only and introduced no database mutation, rollback is application-only:

```text
prior source SHA = c2a1820627f1a036d634241cc6aecd1a926a1479
prior version    = V0.3.10-resource-catalog
```

If rollback were required, the source-only Setup deployment runbook controls: return `/opt/msb-setup` to the prior exact SHA and restart only `msb-setup.service`. No PostgreSQL restore is part of this source-only rollback.

## Final Acceptance

Issue #169 acceptance criteria are satisfied:

- selected reusable task identity remains visible through long detail scrolling;
- switching tasks updates the persistent identity;
- dirty-edit protections remain intact;
- Setup/session/operator context remains readable;
- light/dark/responsive behavior passed review;
- exact candidate passed disposable browser review;
- Production deployment preserved governed data fingerprint;
- 52 focused live tests passed; and
- real protected Production browser acceptance passed.

Production accepted baseline after #169:

```text
Setup V0.3.11-active-task-context
SHA 28ad2d28addd47f8f086ed3b2e53468b453dbe13
```

Issue #169 may be closed after controlled documentation and PR closeout are merged.