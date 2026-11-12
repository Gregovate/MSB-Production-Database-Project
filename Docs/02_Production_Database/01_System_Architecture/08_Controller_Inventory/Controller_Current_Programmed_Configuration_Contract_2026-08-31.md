# Controller Current Programmed Configuration Contract — 2026-08-31

| Item | Value |
|---|---|
| Status | CURRENT ACCEPTED CORRECTION |
| Issue | #110 |
| Scope | Permanent Controller Inventory + FieldWiring + setup/reconciliation |
| Supersedes | Any wording that treats Network/UID/IP/universe only as transient LOR data with no permanent Controller Inventory representation |

## Purpose

Permanent Controller Inventory already separates physical identity from LOR addressing. That identity rule remains correct, but live integration review exposed a missing operational fact: a physical controller must itself be programmed with the Network/Unit ID or E1.31 configuration required for it to operate.

The initial bootstrap staging contained `network_evidence` and `uid_evidence`, but permanent promotion retained physical controller identity and Controller-to-Display relationships without preserving those current programmed configuration values. That omission now blocks authoritative physical-controller resolution for several multi-controller Displays and would also make setup unable to verify whether a shelf or deployed controller is actually programmed correctly.

## Correct Authority Split

```text
ref.controller.controller_id
    permanent physical identity

Controller Inventory
    current programmed controller configuration
    current physical controller-to-Display assignment
    current physical location/status/firmware/verification facts

LOR / approved V7 snapshot
    authoritative show wiring and configuration expected now
    Network / Unit ID / channels / universes / output relationships

Setup / reconciliation
    compare physical controller current configuration to current LOR expectation
    reprogram or verify explicitly when different

FieldWiring
    combine permanent physical controller identity/configuration with current LOR wiring
```

Network, Unit ID, Unit-ID range, IP address, and universe remain mutable. None is permanent physical identity and none may be made globally unique merely to identify a controller.

Intentional duplicate addresses remain valid.

## LOR Unit-ID Range Rule

For a physical LOR controller that uses more than one Unit ID, the programmed Unit IDs are contiguous in hexadecimal order.

Therefore the permanent current-configuration model should store a machine-readable range rather than only a free-text value:

```text
lor_network
uid_start
uid_end
```

For a single-UID controller:

```text
uid_start = uid_end
```

For a multi-UID controller, every Unit ID from `uid_start` through `uid_end` is part of the controller's programmed range. The range count is derived from the inclusive hexadecimal interval:

```text
uid_count = uid_end - uid_start + 1
```

Examples:

```text
Pixie2D   Aux H   01-02   -> 2 contiguous Unit IDs
Pixie4D   Aux N   21-24   -> 4 contiguous Unit IDs
Pixie8D   Aux I   50-57   -> 8 contiguous Unit IDs
Pixie16D  Aux N   30-3F   -> 16 contiguous Unit IDs
CTB32     Aux I   BA-BA   -> one Unit ID, displayed as BA
```

The database should store normalized numeric values suitable for comparison/range arithmetic and render them to operators in uppercase hexadecimal form with appropriate leading zero formatting. Do not make a text value such as `21-24` the only authoritative representation.

If source evidence supplies the first Unit ID plus a known programmed Unit-ID count, `uid_end` can be derived. If source evidence supplies the first and last Unit IDs, the count can be derived. In either case the resulting range must be contiguous.

This rule does not make Unit ID/range unique. Separate permanent controllers may intentionally carry the same Network + Unit-ID range.

## Why Current Programmed Configuration Must Be Stored

A controller does not operate merely because the Production Database knows its `controller_id` and Display assignment. The physical controller has its own programmed configuration.

For a Light-O-Rama controller this includes the current Unit ID or Unit-ID range and relevant LOR Network. For an E1.31 controller this includes the applicable current network/IP/universe configuration needed to configure and troubleshoot the physical device.

