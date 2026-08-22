# Controller Inventory 2026 Source Audit — 2026-08-22

| Item | Value |
|---|---|
| Status | ENGINEERING SOURCE AUDIT — data review in progress |
| Subsystem | Controller Inventory |
| Current working source | `Controller Inventory & Testing 2026.xlsx` |
| FieldWiring baseline reviewed | `FieldWiring_Release_Candidate_Handoff_and_Development_Runbook_2026-08-21.md` |
| PostgreSQL implementation | NOT AUTHORIZED by this audit |

## Purpose

This audit replaces the 2025 CSV as the primary description of the **current working controller inventory source**. The older 2025 inventory, lookup export, `DMX Control Addressing.xlsx`, and preserved LOR snapshots remain useful engineering evidence, but the 2026 workbook is now the active controller-review worksheet.

The objective is to identify what the 2026 workbook already establishes, what still requires physical verification, and what Controller Inventory must eventually provide to FieldWiring without duplicating LOR-owned wiring data.

No PostgreSQL tables, migrations, permanent controller IDs, or automatic source corrections are authorized by this document.

## Workbook Structure

`Controller Inventory & Testing 2026.xlsx` contains three worksheets:

```text
Inventory               A1:K183
Lookup Table             A1:E16
Instructions to Update   A1:B10
```

The `Inventory` worksheet contains 161 populated controller rows before its summary section.

Current working columns are:

```text
Picked Up?
Updated
Display ID
Network
Current?
Model
Firmware
Controller ID (HEX)
Controller Type
Park Location
For What
```

At the time of this audit, `Picked Up?`, `Updated`, and `Current?` are blank across all 161 populated rows. Those fields therefore appear to be workflow/review fields that have not yet been populated; this audit does not assign semantics beyond the worksheet labels.

The `Instructions to Update` worksheet documents the current Light-O-Rama Hardware Utility process for finding a controller by Unit ID, recording model/firmware, and updating firmware from the local firmware folder.

## Current Model Counts in the 2026 Worksheet

The 161 populated rows currently use these model labels:

| Source Model | Rows |
|---|---:|
| `32LD-G3` | 76 |
| `Pixie2D-V3` | 25 |
| `CF50D` | 18 |
| `CTB04-G3` | 12 |
| `Pixie8` | 10 |
| `Pixcon16` | 7 |
| `Pixie4` | 5 |
| `AlphaPix Flex 48` | 2 |
| `Pixie2` | 2 |
| `Pixie2/CCR2` | 2 |
| `CMB24D` | 1 |
| `Pixie16` | 1 |

These are source labels, not yet the final normalized controller-model reference.

## Model Normalization Status

The 2026 lookup table is improved but does not yet contain an exact entry for every model used by the Inventory sheet.

Exact/case-insensitive matches currently exist for:

- `AlphaPix Flex 48`;
- `CF50D`;
- `PixCon16` / source spelling `Pixcon16`; and
- `Pixie2/CCR2`.

Inventory source labels without an exact lookup-table model currently include:

- `32LD-G3`;
- `CMB24D`;
- `CTB04-G3`;
- `Pixie16`;
- `Pixie2`;
- `Pixie2D-V3`;
- `Pixie4`; and
- `Pixie8`.

`PixCon16` is the confirmed controller name and is a different device from a Pixie-16. They must remain separate exact models.

Do not map the other source labels to similar lookup entries solely by spelling. Confirm the actual hardware/model first.

## The 2026 Workbook Closes Several 2025 Gaps

The new source now explicitly contains current controller rows for several physical patterns that were missing or incomplete in the 2025 inventory.

### Church

Current rows include:

```text
Church Cross Left   Aux-N   42-43   Pixie2/CCR2
Church Cross Right  Aux-N   44-45   Pixie2/CCR2
Church Candy Canes  Aux-N   21-24   Pixie4   [two physical rows]
```

The two Church Pixie4 rows intentionally have the same address range. They are not safe to deduplicate merely because the rows are otherwise identical.

The workbook still does **not** identify the permanent physical Church Tree Pixie16 used by the current FieldWiring `30-3F` pattern, and it does not establish the permanent physical controller for the separate Church Tree Star `40-41` context. Those remain physical inventory-review items.

### Candyland

Current rows include:

```text
RGB Lollipops       50-5F   Pixie16
RGB Candy Canes     21-24   Pixie4   [three physical rows]
```

The three Candyland Pixie4 rows intentionally represent more than one physical controller but are currently identical at the worksheet-field level. They still need a distinguishing physical group such as:

