# Controller Inventory

| Document control | Value |
|---|---|
| Status | PRODUCTION CORE INSTALLED — READ EXPERIENCE ACCEPTED — PROTECTED WRITE ACCEPTANCE IN PROGRESS |
| Issue | #110 |
| Permanent identity | `ref.controller.controller_id` |
| Permanent database | Installed on `msb-prod-db` |
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

Accepted production read-side checkpoint before protected browser writes:

```text
checkout                    84d6f06e16c43ebb0f6aa21273b999af7f6d455b
FieldWiring                  V0.3.1 / postgres / healthy
Procedures                   V0.1.0 / postgres / healthy
combined live regression     183 passed in 2.39s
```

The working Controller/FieldWiring read experience includes Stage/Sub-stage-aware browsing/search, programmed LOR Network/UID/IP presentation, Controller/FieldWiring cross-links, firmware history, current assignments, and label state.

## Protected Browser Write Checkpoint — Not Yet Production Deployed

Candidate `99728122e982eb2e77268cf1bb5aee682aaa4c62` implements the first controlled browser write slice: **Print Label**.

The implemented boundary is:

```text
Cloudflare Access authenticated email
    -> current Directus user/role/policy capability resolution
    -> server-side capability check
    -> narrow SECURITY DEFINER PostgreSQL command
    -> existing Controller audit trigger / ref.resolve_actor()
```

New database contracts:

```text
ref.controller_browser_capabilities(text)
ref.request_controller_label(text, bigint)
```

`fieldwiring_app` receives EXECUTE only and retains no broad `UPDATE` on `ref.controller`.

The label command resolves the active Directus user UUID, requires an existing `ref.person.directus_user_id` mapping, sets transaction-local `app.directus_user_uuid`, and then sets only:

```text
ref.controller.print_label = true
```

The existing `ref.set_actor_on_update()` -> `ref.resolve_actor()` path therefore records the real mapped person rather than the application login.

Application regression for this candidate passed on 2026-08-31:

```text
focused Controller auth/write contracts   9 passed in 0.86s
FieldWiring full regression               144 passed in 4.48s
Procedures full regression                 54 passed in 1.23s
combined application regression           198 passed
```

Migrations `021_create_controller_browser_authorization_contract.sql` and `022_create_controller_label_request_command.sql` have **not** yet been applied to production. Current-production disposable PostgreSQL acceptance is the next gate.

## Read This First

For current implementation work, read in this order:

1. [Controller Management Authentication / Authorization Contract — 2026-08-31](Controller_Management_Authentication_Authorization_Contract_2026-08-31.md)
2. [Controller Management Application Boundary — 2026-08-31](Controller_Management_Application_Boundary_2026-08-31.md)
3. [Controller Current Programmed Configuration Contract — 2026-08-31](Controller_Current_Programmed_Configuration_Contract_2026-08-31.md)
4. [Controller Inventory Operational Implementation Roadmap — 2026-08-31](Controller_Inventory_Operational_Implementation_Roadmap_2026-08-31.md)
5. [Controller Inventory / FieldWiring Repeated-Address and Duplicated-Channel Cases — 2026-08-30](Controller_FieldWiring_Repeated_Address_and_Duplicated_Channel_Cases_2026-08-30.md)
6. [FieldWiring / Controller Inventory Handoff — 2026-08-20](../09_Wiring_System/FieldWiring_Controller_Inventory_Handoff_2026-08-20.md)

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

Network, Unit ID/range, IP address, universe, Display, Stage, Scene, workbook row, and LOR Prop UUID are mutable facts/evidence, not permanent Controller identity.

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

The first command is `ref.request_controller_label(text,bigint)`. Later Add/Edit/Assignment operations must follow the same least-privilege pattern.

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

`ref.controller` already contains the established label request/cache fields. Browser Print Label sets the governed request flag; the separate label polling/print service handles downstream printing. Do not create another print queue in Controller Management.

Production Crew, Manager, and Administrator may request Controller labels. Full Controller maintenance remains Manager/Admin only.

## Directus Experiment — Closed

Do not resume the Directus Controller relationship workspace experiment. It caused Controller item-detail failures around the legitimate composite relationship key. Cleanup passed while preserving permanent data and the composite key.

Directus remains useful as authorization data and optional simple one-record/reference maintenance. It is not the Controller operational editor.

## Operator Procedures

Plain-English operator procedures are required after the browser management workflow is accepted so the documentation matches real screens and behavior. They must cover browsing, Stage lookup, shelf stock, Add/Edit, assignment/reassignment/unassignment, firmware/status/location/programmed configuration, labels, and FieldWiring navigation.

## Completion and Main-Merge Gate

Controller Inventory application work from `agent/controller-inventory-ref-sandbox` has not been merged to `main`. Draft PR #111 remains the controlled merge path.

Do not merge merely because production Controller tables already exist. Merge only after the browser management workflow, regression, production acceptance, and operator documentation are complete.

## Active Resume Point

Current sequence:

1. **Current-production disposable PostgreSQL acceptance for migrations 021/022 and Print Label behavior.**
2. Separate explicit production deployment/validation of 021/022 and the browser candidate.
3. Admin browser acceptance: Cloudflare identity, capability resolution, Print Label, correct audit person.
4. Production Crew and Read Only capability-boundary acceptance.
5. Implement Edit Controller using the same narrow command/audit model.
6. Implement Add Controller.
7. Implement Controller ↔ Display assignment/reassignment/unassignment preserving M:N and `wiring_source_display_id`.
8. Minor UI corrections, full regression/acceptance, final operator procedures, and PR #111 merge preparation.

Every deployed application change must preserve the shared FieldWiring + Procedures regression gate and keep responsible documentation current during the work.
