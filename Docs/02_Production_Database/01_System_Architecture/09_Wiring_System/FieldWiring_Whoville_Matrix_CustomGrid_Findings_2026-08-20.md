# FieldWiring Whoville Matrix CustomGrid Findings — 2026-08-20

| Item | Value |
|---|---|
| Status | ENGINEERING FINDING — raw live Preview inspection |
| Sub-project | FieldWiring |
| Display | `WV-WhoMatrix` |
| Live source | `2026 Master Musical Preview v6.6.10 2026-08-20.lorprev` |
| Schema status | No schema, parser, or renderer change authorized by this finding |

## Purpose

This note records raw Light-O-Rama source evidence for the Whoville custom matrix so the dense-RGB FieldWiring design does not have to rediscover how the Display is encoded.

The August 20 live Preview is newer than Run 50 and must not be treated as the exact Run 50 source. It is used here as current LOR structural evidence.

## Raw PropClass

The live Preview contains one `PropClass` for:

```text
Comment: WV-WhoMatrix
Name: Who Mt Crumpet RGB Pixel Matrix
DeviceType: DMX
StringType: RGB
IndividualChannels: False
Tag: RGB Matrix 20x40
MaxChannels: 300
SeparateIds: True
```

Its `ChannelGrid` is:

```text
Regular,147,1,300,2100,Red;Regular,155,1,300,2100,
```

The parser currently preserves these as two DMX legs beginning at Universes 147 and 155. The fifth ChannelGrid field (`2100`) remains opaque in the current parser contract and must not be assigned a physical meaning without further authoritative evidence.

## Custom Grid Structure

The PropClass contains a nested `shape` element with:

```text
ShapeName: Custom
CustomWidth: 40
CustomHeight: 40
```

The serialized `CustomGrid` was inspected directly.

Confirmed properties:

```text
Rows: 40
Columns per row: 40
Cell count: 1600
Unique cell identifiers: 1600
Minimum identifier: 1
Maximum identifier: 1800
Missing identifier range: 801-1000
```

Therefore the custom grid contains exactly two used logical identifier blocks:

```text
1-800
1001-1800
```

and intentionally does not use:

```text
801-1000
```

The grid is serpentine. Adjacent rows reverse direction. Examples include:

```text
1800 ... 1761
1721 ... 1760
1720 ... 1681
```

and around the middle boundary:

```text
1040 ... 1001
800  ... 761
721  ... 760
```

The last rows end with:

```text
120 ... 81
41  ... 80
40  ... 1
```

## Relationship to ChannelGrid

The two logical 800-pixel CustomGrid blocks align numerically with the two ChannelGrid starting universes:

```text
Logical block A: 1001-1800
ChannelGrid start: Universe 147

Logical block B: 1-800
ChannelGrid start: Universe 155
```

The two universe starts are exactly eight universes apart:

```text
155 - 147 = 8
```

Observed arithmetic is strongly consistent with each logical block representing 800 RGB pixels:

```text
800 pixels × 3 RGB channels = 2400 channels
300 + 2100 = 2400
```

This arithmetic is an engineering inference only. It is not authorization to redefine the opaque fifth ChannelGrid field as a channel-count field.

Likewise, the eight-universe separation is consistent with eight 300-channel universe-sized sections per 800-pixel logical block, but this finding does not yet prove a direct physical PixCon output-to-universe mapping.

## Physical Controller Boundary

Operator-confirmed physical configuration:

```text
WV-WhoMatrix -> one physical PixCon16 controller
```

The raw Preview proves a complete 1600-pixel custom logical topology and two large DMX address blocks. It does not explicitly expose sixteen physical PixCon16 output-port assignments.

Therefore FieldWiring must keep these facts separate:

```text
LOR Preview
    -> custom matrix pixel topology
    -> DMX/E1.31 addressing blocks

Controller/network configuration or future Controller Inventory resolver
    -> permanent ctrl_id
    -> physical PixCon16 output/port mapping
```

Do not present Universe 147 or Universe 155 as physical controller identities. Do not automatically assign PixCon outputs 1-16 from universe order until that mapping is confirmed by controller/network configuration or other accepted physical evidence.

## MotionRowDefaults

The nested `MotionRowDefaults` include sequencing/effect regions such as:

- Whole Matrix;
- Tier 1-4;
- Column 1-4;
- Left Half;
- Right Half;
- LL Line;
- LL Fill;
- Cave.

These are useful LOR sequencing geometry but are not currently required to establish physical field wiring.

## FieldWiring Consequence

Whoville Matrix should not be treated as a generic two-row DMX fixture merely because V7 materializes two DMX legs.

It is a dense-RGB custom matrix with one known PixCon16 physical controller context. FieldWiring can use LOR for the current custom-grid/addressing topology, but the physical output-port labels must remain unresolved until a separate authoritative controller mapping is available.

## Related Documents

- [FieldWiring Dense RGB Run 50 Topology Findings — 2026-08-20](FieldWiring_Dense_RGB_Run50_Topology_Findings_2026-08-20.md)
- [FieldWiring Dense RGB Live Preview / Run 50 Source-Drift Boundary — 2026-08-20](FieldWiring_Dense_RGB_Live_Preview_Source_Drift_2026-08-20.md)
- [FieldWiring Dense RGB Physical Controller Map — 2026-08-20](FieldWiring_Dense_RGB_Physical_Controller_Map_2026-08-20.md)
- [FieldWiring / Controller Inventory Handoff — 2026-08-20](FieldWiring_Controller_Inventory_Handoff_2026-08-20.md)
