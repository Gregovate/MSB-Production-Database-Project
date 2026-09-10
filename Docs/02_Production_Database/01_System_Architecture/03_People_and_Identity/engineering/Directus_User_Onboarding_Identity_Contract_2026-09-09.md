# Directus User Onboarding Identity Contract — 2026-09-09

| Document Control | Value |
|---|---|
| Document Type | Engineering Reverse-Engineering / Identity Contract |
| System | People and Identity |
| Status | CURRENT OBSERVED PRODUCTION BEHAVIOR — trigger, accountability, operation graph, and operation permission context captured 2026-09-10 |
| Owner | Production Database / People and Identity |
| Evidence Date | 2026-09-09; supplemented 2026-09-10 |
| Related | Issue #130 |

## Purpose

This document records the current Production Directus **User Onboarding** flow as observed directly in the Directus administrative UI on 2026-09-09 and supplemented by read-only Production database evidence on 2026-09-10. It also records the identity lifecycle decisions that People Manager must preserve.

No Production flow, database row, role, policy, permission, or configuration was changed while gathering this evidence.

## Evidence Source

The flow was first inspected operation-by-operation in the Production Directus UI. On 2026-09-10, the Production `public.directus_flows` and `public.directus_operations` rows for Flow `82013c78-22b1-4e5c-a355-4c2a3a81f644` (`User Onboarding`) were captured read-only.

## Production Flow Trigger — Confirmed 2026-09-10

Current Production Flow row:

```text
id              82013c78-22b1-4e5c-a355-4c2a3a81f644
name            User Onboarding
status          active
trigger         event
accountability  all
root operation  960c69fc-4e42-4ecd-a5e1-eb3d4d0f5c50
```

Current options:

```json
{"type":"action","scope":["items.create"],"collections":["directus_users"]}
```

Therefore this Flow runs as an **action event when a `directus_users` row is created**. It is not a login-time reconciliation Flow and it is not configured for `directus_users.items.update`.

This has an important lifecycle consequence:

```text
Directus user row created
    -> User Onboarding gets one create-event opportunity
    -> if the Person link is not established during that pass
    -> later login does not re-run this Flow
    -> later ordinary Directus user updates do not re-run this Flow
```

That behavior is directly consistent with the 2026-09-10 Randy Miller repeat-login test: his established Directus user row already existed, so a later visit to `db.sheboyganlights.org` could not cause this create-event Flow to reconcile his missing Person link.

## Production Operation Graph — Confirmed 2026-09-10

The current operation graph is:

```text
Read Directus Users
    -> Check Google User
        -> Update User Default Role
            -> Read Person
                -> Found Existing Person ref.person
                    -> resolve: Update Person with Directus ID
                    -> reject:  Add Person if not in Person
```

Confirmed operations:

| Operation | Key | Type | Resolve | Reject |
|---|---|---|---|---|
| Read Directus Users | `read_directus_users` | `item-read` | Check Google User | |
| Check Google User | `check_google_user` | `condition` | Update User Default Role | |
| Update User Default Role | `update_user_default_role` | `item-update` | Read Person | |
| Read Person | `read_person` | `item-read` | Found Existing Person | |
| Found Existing Person ref.person | `found_existing_person_ref_person` | `condition` | Update Person with Directus ID | Add Person if not in Person |
| Update Person with Directus ID | `update_person_with_directus_id` | `item-update` | | |
| Add Person if not in Person | `add_person_if_not_in_person` | `item-create` | | |

All item read/create/update operations in this Flow are explicitly configured with:

```json
{"permissions":"$full","emitEvents":false}
```

The Flow therefore does not depend on the ordinary Manager policy's per-collection `public.directus_permissions` rows for these inner onboarding operations. Directus Manager permissions remain a separate authorization boundary for ordinary Directus use and are documented separately.

All captured operations show `user_created = 71490451-2c6d-4a08-b8aa-05a7ab784419`, the operational Administrator Directus identity for `gliebig@sheboyganlights.org`.

## Current Production Flow

### 1. Read Directus Users

Operation key:

```text
read_directus_users
```

Collection:

```text
directus_users
```

Target ID:

```text
{{$trigger.key}}
```

Current Production options include:

```json
{"permissions":"$full","emitEvents":false,"collection":"directus_users","key":["{{$trigger.key}}"]}
```

The operation reads the Directus user identified by the triggering create event.

### 2. Check Google User

Operation key:

```text
check_google_user
```

Confirmed condition:

```json
{
  "filter": {
    "_and": [
      {
        "$last": {
          "provider": {
            "_eq": "google"
          }
        }
      },
      {
        "$last": {
          "role": {
            "_null": true
          }
        }
      }
    ]
  }
}
```

The only resolve path out of this condition therefore applies to a Google Directus user whose role is still null. The condition has no reject operation configured. A user that does not satisfy both tests stops at this point and never reaches Person reconciliation.

