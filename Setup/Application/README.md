# Setup Session Application

Status: **PRODUCTION RUNTIME OPERATIONAL — 2026 ANNUAL SETUP SESSION LIVE**

The protected application is live at:

```text
https://my.sheboyganlights.org/setup/
```

Production entry point:

```text
Setup/Application/production_backend.py
```

Current reported version and accepted 2026 Scheduling Board application target:

```text
V0.3.17-performance-trace
06a6536d92db5c7352beeed496563ed9bfdb7146
```

The health/version string intentionally remains V0.3.13; #184/#167 extended the durable material/inventory subsystem without starting a new annual Session version line.

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

## Runtime / Rollback

Permanent source checkout:

```text
/opt/msb-setup
```

The accepted 2026 Scheduling Board application target is `06a6536d92db5c7352beeed496563ed9bfdb7146`. Migrations 057/058 and the governed #122 launch deployment tooling established the 2026 launch boundary; later closeout-only commits do not redefine the accepted application target.

Validated rollback archives from #184 and #167 Production deployments are retained under `/home/msbadmin/backups/setup-184/` and `/home/msbadmin/backups/setup-167/`. Do not restore them merely to undo a UI/documentation problem or without reconciling legitimate post-deployment Production work.

## Current Boundaries

The annual Session and Scheduling Board are live. Continue to preserve the boundary between reusable Catalog knowledge and 2026 annual planning/execution. Season-only work belongs in the annual Session unless explicitly promoted to reusable knowledge.

Pick List / early physical material-demand expansion remains owned by #206 / PR #216 and is not part of Scheduling Board closeout. Movement/scanning and park-location semantics remain under their existing owning workstreams.

## Engineering Resume

Before changing the application:

1. read Project Rules;
2. read the Setup engineering README and current handoff;
3. preserve the accepted V0.3.7 through V0.3.13 behavior plus durable #184/#167 inventory state;
4. treat 2026 as the live annual planning/execution Session and 2025 as historical/verification evidence;
5. preserve the accepted Scheduling Board behavior and keep #206 Pick List work in its owning workstream;
6. use Server Management for live runtime and deployment authority.

## Related Documentation

- `Docs/02_Production_Database/01_System_Architecture/12_Setup_and_Deployment/README.md`
- `Docs/02_Production_Database/01_System_Architecture/12_Setup_and_Deployment/engineering/README.md`
- `Docs/02_Production_Database/01_System_Architecture/12_Setup_and_Deployment/engineering/Setup_Session_Production_Engineering_Handoff_2026-09-12.md`
- `Setup/Acceptance/Setup_Kit_Inventory_TPost_Production_Acceptance_2026-09-15.md`
