# FieldWiring E1.31 Dense RGB Field Presentation Contract

| Document control | Value |
|---|---|
| Status | DRAFT — accepted field UX direction; inventory reconciliation pending |
| Sub-project | FieldWiring |
| Current revision | 2026-08-21 |
| Owner | MSB Database Administrator |
| Schema status | No schema change authorized |

## Purpose

FieldWiring must distinguish dense RGB Displays driven through the MSB E1.31 network from both conventional LOR/Pixie hookups and the simpler DMX/DumbRGB fixture case.

The current V7 snapshot represents the reviewed dense RGB examples with:

```text
device_type = DMX
string_type = RGB
```

and materializes their universe/channel topology through the current DMX-channel relations and legacy-compatible wiring views.

For these Displays, the compatibility-view `Controller` value is a universe/addressing value, **not the physical AlphaPix/PixCon controller identity** the installer sees.

FieldWiring must translate the current LOR/E1.31 topology into physical controller/network/output language instead of simply rendering the compatibility `Controller / StartChannel` columns.

## E1.31 Is a Separate Field Presentation Family

The accepted FieldWiring families include:

```text
Traditional LOR
    -> conventional A/C controller / numbered output

LOR + RGB
    -> Pixie controller / numbered RGB output

DMX + DumbRGB
    -> DMX network / fixture hookup

DMX + RGB — reviewed dense RGB examples
    -> E1.31 network / intelligent pixel-controller hookup
```

The last two families both use `device_type = DMX` in the current parser model, but their physical hookup is not the same.

```text
device_type = DMX + string_type = DumbRGB
    -> DMX fixture/network presentation

device_type = DMX + string_type = RGB
    -> reviewed dense-pixel/E1.31 presentation
```

Do not generalize every possible `DMX + RGB` Prop outside reviewed MSB cases without confirming the physical design.

## Physical Field Model

Dense RGB Displays use intelligent pixel controllers connected to the E1.31 network.

The field operator should normally think in terms such as:

```text
Display / Display section
physical pixel controller
physical controller output/port
E1.31 network connection
```

Universe and channel range are also meaningful field information for E1.31 because universe assignments are published together with pixel counts in the MSB wiring workflow. They must remain tied to the physical output/section relationship rather than being presented as though each universe were a separate physical controller.

## Current Source Evidence

FieldWiring now has three complementary E1.31 sources:

```text
current V7 / PostgreSQL topology
    -> current LOR-authoritative universe/channel topology

DMX Control Addressing.xlsx
    -> universe / physical-output / IP mapping history and current planning evidence

Controller Inventory & Firmware 2025 - Inventory.csv
Controller Inventory & Firmware 2025 - Lookup Table.csv
    -> 2025 physical model / deployment / firmware evidence
```

The 2025 controller inventory has now been inspected. It is useful, but incomplete/stale relative to current 2026 topology and does not provide a permanent physical-controller asset key.

See [Controller Inventory 2025 Source Audit — 2026-08-19](../08_Controller_Inventory/Controller_Inventory_2025_Source_Audit_2026-08-19.md).

No one source should be silently promoted over the others. They must be reconciled according to authority:

- LOR/V7 owns current show topology;
- controller inventory owns/should own physical hardware identity after reconciliation; and
- addressing workbooks preserve network/output configuration evidence.

## `DMX Control Addressing.xlsx`

The addressing workbook records this E1.31 IP/controller map:

```text
Show PC
    10.10.5.5

Mega Tree
    10.10.5.10
    Alpha Pix / Flex48

Mega Ball
    10.10.5.11
    PixCon 16

Mega Cube Controller 1
    10.10.5.12
    PixCon 16

Mega Cube Controller 2
    10.10.5.13
    PixCon 16

Mega Cube Controller 3
    10.10.5.14
    PixCon 16

Mega Star Controller 1
    10.10.5.15
    PixCon 16

Mega Star Controller 2
    10.10.5.16
    PixCon 16

Mt. Crumpit
    10.10.5.17
    PixCon 16

Northern Lights / PixieLink
    10.10.5.30
```

