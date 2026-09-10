# Setup Data Consumption and Authorization Contract — 2026-09-10

| Document Control | Value |
|---|---|
| Document Type | Engineering Contract / Production Troubleshooting Reference |
| System | Production Database — Setup and Deployment |
| Status | CURRENT — documents implemented authorization/data-access behavior and 2026-09-10 Production finding |
| Owner | MSB Production Database engineering; People and Identity owns durable person/authentication linkage |
| Last Reviewed | 2026-09-10 |

## Purpose

Define the current Production Setup application's database-consumption surface, human authorization model, PostgreSQL application-role permissions, actor-attribution requirements, and failure boundaries so future work does not have to reconstruct these relationships from SQL, application source, or chat history.

This document does **not** authorize Production permission changes, person-link changes, Directus configuration changes, or Setup data mutation. Gather current Production evidence before changing any permission or identity record.

## Critical Separation of Responsibilities

Setup uses three separate layers that must not be confused:

```text
1. Browser authentication
   Cloudflare Access supplies the authenticated email.

2. Human application authorization
   active Directus user + current Directus role/policy
   -> ref.setup_browser_capabilities(email)
   -> read / movement / Manager / Administrator capability

3. Human write attribution
   Directus user UUID must map to ref.person.directus_user_id
   -> transaction-local app.directus_user_uuid
   -> narrow SECURITY DEFINER command
   -> existing actor/audit triggers
```

A user can therefore be an authorized Setup Manager and still be unable to save anything when the Directus UUID is not linked to `ref.person`.

Changing Directus collection/table permissions does **not** repair that condition.

## Human Capability Model

`ref.setup_browser_capabilities(text)` is the current Setup authorization authority used by the protected application.

| Human authority | Read Setup | Movement capability flag | Maintain reusable/annual Setup data | Create annual Setup Session | Promote annual order to reusable baseline |
|---|---:|---:|---:|---:|---:|
| Production Crew / Volunteer-equivalent accepted policy | Yes | Yes | No | No | No |
| Manager | Yes | Yes | Yes | No | No |
| Administrator / accepted admin access | Yes | Yes | Yes | Yes | Yes |

Current capability evaluation uses active `public.directus_users` plus Directus role/policy membership. It recognizes the accepted role/policy names `Volunteer`, `Production Crew`, `Manager`, and `Administrator`, together with accepted Directus `admin_access` authority.

The current Setup application does **not** use ordinary Directus collection permissions as the authorization check for its PostgreSQL reads/writes. The capability function reads Directus authorization metadata inside a `SECURITY DEFINER` boundary.

### Captain / Alternate execution exception

A mapped person who has Setup read access and is assigned as `CAPTAIN` or `ALTERNATE` for a reusable task may record task progress through the governed execution command even when that person is not a Manager.

`ADVISOR` alone does not grant progress-write authority.

The execution command still requires the authenticated Directus user to map to the correct `ref.person` row.

## Write-Identity Requirement

Manager and Administrator commands call `ref.setup_management_actor(text, boolean)`. Captain/Alternate progress commands call `ref.setup_execution_actor(text, bigint)`.

Both resolve the authenticated Directus user and then require:

```text
ref.person.directus_user_id = public.directus_users.id
```

If no matching `ref.person` row exists, the governed write fails closed with:

```text
Authenticated Setup operator is not mapped to an MSB person
```

This is an actor/audit identity failure, not evidence that the Directus Manager/Administrator role is missing.

## 2026-09-10 Production Finding and Immediate Repair

A read-only Production audit established that several current Manager accounts resolved successfully through `ref.setup_browser_capabilities(...)` with `can_manage_setup = true` while their matching `ref.person` rows had `directus_user_id IS NULL`.

The three proven exact-email/null-link cases were:

```text
person_id 19  Randy Miller  rmiller@sheboyganlights.org
person_id 29  Eric Sandvig  esandvig@sheboyganlights.org
person_id 31  Tom Shircel    tshircel@sheboyganlights.org
```

