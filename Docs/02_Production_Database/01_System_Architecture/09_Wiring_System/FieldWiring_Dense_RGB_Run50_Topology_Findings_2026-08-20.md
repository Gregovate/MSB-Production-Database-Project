# FieldWiring Dense RGB Run 50 Topology Findings — 2026-08-20

| Item | Value |
|---|---|
| Status | ENGINEERING FINDING — source inspection in progress |
| Sub-project | FieldWiring |
| Current snapshot | Run 50 |
| Parser | V7.0.10 |
| Source preview folder | `G:\Shared drives\MSB Database\Database Previews V6.6.10` |
| Schema status | No schema or parser change authorized by this finding |

## Purpose

This record preserves the current Run 50 dense-RGB evidence discovered during FieldWiring acceptance. The goal is to determine what physical string/output relationships can be derived from current LOR/V7 data and what, if anything, must come from separate controller/network configuration.

Do not infer physical controller identity from universe numbers. The physical controller map remains controlled by the separate operator-confirmed dense-RGB controller finding.

## Current DMX Data Shape

The FieldWiring development snapshot contains `lor_snap__v_current_dmx_channels` with current DMX/E1.31 legs. The legacy wiring view exposes `start_universe` as the generic `Controller` value, but that value is addressing, not physical controller identity.

The parser preserves DMX legs with:

- network;
- start universe;
- start channel;
- end channel; and
- an additional opaque `unknown` field.

The `unknown` field has not yet been assigned a trusted physical meaning. In particular, the observed value `2100` for Mega Cube and Whoville Matrix must remain opaque until raw LOR structure or other authoritative evidence establishes its meaning.

## Mega Tree — `TR-MegaTreeRGBTree`

Current Prop evidence:

```text
Name: MT Mega Tree RGB Tree 48 x 100-360
IndividualChannels: 0
Parm1: 48
Parm2: 100
Lights: 100
```

Current DMX legs:

```text
48 legs
Universes 1-48
Each universe: channels 1-300
Unknown: 0
```

This is strongly consistent with the operator-confirmed physical design of 48 ribbons of 100 RGB pixels on one 48-output AlphaPix controller.

The current data establishes a clean one-leg-per-universe string pattern. It does not, by itself, authorize the further assumption that AlphaPix physical Output 1 equals Universe 1, Output 2 equals Universe 2, etc. That final controller-output mapping must be confirmed from raw LOR/controller configuration or other accepted physical evidence.

## Mega Ball — `TR-MegaTreeRGBBall`

Current Prop evidence:

```text
Name: MT Mega Tree RGB Ball 16 x 150
IndividualChannels: 0
Parm1: 16
Parm2: 50
Lights: 50
```

Current DMX legs:

```text
16 legs
Universes 49-64
Each universe: channels 1-150
Unknown: 0
```

This is strongly consistent with a sixteen-string logical pattern and the operator-confirmed one-PixCon16 physical controller context.

As with Mega Tree, current LOR/V7 topology proves the universe/channel legs but does not yet prove the exact physical-output-to-universe mapping.

## Mega Cube — `WA-MegaCube`

Current Prop evidence:

```text
Name: MC Mega Cube Left
IndividualChannels: 1
Parm1-Parm8: not populated in the current materialized master
Lights: 0
```

Current DMX legs:

```text
4 materialized legs
Start universes: 65, 73, 93, 101
Each row: channels 1-300
Unknown: 2100
```

The operator-confirmed physical configuration is one 48-output AlphaPix controller.

The four materialized DMX rows clearly do not represent four physical controllers. They also do not currently expose forty-eight physical outputs. Because `IndividualChannels=1` and the parser consolidates grouped DMX source rows onto one canonical master, the raw `.lorprev` PropClass/ChannelGrid source must be inspected before determining whether per-string detail was flattened during parsing.

## Whoville Matrix — `WV-WhoMatrix`

Current Prop evidence:

```text
Name: Who Mt Crumpet RGB Pixel Matrix
IndividualChannels: 0
Parm1-Parm8: not populated in the current materialized master
Lights: 0
```

Current DMX legs:

```text
2 materialized legs
Start universes: 147, 155
Each row: channels 1-300
Unknown: 2100
```

The operator-confirmed physical configuration is one PixCon16 controller.

The two materialized rows are not sufficient to derive the physical output map. The raw Preview must be inspected before assuming the meaning of the two starting-universe rows or the `2100` value.

## Mega Star — `FT-MegaStar`

Current Prop evidence:

```text
Name: MS Long Spire 1 4x150
IndividualChannels: 0
Parm1: 4
Parm2: 150
Lights: 150
```

Current DMX legs:

```text
28 legs
Universes 113-140
U113-U120: channels 1-450
U121-U124: channels 1-342
U125-U140: channels 1-450
Unknown: 0
```

The operator-confirmed physical configuration is two PixCon16 controllers.

The single current master Prop and its `Parm1=4` cannot describe the full two-controller physical arrangement. The current 28 universe legs preserve substantial topology, but the physical split between the two PixCon16 controllers and their output assignments must be determined from raw LOR source and/or controller configuration evidence.

## Parser Consolidation Risk

The current parser groups DMX source rows by LOR Comment / Display identity, writes one canonical master Prop, and attaches all DMX ChannelGrid legs to that master.

This is useful for Display-level wiring materialization, but it may flatten original per-string `PropClass.Name` and source-row distinctions that are important for dense-RGB physical output presentation.

Therefore the next source-inspection step is the raw Run 50 `.lorprev` XML from:

```text
G:\Shared drives\MSB Database\Database Previews V6.6.10
```

Specifically inspect every DMX `PropClass` whose `Comment` is one of:

```text
TR-MegaTreeRGBTree
TR-MegaTreeRGBBall
WA-MegaCube
WV-WhoMatrix
FT-MegaStar
```

Capture each original:

- PropClass `id`;
- `Name`;
- `Comment`;
- `IndividualChannels`;
- `Parm1`-`Parm8`;
- `ChannelGrid`; and
- any other source attributes that differ between rows sharing the same Comment.

## Current Design Boundary

No dense-RGB renderer rule should be changed from these findings alone.

Evidence order remains:

```text
current Run 50 V7 materialization
        -> raw Run 50 .lorprev source
        -> controller/network configuration only if required
        -> accepted FieldWiring physical-output rule
```

The purpose is to avoid hard-coding a universe-to-output assumption when LOR or the controller configuration may encode a different relationship.

## Related Documents

- [FieldWiring Dense RGB Physical Controller Map — 2026-08-20](FieldWiring_Dense_RGB_Physical_Controller_Map_2026-08-20.md)
- [FieldWiring E1.31 Dense RGB Field Presentation Contract](FieldWiring_E131_Dense_RGB_Field_Presentation_Contract.md)
- [FieldWiring / Controller Inventory Handoff — 2026-08-20](FieldWiring_Controller_Inventory_Handoff_2026-08-20.md)
