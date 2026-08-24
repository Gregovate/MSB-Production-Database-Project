# LOR Network Configuration and UID Management Engineering Plan

| Document control | Value |
|---|---|
| Status | DRAFT — engineering reconnaissance / design requirements |
| Initial revision | 2026-08-23 |
| Owner | MSB Database Administrator / LOR engineering owner |
| Scope | Current LOR Network Preferences visibility, UID allocation, serial-port binding, E1.31 routing |
| Production changes | NOT AUTHORIZED by this plan |

## Purpose

MSB needs an understandable way to see how Light-O-Rama networks are configured and which addresses are already in use before adding or re-addressing controllers.

The current Light-O-Rama Network Preferences live in the Show-PC Windows registry. That registry remains LOR's active configuration source, but it is not a practical human management interface for MSB engineering.

The objective is to build a read-only normalized view that combines:

1. current LOR Network Preferences from the Show PC;
2. current Network + UID usage from the approved LOR/V7 snapshot;
3. current E1.31 universe/IP routing from LOR Network Preferences; and
4. MSB-owned planned/reserved address information not yet present in LOR.

This plan defines requirements only. It does not authorize PostgreSQL tables, registry writes, or changes to LOR Network Preferences.

## Core Architecture

The system must preserve four different concepts.

### 1. Logical LOR network

MSB currently uses the conventional LOR network names:

```text
Regular
Aux-A
Aux-B
Aux-C
Aux-D
Aux-E
Aux-F
Aux-G
Aux-H
Aux-I
Aux-J
Aux-K
Aux-L
Aux-M
Aux-N
Aux-O
```

These are logical LOR network identities/configuration contexts.

### 2. Show-PC transport binding

A conventional LOR network is currently bound by LOR Network Preferences to Show-PC communication settings such as:

- current serial/COM port;
- speed;
- Enhanced mode; and
- any other LOR transport settings established by direct registry/UI inspection.

The exact source field names and values must be reverse engineered from the current Show-PC registry before implementation.

A Windows COM number is mutable configuration. It must not become the permanent identity of a physical USB/RS-485 adapter.

### 3. Current LOR command/address usage

The current approved LOR/V7 snapshot establishes which Network + Unit ID / Unit-ID ranges are actually used by current show topology.

Network + UID/range is a current programmed command group, not permanent physical-controller identity.

Multiple physical controllers may intentionally share one command group and therefore repeat the same LOR commands.

### 4. Physical controller and physical network hardware

Controller Inventory owns permanent physical controller identity.

Network Infrastructure owns physical network hardware and topology, including USB/RS-485 adapter identity when that equipment is brought into the inventory model.

The LOR Network Configuration subsystem links those adjacent facts but does not replace either system.

## Operator / Engineering View Requirement

The normal LOR-network summary should make the current configuration understandable without opening Registry Editor.

Conceptually:

| LOR Network | Status | COM Port | Speed | Enhanced | Used UIDs | Reserved | Notes |
|---|---|---|---|---|---:|---:|---|
| Regular | current | source value | source value | source value | derived | planned | ... |
| Aux-A | current | source value | source value | source value | derived | planned | ... |
| ... | ... | ... | ... | ... | ... | ... | ... |
| Aux-O | current | source value | source value | source value | derived | planned | ... |

Actual COM-port, speed, and Enhanced values must come from the current Show-PC source. This document does not guess them.

Selecting a network should open an address-usage view.

Conceptually:

```text
AUX-O
Current COM port: <source value>
Speed: <source value>
Enhanced: <source value>
Source captured: <timestamp>
Approved LOR/V7 snapshot: Run <X>

UID    State                  Current use
20     SHARED COMMAND GROUP   Elden standard group
21     FREE                   —
22     SHARED COMMAND GROUP   Felix standard group
23     RESERVED / PLANNED     <planned purpose>
24     SHARED COMMAND GROUP   Ralphie standard group
...
```

