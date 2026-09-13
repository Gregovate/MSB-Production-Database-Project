# Setup Session Application

Status: **PRODUCTION RUNTIME OPERATIONAL — V0.3.13 ASSIGNMENT LAYER ACCEPTED**

The protected application is live at:

```text
https://my.sheboyganlights.org/setup/
```

Production entry point:

```text
Setup/Application/production_backend.py
```

Current reported version and deployed source:

```text
V0.3.13-assignment-layer
3fb975ca355711cece564cfd874cf8d7514310bf
```

## Current Production Meaning

The 2025 Setup Session is real Production data and remains the historical/sandbox proving ground. There is no 2026 Setup Session yet.

Managers/reviewers can maintain reusable tasks, resources, prerequisites, Display/Container material participation, explicit Display ownership for subdivided scopes, and physical Kit Box assignments.

## Accepted Assignment Layer

The established LOR Stage/real-Scene resolver remains authoritative for current Display membership.

```text
LOR resolver
    -> resolved Displays
    -> Setup assignment
        -> one material task = implicit ownership
        -> multiple material tasks = explicit one-owner-per-Display assignment
```

Display Ownership does not rewrite LOR membership or `ref.display.container_id`.

The browser supports multi-select with Ctrl/Cmd-click and Shift-click. Drag remains available, and **Move selected to** provides a reliable path for unusually large ownership boards.

Physical Kit Boxes are existing `ref.container` rows with `container_type_id = 2` and use explicit `relationship_type='KIT'` task assignments. The same Kit Box may support several tasks. Existing SUPPORT / REQUIRED_CONTAINER semantics remain separate.

Expected Kit contents, Extra Materials, quantities/specifications, and material-source meaning remain downstream #167 work.

## Migration Chain

Accepted database migrations:

```text
028_harden_setup_task_display_ownership.sql
029_correct_setup_assignment_layer.sql
030_fix_setup_kit_box_assignment_upsert.sql
```

Initial migration-bearing Production candidate:

```text
48f0a44ca20296f7d211df240f0af7c324ad44e1
```

Current source includes a source-only large-scope UI correction:

```text
3fb975ca355711cece564cfd874cf8d7514310bf
```

No database migration belongs to that follow-up.

## Preservation Baseline

Preserve:

- V0.3.7 dirty-edit/client-build protection;
- V0.3.8 compact task-detail layout;
- V0.3.9 prerequisite behavior;
- V0.3.10 Resource Catalog behavior;
- V0.3.11 persistent active-task identity;
- V0.3.13 assignment/Kit behavior;
- Stage/Scene resolver authority; and
- current analytics/privacy integration.

## Runtime / Rollback

Permanent source checkout:

```text
/opt/msb-setup
```

Current source-only rollback for the large-scope UI correction:

```text
48f0a44ca20296f7d211df240f0af7c324ad44e1
restart only msb-setup.service
```

No PostgreSQL restore belongs to that UI rollback.

The migration-bearing #141 deployment has separate governed database rollback evidence recorded in:

`Setup/Acceptance/Setup_Assignment_Layer_V0313_Production_Acceptance_2026-09-12.md`

## Current Boundaries

Still outside the accepted live workflow:

- structured Extra Materials / expected Kit contents / material-source tracking;
- final reusable Catalog acceptance / disposable 2026 seed proof;
- structured external/site readiness;
- Pick List generation and staged release scheduling;
- Container/Display movement/scanning writes; and
- park-location execution evidence.

## Engineering Resume

Before changing the application:

1. read Project Rules;
2. read the Setup engineering README and current handoff;
3. preserve V0.3.7 through V0.3.13;
4. keep 2025 as the proving ground until the remaining gates pass;
5. continue `#167 -> #145 FINAL -> #122`;
6. use Server Management for live runtime and deployment authority.

## Related Documentation

- `Docs/02_Production_Database/01_System_Architecture/12_Setup_and_Deployment/README.md`
- `Docs/02_Production_Database/01_System_Architecture/12_Setup_and_Deployment/engineering/README.md`
- `Docs/02_Production_Database/01_System_Architecture/12_Setup_and_Deployment/engineering/Setup_Session_Production_Engineering_Handoff_2026-09-12.md`
- `Setup/Acceptance/Setup_Assignment_Layer_V0313_Production_Acceptance_2026-09-12.md`
