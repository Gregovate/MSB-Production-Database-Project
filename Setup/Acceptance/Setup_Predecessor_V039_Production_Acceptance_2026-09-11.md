# Setup Prerequisite Editing V0.3.9 — Production Acceptance — 2026-09-11

| Document Control | Value |
|---|---|
| Document Type | Production Acceptance Record |
| System | Production Database — Setup Session |
| Status | ACCEPTED PRODUCTION |
| Owner | MSB Production Database engineering |
| Issue | #151 — Shift+left-drag predecessor creation |
| Implementation PR | #164 |
| PR merge commit | `ebade21e15a9ac62728dca0655476a619b47516d` |
| Accepted application/schema/test candidate | `55478f98f760473b65b5d700a84c868285022ab7` |
| Accepted version | `V0.3.9-predecessor-drag` |
| Prior accepted runtime | `2eee967b6c5359c0e2e2d876a2fe44af8359315c` / `V0.3.8-task-detail-compact` |
| Production migration | `Setup/Database/026_add_setup_dependency_order.sql` |

## Purpose

Preserve the final Production acceptance evidence for Issue #151 so the accepted prerequisite interaction, persistent review order, migration boundary, deployment evidence, rollback point, browser-review failure lesson, and final operator disposition do not depend on chat or issue comments.

## Accepted Operator Behavior

The reusable Setup task Catalog now supports two prerequisite-entry paths.

### Shift-drag fast entry

To make task A depend on task B:

```text
hold Shift before left-button-down on dependent task A
    -> drag A onto prerequisite task B
    -> release
    -> A depends on B
```

Accepted behavior:

- neither task moves during the Shift-drag gesture;
- the target visibly indicates that it will become the prerequisite;
- success feedback names the dependency direction;
- multiple prerequisites can be added to one dependent task;
- repeating an existing dependency remains idempotent and does not create duplicate state;
- circular dependencies fail closed through the governed database command; and
- releasing over empty Stage/Scene space cancels the prerequisite gesture without moving the task.

Ordinary drag without Shift remains the normal reusable Catalog movement/reorder/scope interaction, including legitimate movement between Stage-level / General and real Scene locations.

### Canonical prerequisite editor

Task detail now contains one canonical prerequisite list. Each current prerequisite appears once with:

- position;
- **Up**;
- **Down**; and
- **Remove**.

A separate **Add prerequisite** form remains available as the manual/fallback entry method.

After add/remove/reorder, the application reloads authoritative dependency state so task detail and the Catalog **Requires** line agree immediately. A prerequisite already assigned to the task is no longer offered by the Add dropdown.

Prerequisite Up/Down order is review/display order only. It does not create prerequisite-to-prerequisite dependency semantics. Every listed prerequisite remains independently required.

## Database Migration 026

Migration:

```text
Setup/Database/026_add_setup_dependency_order.sql
```

Accepted candidate blob:

```text
759774d80eb51b706a0e7b71c5e834636b64a451
```

The migration adds:

- `ref.setup_task_dependency.sort_order integer NOT NULL DEFAULT 100`;
- `ck_setup_task_dependency_sort_order`;
- `ix_setup_task_dependency_order`;
- updated governed `ref.set_setup_task_dependency(...)` append-order behavior; and
- governed `ref.reorder_setup_task_dependencies(text,bigint,bigint[])`.

`fieldwiring_app` receives EXECUTE on the narrow governed command and retains no broad `INSERT`, `UPDATE`, or `DELETE` privilege on `ref.setup_task_dependency`.

Existing dependency rows received the constant schema default without a mass UPDATE. Their legacy audit fields were required to remain unchanged.

## Disposable Browser Acceptance

Exact accepted candidate:

```text
55478f98f760473b65b5d700a84c868285022ab7
V0.3.9-predecessor-drag
```

Final disposable browser evidence:

```text
preview report = /tmp/MSB_Setup_Source_Only_Preview_20260911T065847.txt
preview log    = /tmp/MSB_Setup_Source_Only_Preview_Flask_20260911T065847.log
```

