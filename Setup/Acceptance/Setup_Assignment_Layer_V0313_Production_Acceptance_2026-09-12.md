# Setup Assignment Layer V0.3.13 Production Acceptance — 2026-09-12

| Document Control | Value |
|---|---|
| System | Production Database — Setup Session |
| Issue | #141 — task-specific Setup material assignment |
| Pull Request | #179 — Complete Setup #141 assignment layer |
| Status | ACCEPTED IN PRODUCTION |
| Production Version | `V0.3.13-assignment-layer` |
| Current Production Source | `3fb975ca355711cece564cfd874cf8d7514310bf` |
| Initial V0.3.13 Database/Application Candidate | `48f0a44ca20296f7d211df240f0af7c324ad44e1` |
| Prior Production Source | `28ad2d28addd47f8f086ed3b2e53468b453dbe13` — V0.3.11 |
| Owner | MSB Production Database engineering |
| Accepted By | Greg Liebig / Setup Administrator |

## Purpose

Record the accepted Production implementation of Issue #141: task-specific Display ownership after the established LOR Stage/Scene resolver, explicit reusable task -> physical Kit Box assignment, and the follow-up source-only large-scope UI correction found during real Candyland use.

This record is the durable closeout evidence for #141. It does not make Pick List generation, Extra Material contents, or 2026 Session scheduling live.

## Accepted Business Boundary

The accepted Production contract is:

```text
LOR Stage / real Scene resolver
    -> current resolved Displays
    -> Setup assignment layer
        -> exactly one effective reusable Setup-task owner per resolved Display
        -> simple one-material-task scopes remain implicit
        -> complex scopes use explicit ownership

Display -> current Container
    -> remains ref.display.container_id
    -> assignment does not rewrite LOR membership or normal Container identity

physical Kit Box container
    -> explicit reusable task KIT relationship
    -> many-to-many
    -> same Kit Box may support multiple reusable tasks
```

The Catalog checkbox **Uses Display / Container Material** remains the task participation selector. When more than one material-bearing reusable task exists in the same applicable Stage/real-Scene scope, **Display Ownership** becomes available so Managers can assign the resolved Displays between those tasks.

Issue #167 remains responsible for Extra Materials, expected KIT contents, source relationships, T-post/spacer quantities/specifications, and later inventory detail. Issue #122 remains responsible for actual Pick List/scheduling launch behavior.

## Database Migrations

The accepted database layer consists of:

```text
028_harden_setup_task_display_ownership.sql
029_correct_setup_assignment_layer.sql
030_fix_setup_kit_box_assignment_upsert.sql
```

Accepted migration blob SHAs:

```text
028  0cfa0ae5348cadb5cb0a12eb3a98026ed2ae804d
029  1a7baf38a222d4e5c15cc3951987299b05001ea2
030  baa1d9ad60ab26f471aa9bacea238d0f03a725b1
```

Migration 030 is the forward correction for the PL/pgSQL `ON CONFLICT` ambiguity in 029 and uses the named primary-key constraint for the Kit Box upsert path. Migration 029 remains part of the historical accepted chain and is not rewritten.

## Pre-Production Validation

The exact accepted V0.3.13 candidate `48f0a44ca20296f7d211df240f0af7c324ad44e1` passed the Setup/Application regression used for the database-affecting assignment-layer candidate:

```text
255 passed
```

Disposable current-Production-clone validation passed. Final disposable browser review accepted:

- compact Catalog Material checkbox behavior;
- first-use subdivision without hidden seed data;
- Magic Igloo Display ownership;
- Ctrl/Cmd-click multi-select;
- Shift-click range selection;
- drag of selected groups between task columns;
- searchable Kit Box picker;
- immediate Kit assignment persistence and re-read;
- assigned Kit names/IDs displayed in Material / Logistics;
- direct assigned-Kit removal;
- many-to-many Kit sharing; and
- no 2026 Setup Session creation.

The operator explicitly accepted this behavior for Production deployment.

## Production Deployment — Assignment Layer

The first V0.3.13 deployment attempt stopped before mutation because the previously recorded governed-data fingerprint was stale. Production had legitimately changed during ongoing Catalog work.

Stopped deployment evidence:

```text
expected fingerprint = 3ef6f726958011e9f5d2ed7603921330
current fingerprint  = 16ffb0f8ae56ea5a7f01984887db8dfa
live SHA remained    = 28ad2d28addd47f8f086ed3b2e53468b453dbe13
report                = /home/msbadmin/setup-deployment-reports/Setup_V0313_Issue141_Production_Deploy_20260913T005536.txt
```

No rollback archive was needed for that stopped attempt because mutation never began.

A fresh disposable acceptance was then run against the current Production state and passed:

```text
SETUP_REUSABLE_DISPOSABLE_ACCEPTANCE_PASS
Production fingerprint before = 16ffb0f8ae56ea5a7f01984887db8dfa
Production fingerprint after  = 16ffb0f8ae56ea5a7f01984887db8dfa
Live Setup before/after        = 28ad2d28addd47f8f086ed3b2e53468b453dbe13
report = /home/msbadmin/setup-acceptance-reports/Setup_Disposable_Acceptance_20260913T005750.txt
```

