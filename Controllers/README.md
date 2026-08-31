# Controller Inventory — Application-First Bootstrap Sandbox

Status: **EXPERIMENTAL / RESETTABLE — DO NOT PRINT PERMANENT CONTROLLER LABELS**

Issue: #110

## Current Source Facts

The current bootstrap evidence is:

- `Controller Inventory & Testing 2026(7).xlsx`
- `lor_output_v7_scene(20260830-185521).db`
- generated reconciliation CSV for those two artifacts

The workbook contains **177 deployed controllers and no spare/available controllers**.

Current reconciliation result:

- 177 deployed-controller candidates
- 152 direct V7 Display-name matches
- 25 candidates requiring review
- 172 recorded firmware versions
- 5 firmware values requiring verification (`???`, `New`, or blank)

## Identity Rule

Permanent identity is only:

```text
ref.controller.controller_id
```

The first permanent Controller ID is **1001**.

The initial IDs are intentionally allocated in a reviewed rough oldest-to-newest order, using `year_deployed` derived from permanent Display evidence before the first permanent insert. This makes the initial number range more useful to people without turning the ID into encoded year/UID meaning.

## Bootstrap Boundary

Temporary reconstruction belongs in the already-established `stage` schema:

```text
stage.controller_bootstrap
stage.controller_bootstrap_display
stage.v_controller_bootstrap_review
```

No permanent `controller_id` exists in stage.

**The entire initial reconstruction, Display resolution, year backfill, duplicate-address review, and proposed 1001+ ordering is completed in `stage.*` before `ref.controller*` is created.**

Permanent-shaped Controller Inventory objects are created only after the staged set/order is accepted. Existing production tables are FK targets only and must not depend on `ref.controller*` during the experimental phase.

## Database Scripts — Current Sequence

### Phase A — Stage-only reconstruction

1. `Database/001_create_stage_controller_bootstrap.sql`
   - creates the disposable staging/review layer
   - allocates no controller IDs

2. Validate and then load the generated reconciliation CSV with:

   ```text
   Bootstrap/load_controller_reconciliation_csv.py
   ```

   Default mode is validation only. `--apply` writes **stage only**.

3. `Database/003_prepare_controller_bootstrap.sql`
   - requires only the stage tables plus existing `ref.display`
   - auto-links only unique exact permanent Display-name matches
   - derives `year_deployed` from the earliest assigned `ref.display.year_built`
   - creates the review view and order-preparation function
   - writes only `stage.*`
   - allocates no controller IDs

4. `Database/005_validate_controller_bootstrap.sql`
   - stage-only read/report
   - shows unresolved Display/year rows
   - shows firmware evidence state
   - exposes repeated Network/UID groups without collapsing them

5. Resolve the remaining staging review cases. This may be done through controlled SQL first and then through `Application/` once its stage-only deployment is accepted.

6. Run `stage.prepare_controller_bootstrap_order()` only after all physical controller rows are READY/SKIPPED.
   - writes only `bootstrap_order` / `proposed_controller_id` in stage
   - no permanent ID is allocated

7. Run `Database/005_validate_controller_bootstrap.sql` again and review the complete oldest-to-newest proposed 1001+ order.

### Phase B — Permanent-shaped experimental Controller Inventory

Only after Phase A is accepted:

8. `Database/002_create_ref_controller_sandbox.sql`
   - creates isolated permanent-shaped Controller Inventory tables
   - seeds accepted current model codes and controller statuses
   - leaves `ref.controller` empty
   - `controller_id` identity is configured to start at 1001

9. `Database/004_promote_controller_bootstrap.sql`
   - **explicit controlled gate; not exposed in the browser**
   - resolves staged model evidence to `ref.controller_model`
   - creates firmware catalog rows only for source values classified `RECORDED`
   - requires empty `ref.controller`
   - restarts identity at 1001
   - promotes all READY rows in one transaction
   - verifies every generated ID equals the reviewed proposed ID
   - any mismatch rolls back the entire transaction

10. Perform post-promotion validation before permanent Controller identities are accepted.

## Experimental Reset

`Database/006_reset_experimental_controller_data.sql` is PRE-ACCEPTANCE ONLY.

It refuses to reset if Controller label request/print evidence exists or if an external subsystem has begun depending on `ref.controller`.

Once Controller IDs are formally accepted as permanent, the reset/restart workflow is retired and IDs are never reused.

## Label Fields

`ref.controller` mirrors the existing Display label-state pattern:

```text
label_required
print_label
label_print_count_cached
label_print_last_at_cached
label_print_last_by_cached_id
label_template_id
```

`label_template_id` references the existing `ref.label_template.label_template_id` authority.

No new `label_id`, `label_type_id`, or Controller-specific template table is introduced.

## Important Boundaries

- Network/UID/channel/IP/universe are current LOR/V7 evidence, never permanent controller identity.
- The same address may belong to multiple physical controllers.
- Controller-to-Display is many-to-many.
- `year_deployed` is first-known deployment/use evidence, not manufacture year.
- Unknown firmware remains unknown; text such as `New` is not inserted as a firmware version.
- Current physical `ref.location`, Display assignment, Stage context, and LOR address are separate mutable facts.
- The current workbook is deployed-controller bootstrap evidence, not spare inventory.
- No Controller label should be physically printed while the identity set remains resettable.
