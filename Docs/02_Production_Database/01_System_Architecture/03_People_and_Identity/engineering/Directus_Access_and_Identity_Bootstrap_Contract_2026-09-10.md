# Directus Access and Identity Bootstrap Contract — 2026-09-10

| Document Control | Value |
|---|---|
| Document Type | Engineering Authorization / Identity Bootstrap Contract |
| System | People and Identity / Directus |
| Status | CURRENT OBSERVED/OPERATOR-CONFIRMED BEHAVIOR — exact permission-row inventory still requires Production evidence |
| Owner | Production Database / People and Identity |
| Evidence Date | 2026-09-10 |
| Related | Issue #130; Setup Issue #122 |

## Purpose

Document the distinction between Directus identity bootstrap access, Directus role/policy authorization, Directus collection/action permissions, MSB Person linkage, and PostgreSQL application permissions.

This distinction is required because an MSB user can fail at any one of these layers, and a successful or failed test at one layer does not prove the state of the others.

## Authorization / Identity Layers

Current MSB protected applications depend on several separate controls:

```text
1. Cloudflare authentication
   -> establishes the authenticated browser email

2. Directus identity/bootstrap
   -> user reaches db.sheboyganlights.org
   -> Directus establishes a Directus user identity / UUID

3. Directus role and policy assignment
   -> public.directus_roles
   -> public.directus_access
   -> public.directus_policies

4. Directus collection/action/field permissions
   -> public.directus_permissions
   -> controls what a Directus policy may read/create/update/delete

5. MSB durable Person linkage
   -> ref.person.directus_user_id = public.directus_users.id
   -> supplies durable human identity / actor attribution

6. PostgreSQL application-role boundary
   -> fieldwiring_app / people_app / other application login
   -> approved SELECT surfaces and narrow SECURITY DEFINER EXECUTE grants
```

Do not infer one layer from another.

## `$t:public_label` — Operator-Confirmed Bootstrap Purpose

A 2026-09-10 Directus authorization inventory showed a user-specific policy assignment whose stored policy name is:

```text
$t:public_label
```

Operator clarification established the purpose of this policy in the MSB environment:

> it is the minimal Directus rights configured so a person reaching `db.sheboyganlights.org` can obtain a Directus UID.

Therefore this policy must **not** be classified merely from its name as accidental extra access or permission drift.

Its architectural role is **identity bootstrap**, distinct from normal Manager/Administrator application authorization.

Known example from the 2026-09-10 inventory:

```text
rneerhof@sheboyganlights.org
    Directus role = Manager
    Manager policy via role
    Manager policy via direct user assignment
    $t:public_label via direct user assignment
```

The presence of `$t:public_label` on this user is therefore not, by itself, evidence of an authorization defect.

## What Is Not Yet Established

The following must not be inferred without current Production evidence:

- whether every new Directus user receives the bootstrap policy by the same mechanism;
- whether the bootstrap policy is intended to remain after a user later receives Manager/Administrator authority;
- whether historical users may retain or lack user-specific bootstrap assignments for legitimate reasons;
- whether duplicate Manager policy assignments through both ROLE and USER are required or historical;
- the exact current collection/action/field grants held by `$t:public_label`, Manager, and Administrator policies.

These questions require inspection of `public.directus_access` and `public.directus_permissions`, not guesses based on policy names.

## Directus Tables That Must Be Included in Permission Documentation

### Identity / authorization metadata

| Table | Purpose |
|---|---|
| `public.directus_users` | Directus user UUID, email, status, provider, role |
| `public.directus_roles` | role definitions |
| `public.directus_access` | user/role -> policy assignments |
| `public.directus_policies` | policy identity and broad flags such as `admin_access` / `app_access` |
| `public.directus_permissions` | collection/action/field permissions for each policy |

### Directus configuration affecting usable workflows

