# Directus User Onboarding Identity Contract — 2026-09-09

| Document Control | Value |
|---|---|
| Document Type | Engineering Reverse-Engineering / Identity Contract |
| System | People and Identity |
| Status | CURRENT OBSERVED PRODUCTION BEHAVIOR — LIVE REVERIFIED; #395 GAP OPEN |
| Owner | Production Database / People and Identity |
| Evidence Date | 2026-09-09; live metadata reverified 2026-10-15 |
| Related | #130; #385; #395 |

## Purpose

This document records the current Production Directus **User Onboarding** flow as observed directly in the Directus administrative UI on 2026-09-09. It also records the identity lifecycle decisions that People Manager must preserve.

No Production flow, database row, role, or configuration was changed while gathering this evidence.

## Evidence Source

The flow was inspected operation-by-operation in the Production Directus UI. A normal export mechanism was not available from that interface, so the operation configuration was captured manually from the live flow screens.

## Current UI/UX Boundary — 2026-10-15

The Production user-facing application origin is `https://my.sheboyganlights.org/`.

Directus originally served a larger portion of the operator UI on `db.sheboyganlights.org`, but MSB moved operational UI/UX into task-focused applications under `my.sheboyganlights.org` because Directus Data Studio was not suitable for the required operator experience.

Directus remains important behind the scenes for:

- Google-backed Directus identity creation/authentication;
- Directus role/policy authorization;
- administrator/backend user-role maintenance;
- selected Directus-owned backend/administrative functions.

Therefore `db.sheboyganlights.org` is not the normal application destination for human operators. Any #395 first-login/bootstrap solution must return the user to `my.sheboyganlights.org` and must not reintroduce Directus Data Studio as the ordinary user interface.

## Live Directus Google SSO Configuration — 2026-10-15

Read-only inspection of the running `msb-directus` container confirmed:

```text
image                                  directus/directus:11.17.1
status                                 running
AUTH_PROVIDERS                         google
AUTH_GOOGLE_DRIVER                     openid
AUTH_GOOGLE_SCOPE                      openid email profile
AUTH_GOOGLE_ALLOW_PUBLIC_REGISTRATION  true
AUTH_GOOGLE_ISSUER_URL                 https://accounts.google.com
PUBLIC_URL                             https://db.sheboyganlights.org
AUTH_GOOGLE_CLIENT_ID                  configured (value intentionally not recorded)
AUTH_GOOGLE_CLIENT_SECRET              configured (value intentionally not recorded)
AUTH_GOOGLE_IDENTIFIER_KEY             configured; exact non-secret value still to be re-read
```

Directus documentation confirms that OpenID/OAuth public registration automatically creates a Directus account when a user authenticates through the configured provider. The supported browser SSO entry point is the provider-specific login route:

```text
https://db.sheboyganlights.org/auth/login/google?redirect=<allowed return URL>
```

This can initiate Google SSO without first rendering the Directus Data Studio login page.

The current environment does not expose a configured `AUTH_GOOGLE_DEFAULT_ROLE_ID` in the inspected variable set. Production instead relies on the active **User Onboarding** Flow to assign **MSB Browser** after `directus_users.items.create`.

This makes a direct provider-login bootstrap technically plausible for #395, but it is not yet accepted. Shared tablets create an additional identity-integrity requirement: the Google identity completing the Directus OIDC step must not differ from the human identity already authenticated by Cloudflare Access. That mismatch behavior must be explicitly tested before adopting the browser-redirect approach.

## Live Metadata Reverification — 2026-10-15

Issue #395 reconnaissance reconstructed this Flow directly from the live Production Directus metadata tables rather than from screenshots.

Confirmed Flow metadata:

```text
flow id          82013c78-22b1-4e5c-a355-4c2a3a81f644
name             User Onboarding
status           active
trigger          event
accountability   all
scope            items.create
collection       directus_users
root operation   960c69fc-4e42-4ecd-a5e1-eb3d4d0f5c50
description      Add users to directus when logging into database 1st time
```

Confirmed default role:

```text
role id          0ce54f42-8438-4eb6-8081-4303612c9da1
role name        MSB Browser
description      Everyone with read-only access
policy           Read Only - MSB Core
```

The live graph also confirms that **Check Google User** requires:

```text
provider = google
AND role IS NULL
```

and has no reject branch. Therefore a Google-backed Directus user whose role is already non-NULL exits the onboarding Flow before the Person lookup/link. This is the historical stale-link failure mode later repaired systemically by the V0.2.2 / #385 protected-actor reconciliation contract.

The separate #395 defect is earlier in the lifecycle: Cloudflare Access can authenticate a real human into `my.sheboyganlights.org` without creating any Directus user. Because this Flow fires only on `directus_users.items.create`, the Flow never runs unless some supported Directus/Google first-login mechanism actually creates the Directus identity.

Confirmed Production example:

```text
Person 18
Don Martens
dmartens@sheboyganlights.org
active = true
legacy is_manager = true
directus_user_id = NULL
matching Directus user = NONE
Setup capability row = NONE
```

Don could authenticate through Cloudflare Access and reach the Apps launcher, but Setup could not authorize him because no Directus identity existed.

### Current engineering direction

Normal human onboarding must not depend on the user seeing or understanding the Directus admin/login screen.

Target behavior:

```text
Cloudflare-authenticated human
    -> supported invisible Directus Google identity initialization
    -> default MSB Browser role only
    -> exact existing Person link when safe
    -> application continues using Directus role/policy authorization
```

Role elevation remains an explicit administrator action after the Directus identity exists. Administrators may continue changing an existing user's role in the Directus backend. The first-login bootstrap must **not** infer or grant Production Crew, Manager, or Administrator from `ref.person.is_manager`, `ref.person.is_team`, or any other legacy Person flag.

A future People Manager role-administration surface may make that administrator workflow friendlier, but Directus remains the runtime authorization authority.

Shared tablet/device/service identities are intentionally different from humans. A tablet account may have a Directus identity and no Person row. It must remain non-human, MSB Browser only, and must never be converted to a Person or elevated automatically.

The current missing-Person branch documented below still auto-creates a Person. That is an accurate description of the live Flow, **not** the accepted design for invisible #395 bootstrap. Any #395 implementation must preserve the #385 rule that human Person reconciliation uses an exact existing Person and must fail closed rather than fabricating a new Person from authentication alone.

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

Live Production metadata reverified on 2026-10-15 identifies this UUID as **MSB Browser** with policy **Read Only - MSB Core**.

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

## Authorization Administration Boundary

The Person table is not the runtime role authority.

```text
ref.person
    -> durable human identity and People administration context

Directus role/policy
    -> runtime application authorization
```

Legacy `ref.person.is_manager` / `is_team` values must not automatically create or elevate Directus authorization. For an already-existing Directus user, an administrator may continue assigning the appropriate Directus role in the Directus backend.

This keeps first-login identity initialization and later authorization assignment separate:

```text
first initialization
    -> MSB Browser

explicit administrator decision
    -> Production Crew / Manager / Administrator
```

## Current Boundary

This document records observed Production behavior and accepted People Manager identity requirements.

It does **not** authorize changing the Production Directus flow, creating Google Workspace accounts, modifying Production person rows, or deploying People Manager.