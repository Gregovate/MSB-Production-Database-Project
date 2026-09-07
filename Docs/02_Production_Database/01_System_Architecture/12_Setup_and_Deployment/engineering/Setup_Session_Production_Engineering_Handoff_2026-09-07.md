# Setup Session Production Engineering Handoff — 2026-09-07

| Document Control | Value |
|---|---|
| Document Type | Engineering Handoff |
| System | Production Database — Setup Session |
| Status | CURRENT HANDOFF — database accepted, protected application deployment in progress |
| Owner | MSB Production Database engineering |
| Last Reviewed | 2026-09-07 |

## Purpose

Preserve the accepted Setup Session V0.3.4 Production database state, intended 2025 historical-review operating model, security boundaries, runtime dependencies, rollback evidence, and exact resume point so subsequent work does not depend on chat history.

## Operating Model

The real 2025 Production-backed Setup Session is the shared historical reconstruction and training area.

Authorized reviewers use it to:

- reconstruct and correct 2025 annual Setup facts;
- learn the Setup application using real data;
- improve reusable Setup task knowledge where the corrected rule should carry forward; and
- establish a clean reusable baseline before an Administrator creates the 2026 Setup Session.

The selected Setup Session controls the allowable operational year:

```text
2025 session -> 2025 operational dates/timestamps only
2026 session -> 2026 operational dates/timestamps only
```

Audit/recording timestamps remain current truthful timestamps.

## Production Database Promotion

Exact source used for the controlled promotion:

```text
branch = agent/setup-session-production-foundation
SHA    = 2b94e0ecb21fde88ce20acc24855fc1c84d21eb6
PR     = #125
```

Read-only Production preflight passed with:

```text
READY_FOR_CONTROLLED_V034_PROMOTION
```

Approved durable migration sequence applied in order:

```text
008_create_setup_resource_management_commands.sql
009_create_setup_scope_schedule_execution_commands.sql
010_seed_2025_stage02_elf_scope_corrections.sql
011_create_setup_planning_order_and_crew_lanes.sql
013_fix_setup_task_creation_command.sql
014_grant_setup_scene_field_context_read.sql
015_harden_setup_command_conflict_targets.sql
016_seed_command_center_park_infrastructure_production.sql
017_enforce_setup_session_year_and_admin_promotion.sql
```

`012_seed_site_infrastructure_review_tasks.sql` was intentionally excluded because it contains disposable browser-review reset/seed behavior.

## Production Validation

Migration-level acceptance included:

```text
008: narrow resource commands present; broad task-resource UPDATE denied
009: scope/schedule/execution layer committed successfully
010: 2025 annual tasks increased to 50; all remained UNVERIFIED
011: planning-order / crew-lane revision marker applied
013: create-task conflict-target fix applied
014: Scene/display read enabled; broad Display/Container UPDATE denied
015: resource/dependency/scheduling conflict targets hardened
016: seven Command Center / Park Infrastructure tasks created as UNVERIFIED / COMPLETE 2025 rows
017: work-day, annual-task, and movement year guards present; future-baseline promotion requires Administrator
```

Final read-only Production state:

```text
setup_session_id          = 1
season_year               = 2025
session_status            = HISTORICAL_VERIFICATION
annual_tasks              = 57
unverified_tasks          = 57
sessions_2026             = 0
work_days                 = 0
movement_events           = 0
active_reusable_tasks     = 57
```

## Rollback Evidence

Pre-promotion PostgreSQL custom-format dump:

```text
/home/msbadmin/backups/setup-v034/msb_pre_setup_v034_20260907T202706Z.dump
```

SHA256:

```text
e09bd97010b464fe307a9fbe0192c9ca4189fd562215f4eaa93e02a2d08f89a5
```

`pg_restore -l` successfully read the archive and reported the expected `msb` database catalog.

Do not delete this archive during normal Setup application deployment cleanup.

## Authorization Boundary

The protected Setup API uses:

```text
Cloudflare Access authenticated email
  -> Directus/ref.person capability lookup
  -> server-side Setup role enforcement
  -> narrow PostgreSQL SECURITY DEFINER command
```

A shared link alone does not grant write authority.

Managers/reviewers may work on the 2025 annual session and reusable Setup knowledge according to capability. Only Administrators may:

- create annual Setup Sessions; and
- promote an annual plan order to the reusable future baseline.

`fieldwiring_app` must not receive broad table DML merely to support browser actions.

## Year Guard Boundary

Migration 017 enforces the selected Setup Session year at both the command and table level for:

