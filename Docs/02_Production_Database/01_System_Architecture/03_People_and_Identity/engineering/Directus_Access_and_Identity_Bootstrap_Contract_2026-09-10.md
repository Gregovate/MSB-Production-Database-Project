# Directus Access and Identity Bootstrap Contract — 2026-09-10

| Document Control | Value |
|---|---|
| Document Type | Engineering Authorization / Identity Bootstrap Contract |
| System | People and Identity / Directus |
| Status | CURRENT — bootstrap purpose and Production permission matrix captured; lifecycle hardening remains open |
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

The stored Directus policy name is:

```text
$t:public_label
```

Operator clarification established its MSB purpose: it is the minimal Directus access configured so a person reaching `db.sheboyganlights.org` can obtain a Directus UID.

Current Production evidence shows:

```text
policy_id                  abf8a154-5b1c-4a46-ac9c-7300570f4f17
app_access                 true
admin_access               false
explicit permission rows  0
```

Therefore the bootstrap policy is not a business-data collection permission set. Its role is Directus application/identity bootstrap. It must not be classified from its translated stored name as accidental permission drift.

Known 2026-09-10 example:

```text
rneerhof@sheboyganlights.org
    Directus role = Manager
    Manager policy via role
    Manager policy via direct user assignment
    $t:public_label via direct user assignment
```

The presence of `$t:public_label` on this user is not, by itself, evidence of an authorization defect.

## Production Policy-Level Permission State — 2026-09-10

Read-only Production inspection established:

| Policy | app_access | admin_access | Explicit `directus_permissions` rows | Meaning |
|---|---:|---:|---:|---|
| `$t:public_label` | true | false | 0 | UID/bootstrap access; no explicit collection/action grants |
| `Administrator` | true | true | 0 | broad Directus authority derives from `admin_access=true` |
| `Manager` | true | false | 109 | explicit collection/action permission matrix |

The Manager matrix spans 43 distinct collections:

```text
create  26 rows
read    44 rows
update  33 rows
delete   6 rows
```

The detailed current matrix, including exact restricted field lists, permission filters, validation rules, and preset evidence, is authoritative in:

- [`Directus_Production_Permission_Matrix_2026-09-10.md`](Directus_Production_Permission_Matrix_2026-09-10.md)

The Manager policy description currently says:

```text
Manager Read Write and Update No Delete
```

Production nevertheless contains six explicit Manager DELETE rows. This does not prove the deletes are wrong; it proves the description is stale and must not be treated as the authorization contract.

## Current Permission Evidence Status

The 2026-09-10 Production capture now includes:

- policy IDs and `app_access` / `admin_access` state;
- assignment evidence through `public.directus_access`;
- all 109 Manager collection/action rows;
- all 17 restricted-field Manager permission rows exploded to one field per row so long lists are not truncated;
- every Manager permission row with a non-null permission filter and/or validation rule; and
- confirmation that no non-empty Manager `presets` payload was returned in the evidence capture.

This closes the earlier documentation gap around the exact Production Manager permission matrix.

Security-significant current-state observations are recorded, not automatically changed:

- Manager `person` create/read/update uses `fields='*'`;
- Manager `directus_users` READ is limited to the current user but its permitted field list includes `password` and `tfa_secret` field names;
- four MSB business collections have unfiltered Manager DELETE permission rows; and
- the Manager policy description is not consistent with the actual DELETE matrix.

Any proposed permission correction requires separate workflow validation and a Production change gate.

## What Is Still Not Established

The following lifecycle/configuration questions remain open and must not be guessed from the permission matrix:

- whether every new Directus user receives the bootstrap policy by the same mechanism;
- whether bootstrap policy assignment is intended to remain after later Manager/Administrator authority;
- whether historical users may legitimately retain or lack direct-user bootstrap assignments;
- whether duplicate Manager policy assignments through both ROLE and USER are required or historical; and
- the exact trigger and execution/accountability context of the Directus User Onboarding Flow.

These are lifecycle-hardening questions, not missing permission-row documentation.

## Directus Tables That Must Remain in the Authorization Documentation

### Identity / authorization metadata

| Table | Purpose |
|---|---|
| `public.directus_users` | Directus user UUID, email, status, provider, role |
| `public.directus_roles` | role definitions |
| `public.directus_access` | user/role -> policy assignments |
| `public.directus_policies` | policy identity and broad flags such as `admin_access` / `app_access` |
| `public.directus_permissions` | collection/action/field permissions for each policy |

### Directus configuration affecting workflows

| Table | Purpose |
|---|---|
| `public.directus_collections` | collection metadata exposed in Directus |
| `public.directus_fields` | field visibility/editability/interface metadata |
| `public.directus_relations` | relationship metadata used by Directus UI/workflows |
| `public.directus_flows` | Directus Flow definitions |
| `public.directus_operations` | operations executed by Directus Flows |

For a Directus-hosted workflow, role/policy membership alone is insufficient documentation. Effective behavior may depend on collection/action permissions, field restrictions, relations, Flow definition, trigger, and Flow execution context.

## Relationship to the 2026-09-10 Setup Incident

Randy Miller's Setup failure did not prove Directus permissions are unimportant.

For that specific incident:

```text
Cloudflare authentication       PASS
Directus user identity          PASS
Directus Manager authorization  PASS
Setup can_manage_setup          PASS
MSB Person linkage              FAIL
```

After only `ref.person.directus_user_id` was repaired, Randy successfully deleted a Setup task and added a new Setup task. No Directus role/policy/access/collection permission was changed during that repair.

Therefore the root cause of that incident was the Person-link layer, while Directus permissions remain a separate required control plane for other failures and Directus-hosted workflows.

## Relationship to Directus User Onboarding

The existing Directus User Onboarding Flow is documented separately in [`Directus_User_Onboarding_Identity_Contract_2026-09-09.md`](Directus_User_Onboarding_Identity_Contract_2026-09-09.md).

The bootstrap access described here explains the minimal access needed for a person to reach Directus and establish a Directus UUID.

The current lifecycle limitation remains:

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

For the relevant policy/user, prove how the policy is assigned, whether the policy has `admin_access` or `app_access`, every collection/action permission row, field restrictions, permission/validation filters and presets, and the specific MSB workflow requiring the permission.

Do not remove `$t:public_label`, duplicate Manager assignments, or other user-level policy rows solely because they appear unusual in a flattened report.

## Current Open Work

The Directus permission matrix is now documented. The remaining current corrective work is lifecycle hardening:

1. establish the exact Directus User Onboarding Flow trigger and execution/accountability context;
2. establish how the bootstrap policy is assigned and whether/when it is removed;
3. resolve whether direct USER Manager assignments are intentional or historical;
4. design a deterministic Directus UID -> existing `ref.person.directus_user_id` reconciliation mechanism that does not require manual repair; and
5. add acceptance proving first-onboarding linkage, established-user reconciliation, conflict failure, and population-wide mapping health.

## Related Documents

- [Directus Production Permission Matrix](Directus_Production_Permission_Matrix_2026-09-10.md)
- [Directus User Onboarding Identity Contract](Directus_User_Onboarding_Identity_Contract_2026-09-09.md)
- [People Manager Directus-Person Link Acceptance Gap](People_Manager_Directus_Person_Link_Acceptance_Gap_2026-09-10.md)
- [People and Identity engineering portal](README.md)
- [Setup engineering authorization/data-consumption contract](../../12_Setup_and_Deployment/engineering/Setup_Data_Consumption_and_Authorization_Contract_2026-09-10.md)
