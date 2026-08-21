# Controller Inventory Current Assignment Cardinality — 2026-08-20

| Item | Value |
|---|---|
| Status | ENGINEERING FINDING — current-state assignment requirements |
| Subsystem owner | Controller Inventory |
| Consumer | FieldWiring |
| Assignment scope | Current approved LOR/V7 snapshot only |
| Schema status | No PostgreSQL table/column design authorized by this finding |

## Purpose

This finding records the real controller-to-Display cardinality that the eventual Controller Inventory current-assignment model and FieldWiring controller-resolution boundary must support.

It supplements the Controller Inventory current-state integration plan and the FieldWiring return handoff. It does not authorize a schema implementation.

## Confirmed Real Cases

### HWY-42 traffic signs — several physical controllers, identical LOR address/channel

The HWY-42 traffic-sign Displays each use their own physical `CTB04-PC` controller.

All of these controllers are on the LOR `Regular` network and intentionally use:

```text
UID 09
Channel 1
```

This is deliberate. The shared programmed address allows all of the traffic signs to be controlled together so they turn on at the start of the show (4:30 PM) and off at 9:00 PM in synchronization.

Therefore several different physical controllers can have the same current:

```text
Network = Regular
UID     = 09
Channel = 1
```

while each controller belongs to a different Display.

This proves `Network + UID + Channel` is not a permanent controller identifier and is not sufficient by itself to determine which physical controller is involved.

### One Display may use multiple A/C controllers

A sufficiently complex Display may require two or more conventional A/C controllers.

Therefore Controller Inventory must not assume:

```text
one Display -> one controller
```

The current assignment relationship must allow multiple permanent controller assets to be associated with one Display/current wiring context.

### One Pixie controller may span multiple UIDs for one Display

Who Forest Trees are current examples where one physical Pixie controller serves one Display while LOR represents that controller through multiple Unit IDs.

Therefore Controller Inventory must not assume:

```text
one controller -> one UID
```

A single permanent controller may correspond to a Unit-ID range or multiple address rows in the current snapshot.

### One Pixie controller may serve multiple Displays

Candy Cane patterns are current examples where one Pixie 4 physically serves four separate Displays.

Therefore Controller Inventory must not assume:

```text
one controller -> one Display
```

The current assignment relationship must allow one permanent controller asset to serve several Displays.

## Cardinality Requirement

Taken together, the current controller-to-Display relationship is many-to-many.

The eventual design must support all of the following without special-case schema redesign:

```text
many controllers -> one Display
one controller   -> many Displays
one controller   -> many UIDs/address rows
many controllers -> same Network + UID + channel
```

The physical controller itself still has one permanent identity (`ctrl_id` or equivalent future key). The many-to-many requirement applies to the controller's current assignment into the current approved LOR/V7 topology.

## FieldWiring Resolution Boundary

FieldWiring must continue to obtain detailed current wiring topology from LOR/V7.

The future controller resolver must use enough current wiring context to distinguish the physical controller where address information is ambiguous.

Conceptually:

```text
current approved LOR/V7 wiring row/context
    display_id
    Preview / Scene context
    Network
    UID / UID range
    channel/output information
        +
Controller Inventory current assignment
        ->
permanent physical controller identity
```

The exact set of resolver inputs and the eventual PostgreSQL representation must be designed from reviewed source data. This document does not authorize specific columns or a specific junction-table name.

## Important Consequence for the Temporary FieldWiring Design

The current operator-confirmed controller mappings are a temporary implementation of the future controller-resolution function.

They should be isolated so that the later Controller Inventory implementation can replace the temporary provider with an authoritative current-assignment provider that returns permanent controller identity without changing the FieldWiring browser presentation.

The target transition remains:

```text
TODAY
operator-confirmed temporary controller resolution
        -> FieldWiring presentation

FUTURE
Controller Inventory current assignment + permanent ctrl_id
        -> same FieldWiring presentation
```

## Rule Established

> LOR address information describes programmed show behavior. Physical controller identity is a separate fact. Because controller-to-Display assignment is many-to-many and LOR addresses can be intentionally reused, the eventual Controller Inventory current-assignment model must map permanent physical controllers into the current approved LOR/V7 Display/address context rather than treating UID, channel, Display, or address range as a one-to-one controller key.

## Related Documents

- [Controller Inventory Current-State / FieldWiring Integration Plan — 2026-08-20](Controller_Inventory_Current_State_FieldWiring_Integration_Plan_2026-08-20.md)
- [Controller Inventory / LOR Address Ambiguity — HWY-42 — 2026-08-20](Controller_Inventory_LOR_Address_Ambiguity_HWY42_2026-08-20.md)
- [Controller Inventory and Labeling Plan](Controller_Inventory_and_Labeling_Plan.md)
- [FieldWiring / Controller Inventory Handoff — 2026-08-20](../09_Wiring_System/FieldWiring_Controller_Inventory_Handoff_2026-08-20.md)
