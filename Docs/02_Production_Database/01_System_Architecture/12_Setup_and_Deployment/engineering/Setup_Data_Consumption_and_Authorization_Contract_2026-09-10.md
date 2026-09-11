# Setup Data Consumption and Authorization Contract — 2026-09-10

| Document Control | Value |
|---|---|
| Document Type | Engineering Contract / Production Troubleshooting Reference |
| System | Production Database — Setup and Deployment |
| Status | CURRENT |
| Owner | MSB Production Database engineering; People and Identity owns durable person/authentication linkage |
| Last Reviewed | 2026-09-11 |

## Purpose

Define the current Production Setup application's database-consumption surface, human authorization model, PostgreSQL application-role boundary, actor-attribution requirement, and the troubleshooting distinction between authorization, person identity, and database grants.

## Three Separate Layers

Do not treat these as the same problem:

```text
1. Browser authentication
   Cloudflare Access supplies authenticated email.

2. Human Setup capability
   active Directus user + role/policy
   -> ref.setup_browser_capabilities(email)

3. Human write attribution
   Directus user UUID
   -> ref.person.directus_user_id
   -> transaction-local app.directus_user_uuid
   -> governed SECURITY DEFINER command
   -> actor/audit trigger
```

A user can therefore have Manager capability and still fail to save when the Directus UUID is not mapped to an MSB Person.

The characteristic error is:

```text
Authenticated Setup operator is not mapped to an MSB person
```

That is a People/Identity mapping failure, not evidence that broad Setup table permissions should be granted.

## Human Capability Model

`ref.setup_browser_capabilities(text)` is the Setup capability authority consumed by the protected application.

Current intent:

| Authority | Read Setup | Maintain reusable/annual Setup | Create annual Setup Session | Promote annual order to reusable baseline |
|---|---:|---:|---:|---:|
| Production Crew / accepted field user | Yes | No | No | No |
| Manager | Yes | Yes | No | No |
| Administrator | Yes | Yes | Yes | Yes |

Captain/Alternate execution authority is a separate governed exception for task progress. `ADVISOR` alone does not grant progress-write authority.

## Actor Identity Requirement

Manager/Admin commands resolve through `ref.setup_management_actor(...)`. Captain/Alternate progress commands resolve through the governed execution actor path.

The durable identity requirement is:

```text
public.directus_users.id
    = ref.person.directus_user_id
```

Exact-email matching is evidence used for governed reconciliation; names must not be guessed.

A 2026-09-10 Production incident proved that repeat Directus/Google login is not a general repair mechanism for already-established Manager accounts whose Person link is null. The immediate affected Manager links were repaired only after bounded read-only preflight proved exact email, active Person, active Directus user, expected UUID, null current link, and no conflicting Person link.

The systemic reconciliation/onboarding fix belongs to **People and Identity**, not Setup.

## PostgreSQL Application Role

The protected Setup backend connects through:

```text
fieldwiring_app
```

The intended database boundary is:

```text
fieldwiring_app
    -> SELECT approved read surfaces
    -> EXECUTE approved SECURITY DEFINER commands
    -> no broad Setup-table INSERT / UPDATE / DELETE
```

Write repositories explicitly enter a bounded read-write transaction only to invoke the governed command. Direct table DML is not the browser authorization model.

## Direct Read Surfaces Used by Setup

Setup consumes, among other current objects:

### Reusable / reference

```text
ref.season
ref.stage
ref.setup_task
ref.setup_task_dependency
ref.setup_task_container_support
ref.setup_task_captain
ref.setup_resource
ref.setup_task_resource
```

### Current permanent/LOR context

```text
ref.display
ref.display_status
ref.container
ref.lor_scene
ref.lor_scene_display
ref.person
```

### Annual Setup operations

```text
ops.setup_session
ops.setup_session_task
ops.setup_work_day
ops.setup_work_day_task
ops.setup_task_progress
ops.setup_container_state
ops.setup_display_state
ops.setup_movement_event
ops.setup_movement_event_display
```

Movement/scanning writes remain outside the currently accepted Production workflow even though movement state is readable.

## Material Resolver Grant Added by Migration 025

The automatic Stage/real-Scene material resolver filters current Display membership through `ref.display_status`.

Migration:

```text
Setup/Database/025_add_setup_display_material_requirement.sql
```

therefore grants only the additional read privilege required by that resolver:

```sql
GRANT SELECT ON TABLE ref.display_status TO fieldwiring_app;
```

Production acceptance on 2026-09-11 proved:

- the grant exists;
- the governed material setter is executable by `fieldwiring_app`;
- broad direct DML on `ref.setup_task` remains absent; and
- the Production business-data fingerprint was unchanged by the migration.

## Governed Write Pattern

Setup browser writes use narrow SECURITY DEFINER functions rather than broad table permissions. Current command classes include:

- create/update reusable task;
- set Stage/Scene scope;
- set Physical Effort;
- set Display-material applicability;
- add/remove predecessor;
- create/assign reusable resources;
- manage Captain/Alternate/Advisor;
- update annual review/actuals;
- change annual planned order;
- create/update work days and assignments;
- record progress/completion;
- Administrator annual Session creation;
- Administrator future-baseline promotion; and
- reconstruction-safe task deletion.

## Troubleshooting Decision Tree

### User cannot open/read Setup

Inspect:

```text
Cloudflare email
-> active Directus user
-> role/policy
-> ref.setup_browser_capabilities(email)
```

### Manager is authorized but save says not mapped to Person

Inspect:

```text
public.directus_users.id
<-> ref.person.directus_user_id
```

Do not grant broad Setup DML to bypass this.

### Backend reports PostgreSQL permission denied

Inspect actual `fieldwiring_app` grants:

- schema USAGE;
- direct SELECT on the required read surface;
- EXECUTE on the specific governed function; and
- absence of unexpected direct DML.

The 2026-09-10 browser-preview failure `permission denied for table display_status` was this class of error and was corrected in migration 025.

### UI button missing despite valid capability

Inspect client capability/rendering logic separately. Button visibility is not the security boundary.

## Authoritative Sources

- `Setup/Database/002_create_setup_browser_authorization_contract.sql`
- `Setup/Database/003_create_setup_management_commands.sql`
- `Setup/Database/006_grant_setup_app_read.sql`
- `Setup/Database/008_create_setup_resource_management_commands.sql`
- `Setup/Database/009_create_setup_scope_schedule_execution_commands.sql`
- `Setup/Database/014_grant_setup_scene_field_context_read.sql`
- `Setup/Database/017_enforce_setup_session_year_and_admin_promotion.sql`
- `Setup/Database/019_add_reconstruction_safe_task_delete.sql`
- `Setup/Database/020_add_setup_captain_management_commands.sql`
- `Setup/Database/022_require_active_setup_captain_people.sql`
- `Setup/Database/023_add_setup_task_effort.sql`
- `Setup/Database/025_add_setup_display_material_requirement.sql`
- `Setup/Application/setup_repository.py`
- `Setup/Application/setup_next_repository.py`
- `Setup/Application/setup_material_resolution.py`
- `Setup/Application/setup_material_api.py`

## Related Systems

- [Setup engineering portal](README.md)
- [People and Identity](../../03_People_and_Identity/README.md)
- [Wiring System](../../09_Wiring_System/README.md)
