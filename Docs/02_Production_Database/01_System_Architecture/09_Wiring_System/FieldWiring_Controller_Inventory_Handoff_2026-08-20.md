# FieldWiring / Controller Inventory Handoff — 2026-08-20

| Item | Value |
|---|---|
| Status | CURRENT CROSS-WORKSTREAM CONTRACT — PERMANENT CONTROLLER INTEGRATION ACTIVE |
| Issue | #110 |
| FieldWiring ownership | Browser wiring presentation and consumption of permanent Controller relationships |
| Controller Inventory ownership | Permanent physical controller identity, current Controller-to-Display relationships, current programmed controller facts |
| Schema status | FieldWiring does not own or authorize Controller Inventory schema changes |
| Current Controller architecture | [Controller Management Application Boundary — 2026-08-31](../08_Controller_Inventory/Controller_Management_Application_Boundary_2026-08-31.md) |

## Purpose

This note is the durable handoff between FieldWiring and Controller Inventory. It exists so Controller requirements discovered during FieldWiring engineering and Controller integration are available from the repository rather than depending on conversation memory.

Controller Inventory owns its PostgreSQL model and permanent physical identities. FieldWiring is a consumer of those governed facts plus the current LOR/V7 wiring snapshot.

## Current Accepted Production Checkpoint

The first permanent Controller Inventory / FieldWiring integration is now production-accepted.

```text
production checkout           84d6f06e16c43ebb0f6aa21273b999af7f6d455b
FieldWiring                   V0.3.1 / postgres / healthy
Procedures                    V0.1.0 / postgres / healthy
combined live regression      183 passed in 2.39s
```

Accepted current behavior includes:

- permanent Controller Inventory is populated and authoritative for physical `controller_id`;
- Stage/Sub-stage-aware Controller browsing is working;
- current programmed LOR Network / UID / management IP facts are visible in Controller Inventory;
- FieldWiring shows permanent Controller ID and model context where governed Controller relationships resolve the physical device;
- FieldWiring provides a Controller Inventory cross-link;
- Controller Inventory assignments provide **Open Field Wiring** links back to the relevant Display wiring view;
- LOR/V7 remains authoritative for detailed current wiring topology;
- the shared FieldWiring + Procedures regression gate is the deployment safety gate.

The older temporary Controller presentation logic described later in this document remains historical/bridge evidence only where a presentation family still lacks enough governed permanent Controller resolution.

## Authority Boundary

- LOR is authoritative for current show topology, addressing, channels, universe/network assignments, and wiring definitions.
- PostgreSQL owns permanent Production Database identities, current Controller relationships, constraints, and audit.
- `ref.display.display_id` is permanent Display identity; LOR Prop UUID / `lor_prop_id` is an external binding.
- `ref.controller.controller_id` is permanent physical Controller identity.
- Google Shared Drive `Display Folders` remains the engineering document/image authority used by FieldWiring.
- FieldWiring does **not** own the Controller Inventory schema.
- Controller Inventory provides permanent physical controller identity plus the current physical Controller-to-Display relationship.
- FieldWiring does **not** require historical controller deployment relationships.

Permanent physical controller identity must **not** be based on:

- LOR Unit ID or Unit-ID range;
- E1.31 universe;
- IP address;
- Display name;
- physical location alone;
- Stage/Scene context.

Intentional repeated addresses are valid. One E1.31 controller may span many universes, and one Display may use multiple physical controllers.

## Accepted Permanent Resolver Contract

The permanent relationship basis is:

```text
physical controller = ref.controller.controller_id
physical Display     = ref.controller_display.display_id
wiring Display       = COALESCE(
    ref.controller_display.wiring_source_display_id,
    ref.controller_display.display_id
)
```

FieldWiring uses the governed Controller-to-Display relationship first. Current programmed Network/UID may then distinguish which already-assigned physical Controller applies to an AC/Pixie wiring row. Addressing is never promoted into permanent physical identity.

For reviewed duplicated-channel physical copies, `wiring_source_display_id` provides the explicit bridge to the Display whose current LOR wiring defines the hookup.

## Current-State Assignment Scope

FieldWiring answers the current operational question:

> Which permanent physical controller is assigned to the wiring relationships in the current approved LOR/V7 snapshot?

The controller itself has permanent identity. Its Display assignment, current programmed address, management IP, physical location, firmware, and status are mutable current-state facts.

