# Controller Inventory / LOR Address Ambiguity — HWY-42 — 2026-08-20

| Item | Value |
|---|---|
| Status | ENGINEERING FINDING — Controller Inventory / FieldWiring integration |
| Subsystem owner | Controller Inventory |
| Consumer | FieldWiring |
| Assignment scope | Current approved LOR/V7 snapshot only |
| Schema status | No PostgreSQL schema or migration authorized by this finding |

## Purpose

This finding records a current MSB controller case that proves LOR Unit ID plus channel information cannot directly identify a permanent physical controller.

Together with the already-documented repeated-address Pixie cases, it reinforces the broader rule that current LOR addressing must not be treated as permanent controller identity.

It supplements the current Controller Inventory / FieldWiring integration plan and return handoff.

## Confirmed HWY-42 Example

The HWY-42 traffic-sign Displays use several physical Light-O-Rama `CTB04-PC` controllers.

The physical arrangement is one controller for each applicable Display.

The controllers intentionally share the same programmed LOR values:

```text
UID 09
Channel 1
```

Therefore multiple separate physical controllers can present the same Unit ID and channel while serving different Displays.

The LOR Network for each controller was not established by this finding and must not be inferred here.

## Consequence

There is no direct permanent-controller link in LOR.

LOR knows the show wiring relationship and its programmed address values. It does not know the MSB permanent physical controller identity.

The HWY-42 case specifically proves that neither of these is sufficient physical identity:

- Unit ID alone; or
- Unit ID + channel.

The broader current FieldWiring evidence also establishes that Network + Unit ID/range must not be defined as permanent controller identity because separate physical controllers may intentionally reuse the same programmed address context.

Those values describe current show addressing, not permanent hardware identity.

## Current-Assignment Mapping Requirement

Where an address/context is unique in the current snapshot, it may be sufficient evidence to associate one permanent controller with the current LOR context.

Where the programmed address is reused, Controller Inventory must provide an additional current physical discriminator.

That discriminator may be the current Display itself or another reviewed Display/group context.

Conceptually:

```text
current LOR/V7 wiring context
    Display / Display group
    Network when applicable
    UID / UID range
    channel/output context
        +
Controller Inventory current assignment
        ->
permanent ctrl_id
```

No specific table or column design is authorized by this document.

## HWY-42 Conceptual Example

Conceptually, the Controller Inventory side must eventually be able to distinguish records such as:

```text
ctrl_id A | CTB04-PC | UID 09 | Channel 1 | HWY-42 Display A
ctrl_id B | CTB04-PC | UID 09 | Channel 1 | HWY-42 Display B
ctrl_id C | CTB04-PC | UID 09 | Channel 1 | HWY-42 Display C
```

The exact Display identities, Network values, and eventual PostgreSQL representation must come from reviewed current source data. The example above illustrates the relationship only; it is not authorization to create these rows or identifiers now.

## FieldWiring Handoff Requirement

FieldWiring should continue to obtain the detailed Display/channel/output topology from the current approved LOR/V7 snapshot.

The future Controller Inventory resolver should enrich that topology by returning the permanent physical controller identity for the applicable current Display/address context.

This allows the current temporary controller design to be replaced later without redesigning the browser presentation:

```text
TODAY
operator-confirmed temporary controller grouping
        -> FieldWiring presentation

FUTURE
Controller Inventory current assignment -> permanent ctrl_id
        -> same FieldWiring presentation
```

The resolver boundary must support both address-unique controllers and address-duplicate controllers such as the HWY-42 CTB04-PC case.

## Rule Established

> A LOR address identifies programmed show behavior, not a physical controller asset. When several physical controllers share the same current address values, the permanent controller must be resolved using Controller Inventory plus the applicable current Display or reviewed physical group context.

## Related Documents

- [Controller Inventory Current-State / FieldWiring Integration Plan — 2026-08-20](Controller_Inventory_Current_State_FieldWiring_Integration_Plan_2026-08-20.md)
- [Controller Inventory and Labeling Plan](Controller_Inventory_and_Labeling_Plan.md)
- [FieldWiring / Controller Inventory Handoff — 2026-08-20](../09_Wiring_System/FieldWiring_Controller_Inventory_Handoff_2026-08-20.md)
- [FieldWiring Physical Controller / Output Presentation Contract](../09_Wiring_System/FieldWiring_Physical_Controller_Output_Presentation_Contract.md)