### 3. Update User Default Role

Operation key:

```text
update_user_default_role
```

Collection:

```text
directus_users
```

Target ID:

```text
{{read_directus_users.id}}
```

Confirmed payload:

```json
{
  "role": "0ce54f42-8438-4eb6-8081-4303612c9da1"
}
```

Current Production options explicitly use `$full` permissions and `emitEvents=false`.

### 4. Read Person

Operation key:

```text
read_person
```

Collection:

```text
Person
```

Confirmed query intent:

```json
{
  "filter": {
    "_and": [
      {
        "email": {
          "_eq": "{{read_directus_users.email}}"
        }
      },
      {
        "_or": [
          {
            "directus_user_id": {
              "_null": true
            }
          },
          {
            "directus_user_id": {
              "_eq": "{{read_directus_users.id}}"
            }
          }
        ]
      }
    ]
  },
  "limit": 1
}
```

The operation is explicitly configured with `$full` permissions and `emitEvents=false`.

This is the critical identity-matching rule. The Flow matches an existing Person by **MSB email**, not by first name, last name, `personal_email`, or phone. The existing row is eligible when `directus_user_id` is either null or already equals the triggering Directus user ID.

### 5. Found Existing Person

Operation key:

```text
found_existing_person_ref_person
```

Confirmed condition:

```json
{
  "filter": {
    "$last[0].person_id": {
      "_null": false
    }
  }
}
```

If a matching Person exists, the resolve branch updates that Person. If not, the reject branch creates a Person.

### 6. Existing Person Branch — Update Person with Directus ID

Operation key:

```text
update_person_with_directus_id
```

Collection:

```text
Person
```

Target ID:

```text
{{read_person[0].person_id}}
```

Confirmed payload:

```json
{
  "directus_user_id": "{{read_directus_users.id}}"
}
```

The Flow therefore preserves the existing `person_id` and links the Directus identity to it.

### 7. Missing Person Branch — Add Person if not in Person

Operation key:

```text
add_person_if_not_in_person
```

Collection:

```text
Person
```

Confirmed payload begins with:

```json
{
  "directus_user_id": "{{read_directus_users.id}}",
  "first_name": "{{read_directus_users.first_name}}",
  "last_name": "{{read_directus_users.last_name}}",
  "email": "{{read_directus_users.email}}"
}
```

The original UI inspection also established `active_flag = true` in this branch. Current Production options are explicitly configured with `$full` permissions and `emitEvents=false`.

Therefore `ref.person` does **not** have to pre-exist for a new Google/Directus user. If the Flow cannot find a matching Person by MSB email, it can create a new active Person row.

## Identity Consequence

The current Flow makes `ref.person.email` the deterministic bridge between an existing Person and a future Google/Directus identity.

For an existing casual volunteer to become a team member without creating a second Person row, the intended Sheboygan Lights email must already be stored on the existing `ref.person` row before the Directus user row is created.

The lifecycle is therefore timing-sensitive:

```text
existing ref.person with reserved MSB email
    -> Directus user row is created
    -> create-event Flow executes once
    -> exact-email Person link succeeds
```

If the Person email is not staged correctly at that moment, or the create-event resolve path is skipped, the current Flow provides no later reconciliation mechanism.

Do **not** change the Flow to guess identity from name alone. Different real people may share a name.

## Confirmed 2026-09-10 Lifecycle Failure

Production evidence proved that established Manager accounts can exist with:

```text
active Directus user
Manager authorization
exact matching ref.person.email
ref.person.directus_user_id = NULL
```

Randy Miller explicitly authenticated again at `db.sheboyganlights.org`, but the Person link remained NULL. The outer Flow evidence now proves why: `User Onboarding` listens only to `directus_users.items.create`, not login or update events.

A bounded Production repair of the Person link immediately restored governed Setup create/delete behavior without any Directus permission change.

The current failure mechanism is therefore fully established:

```text
one create-event opportunity
    + Person reconciliation nested behind provider=google AND role IS NULL
    + no reject branch from that condition
    + no later reconciliation trigger
    = established users can remain permanently unmapped until manually repaired
```

## People Manager Manual-Create Rule

When People Manager manually creates a casual volunteer, it should create the durable Person identity and also construct/reserve the person's future Sheboygan Lights email in `ref.person.email`.

The established naming convention is:

```text
first initial + last name @ sheboyganlights.org
```

The generated address must be normalized and checked against the existing case-insensitive uniqueness protection on `ref.person.email` before create/update.

When the normal convention collides with an existing reserved/MSB email, do not silently assign another person's address. The UI should present an explicit alternate proposal, favoring additional characters from the first name before resorting to opaque numbering, and require review before the alternate is reserved.

Reserving the address in `ref.person.email` does **not** create a Google Workspace account, grant access, or prove the address can receive mail.

