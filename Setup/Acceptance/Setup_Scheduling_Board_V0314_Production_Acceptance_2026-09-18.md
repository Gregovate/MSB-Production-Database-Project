# Setup Scheduling Board V0.3.14 Production Acceptance — 2026-09-18

| Document Control | Value |
|---|---|
| Document Type | Production Acceptance Record |
| System | Production Database — Setup Session |
| Issues | #205 / #122 |
| Status | ACCEPTED PRODUCTION |
| Production version | `V0.3.14-scheduling-board` |
| Final live Setup SHA | `8161e91384cb13587fa0c92da2f80f6cf770592d` |
| Database migration | `050_add_setup_scheduling_board_foundation.sql` |

## Accepted Capability

Production now includes the rolling Setup Scheduling Board foundation:

- persisted chronological Setup Day Number with DOW derived from work date;
- dynamic per-work-day crews;
- independent AM/PM planned crew availability;
- optional Crew Captain context;
- Task / Time / minimum Crew / Effort finder;
- selectable `≤` / `≥` Time and minimum-Crew filters;
- readiness state/note separate from hard prerequisites;
- deliberate SHORT CREW confirmation plus persistent warning;
- stable schedule-assignment identity and historical stickiness;
- season-only annual work;
- annual Work Order gates;
- rolling-board history behavior;
- independent finder/board scrolling and drag-edge auto-scroll; and
- responsive narrow-screen behavior.

The accepted application identity is:

```text
8161e91384cb13587fa0c92da2f80f6cf770592d
V0.3.14-scheduling-board
Client V0.3.14
```

## Pre-Production Acceptance

Final exact-target regression:

```text
370 passed in 0.99s
```

Reusable disposable current-Production acceptance:

```text
SETUP_REUSABLE_DISPOSABLE_ACCEPTANCE_PASS
Production Setup fingerprint before/after =
576f3e1f2bc06314ff470deb9dddb149 unchanged
live Setup SHA before/after =
052d31dd4e68e13f2997f723778b88eddf9c53cf unchanged
report =
/home/msbadmin/setup-acceptance-reports/Setup_Disposable_Acceptance_20260918T164805.txt
```

The final disposable browser review confirmed:

- `Client V0.3.14`;
- Scheduling Board loads normally;
- closed Time comparator visibly shows `≤`;
- closed Min crew comparator visibly shows `≤`;
- narrower-window comparator visibility is correct; and
- governed preview cleanup completed cleanly.

## Production Deployment Incident and Recovery

The first Production runner applied migration 050 successfully and passed its database contract validation:

```text
MIGRATION 050: COMMITTED
DATABASE CONTRACT VALIDATION: PASS
```

The runner then stopped on an ad-hoc legacy fingerprint that incorrectly required pre-existing annual-task rows to remain byte-for-byte unchanged even though migration 050 intentionally backfilled new annual snapshot/readiness fields.

The migration UPDATEs fired the standard audit trigger:

```sql
NEW.updated_at := now();
```

All 108 existing `ops.setup_session_task` rows received the same migration-time `updated_at` value. The application checkout had **not** advanced when the runner stopped.

Retained pre-migration evidence:

```text
rollback archive =
/home/msbadmin/backups/setup-205/msb-pre-setup-205-scheduling-board-20260918T170327.dump

failed deployment report =
/home/msbadmin/setup-deployment-reports/Setup_205_Production_Deploy_20260918T170327.txt
```

The remaining application half was completed under the existing Server Management source-only Setup deployment runbook with **no further PostgreSQL mutation**.

Recovery proof:

```text
Pre-resume health:
V0.3.13-assignment-layer

Post-050 / pre-source fingerprint:
4ccf5d7505c7ae58bc95a435742a0c6b

Detached exact-target regression:
370 passed in 0.86s

Post-resume health:
V0.3.14-scheduling-board

Live Setup regression:
370 passed in 0.86s

Fingerprint before source deployment:
4ccf5d7505c7ae58bc95a435742a0c6b

Fingerprint after source deployment:
4ccf5d7505c7ae58bc95a435742a0c6b

SETUP_205_PRODUCTION_RESUME_PASS
Exit status: 0
```

Recovery report:

```text
/home/msbadmin/setup-deployment-reports/Setup_205_Production_Resume_20260918T172933.txt
```

## Protected Production Browser Acceptance

Final protected-route operator validation confirmed:

```text
Client V0.3.14
2025 — HISTORICAL VERIFICATION
2026 — no Setup Session
Setup Scheduling Board visible
≤ comparator controls visible
```

Most importantly, the deployment did **not** create the real 2026 Setup Session.

## Final Catalog Review Meaning

V0.3.14 changes the final #145 review burden.

The launch-critical Catalog review now focuses on:

- whether each reusable task is a real Setup work step;
- whether its Park Infrastructure / Stage / real-Scene scope is correct;
- whether duplicates, obsolete/reconstruction-only, or unnecessarily granular tasks are removed/deactivated; and
- whether hard prerequisites are correct.

Crew guidance, expected Time, Effort, Readiness, Weather, and Completion Point can be corrected from the Scheduling Board before actual work exists.

Readiness conditions are not separate work steps.

Example:

```text
Task: Lay Cords/Network
Readiness: Ensure grass cutting is complete before laying cords.
```

Do not retain or create a synthetic task such as `City Approval to Lay Cords/Network` merely to represent that condition.

## Diagnostics / Reproduction Path

Retain for future Production diagnosis:

- exact deployed Setup SHA;
- migration 050 identity;
- this acceptance record;
- retained pre-050 rollback archive;
- recovery report;
- `GET /api/health`;
- protected `GET /api/setup/scheduling-board?season_year=<year>`;
- `msb-setup.service` status/journal;
- read-only `ops.setup_session_task`;
- read-only `ops.setup_work_day`;
- read-only `ops.setup_work_day_crew`;
- read-only `ops.setup_work_day_task`;
- dependency/progress evidence;
- migration 050;
- disposable #205 validation SQL;
- disposable #205 browser fixture;
- Scheduling Board controlled contract/tests.

No unrestricted debug endpoint is required.

## Deployment Process Follow-Up

Server Management issue #41 is P0 before the next major migration-bearing subsystem deployment.

The existing Runbook-First Production Rule was already explicit. #41 owns **mechanical enforcement** so a feature runner cannot introduce an ad-hoc migration invariant, rollback strategy, or retry procedure outside the approved runbook pattern.

## Final Disposition

```text
#205 Scheduling Board = ACCEPTED PRODUCTION
V0.3.14 = LIVE
migration 050 = installed / validated
2026 Setup Sessions = 0
next launch gate = #145 FINAL reusable-Catalog acceptance + disposable 2026 seed proof
then = #122 real 2026 Setup Session launch
```
