# Setup and Deployment Engineering

| Document Control | Value |
|---|---|
| Document Type | Engineering Handoff Portal |
| System | Production Database — Setup and Deployment |
| Audience | Greg, maintainers, database administrators, future engineering sessions |
| Status | CURRENT HANDOFF — V0.3.13 accepted; #152 resource write repair accepted in Production |
| Owner | MSB Production Database engineering |
| Last Reviewed | 2026-09-13 |

Operator-facing instructions are separate under [`../operatorSOP/`](../operatorSOP/README.md).

## Current Production State

```text
protected application = https://my.sheboyganlights.org/setup/
live /opt/msb-setup SHA = 3fb975ca355711cece564cfd874cf8d7514310bf
version = V0.3.13-assignment-layer
2025 Setup Session = HISTORICAL_VERIFICATION / SANDBOX
2026 Setup Sessions = 0
```

V0.3.13 preserves the accepted V0.3.7 through V0.3.11 baseline and adds the #141 task-material assignment layer. Migration 031 is the accepted database-only correction for the #152 task-resource upsert regression; it does not change the application SHA/version.

## Accepted #141 Assignment Contract

The existing LOR Stage/real-Scene resolver remains authoritative for the current Display source set.

```text
LOR resolver
    -> current resolved Displays
    -> Setup assignment layer
        -> simple one-material-task scope = implicit ownership
        -> multi-task scope = each resolved Display has one effective reusable task owner
```

Managers use the Catalog **Uses Display / Container Material** checkbox to identify participating tasks. In multi-task scopes, **Display Ownership** provides explicit assignment. Ctrl/Cmd-click and Shift-click support multi-select; drag works for ordinary scopes; **Move selected to** provides a reliable non-drag path for unusually large boards.

Display Ownership never rewrites LOR membership or `ref.display.container_id`.

Physical Kit Boxes are existing `ref.container` rows with `container_type_id = 2`. Reusable task -> Kit assignment is explicit many-to-many using `ref.setup_task_container_support` with `relationship_type='KIT'`. Existing SUPPORT and REQUIRED_CONTAINER meanings remain separate.

The same Kit Box may support several reusable tasks. #141 assigns the physical Kit Box; #167 owns expected contents, Extra Materials, quantities/specifications, and source meaning.

## Resource Catalog Write Repair — #152

Real Production use exposed a PL/pgSQL ambiguity in the migration-027 recreation of `ref.set_setup_task_resource(...)`. Migration 031 restores the named `pk_setup_task_resource` conflict target while preserving the existing governed command, inactive-resource behavior, actor/audit boundary, and least privilege.

Production acceptance passed with:

```text
exact candidate regression = 256 passed
post-migration function/privilege contract = PASS
governed Setup fingerprint unchanged = PASS
live Setup SHA/version unchanged = PASS
protected Production SkyTrak assignment persistence = PASS
```

Normal authorized Equipment / Resource Add/Update/Remove operations are accepted again. See [Setup Resource Upsert Repair Production Acceptance](../../../../../Setup/Acceptance/Setup_Resource_Upsert_Repair_Production_Acceptance_2026-09-13.md).

Independent follow-up: #181 owns resource-search typo tolerance/match ranking. Server Management #37 owns a future governed Setup maintenance/write-freeze mode.

## Production Evidence

Initial migration-bearing V0.3.13 candidate:

```text
48f0a44ca20296f7d211df240f0af7c324ad44e1
migrations 028 -> 029 -> 030
```

Current source-only large-scope correction:

```text
3fb975ca355711cece564cfd874cf8d7514310bf
```

Current database repair added after that accepted source baseline:

```text
031_fix_setup_task_resource_upsert.sql
```

Final protected Production browser acceptance for #141 passed on the real Candyland scope and showed **Coverage complete**. Final protected Production browser acceptance for the #152 repair proved a legitimate `SkyTrak` task Resource assignment persisted after close/reopen.

## Preservation Baseline

Preserve:

```text
V0.3.7  dirty-edit/client-build safety
V0.3.8  compact task-detail layout
V0.3.9  Shift-drag prerequisite + canonical prerequisite editor
V0.3.10 reusable Resource Catalog
031      task-resource upsert named-constraint repair
V0.3.11 persistent active-task identity
V0.3.13 Display ownership + physical Kit Box assignment
```

Also preserve the Stage/Scene resolver, 2025 historical/sandbox boundary, current Display/Container authority, narrow governed write commands, existing analytics integration/privacy boundary, and no real 2026 Session until launch gates pass.

## Remaining Launch Sequence

#141 and the corrective #152 repair are complete. The controlling sequence returns to:

```text
#167  Extra Materials / KIT contents / material-source foundation
  -> #145 FINAL reusable-Catalog acceptance + disposable 2026 seed proof
  -> #122 real 2026 Setup Session + scheduling / Pick List launch gate
```

#167 may legitimately add/split/correct reusable tasks. #145 is the final content/seed acceptance gate after that work, not unfinished Catalog-management software.

## Runtime / Rollback

Current source-only rollback for the large-scope UI correction:

```text
48f0a44ca20296f7d211df240f0af7c324ad44e1
restart only msb-setup.service
```

No PostgreSQL restore belongs to that UI rollback.

The migration-bearing #141 deployment and migration-031 #152 repair each have separate governed database rollback evidence recorded in their Production acceptance records. Do not use those database archives to undo a UI problem or without reconciling legitimate post-deployment Production work.

## Resume Checklist

Before the next Setup change:

1. refresh current remote `main` and record exact HEAD;
2. read Project Rules and this engineering portal;
3. read `Setup_Session_Production_Engineering_Handoff_2026-09-12.md`;
4. read `Setup_Task_Supporting_Information_Contract_2026-09-11.md`;
5. preserve accepted V0.3.7 through V0.3.13 behavior plus migration 031;
6. keep 2025 as the proving ground until the remaining launch gates pass;
7. continue with `#167 -> #145 FINAL -> #122`;
8. use `Gregovate/MSB-Server-Management` for runtime/deployment/browser-review authority; and
9. update controlled docs and acceptance evidence whenever accepted behavior or the resume point changes.

## Related Systems

- [Setup operator portal](../README.md)
- [Operator procedures](../operatorSOP/README.md)
- [Detailed Manager Review Guide](../../../02_Operational_SOPs/Setup/Setup_Session_Manager_Review_Guide.md)
- [Setup Resource Upsert Repair Production Acceptance](../../../../../Setup/Acceptance/Setup_Resource_Upsert_Repair_Production_Acceptance_2026-09-13.md)
- [Setup Assignment Layer V0.3.13 Production Acceptance](../../../../../Setup/Acceptance/Setup_Assignment_Layer_V0313_Production_Acceptance_2026-09-12.md)
