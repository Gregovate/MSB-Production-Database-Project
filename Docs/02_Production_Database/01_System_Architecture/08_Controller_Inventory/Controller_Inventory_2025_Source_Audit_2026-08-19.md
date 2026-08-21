# Controller Inventory 2025 Source Audit — 2026-08-19

| Item | Value |
|---|---|
| Status | ENGINEERING SOURCE AUDIT — no schema change authorized |
| Subsystem | Controller Inventory |
| Source year | 2025 working inventory / firmware tracking |
| FieldWiring relevance | High |
| PostgreSQL implementation | Not yet designed from this source |

## Purpose

This audit records the first direct inspection of the controller inventory source supplied during the FieldWiring engineering recovery work.

The source consists of two CSV exports:

```text
Controller Inventory & Firmware 2025 - Inventory.csv
Controller Inventory & Firmware 2025 - Lookup Table.csv
```

These files are valuable physical-controller evidence, but they must not be treated as a finished 2026 permanent asset register without reconciliation.

## Inventory File Shape

The populated inventory rows carry these fields:

```text
Tested By
Complete
Display ID
Network
Changes
Model
Firmware
Controller ID (HEX)
Controller Type
Park Location
For What
```

There are 129 populated Display rows in the CSV export. The file also contains an embedded summary section after the inventory rows.

The embedded summary reports:

```text
126 controllers
1539 total channels
35 controllers at Displays
```

Those summary values are historical workbook calculations and should be preserved as source evidence rather than assumed to be a current 2026 count.

The `Complete` field confirms that this was a working inspection/firmware checklist rather than a finished permanent inventory: 128 of the 129 populated rows are `FALSE`; one populated row is `TRUE`.

## Lookup Table Shape

The companion lookup table contains:

```text
Model
Description
Channels
Retail
Latest Firmware
```

and includes model/capability entries such as:

- conventional 4- and 16-channel LOR controllers;
- Pixie 16;
- PixCon 16;
- Cosmic Color devices;
- ServoDog; and
- Easy Light Linkers.

This is useful as model/firmware reference data, but it is not physical-controller identity.

## Important Identity Finding

The 2025 inventory does **not** provide a durable permanent controller asset key.

`Controller ID (HEX)` is deployment/configuration data and appears in several forms:

```text
single LOR Unit ID       3F
Unit-ID range            50-57
paired IDs               1_2
IP marker                IP
blank                    <empty>
```

Therefore `Controller ID (HEX)` cannot become the permanent Controller Inventory primary identity.

Likewise, Display ID, network, Park Location, and IP address are deployment/location/configuration attributes that may change over the life of a physical controller.

The future PostgreSQL controller master still requires a stable physical controller identity independent of these changing assignments.

## Model Normalization Required

The source uses several naming variants that must be reconciled before import design. Examples include:

```text
Pixicon-16
Pixiecon 16
PixCon16          [lookup table]

Pixie-16
Pixie16D          [lookup table]

32LD-G3
LOR160x / CTB32   [lookup terminology]

Coro / CORO
```

These are source values and should not be silently normalized during this audit. A controlled controller-model reference mapping is needed later.

## Who Forest — Strong Match to Current LOR Pattern

The inventory explicitly records eight Pixie 8 controllers for `07- Who Forest`:

```text
Tree 1 -> Pixie8 -> 50-57
Tree 2 -> Pixie8 -> 58-5F
Tree 3 -> Pixie8 -> 60-67
Tree 4 -> Pixie8 -> 68-6F
Tree 5 -> Pixie8 -> 70-77
Tree 6 -> Pixie8 -> 78-7F
Tree 7 -> Pixie8 -> 80-87
Tree 8 -> Pixie8 -> 88-8F
```

This independently confirms the eight physical Pixie 8 controller blocks already inferred from the current V7 Master Musical topology.

### Review item — Tree 4 network

The 2025 inventory records Tree 4 (`68-6F`) on:

```text
Aux-F
```

while the current V7 topology reviewed during FieldWiring shows the Who Forest Tree block on `Aux-I`.

Do not silently correct either source. Treat this as a historical/current reconciliation item.

## Santa's Workshop — Inventory Gap for Current Pixie 8 Trees

The current V7 Master Musical topology shows two Pixie 8-style RGB Tree blocks at Santa's Workshop:

```text
10-17
18-1F
```