Operator acceptance confirmed:

- Shift-drag direction `dependent -> prerequisite`;
- neither task moves;
- multiple prerequisites stack correctly;
- repeated dependency remains single/idempotent;
- circular dependency is rejected;
- one canonical prerequisite list only;
- Up/Down persistent display ordering is reflected identically in detail and Catalog;
- Remove synchronizes both views and persists after reopen;
- manual Add appends once and removes the assigned task from the available dropdown;
- Shift-release over empty Stage/Scene space cancels without moving the task; and
- ordinary drag, including movement to another valid Stage/Scene, remains functional.

Final preview cleanup proved Production remained unchanged:

```text
Production fingerprint before = 9510360aa7de2da59d1ed8a9ad9d69f7
Production fingerprint after  = 9510360aa7de2da59d1ed8a9ad9d69f7
live Setup before             = 2eee967b6c5359c0e2e2d876a2fe44af8359315c
live Setup after              = 2eee967b6c5359c0e2e2d876a2fe44af8359315c
```

## Browser Preview Lifecycle Failure / Recovery Finding

During the final review pass, the original workstation SSH tunnel disappeared while the remote source-only preview wrapper remained blocked on its browser-review prompt. The detached `fieldwiring` Flask process therefore survived and continued listening on preview port 8795.

Evidence showed the application itself had not crashed at the last prerequisite mutation: the final dependency request logged HTTP 200 and the following refresh requests also logged 200. A direct server health request still returned:

```json
{"data_mode":"postgres","status":"ok","version":"V0.3.9-predecessor-drag"}
```

The failure was the preview/tunnel lifecycle, not the prerequisite Add operation.

Acceptance tooling was hardened before final review to:

- recognize the source-only preview resource naming/runtime boundary;
- refuse governed Production ports;
- clean only the identified stale preview resources;
- preserve acceptance reports/logs;
- use SSH keepalives;
- include HUP in preview cleanup handling; and
- use `timeout --foreground` when bounding the interactive remote preview so `sudo` and the final review prompt retain the controlling PTY.

A first non-foreground `timeout` attempt was rejected after it stopped the remote shell at its terminal-sensitive `sudo -v` step. The corrected foreground-safe launcher then completed final browser acceptance normally.

## Production Pre-Mutation Gate

Immediately before mutation:

```text
live Setup SHA          = 2eee967b6c5359c0e2e2d876a2fe44af8359315c
live health             = V0.3.8-task-detail-compact
accepted target         = 55478f98f760473b65b5d700a84c868285022ab7
forward ancestry        = PASS
migration 026 blob      = 759774d80eb51b706a0e7b71c5e834636b64a451
Production fingerprint  = 9510360aa7de2da59d1ed8a9ad9d69f7
sort_order already live = NO
reorder function live   = NO
broad dependency DML    = NO
fieldwiring_app read-only default = ON
```

The exact candidate full Setup application suite produced:

```text
191 passed
2 failed
```

The same two failures were then reproduced against the already accepted V0.3.8 Production checkout:

```text
2 failed
6 passed
```

The failures are inherited stale literal-string contracts, not V0.3.9 regressions:

- `test_setup_internal_analytics_contract.py` expected `Updated 2026-09-10` while accepted source displays `Updated 2026-09-11`;
- `test_setup_shared_review_contract.py` expected the literal phrase `must be in 2025` while the current operator authority says the 2025 session accepts 2025 operational dates only.

The current focused V0.3.9 deployment suite passed:

```text
63 passed in 0.27s
```

Closeout corrects those stale test literals; this acceptance record does not falsely claim that the pre-deployment full suite was green.

## Rollback Archive

Before migration 026, a custom-format Production PostgreSQL archive was created and validated:

```text
/home/msbadmin/backups/setup-151/msb-pre-setup-151-20260911T071801.dump
```

SHA256:

