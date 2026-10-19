# #230 Reference Data Manager — Physical Container/Display Identity, Integral Show Bases and Labelability

| Document control | Value |
| --- | --- |
| Document type | Engineering contract — proposed #230 requirements and acceptance |
| Status | **DRAFT — October 19, 2026; not implemented or Production approved** |
| Owner | Production Database #230, under Setup commanding #122 |
| Source baseline | `main` `a770e755dc4ce59873a004b3d92368c4c4cf7eae`; existing draft #88 PR #418 and #171 PR #319 are separate implementation owners |
| Relevant existing authority | [Containers and Storage](../README.md), [Testing System](../../05_Testing_System/README.md), [Labeling and Scanning](../../07_Labeling_and_Scanning/README.md), [Label Payload and Profile Architecture](../../07_Labeling_and_Scanning/Label_Payload_and_Profile_Architecture.md) |
| User workflows | [#88 movement design (draft PR #418)](https://github.com/Gregovate/MSB-Production-Database-Project/blob/fix/88-empty-recording/Docs/02_Production_Database/01_System_Architecture/12_Setup_and_Deployment/engineering/Setup_88_Pick_Mode_Movement_Design_2026-09-29.md), [#88 Mixed-Stage Unload](../../12_Setup_and_Deployment/engineering/Setup_Mixed_Stage_Container_Unload_Contract_2026-09-09.md), [#132 Crew Work Reporting](../../12_Setup_and_Deployment/engineering/Setup_Crew_Work_Reporting_Contract_2026-09-08.md) |

## Purpose and authoritative ownership

**This is the owning #230 engineering contract** for permanent physical Container/Display classification and labelability. Permanent `ref.*` identity and relationship metadata must let #88 Setup movements, #231 Testing, #423 Takedown, #132 Report Work, #171 GIS and the existing LabelPrintService handle each *real physical object* correctly.

Do **not** infer the number of physical objects from the number of database IDs or the number of `ref.display` children. A Container may **become part of the show**, may carry *separate removable Displays*, and may also have **one Display identity integral to its base**. These conditions are not mutually exclusive. A Display may already have a permanent `ref.display.display_id` while still **not bearing any readable physical label**. Not labeled, not serialized in the database, not installed, not physically scan-verifiable, and not currently onboard a Container are five different facts.

This design complements the existing #230 issue specification for immutable keys, governed `ref.display.container_id` ownership, Home Location, Manager editor and Print Label action. The issue and PR descriptions must consume this contract; they do not replace it. No independent generic `ref.*` CRUD, movement state, new test ledger or print-service implementation belongs here.

## Operator-confirmed repeatable cases — October 19 field launch

| Physical asset | Known source and field reality | Required treatment / open verification |
| --- | --- | --- |
| **C009 Ginger Bread House** | User DBeaver readback: C009 description Ginger Bread House; type Display Pallet; Home Z-BLDG-A-EAST; **13 permanent Display assignments**. Display **909 CL-GingerbreadHouse** is physically integral to C009; the **other 12** are removable Candy Cane, Tumbling Gingerbread and other assigned Displays. During an `EMPTY` reconciliation, events #538–550 marked **all 13 DETACHED**, including **909 event #544**, using `inferred_unload=true; prior_event_id=250`. User reports toggling `display_pallet` on after an earlier unchecked screenshot; last supplied query showed blank, so fresh readback still required. | Must support **one integral Display plus removable cargo** on the same show base. Cargo can be zero while physical Container and integral Display remain installed at the Stage. Guard future `EMPTY` from detaching 909. Restore erroneous annual state only via #88 Manager audited correction, with new-event guard and historical #544 intact. Do not falsely mark C009 Returned Home. |
| **Traditional Christmas / Peanuts Container** | Operator confirms the Container transports equipment, then becomes the **Thank You for Visiting** sign when deployed. | **Same recurring physical transformation** as C009: integral displayed sign may coexist with removable components. Exact Container ID, `ref.display` sign ID and manifest are **not yet read back**; do not invent them or auto-classify solely from the Container's description. Operator says moved into final position on Oct 19; verify actual movement event/physical identity read-only. |
| **U.S. Flag Container** | Operator confirms the Container becomes the physical **U.S. Flag Display** at its show position; moved into position Oct 19. | Need exact Container/Display IDs, flag/type, whether any removable contents exist, and last current movement. Preserve physical show placement and paired identities; no synthetic detachment/automatic Home return. |
| **C131 Antenna Trailer** | Operator confirms trailer carries multiple Displays that are unloaded over one or more stops. Existing #122 **DBG-2026-012** identifies missing *Command Center* in the drop picker, GPS absent at a different stop even with hotspot connectivity; the trailer was then reported physically empty and positioned at the park. User now reiterates that an **unload bug** occurred. | Preserve valid partial/complete unload events; **do not retroactively classify as C009-style integral detach** without an actual linked integral Display identity and event evidence. Investigate C131 location-picker, GPS/selected named location, chronology and actual child effects separately under #88/#171, retaining current valid Empty / Park position. |
| **C034 Arch Trailer** | Operator confirms roughly **one-mile Stage distribution loop**, with unload stops hundreds of feet apart. Older engineering design says trailer later becomes Who House base while actual Who House is stored elsewhere. | Multi-Stage distribution and later show-base use are legitimate and not a GPS-distance error or license to create an invented integral Display association. Preserve individual Stage unload HERE/PRIOR evidence; classify base versus cargo by reviewed physical facts. |
| **Church Bells, Candy Canes, Tumbling Gingerbread** | Field photos/observations confirm some individual Displays cannot practically carry the existing large labels; some have no physical QR at all. Candyland physical photos show erected Candy Cane and three Tumbling Gingerbread panels. | **Existing Display IDs do not prove physically serialized/labeled pieces.** Assess each piece/group for a narrower durable label where feasible and otherwise authorize task/Scene-scoped accountable visual identification (not a fake scan). Do not invent individual surveyed coordinates. |

These are engineering acceptance fixtures and field leads, **not authority to edit Production reference rows**. The operator-confirmed physical pattern has several instances; a C009-specific hardcoded exception is unacceptable.

## Permanent physical role model and constraints

The Manager editor must expose and validate a **physical-role classification**, at both Container and associated Display level. Review current live schema/constraints/Directus fields first to determine whether approved existing metadata can express it; only then propose the minimal governed schema extension.

**Container physical roles** to distinguish conceptually (these are business meanings, not prematurely approved new column names):

- **Transport-only carrier:** holds removable Displays/Kits and is not itself a deployed show Display.
- **Deployed show base:** the Container/pallet/frame itself stays in the park and participates in the show after removable cargo is unloaded; can be empty of removable cargo without being Returned.
- **Single integral unit:** one physical show Display represented by a Container plus possibly a linked Display ID, including synthetic Standalone Testing wrappers or singular physical pallets. A second identifier/label is not a second physical object.
- **Mixed show base/carrier:** a show base with one or more **integral physical Display components** and **independent removable cargo Displays**; C009 is the required acceptance case. One integral Display is not the same as one active permanently assigned Display.
- **Multi-stage trailer with deployed role:** moves, partially unloads at separate Stages and may subsequently become a show structure; retain trailer's own position separate from each removed Display.

The **integral/non-removable designation must resolve at the specific Container-to-Display relationship or Display identity**, not merely by `container_type_name='Display Pallet'`, `ref.container.display_pallet` or the number of `ref.display.container_id` assignments. Current `ref.display.container_id` remains the single authoritative *permanent assignment* relation: no duplicate reverse membership table. If existing attributes cannot identify the integral child, design the smallest audited extension (exact DDL after schema reconnaissance), guard one integral Display from simultaneously being removable cargo, and require Manager authority/review for changes to physical role.

The following are independent dimensions: permanent assignment, physical integral relationship, current removable cargo status, physical installed show-base status, actual workshop return, assigned Home, Setup Display installed verification and Testing inclusion. **Do not collapse them into a single `display_pallet` or `position_mode` Boolean**. `display_pallet` may identify a pallet type but cannot identify child 909 specifically.

### Invariants to enforce and share

1. **Empty means no removable cargo remains**, not zero permanently assigned Displays, not all Displays detached, not Container Returned, and not installation of each child. For C009 the base and 909 are still installed together even with twelve removable items absent.
2. A read-only Manager/Scan summary explicitly displays **integral show-Display Names** separately from **removable cargo Names**, including expected and current attached/unloaded state. C009 must display `CONT:9 + DISP:909` as one physical show structure with twelve additional independently traceable components.
3. Container type and `display_pallet` flag are independently visible and validate their intended relationship; no automatic toggle without the reviewed contract. Saved/current value must be confirmed against live `ref.container`, not inferred from a form screenshot.
4. **#88** must reject accidental integral child detachment, distinguish cargo empty from show-base present, and retain original prior/HERE provenance; support reviewed restoration of invalid existing history with exact latest-event/version guard, not SQL rewrites.
5. **#231 Testing** must count/test actual distinct physical Displays/components and track Container-level test identity without counting one physical unit twice, losing prior repair history or assuming all assigned cargo remains attached during Setup.
6. **#423 Takedown** scans one actual Container, then each individually loaded *removable* Display as appropriate; its physical integral Display is already part of that Container and not another cargo scan. Damaged/unlabelable items follow authorized identified exception workflow.
7. **#171 Park Map** consumes #88's truthful location/provenance projection, shows base/integral item as one physical geographic object where verified, and does not turn copied prior unloading GPS into individually verified show positions. No new GPX/source map identity is created.
8. Changes to permanent Container/Display relationships/physical roles require Manager authorization and audit; protect valid newer field evidence/approved 2026 work reports and LOR-owned Display Name/Stage.

## Separate Testing workaround from real physical identity — eliminate forced false Containers

**Operator correction October 19:** The authoritative show Display identity is the **LOR-generated permanent `ref.display.display_id` and human `display_name`**. Some physical Displays are deliberately built as a single combined show/transport unit, so the Container is a useful *transport and storage role of the same object*, not a second actual show object. Examples include C009/909 Ginger Bread House, Traditional Christmas/Peanuts → Thank You for Visiting and the U.S. Flag show unit; additional real fixtures such as the volunteer-trailer cable/assembly require explicit item-by-item reconciliation, **not invented master IDs**.

The earlier Testing design required a Container identity to create/organize Test Sessions, which led to **synthetic or false Containers for physically standalone Displays**. That workaround must not become a permanent mandate to manufacture additional `ref.container` records. A real Container ID created solely for Testing administration is not proof of a second transport/storage object or an actual Container return obligation.

**#230 reference-data requirements**: show `LOR Display` as canonical Show identity; show whether its assigned Container is (a) a **real separate carrier**, (b) a **combined one-object display/transport identity**, or (c) a **Testing-only synthetic wrapper with NO physical Container**. The choice must be explicit, searchable, audited and supported through the existing immutable keys. Manager UI must identify synthetic records and which live Testing/Movement/Label histories depend on them **before** any retirement/reclassification. Avoid changing LOR-owned Name/ID and avoid allocating a new Container just to allow Testing to proceed.

**#231 dependency and migration**: Test Session Manager should accept/test a physically standalone LOR Display **without requiring a false Container**, by adapting the existing governed Testing workflow. For historical synthetic wrappers, perform dependency inventory and disposable rehearsal first; preserve foreign-key integrity, historical test/repair identities, printed labels and past Setup movement evidence. Do not immediately delete/reassign/merge wrappers in Production. If the accepted current schema cannot represent this directly, propose minimal #231/#230 reference/Testing contract changes **after** current production schema and testing-query audit. No parallel testing database.

**Scans/QR:** whichever real Container or Display label is physically affixed must resolve the linked canonical IDs; one physical object must never create double current geographic pins, duplicate installed-unit counts or phantom empty-return work. Do not force two tags just because two database records exist. A real separate carrier with removable cargo is different and retains independent physical movement/return identity.

**Acceptance:** a genuine Standalone Display with no Container, an existing historical synthetic wrapper, C009 with integral 909 and twelve removable child records, another combined show/transport unit, a real carrier, and a physically unlabelable LOR Display. Test that #231 can start and complete its governed Test Session without manufacturing a false Container or editing historical evidence. **This is a distinct Testing workflow deliverable** from #230 physical-role reference editing, the 24mm label profile and #88 launch Container return corrections. Implementation and Production migration remain unapproved.

## Physical serialization and labelability — #230 reference editor responsibility

The current default **Display label family is 36mm** under the [Label Payload and Profile Architecture](../../07_Labeling_and_Scanning/Label_Payload_and_Profile_Architecture.md). Greg has proposed **24mm laminated labels** for small Candyland components where a 36mm label cannot be fitted; that is a needed **profile/physical test candidate**, not proof that all panels will accept 24mm. Some Church Bells and other uniquely shaped pieces remain physically impossible to label and must have a governed alternative.

The Manager's Display/Container Detail and Scene/Task membership view must show, for each canonical Display ID:

| Required field / decision | Semantics |
| --- | --- |
| Permanent identity | Exact existing `ref.display.display_id`, human LOR-owned `display_name`, assigned Container (if any); ID creation/renaming cannot be confused with physical tag |
| Physical part role | Integral to named physical Container, removable cargo, independent, or needs field classification |
| Tag inventory / condition | **Affixed and readable**; tag missing but feasible; physically unlabelable; damaged/unreadable; or not inspected. Physical label status is evidence, not inferred from having a record or prior print-batch |
| Requested label profile | Existing approved 36mm default; **proposed 24mm narrower Display profile** after scanning/material durability acceptance; separate Container labels retained. Store governed profile choice, not a printer template filename in `ref.display` |
| Print action | Use the existing `ref.display.print_label` / LabelPrintService handshake and show job/printing evidence; no second print queue, and no silent mass reprint merely because a field is null |
| No-label alternative | Reviewed no-QR physical exception with exact Display/Scene/Task membership, responsible actor, date/reason and manual/visual identification. **Never synthesize a `DISP:` QR scan** for a physically unlabelable piece |

24mm profile must be verified by the **Labeling and Scanning** owner for QR density/scan distance, wear/adhesive, wet/cold field use, print-service media/preflight/template, and no ambiguous text/QR identity. Printed tags must resolve the **existing permanent `DISP:<id>` identity**; do not change the underlying ID or deployed URL payloads. The profile must support a readable Display Name as appropriate. **If no feasible label**, explicitly retain the no-label exception and allow fast authenticated task/Scene visual verification without phone lookups of each ID. Do not pretend that a Container label substitutes for observing an independently removable Display.

Batch **Identify → Decide Labelability → Print Selected 24mm/approved profile → Affix → Scan to verify** is the requested Manager workflow for eligible components. It must permit partial batches, show which exact human Display Names remain unlabeled, and avoid forcing a slow Directus per-record edit. Scanning completion must not be marked successful simply because a label was printed.

## Field incident and reconciliation: #88 Antenna Trailer separate from C009

#122 records **DBG-2026-012** for C131 Antenna Trailer: Command Center not in Setup drop selector; GPS unavailable at a stop despite an online hotspot; later status reported *physically empty and in park position*. The user now reiterates an unload bug. Do not assume that was a missing-permanent-integral child like C009. Examine actual C131 `ops.setup_movement_event`, `ops.setup_movement_event_display`, `ops.setup_display_state`, latest `ops.setup_container_state`, capture actor/time, prior/HERE inference and picker/reference revision **read-only**.

Required acceptance uses a partial multi-stop unload then a truthful confirmed Empty without overwriting already recorded unloads, with or without device GPS when an authorized named drop location was selected. Regression must preserve later Display scans, correct current Container park position and current removable-cargo summary. The deployed C131 current state should not be mass replayed or corrected merely because the picker was deficient. `#88` owns any eventual guarded recorded-state correction, and `#171` owns maintained location catalog/display only.

## #230 Manager interface and acceptance

Provide **search from either direction**: Container ID/description → integral + removable Display Names and their physical QR states; Display Name/ID → canonical parent Container, physical role and its other physical components. Use the existing `ref.display.container_id` relationship, protect immutable IDs and LOR-owned Display Name. Provide a clear review/preview before physical-classification edits; show which #88/#231/#423 operations would be affected.

Acceptance fixtures (current-Production disposable clone, real protected browser and relevant field testing before deployment):

1. **C009** 1 integral Display 909 + 12 removable cargo: pre-existing erroneous 13 detach events still auditable; approved classification prevents future integral detach and represents no removable cargo as **Empty but show base present**; later genuine direct Display scan cannot be overwritten by old inference. Verify current saved `display_pallet` Boolean.
2. **Traditional Christmas / Peanuts → Thank You for Visiting**: identify actual current Container/Display IDs from read-only current master and field observation; prove integral unit remains after removable cargo unload. Do not guess ID/name association from words.
3. **U.S. Flag Container → show Flag Display**: same identity and show-base case; actual current movement and any child members inspected rather than presupposed.
4. **C131 Antenna Trailer**: multi-stop unload and missing Command Center/GPS pathway; preserve existing real Empty/park state and classify actual bug from original receipt instead of guessing.
5. **C034 Arch Trailer**: roughly one-mile valid distribution path at many Stages, no arbitrary distance-based rejection; when base becomes Who House support, do not create fake Who House assigned child.
6. **Mixed sizes and no tags**: actual Candy Cane Rows/Tumbling Gingerbread/Church Bells; accept physically possible 24mm profile only after PrintService + Zebra/HOTWAV scan tests; make physical impossibility explicitly auditable and complete by task/Scene visual workflow.
7. Confirm true saved reference status vs just opened Directus edit page, field-role permissions, audit attribution, stale-state/version guard, duplicate print protection, LOR-owned/read-only field constraints, no Production migration without runbook authorization.

No code, Printer Service deployment, schema, SQL mutation, physical label printing or Production field correction is authorized by this DRAFT. PRs consume the accepted requirements; #230 remains open until the reference editor and identity/labelability workflows pass full validation.

## Navigation and engineering restart

- **Permanent reference editor owner:** [#230](https://github.com/Gregovate/MSB-Production-Database-Project/issues/230); [Containers and Storage README](../README.md).
- **Movement/partial unload and historical correction:** [#88](https://github.com/Gregovate/MSB-Production-Database-Project/issues/88), [draft PR #418](https://github.com/Gregovate/MSB-Production-Database-Project/pull/418).
- **Task installed proof and no-tag visual exception:** [#132](https://github.com/Gregovate/MSB-Production-Database-Project/issues/132); [Crew Work Reporting contract](../../12_Setup_and_Deployment/engineering/Setup_Crew_Work_Reporting_Contract_2026-09-08.md).
- **January Takedown:** [#423](https://github.com/Gregovate/MSB-Production-Database-Project/issues/423).
- **Testing:** [#231](https://github.com/Gregovate/MSB-Production-Database-Project/issues/231).
- **Label media/profile/scan:** [Labeling and Scanning contract](../../07_Labeling_and_Scanning/Label_Payload_and_Profile_Architecture.md), external MSB_LabelPrintService V4 accepted preflight and current print templates.
- **GIS map and reference:** [#171](https://github.com/Gregovate/MSB-Production-Database-Project/issues/171), [draft PR #319](https://github.com/Gregovate/MSB-Production-Database-Project/pull/319).
- **Commands/runbooks and disposable/browser:** [MSB Server Management](https://github.com/Gregovate/MSB-Server-Management/blob/main/docs/server/PostgreSQL_Disposable_Acceptance_Standard.md) and [Pre-Production Browser Review](https://github.com/Gregovate/MSB-Server-Management/blob/main/docs/server/Pre_Production_Browser_Review_Runbook.md).

**Next engineering actions:** read-only live Container/Display/flag and event review for all repeat examples; resolve physical base/cargo/labelability per real Display ID; choose minimal governed #230 representation after schema inventory, then reconcile #88/#231 consumers, label capability, offline/camera flow and protected browser before asking to deploy. Preserve actual October 19 field moves and all existing audit evidence.
