# FieldWiring / Controller Inventory Design Rationale — 2026-08-20

| Item | Value |
|---|---|
| Status | ENGINEERING DECISION / RATIONALE RECORD |
| FieldWiring branch | `agent/fieldwiring-engineering-recovery` |
| Scope | Why FieldWiring uses a replaceable controller-resolution boundary and what Controller Inventory must eventually supply |
| Assignment scope | Current approved LOR/V7 snapshot only |
| Schema status | No PostgreSQL Controller Inventory schema or migration authorized by this document |

## Why This Document Exists

This document preserves the reasoning developed during FieldWiring browser acceptance and the parallel Controller Inventory review. The decisions below must not depend on conversation memory or be rediscovered later.

The repository, branch history, tests, and the documents linked below are the durable authority for this integration direction.

## Core Problem

LOR knows show programming and wiring topology. It does **not** know the permanent identity of the physical controller box installed in the park.

A raw LOR Unit ID, Unit-ID range, Network, channel/output, E1.31 universe, IP address, Display name, or physical location cannot be treated as the permanent controller identity.

The missing fact is the relationship between:

```text
permanent physical controller
        +
its current assignment/context
        +
the current approved LOR/V7 snapshot
```

FieldWiring needs that relationship so it can present field technicians with the physical controller and output interpretation while continuing to use LOR/V7 for the actual current Display/channel wiring rows.

## Why Address Alone Cannot Identify a Controller

### HWY-42 traffic signs

The HWY-42 traffic-sign Displays use several separate physical Light-O-Rama `CTB04-PC` controllers.

Confirmed operating arrangement:

- one physical controller per traffic-sign Display;
- all are on the `Regular` LOR Network;
- all use Unit ID `09`;
- the applicable sign control is Channel `1`;
- the shared programming is intentional so the traffic signs can be switched together at the beginning and end of the show schedule.

The operational reason for the repeated address is synchronization: the traffic signs are turned on together at approximately 4:30 PM and off together at approximately 9:00 PM.

Therefore multiple distinct physical controllers can simultaneously have the same:

```text
Network: Regular
UID:     09
Channel: 1
```

while each physical controller belongs to a different Display.

This proves that even `Network + UID + channel` is not a permanent physical-controller key.

### Candy Cane Pixies

Church and Candyland intentionally use multiple physical Pixie controllers carrying the same programmed Unit-ID range.

For example, Candyland has three physical Pixie 4 groups, each using the same intended `21-24` address block for a different four-Display Candy Cane group.

The address repetition is intentional and useful; it must not be normalized away or prohibited by a uniqueness rule.

## Required Current-State Cardinality

The current controller assignment relationship is not one-to-one.

The real system must support all of these current-state cases:

### Many controllers -> one Display

A sufficiently complex A/C Display may use two or more physical controllers.

Therefore a Display cannot have a single-controller foreign-key assumption.

### One controller -> many Displays

A Pixie 4 can control four separate Displays, such as a four-Candy-Cane group.

Therefore a controller cannot have a single-Display foreign-key assumption.

### One controller -> many LOR Unit IDs

A Pixie controller may span multiple Unit IDs while serving one physical Display, such as the Who Forest Tree controllers.

Therefore one physical controller cannot be equated to one Unit ID.

### Many controllers -> same Network / UID / channel

The HWY-42 CTB04-PC example proves several physical controllers can share the same Network, Unit ID, and channel while serving separate Displays.

Therefore an addressing tuple cannot be used as permanent controller identity.

## Architectural Consequence

The eventual current controller-to-Display relationship must support a **many-to-many current assignment model**.

This statement is a cardinality requirement, not authorization for a specific table design.

The Controller Inventory workstream still owns the final PostgreSQL schema and must derive it from the reviewed physical data.

## Authority Boundary

### LOR / LOR2DB remains authoritative for

- current show topology;
- current Stage/Scene/Display context;
- current LOR Network;
- Unit ID / Unit-ID range;
- channel/output relationships represented by LOR;
- DMX/E1.31 universe/channel topology; and
- the detailed wiring rows in the current approved V7/PostgreSQL snapshot.

### Controller Inventory will own

- permanent physical controller identity (`ctrl_id` / permanent controller key once the schema is approved);
- exact manufacturer/model and controller classification;
- physical output/port capability;
- serial number when available;
- current status;
- current assignment/context needed to associate that physical controller with the current approved LOR/V7 snapshot;
- the additional Display/group discriminator required when addresses are intentionally reused;
- firmware history; and
- durable controller labeling/scan identity.

### Work Orders own

Repair, troubleshooting, parts replacement, maintenance actions, and repair resolution. Controller Inventory should link the permanent controller to Work Orders rather than duplicate repair history.

## Current-State Only

FieldWiring does not require historical deployment relationships.

The permanent controller identity persists. The show assignment is current-state data tied to the current approved LOR/V7 snapshot.

When controller assignments change, the current Controller Inventory mapping can be reconciled to the newly approved snapshot. Older LOR snapshots and preserved source files remain engineering evidence without requiring historical controller-assignment rows.

## Why FieldWiring Is Not Waiting for Controller Inventory

Controller Inventory source cleanup is still in progress and the final PostgreSQL schema has not been approved.

FieldWiring browser recovery and acceptance must continue in the meantime.