There is no FieldWiring requirement to preserve each prior controller deployment as historical relationship rows. Older LOR snapshots and preserved source artifacts remain engineering evidence without requiring duplicate Controller deployment-history relationships.

## Controller Management Boundary

Controller Management is now explicitly a browser-native/custom application workflow.

Directus remains the shared login/identity/Manager-policy authority and may still be used for simple one-table/reference maintenance. It is **not** the Controller operational editor.

The accepted Manager workflow belongs in the Controller browser:

```text
Controller Detail
    -> authenticated Manager check
    -> Edit Controller / Add Controller
    -> current programmed Network / UID / IP maintenance
    -> Assign / Reassign / Unassign Displays
    -> label request state
    -> PostgreSQL validation/audit
```

Do not make `fieldwiring_app` broadly writable merely to support Controller Management. The server-side write path must have its own governed authorization and database-write boundary.

The permanent relationship key remains:

```text
PRIMARY KEY (controller_id, display_id)
```

Do not introduce a surrogate relationship key merely to satisfy Directus.

## Directus Relationship Experiment — Closed

Live testing showed that the multi-table Controller workflow did not fit Directus reliably. The attempted reverse relationship workspaces caused Controller item-detail failures around the legitimate composite relationship model.

The accepted cleanup removed the Directus `display_assignments` and `firmware_history` reverse workspaces plus temporary assignment DELETE capability while preserving permanent data and the composite key. Validation returned:

```text
DIRECTUS CONTROLLER SIMPLIFICATION: PASS
```

Accepted post-cleanup data counts were:

```text
Controller/Display assignments  194
firmware-history rows            172
```

Do not resume the Directus O2M relationship workspace as a FieldWiring/Controller integration task.

## Current FieldWiring Implementation Consequence

FieldWiring no longer needs to wait for a future Controller Inventory subsystem before showing permanent physical context. The first permanent resolver integration is active.

Current rules:

- show permanent `controller_id` and exact model where governed Controller relationships resolve the physical device;
- use `ref.controller_display` before using current programmed Network/UID to distinguish physical controllers;
- preserve intentional duplicate addresses;
- use `wiring_source_display_id` for reviewed duplicated-channel copies;
- continue sourcing detailed Network/UID/channel/universe wiring from LOR/V7;
- do not invent wiring for an assigned Controller/Display without current approved LOR wiring or a reviewed wiring source;
- keep any remaining temporary named/family-specific mappings centralized and replaceable until their real cases are covered by permanent Controller evidence and regression accepted.

## Confirmed Consumer Requirements

### Reused Unit IDs

Repeated Unit IDs across separate operator-confirmed physical Displays can be positive evidence of multiple physical controllers. Reused addresses must not be treated as permanent physical identity and must not be "fixed" merely because they repeat.

### Physical Grouping vs Current Snapshot Output Mapping

A known physical controller grouping and the current snapshot output relationships inside that controller are separate concerns.

FieldWiring may preserve an operator-confirmed physical controller group while displaying the exact current snapshot wiring relationships inside that group. FieldWiring must not silently rewrite stale LOR topology outside the normal controlled parser/import cycle.

A physical output may legitimately show more than one Display/connection relationship when the current source topology says so.

### Unknown Physical Detail

When the controller context is known but the exact physical output mapping is not established, FieldWiring must preserve the known Controller context without inventing the missing physical fact. Unknown output may be shown as `—`; this is different from a genuinely unresolved grouping that requires review.

## Historical / Accepted Examples

These examples remain useful evidence for regression and for understanding why permanent identity cannot be inferred from addressing.

### Church RGB Tree Star

`CH-RGBTree-Star` is a controller context separate from `CH-RGBTree-16x100-180`.

Confirmed historical evidence:

- Network: `Aux N`;
- LOR Unit-ID span: `40-41`;
- not part of the Tree Pixie 16 at `30-3F`.

See `FieldWiring_Church_RGB_Tree_Star_Controller_Context_2026-08-20.md`.

### Church RGB Candy Canes

Eight Candy Canes use two physical Pixie 4 controllers. Each controller intentionally uses Unit IDs `21-24` and Outputs 1-4.

### Candyland RGB Candy Canes

Twelve Candy Canes use three physical Pixie 4 controllers. Repeated `21-24` ranges are intentional physical-controller reuse, not identity conflicts.

The historical stale-snapshot case that temporarily showed Cane 12 on `22` instead of corrected `24` remains useful regression evidence for the rule that FieldWiring preserves the current approved snapshot rather than silently rewriting source topology.

