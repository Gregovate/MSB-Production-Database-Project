# Setup V0.3.4 Controlled Production Install Plan

## Purpose

This file freezes the intended Production promotion set for the shared 2025 historical review/training workflow.

It is an engineering install plan, not an operator procedure.

## Production baseline before promotion

Production must first pass:

`Setup/Acceptance/setup_v03_production_preflight.sql`

Expected final marker:

```text
READY_FOR_CONTROLLED_V034_PROMOTION
```

The preflight requires:

- exactly one 2025 `HISTORICAL_VERIFICATION` Setup Session;
- no 2026 Setup Session;
- no partial post-007 Setup install;
- required Stage/Scene/resource authority; and
- existing operational dates compatible with the session-year guard.

## Durable migration/install sequence

Apply, in order:

1. `008_create_setup_resource_management_commands.sql`
2. `009_create_setup_scope_schedule_execution_commands.sql`
3. `010_seed_2025_stage02_elf_scope_corrections.sql`
4. `011_create_setup_planning_order_and_crew_lanes.sql`
5. **skip `012_seed_site_infrastructure_review_tasks.sql`**
6. `013_fix_setup_task_creation_command.sql`
7. `014_grant_setup_scene_field_context_read.sql`
8. `015_harden_setup_command_conflict_targets.sql`
9. `016_seed_command_center_park_infrastructure_production.sql`
10. `017_enforce_setup_session_year_and_admin_promotion.sql`

`012` is intentionally excluded because it contains disposable browser-review execution resets. `016` is its Production-safe durable replacement for confirmed Command Center/Park Infrastructure reconstruction.

## Data effects permitted by this promotion

Permitted durable effects include:

- reusable task/resource/scope/planning command support;
- confirmed Stage 02/Fred's Stars/Elf Choir 2025 reconstruction;
- confirmed Stage 40 Command Center and Park Infrastructure reusable tasks;
- corresponding 2025 UNVERIFIED historical-review annual rows;
- annual planned-order and rolling work-day/shift/crew-lane structure;
- Scene-derived material/location read support;
- command conflict-target hardening;
- session-year operational-date enforcement; and
- Administrator-only future-baseline promotion.

## Effects explicitly prohibited

This promotion must not:

- create a 2026 Setup Session;
- create fake/example work days or crew-lane schedule rows;
- reset historical 2025 execution state merely for browser testing;
- create preview-probe reusable tasks;
- install movement/scanning write commands;
- replace the current live FieldWiring/Procedure checkout; or
- expose broad table DML to `fieldwiring_app`.

## Application review boundary

After database promotion, run the Setup V0.3.4 candidate application as an isolated Production-backed review service before replacing any current shared application route.

Reviewers must authenticate through the existing access model. A shared link alone does not grant write authority.