Therefore FieldWiring currently uses operator-confirmed temporary controller interpretations for known physical patterns. These temporary rules are acceptable only as an interim controller-resolution implementation.

They are **not** permanent controller identity and must not become scattered architectural dependencies.

## Replaceable Controller-Resolution Boundary

FieldWiring should converge on this shape:

```text
TODAY
current LOR/V7 wiring rows
        +
operator-confirmed temporary controller resolver
        ->
FieldWiring controller/output presentation

FUTURE
current LOR/V7 wiring rows
        +
Controller Inventory resolver returning permanent ctrl_id/current assignment
        ->
same FieldWiring controller/output presentation
```

The renderer/browser should not need to be redesigned when Controller Inventory becomes authoritative.

The temporary controller design is therefore a **replaceable provider**, not throwaway browser design.

## Conceptual Future Resolver Result

The future Controller Inventory resolver/read model needs to be able to provide enough current information for FieldWiring to determine, conceptually:

```text
permanent ctrl_id
exact controller model/family
physical output/port capability
current address/controller context
current Display or Display-group discriminator where needed
current approved LOR/V7 snapshot provenance
```

The detailed Display/channel/output wiring itself continues to come from LOR/V7.

No specific table, column, foreign key, or uniqueness rule is authorized by this conceptual interface.

## Concrete Relationship Examples

### HWY-42 traffic signs

Conceptually:

```text
ctrl_id A -> Traffic Sign Display A -> Regular / UID 09 / Channel 1
ctrl_id B -> Traffic Sign Display B -> Regular / UID 09 / Channel 1
ctrl_id C -> Traffic Sign Display C -> Regular / UID 09 / Channel 1
```

The Display context distinguishes the physical controllers because the LOR address is intentionally identical.

### Candyland Candy Canes

Conceptually:

```text
ctrl_id D -> Candy Canes 01-04 -> UID 21-24
ctrl_id E -> Candy Canes 05-08 -> UID 21-24
ctrl_id F -> Candy Canes 09-12 -> UID 21-24
```

One physical Pixie 4 controls four Displays, while multiple physical Pixie 4 controllers reuse the same programmed range.

### Complex A/C Display

Conceptually:

```text
ctrl_id G \
           -> Display X
ctrl_id H /
```

One Display may require more than one physical A/C controller.

### Who Forest Tree

One physical Pixie controller can span multiple Unit IDs while serving the Tree Display. The physical controller must remain one asset even though LOR represents several Unit IDs.

## Important Non-Decisions

This rationale does **not** authorize:

- creation of Controller Inventory PostgreSQL tables;
- a specific controller-assignment junction table;
- a `ctrl_id` data type or naming sequence;
- a uniqueness rule on Network/UID/range/channel;
- historical deployment relationships;
- manual duplication in Controller Inventory of every LOR Display/output row; or
- replacement of LOR as wiring/topology authority.

Those decisions remain gated on the reviewed Controller Inventory data.

## Current FieldWiring Acceptance Context

FieldWiring recovery currently includes temporary named/operator-confirmed controller patterns for Church, Candyland, Who Forest, Santa's Workshop, and other reviewed cases.

The branch also contains a known implementation issue around the stale Candyland third Candy Cane block: the temporary stale-source exception must be limited to the actual Candyland Scene while generic inconsistent repeated blocks continue to fail safe. That implementation issue does not change the controller-integration architecture recorded here.

## Recovery Rule for Future Threads

If a future conversation, engineer, or tool needs to understand why Controller Inventory and FieldWiring are designed this way, do **not** rediscover the model from LOR addresses alone.

Start with this rationale and the linked documents, then inspect current branch tests and source evidence.

The key invariant is:

> LOR describes current programmed wiring behavior; Controller Inventory identifies the physical controller asset and its current association to that wiring context. Neither system alone can represent all current physical-controller relationships.

## Related Durable Records

- [Controller Inventory Current-State / FieldWiring Integration Plan — 2026-08-20](../08_Controller_Inventory/Controller_Inventory_Current_State_FieldWiring_Integration_Plan_2026-08-20.md)
- [Controller Inventory Current Assignment Cardinality — 2026-08-20](../08_Controller_Inventory/Controller_Inventory_Current_Assignment_Cardinality_2026-08-20.md)
- [Controller Inventory / LOR Address Ambiguity — HWY-42 — 2026-08-20](../08_Controller_Inventory/Controller_Inventory_LOR_Address_Ambiguity_HWY42_2026-08-20.md)
- [Controller Inventory and Labeling Plan](../08_Controller_Inventory/Controller_Inventory_and_Labeling_Plan.md)
- [FieldWiring / Controller Inventory Handoff — 2026-08-20](FieldWiring_Controller_Inventory_Handoff_2026-08-20.md)
- [FieldWiring Physical Controller / Output Presentation Contract](FieldWiring_Physical_Controller_Output_Presentation_Contract.md)
- [FieldWiring RGB Controller Pattern Findings — 2026-08-19](FieldWiring_RGB_Controller_Pattern_Findings_2026-08-19.md)
- [FieldWiring Church RGB Tree Star Controller Context — 2026-08-20](FieldWiring_Church_RGB_Tree_Star_Controller_Context_2026-08-20.md)
- [FieldWiring Candyland Stale Snapshot Output Mapping — 2026-08-20](FieldWiring_Candyland_Stale_Snapshot_Output_Mapping_2026-08-20.md)
