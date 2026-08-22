# Controller Inventory Current-State / FieldWiring Integration Plan

| Item | Value |
|---|---|
| Status | ENGINEERING PLAN — 2026 source/data review in progress |
| Subsystem owner | Controller Inventory |
| Consumer | FieldWiring |
| Current working inventory | `Controller Inventory & Testing 2026.xlsx` |
| FieldWiring baseline | Release Candidate handoff dated 2026-08-21 |
| Assignment scope | Current approved LOR/V7 snapshot only |
| Schema status | NO PostgreSQL schema or migration authorized by this plan |

## Purpose

FieldWiring development must continue while the physical controller data is being reviewed. The application currently contains reviewed temporary physical-controller interpretations needed for correct field presentation. Those temporary rules must remain replaceable rather than becoming the permanent inventory architecture.

The design direction is:

```text
permanent physical controller identity
        +
current controller address / distinguishing physical group
        +
current approved LOR/V7 snapshot
        ->
current physical-controller interpretation used by FieldWiring
```

Controller Inventory supplies the physical-controller fact that LOR cannot represent. It does not replace LOR topology.

See [Controller Inventory 2026 Source Audit — 2026-08-22](Controller_Inventory_2026_Source_Audit_2026-08-22.md) for the current source findings and unresolved conflicts.

## Authority Boundary

### Controller Inventory owns

- permanent identity of each physical controller;
- exact manufacturer/model and normalized controller classification;
- physical output/port capability;
- serial number when available;
- current controller status;
- current controller address/context needed to associate the physical asset with the current approved LOR/V7 topology;
- one additional distinguishing physical group when duplicate addressing makes the controller ambiguous;
- firmware update history; and
- durable controller labeling/scan identity.

### LOR / LOR2DB owns

- current show topology;
- current Display wiring relationships;
- LOR Network;
- Unit ID / Unit-ID range used by the current show;
- channel/output relationships represented by LOR;
- DMX/E1.31 universe/channel topology;
- current Stage/Scene/Display context; and
- current wiring provenance through the approved V7/PostgreSQL snapshot.

### Work Orders own

Repairs, troubleshooting, parts replacement, maintenance actions, and repair resolution belong in the Work Order system and should link to the permanent controller asset. Controller Inventory does not need a competing repair-history subsystem.

## Current Assignment Only

The controller itself has permanent identity. Its show assignment is current-state data.

Controller Inventory does **not** need to preserve prior Stage, Scene, Display, Unit-ID, network, IP, universe, or deployment assignments as historical relationship rows.

When the approved LOR/V7 snapshot changes, the current controller assignment can be reviewed/reconciled to that new current snapshot.

Older LOR snapshots and preserved spreadsheets remain engineering evidence without being duplicated into Controller Inventory assignment history.

## Firmware Is the Controller-Specific History to Preserve

Firmware updates are different from show assignments because firmware progression can matter for troubleshooting and compatibility.

The eventual Controller Inventory model should be able to preserve, at minimum:

- permanent controller identity;
- firmware version;
- date installed or verified;
- person who installed or verified it; and
- optional notes / Work Order reference when applicable.

The lookup workbook's `Latest Firmware` value is model-reference information. It is not proof of the firmware actually installed on an individual controller.

## Exact Model and Generic Classification Are Both Needed

A simple controller class is useful for people and FieldWiring presentation, but the exact controller model must remain distinct.

Example:

```text
Generic class: Pixel Controller
Exact model:   PixCon16
```

`PixCon16` and Pixie-16 are different devices and must never be normalized into one model.

The 2026 source currently uses model labels that still require controlled normalization. Do not infer exact hardware solely from similar spelling.

## Do Not Duplicate LOR Display/Output Rows Unnecessarily

The inventory team does **not** need to manually recreate every controller-to-Display/output relationship that the current approved LOR snapshot already provides.

For a controller with a unique current address, Controller Inventory only needs enough physical information to say which permanent controller owns that current address/context.

Example:

```text
CL-017
Network: Regular
Unit ID: 41
```

The current approved LOR/V7 snapshot can determine which Displays and LOR outputs use `Regular / 41`.

Likewise, a Pixie with a unique address range can normally be associated with its physical asset by current Network/range plus the current snapshot context.

## Intentional Duplicate Addresses Need One Additional Distinguishing Fact

MSB intentionally uses repeated Unit IDs/ranges. Therefore `network + Unit ID/range` must **not** be assumed to uniquely identify a physical controller.

Where multiple physical controllers intentionally use the same address, the current inventory review must capture a short distinguishing assignment/group.

Example:

```text
CL-042 | UID 21-24 | Candy Canes 1-4
CL-043 | UID 21-24 | Candy Canes 5-8
CL-044 | UID 21-24 | Candy Canes 9-12
```

This distinguishing group is the physical fact LOR cannot infer when multiple controller instances carry the same programmed address.