This is a planning and visibility tool. It must not imply that one UID equals one physical controller.

## UID Occupancy Rules

### IN USE

A UID is `IN USE` when the current approved LOR/V7 snapshot contains current wiring/address relationships using that UID on the selected LOR network.

### SHARED COMMAND GROUP

A UID is a `SHARED COMMAND GROUP` when the same current Network + UID intentionally applies to more than one current Display and/or more than one physical controller assignment.

Examples already established in current engineering evidence include:

- HWY-42 traffic controllers sharing `Regular` + the same UID so one command operates multiple signs; and
- Glistening Grove character groups where several physical controller-equipped Displays intentionally share one Network + UID command group.

A shared command group is not automatically a conflict.

### RESERVED / PLANNED

A UID is `RESERVED / PLANNED` when MSB has intentionally held that address for approved planned work that has not yet reached the current LOR/V7 snapshot.

This state is necessary because current-snapshot inspection alone cannot prevent two future projects from choosing the same currently-free UID.

Reservation is MSB planning data, not LOR source data.

### FREE

A UID may be presented as `FREE` only when:

- the current approved LOR/V7 snapshot does not use it on that network; and
- there is no active MSB reservation for it.

The valid Unit-ID address domain itself must be confirmed from the current LOR configuration/documented product rules before implementing a complete free-address grid. This plan does not invent an address range.

### REVIEW

Use `REVIEW` when current sources disagree or when the available evidence is insufficient to say safely whether an address should be considered available.

## UID Range Requirement

Some controller configurations consume more than one Unit ID.

The future planning interface must therefore support questions such as:

> Find a contiguous block of N available UIDs on Aux-I.

The required span must be provided from the reviewed controller/configuration requirement. Do not hard-code a universal rule that a given model always consumes a fixed UID count unless that rule has been established for the actual operating mode.

The allocator should be able to report:

```text
requested span: N
candidate free blocks: ...
blocked because current LOR use: ...
blocked because reservation: ...
```

It must also allow an engineer deliberately to join an existing shared command group when that is the intended show behavior rather than forcing every new physical controller to have a unique UID.

## Current-Source Idempotence

Repeated read-only captures of unchanged Show-PC Network Preferences and unchanged current LOR/V7 topology should produce the same normalized configuration/usage result.

No new business change should be recorded merely because the source was re-read.

Conceptually:

```text
registry capture A == registry capture B
and
current approved LOR/V7 usage unchanged
    -> no configuration change
```

A real source change, such as a COM-port reassignment, speed change, Enhanced-mode change, E1.31 target change, or new UID appearing in the approved LOR/V7 snapshot, should be surfaced as a configuration difference for review.

## Conventional LOR RS-485 Registry Reconnaissance

Current repository evidence proves the Show PC loads sixteen LOR network records, but the conventional LOR network registry structure has not yet been documented to the same depth as E1.31.

The next reconnaissance must establish, from the live/current Show-PC registry and LOR Network Preferences UI, how each of the sixteen logical networks stores:

- logical network/index identity;
- configured/disabled state;
- serial/COM-port assignment;
- speed;
- Enhanced-mode state;
- adapter/protocol-related values; and
- any other setting required to reproduce the human-visible Network Preferences configuration accurately.

Do not infer registry value names from general Light-O-Rama knowledge. Capture and compare the actual current source.

## Physical Serial Adapter Boundary

The Show-PC COM-port value answers:

> Which Windows serial port is LOR currently using for this logical network?

It does not answer permanently:

> Which physical USB/RS-485 adapter is this?

Longer term, Network Infrastructure may give each physical USB/RS-485 adapter a durable identity and current physical connection relationship.

Conceptually:

```text
LOR logical network: Aux-O
    -> current Show-PC binding: COM<number>
    -> physical adapter: <future Network Infrastructure identity>
```

The COM number may change while the physical adapter remains the same, or the adapter may be replaced while the logical LOR network remains `Aux-O`.

