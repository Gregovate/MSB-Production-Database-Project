# Setup Session Application

## #88 guided contents reconciliation candidate

[Implementation, reconnaissance, verification and exact-candidate review handoff](../Acceptance/Setup_88_Contents_Reconciliation_Candidate.md).
V0.3.45 reuses existing movement/event tables with function-only migration 070.
The accepted Stage-group **What came off here?** unload remains available alongside
prior-location reconciliation for missed unloads. Each path names its location basis.
Stage rows/counts stay compact; Display Names expand on demand. A persistent
selection/action dock and focused review keep selected groups visible. Contents
checking opens separately; Display Name filtering preserves remaining selections
across hidden rows. Current-clone/browser acceptance and Production deployment
remain pending.


For a reviewed update or urgent fix, use [Install a reviewed Setup change](../operatorSOP/Install_a_Reviewed_Setup_Change.md). It explains the checks, maintenance window, STOP result and required documentation closeout.

Status: **PRODUCTION RUNTIME OPERATIONAL — 2026 ANNUAL SETUP SESSION LIVE**

The protected application is live at:

```text
https://my.sheboyganlights.org/setup/
```

Production entry point:

```text
Setup/Application/production_backend.py
```

Current reported version and Production application target:

```text
V0.3.22-pick-list-delay
6f53d7f0c4b15f7175e773a2069595eef3f0e698
```

The visible Production version is `V0.3.22-pick-list-delay`. #206 adds the accepted bounded material frontier and transient Manager Pick Delay behavior on top of the #205 Scheduling Board release. Persisted physical PICKED/movement execution remains owned by #88.

## Current Production Meaning

The 2025 Setup Session remains historical/verification evidence. The real 2026 Setup Session has now been created and is the active annual planning/scheduling context.

Managers/reviewers can maintain reusable tasks, resources, prerequisites, Display/Container material participation, explicit Display ownership, physical Kit Box assignments, and structured reusable-task Extra Material requirements.

Durable inventory routes are live:

```text
/setup/kit-inventory/
/setup/t-post-inventory/
```

## Durable Material / Inventory Contract

Keep four facts separate:

```text
reusable task requirement
expected Container / Kit content or source
physical inventory balance/history
current Display -> Container membership
```

The normalized catalog is `ref.setup_extra_material`. Reusable task requirements live in `ref.setup_task_extra_material`; expected source allocations in `ref.setup_task_extra_material_source`; expected Container contents in `ref.setup_container_extra_material`; durable Remainders in `ref.setup_container_extra_material_review`; physical changes in append-only `ops.setup_extra_material_inventory_event`; and current balance through `ops.setup_extra_material_inventory_balance`.

Task-to-Kit authority remains `ref.setup_task_container_support` with `relationship_type='KIT'`. Current physical Display contents remain `ref.display.container_id` truth.

Kit Inventory covers all physical Kit Boxes and exposes task assignment, current Displays, expected Extra Materials, Remainders, physical balances, and inventory history without collapsing those concepts.

T-Post Inventory uses the same physical inventory ledger while grouping shared/bulk stock separately from T-Posts intentionally stored with Kits/Displays. Physical storage does not create or alter reusable task requirements.

## Accepted Reconstruction

The one-time #167 reconstruction is complete in Production. It loaded procedure-derived task requirements, expected Kit contents, Remainders, T-Post requirements, and stock variants as `UNVERIFIED` / `NEEDS_REVIEW` where appropriate.

The reconstruction created no 2026 Setup Session and no fabricated physical inventory events. Existing Production task-to-Kit assignments remained authoritative and unchanged.

## Migration Chain

Accepted durable foundation / reconstruction migrations now include:

```text
028_harden_setup_task_display_ownership.sql
029_correct_setup_assignment_layer.sql
030_fix_setup_kit_box_assignment_upsert.sql
031_fix_setup_task_resource_upsert.sql
032_add_setup_extra_material_schema.sql
033_add_setup_extra_material_manager_commands.sql
034_add_setup_extra_material_container_commands.sql
035_add_setup_extra_material_inventory_commands.sql
036_seed_setup_extra_material_catalog.sql
037_harden_setup_extra_material_duplicate_rows.sql
038_preload_setup_extra_material_known_evidence.sql
043_preload_setup_kit_inventory_and_tpost_stock.sql
044_preload_elf_choir_tpost_requirement.sql
045_preload_reviewed_kit_assignments.sql
046_preload_explicit_tpost_requirements.sql
047_finalize_assigned_kit_inventory_coverage.sql
048_complete_tpost_requirements_and_stock_variants.sql
059_sync_reusable_task_name_to_open_annual.sql
060_add_setup_pick_list_manager_override.sql
061_add_live_assignment_report_work.sql
062_add_setup_context_work_order_intake.sql
063_add_setup_pick_list_delay.sql
```