```text
Candy Canes 1-4
Candy Canes 5-8
Candy Canes 9-12
```

The Candyland Lollipop row is recorded on `Aux-B`, while the current FieldWiring accepted Lollipop resolver expects the reviewed LOR pattern on `Aux C`. Do not change either source by assumption. Reconcile this against the current approved LOR/V7 snapshot and the actual controller before database implementation.

### Who Forest

The workbook now records eight Pixie8 rows on `Aux-I`:

```text
50-57
58-5F
60-67
68-6F
70-77
78-7F
80-87
88-8F
```

This agrees with the current FieldWiring physical grouping. In particular, Tree 4 is now recorded on `Aux-I`, resolving the old 2025 worksheet value of `Aux-F` at the working-source level. The older source should remain preserved as historical evidence of the discrepancy rather than overwritten.

### Santa's Workshop

The workbook now records the two current Pixie8 Tree controllers:

```text
Aux-D  10-17  Santa Tree-01
Aux-D  18-1F  Santa Tree-02
```

These were missing from the 2025 inventory.

## E1.31 Inventory Now Has Better Physical Coverage

Current 2026 rows include:

```text
Mega Tree          AlphaPix Flex 48   10.10.5.10
Mega Cube          AlphaPix Flex 48   10.10.5.12
Mega Star #1       PixCon16           10.10.5.15
Mega Star #2       PixCon16           10.10.5.16
Hwy 42 Open/Close  PixCon16           10.10.5.20
Mega Ball/Globe    PixCon16           10.10.5.11
Mt. Crumpit        PixCon16           10.10.5.17
Santa Conveyor     PixCon16           10.10.5.18
Santa Conveyor Bag PixCon16           10.10.5.19
```

This now directly supports several temporary physical mappings documented by the FieldWiring release candidate.

The release-candidate handoff identifies the current explicit temporary E1.31 mappings in `FieldWiring/Application/wiring_e131.py` as:

```text
Mega Tree  -> AlphaPix / Flex48 -> Universes 1-48 -> Outputs 1-48
Mega Ball  -> PixCon16          -> Universes 49-64 -> Outputs 1-16
Mega Star Controller 1 -> PixCon16 -> Universes 113-128 -> Outputs 1-16
Mega Star Controller 2 -> PixCon16 -> Universes 129-140 -> Outputs 1-12
```

The 2026 workbook now provides physical inventory rows for all four of those temporary controller contexts, although permanent `CL-###` identities have not yet been assigned.

## Mega Cube Must Be Re-Reconciled

Do not carry the older Controller Inventory assumption of three PixCon16 controllers forward as an accepted current fact.

The 2026 workbook currently records:

```text
03-Mega Cube
Network: E1.31
Model: AlphaPix Flex 48
Firmware: 2.0.13
Controller ID: IP
Controller Type: 16
Park Location: At display
IP: 10.10.5.12
```

This conflicts both with the older three-PixCon evidence and internally with the `AlphaPix Flex 48` model / `Controller Type 16` combination.

The current FieldWiring release candidate intentionally leaves Mega Cube compact CustomGrid expansion as a parser/materialization limitation rather than fabricating physical rows. Therefore Mega Cube should remain a Controller Inventory review item until the actual installed hardware and intended output count are physically confirmed.

## Exact Repeated Rows Are Not Safe to Deduplicate

The worksheet contains repeated rows that can represent separate physical controllers intentionally carrying the same address. Without permanent controller identity, an identical row is not proof of a duplicate spreadsheet entry.

Important examples include:

- two Church Pixie4 rows at `Aux-N / 21-24`;
- three Candyland Pixie4 rows at `Aux-A / 21-24`;
- repeated Pixie2D-V3 rows for Elden, Felix, Ralphie, and Zuzu; and
- repeated CF50D rows for several fixtures.

The cleanup process must assign or otherwise establish physical controller identity before removing any of these rows.

For duplicate-address cases where the current Network + Unit ID/range cannot distinguish the physical controller, record a short physical group/role until permanent `CL-###` identity is available.

## Other Current Address Collisions Need Review, Not Automatic Correction

The current worksheet also contains same-Network/same-address rows associated with different contexts, including examples such as:

```text
Aux-B / 60
Aux-B / 62
Aux-I / 20
Regular / 22
Regular / 7A
```

MSB intentionally repeats addresses in some locations. These values should therefore be reviewed as either intentional repeated-command relationships or actual address conflicts. Do not enforce `Network + Unit ID` uniqueness.

## Network Name Normalization Is Still Needed

