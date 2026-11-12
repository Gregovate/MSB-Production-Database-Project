# Controller Inventory Current-State / FieldWiring Integration Plan — 2026-08-20

| Item | Value |
|---|---|
| Status | CURRENT PRODUCTION INTEGRATION CONTRACT |
| Subsystem owner | Controller Inventory |
| Consumer | FieldWiring |
| Permanent controller authority | `ref.controller*` |
| Current show-wiring authority | approved LOR / Parser V7 / LOR2DB snapshot |
| Issue | #110 |

## Purpose

This document records the current production boundary between permanent Controller Inventory and FieldWiring. The original pre-DDL/source-review phase is closed. Permanent Controller Inventory is installed and the Controller/FieldWiring read integration is operational.

The initial Controller spreadsheet and stage reconstruction are historical migration evidence only. They are not current operational authority and are not updated after migration.

## Current production state

Permanent Controller Inventory is installed in:

```text
ref.controller_model
ref.controller_firmware_version
ref.controller_status
ref.controller
ref.controller_display
ref.controller_firmware_history
```

The accepted initial permanent set contains 177 controllers with permanent IDs `1001` through `1177`.

The working Controller Inventory / FieldWiring read experience includes:

- permanent Controller ID and exact model context;
- Stage/Sub-stage-aware Controller browsing;
- current programmed LOR Network / First UID / UID Count / calculated UID range / management IP presentation;
- permanent Controller-to-Display relationships;
- `wiring_source_display_id` for reviewed duplicated-channel physical copies;
- Controller Inventory -> Field Wiring navigation; and
- Field Wiring -> permanent Controller Inventory cross-links.

## Authority boundary

### Controller Inventory owns

- permanent physical controller identity: `ref.controller.controller_id`;
- exact manufacturer/model reference;
- installed firmware and firmware verification/history;
- controller status, location, serial/hardware facts, notes, and verification facts;
- current physical Controller-to-Display relationship;
- reviewed `wiring_source_display_id` relationship when a physical copy intentionally uses another Display's LOR wiring definition;
- the physical controller's **current programmed configuration**, including current LOR Network / Unit ID information or applicable current management-IP configuration; and
- permanent Controller label/request state.

### LOR / Parser V7 / LOR2DB owns

- authoritative current show topology;
- the Network / Unit ID / channel / output / universe configuration the current approved show requires;
- current Display wiring relationships represented in LOR;
- Preview / Scene context; and
- current source wiring provenance.

### FieldWiring owns

- technician-facing read presentation that combines permanent Controller Inventory facts with current approved LOR wiring;
- current physical-controller resolution where the governed Controller relationship/configuration is sufficient; and
- explicit unresolved/review behavior where governed data is not sufficient.

Controller Inventory does not rewrite LOR show topology, and FieldWiring does not become an authoring system.

## Current programmed configuration correction

A physical controller must retain what it is **currently programmed as** even though LOR remains authoritative for what the current show **requires**.

For LOR-addressed controllers, permanent Controller Inventory therefore carries the current programmed values in `ref.controller`, including:

```text
lor_network
lor_uid_start
lor_uid_count
lor_uid_end   -- calculated/generated presentation boundary
```

For applicable network-managed controllers, `management_ip` is also current Controller Inventory state.

These values are mutable current configuration. They are not permanent identity and are not globally unique. Intentional duplicate Network/UID ranges remain valid.

Operational comparison is:

```text
physical controller current configuration   -> ref.controller
current show-required configuration          -> LOR / approved V7 snapshot
comparison / verification                    -> setup / reconciliation / FieldWiring context
```

A mismatch is a verification/reprogramming condition, not a new physical controller identity.

See `Controller_Current_Programmed_Configuration_Contract_2026-08-31.md`.

## Permanent Controller-to-Display relationship

Current physical assignment is many-to-many:

```text
one controller -> zero, one, or many Displays
one Display    -> zero, one, or many controllers
```

The durable pair is:

```text
controller_id <-> display_id
```

The permanent junction key remains:

```text
PRIMARY KEY (controller_id, display_id)
```

Do not use Network, UID/range, universe, IP address, Display name, Stage, Scene, source row, or import-run identity as permanent controller identity.

Assignments are current-state only. Historical assignment rows are not required merely because the show configuration changes. Firmware history remains the controller-specific history intentionally preserved.

## Relationship stability across new LOR ingests

A normal new LOR2DB ingest does not automatically replace a permanent physical Controller-to-Display relationship.

Conceptually:

```text
Run N
CTRL 1058 <-> Display 701

Run N+1
CTRL 1058 <-> Display 701       normally unchanged
show-required Network/UID/etc.  may change
```

If the physical controller/Display relationship actually changes, update the governed `ref.controller_display` relationship through Controller Management.

If only LOR addressing changes, preserve the permanent physical assignment and compare/update the controller's current programmed configuration as an explicit operational step.

If a Display no longer resolves to expected current LOR wiring, surface a review condition rather than silently deleting the physical assignment.

## Repeated-address and duplicated-channel cases

Repeated programmed addresses are legal. Permanent identity comes from `controller_id`, not address uniqueness.

Accepted examples include:

- Highway 42 traffic-sign controllers intentionally sharing an address;
- Church and Candyland Pixie groups intentionally reusing UID ranges; and
- Glistening Grove physical copies intentionally using another Display's current LOR wiring definition.

For a physical Controller/Display relationship:

```text
physical controller = ref.controller.controller_id
physical Display     = ref.controller_display.display_id
wiring Display       = COALESCE(
    ref.controller_display.wiring_source_display_id,
    ref.controller_display.display_id
)
```

See `Controller_FieldWiring_Repeated_Address_and_Duplicated_Channel_Cases_2026-08-30.md`.

## Capacity and resolution rule

Controller capacity is based on the physical resources/outputs required, not simply the number of assigned Displays.

Do not use either of these invalid assumptions:

```text
one Display = one controller
assigned Display count <= controller output count
```

Conventional A/C, Pixie, E1.31, and other families require family-appropriate interpretation of the current LOR wiring. FieldWiring may resolve exact physical controller context only where the governed permanent relationship/current configuration is sufficient.

Known limitation: E1.31 exact physical port/universe partition remains incomplete where no governed physical-controller partition exists. Do not invent a partition from universe ordering alone.

## Controller Management write boundary

The Controller Inventory / FieldWiring read application remains read-only until the authenticated Manager write path is implemented.

The accepted operational direction is browser-native Controller Management:

- Add Controller;
- Edit Controller;
- edit current programmed Network/UID/IP configuration;
- assign/reassign/unassign Displays;
- maintain reviewed `wiring_source_display_id` when required;
- maintain status/location/firmware/verification facts; and
- request Controller labels through the existing `print_label` contract.

Directus supplies login/session/Manager authorization. Purpose-built browser workflow owns operational editing. PostgreSQL remains constraints/audit/final data authority. Do not make the existing `fieldwiring_app` PostgreSQL role broadly writable.

## Ongoing handoff rule

Whenever FieldWiring engineering discovers a requirement that changes permanent controller identity, current programmed configuration, model capability, Controller-to-Display relationship semantics, duplicated-address behavior, E1.31 resolution, or Controller/FieldWiring navigation, update the responsible Controller Inventory and Wiring System documents before the change is considered fully documented.

Conversation history and retired spreadsheets are not the recovery mechanism.
