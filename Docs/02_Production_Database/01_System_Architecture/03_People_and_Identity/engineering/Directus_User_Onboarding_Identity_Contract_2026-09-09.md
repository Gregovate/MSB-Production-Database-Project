# Directus User Onboarding Identity Contract — 2026-09-09

| Document Control | Value |
|---|---|
| Document Type | Engineering Reverse-Engineering / Identity Contract |
| System | People and Identity |
| Status | CURRENT OBSERVED PRODUCTION BEHAVIOR — operation graph and operation permission context captured 2026-09-10; outer trigger/accountability still to confirm |
| Owner | Production Database / People and Identity |
| Evidence Date | 2026-09-09; supplemented 2026-09-10 |
| Related | Issue #130 |

## Purpose

This document records the current Production Directus **User Onboarding** flow as observed directly in the Directus administrative UI on 2026-09-09 and supplemented by read-only Production database evidence on 2026-09-10. It also records the identity lifecycle decisions that People Manager must preserve.

No Production flow, database row, role, policy, permission, or configuration was changed while gathering this evidence.

## Evidence Source

The flow was first inspected operation-by-operation in the Production Directus UI. On 2026-09-10, the Production `public.directus_operations` rows for Flow `82013c78-22b1-4e5c-a355-4c2a3a81f644` (`User Onboarding`) were captured read-only, including each operation's resolve/reject links and options.

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

Confirmed operation IDs and keys:

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

This is a critical boundary. The Flow's inner collection operations are deliberately configured for `$full` permissions rather than depending on the ordinary Manager policy's collection/action matrix. That statement is limited to the operation options observed here; the Flow-level outer `trigger` and `accountability` configuration still requires direct read-only confirmation before changing the Flow.

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

The operation reads the Directus user identified by the triggering event.

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

The onboarding branch therefore applies only to a Google Directus user whose role is still null.

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

The human-readable role name for `0ce54f42-8438-4eb6-8081-4303612c9da1` was not established by the original UI inspection and must not be inferred from the UUID alone unless separately confirmed.

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

This is the critical identity-matching rule. The flow matches an existing person by **MSB email**, not by first name, last name, `personal_email`, or phone.

The existing row is eligible when `directus_user_id` is either null or already equals the triggering Directus user ID.

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

If a matching person exists, the resolve branch updates that person. If not, the reject branch creates a person.

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

Current Production options are explicitly:

```json
{"permissions":"$full","emitEvents":false,...}
```

The flow therefore preserves the existing `person_id` and links the Directus identity to it.

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

Therefore `ref.person` does **not** have to pre-exist for a new Google/Directus user. If the flow cannot find a matching person by MSB email, it can create a new active person row.

## Identity Consequence

The current flow makes `ref.person.email` the deterministic bridge between an existing person and a future Google/Directus identity.

For an existing casual volunteer to become a team member without creating a second person row, the intended Sheboygan Lights email must already be stored on the existing `ref.person` row **before the relevant onboarding event**.

Example:

```text
person_id 123 exists as a casual volunteer
personal_email = jane@example.com
email = jsmith@sheboyganlights.org
directus_user_id = NULL

Google Workspace account jsmith@sheboyganlights.org is created later

Directus onboarding event occurs
    -> flow searches email = jsmith@sheboyganlights.org
    -> finds person_id 123
    -> sets directus_user_id on person_id 123
```

Do **not** change the flow to guess identity from name alone. Different real people may share a name.

## Confirmed 2026-09-10 Lifecycle Failure

Production evidence proved that established Manager accounts can exist with:

```text
active Directus user
Manager authorization
exact matching ref.person.email
ref.person.directus_user_id = NULL
```

Randy Miller explicitly authenticated again at `db.sheboyganlights.org`, but the Person link remained NULL. A bounded Production repair of the Person link immediately restored governed Setup create/delete behavior without any Directus permission change.

This means the existing onboarding mechanism is not a sufficient reconciliation mechanism for already-established users.

The inner `provider=google AND role IS NULL` condition is one confirmed reason such an established Manager cannot traverse the Person-link branch. The exact outer trigger event must still be read directly from `public.directus_flows` before the final durable hardening design is chosen.

## People Manager Manual-Create Rule

When People Manager manually creates a casual volunteer, it should create the durable person identity and also construct/reserve the person's future Sheboygan Lights email in `ref.person.email`.

The established naming convention is:

```text
first initial + last name @ sheboyganlights.org
```

Example:

```text
Jane Smith -> jsmith@sheboyganlights.org
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

A staged `@sheboyganlights.org` value may exist before the Google Workspace account exists. Therefore application code must not infer email deliverability merely from `ref.person.email IS NOT NULL`.

Google Workspace remains the authority for whether the MSB account actually exists.

For scheduling/contact behavior:

- before Google provisioning is confirmed, use `personal_email`;
- after Google provisioning is confirmed, the Sheboygan Lights address may become the business/deliverable address;
- `directus_user_id` is a separate Directus identity/linkage state and is not the test for whether Google email is deliverable.

The mechanism by which application code will obtain authoritative Google-provisioning state is still an implementation item; do not invent that state from existing PostgreSQL fields.

## Active / Inactive Person Lifecycle

`active_flag` represents whether the person is currently active with MSB. It is not Captain eligibility, skill, system-access state, or proof of a Google account.

For casual/seasonal volunteers:

- create one durable `ref.person` identity;
- if the person does not return in subsequent seasons, set `active_flag = false` rather than deleting the identity;
- preserve the person's historical relationships and identity fields;
- if the person returns later, reactivate the same person record rather than creating another person.

People Manager must therefore support safe activation/inactivation and must not treat an inactive record as disposable duplicate data.

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

The current corrective goal is to remove the operational dependency on a human remembering to visit Directus merely so unrelated governed MSB applications can obtain a usable actor mapping.

## Acceptance Requirements for Corrected Identity Lifecycle

Before the corrected lifecycle is accepted, prove at least:

1. manual casual-volunteer create reserves a collision-safe MSB email without granting access;
2. an existing Person with the staged MSB email can be linked to the same `person_id` when the corresponding Directus identity is established;
3. an already-established Directus user with an exact-email Person and NULL link is safely reconciled without manual database patching;
4. conflicting Directus UUID or ambiguous/no exact-email identity fails closed;
5. no staged email causes scheduler/business mail to be sent to an unprovisioned Google address;
6. email collision handling cannot overwrite or reuse another person's reserved/system identity;
7. manually created and Directus-created people are both visible to duplicate detection;
8. inactive seasonal Person identity is preserved and may be reactivated without duplication;
9. `directus_user_id` remains protected from ordinary People Manager contact editing;
10. population-wide audit proves every human identity required for governed writes is either correctly mapped or explicitly documented as an intentional exception; and
11. no Production Flow/database mutation occurs without the separate Production gate.

## Remaining Evidence Before Hardening Design

The exact `public.directus_operations` graph and operation permission configuration are now captured.

Before changing the Flow or selecting another reconciliation mechanism, still capture the Flow row itself from `public.directus_flows`, specifically:

```text
id
name
status
trigger
accountability
options
operation
```

This is required to establish the outer event that causes the Flow to run and its Flow-level accountability semantics.

## Current Boundary

This document records observed Production behavior and accepted identity requirements.

It does **not** authorize changing the Production Directus flow, creating Google Workspace accounts, modifying additional Production Person rows, or deploying a new reconciliation mechanism.