```text
ops.setup_work_day.work_date
ops.setup_session_task.planned_date
ops.setup_session_task.actual_started_at
ops.setup_session_task.actual_completed_at
ops.setup_movement_event.occurred_at
```

`timestamptz` operational-year checks use `America/Chicago`.

Audit timestamps such as `created_at`, `updated_at`, and progress-recording timestamps are intentionally not season-limited.

## 2025 Annual vs Reusable Knowledge

This distinction is part of the application contract:

```text
annual 2025 change
    = 2025 historical fact/state

Reusable Task change
    = permanent Setup knowledge that may carry forward
```

Reviewers must not encode a one-off 2025 condition into reusable knowledge merely to make the historical record fit.

## Application Source Boundary

Protected Production entry point:

```text
Setup/Application/production_backend.py
```

Expected version:

```text
V0.3.4-shared-season-guard-review
```

Protected Setup APIs require `Cf-Access-Authenticated-User-Email`. Write commands additionally require the same-origin application command shape including:

```text
X-MSB-Setup-Command: 1
Content-Type: application/json
```

The application consumes an explicit Setup PostgreSQL DSN and shared Display Folders root. It reuses the accepted shared Field Context / Procedure resolver rather than creating another Stage/Sub-stage/Scene resolver.

## Runtime / Filesystem Dependency

Server/runtime authority is `Gregovate/MSB-Server-Management`.

Critical dependency:

```text
service account          = fieldwiring
supplementary group      = msb-docs-read
Display Folders mount    = /mnt/msb-display-folders (read-only)
```

`msbadmin` does not have the same `msb-docs-read` traversal rights. Direct filesystem acceptance under `/mnt/msb-display-folders` must run under the `fieldwiring` runtime account.

This is an established Production failure class from the rejected first Setup resolver acceptance on 2026-08-28 and must not be rediscovered as a new application defect.

## Protected Route Target

Permanent intended application route:

```text
https://my.sheboyganlights.org/setup/
```

Expected runtime shape:

```text
Cloudflare Access
  -> Synology protected nginx path-prefix proxy
  -> msb-setup.service
  -> 192.168.5.9:8794
  -> production_backend.py
```

The existing `fieldwiring.service` on 8790 and `msb-procedures.service` on 8792 remain separate accepted services.

## Old Preview Identified

Live inspection before permanent service deployment found:

```text
listener = 127.0.0.1:8794
PID      = 3258879
user     = fieldwiring
command  = /opt/fieldwiring/.venv/bin/python /tmp/msb-setup-browser-preview-20260907-135435/setup_session_browser_preview_entry.py
cwd      = /tmp
```

This is the disposable Setup browser preview, not a documented Production service. It must be cleaned up before the permanent Setup service claims port 8794.

A separate `/proc/<pid>/environ` inspection attempt failed because shell input redirection was opened as `msbadmin` before the sudo target process ran. No protected environment values are required for this deployment decision.

## Documentation / Intranet Boundary

The Setup subsystem is being converted to the Production documentation structure:

```text
12_Setup_and_Deployment/
├── README.md
├── operatorSOP/
│   ├── README.md
│   └── Review_2025_Setup_History.md
└── engineering/
    ├── README.md
    ├── Internal_Web_Backbone_Handoff.md
    └── Setup_Session_Production_Engineering_Handoff_2026-09-07.md
```

Existing dated engineering evidence at the parent level is not being mass-moved during this deployment because of inbound-link and historical-reference risk. The engineering portal links to current supporting authorities.

`Gregovate/MSB-Internal-Web-Backbone` should consume the source-subsystem handoff rather than scraping engineering history into normal operator navigation.

## PR / Merge State

PR #125 has been updated to reflect the actual Production database promotion and the remaining application/service/public-route gate. It must not be merged until live `/setup/` acceptance and final documentation closeout pass.

The current Setup work is stacked across draft PRs #123, #124, and #125. Before final merge, normalize the stack so the accepted documentation, prototype lineage, production implementation, and deployment evidence land on `main` without losing history or leaving competing current authorities.

## Resume Point

```text
Database V0.3.4 promotion       = ACCEPTED
2025 historical session         = 57 / 57 UNVERIFIED
2026 session                    = absent
work days / movement events     = 0 / 0
rollback archive                = validated and retained
old preview on 8794             = positively identified
permanent Setup service         = not installed
public /setup/ route            = not installed
```

Next engineering action is Server Management controlled cleanup/install of the permanent Setup runtime, followed by direct/public acceptance and documentation finalization.

## Related Documents

- [Setup engineering portal](README.md)
- [Setup operator procedures](../operatorSOP/README.md)
- [Internal Web Backbone handoff](Internal_Web_Backbone_Handoff.md)