Do not collapse these identities.

## E1.31 / sACN Routing View

The same logical subsystem should provide a human-readable E1.31 view because those settings are also LOR Network Preferences, even though the transport is different.

Current repository evidence already establishes the per-universe registry source and current controller-routing ranges.

The normalized view should show, as applicable:

- LOR controller/context name;
- universe start/end;
- target IP;
- sACN port;
- enabled/disabled state;
- current source timestamp; and
- current LOR/V7 universe usage inside the configured range.

Configured-but-unused capacity must remain distinguishable from current Display usage.

Configured routing must also remain distinguishable from confirmed physical installation.

## IP Address Planning Requirement

A future management view should eventually help answer whether a target IP is already in use/reserved, but IP allocation cannot be designed correctly from LOR registry data alone.

The LOR registry tells us current LOR-configured targets.

Controller Inventory supplies reviewed current physical-controller state.

Network Infrastructure may own broader network/subnet/device allocation information.

Therefore IP-address availability/planning is a cross-system requirement and should not be implemented as a uniqueness rule inside Controller Inventory.

Before implementing IP allocation, inspect the current Network Infrastructure addressing practices and determine the authoritative source for planned/static IP assignments.

## Universe Planning Requirement

The E1.31 view should similarly distinguish:

```text
CONFIGURED IN LOR
CURRENTLY USED BY LOR/V7 DISPLAY TOPOLOGY
RESERVED / PLANNED
FREE / UNASSIGNED
REVIEW
```

A configured universe can exist without current Display usage, and a planned universe may need to be reserved before it appears in LOR.

Do not infer that every gap is free merely because no current Preview row uses it.

## Relationship to Controller Inventory

Controller Inventory should not carry duplicated columns for:

```text
DisplayName
display_id
Stage
Scene
Network
UID
UID range
Universe
IP
COM port
network speed
Enhanced mode
```

Those are current assignment/configuration relationships owned by adjacent systems.

The permanent controller record should remain focused on the physical asset.

Controller Inventory can then associate a permanent controller with the applicable current LOR command/routing context without making the command/routing values part of the controller's permanent identity.

## Minimum Acceptance Cases

Before implementation design is accepted, test the conceptual model against at least:

1. a unique conventional A/C UID on one LOR network;
2. HWY-42 shared Regular-network command group;
3. Glistening Grove repeated Aux-O standard-tree command groups;
4. Glistening Grove separate Aux-F V2 command groups;
5. a Pixie controller consuming a reviewed UID range;
6. an intentionally repeated Pixie UID range;
7. a disabled/unused LOR network;
8. an active network with a current COM-port/speed/Enhanced configuration;
9. Mega Tree E1.31 configured and currently used universe range;
10. an E1.31 configured-but-not-physically-installed context such as the Open/Close Sign state documented during 2026 recovery; and
11. a planned UID/universe reservation that does not yet exist in LOR.

## Safety / Change Boundary

Initial work is reconnaissance and read-only extraction.

Do not:

- write the Show-PC registry;
- change LOR Network Preferences;
- change COM-port assignments;
- change network speed or Enhanced mode;
- change controller UIDs;
- change E1.31 universe/IP routing;
- create PostgreSQL schema/migrations from assumptions; or
- move physical Network Infrastructure ownership into this subsystem.

## Related Documents

- [LOR Network Configuration portal](README.md)
- [FieldWiring E1.31 LOR Controller Definitions](../../02_Production_Database/01_System_Architecture/09_Wiring_System/FieldWiring_E131_LOR_Controller_Definitions_2026-08-21.md)
- [Controller Inventory](../../02_Production_Database/01_System_Architecture/08_Controller_Inventory/README.md)
- [Network Infrastructure](../../02_Production_Database/01_System_Architecture/10_Network_Infrastructure/README.md)
- [Wiring System / FieldWiring](../../02_Production_Database/01_System_Architecture/09_Wiring_System/README.md)