One affected established Manager, Randy Miller, explicitly authenticated again through the Directus/Google login path at `db.sheboyganlights.org`; a repeated read-only audit showed that `ref.person.directus_user_id` remained NULL. Therefore **repeat login is not a supported repair mechanism for an already-established Manager account**.

A bounded Production preflight then proved for all three rows: active Person, exact email match, active Directus user with the same exact email, null existing Person link, expected Directus UUID, and no UUID conflict with another Person.

A single bounded transaction updated only `ref.person.directus_user_id` for those three existing Person rows, leaving the normal `ref.person` audit trigger enabled. Post-update readback confirmed:

```text
person_id 19 -> 27b7a81c-103b-4bd4-b147-72d32fb83418
person_id 29 -> 3875bfd3-86f6-4f7b-84fb-c06328b05005
person_id 31 -> 28640462-2cc3-40b1-8a87-50e2a3b9074f
```

This was an immediate operational recovery. It does **not** fix the systemic onboarding/reconciliation flaw.

The administrator performing normal MSB operations uses `gliebig@sheboyganlights.org`, which is correctly mapped to `ref.person` person_id 17. The separately authorized `greg@engrinnovations.com` account is an intentional backup/business engineering identity used for system design. It must not be treated as an ordinary missing-Person defect or auto-linked/auto-created merely because it appears in an authorization audit.

## Directus Onboarding Dependency / Known Flaw

The current documented Directus **User Onboarding** flow matches an existing `ref.person` by exact MSB email when the person's `directus_user_id` is NULL or already equals the triggering Directus user UUID. If no matching person is found, its missing-person branch can create a person.

The observed onboarding branch is gated to an active Google-provider Directus user whose role is still NULL before the flow assigns the default role.

That is adequate for the specific first-onboarding path but is **not a general reconciliation mechanism** for already-established Directus users whose role/policy is already populated.

Operationally, Setup must not depend on a Manager remembering to visit `db.sheboyganlights.org` merely to establish the identity needed by another protected application. The current 2026-09-10 evidence also proves that a repeat visit does not repair the affected established Manager case.

People and Identity owns the durable fix. The accepted direction is to preserve exact-email identity matching and Directus authorization authority while adding a governed reconciliation/provisioning path that is independent of a manual Directus UI visit. Any repair must fail closed on conflicting UUIDs or ambiguous identity and must not guess from a person's name.

## PostgreSQL Application Role

The protected Setup backend connects through the existing PostgreSQL login:

```text
fieldwiring_app
```

That login intentionally has `default_transaction_read_only = on` as a backstop inherited from the shared FieldWiring runtime contract.

Setup ordinary reads remain read-only. Setup write repositories explicitly open a bounded read-write transaction only when invoking a narrow governed command.

The application role is intentionally **not** granted broad INSERT/UPDATE/DELETE on Setup tables.

Conceptually:

```text
fieldwiring_app
    -> SELECT approved read surfaces
    -> EXECUTE approved SECURITY DEFINER commands
    -> no broad Setup-table DML
```

## Direct PostgreSQL Read Surface Used by Setup

The following tables are directly read by the protected Setup application's PostgreSQL login.

### Setup-owned reusable/reference data

| Table | Current Setup use |
|---|---|
| `ref.season` | annual season selection/context |
| `ref.stage` | Stage/Sub-stage scope, names, ordering, current-location context |
| `ref.setup_task` | reusable task catalog and task definition |
| `ref.setup_task_dependency` | reusable predecessor relationships |
| `ref.setup_task_display` | explicit task-to-Display relationships |
| `ref.setup_task_container_support` | supplemental/support/KIT Container relationships |
| `ref.setup_task_captain` | Captain/Alternate/Advisor assignments |
| `ref.setup_resource` | reusable equipment/resource catalog |
| `ref.setup_task_resource` | reusable task-resource requirements |

### Permanent/shared physical and LOR context consumed by Setup

