# Directus Production Permission Matrix — 2026-09-10

| Document Control | Value |
|---|---|
| Document Type | Production Authorization Evidence / Permission Matrix |
| System | People and Identity / Directus |
| Status | CURRENT PRODUCTION EVIDENCE — collection/action matrix captured; exact long field lists require non-truncated export |
| Owner | Production Database / People and Identity |
| Evidence Date | 2026-09-10 |
| Related | `Directus_Access_and_Identity_Bootstrap_Contract_2026-09-10.md`; Issue #130; Setup Issue #122 |

## Purpose

Capture the current Production Directus permission state for the three policies relevant to MSB bootstrap and management authorization:

```text
$t:public_label
Manager
Administrator
```

This is a read-only Production evidence record. It does not authorize permission changes.

## Policy-Level Production State

| Policy | Policy ID | app_access | admin_access | Explicit permission rows | Production interpretation |
|---|---|---:|---:|---:|---|
| `$t:public_label` | `abf8a154-5b1c-4a46-ac9c-7300570f4f17` | true | false | 0 | Operator-confirmed Directus UID/bootstrap access; no explicit collection/action rows |
| `Administrator` | `cb4c7c95-c1f0-4580-940e-0b4309eec60f` | true | true | 0 | Broad Directus authority derives from `admin_access=true`; no explicit collection/action rows |
| `Manager` | `934ea348-8aa8-4465-88c7-b583c09a0fc4` | true | false | 109 | Explicit collection/action permission matrix |

Important distinction:

- `$t:public_label` and `Administrator` both have zero explicit `public.directus_permissions` rows, but for different architectural reasons.
- `$t:public_label` is operator-confirmed minimal Directus bootstrap access used so a person can reach Directus and obtain a Directus UUID.
- `Administrator` has `admin_access=true`; its broad authority is not represented by per-collection permission rows.
- `Manager` has `admin_access=false` and therefore depends on its explicit permission matrix.

## Manager Permission Totals

Current Production `Manager` policy:

```text
explicit permission rows = 109
distinct collections      = 43
create rows               = 26
read rows                 = 44
update rows               = 33
delete rows               = 6
```

## Manager Collection / Action Matrix

| Collection | Explicit actions | Permission rows |
|---|---|---:|
| `container` | create, read, update, delete | 4 |
| `container_endpoint` | create, read, update | 3 |
| `container_test_status` | read, update | 2 |
| `container_type` | create, read, update | 3 |
| `controller` | create, read, update | 3 |
| `controller_display` | create, read, update | 3 |
| `controller_firmware_history` | create, read, update | 3 |
| `controller_firmware_version` | create, read, update | 3 |
| `controller_model` | create, read, update | 3 |
| `controller_status` | create, read, update | 3 |
| `directus_activity` | read | 1 |
| `directus_collections` | read | 1 |
| `directus_comments` | create, read, update, delete | 4 |
| `directus_fields` | read | 1 |
| `directus_notifications` | read, update | 2 |
| `directus_presets` | create, read, update, delete | 4 |
| `directus_relations` | read | 1 |
| `directus_roles` | read | 1 |
| `directus_settings` | read | 1 |
| `directus_shares` | read | 1 |
| `directus_translations` | read | 2 |
| `directus_users` | read | 1 |
| `display` | read, update | 2 |
| `display_status` | read, update | 2 |
| `display_test_session` | read, update, delete | 3 |
| `display_test_status` | read, update | 2 |
| `frame` | create, read, update | 3 |
| `inventory_type` | create, read, update | 3 |
| `person` | create, read, update | 3 |
| `stage` | read, update | 2 |
| `storage_location` | create, read, update | 3 |
| `task_type` | create, read, update | 3 |
| `test_session` | create, read, update | 3 |
| `theme` | create, read, update | 3 |
| `urgency` | create, read, update | 3 |
| `work_area` | create, read, update | 3 |
| `work_order` | create, read, update | 3 |
| `work_order_assignment` | create, read, update | 3 |
| `work_order_intake` | create, read, update, delete | 4 |
| `work_order_intake_assignment` | create, read, update | 3 |
| `work_order_outbound_message` | create, read, update, delete | 4 |
| `work_order_status` | create, read, update | 3 |
| `work_order_status_history` | read | 1 |

## Explicit Manager DELETE Permissions

The Manager policy description currently reads:

```text
Manager Read Write and Update No Delete
```

That description is **not an accurate statement of the current Production permission matrix** because six explicit DELETE permissions exist.

This finding does not, by itself, mean the DELETE grants are incorrect. Each may be intentional for the owning workflow. It means the policy description cannot be treated as the authorization contract.

