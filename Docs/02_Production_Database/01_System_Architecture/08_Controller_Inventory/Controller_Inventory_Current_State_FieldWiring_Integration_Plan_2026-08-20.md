# Controller Inventory Current-State / FieldWiring Integration Plan — 2026-08-20

| Item | Value |
|---|---|
| Status | ENGINEERING PLAN — source/data review in progress |
| Subsystem owner | Controller Inventory |
| Consumer | FieldWiring |
| Assignment scope | Current approved LOR/V7 snapshot only |
| Schema status | NO PostgreSQL schema or migration authorized by this plan |

## Purpose

FieldWiring development needs to continue while the controller source data is being reviewed. Temporary named controller-group rules are currently necessary for known physical patterns, but those rules must not become the permanent controller model.

This plan defines the Controller Inventory direction clearly enough for FieldWiring to build toward the future interface without requiring the Controller Inventory schema to be finalized before the source data is corrected.

The design goal is:

```text
permanent physical controller identity
        +
current controller address / distinguishing assignment
        +
current approved LOR/V7 snapshot
        ->
current physical-controller interpretation used by FieldWiring
```

Controller Inventory does not replace LOR topology. It supplies the physical-controller fact that LOR cannot represent.

## Confirmed Authority Boundary

### Controller Inventory owns

- permanent identity of each physical controller;
- exact manufacturer/model and normalized controller classification;
- physical output/port capability;
- serial number when available;
- current controller status;
- current controller address/assignment needed to associate the physical asset with the current approved LOR/V7 topology;
- firmware update history; and
- durable controller labeling/scan identity.

### LOR / LOR2DB owns

- current show topology;
- current Display wiring relationships;
- LOR Network;
- Unit ID / Unit-ID range used by the current show;
- channel/output relationships represented by LOR;
- DMX/E1.31 universe/channel topology; and
- current Stage/Scene/Display context through the approved V7/PostgreSQL snapshot.

### Work Orders own

Repairs, troubleshooting, parts replacement, maintenance actions, and repair resolution belong in the Work Order system and should link to the permanent controller asset. Controller Inventory does not need a competing repair-history subsystem.

## No Controller Assignment History Requirement

The controller itself has permanent identity. Its show assignment is current-state data.

Controller Inventory does **not** need to preserve prior Stage, Scene, Display, Unit-ID, network, IP, universe, or deployment assignments as historical relationship rows.

When the approved LOR/V7 snapshot changes, the current controller assignment can be reviewed/reconciled to that new current snapshot.

Older LOR snapshots and preserved spreadsheets remain available as engineering evidence without being duplicated into Controller Inventory assignment history.

## Firmware Is the Controller-Specific History to Preserve

Firmware updates are different from show assignments because knowing the firmware progression of a physical controller can matter for troubleshooting and compatibility.

The eventual Controller Inventory model should be able to preserve, at minimum:

- permanent controller identity;
- firmware version;
- date installed or verified;
- person who installed or verified it; and
- optional notes / Work Order reference when applicable.

The lookup spreadsheet's `Latest Firmware` value is model-reference information. It must not be treated as proof of the firmware actually installed on an individual physical controller.

## Exact Model and Generic Classification Are Both Needed

A simple controller class is useful for people and FieldWiring presentation, but the exact controller model must remain distinct.

For example:

```text
Generic class: Pixel Controller
Exact model:   PixCon16
```

and:

```text
Generic class: Pixel Controller
Exact model:   Pixie-16
```

`PixCon16` and `Pixie-16` are different devices and must never be normalized into one model.

Source spellings such as `Pixicon-16` or `Pixiecon 16` must be physically verified before being mapped to an exact model.

For conventional A/C controllers, useful generic characteristics may include output count and applicable current rating while the exact Light-O-Rama model/generation remains preserved.

## Current Assignment — Do Not Duplicate LOR Data Unnecessarily

The inventory team does **not** need to manually recreate every controller-to-Display/output relationship that the current approved LOR snapshot already provides.

For a controller with a unique current address, Controller Inventory only needs enough physical information to say which permanent controller owns that current address/context.

Example:

```text
CL-017
Network: Regular
Unit ID: 41
```

The current approved LOR/V7 snapshot can then determine which Displays and LOR outputs currently use `Regular / 41`.

Likewise, a Pixie with a unique address range can be associated to its physical controller asset by its current Network/range plus the current snapshot context.

## Intentional Duplicate Addresses Need One Additional Distinguishing Fact

MSB intentionally uses repeated Unit IDs/ranges in some places. Therefore `network + Unit ID/range` must **not** be assumed to uniquely identify a physical controller.

Where two or more physical controllers intentionally use the same address, the current inventory review must capture a short distinguishing assignment/group.