The 2025 controller inventory does **not** contain corresponding Pixie8 inventory rows for those two Tree controllers.

The inventory does contain other Santa's Workshop hardware, including:

- conventional LOR controllers; and
- two `E1.31` `Pixicon-16` records for the Gift Conveyor / Gift Bag and conveyor rollers.

Therefore the 2025 inventory is not complete enough to serve as the sole current controller authority for Santa's Workshop.

## Church and Candyland — Current RGB Controllers Not Present

The Church RGB controller patterns reviewed during FieldWiring are not represented as current Pixie inventory rows in this 2025 file:

- Church Pixie 16 RGB Tree;
- Church Pixie 2 Cross controllers; and
- Church repeated-address Pixie 4 Candy Cane controllers.

Likewise, the current Candyland repeated Pixie 4 Candy Cane groups are not present.

This is further evidence that the 2025 inventory is a valuable source artifact but is incomplete relative to the current 2026 LOR topology.

## E1.31 Rows in the 2025 Inventory

The inventory contains six populated `E1.31` rows:

```text
19-Santas Workshop
    Pixicon-16
    Gift Conveyor

19-Santas Workshop
    Pixicon-16
    Gift Bag & Conveyor Rollers

07- Mt Crumpet
    Pixicon-16
    Matrix

03-MT Globe
    Pixiecon 16
    legacy IP evidence 192.168.5.103

03-MT Tree Pixiecon
    model recorded as Coro
    controller type 48
    legacy IP evidence 192.168.5.110

Mega Cube
    model recorded as Coro
    controller type 48
    incomplete legacy IP text 192.168.5.
```

### Interpretation

These rows are useful physical/deployment evidence, but they do not fully describe the current E1.31 physical controller layout.

In particular:

- the Mega Cube is physically known to use three PixCon controllers, but the 2025 inventory has one aggregate `48`-channel/port-style row;
- the current Mega Star two-controller layout is absent;
- current IP addressing has changed from the older `192.168.5.x` values recorded here to the `10.10.5.x` values in `DMX Control Addressing.xlsx`; and
- the Mt. Crumpit row supports one PixCon 16 physical controller for the Matrix but does not carry the current IP mapping.

Therefore the 2025 inventory and `DMX Control Addressing.xlsx` must be reconciled as complementary evidence:

```text
2025 Controller Inventory
    -> physical model / deployment / location / firmware evidence

DMX Control Addressing.xlsx
    -> universe / physical output / IP configuration history and current planning evidence

current V7 / PostgreSQL snapshot
    -> current LOR-authoritative show topology
```

None of these sources alone should be promoted unreviewed into a new permanent controller schema.

## Other Useful Controller Families Present

The inventory also provides real deployment examples for:

- conventional 16-channel LOR A/C controllers (`32LD-G3`);
- 4-channel LOR controllers (`CTB04-G3`);
- Pixie 2 controllers;
- Pixie 8 controllers;
- one Pixie 16 example;
- Cosmic Color Flood-style devices; and
- E1.31/PixCon-style devices.

These source examples are useful for Controller Inventory model normalization and FieldWiring acceptance tests.

## FieldWiring Consequences

This source materially improves FieldWiring development because it confirms that physical controller information exists outside the generic LOR wiring rows.

However, FieldWiring must distinguish three levels of certainty:

```text
current LOR topology
    authoritative for show addressing

accepted physical mapping from inventory/source evidence
    usable for field presentation when reconciled

permanent controller asset identity
    not yet established in PostgreSQL
```

The browser must not fabricate a permanent controller identity from Unit ID, network, IP address, Display name, or Park Location.

## Next Controller-Inventory Work

Before any PostgreSQL controller schema is proposed:

1. preserve these two 2025 CSVs as source artifacts;
2. reconcile model-name variants against the lookup table and actual hardware;
3. compare 2025 inventory rows against current 2026 V7/LOR controller topology;
4. compare E1.31 inventory rows with `DMX Control Addressing.xlsx`;
5. identify additions/removals since the 2025 inventory, especially Church, Candyland, Santa's Workshop Pixie 8 Trees, Mega Star, and other current RGB controllers;
6. resolve source conflicts such as Who Forest Tree 4 `Aux-F` versus current V7 `Aux-I`;
7. define a stable permanent physical controller key independent of LOR Unit ID, network, IP, Display, or location;
8. then design deployment/history relationships and FieldWiring enrichment.

No schema change is authorized by this source audit.