| Table | Owning/related subsystem | Current Setup use |
|---|---|---|
| `ref.display` | permanent Display identity/inventory | task/material context and current `container_id` |
| `ref.container` | Containers and Storage | current storage/transport Container context |
| `ref.lor_scene` | current LOR projection | explicit Scene scope/context |
| `ref.lor_scene_display` | current LOR projection | current Scene Display membership |
| `ref.person` | People and Identity | person names for execution/audit context; durable Directus-person identity link |

`ref.person` SELECT access for `fieldwiring_app` predates Setup and is part of the shared FieldWiring least-privilege read contract. Setup nevertheless consumes it and therefore has a cross-subsystem dependency on People and Identity.

### Annual Setup operational data

| Table | Current Setup use |
|---|---|
| `ops.setup_session` | annual Setup Session identity/status |
| `ops.setup_session_task` | annual inclusion/review/planning/execution state |
| `ops.setup_work_day` | short-horizon work-day planning |
| `ops.setup_work_day_task` | work-day/shift/crew-lane task assignment |
| `ops.setup_task_progress` | multi-period progress/evidence |
| `ops.setup_container_state` | annual Container position state/read context |
| `ops.setup_display_state` | annual Display position state/read context |
| `ops.setup_movement_event` | movement history/read context |
| `ops.setup_movement_event_display` | movement-event Display relationships |

Movement/scanning write commands remain outside the currently accepted Setup Production workflow even though current read models/capability flags include movement context.

## Authorization Metadata Consumed Inside SECURITY DEFINER Functions

The Setup application role does not receive ordinary direct SELECT access to these Directus system tables. Setup capability/actor functions consume them inside the governed function boundary:

| Table | Purpose |
|---|---|
| `public.directus_users` | resolve active Directus user UUID/email/provider/role |
| `public.directus_roles` | resolve current role name |
| `public.directus_access` | resolve user/role policy assignments |
| `public.directus_policies` | resolve policy names and `admin_access` |

These are **authorization metadata**, not Setup business tables.

## Governed Write Targets

Do not grant direct table DML merely because one of these actions writes a table. The browser/backend calls the named narrow function and the function performs the table mutation as `SECURITY DEFINER` after authorization and actor resolution.

| User action / command class | Principal table(s) mutated |
|---|---|
| Create reusable task | `ref.setup_task`; also adds `ops.setup_session_task` rows for still-open sessions |
| Update reusable task | `ref.setup_task` |
| Set Stage/Scene scope | `ref.setup_task` |
| Set Physical Effort | `ref.setup_task` |
| Add/remove predecessor | `ref.setup_task_dependency` |
| Create reusable resource | `ref.setup_resource` |
| Add/update/remove task resource | `ref.setup_task_resource` |
| Add/update/remove Captain/Alternate/Advisor | `ref.setup_task_captain` |
| Update annual historical review/actuals | `ops.setup_session_task` |
| Change annual planned order | `ops.setup_session_task` |
| Create/update work day | `ops.setup_work_day` |
| Schedule/remove task on work day | `ops.setup_work_day_task`; may update `ops.setup_session_task` planned state/date |
| Record progress | `ops.setup_task_progress`; updates `ops.setup_session_task`; may update `ops.setup_work_day_task` |
| Administrator creates annual Setup Session | `ops.setup_session`, `ops.setup_session_task`, `ops.setup_display_state`, `ops.setup_container_state` |
| Administrator promotes annual order to future baseline | `ref.setup_task.baseline_plan_order` |
| Reconstruction-safe task delete | removes eligible rows from `ops.setup_session_task`, `ref.setup_task_dependency`, `ref.setup_task_display`, `ref.setup_task_container_support`, `ref.setup_task_captain`, `ref.setup_task_resource`, then `ref.setup_task` |

The Session-creation command also reads `ref.season`, `ref.setup_task`, `ref.display`, `ref.display_status`, and `ref.container` inside its governed function to seed the annual Session state.

## Where Permission Changes Actually Belong

Before changing anything, identify which layer failed.

### User cannot open/read Setup

Inspect:

```text
Cloudflare authenticated email
-> active public.directus_users row
-> Directus role / directus_access / directus_policies
-> ref.setup_browser_capabilities(email)
```

