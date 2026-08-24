# LOR Network Configuration

This subsystem documents how Light-O-Rama network configuration is read, understood, and presented for engineering and planning.

It is separate from Controller Inventory and from the physical Network Infrastructure subsystem.

## Current State

The active Show-PC Light-O-Rama Network Preferences are stored in the current Windows user's registry, not in a normal project file.

Current engineering evidence has already reconstructed the E1.31 / sACN universe-routing side of those preferences, including named controller contexts, target IP addresses, ports, enabled/disabled universe records, and the current registry location.

The conventional LOR RS-485 side still requires direct reconnaissance. MSB uses sixteen logical LOR networks:

```text
Regular
Aux-A through Aux-O
```

Current operational requirements include knowing, for each network:

- whether it is configured/active;
- the current Show-PC serial/COM-port binding;
- network speed;
- Enhanced-mode state and other relevant LOR transport settings; and
- which Unit IDs are already in use in the current approved LOR/V7 topology.

## Design Intent

Build a read-only engineering view of the current LOR Network Preferences and combine it with the current approved LOR/V7 snapshot so MSB can answer practical questions without manually reading the Windows registry.

The target operator/engineering outcome is to be able to answer quickly:

- What LOR networks are configured?
- Which COM port is each Regular/Aux network using?
- Which networks are high-speed or Enhanced?
- Which Unit IDs are currently used on each network?
- Which Unit IDs are intentionally shared by multiple physical controllers?
- Which Unit IDs are available for a new command group?
- Which Unit IDs have been reserved for planned work but are not yet present in LOR?
- Which E1.31 universe ranges are configured, where are they routed, and what target IP/port does LOR currently use?

## Authority Boundaries

### LOR Network Configuration owns

- the current logical LOR network definitions (`Regular`, `Aux-A` through `Aux-O`);
- current Show-PC transport/configuration values read from LOR Network Preferences;
- current COM-port binding for conventional LOR RS-485 networks;
- current speed / Enhanced-mode configuration;
- current E1.31 universe routing, target IP, port, and enabled state;
- current UID-occupancy reporting derived from the approved LOR/V7 snapshot; and
- MSB-managed planning/reservation information needed to avoid accidental new-address conflicts.

### LOR Preview / LOR2DB owns

- current Display/controller addressing represented in Preview data;
- current Network + UID / UID-range usage;
- current channel/output topology; and
- the approved LOR/V7 snapshot used to derive current UID occupancy.

### Controller Inventory owns

- permanent physical controller identity;
- exact hardware/model/capability;
- firmware history;
- current physical-controller assignment to the applicable LOR command/routing context; and
- durable controller labels/QR identity.

A Network + UID is a current LOR command group, not a permanent physical-controller identity.

### Network Infrastructure owns

- physical USB/RS-485 adapters and other network hardware when inventoried;
- physical cable/node identity and topology;
- switch/cable/adapter relationships; and
- infrastructure test history.

A Windows `COM` number is a current Show-PC binding, not a permanent physical-adapter identity.

## UID Availability Requirement

The UID-management view must be derived from the current approved LOR/V7 topology rather than manually re-entered from the controller inventory spreadsheet.

For each LOR network, the view should be able to distinguish at least:

```text
IN USE
    current approved LOR/V7 uses this UID

SHARED COMMAND GROUP
    more than one Display / physical controller intentionally uses the same Network + UID

RESERVED / PLANNED
    MSB has reserved the UID for planned work that is not yet present in current LOR

FREE
    no current LOR use and no active reservation

REVIEW
    conflicting or incomplete source evidence prevents a safe availability conclusion
```

A UID is not "free" merely because Controller Inventory has no permanent controller assigned to it. Current LOR usage remains the first authority for whether that command address is already occupied.

The final implementation must also support controller types that consume a Unit-ID range. The required size/shape of a proposed range must come from reviewed controller/configuration requirements rather than a hard-coded assumption.

## Registry Extraction Boundary

The first implementation should be read-only.

Do not make PostgreSQL, Directus, or FieldWiring write the Show-PC registry as part of the initial recovery/design.

Conceptually:

```text
Show-PC LOR Network Preferences registry
    -> read-only source adapter
    -> captured raw configuration evidence
    -> normalized current LOR network/routing configuration

current approved LOR/V7 snapshot
    -> Network + UID / UID-range usage

MSB planning data
    -> UID reservations / planned addressing

combined engineering/operator view
    -> configured networks
    -> COM/speed/Enhanced state
    -> used/shared/reserved/free UIDs
    -> E1.31 universe/IP routing
```

## Known E1.31 Baseline

The E1.31 side of the registry has already been reverse engineered sufficiently to establish the current per-universe source structure and derive contiguous controller-routing ranges.

See [FieldWiring E1.31 LOR Controller Definitions](../../02_Production_Database/01_System_Architecture/09_Wiring_System/FieldWiring_E131_LOR_Controller_Definitions_2026-08-21.md).

That evidence also proves that configured LOR routing and actual physical installation are separate facts. A configured target IP/universe range does not by itself prove that a physical controller is installed.

## Open Engineering Work

Before any PostgreSQL network-configuration schema is designed:

1. inspect the current Show-PC registry records for all sixteen conventional LOR networks;
2. identify the exact source fields for logical network name/index, enabled state, COM-port binding, speed, Enhanced mode, and other settings that affect operation;
3. confirm how the registry represents unused/disabled conventional LOR networks;
4. compare the registry values with what the LOR Network Preferences UI shows;
5. define a repeatable read-only capture/export method;
6. define current UID occupancy from the approved V7 snapshot;
7. define a planning/reservation workflow so a UID can be held before the new controller reaches LOR;
8. define safe presentation of intentionally shared Network + UID command groups;
9. keep E1.31 universe/IP routing in the same logical subsystem while preserving its different transport model; and
10. review the relationship to permanent physical USB/RS-485 adapter identity in Network Infrastructure.

No PostgreSQL schema, registry writer, COM-port changes, LOR Network Preferences changes, or production configuration changes are authorized by this portal.

## Related Systems

- [LOR System Documentation](../README.md)
- [Controller Inventory](../../02_Production_Database/01_System_Architecture/08_Controller_Inventory/README.md)
- [Wiring System / FieldWiring](../../02_Production_Database/01_System_Architecture/09_Wiring_System/README.md)
- [Network Infrastructure](../../02_Production_Database/01_System_Architecture/10_Network_Infrastructure/README.md)

## Resume Development

Start with [LOR Network Configuration and UID Management Engineering Plan](LOR_Network_Configuration_and_UID_Management_Engineering_Plan_2026-08-23.md), then inspect the current Show-PC registry read-only before proposing tables or code changes.