See `FieldWiring_Candyland_Stale_Snapshot_Output_Mapping_2026-08-20.md`.

### Candyland RGB Lollipops

The reviewed topology is one Pixie 16 presentation spanning Unit IDs `50-5B` with twelve physical outputs across eight Lollipop Displays. This illustrates why Display count and Unit-ID count are not Controller identity.

### Who Forest

Reviewed Pixie 8 groups use multiple contiguous ranges from `50-57` through `88-8F`. Historical source conflicts must remain explicit until corrected through the governed source/ingest path.

### E1.31 / Dense RGB

E1.31 universes are addressing, not physical Controller identity. A single physical controller may span many universes. FieldWiring must not infer controller count merely from universe rows.

Current Controller Inventory provides assignment context, but exact universe-to-physical-controller partitioning may still require additional governed evidence for some E1.31 cases.

### CR50 / DumbRGB boundary

A CR50 fixture is a field presentation/fixture concept, not automatically a permanent Controller Inventory asset. FieldWiring may aggregate LOR source rows into technician-facing fixture instructions without creating one permanent controller record per fixture.

## E1.31 / DMX Consumer Requirements

Parser V7.0.11+ preserves detailed grouped-DMX source wiring information on atomic DMX rows, including:

```text
RawPropID
ChannelName
ChannelGridRowNumber
Universe
StartChannel
EndChannel
```

Those fields remain LOR/LOR2DB wiring authority. They are **not** Controller Inventory identity fields.

For E1.31, FieldWiring may require enough permanent assignment information to determine the physical Controller and, where governed evidence exists, the applicable physical output/port. Controller Inventory should not duplicate every LOR universe/channel relationship when a simpler reviewed controller/output rule is sufficient.

## Ongoing Handoff Rule

This handoff is continuous for the life of the FieldWiring and Controller Inventory workstreams.

Whenever FieldWiring discovers a new requirement affecting permanent controller identity, exact model, physical output capability, current assignment/addressing, duplicate-address grouping, E1.31 controller/output resolution, or mapping provenance, update the responsible Controller Inventory and Wiring System documents **during the work** before later engineering depends on the discovery.

Whenever Controller Inventory changes the permanent resolver or Manager workflow in a way that affects FieldWiring, update this handoff and the Wiring System current-state documentation in the same workstream.

Issue comments and conversation history are implementation evidence, not substitutes for the controlled handoff.

## Current Resume Point

The read-side Controller/FieldWiring integration is accepted. Do not resume from the historical temporary-grouping investigation as if permanent Controller Inventory were still future work.

Current cross-workstream next steps are:

1. browser-native Directus-authenticated Manager boundary in Controller Inventory;
2. Edit/Add Controller workflow;
3. governed current programmed Network/UID/IP editing;
4. Controller ↔ Display assignment/reassignment/unassignment workbench;
5. Manager `print_label` request action;
6. real shelf-stock/reassignment acceptance;
7. continue replacing remaining temporary FieldWiring presentation mappings only when permanent Controller evidence fully covers their real cases;
8. preserve the shared FieldWiring + Procedures regression gate for every deployment.

## Related Documents

- [Controller Management Application Boundary — 2026-08-31](../08_Controller_Inventory/Controller_Management_Application_Boundary_2026-08-31.md)
- [Controller Inventory Operational Implementation Roadmap — 2026-08-31](../08_Controller_Inventory/Controller_Inventory_Operational_Implementation_Roadmap_2026-08-31.md)
- [Controller Inventory Current-State / FieldWiring Integration Plan — 2026-08-20](../08_Controller_Inventory/Controller_Inventory_Current_State_FieldWiring_Integration_Plan_2026-08-20.md)
- [Controller Inventory](../08_Controller_Inventory/README.md)
- `FieldWiring_Physical_Controller_Output_Presentation_Contract.md`
- `FieldWiring_E131_Dense_RGB_Field_Presentation_Contract.md`
- `FieldWiring_DMX_DumbRGB_Field_Presentation_Contract.md`
- `FieldWiring_PostgreSQL_DMX_Propagation_Change_Map_2026-08-21.md`
- `FieldWiring_RGB_Controller_Pattern_Findings_2026-08-19.md`
- `FieldWiring_Church_RGB_Tree_Star_Controller_Context_2026-08-20.md`
- `FieldWiring_Candyland_Stale_Snapshot_Output_Mapping_2026-08-20.md`
- `FieldWiring_Accepted_Baseline_Recovery_2026-08-20.md`
