# Setup Extra Material Catalog / UOM Production Acceptance — 2026-09-15

## Scope

Production acceptance record for:

- Issue #189 — Kit Inventory inline Extra Material catalog management
- Issue #191 — governed Unit-of-Measure catalog
- PR #190 — Setup #189 inline Extra Material catalog management from Kit Inventory

## Accepted runtime

Exact operator-accepted runtime SHA:

`0322e32360d1cd5663812856c555fefe9770e029`

PR #190 was merged to `main` with merge commit:

`3fc04a1c0a0f7d17c30bb67d1d07e570a6fb7516`

The commits after the accepted runtime SHA contained Production deployment tooling only. `/opt/msb-setup` was intentionally deployed to the accepted runtime SHA, not the later PR/tooling head.

## Pre-Production acceptance

The exact runtime SHA passed:

1. Full `Setup/Application` regression.
2. Reusable disposable current-Production clone acceptance.
3. Migration `Setup/Database/049_add_setup_uom_catalog.sql` on the disposable clone.
4. `setup_191_uom_catalog_disposable_validation.sql` behavioral validation.
5. Fresh disposable browser review.
6. Operator acceptance of the corrected Kit Inventory catalog UX and UOM workflow.
7. Browser-preview cleanup with unchanged Production Setup fingerprint and unchanged live Setup SHA.

Disposable acceptance report:

`/home/msbadmin/setup-acceptance-reports/Setup_Disposable_Acceptance_20260915T130709.txt`

Disposable browser preview report:

`/home/msbadmin/setup-acceptance-reports/Setup_Disposable_Browser_Preview_20260915T130852.txt`

## Production deployment

Deployment completed through the bounded #189/#191 Production deployment wrapper.

Result:

`SETUP_189_191_PRODUCTION_DEPLOYMENT_PASS`

Final live Setup SHA:

`0322e32360d1cd5663812856c555fefe9770e029`

Final Production Setup fingerprint:

`ebfd043246aa18a721ede5050aca167a`

Final existing Extra Material/task/Container source fingerprint:

`295e27c7af44ca0e8674f9d69de32e14`

Final governed UOM catalog rows:

`7`

Final 2026 Setup Session rows:

`0`

Production deployment report:

`/home/msbadmin/setup-deployment-reports/Setup_189_191_Production_Deploy_20260915T132100.txt`

Validated rollback archive:

`/home/msbadmin/backups/setup-191/msb-pre-setup-191-uom-20260915T132100.dump`

Rollback archive SHA256:

`db862d51f767065b323c4b3b7003a33bcb18ea99d03f7cc7da915cd0d8a77d27`

## Production invariants

Production after-check proved:

- Production Setup governed-data fingerprint unchanged.
- Existing `ref.setup_extra_material`, `ref.setup_task_extra_material`, and `ref.setup_container_extra_material` source rows unchanged.
- Migration 049 installed the governed UOM catalog and relationships without rewriting existing Extra Material data.
- No 2026 Setup Session was created.
- Live Setup regression passed after deployment.
- `/opt/msb-setup` finished clean at the exact accepted runtime SHA.

## Accepted behavior

### Extra Material catalog / Kit Inventory

- Managers can create a missing normalized Extra Material family from Kit Inventory.
- Existing Expected Kit rows lock material identity during edit.
- Creating/selecting a new catalog identity cannot silently reinterpret an existing Expected Kit row.
- The new-material workflow returns to the new Expected Kit row for quantity/UOM/spec/notes completion.
- Existing catalog editing is opt-in rather than auto-populated.
- Remainders remain temporary evidence and can be normalized into the Extra Material catalog / Expected Kit Contents workflow.
- Save/Create actions follow the primary blue commit-action convention.

### Governed UOM catalog

Canonical starter/current Production UOM catalog contains:

- `EA`
- `FT`
- `IN`
- `SHEET`
- `SET`
- `ROLL`
- `CAN`

Migration 049 provides:

- stable UOM code identity;
- active/inactive governance;
- Manager-governed create/update commands;
- foreign-key enforcement from Extra Material catalog, task requirement, and Container expected-content UOM fields;
- prevention of UOM deactivation while active rows still reference it;
- selectors instead of unrestricted UOM text entry on governed Setup surfaces.

Quantity remains nullable while evidence is genuinely unverified; when supplied, existing positive numeric rules remain authoritative.

## Disposition

Production deployment accepted.

Issues #189 and #191 are complete.