Example:

```text
CL-042 | UID 21-24 | Candy Canes 1-4
CL-043 | UID 21-24 | Candy Canes 5-8
CL-044 | UID 21-24 | Candy Canes 9-12
```

This distinguishing group is the physical fact LOR cannot infer when multiple physical controllers intentionally carry the same programmed address.

During source cleanup, a plain-language group is sufficient. The eventual PostgreSQL representation must be designed only after the reviewed data shows what structured relationship is actually required.

Do not create a uniqueness rule that prohibits intentional duplicate controller addresses.

## Stage / Scene / Display Collection Scope During Data Review

For the current cleanup effort, Stage/Scene or another simple physical-context description is sufficient for ordinary controller records when the controller address uniquely resolves its LOR relationships.

The team does **not** need to manually list every Display for every controller.

Display/group information is required during cleanup only when needed to distinguish physical controllers that share the same current address or when the current physical grouping cannot otherwise be determined.

FieldWiring can use the current approved LOR/V7 snapshot to derive the detailed current Display/output rows after the physical controller has been associated with the correct address/group.

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

This is a currentness/provenance requirement, not controller assignment history.

No specific PostgreSQL column or table is authorized by this plan.

## FieldWiring Consumer Interface Direction

FieldWiring should be built so temporary hard-coded physical-controller rules can later be replaced by an authoritative Controller Inventory resolver/read model without redesigning the browser presentation layer.

The eventual read interface is expected to provide enough information to answer questions such as:

- Which permanent physical controller applies to this current wiring context?
- What exact controller model/family is it?
- How many physical outputs/ports does it have?
- What current Network / Unit ID / Unit-ID range or E1.31 controller context applies?
- If an address is intentionally duplicated, which physical Display/group distinguishes this controller instance?
- Which approved LOR/V7 snapshot was this current mapping reconciled against?

This is an interface requirement, **not a proposed table definition**.

## FieldWiring Requirements Added During DMX / E1.31 Recovery — 2026-08-21

FieldWiring dense-RGB recovery exposed additional Controller Inventory consumer requirements that must be available to the Controller Inventory workstream even though its PostgreSQL schema is not yet finalized.

### E1.31 controller resolution

For an E1.31 wiring relationship, FieldWiring ultimately needs to resolve the current LOR/V7 relationship to the physical controller context the technician sees.

The eventual Controller Inventory read boundary must be able to provide, conceptually:

```text
permanent controller identity / controller key
human-readable controller label
exact manufacturer + model
physical output/port capacity
current addressing family = E1.31
current E1.31 assignment/context sufficient to associate LOR universe rows
current physical output/port for the relationship,
    OR a reviewed deterministic mapping basis from which FieldWiring can resolve it
optional current management IP address when operationally useful
current Stage / Scene / physical distinguishing context when needed
approved LOR/V7 snapshot provenance for the assignment
assignment ambiguity/review state when the mapping is not yet authoritative
```

The inventory model does **not** have to copy every LOR DMX row merely to satisfy this interface. Where a physical controller owns a clean contiguous universe/output block, the controller assignment may provide enough current context for FieldWiring to combine that physical fact with LOR-authored universe/channel rows.

Examples already established by FieldWiring evidence include:

```text
Mega Tree
    one 48-output AlphaPix/Flex48-style controller context
    Universes 1-48
    one physical output per current universe relationship

Mega Star
    two physical PixCon16 controller contexts
    Controller 1: Universes 113-128
    Controller 2: Universes 129-144 current controller context

Mega Cube
    three physical controller contexts
    detailed LOR compact-grid expansion is still a separate parser issue
```

These examples are consumer requirements/evidence. They do not authorize permanent Controller Inventory rows or IDs until the Controller Inventory source review establishes them.

### What Controller Inventory must not duplicate from V7.0.11

Parser V7.0.11 now preserves detailed DMX source wiring provenance in the current LOR snapshot:

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

The V7.0.11 DMX `RawPropID` is source PropClass provenance. It is **not** a permanent controller identifier and must not become a Controller Inventory foreign-key identity merely because FieldWiring uses it to preserve source wiring detail.

Likewise, E1.31 universe, IP address, Display name, Channel Name, Stage, Scene, or source row position must not become permanent controller identity.

### Physical output is a consumer requirement, not necessarily a duplicated wiring table

FieldWiring's accepted E1.31 technician view is grouped by physical controller and shows:

```text
OUTPUT / PORT
CHANNEL / DISPLAY SECTION
UNIVERSE
PIXELS
CHANNEL RANGE
```

Controller Inventory must therefore provide enough current physical assignment information for FieldWiring to determine the correct physical controller and output/port for an LOR/V7 relationship.