| Collection | Permission ID | Fields | Permission filter |
|---|---:|---|---|
| `container` | `158` | `*` |  |
| `directus_comments` | `13` | `*` | `{"user_created":{"_eq":"$CURRENT_USER"}}` |
| `directus_presets` | `17` | `*` | `{"user":{"_eq":"$CURRENT_USER"}}` |
| `display_test_session` | `129` | `*` |  |
| `work_order_intake` | `131` | `*` |  |
| `work_order_outbound_message` | `142` | `*` |  |

Interpretation of the two filtered Directus-system deletes:

- `directus_comments` DELETE is limited to rows whose `user_created` is `$CURRENT_USER`.
- `directus_presets` DELETE is limited to rows whose `user` is `$CURRENT_USER`.

The remaining four captured DELETE rows have no permission filter in the Production evidence:

```text
container
display_test_session
work_order_intake
work_order_outbound_message
```

Do not remove or change any of these without validating the owning workflows and current Production behavior.

## Directus System-Collection Permissions Present for Manager

The Production Manager policy also includes Directus system collection permissions needed for ordinary Directus application behavior, including:

```text
directus_activity
directus_collections
directus_comments
directus_fields
directus_notifications
directus_presets
directus_relations
directus_roles
directus_settings
directus_shares
directus_translations
directus_users
```

Several are constrained to the current user. Examples captured in Production include:

- `directus_activity` read: `{"user":{"_eq":"$CURRENT_USER"}}`
- `directus_comments` read/update/delete: current user's own comments
- `directus_notifications` read/update: current recipient
- `directus_presets` create/update/delete: current user
- `directus_roles` read: IDs in `$CURRENT_ROLES`
- `directus_users` read: current user's own row, with an explicit field list

These system permissions are part of usable Directus Manager behavior and must not be confused with MSB business-table permissions.

## MSB Business Collections Explicitly Present for Manager

The captured Production Manager matrix includes these MSB business collections:

```text
container
container_endpoint
container_test_status
container_type
controller
controller_display
controller_firmware_history
controller_firmware_version
controller_model
controller_status
display
display_status
display_test_session
display_test_status
frame
inventory_type
person
stage
storage_location
task_type
test_session
theme
urgency
work_area
work_order
work_order_assignment
work_order_intake
work_order_intake_assignment
work_order_outbound_message
work_order_status
work_order_status_history
```

The permission action set varies by collection and is authoritative only as represented in the current Production `public.directus_permissions` rows.

## Field / Filter / Validation Evidence Boundary

The 2026-09-10 DBeaver result captured `fields`, `permissions`, `validation`, and `presets`, but several long `fields` cells were visibly truncated in the pasted output, including at least:

```text
display UPDATE
test_session UPDATE
work_order UPDATE
```

Therefore this document **does not yet claim a complete byte-for-byte field restriction inventory** for those long rows.

The collection/action matrix and permission-row counts above are complete for the captured result, but the remaining acceptance step for full permission documentation is a non-truncated export of every Manager permission row's:

```text
permission_id
collection
action
fields
permissions
validation
presets
```

Do not reconstruct missing field names from source code or Directus UI assumptions.

## Relationship to Randy Miller Setup Incident

Randy Miller's 2026-09-10 Setup failure was not caused by this Manager permission matrix.

Before repair:

```text
Cloudflare authentication       PASS
Directus UID                    PASS
Manager authorization           PASS
Setup can_manage_setup          PASS
ref.person.directus_user_id     MISSING
```

After only the `ref.person.directus_user_id` link was repaired, Randy successfully deleted a Setup task and created a new Setup task.

No Directus role, policy, access assignment, or `public.directus_permissions` row was changed for that operational repair.

This proves only the root cause of that incident. It does not reduce the importance of Directus permission documentation for other MSB workflows.

## Required Ongoing Rule

For any Directus permission problem or proposed permission change:

1. identify the exact policy and how it is assigned through `public.directus_access`;
2. inspect the exact `public.directus_permissions` collection/action row;
3. inspect fields, permission filter, validation filter, and presets;
4. identify the owning MSB workflow;
5. validate current PostgreSQL privileges separately;
6. do not infer permissions from policy descriptions alone; and
7. capture post-change read-only evidence.

## Related Documents

- [Directus Access and Identity Bootstrap Contract](Directus_Access_and_Identity_Bootstrap_Contract_2026-09-10.md)
- [Directus User Onboarding Identity Contract](Directus_User_Onboarding_Identity_Contract_2026-09-09.md)
- [People Manager Directus-Person Link Acceptance Gap](People_Manager_Directus_Person_Link_Acceptance_Gap_2026-09-10.md)
- [People and Identity engineering portal](README.md)
