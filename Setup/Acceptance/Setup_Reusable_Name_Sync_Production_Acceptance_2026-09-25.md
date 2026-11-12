# Setup #122 Reusable Task Name Synchronization — Production Acceptance — 2026-09-25

| Document Control | Value |
|---|---|
| System | Production Database — Setup |
| Issue | #122 |
| Feature PR | #247 |
| Deployment tooling PRs | #248, #249 |
| Status | ACCEPTED PRODUCTION |
| Accepted candidate SHA | `dd4c80fe3180df8f99cb88be451c803d60b5774f` |
| Feature merge commit | `0462d9318eb97e04c238c5e5b8815ec2f266bfe0` |
| Migration | `Setup/Database/059_sync_reusable_task_name_to_open_annual.sql` |
| Migration Git blob | `1be0837c88c243fd54763817983be23fa10853bd` |
| Live Setup application SHA | `55e097e7bb3b807793893defc939c9a23fc4ec5d` |
| Live Setup version | `V0.3.18-scheduling-board` |

## Accepted Behavior

Reusable Setup task identity remains stable across renames, and the current annual Setup Session now keeps the same operator-facing task name as the reusable Catalog.

The current Setup season for reusable-name synchronization is the newest non-`HISTORICAL_VERIFICATION` Setup Session. That annual Session remains the synchronization target until a later annual Setup Session is actually created.

For the 2026 -> 2027 transition:

```text
no 2027 Setup Session exists
    -> 2026 remains the current Setup season
    -> reusable renames continue synchronizing into 2026

2027 Setup Session is created
    -> 2027 becomes the current Setup season
    -> 2026 annual names freeze as prior-year history
```

`ref.season` remains the annual operational season reference, but changing its active flag alone does not freeze the prior Setup annual occurrence.

Season-only annual tasks retain their independent annual task names.

## Defect Proven in Production

Before migration 059:

- reusable Task 74 = `Move Volunteer Trailer`;
- 2026 annual Task 74 = `Move Volunteer Trailer and Setup Volunteer Steps`;
- reusable/annual Task 376 = `Move Volunteer Steps`.

The task IDs were correct. The defect was stale annual naming after a reusable Catalog correction.

## Disposable Acceptance

Exact candidate:

```text
dd4c80fe3180df8f99cb88be451c803d60b5774f
```

Reusable disposable acceptance passed:

```text
SETUP_REUSABLE_DISPOSABLE_ACCEPTANCE_PASS
SETUP REUSABLE DISPOSABLE ACCEPTANCE: CLEAN EXIT
Exit status: 0
```

Production remained unchanged during disposable acceptance:

```text
Production Setup fingerprint before: 5b32a041912a710dfc553eed814e9232
Production Setup fingerprint after:  5b32a041912a710dfc553eed814e9232
live Setup SHA before: 55e097e7bb3b807793893defc939c9a23fc4ec5d
live Setup SHA after:  55e097e7bb3b807793893defc939c9a23fc4ec5d
```

Report:

```text
/home/msbadmin/setup-acceptance-reports/Setup_Disposable_Acceptance_20260926T002851.txt
```

## Disposable Browser Acceptance

The exact candidate was exercised against a disposable current-Production clone.

Operator visual acceptance confirmed:

- Task 74 displayed `Move Volunteer Trailer`;
- Task 376 displayed `Move Volunteer Steps`;
- the stale combined Task 74 name was absent.

The browser wrapper then returned:

```text
SETUP REUSABLE DISPOSABLE BROWSER PREVIEW: CLEAN EXIT
```

## First Production Attempt — Rejected and Rolled Back

The first Production migration attempt correctly failed closed after migration 059 committed.

Root cause was in the deployment runner, not migration 059. The runner allowed only `annual_task_name` to change, but the accepted shared audit trigger on `ops.setup_session_task` also correctly updates:

- `updated_at`;
- `updated_by`;
- `updated_by_person_id`.

The runner therefore stopped at exit 20.

Fail-closed recovery succeeded:

```text
Migration 059 narrow rollback: PASS
live Setup SHA before/after:
55e097e7bb3b807793893defc939c9a23fc4ec5d
```

Rollback archive:

```text
/home/msbadmin/backups/setup-122-name-sync/msb-pre-setup-122-name-sync-20260926T004851.dump
SHA256:
c2a80dfb5d1b32853cbe9e5da729d31d839860e81180016d8635a8b9366f466b
```

Deployment report:

```text
/home/msbadmin/setup-deployment-reports/Setup_122_Reusable_Name_Sync_Production_Deploy_20260926T004851.txt
```

The runner was corrected in PR #249 to preserve the already-accepted audit attribution contract rather than suppressing audit metadata changes.

## Audit Attribution Contract

For ordinary Manager reusable-task renames, the governed reusable-task command establishes the authenticated Manager actor before updating `ref.setup_task`. Migration 059's synchronization trigger updates the current annual occurrence inside that transaction, and the shared `ref.set_actor_on_update()` trigger stamps the same authenticated actor on the annual row.

For the one-time Production backfill, the corrected deployment runner explicitly established the governed deployment operator identity before applying migration 059 and verified the changed annual rows received the expected person attribution.

The final accepted deployment therefore preserved the shared audit repair rather than creating a database/service actor exception.

## Final Production Deployment

Final deployment result:

```text
SETUP_122_REUSABLE_NAME_SYNC_PRODUCTION_DEPLOYMENT_PASS
SETUP #122 REUSABLE NAME SYNC PRODUCTION DEPLOYMENT WRAPPER: PASS
Exit status: 0
```

Final Production invariants:

```text
Final live Setup SHA:       55e097e7bb3b807793893defc939c9a23fc4ec5d
Final name mismatch count:  0
Final allowed fingerprint:  9fefc5a6540588266002af2464ea2b07
```

The Setup application source did not move. Migration 059 was the only accepted Production behavior change.

Final rollback archive:

```text
/home/msbadmin/backups/setup-122-name-sync/msb-pre-setup-122-name-sync-20260926T005732.dump
SHA256:
c1d5e0aa8226f80c910528cc3c6c0ab2a32f61ccaa861f145b351d009f0f08ae
```

Final deployment report:

```text
/home/msbadmin/setup-deployment-reports/Setup_122_Reusable_Name_Sync_Production_Deploy_20260926T005732.txt
```

## Production Result

Production now has zero reusable-name mismatches in the current annual Setup Session.

The live application remains:

```text
SHA:     55e097e7bb3b807793893defc939c9a23fc4ec5d
version: V0.3.18-scheduling-board
```

Future reusable task renames remain synchronized into the current annual Setup Session until the next annual Setup Session is created.

## Related Authority

- Issue #122 — commanding Setup workflow authority.
- PR #247 — accepted reusable-name synchronization behavior.
- PR #248 — initial bounded Production runner.
- PR #249 — audit-aware Production runner correction.
- `Docs/02_Production_Database/01_System_Architecture/12_Setup_and_Deployment/engineering/Setup_Scheduling_Board_Contract_2026-09-17.md`.
- `Gregovate/MSB-Server-Management/docs/server/Production_Database_Change_Deployment_Runbook.md`.
