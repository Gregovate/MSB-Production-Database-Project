# Setup Session Shared Review and Season-Year Guard — 2026-09-07

## Purpose

This document defines the safety boundary for the shared Production-backed Setup Session review/training workflow and for future annual Setup planning.

The immediate operating target is the existing **2025 `HISTORICAL_VERIFICATION` Setup Session**. A small group of authenticated reviewers may use the Setup application to improve the reconstructed 2025 record and reusable Setup knowledge before the 2026 Setup Session is created.

This is not a disposable sandbox. Saved changes are Production Database records.

## Core rule: the Setup Session owns the operational year

The selected annual Setup Session is the authority for operator-entered operational dates.

```text
2025 Setup Session
    -> operational dates must be in 2025

2026 Setup Session
    -> operational dates must be in 2026
```

The rule is generic. It is not a hard-coded 2025 exception.

Current guarded operational values are:

- `ops.setup_work_day.work_date`;
- `ops.setup_session_task.planned_date`;
- `ops.setup_session_task.actual_started_at`;
- `ops.setup_session_task.actual_completed_at`; and
- `ops.setup_movement_event.occurred_at` when movement commands are later introduced.

Operational timestamp year checks use `America/Chicago`, consistent with the existing MSB FieldWiring runtime timezone contract.

## Audit timestamps are not historical operational dates

Audit/recording timestamps must continue to show when the database change actually happened.

The season-year rule therefore does **not** rewrite or constrain:

- `created_at`;
- `updated_at`; or
- `ops.setup_task_progress.recorded_at`.

For example, if a Manager records a 2025 historical correction during September 2026:

```text
actual work date/time    -> 2025
recorded/updated time    -> 2026
```

Both facts are useful and should remain truthful.

## Enforcement layers

The year boundary is enforced in two places.

### Database authority

Database triggers reject operational dates/timestamps that do not match the associated `ops.setup_session.season_year`.

This prevents a bad year from being written even if a browser check is bypassed or another approved application later calls the same command layer.

The governed work-day and historical-review commands also perform explicit year validation so the operator receives a clear error instead of relying only on a trigger failure.

### Browser guidance

The Setup browser limits date and date-time controls to January 1 through December 31 of the currently selected Setup Session year.

For a historical-verification session it also presents a visible banner explaining that:

- saved changes are permanent records for that historical session;
- operational dates are limited to that session year;
- the historical review does not create or schedule a future Setup Session; and
- future-baseline promotion is Administrator-only.

The browser boundary improves usability, but the database remains the authority.

## Shared 2025 review is Production-backed, not disposable

The shared 2025 review is intentionally useful as both reconstruction work and Manager training.

Authorized reviewers may improve:

- 2025 annual verification state;
- 2025 annual crew/time/date evidence where known;
- 2025 annual notes;
- 2025 annual planned order and work-day assignments if useful for reconstruction/training;
- reusable task scope;
- reusable prerequisites;
- normal crew/time expectations;
- reusable equipment/resource relationships; and
- reusable Procedure organization.

The distinction between annual and reusable data remains important:

- **annual 2025 edits** describe the 2025 occurrence;
- **reusable task edits** are permanent Setup knowledge and may be inherited by later seasons.

A reviewer must therefore not treat the 2025 shared application as throwaway test data.

## Future-season authority boundary

Two actions can affect future annual planning and are reserved for Setup Administrators:

1. create/manage the annual Setup Session; and
2. promote a current annual planned order into the reusable future baseline.

Managers/reviewers may reorder the active annual session because that is normal annual planning/reconstruction work. They cannot use that order to redefine the future baseline.

This prevents a one-year anomaly, training experiment, or 2025 reconstruction choice from silently becoming the starting order for 2026 or later.

## 2026 transition

There is currently no 2026 Setup Session in the accepted Production baseline.

When an Administrator explicitly creates the 2026 Setup Session:

- the application selects the 2026 annual context;
- browser operational date bounds become `2026-01-01` through `2026-12-31`;
- database year guards require 2026 for operational dates/timestamps attached to that session; and
- the 2025 historical record remains separate and unchanged except through explicit 2025 review actions.

Creating 2026 does not require changing the season-year guard implementation.

## Access and sharing

A URL does not grant Setup write authority.

Shared review must remain behind the existing authenticated application boundary. A person who receives the link must still resolve through the existing Cloudflare/Directus Setup capability model.

Current authority direction:

- **Reader / field user** — view permitted Setup information;
- **Manager / reviewer** — maintain the active annual review/planning data and reusable Setup knowledge within Manager commands;
- **Administrator** — Manager capabilities plus annual Setup Session creation and future-baseline promotion.

Do not expose generic table DML merely to make shared review easier.

## Current execution boundary

This shared review does not expand movement/scanning authority.

The Captain/Perform Work screen may show current material/location context, but narrow movement/scanning write commands remain a separate guarded implementation step.

The Production-backed 2025 review therefore does not create movement semantics merely from scans or from review activity.

## Related implementation

- `Setup/Database/017_enforce_setup_session_year_and_admin_promotion.sql`
- `Setup/Application/setup_session_year_guard.js`
- `Setup/Application/setup_session_year_guard.css`
- `Setup/Application/setup_next_api.py`
- `Setup/Application/test_setup_session_year_guard_contract.py`
- `Setup/Acceptance/setup_v03_production_preflight.sql`

## Related operator documentation

See:

`Docs/02_Production_Database/02_Operational_SOPs/Setup/Setup_Session_Manager_Review_Guide.md`