The workbook also contains historical configuration columns such as `IP 2023`, `IP 2024`, `Original Config`, and `2023 Config`.

IP address is configuration data, not permanent controller identity.

## 2025 Controller Inventory E1.31 Evidence

The 2025 inventory contains six populated `E1.31` rows:

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
    Controller Type 16
    legacy IP evidence 192.168.5.103

03-MT Tree Pixiecon
    model recorded as Coro
    Controller Type 48
    legacy IP evidence 192.168.5.110

Mega Cube
    model recorded as Coro
    Controller Type 48
    incomplete legacy IP text 192.168.5.
```

These rows provide useful model/deployment evidence but do not fully encode the current physical controller layout.

Important consequences:

- the 2025 inventory's older `192.168.5.x` addressing must not override the newer `10.10.5.x` addressing workbook evidence;
- Mega Cube's single aggregate `48` row cannot represent the known three physical PixCon controllers as separate assets;
- Mega Star is absent from the 2025 E1.31 inventory rows; and
- the source contains model-name variants (`Pixicon-16`, `Pixiecon 16`, `Coro`) that require controlled normalization.

## Mega Tree

Current V7:

```text
lor_comment = TR-MegaTreeRGBTree
device_type = DMX
string_type = RGB
parm1 = 48
parm2 = 100
Universes 1-48
```

Accepted physical evidence:

```text
one 48-output AlphaPix / Flex48-style controller
DMX addressing workbook IP: 10.10.5.10
Outputs 1-48 -> Universes 1-48
```

The 2025 inventory contains a corresponding 48-type E1.31 row for `03-MT Tree Pixiecon`, recorded with model `Coro` and legacy IP evidence `192.168.5.110`.

The two source labels must be reconciled; FieldWiring must not guess that the source model strings are already normalized permanent identities.

The 48 universe values are E1.31 addressing for one physical controller context, not 48 physical controllers.

## Mega Ball

Current V7:

```text
lor_comment = TR-MegaTreeRGBBall
device_type = DMX
string_type = RGB
parm1 = 16
Universes 49-64
```

Accepted physical evidence:

```text
one PixCon 16
DMX addressing workbook IP: 10.10.5.11
Outputs 1-16 -> Universes 49-64
```

The 2025 inventory independently contains `03-MT Globe`, model `Pixiecon 16`, Controller Type `16`, with older IP evidence `192.168.5.103`.

This is useful corroboration of the physical controller model while also proving that IP address is historical/configuration data.

## Mega Cube

Current V7:

```text
lor_comment = WA-MegaCube
device_type = DMX
string_type = RGB
```

Accepted physical evidence from the addressing workbook:

```text
three PixCon 16 controllers
10.10.5.12
10.10.5.13
10.10.5.14
```

The current V7 materialization exposes generic start-universe records at:

```text
65
73
93
101
```

The 2025 controller inventory has only one aggregate `Mega Cube` E1.31 row with model `Coro`, Controller Type `48`, and incomplete legacy IP text.

Therefore:

> FieldWiring must not derive physical controller count from either generic compatibility row count or the aggregate 2025 `Controller Type 48` row.

The three physical controller identities/labels remain a reconciliation task.

## Mega Star

Current V7:

```text
lor_comment = FT-MegaStar
device_type = DMX
string_type = RGB
Universes 113-140 active
```

The addressing workbook records:

```text
Mega Star Controller 1 -> PixCon 16 -> 10.10.5.15
Mega Star Controller 2 -> PixCon 16 -> 10.10.5.16
```

and maps:

```text
Controller 1 outputs 1-16 -> Universes 113-128
Controller 2 outputs 1-12 -> Universes 129-140
```

Mega Star is absent from the 2025 E1.31 inventory rows.

That absence is a concrete controller-inventory reconciliation gap, not permission to invent a permanent asset identity from the workbook or universes.

## Mt. Crumpit Matrix

Current V7:

```text
lor_comment = WV-WhoMatrix
device_type = DMX
string_type = RGB
large blocks beginning at Universes 147 and 155
```

The addressing workbook records:

```text
one PixCon 16
IP 10.10.5.17
Outputs 1-16
Universes 147-162
```

The 2025 inventory independently records:

```text
07- Mt Crumpet
E1.31
Pixicon-16
Controller Type 16
On back of Panel
For Matrix top of MT
```

This is strong corroboration that Mt. Crumpit is one physical 16-output PixCon-style controller context, while the exact current permanent controller identity still requires the future controller master.

## Santa's Workshop E1.31 Devices

The 2025 inventory also reveals two E1.31 devices at Santa's Workshop that were not part of the initial dense-RGB examples:

```text
Pixicon-16 -> Gift Conveyor
Pixicon-16 -> Gift Bag & Conveyor Rollers
```

These should be included in later E1.31 FieldWiring/controller-inventory reconciliation rather than ignored simply because the initial discussion focused on Mega Tree/Cube/Star and Mt. Crumpit.

They are separate from the two current LOR/Pixie 8 RGB Tree controller blocks at Santa's Workshop.

## V7.0.11 Source Preservation and Browser Read Contract

Parser V7.0.11 additively preserves the originating grouped-DMX source detail on each materialized `dmxChannels` row:

```text
RawPropID
ChannelName
ChannelGridRowNumber
```

The canonical `PropId` relationship remains the Display/master relationship. The new fields provide the LOR-authored source identity and Channel Name needed to distinguish physical sections/strings within grouped dense-RGB Displays such as Mega Star.

The E1.31 FieldWiring read model must therefore carry, at minimum:

```text
display_id
display_name
source_raw_prop_id
channel_name
channel_grid_row_number
network
universe
start_channel
end_channel
```

Physical controller identity and physical output/port are supplied by the Controller Inventory/current-assignment side of the contract or by a centralized temporary reviewed mapping during recovery. They must not be invented from universe, IP address, Display name, or source row position.

## Accepted Technician-Facing E1.31 Table

Where the physical controller/output relationship is accepted/current, the normal browser presentation is grouped by **physical controller** and shows one relationship per physical output/section with these columns:

```text
OUTPUT / PORT
CHANNEL / DISPLAY SECTION
UNIVERSE
PIXELS
CHANNEL RANGE
```

Conceptually:

```text
E1.31 · <Physical Controller>