## Email Meaning and Deliverability

The current People/Identity contract distinguishes two email purposes:

```text
ref.person.email
    -> reserved/current Sheboygan Lights business and system identity

ref.person.personal_email
    -> personal/contact address
```

A staged `@sheboyganlights.org` value may exist before the Google Workspace account exists. Application code must not infer email deliverability merely from `ref.person.email IS NOT NULL`.

Google Workspace remains the authority for whether the MSB account actually exists. `directus_user_id` is a separate Directus identity/linkage state and is not the test for whether Google email is deliverable.

## Active / Inactive Person Lifecycle

`active_flag` represents whether the Person is currently active with MSB. It is not Captain eligibility, skill, system-access state, or proof of a Google account.

For casual/seasonal volunteers:

- create one durable `ref.person` identity;
- if the person does not return in subsequent seasons, set `active_flag = false` rather than deleting the identity;
- preserve historical relationships and identity fields; and
- if the person returns later, reactivate the same Person rather than creating another Person.

## Google as User-Management Authority

Google Admin / Google Workspace remains the source of truth for creating and managing the actual Sheboygan Lights account.

The current desired lifecycle is:

```text
casual volunteer
    -> manually create ref.person
    -> store personal contact email
    -> generate/reserve future @sheboyganlights.org identity
    -> use personal email while Google account does not yet exist
    -> later create the Google Workspace account when the person becomes a team member
    -> MSB email becomes usable business email once Google provisioning is confirmed
    -> Directus identity is established
    -> exact-email reconciliation links the existing person_id
```

People Manager must not infer Directus authorization roles from the person's email address.

The current corrective goal is to remove both brittle lifecycle dependencies:

1. Person linkage must not depend on a single unrecoverable `directus_users.items.create` pass; and
2. ordinary governed MSB application use must not depend on a person remembering to visit Directus solely to bootstrap identity.

## Required Hardening Direction

The permanent design must separate **Directus role/bootstrap setup** from **Person identity reconciliation**.

At minimum, a corrected design must ensure:

```text
A. new Directus user
   -> role/bootstrap handling may occur when appropriate
   -> Person reconciliation is attempted independently of whether role was NULL

B. established Directus user
   + exact-email existing Person
   + Person.directus_user_id IS NULL
   -> deterministic governed reconciliation path exists
   -> no manual SQL patch required

C. conflict
   -> Person already linked to a different Directus UUID
   OR Directus UUID already linked to a different Person
   OR ambiguous/no exact-email identity
   -> fail closed for Administrator review
```

The design must not rely on name matching and must preserve the existing Person/audit model.

Removing `role IS NULL` from the current condition by itself is **not** sufficient hardening because the Flow still fires only on `directus_users.items.create`. Likewise, adding an update trigger by itself would not remove the dependency on a human first causing Directus identity creation.

## Acceptance Requirements for Corrected Identity Lifecycle

Before the corrected lifecycle is accepted, prove at least:

1. manual casual-volunteer create reserves a collision-safe MSB email without granting access;
2. an existing Person with the staged MSB email is linked to the same `person_id` when the corresponding Directus identity is established;
3. an already-established Directus user with an exact-email Person and NULL link is safely reconciled without manual database patching;
4. conflicting Directus UUID or ambiguous/no exact-email identity fails closed;
5. no staged email causes scheduler/business mail to be sent to an unprovisioned Google address;
6. email collision handling cannot overwrite or reuse another person's reserved/system identity;
7. manually created and Directus-created people are both visible to duplicate detection;
8. inactive seasonal Person identity is preserved and may be reactivated without duplication;
9. `directus_user_id` remains protected from ordinary People Manager contact editing;
10. population-wide audit proves every human identity required for governed writes is either correctly mapped or explicitly documented as an intentional exception;
11. the corrected design proves what event establishes a Directus UID without relying on undocumented operator behavior; and
12. no Production Flow/database mutation occurs without the separate Production gate.

## Remaining Evidence Before Implementing Hardening

The Flow trigger, accountability, operation graph, and operation permission context are now fully captured.

Before implementing a durable reconciliation command or changing actor behavior, inspect the current Production definitions and constraints for:

```text
ref.resolve_actor()
ref.set_actor_on_update()
ref.person.directus_user_id constraints/indexes
```

That evidence is required because a reconciliation mechanism must preserve MSB person-level audit attribution and fail closed on UUID conflicts.

Separately, before eliminating the human visit to Directus, establish a supported and controlled mechanism for creating/provisioning the Directus identity from the Google/MSB onboarding process. Do not pre-create Directus users by unsupported direct table manipulation.

## Current Boundary

This document records observed Production behavior and required hardening direction.

It does **not** authorize changing the Production Directus Flow, creating Google Workspace accounts, modifying additional Production Person rows, or deploying a new reconciliation mechanism.
