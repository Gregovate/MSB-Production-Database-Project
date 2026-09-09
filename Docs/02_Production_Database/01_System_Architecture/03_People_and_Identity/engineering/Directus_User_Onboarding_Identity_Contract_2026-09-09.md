# Directus User Onboarding Identity Contract — 2026-09-09

| Document Control | Value |
|---|---|
| Document Type | Engineering Reverse-Engineering / Identity Contract |
| System | People and Identity |
| Status | CURRENT OBSERVED PRODUCTION BEHAVIOR — DOCUMENTED, NOT MODIFIED |
| Owner | Production Database / People and Identity |
| Evidence Date | 2026-09-09 |
| Related | Issue #130 |

## Purpose

This document records the current Production Directus **User Onboarding** flow as observed directly in the Directus administrative UI on 2026-09-09. It also records the identity lifecycle decisions that People Manager must preserve.

No Production flow, database row, role, or configuration was changed while gathering this evidence.

## Evidence Source

The flow was inspected operation-by-operation in the Production Directus UI. A normal export mechanism was not available from that interface, so the operation configuration was captured manually from the live flow screens.

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

Observed query:

```json
{
  "filter": {
    "status": {
      "_eq": "active"
    }
  }
}
```

The flow therefore reads the active Directus user created by the triggering event.

### 2. Check Google User

Operation key:

```text
check_google_user
```

Observed condition:

```json
{
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
```

The onboarding branch therefore applies to an active Directus user whose provider is Google and whose role is still null.

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

Observed payload:

```json
{
  "role": "0ce54f42-8438-4eb6-8081-4303612c9da1"
}
```

The human-readable role name was not established by this inspection and must not be inferred from the UUID alone.

### 4. Read Person

Operation key:

```text
read_person
```

Collection:

```text
Person
```

Observed query:

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

This is the critical identity-matching rule. The flow matches an existing person by **MSB email**, not by first name, last name, `personal_email`, or phone.

The existing row is eligible when `directus_user_id` is either null or already equals the triggering Directus user ID.

### 5. Found Existing Person

Operation key:

```text
found_existing_person_ref_person
```

Observed condition:

```json
{
  "$last[0].person_id": {
    "_null": false
  }
}
```

If a matching person exists, the success branch updates that person. If not, the failure branch creates a person.

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

Observed payload:

```json
{
  "directus_user_id": "{{read_directus_users.id}}"
}
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

Observed payload:

```json
{
  "directus_user_id": "{{read_directus_users.id}}",
  "first_name": "{{read_directus_users.first_name}}",
  "last_name": "{{read_directus_users.last_name}}",
  "email": "{{read_directus_users.email}}",
  "active_flag": true
}
```

Therefore `ref.person` does **not** have to pre-exist for a new Google/Directus user. If the flow cannot find a matching person by MSB email, it creates a new active person row.

## Identity Consequence

The current flow makes `ref.person.email` the deterministic bridge between an existing person and a future Google/Directus identity.

For an existing casual volunteer to become a team member without creating a second person row, the intended Sheboygan Lights email must already be stored on the existing `ref.person` row **before the person's first Google/Directus login**.

Example:

```text
person_id 123 exists as a casual volunteer
personal_email = jane@example.com
email = jsmith@sheboyganlights.org
directus_user_id = NULL

Google Workspace account jsmith@sheboyganlights.org is created later

first Directus login
    -> flow searches email = jsmith@sheboyganlights.org
    -> finds person_id 123
    -> sets directus_user_id on person_id 123
```

If the MSB email is not staged on the existing person first, the current flow has no identity evidence with which to match the Google user to that volunteer and may create a second person row.

Do **not** change the flow to guess identity from name alone. Different real people may share a name.

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
- `directus_user_id` is a separate first-login/linkage state and is not the test for whether Google email is deliverable.

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
    -> first Directus login links the existing person_id through the current email-match flow
```

People Manager must not create Directus users or infer Directus authorization roles from the person's email address.

## Acceptance Requirements for People Manager

Before any Production implementation is accepted, prove at least these identity cases on a current Production clone or other approved disposable environment:

1. manually creating a casual volunteer reserves a collision-safe MSB email without granting access;
2. an existing casual volunteer with the staged MSB email is later linked to the same `person_id` on first Directus login;
3. no staged email causes scheduler/business mail to be sent to an unprovisioned Google address;
4. email collision handling cannot overwrite or reuse another person's reserved/system identity;
5. manually created and Directus-created people are both visible to duplicate detection;
6. an inactive seasonal person is preserved and can be reactivated without creating a duplicate;
7. `directus_user_id` remains protected from ordinary People Manager contact editing; and
8. no Production flow or database mutation occurs without the separate Production gate.

## Current Boundary

This document records observed Production behavior and accepted People Manager identity requirements.

It does **not** authorize changing the Production Directus flow, creating Google Workspace accounts, modifying Production person rows, or deploying People Manager.