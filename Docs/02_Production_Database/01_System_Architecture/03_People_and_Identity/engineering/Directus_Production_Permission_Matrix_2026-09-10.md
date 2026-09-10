# Directus Production Permission Matrix — 2026-09-10

| Document Control | Value |
|---|---|
| Document Type | Production Authorization Evidence / Permission Matrix |
| System | People and Identity / Directus |
| Status | CURRENT PRODUCTION EVIDENCE — policy, collection/action, restricted-field, filter, validation, and preset evidence captured |
| Owner | Production Database / People and Identity |
| Evidence Date | 2026-09-10 |
| Related | `Directus_Access_and_Identity_Bootstrap_Contract_2026-09-10.md`; Issue #130; Setup Issue #122 |

## Purpose

Capture the current Production Directus permission state for the three policies relevant to MSB identity bootstrap and management authorization:

```text
$t:public_label
Manager
Administrator
```

This is read-only Production evidence. It does not authorize permission changes.

## Policy-Level Production State

| Policy | Policy ID | app_access | admin_access | Explicit permission rows | Production interpretation |
|---|---|---:|---:|---:|---|
| `$t:public_label` | `abf8a154-5b1c-4a46-ac9c-7300570f4f17` | true | false | 0 | Operator-confirmed Directus UID/bootstrap access; no explicit collection/action rows |
| `Administrator` | `cb4c7c95-c1f0-4580-940e-0b4309eec60f` | true | true | 0 | Broad Directus authority derives from `admin_access=true`; no explicit collection/action rows |
| `Manager` | `934ea348-8aa8-4465-88c7-b583c09a0fc4` | true | false | 109 | Explicit collection/action permission matrix |

Important distinctions:

- `$t:public_label` and `Administrator` both have zero explicit `public.directus_permissions` rows, but for different reasons.
- `$t:public_label` is the operator-confirmed minimal Directus bootstrap policy used so a person can reach Directus and obtain a Directus UUID.
- `Administrator` has `admin_access=true`; its authority is not represented by a hand-maintained per-collection matrix.
- `Manager` has `admin_access=false` and depends on its explicit permission rows.

## Manager Permission Totals

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

That description is not an accurate contract for current Production because six explicit DELETE permissions exist:

| Collection | Permission ID | Fields | Permission filter |
|---|---:|---|---|
| `container` | `158` | `*` | none |
| `directus_comments` | `13` | `*` | `{"user_created":{"_eq":"$CURRENT_USER"}}` |
| `directus_presets` | `17` | `*` | `{"user":{"_eq":"$CURRENT_USER"}}` |
| `display_test_session` | `129` | `*` | none |
| `work_order_intake` | `131` | `*` | none |
| `work_order_outbound_message` | `142` | `*` | none |

This does not establish that any of those DELETE permissions is wrong. It establishes that the policy description has drifted and cannot be treated as the permission contract.

## Restricted Manager Field Lists

Only the following captured Manager permission rows use an explicit field list rather than `*`. Field order below preserves the Production evidence order.

### `container_test_status` UPDATE — permission 106

```text
container_test_status_name
sort_order
active_flag
container_test_status_code
created_at
created_by
created_by_person_id
updated_at
updated_by
updated_by_person_id
```

### `container_type` UPDATE — permission 33

```text
container_type_name
is_stackable_default
default_width_in
default_depth_in
default_height_in
notes
created_at
created_by
updated_at
updated_by
created_by_person_id
updated_by_person_id
```

### `directus_comments` UPDATE — permission 12

```text
comment
```

### `directus_notifications` UPDATE — permission 22

```text
status
```

### `directus_users` READ — permission 24

```text
id
first_name
last_name
last_page
email
password
location
title
description
tags
provider
preferences_divider
avatar
language
appearance
theme_light
theme_dark
tfa_secret
status
role
```

The row is filtered to the current user's own Directus record; nevertheless `password` and `tfa_secret` are security-significant field names and must remain visible in the documented current state. This document does not infer whether Directus returns usable secret values for those fields or whether the configuration should change.

### `display` UPDATE — permission 35

```text
display_name
created_at
created_by
updated_at
updated_by
created_by_person_id
updated_by_person_id
print_label
label_required
display_status_id
container_id
Display_Status_and_Container_Assigned
year_built
frame_id
designer_id
theme_id
amps_measured
est_light_count
dumb_controller
notes
Display_Details
```

### `display_status` UPDATE — permission 37

```text
display_status_name
description
created_at
updated_at
created_by
updated_by
created_by_person_id
updated_by_person_id
```

### `display_test_session` UPDATE — permission 39

```text
test_session_id
display_test_session_id
is_display_present
test_status
amps_measured
light_count
notes
checked_at
checked_by
checked_date_text
created_at
created_by
updated_at
updated_by
created_by_person_id
checked_by_person_id
updated_by_person_id
```

### `display_test_status` UPDATE — permission 107

```text
test_status_code
sort_order
created_by_person_id
updated_by_person_id
created_at
updated_at
created_by
updated_by
label
```

### `frame` UPDATE — permission 41

```text
frame_name
w_ft
h_ft
created_at
created_by
updated_at
updated_by
created_by_person_id
updated_by_person_id
frame_id
```

### `inventory_type` UPDATE — permission 43

```text
created_at
created_by
created_by_person_id
updated_at
updated_by
updated_by_person_id
inventory_type
```

### `stage` UPDATE — permission 145

```text
created_by_person_id
updated_by_person_id
updated_at
updated_by
park_order
sub_order
created_at
created_by
parent_stage_key
notes
```

