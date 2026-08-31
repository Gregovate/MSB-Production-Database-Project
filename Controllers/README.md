# Controller Inventory — Bootstrap Engineering Artifacts

Status: **HISTORICAL BOOTSTRAP COMPLETE — PERMANENT CONTROLLER IDS ACCEPTED — DO NOT RESET**

Issue: #110

Current operational authority is:

- `Docs/02_Production_Database/01_System_Architecture/08_Controller_Inventory/README.md`
- `Docs/02_Production_Database/01_System_Architecture/08_Controller_Inventory/Controller_Management_Application_Boundary_2026-08-31.md`
- `Docs/02_Production_Database/01_System_Architecture/08_Controller_Inventory/Controller_Inventory_Operational_Implementation_Roadmap_2026-08-31.md`

This `Controllers/` area preserves the bootstrap source, reconciliation evidence, database scripts, diagnostics, migrations, and acceptance artifacts used to create the permanent Controller Inventory. It is no longer the current operational handoff.

## Accepted Permanent State

The initial Controller Inventory bootstrap is complete and permanent identity has been accepted:

```text
177 permanent physical controllers
controller_id range 1001-1177
permanent authority ref.controller.controller_id
```

Permanent IDs must not be reset or reused.

The former experimental reset path is retired. `Database/006_reset_experimental_controller_data.sql` is historical PRE-ACCEPTANCE tooling and must not be used against the accepted permanent Controller Inventory.

Permanent Controller labels are no longer blocked merely because the original identity set was experimental. Current label behavior is governed by the operational Controller Inventory and labeling documentation.

## Historical Source Facts

The bootstrap evidence was:

- `Controller Inventory & Testing 2026(7).xlsx`
- `lor_output_v7_scene(20260830-185521).db`
- generated reconciliation CSV for those two artifacts

The workbook contained **177 deployed controllers and no spare/available controllers**.

Initial reconciliation result:

- 177 deployed-controller candidates
- 152 direct V7 Display-name matches
- 25 candidates requiring review
- 172 recorded firmware versions
- 5 firmware values requiring verification (`???`, `New`, or blank)

These values describe the initial reconstruction process, not the current operational inventory workflow.

## Identity Rule

Permanent identity is only:

```text
ref.controller.controller_id
```

The first permanent Controller ID is **1001**.

Network/UID/channel/IP/universe, Display name, Stage, Scene, spreadsheet row, workbook text, and other source evidence are not permanent physical identity.

## Historical Bootstrap Boundary

Temporary reconstruction used the already-established `stage` schema:

```text
stage.controller_bootstrap
stage.controller_bootstrap_display
stage.v_controller_bootstrap_review
```

No permanent `controller_id` existed in stage.

The complete initial reconstruction, Display resolution, year backfill, duplicate-address review, and proposed 1001+ ordering were completed in `stage.*` before accepted promotion into permanent `ref.controller*`.

The stage objects were engineering scaffolding only and are not operational Controller Inventory authority.

## Historical Database Sequence

The original controlled bootstrap sequence was:

1. `Database/001_create_stage_controller_bootstrap.sql`
   - create disposable staging/review layer
   - allocate no controller IDs

2. validate/load generated reconciliation with:

   ```text
   Bootstrap/load_controller_reconciliation_csv.py
   ```

3. `Database/003_prepare_controller_bootstrap.sql`
   - resolve exact permanent Display-name matches
   - derive initial deployment-year evidence
   - create review/order preparation structures

4. `Database/005_validate_controller_bootstrap.sql`
   - stage-only validation/review

5. resolve remaining staging cases and accepted repeated-address/duplicated-channel cases

6. run `stage.prepare_controller_bootstrap_order()` only after all physical-controller rows were READY/SKIPPED

7. review the complete proposed 1001+ order while still in stage

8. `Database/002_create_ref_controller_sandbox.sql`
   - create permanent-shaped empty Controller tables

9. `Database/004_promote_controller_bootstrap.sql`
   - controlled all-or-nothing promotion
   - verify generated IDs match reviewed proposed IDs

10. post-promotion validation and explicit acceptance of permanent identities

This sequence is retained as engineering history. It is **not** the normal Add Controller workflow.

## Retired Experimental Reset

`Database/006_reset_experimental_controller_data.sql` was PRE-ACCEPTANCE ONLY.

Permanent Controller identities are now accepted and external systems already consume `ref.controller*`. Do not run the reset/restart workflow and do not reuse Controller IDs.

## Label Fields

`ref.controller` uses the established label-state pattern:

```text
label_required
print_label
label_print_count_cached
label_print_last_at_cached
label_print_last_by_cached_id
label_template_id
```

`label_template_id` references the existing `ref.label_template.label_template_id` authority.

No new `label_id`, `label_type_id`, or Controller-specific template table is authorized.

Current Manager label-request behavior belongs in the browser-native Controller Management workflow. Actual printer handoff remains governed by the existing labeling subsystem.

## Current Operational Direction

The initial bootstrap is closed. Current work is not staging reconstruction.

The accepted next phase is browser-native Controller Management using the already-working Controller Inventory / FieldWiring read experience as the foundation:

- Directus supplies login/session/Manager authorization;
- the Controller browser owns Add/Edit/Assign/Unassign/Print Label UX;
- PostgreSQL owns constraints/audit/final data integrity;
- `ref.controller_display` retains its composite key `(controller_id, display_id)`;
- ordinary users remain read-only;
- no normal Controller DELETE workflow exists.

See the current architecture/roadmap documents linked at the top of this file before using any artifact in this directory for new work.

## Important Permanent Boundaries

- Network/UID/channel/IP/universe are mutable programmed/show facts, never permanent controller identity.
- The same address may belong to multiple physical controllers.
- Controller-to-Display is many-to-many.
- `year_deployed` is first-known deployment/use evidence, not manufacture year.
- Unknown firmware remains unknown; text such as `New` is not a firmware version.
- Current physical location, Display assignment, Stage context, and LOR address are separate mutable facts.
- Newly found shelf controllers are created through the permanent Controller Management workflow; they are not appended to the historical workbook bootstrap.
