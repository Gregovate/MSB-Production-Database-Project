# Controller Inventory

| Document control | Value |
|---|---|
| Status | PRODUCTION CORE INSTALLED — READ EXPERIENCE ACCEPTED — PROTECTED PRINT LABEL DEPLOYED |
| Issue | #110 |
| Permanent identity | `ref.controller.controller_id` |
| Permanent database | Installed on `msb-prod-db` |
| Current production checkout | `e9ab029a17067b38b34f9306069f54899925f73f` |
| Current application rollback | `f334cfe71717b643a4d3a7ac6a5064fb13b9047e` |
| FieldWiring production | `V0.3.3 / postgres / healthy` |
| Procedures production | `V0.1.0 / postgres / healthy` |
| Authentication / authorization | [Controller Management Authentication / Authorization Contract — 2026-08-31](Controller_Management_Authentication_Authorization_Contract_2026-08-31.md) |
| Management boundary | [Controller Management Application Boundary — 2026-08-31](Controller_Management_Application_Boundary_2026-08-31.md) |
| Programmed configuration | [Controller Current Programmed Configuration Contract — 2026-08-31](Controller_Current_Programmed_Configuration_Contract_2026-08-31.md) |
| Operational roadmap | [Controller Inventory Operational Implementation Roadmap — 2026-08-31](Controller_Inventory_Operational_Implementation_Roadmap_2026-08-31.md) |
| Repeated-address / duplicated-channel contract | [Accepted Cases — 2026-08-30](Controller_FieldWiring_Repeated_Address_and_Duplicated_Channel_Cases_2026-08-30.md) |

Controller Inventory owns permanent physical controller identity, current physical Controller-to-Display relationships, and the physical controller's recorded current programmed configuration. LOR/V7 remains authoritative for current show wiring topology and what the show currently requires.

## Current Production State

The permanent Controller Inventory core is installed and populated in PostgreSQL:

```text
ref.controller_model
ref.controller_firmware_version
ref.controller_status
ref.controller
ref.controller_display
ref.controller_firmware_history
```

Every existing `ref.controller*` object above is a **production** object. Historical migration filenames containing `sandbox`, `bootstrap`, or `experimental` describe migration history only; they do not make the installed tables disposable.

Accepted permanent state includes 177 physical controllers with IDs `1001` through `1177`. `ref.controller_display` retains the legitimate composite key `(controller_id, display_id)`. Controller 1176 remains intentionally unassigned until its new Display exists through the normal LOR/Preview workflow.

Current production checkpoint after the first protected browser write deployment:

```text
checkout                    e9ab029a17067b38b34f9306069f54899925f73f
rollback checkout           f334cfe71717b643a4d3a7ac6a5064fb13b9047e
FieldWiring                  V0.3.3 / postgres / healthy
Procedures                   V0.1.0 / postgres / healthy
combined live regression     204 passed in 2.21s
Controller fingerprint       411fcef3fc3122ae77e75fe375dff215 unchanged
```

The working Controller/FieldWiring read experience includes Stage/Sub-stage-aware browsing/search, programmed LOR Network/UID/IP presentation, Controller/FieldWiring cross-links, firmware history, current assignments, and label state.

## Protected Browser Write — Production Deployed

The first controlled browser write slice, **Print Label**, is now deployed in production.

Production database contracts:

```text
ref.controller_browser_capabilities(text)
ref.request_controller_label(text, bigint)
```

Production migrations:

```text
Controllers/Database/021_create_controller_browser_authorization_contract.sql
Controllers/Database/022_create_controller_label_request_command.sql
```

The deployed boundary is:

```text
Cloudflare Access authenticated email
    -> current Directus user/role/policy capability resolution
    -> server-side capability check
    -> narrow SECURITY DEFINER PostgreSQL command
    -> existing Controller audit trigger / ref.resolve_actor()
```

`fieldwiring_app` has EXECUTE on the two controlled functions and still has no broad `UPDATE` on `ref.controller`. It also does not receive direct read access to Directus user tables merely to implement authorization.

The label command resolves the active Directus user UUID, requires an existing `ref.person.directus_user_id` mapping, sets transaction-local `app.directus_user_uuid`, and sets only:

```text
ref.controller.print_label = true
```

The existing `ref.set_actor_on_update()` -> `ref.resolve_actor()` path therefore records the real mapped person rather than the application login.

### Disposable acceptance