The controlled Production deployment then completed cleanly:

```text
SETUP_V0313_ISSUE141_PRODUCTION_DEPLOYMENT_PASS
live SHA     = 48f0a44ca20296f7d211df240f0af7c324ad44e1
version      = V0.3.13-assignment-layer
fingerprint  = 16ffb0f8ae56ea5a7f01984887db8dfa unchanged by deployment
rollback dump = /home/msbadmin/backups/setup-141/msb-pre-setup-141-v0313-20260913T010058.dump
deployment report = /home/msbadmin/setup-deployment-reports/Setup_V0313_Issue141_Production_Deploy_20260913T010058.txt
```

## Real Production Use and Large-Scope UI Defect

After deployment, the operator used the assignment layer for real 2025 Catalog cleanup. Candyland proved an unusually large Display-consuming Stage could produce a very tall ownership board.

The underlying ownership writes worked, but the browser had two usability defects:

- native drag did not auto-scroll far enough to reach a distant target task; and
- an abandoned/stuck native drag could leave the dialog interaction unresponsive until the browser was reset.

The dialog also exposed engineering-only wording (`Issue #141`) in the operator UI.

This was treated as a source-only Production follow-up, not a database redesign.

## Source-Only Large-Scope Correction

Current Production source after the correction:

```text
3fb975ca355711cece564cfd874cf8d7514310bf
```

Delta from the database/application baseline `48f0a44...` is source-only:

```text
Setup/Application/production.html
Setup/Application/production_backend.py
Setup/Application/setup_display_ownership_large_scope_fix.js
```

No SQL, migration, environment, systemd, proxy, firewall, mount, or database-contract file changed.

The corrective UI adds:

- **Move selected to** task selection so drag is not the only movement method;
- drag-edge auto-scroll for tall ownership boards;
- drag/dialog state cleanup on close/cancel;
- dialog scroll reset on reopen; and
- operator-facing heading **Display material assignment** instead of an Issue number.

Focused local exact-candidate regression:

```text
18 passed in 0.34s
```

Focused exact-target regression on the Production host before promotion:

```text
18 passed in 0.17s
```

Source-only Production promotion followed the Server Management `Setup_Source_Only_Application_Deployment_Runbook.md`.

Deployment evidence:

```text
old source = 48f0a44ca20296f7d211df240f0af7c324ad44e1
new source = 3fb975ca355711cece564cfd874cf8d7514310bf
health     = V0.3.13-assignment-layer
new UI asset served = PASS
live focused regression = 18 passed in 0.17s
Production fingerprint before = 614c4941e138adfea35a4c39ceee2c63
Production fingerprint after  = 614c4941e138adfea35a4c39ceee2c63
fingerprint unchanged by deployment = PASS
```

The fingerprint differs from the earlier `16ff...` deployment checkpoint because legitimate #141 Production assignments were made during real operator use between those deployments. The source-only promotion itself did not change governed data.

## Protected Production Browser Acceptance

Final real protected-route acceptance passed at:

```text
https://my.sheboyganlights.org/setup/
```

Candyland acceptance confirmed:

- the large Display Ownership workflow opens after browser refresh;
- Tumbling Gingerbread Displays were assigned to their proper task;
- the remaining far-away Display could be assigned without dragging the full board;
- the operator-facing engineering Issue label is removed;
- the dialog can be closed/reopened without retaining the stuck state; and
- the final real Candyland task showed **Coverage complete**.

Operator disposition:

```text
PASS
```

## Rollback Boundaries

### Source-only UI rollback

If the current large-scope UI correction must be reverted without changing the accepted #141 database layer:

```text
return /opt/msb-setup to:
48f0a44ca20296f7d211df240f0af7c324ad44e1

restart only:
msb-setup.service
```

No PostgreSQL restore belongs to this source-only rollback.

### Database/application rollback

The migration-bearing #141 deployment has separate rollback evidence at:

```text
/home/msbadmin/backups/setup-141/msb-pre-setup-141-v0313-20260913T010058.dump
```

Do not restore that archive merely to undo a browser/UI problem. The Production database now contains legitimate operator-entered #141 assignments, so any database rollback would require a new governed decision and reconciliation of post-deployment Production changes.

## Final Accepted Production State

```text
Setup version = V0.3.13-assignment-layer
live source   = 3fb975ca355711cece564cfd874cf8d7514310bf
2025 session  = HISTORICAL_VERIFICATION / sandbox
2026 sessions = 0
#141 assignment layer = accepted
Display ownership = Production operational
physical Kit Box task assignment = Production operational
Extra Material / expected KIT contents / material-source model = #167 next
final reusable Catalog acceptance / disposable 2026 seed proof = #145 after #167
real 2026 Session / Pick List scheduling launch = #122 after #145
```

## Closeout

Issue #141 is complete when this acceptance record, operator documentation, engineering handoff/README, runtime documentation, PR merge evidence, and issue closeout are all current.

The next Setup engineering work in the controlling launch sequence is:

```text
#167 -> #145 FINAL -> #122
```