| Table | Purpose |
|---|---|
| `public.directus_collections` | collection metadata exposed in Directus |
| `public.directus_fields` | field visibility/editability/interface metadata |
| `public.directus_relations` | relationship metadata used by Directus UI/workflows |
| `public.directus_flows` | Directus Flow definitions |
| `public.directus_operations` | operations executed by Directus Flows |

For a Directus-hosted workflow, role/policy membership alone is insufficient documentation. The effective contract may depend on collection/action permissions, field restrictions, relations, Flow definition, and Flow execution context.

## Directus Permission Documentation Standard

For each MSB role/policy used by an application, durable engineering documentation should identify at least:

```text
policy name
assignment source: ROLE or USER
collection
Directus action: read/create/update/delete/share/etc.
field restriction
permission filter
validation filter
presets
reason the permission exists
consumer/workflow that depends on it
```

Where the permission is bootstrap-only, document it as bootstrap rather than ordinary business authorization.

Where a direct USER policy assignment exists in addition to ROLE-derived authority, document whether it is:

```text
required bootstrap access
intentional exception
temporary migration state
or historical/unresolved configuration
```

Do not automatically remove a direct-user assignment merely because the same user also receives a role policy.

## Relationship to the 2026-09-10 Setup Incident

Randy Miller's Setup failure did **not** prove that Directus permissions are unimportant.

For that specific incident:

```text
Cloudflare authentication       PASS
Directus user identity          PASS
Directus Manager authorization  PASS
Setup can_manage_setup          PASS
MSB Person linkage              FAIL
```

After only `ref.person.directus_user_id` was repaired, Randy successfully deleted a Setup task and added a new Setup task. No Directus role/policy/access/collection permission was changed during that repair.

Therefore the root cause of that incident was the Person-link layer, while Directus permissions remain a separate required control plane that must be validated for other failures and Directus-hosted workflows.

## Relationship to Directus User Onboarding

The existing Directus User Onboarding Flow is documented separately in [`Directus_User_Onboarding_Identity_Contract_2026-09-09.md`](Directus_User_Onboarding_Identity_Contract_2026-09-09.md).

The bootstrap access described here explains the minimal access needed for a person to reach Directus and establish a Directus UUID.

The current lifecycle limitation remains separate:

```text
person must reach Directus to establish UID
AND
existing onboarding Person-link branch is gated by provider=google AND role IS NULL
```

Thus the bootstrap policy can be correct while the broader identity lifecycle still has a gap for already-established Directus users whose `ref.person.directus_user_id` is NULL.

## Required Production Evidence Before Permission Changes

Before changing any Directus policy or user assignment, capture read-only Production evidence from:

```text
public.directus_access
public.directus_policies
public.directus_permissions
```

For the relevant policy/user, prove:

- how the policy is assigned (ROLE vs USER);
- whether the policy has `admin_access` or `app_access`;
- every collection/action permission row;
- any field restrictions;
- permission/validation filters and presets; and
- the specific MSB workflow that requires the permission.

Do not remove `$t:public_label`, duplicate Manager assignments, or other user-level policy rows solely because they appear unusual in a flattened report.

## Current Open Documentation Work

The exact Production permission matrix for the bootstrap, Manager, and Administrator policies still needs to be captured and promoted into durable documentation.

Until that evidence is captured, this contract records the confirmed architectural purpose of the bootstrap policy and the required separation of permission layers, but it does not claim the exact effective collection/action grants.

## Related Documents

- [Directus User Onboarding Identity Contract](Directus_User_Onboarding_Identity_Contract_2026-09-09.md)
- [People Manager Directus-Person Link Acceptance Gap](People_Manager_Directus_Person_Link_Acceptance_Gap_2026-09-10.md)
- [People and Identity engineering portal](README.md)
- [Setup engineering authorization/data-consumption contract](../../12_Setup_and_Deployment/engineering/Setup_Data_Consumption_and_Authorization_Contract_2026-09-10.md)