Current-production disposable PostgreSQL acceptance passed before deployment. It verified:

```text
fieldwiring_app direct ref.controller UPDATE denied
unauthorized label request denied
authorized mapped-person request accepted
real updated_by_person_id stamped
repeated pending request idempotent
production Controller fingerprint unchanged
```

### Production deployment acceptance

Detached production-environment candidate regression:

```text
204 passed in 2.43s
```

Validated rollback archive retained on `msb-prod-db`:

```text
/home/msbadmin/backups/postgres/msb-pre-controller-browser-20260901T051332.dump
SHA256 fdffebe1e1f9a43f795934d7930d2b8ba2806b418170f4fd12fdbed7b7317750
```

Production migration validation:

```text
fieldwiring_app EXECUTE controller_browser_capabilities = true
fieldwiring_app direct Directus user-table read         = false
fieldwiring_app direct ref.controller UPDATE            = false
fieldwiring_app EXECUTE request_controller_label        = true
```

Live negative-path proof:

```text
/api/controller-access without Cloudflare identity -> HTTP 401
```

Final production result:

```text
CONTROLLER LABEL PRODUCTION DEPLOYMENT: PASS
CONTROLLER LABEL PRODUCTION DEPLOYMENT WRAPPER: PASS
```

The authoritative server-side deployment procedure and all deployment failure lessons are now documented in `Gregovate/MSB-Server-Management`:

- `docs/server/Production_Database_Change_Deployment_Runbook.md`
- `docs/server/Controller_Browser_Write_Production_Acceptance_2026-09-01.md`
- `docs/server/PostgreSQL_Disposable_Acceptance_Standard.md`
- `docs/server/FieldWiring_Production_Runtime.md`

Future Production Database changes must consume those runbooks rather than rediscovering SSH, CRLF, Docker host/container file paths, rollback validation, or `pipefail` behavior in feature work.

## Read This First

For current implementation work, read in this order:

1. [Controller Management Authentication / Authorization Contract — 2026-08-31](Controller_Management_Authentication_Authorization_Contract_2026-08-31.md)
2. [Controller Management Application Boundary — 2026-08-31](Controller_Management_Application_Boundary_2026-08-31.md)
3. [Controller Current Programmed Configuration Contract — 2026-08-31](Controller_Current_Programmed_Configuration_Contract_2026-08-31.md)
4. [Controller Inventory Operational Implementation Roadmap — 2026-08-31](Controller_Inventory_Operational_Implementation_Roadmap_2026-08-31.md)
5. [Controller Inventory / FieldWiring Repeated-Address and Duplicated-Channel Cases — 2026-08-30](Controller_FieldWiring_Repeated_Address_and_Duplicated_Channel_Cases_2026-08-30.md)
6. [FieldWiring / Controller Inventory Handoff — 2026-08-20](../09_Wiring_System/FieldWiring_Controller_Inventory_Handoff_2026-08-20.md)
7. Server Management `docs/server/Production_Database_Change_Deployment_Runbook.md` before any future production mutation.

Older bootstrap/Pre-DDL material remains historical evidence. Current production and active management/authentication documents control when older material conflicts.

## Permanent Identity and Relationships

Permanent physical identity is only:

```text
ref.controller.controller_id
```

Accepted scan payload:

```text
CTRL:<controller_id>
```

Network, Unit ID/range, IP address, universe, Display, Stage, Scene, spreadsheet row, and LOR Prop UUID are mutable facts/evidence, not permanent Controller identity.

Controller-to-Display cardinality is many-to-many:

```text
one controller -> zero, one, or many Displays
one Display    -> zero, one, or many controllers
```

Intentional repeated addresses are valid. Never make Network + UID globally unique physical identity.

`ref.controller_display.wiring_source_display_id` remains the explicit reviewed bridge for duplicated-channel physical copies whose LOR wiring is intentionally defined by another Display.

## Authority Boundary

```text
Cloudflare Access
    -> authenticates the protected browser user

Directus
    -> current user / role / policy authorization data

Controller Inventory
    -> permanent physical controller identity
    -> model/status/firmware/location/notes
    -> current programmed Network / UID range / management IP
    -> current physical Controller-to-Display relationship

LOR / Parser V7 / LOR2DB
    -> authoritative current show wiring topology
    -> addressing/channels/universes required by the show
    -> Preview / Scene / Display wiring definitions

Purpose-built Controller / FieldWiring browser
    -> operational read and management UX

PostgreSQL
    -> constraints / audit / narrow write commands / final authority
```