OUTPUT   CHANNEL / SECTION        UNIVERSE   PIXELS   CHANNEL RANGE
1        <LOR Channel Name>       113        150      1-450
2        <LOR Channel Name>       114        150      1-450
```

This is intentionally more field-facing than the current one-row `E1.31 controller mapping pending` summary.

### Addressing and pixel-count rules

`Universe`, `StartChannel`, and `EndChannel` are authoritative addressing values and must remain available on each relationship.

For an RGB E1.31 relationship, FieldWiring may derive:

```text
channel_count = EndChannel - StartChannel + 1
pixel_count   = channel_count / 3
```

only when the channel span is valid for an RGB relationship and divides cleanly by three.

Examples:

```text
50 pixels  -> 150 channels
100 pixels -> 300 channels
150 pixels -> 450 channels
170 pixels -> 510 channels
```

A standard 510-channel RGB universe therefore carries at most 170 RGB pixels without spillover.

Pixel count is derived presentation data. It does **not** replace the authoritative start/end channel values, and FieldWiring must not assume that every relationship begins at channel `1`.

Universe plus pixel count is intentionally visible in the normal technician presentation because that pairing is already published in the MSB E1.31 wiring workflow. Channel range remains visible alongside it for exact addressing and troubleshooting.

## What the Operator Should See

Where the physical relationship is accepted/current, the normal E1.31 field result should identify:

```text
Display / Display section
physical controller
physical output/port
Universe
Pixel count
StartChannel-EndChannel
```

Raw source UUIDs, parser provenance, IP address, legacy compatibility `Controller`, Source, and DeviceType belong under Engineering Details unless a specific troubleshooting workflow requires them in the normal view.

## What Can Be Done Now

FieldWiring development does not need to stop for controller-inventory schema work.

The combined evidence is sufficient to:

- classify reviewed `DMX + RGB` dense Displays into the E1.31 presentation family;
- avoid presenting universe numbers as physical controller identities;
- preserve and display universe/channel topology with the applicable physical output/section relationship;
- derive and present RGB pixel count where the channel span supports it;
- use V7.0.11 `RawPropID`, `ChannelName`, and `ChannelGridRowNumber` as source wiring provenance without changing permanent Display identity;
- use accepted physical controller/output mappings in prototypes where corroborated; and
- explicitly mark where permanent asset identity or current mapping remains unresolved.

Do not create permanent controller IDs from Unit ID, universe, IP address, Display name, Park Location, or source row position.

## Controller Inventory Requirements Exposed by E1.31

The future controller master/deployment model must represent at least:

- permanent physical controller identity;
- normalized controller family/model;
- physical output/port count;
- Stage/Scene/Display deployment;
- E1.31 network relationship;
- current management IP address when operationally required;
- current universe/address range;
- physical output/port to Display/string/section mapping; and
- deployment/history so changed IPs/universe mappings do not overwrite prior evidence.

Universe and IP address are configuration attributes, not permanent controller identity.

One Display may use multiple physical controllers (Mega Cube, Mega Star).

One physical controller may serve many universes (Mega Tree).

## Acceptance Requirements

At minimum, E1.31 FieldWiring testing must prove:

1. reviewed `DMX + RGB` dense Displays are not rendered as DMX/DumbRGB fixtures;
2. Mega Tree Universes `1-48` are presented as one accepted 48-output controller context, not 48 controllers;
3. Mega Ball Universes `49-64` are presented as one accepted PixCon 16 context;
4. Mega Cube can be presented as three physical PixCon controller contexts using accepted mapping rather than generic row count or the aggregate 2025 inventory row;
5. Mega Star can be presented as two physical PixCon 16 contexts using accepted addressing evidence while remaining an inventory reconciliation gap;
6. Mt. Crumpit can be presented as one PixCon 16 context, corroborated by both the addressing workbook and 2025 inventory;
7. Santa's Workshop E1.31 Gift Conveyor / Gift Bag controller records are retained for reconciliation;
8. normal E1.31 rows show physical output/port, source Channel Name/section, universe, derived pixel count when valid, and exact start/end channel range;
9. V7.0.11 grouped-DMX source Channel Names remain attached to the correct universe/channel relationships rather than collapsing to the canonical master Channel Name;
10. permanent controller labels/output ports are supplied from reconciled Controller Inventory or an explicitly reviewed temporary resolver rather than invented from universe or IP values;
11. raw UUID/provenance/IP/source metadata remains available for engineering/troubleshooting without replacing the field-facing hookup table; and
12. no current LOR/E1.31 topology is rewritten merely to simplify browser presentation.

## Related Documents

- [Controller Inventory 2025 Source Audit — 2026-08-19](../08_Controller_Inventory/Controller_Inventory_2025_Source_Audit_2026-08-19.md)
- [FieldWiring Field Presentation Requirements](FieldWiring_Field_Presentation_Requirements.md)
- [FieldWiring Physical Controller / Output Presentation Contract](FieldWiring_Physical_Controller_Output_Presentation_Contract.md)
- [FieldWiring DMX / DumbRGB Field Presentation Contract](FieldWiring_DMX_DumbRGB_Field_Presentation_Contract.md)
- [Controller Inventory and Labeling Plan](../08_Controller_Inventory/Controller_Inventory_and_Labeling_Plan.md)
- [Network Infrastructure](../10_Network_Infrastructure/README.md)
- [FormView Engineering Architecture](../../../01_LOR_System/04_FormView/FormView_Engineering_Architecture.md)