The 2026 workbook already contains two identical Church Pixie4 `21-24` rows and three identical Candyland Pixie4 `21-24` rows. Those rows must be physically distinguished before permanent import design.

Do not create a uniqueness rule that prohibits intentional duplicate controller addresses.

## Stage / Scene / Display Collection Scope During Data Review

For ordinary controller records, Stage/Scene or another simple physical-context description is sufficient during cleanup when the controller address uniquely resolves its LOR relationships.

The team does **not** need to manually list every Display for every controller.

Display/group information is required only when needed to distinguish physical controllers that share the same current address or when the current physical grouping cannot otherwise be determined.

FieldWiring can derive detailed current Display/output rows from the approved LOR/V7 snapshot after the correct physical controller has been associated with the address/group.

## Current Snapshot Provenance Requirement

The future current-assignment relationship must make it possible to determine which approved LOR/V7 snapshot the controller mapping was reconciled against.

Conceptually:

```text
current approved snapshot = Run X
controller mapping reviewed against = Run X
    -> current

current approved snapshot = Run Y
controller mapping reviewed against = Run X
    -> controller mapping requires review/reconciliation
```

This is currentness/provenance, not assignment history.

No specific PostgreSQL column or table is authorized by this plan.

## Current FieldWiring Release-Candidate Boundary

The current FieldWiring release candidate is read-only and explicitly identifies where temporary physical-controller interpretation currently lives.

### `FieldWiring/Application/wiring_presentation.py`

This module owns the current reviewed A/C/Pixie presentation/grouping rules. Current named/accepted patterns include such cases as:

- Church Tree/Cross/Candy Cane contexts;
- Candyland Lollipops/Candy Canes;
- Who Forest Pixie8 groups; and
- Santa's Workshop Pixie8 Trees.

These are temporary physical interpretations needed for FieldWiring correctness. They are not permanent controller identities.

### `FieldWiring/Application/wiring_e131.py`

This module is the centralized reviewed **temporary** E1.31 physical-controller/output resolver until Controller Inventory can supply permanent physical identity/current assignment.

The current release-candidate handoff lists these explicit mappings:

```text
Mega Tree
    AlphaPix / Flex48
    Universes 1-48 -> Outputs 1-48

Mega Ball
    PixCon16
    Universes 49-64 -> Outputs 1-16

Mega Star Controller 1
    PixCon16
    Universes 113-128 -> Outputs 1-16

Mega Star Controller 2
    PixCon16
    Universes 129-140 -> Outputs 1-12
```

The 2026 workbook now contains physical inventory rows corresponding to all four of those temporary contexts, but permanent `CL-###` controller identity is still missing.

## What Controller Inventory Must Eventually Replace

FieldWiring should not need to know permanent controller identity through named Display/Scene-specific rules.

The future Controller Inventory read boundary must provide enough current physical information for FieldWiring to resolve:

```text
permanent controller identity / controller key
human-readable controller label
exact manufacturer + model
physical output/port capacity
current addressing family
current Network + Unit ID/range OR E1.31 controller context
optional duplicate-address distinguishing group
optional current management IP when operationally useful
current physical output mapping basis when it cannot be derived safely from LOR
approved LOR/V7 snapshot provenance
review/ambiguity state when the physical mapping is not yet authoritative
```

This is an interface requirement, **not a proposed table definition**.

## What Controller Inventory Must Not Copy from V7.0.11

Parser V7.0.11 preserves detailed current DMX source wiring provenance including:

```text
source RawPropID
source ChannelName
source ChannelGridRowNumber
Universe
StartChannel
EndChannel
```

Those remain LOR/LOR2DB wiring facts. Controller Inventory should not manually recreate them as controller-owned wiring rows.

FieldWiring will combine:

```text
LOR/V7 source wiring relationship
    +
Controller Inventory permanent controller/current assignment
    ->
physical field instruction
```

RawPropID, universe, IP address, Display name, Channel Name, Stage, Scene, or source row position must not become permanent controller identity.

## Physical Output Is a Consumer Requirement, Not Necessarily a Duplicate Wiring Table

FieldWiring presents physical outputs/ports when the physical mapping is known.

Controller Inventory must provide enough current physical assignment information for FieldWiring to determine the correct physical controller and output/port for an LOR/V7 relationship.

That does **not** imply a duplicate Controller Inventory row for every Display/output/universe relationship. A reviewed range/base mapping or other simpler assignment is preferred when sufficient and unambiguous.

Where the physical mapping is irregular, duplicated, or cannot be safely derived from current LOR topology, Controller Inventory must preserve the additional distinguishing physical fact rather than forcing FieldWiring to hard-code the exception permanently.

## 2026 Source Cases That Must Be Reconciled Before Interface Finalization

The current workbook materially improves physical coverage but exposes unresolved cases.

### Church

The workbook now contains the Pixie2 Cross controllers and two Pixie4 Candy Cane controllers, but it still lacks the permanent physical Church Tree Pixie16 and the separate Tree Star controller context used by FieldWiring.