No Directus login redirect or cross-origin Directus browser-session bridge is required for Controller Management.

## Capability Matrix

```text
Production Crew           -> browse + Print Label
Manager                   -> browse + Print Label + Controller management
Administrator             -> browse + Print Label + Controller management
MSB Browser / Read Only   -> browse only
```

Controller management means Add/Edit Controller and Controller-to-Display assignment/reassignment/unassignment. No normal Controller DELETE workflow is authorized.

Button visibility is presentation only. Every write rechecks authenticated identity and current authorization server-side.

## PostgreSQL Write Boundary

Do not make `fieldwiring_app` a broad table writer.

Accepted direction:

```text
fieldwiring_app
    -> SELECT approved read model
    -> EXECUTE narrow SECURITY DEFINER commands
    -> no broad INSERT / UPDATE / DELETE on ref.controller*
```

The first deployed command is `ref.request_controller_label(text,bigint)`. Later Add/Edit/Assignment operations must follow the same least-privilege pattern.

## Current Programmed Configuration

`ref.controller` records the physical controller's **current programmed configuration**, including current `lor_network`, `lor_uid_start`, `lor_uid_count`, calculated `lor_uid_end`, and management IP where applicable. These are mutable operational facts, not identity.

LOR/V7 remains authoritative for the show-required configuration. Setup/reconciliation compares physical recorded programming against current show requirements.

Fixed full-UID models remain governed by the existing database validation rules, including CCB100=2, Pixie4D=4, Pixie8D=8, Pixie16D=16.

## Stage and Assignment Model

Do not add redundant `stage_id` to `ref.controller` merely for browsing. Stage context is derived through current Display relationships:

```text
ref.controller
    -> ref.controller_display
        -> ref.display
            -> ref.stage
```

Unassigned shelf controllers may legitimately have zero assignments and no Stage.

## FieldWiring Integration

Accepted resolver basis:

```text
physical controller = ref.controller.controller_id
physical Display     = ref.controller_display.display_id
wiring Display       = COALESCE(
    ref.controller_display.wiring_source_display_id,
    ref.controller_display.display_id
)
```

Permanent Controller context is visible in FieldWiring. Detailed show wiring remains LOR/V7 authority.

## Labels and Scan

Controller labels use permanent identity `CTRL:<controller_id>`.

`ref.controller` contains the established label request/cache fields. Browser Print Label now sets the governed request flag in production; the separate label polling/print service handles downstream printing. Do not create another print queue in Controller Management.

Production Crew, Manager, and Administrator may request Controller labels. Full Controller maintenance remains Manager/Admin only.

## Directus Experiment — Closed

Do not resume the Directus Controller relationship workspace experiment. It caused Controller item-detail failures around the legitimate composite relationship key. Cleanup passed while preserving permanent data and the composite key.

Directus remains useful as authorization data and optional simple one-record/reference maintenance. It is not the Controller operational editor.

## Operator Procedures

Plain-English operator procedures are required after the browser management workflow is accepted so the documentation matches real screens and behavior. They must cover browsing, Stage lookup, shelf stock, Add/Edit, assignment/reassignment/unassignment, firmware/status/location/programmed configuration, labels, and FieldWiring navigation.

## Completion and Main-Merge Gate

Controller Inventory application work from `agent/controller-inventory-ref-sandbox` has not been merged to `main`. Draft PR #111 remains the controlled merge path.

Do not merge merely because production Controller tables and the Print Label command are deployed. Merge only after the broader browser management workflow, regression, production/operator acceptance, and operator documentation are complete.

## Active Resume Point

Current sequence:

1. **Administrator browser acceptance on the deployed production change:** verify Cloudflare email resolves, Print Label is visible, the request succeeds, and audit identity is correct.
2. Production Crew browser acceptance: Print Label available, management actions unavailable.
3. MSB Browser / Read Only acceptance: no write actions available.
4. Implement Edit Controller using the same narrow command/audit model.
5. Implement Add Controller.
6. Implement Controller ↔ Display assignment/reassignment/unassignment preserving M:N and `wiring_source_display_id`.
7. Minor UI corrections, full regression/acceptance, final operator procedures, and PR #111 merge preparation.

Every deployed application change must preserve the shared FieldWiring + Procedures regression gate and keep responsible documentation current during the work.