### `task_type` UPDATE — permission 108

```text
task_type_key
task_type_name
active_flag
sort_order
notes
created_at
updated_at
created_by_person_id
updated_by_person_id
```

### `test_session` UPDATE — permission 51

```text
container_id
container_test_status_id
home_location_code
display_checks
work_location_code
refresh_requested
notes
done_by
done_at
remaining_notes
tag_state
season_year
legacy_flag
last_refresh_delete_count
last_refresh_add_count
last_refreshed_by_person_id
last_refreshed_at
created_by_person_id
created_at
pulled_by_person_id
pulled_at
updated_by_person_id
updated_at
container_status_legacy
container_search_helper
updated_by
created_by
last_refreshed_by
returned_to_storage_by
pulled_by
returned_to_storage_at
```

### `theme` UPDATE — permission 53

```text
theme_name
updated_at
created_at
created_by
updated_by
additional_info
created_by_person_id
updated_by_person_id
```

### `work_area` UPDATE — permission 112

```text
work_area_key
work_area_name
active_flag
sort_order
notes
created_at
updated_at
created_by_person_id
updated_by_person_id
```

### `work_order` UPDATE — permission 56

```text
stage_id
work_area_id
task_type_id
urgency
target_year
display_id
display_test_session_id
is_active
submitted_by_person_id
submitted_at
urgency_id
problem
notes
photo_url
Problem_Definition
wo_assignments
completion_notes
completed_by_person_id
date_completed
repair_complete
Work_Order_Competion
triage_notes
triaged_by_person_id
triaged_at
updated_by_person_id
updated_at
created_by_person_id
created_at
source_system
source_form_name
display_lor_prop_id
legacy_priority_raw
source_intake_id
created_by
updated_by
Audit_Fields
```

All other captured Manager permission rows use `fields='*'`.

## Manager Permission Filters and Validation Rules

The following Manager permission rows have a non-null permission filter and/or validation rule in Production. Empty JSON object `{}` is preserved because it is explicitly stored state.

| Permission ID | Collection | Action | Permission filter | Validation filter |
|---:|---|---|---|---|
| 9 | `directus_activity` | read | `{"user":{"_eq":"$CURRENT_USER"}}` | none |
| 5 | `directus_collections` | read | `{}` | none |
| 11 | `directus_comments` | create | `{}` | `{"comment":{"_nnull":true}}` |
| 13 | `directus_comments` | delete | `{"user_created":{"_eq":"$CURRENT_USER"}}` | none |
| 10 | `directus_comments` | read | `{"user_created":{"_eq":"$CURRENT_USER"}}` | none |
| 12 | `directus_comments` | update | `{"user_created":{"_eq":"$CURRENT_USER"}}` | none |
| 6 | `directus_fields` | read | `{}` | none |
| 21 | `directus_notifications` | read | `{"recipient":{"_eq":"$CURRENT_USER"}}` | none |
| 22 | `directus_notifications` | update | `{"recipient":{"_eq":"$CURRENT_USER"}}` | none |
| 15 | `directus_presets` | create | `{}` | `{"user":{"_eq":"$CURRENT_USER"}}` |
| 17 | `directus_presets` | delete | `{"user":{"_eq":"$CURRENT_USER"}}` | none |
| 14 | `directus_presets` | read | `{"_or":[{"user":{"_eq":"$CURRENT_USER"}},{"_and":[{"user":{"_null":true}},{"role":{"_eq":"$CURRENT_ROLE"}}]},{"_and":[{"user":{"_null":true}},{"role":{"_null":true}}]}]}` | none |
| 16 | `directus_presets` | update | `{"user":{"_eq":"$CURRENT_USER"}}` | `{"user":{"_eq":"$CURRENT_USER"}}` |
| 7 | `directus_relations` | read | `{}` | none |
| 18 | `directus_roles` | read | `{"id":{"_in":"$CURRENT_ROLES"}}` | none |
| 19 | `directus_settings` | read | `{}` | none |
| 23 | `directus_shares` | read | `{"user_created":{"_eq":"$CURRENT_USER"}}` | none |
| 8 | `directus_translations` | read | `{}` | none |
| 20 | `directus_translations` | read | `{}` | none |
| 24 | `directus_users` | read | `{"id":{"_eq":"$CURRENT_USER"}}` | none |

No non-empty `presets` payload was returned for the Manager policy in this evidence capture.

## Security-Significant Current-State Observations

These observations are recorded for architecture review; they are not automatic change requests.

1. `person` has Manager create/read/update with `fields='*'`. This means Directus Manager permission itself does not protect individual Person fields. Any protected-field behavior in the standalone People Manager application is a separate application/database contract and must not be mistaken for a Directus collection restriction.
2. `directus_users` READ is restricted to the current user's own row, but its allowed field list includes `password` and `tfa_secret`. Do not infer exposure of usable secret material from field names alone; verify Directus runtime behavior before proposing any permission change.
3. Four MSB business collections have unfiltered Manager DELETE rows: `container`, `display_test_session`, `work_order_intake`, and `work_order_outbound_message`.
4. The Manager policy description says `No Delete`, but Production contains six explicit DELETE permission rows. The description is therefore not authoritative.

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

After only the `ref.person.directus_user_id` link was repaired, Randy successfully deleted a Setup task and created a new Setup task. No Directus role, policy, access assignment, or `public.directus_permissions` row was changed for that repair.

This proves the root cause of that incident only. Directus permissions remain an independent control plane for other MSB workflows.

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