The 2026 source uses both:

```text
E1.31
E-1.31
```

for the E1.31 family. This is source terminology that should be normalized during controlled data cleanup before database implementation, while preserving the original source evidence.

## Firmware Evidence Is Much Better

Firmware is populated on 160 of the 161 controller rows.

Current model/version patterns include:

```text
32LD-G3        1.17 on 70 rows; 1.15 on 3; 1.01 on 3
PixCon16       2.0.13 on 7 rows
CF50D          1.05 on 18 rows
CTB04-G3       1.01 on 12 rows
Pixie4         1.10 on 5 rows
Pixie8         1.05 on 8 rows; 1.10 on 2 rows
Pixie16        1.09 on 1 row
Pixie2         1.08 on 2 rows
Pixie2/CCR2    1.06 on 2 rows
Pixie2D-V3     1.05 on 25 rows
```

The Mega Tree AlphaPix Flex 48 row is the one current controller row with blank firmware.

The lookup table's `Latest Firmware` remains model-reference information and must not be treated as proof of installed firmware.

## Summary Section Is Not Engineering Authority

The embedded summary at the bottom of the Inventory worksheet still contains stale/inconsistent formulas and values and should not be used as migration authority.

Confirmed examples:

1. `Pixcon16` is summarized as `8` channels each even though the seven inventory rows carry `Controller Type = 16` and the lookup table lists `PixCon16` as 16 channels/outputs.
2. The total in `H183` uses `=SUM(I2:I154)`, excluding the remaining populated controller rows through row 162. It reports `1712`; the populated `Controller Type` values through row 162 sum to `1776`.
3. `Controllers at Displays` uses a formula limited to `J3:J49`, so the reported `36` is not a count over the full 2026 inventory.
4. Some per-model total cells are blank even when row counts/output counts are populated.

The individual source rows should be reviewed first. Summary formulas can be repaired later if the workbook remains an operational tool.

## FieldWiring Integration Consequence

The current FieldWiring release candidate makes the intended replacement boundary explicit:

- `wiring_presentation.py` contains temporary reviewed A/C/Pixie grouping rules;
- `wiring_e131.py` contains temporary reviewed E1.31 controller/output mappings;
- FieldWiring remains read-only and does not own permanent controller identity; and
- Controller Inventory is the future replacement source for permanent controller identity/current physical assignment.

The 2026 workbook now provides enough physical-controller evidence to continue designing that **read interface**, but not enough reviewed data to authorize PostgreSQL tables.

The eventual Controller Inventory interface should allow FieldWiring to replace named temporary controller groups with permanent controller identity while continuing to obtain detailed Display/output/universe/channel relationships from the current LOR/V7 snapshot.

## Immediate Data Review Priorities

Before schema design:

1. assign/establish one permanent physical controller identity per real controller;
2. physically distinguish identical duplicate-address rows, especially Church and Candyland Pixie4 groups;
3. verify missing Church Tree Pixie16 and Church Tree Star controller assets;
4. resolve Candyland Lollipop `Aux-B` versus current FieldWiring/LOR `Aux C` evidence;
5. physically verify Mega Cube model/output count/current layout;
6. normalize confirmed model names, including canonical `PixCon16`, without merging it with Pixie-16;
7. normalize `E1.31` / `E-1.31` terminology;
8. verify the Mega Tree AlphaPix firmware;
9. review same-network/same-address A/C and other repeated-controller rows as intentional repeat versus conflict; and
10. only after those reviews, define the minimum Controller Inventory current-state read contract required to replace FieldWiring's temporary hard-coded controller mappings.

## Schema Gate

This updated source materially improves the data, but the PostgreSQL schema gate remains closed.

Do not create Controller Inventory tables or migrations until permanent physical identity, model normalization, duplicate-address disambiguation, current address mapping, and the FieldWiring replacement interface have been reviewed and accepted.

## Related Documents

- [Controller Inventory](README.md)
- [Controller Inventory Current-State / FieldWiring Integration Plan](Controller_Inventory_Current_State_FieldWiring_Integration_Plan_2026-08-20.md)
- [Controller Inventory 2025 Source Audit](Controller_Inventory_2025_Source_Audit_2026-08-19.md)
- [FieldWiring Release Candidate Handoff and Development Runbook](../09_Wiring_System/FieldWiring_Release_Candidate_Handoff_and_Development_Runbook_2026-08-21.md)
- [FieldWiring / Controller Inventory Handoff](../09_Wiring_System/FieldWiring_Controller_Inventory_Handoff_2026-08-20.md)