#184 is the durable model/runtime; #167 is the completed one-time data reconstruction only.

## Preservation Baseline

Preserve:

- V0.3.7 dirty-edit/client-build protection;
- V0.3.8 compact task-detail layout;
- V0.3.9 prerequisite behavior;
- V0.3.10 Resource Catalog behavior plus migration 031 repair;
- V0.3.11 persistent active-task identity;
- V0.3.13 Display ownership / physical Kit assignment;
- durable task Extra Materials, Kit expected contents/Remainders, append-only inventory, Kit Inventory, and T-Post Inventory;
- Stage/Scene resolver authority; and
- current analytics/privacy integration.

## Production Report Correction — #172

The live **Perform Work** surface now includes **Report Correction** for authenticated Production Crew / Managers.

Report Correction preserves the exact scheduled-assignment context, prepares the authoritative Setup provenance through PostgreSQL, and creates a **Submitted** Work Order Intake item through the existing Directus Items API. The current Directus `items.create` notification Flow remains the Manager-triage notification boundary.

Report Correction does not directly create an active Work Order and does not grant field operators reusable-Catalog, Kit, Procedure, LOR, scheduling, or other Manager mutation authority.

Production acceptance is recorded in:

`Setup/Acceptance/Setup_172_Report_Correction_Production_Acceptance_2026-09-27.md`

## Runtime / Rollback

Permanent source checkout:

```text
/opt/msb-setup
```

The current exact Production application target is `6f53d7f0c4b15f7175e773a2069595eef3f0e698`. The accepted Pick Delay migration `063_add_setup_pick_list_delay.sql` is installed in addition to migrations through 062. Later merge, deployment-tooling, or closeout-only commits do not redefine the deployed application target.

The #206 V0.3.22 validated rollback archive is `/home/msbadmin/backups/setup-206/msb-pre-setup-206-v0322-pick-list-delay-20260930T091257.dump` with SHA256 `1415868b93bca4b0ad073b65d741087f34851d134dd8ce18346cce45061154af`. The #172 rollback archive and older accepted rollback archives remain historical recovery evidence. Do not restore any database archive without reconciling legitimate post-deployment Production work.

## Current Boundaries

The annual Session and Scheduling Board are live. Continue to preserve the boundary between reusable Catalog knowledge and 2026 annual planning/execution. Season-only work belongs in the annual Session unless explicitly promoted to reusable knowledge.

#206 Pick List demand/frontier and transient Pick Delay are now Production accepted. Persisted physical pick/movement events belong to #88, scanner/tablet capture plumbing to #113, GIS/location interpretation to #171, and Manager reference/Home Location maintenance to #230.

## Engineering Resume

Before changing the application:

1. read Project Rules;
2. read the Setup engineering README and current handoff;
3. preserve the accepted V0.3.7 through V0.3.13 behavior plus durable #184/#167 inventory state;
4. treat 2026 as the live annual planning/execution Session and 2025 as historical/verification evidence;
5. preserve the accepted Scheduling Board, Perform Work / Report Work, and Report Correction -> Work Order Intake boundaries;
6. preserve #206 Pick List/Pick Delay as accepted Production behavior and put persisted physical pick/movement execution under #88; and
7. use Server Management for live runtime and deployment authority.

## Related Documentation

- `Docs/02_Production_Database/01_System_Architecture/12_Setup_and_Deployment/README.md`
- `Docs/02_Production_Database/01_System_Architecture/12_Setup_and_Deployment/engineering/README.md`
- `Docs/02_Production_Database/01_System_Architecture/12_Setup_and_Deployment/engineering/Setup_Session_Production_Engineering_Handoff_2026-09-12.md`
- `Setup/Acceptance/Setup_206_V0322_Pick_List_Delay_Production_Acceptance_2026-09-30.md`
- `Setup/Acceptance/Setup_205_Scheduling_Board_Production_Acceptance_2026-09-29.md`
- `Setup/Acceptance/Setup_172_Report_Correction_Production_Acceptance_2026-09-27.md`
- `Setup/Acceptance/Setup_Kit_Inventory_TPost_Production_Acceptance_2026-09-15.md`