That requirement does **not** imply that Controller Inventory must store a duplicate row for every Display/output/universe relationship. A reviewed range/base mapping or another simpler assignment model is preferred when it is sufficient and unambiguous.

Where the physical mapping is irregular, duplicated, or cannot be derived safely from current LOR topology, the Controller Inventory workstream must preserve the additional distinguishing fact needed to resolve it rather than forcing FieldWiring to hard-code the exception permanently.

### CR50 / DumbRGB boundary

CR50 fixtures are 5-channel DMX fixtures whose LOR Channel Grid intentionally contains only the three RGB channels. FieldWiring groups the three RGB source rows into one fixture instruction and preserves the two omitted function-channel gaps.

That CR50 fixture-row grouping is a **FieldWiring/LOR presentation rule**, not a requirement to create a permanent Controller Inventory record for every CR50 fixture.

If a physical DMX/E1.31 gateway, PixieLink, or other controller serving those fixtures is within Controller Inventory scope, its permanent identity/current assignment belongs in Controller Inventory. The individual CR50 fixture source rows remain LOR wiring topology unless the Controller Inventory project separately establishes fixture assets as part of its scope.

## Ongoing Cross-Workstream Handoff Rule

This integration plan is not a one-time handoff.

Whenever FieldWiring engineering discovers a new requirement that affects any of the following, the responsible Controller Inventory documentation must be updated before that FieldWiring milestone is considered fully documented:

- permanent physical controller identity;
- controller manufacturer/model normalization;
- physical output/port capability;
- current controller assignment/addressing;
- duplicate-address distinguishing context;
- E1.31 physical-controller/output resolution;
- controller currentness/provenance relative to the approved LOR/V7 snapshot; or
- the minimum Controller Inventory read interface consumed by FieldWiring.

FieldWiring may document the discovery first in its own engineering artifact, but it must also carry the consumer requirement into this Controller Inventory-owned plan and/or the applicable Controller Inventory contract. Conversation history is not the handoff mechanism.

This rule does not transfer Controller Inventory schema ownership to FieldWiring. Controller Inventory still determines its implementation from its own inspected source evidence and approved data model.

## Guidance to FieldWiring While Inventory Is Pending

FieldWiring does not need to stop development.

Until Controller Inventory becomes authoritative:

1. preserve current operator-confirmed controller patterns needed for browser correctness;
2. keep named/recovery mappings isolated behind a controller-resolution boundary rather than spreading Display-specific conditions throughout presentation code;
3. treat those mappings as temporary evidence, not permanent asset identity;
4. continue to use the current LOR/V7 snapshot for actual Display/output wiring rows;
5. never invent permanent controller IDs from Unit ID, range, universe, IP, Display name, or source row;
6. allow intentional duplicate Pixie address ranges;
7. preserve unknown physical detail as unknown rather than fabricating a model/output; and
8. make the temporary resolver replaceable by the future PostgreSQL Controller Inventory read contract.

The objective is to prevent more hard-coded physical interpretations from becoming architectural dependencies while allowing FieldWiring acceptance/recovery work to continue.

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

## Schema Gate

No PostgreSQL Controller Inventory tables or migrations should be created until:

- controller model names have been reviewed and normalized;
- current physical controllers have been reconciled against the current LOR/V7 snapshot and E1.31 evidence;
- duplicate-address groups have been identified where needed;
- the permanent controller identity/labeling rule has been accepted; and
- the minimum current-assignment interface required by FieldWiring has been reviewed against real controller cases.

## Related Documents

- [Controller Inventory](README.md)
- [Controller Inventory and Labeling Plan](Controller_Inventory_and_Labeling_Plan.md)
- [Controller Inventory 2025 Source Audit — 2026-08-19](Controller_Inventory_2025_Source_Audit_2026-08-19.md)
- [FieldWiring / Controller Inventory Handoff — 2026-08-20](../09_Wiring_System/FieldWiring_Controller_Inventory_Handoff_2026-08-20.md)
- [FieldWiring Physical Controller / Output Presentation Contract](../09_Wiring_System/FieldWiring_Physical_Controller_Output_Presentation_Contract.md)
- [FieldWiring E1.31 Dense RGB Field Presentation Contract](../09_Wiring_System/FieldWiring_E131_Dense_RGB_Field_Presentation_Contract.md)
- [FieldWiring DMX / DumbRGB Field Presentation Contract](../09_Wiring_System/FieldWiring_DMX_DumbRGB_Field_Presentation_Contract.md)
- [FieldWiring PostgreSQL DMX Propagation Change Map](../09_Wiring_System/FieldWiring_PostgreSQL_DMX_Propagation_Change_Map_2026-08-21.md)
- [Work Orders](../06_Work_Orders/README.md)