Do not change Setup table DML permissions to solve this.

### User is recognized as Manager but write returns "not mapped to an MSB person"

Inspect:

```text
public.directus_users.id
<-> ref.person.directus_user_id
```

This is an identity-link problem owned by People and Identity. Do not grant broad Setup table DML and do not change the Manager policy to bypass it.

### Setup backend receives PostgreSQL permission denied

Inspect the `fieldwiring_app` grant contract:

- schema USAGE;
- direct SELECT on the approved read surface;
- EXECUTE on the specific governed function being called;
- no unexpected broad table DML.

### UI button missing despite valid capability

Inspect the Setup application/UI capability logic separately. A hidden/visible button is not the security boundary.

## Production Preflight — Human Identity Mapping

Before onboarding Managers/Captains or troubleshooting write failures, use a read-only audit that compares current Setup-authorized Directus identities to `ref.person.directus_user_id` and exact `ref.person.email` matches.

Required classifications:

```text
OK - DIRECTUS USER IS MAPPED
BROKEN - PERSON EXISTS BY EMAIL BUT DIRECTUS LINK IS NULL
CONFLICT - EMAIL PERSON IS LINKED TO DIFFERENT DIRECTUS USER
BROKEN - NO REF.PERSON WITH MATCHING MSB EMAIL
```

An authorized account with no Person match may also be an intentionally separate engineering/service/backup identity rather than a defect. Confirm purpose before classifying or repairing it. Never auto-repair a `CONFLICT` or no-match case by first/last name.

## Production Preflight — PostgreSQL Grants

Before altering database permissions, inspect actual current grants rather than assuming migration history still represents Production exactly.

At minimum verify:

- `fieldwiring_app` can CONNECT;
- schema USAGE exists for required schemas;
- every directly queried Setup table has SELECT;
- every invoked governed Setup function has EXECUTE;
- direct INSERT/UPDATE/DELETE remains absent from governed Setup tables.

The current grant authorities include:

- `FieldWiring/Application/grant_fieldwiring_app.sql` for the shared base read login and `ref.person`/LOR/shared reference reads;
- `Setup/Database/006_grant_setup_app_read.sql` for Setup core read tables;
- `Setup/Database/009_create_setup_scope_schedule_execution_commands.sql` for `ops.setup_task_progress` read and governed execution commands; and
- `Setup/Database/014_grant_setup_scene_field_context_read.sql` for Display/Container/current Scene material-context reads.

## Authoritative Implementation Sources

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
- `Setup/Application/setup_api.py`
- `Setup/Application/setup_repository.py`
- `Setup/Application/setup_resource_repository.py`
- `Setup/Application/setup_next_repository.py`
- `Setup/Application/setup_training_api.py`
- `FieldWiring/Application/grant_fieldwiring_app.sql`
- `Docs/02_Production_Database/01_System_Architecture/03_People_and_Identity/engineering/Directus_User_Onboarding_Identity_Contract_2026-09-09.md`

## Related Systems

- [Setup engineering portal](README.md)
- [People and Identity](../../03_People_and_Identity/README.md)
- [Wiring System](../../09_Wiring_System/README.md)

## Current Resume Point

The immediate three-Manager Production write blocker was repaired on 2026-09-10 by linking the three proven exact-email Person rows to their existing active Directus UUIDs. Manager role/policy permissions were not changed.

The next identity work belongs to People and Identity:

1. validate Randy Miller's real Setup write path after the repair, then allow the assigned Manager review to continue if successful;
2. define a durable onboarding/reconciliation mechanism that does not require a manual visit to the Directus UI and that can reconcile already-established users safely;
3. add acceptance coverage for first-onboarding linkage, established-user reconciliation, conflict/no-match failure, and population-wide authorized-user audit; and
4. treat intentionally separate engineering/backup identities according to their documented purpose rather than forcing them into the operational Person mapping model.

Do not weaken `ref.setup_management_actor(...)`, bypass person attribution, or grant broad Setup table DML as a workaround.