```text
21e5b9b0fbd07dd01b7c9a86027615988bc33f950767839e4d74bb4a1f407029
```

The pre-migration dependency baseline was:

```text
dependency rows               = 17
dependency legacy fingerprint = 26b170fba3500ea2647967e87aa02a1c
```

## Production Migration Acceptance

Migration 026 applied successfully.

Post-migration validation:

```text
sort_order NOT NULL/default   = PASS / 100
reorder command present       = PASS
reorder EXECUTE               = PASS
dependency command EXECUTE    = PASS
broad INSERT/UPDATE/DELETE    = f / f / f
dependency rows               = 17
min/max initial sort_order    = 100 / 100
dependency legacy fingerprint = 26b170fba3500ea2647967e87aa02a1c
Production governed fingerprint = 9510360aa7de2da59d1ed8a9ad9d69f7
```

The unchanged legacy dependency fingerprint proves migration 026 did not rewrite the existing dependency-note/audit evidence while adding presentation order.

## Production Application Deployment

The dedicated Setup Production checkout advanced from:

```text
2eee967b6c5359c0e2e2d876a2fe44af8359315c
V0.3.8-task-detail-compact
```

to the exact browser-accepted candidate:

```text
55478f98f760473b65b5d700a84c868285022ab7
V0.3.9-predecessor-drag
```

Only `msb-setup.service` was restarted for the application promotion.

Post-restart evidence:

```json
{"data_mode":"postgres","status":"ok","version":"V0.3.9-predecessor-drag"}
```

Live focused regression:

```text
63 passed in 0.27s
```

Direct unauthenticated protected-path negative check:

```text
HTTP 401 = PASS
```

Final governed fingerprint before any operator acceptance write:

```text
9510360aa7de2da59d1ed8a9ad9d69f7
```

## Final Protected Production Browser Acceptance

The real protected Production application was opened at:

```text
https://my.sheboyganlights.org/setup/
```

Final operator validation confirmed:

- visible `Client V0.3.9`;
- Shift-drag creates the intended real prerequisite and does not move either task;
- Catalog **Requires** updates correctly;
- task detail shows one canonical prerequisite list;
- the dependency appears once;
- Up/Down/Remove controls are present;
- the already-assigned prerequisite is absent from the manual Add choices; and
- ordinary non-Shift movement remains functional.

Production browser acceptance: **PASS**.

## Current Boundary / Known Limitations

Issue #151 does not implement structured external/site readiness. The existing distinction remains:

```text
hard predecessor != preferred order != readiness condition
```

Prerequisite display order does not create additional dependency semantics.

No 2026 Setup Session was created by this work. Issue #145 remains the cleanup gate before 2026 annual-session creation.

Task-specific staged material / Pick List release timing remains separate work in Issue #141. Resource editing/sort work remains separate from #151.

## Closeout State

Issue #151 is eligible for completed closeout after:

- operator instructions are updated;
- current engineering portal/handoff/contract are updated;
- Server Management runtime and preview-runbook authority are updated;
- stale inherited test literals are corrected;
- documentation PRs are merged; and
- local feature/closeout branches are cleaned after verifying `main`.

## Related Authority

- `Docs/02_Production_Database/01_System_Architecture/12_Setup_and_Deployment/engineering/Setup_Predecessor_and_Readiness_Contract_2026-09-09.md`
- `Docs/02_Production_Database/01_System_Architecture/12_Setup_and_Deployment/engineering/Setup_Session_Production_Engineering_Handoff_2026-09-11.md`
- `Docs/02_Production_Database/02_Operational_SOPs/Setup/Setup_Session_Manager_Review_Guide.md`
- `Docs/02_Production_Database/01_System_Architecture/12_Setup_and_Deployment/operatorSOP/Review_2025_Setup_History.md`
- `Gregovate/MSB-Server-Management/docs/server/Production_Database_Change_Deployment_Runbook.md`
- `Gregovate/MSB-Server-Management/docs/server/Pre_Production_Browser_Review_Runbook.md`
