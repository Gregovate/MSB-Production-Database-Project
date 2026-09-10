# Directus Access and Identity Bootstrap Contract — 2026-09-10

| Document Control | Value |
|---|---|
| Document Type | Engineering Authorization / Identity Bootstrap Contract |
| System | People and Identity / Directus |
| Status | CURRENT — bootstrap purpose and Production policy/action matrix captured; exact long field-list export still pending |
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

Current Production evidence now shows:

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

The Manager matrix spans 43 distinct collections and currently contains:

```text
create  26 rows
read    44 rows
update  33 rows
delete   6 rows
```

The detailed current matrix is authoritative in:

- [`Directus_Production_Permission_Matrix_2026-09-10.md`](Directus_Production_Permission_Matrix_2026-09-10.md)

### Manager description is not an authorization contract

The Manager policy description currently reads:

```text
Manager Read Write and Update No Delete
```

Production nevertheless contains six explicit Manager DELETE rows:

```text
container
directus_comments
directus_presets
display_test_session
work_order_intake
work_order_outbound_message
```

This does not prove those DELETE grants are incorrect; several may be required by their owning workflows. It proves the description is stale/incomplete and must not be used as the effective permission contract.

## What Is Still Not Established

The following must not be inferred without evidence:

- whether every new Directus user receives the bootstrap policy by the same mechanism;
- whether bootstrap policy assignment is intended to remain after later Manager/Administrator authority;
- whether historical users may legitimately retain or lack direct-user bootstrap assignments;
- whether duplicate Manager policy assignments through both ROLE and USER are required or historical;
- the complete untruncated field list for every long Manager permission row.

The 2026-09-10 DBeaver capture proved the collection/action matrix and permission counts, but several long `fields` cells were visibly truncated in pasted output. Full byte-for-byte field restriction documentation therefore still requires a non-truncated export.

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

For a Directus-hosted workflow, role/policy membership alone is insufficient documentation. Effective behavior may depend on collection/action permissions, field restrictions, relations, Flow definition, and Flow execution context.

## Directus Permission Documentation Standard

For each MSB role/policy used by an application, durable engineering documentation must identify at least:

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

Where a direct USER policy assignment exists in addition to ROLE-derived authority, document whether it is required bootstrap access, intentional exception, temporary migration state, or historical/unresolved configuration. Do not automatically remove a direct-user assignment merely because the same user also receives a role policy.

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

For the relevant policy/user, prove how the policy is assigned, whether the policy has `admin_access` or `app_access`, every collection/action permission row, field restrictions, permission/validation filters and presets, and the specific MSB workflow requiring the permission.

Do not remove `$t:public_label`, duplicate Manager assignments, or other user-level policy rows solely because they appear unusual in a flattened report.

## Current Open Work

The collection/action matrix is now captured. Remaining Directus documentation work is:

1. capture untruncated field restrictions for the long Manager permission rows;
2. resolve whether direct USER Manager assignments are still required or historical;
3. document bootstrap assignment/removal lifecycle; and
4. document relevant Directus Flow execution context.

The separate current corrective work is to harden Directus UID -> `ref.person.directus_user_id` reconciliation so future Managers do not require manual repair.

## Related Documents

- [Directus Production Permission Matrix](Directus_Production_Permission_Matrix_2026-09-10.md)
- [Directus User Onboarding Identity Contract](Directus_User_Onboarding_Identity_Contract_2026-09-09.md)
- [People Manager Directus-Person Link Acceptance Gap](People_Manager_Directus_Person_Link_Acceptance_Gap_2026-09-10.md)
- [People and Identity engineering portal](README.md)
- [Setup engineering authorization/data-consumption contract](../../12_Setup_and_Deployment/engineering/Setup_Data_Consumption_and_Authorization_Contract_2026-09-10.md)