An `AVAILABLE` controller on the shelf still has its currently programmed configuration even though it has no Display or Stage assignment. When that controller is assigned later, its old programmed configuration may need to be changed before deployment.

Therefore Controller Inventory must be able to answer both:

```text
What is this physical controller currently programmed as?
What does the current approved LOR/V7 snapshot require it to be programmed as?
```

A mismatch is a setup/reconciliation condition, not a reason to change permanent identity.

## Bootstrap Evidence Proving the Requirement

The original stage bootstrap retained current configuration evidence such as:

```text
WV-SpiralTree
    four CTB32 controllers
    Aux-I / BA
    Aux-I / BB
    Aux-I / BC
    Aux-I / BD

FC-LogoTreeStar
    Pixie2 controller 1 -> Aux-H / 1-2
    Pixie2 controller 2 -> Aux-H / 3-4

SW-PotterPoleBall
    Pixie2 controller 1 -> Aux-D / 01-02
    Pixie2 controller 2 -> Aux-D / 03-04

FC-ArrowRight-2CH-02
    two CTB32 physical controllers intentionally using the same Regular / UID 22 programming

PB Igloos
    two CF50D physical controllers per Igloo intentionally sharing the same programmed UID for that Igloo
```

The permanent promotion did not carry these current configuration discriminators forward.

## Multi-Controller Display Consequence

`ref.controller_display` correctly represents many-to-many physical assignment, but it is not sufficient by itself to resolve which current LOR wiring block belongs to each physical controller when one Display uses multiple physical controllers.

Current production review identified examples including:

- `WV-SpiralTree` — four physical CTB32 controllers and four clean LOR UID blocks BA/BB/BC/BD;
- `FC-LogoTreeStar` — two Pixie2D controllers using ranges 01-02 and 03-04;
- `SW-PotterPoleBall` — two Pixie2D controllers using ranges 01-02 and 03-04;
- `FT-MegaStar` — two PixCon16 controllers spanning current E1.31 universe blocks;
- Polar Bear Igloos — two physical CF50D controllers behind one LOR UID block per Igloo;
- `FC-ArrowRight-2CH-02` — two physical CTB32 controllers using the same current UID block;
- `WW-FreeFrosty-Spotlight` — multiple physical CF50D controllers with duplicated/shared LOR command context.

This means the permanent model must support both:

1. a physical controller's own current programmed configuration; and
2. reviewed assignment/resolution detail where several physical controllers intentionally share one LOR wiring definition or one Display spans multiple address/universe blocks.

Do not resolve these cases by `controller_id` ordering.

## Required Controller Inventory UX

Controller detail and the assignment workbench must eventually show the current programmed configuration alongside the current LOR-required configuration.

Conceptually:

```text
CTRL 1058   CTB32
Display: WV-SpiralTree
Current programmed: Aux I / BA
LOR requires:       Aux I / BA
Configuration:      MATCH
```

or:

```text
CTRL 1201   Pixie4D   AVAILABLE
Display: none
Current programmed: Aux N / 21-24
LOR requires:       n/a until assigned
Configuration:      VERIFY / REPROGRAM ON ASSIGNMENT
```

The assignment workflow must not silently overwrite the controller's recorded programmed configuration merely because a new Display is selected. It should show the required configuration and make any required reprogramming explicit.

## Setup / Operator Procedure Consequence

Future plain-English setup procedures must include controller programming/verification. For a controller being deployed, the operator must be able to see:

- Controller ID / label;
- model;
- target Stage/Display;
- current programmed Network/UID or applicable E1.31 configuration;
- configuration required by current LOR/V7;
- whether they match;
- what must be changed before connection when they do not match.

This is separate from physical placement and Display assignment.

## Implementation Rule

Do not complete the permanent FieldWiring controller resolver until this current-configuration gap is represented in the permanent Controller Inventory model for the cases that require it.

Do not restore Network/UID as physical identity. Restore them as mutable, auditable, current controller configuration.