### Candyland

The workbook now contains one Pixie16 Lollipop row and three Pixie4 Candy Cane rows. The three Pixie4 rows require physical group distinction.

The Lollipop row is recorded on `Aux-B`, while current FieldWiring accepted LOR evidence expects the Lollipop Pixie pattern on `Aux C`. This must be reconciled, not guessed.

### Who Forest

The 2026 workbook now records all eight Pixie8 groups on `Aux-I`, including Tree 4, matching current FieldWiring topology and superseding the old 2025 working value for current-review purposes.

### Santa's Workshop

The two Pixie8 Tree controllers are now present at `10-17` and `18-1F` on `Aux-D`.

### Mega Cube

Do **not** carry the older assumption of three PixCon16 physical controllers forward as current accepted truth.

The 2026 workbook now records one `AlphaPix Flex 48` row at `10.10.5.12`, while its `Controller Type` is recorded as `16`. This conflicts with older evidence and is internally inconsistent.

The current FieldWiring release candidate intentionally leaves Mega Cube compact CustomGrid expansion unresolved rather than fabricating physical rows. Actual installed hardware/output count must be physically confirmed before Controller Inventory defines this assignment.

## CR50 / DumbRGB Boundary

CR50 fixture grouping remains a FieldWiring/LOR presentation rule. The fact that FieldWiring groups three RGB source rows into one fixture instruction does not itself require a permanent Controller Inventory asset for every CR50 fixture.

If a physical gateway/PixieLink/controller serving those fixtures is within Controller Inventory scope, that physical controller's identity/current assignment belongs here. The fixture source rows remain LOR topology unless separately established as inventory assets.

## Guidance to FieldWiring While Inventory Is Pending

FieldWiring does not need to stop development.

Until Controller Inventory becomes authoritative:

1. preserve operator-confirmed controller patterns required for browser correctness;
2. keep temporary mappings centralized in the existing presentation/resolver modules;
3. do not spread new permanent-looking controller facts into unrelated rendering or route code;
4. treat named mappings as temporary engineering evidence, not physical asset identity;
5. continue to use current LOR/V7 data for actual Display/output/universe/channel rows;
6. never invent `CL-###` identity from Unit ID, range, universe, IP, Display name, or source row;
7. allow intentional duplicate Pixie and A/C addresses;
8. preserve unknown or conflicting physical detail as review state; and
9. make the temporary resolver replaceable by the eventual PostgreSQL Controller Inventory read contract.

## Data Review Action Plan

For each physical controller, collect or verify:

1. permanent MSB controller key when assigned (`CL-###`);
2. manufacturer;
3. exact model;
4. generic controller class;
5. physical output/port count and type;
6. serial number when available;
7. current firmware;
8. current status;
9. current Network / Unit ID or range, or applicable E1.31/IP information;
10. Stage/Scene or simple current physical context; and
11. a distinguishing Display/group only when duplicate addressing or another ambiguity requires it.

Do not spend substantial effort reconstructing unknown purchase/deployment dates for older controllers. Those fields may remain unknown. If useful and supportable, `First Known Use Year` may later be captured from known Display build information, but it must not be represented as a purchase date.

## Ongoing Cross-Workstream Handoff Rule

FieldWiring may discover physical-controller requirements before Controller Inventory data is complete. Those findings must be carried into Controller Inventory documentation rather than living only in code or conversation history.

Conversely, Controller Inventory source review must update this interface plan when physical evidence contradicts an earlier temporary FieldWiring assumption.

This does not transfer schema ownership to FieldWiring. Controller Inventory determines its final implementation from reviewed source evidence.

## Schema Gate

No PostgreSQL Controller Inventory tables or migrations should be created until:

- permanent physical controller identity has been established;
- controller model names have been reviewed and normalized;
- current physical controllers have been reconciled against current LOR/V7 and E1.31 evidence;
- duplicate-address groups have been physically distinguished where required;
- current source conflicts identified in the 2026 audit have been resolved or intentionally marked unknown; and
- the minimum current-assignment interface required to replace FieldWiring temporary controller mappings has been reviewed against real cases.

## Related Documents

- [Controller Inventory](README.md)
- [Controller Inventory 2026 Source Audit — 2026-08-22](Controller_Inventory_2026_Source_Audit_2026-08-22.md)
- [Controller Inventory and Labeling Plan](Controller_Inventory_and_Labeling_Plan.md)
- [Controller Inventory 2025 Source Audit — historical evidence](Controller_Inventory_2025_Source_Audit_2026-08-19.md)
- [FieldWiring Release Candidate Handoff and Development Runbook](../09_Wiring_System/FieldWiring_Release_Candidate_Handoff_and_Development_Runbook_2026-08-21.md)
- [FieldWiring / Controller Inventory Handoff](../09_Wiring_System/FieldWiring_Controller_Inventory_Handoff_2026-08-20.md)
- [Work Orders](../06_Work_Orders/README.md)
