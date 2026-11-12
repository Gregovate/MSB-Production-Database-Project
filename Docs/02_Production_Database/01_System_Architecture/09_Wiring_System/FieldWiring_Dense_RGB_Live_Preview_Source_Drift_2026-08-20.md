# FieldWiring Dense RGB Live Preview / Run 50 Source-Drift Boundary — 2026-08-20

| Item | Value |
|---|---|
| Status | ENGINEERING FINDING — source comparison in progress |
| Sub-project | FieldWiring |
| Run 50 source filename | `2026 Master Musical Preview v6.6.10 2026-08-11.lorprev` |
| Current live source filename | `2026 Master Musical Preview v6.6.10 2026-08-20.lorprev` |
| Schema status | No schema, parser, or renderer change authorized by this finding |

## Purpose

This record prevents the current live Master Musical Preview from being silently treated as though it were the exact source file used to create Run 50.

Run 50 provenance records the August 11 Master Musical Preview. The live Preview has since advanced to the August 20 file and contains known operator edits, including the Candyland Candy Cane 12 correction from Unit ID `22` to `24` plus other current authoring changes.

Therefore:

- Run 50 remains the authority for the current FieldWiring development snapshot being accepted;
- the August 20 Preview is current live source evidence;
- structural evidence from the August 20 Preview may be used to understand how LOR represents dense RGB, but it must not be described as proof of the exact Run 50 source state unless the relevant object is shown to match; and
- no Run 50 provenance record should be rewritten merely because the live Preview filename advanced after the run.

## Whoville Matrix — Current Live Preview Inspection

The August 20 live Preview contains exactly one raw `PropClass` for:

```text
Comment: WV-WhoMatrix
Name: Who Mt Crumpet RGB Pixel Matrix
DeviceType: DMX
StringType: RGB
IndividualChannels: False
Tag: RGB Matrix 20x40
```

Its raw `ChannelGrid` is:

```text
Regular,147,1,300,2100,Red;Regular,155,1,300,2100,
```

This matches the current Run 50 materialized shape of two DMX legs beginning at Universes `147` and `155`.

### Consequence

For Whoville Matrix, the parser is not hiding multiple same-Display raw `PropClass` rows carrying per-string/output names. The current live Preview itself exposes one Display-level PropClass with two DMX grid legs.

The operator-confirmed physical configuration is one PixCon16 controller, but the raw Preview evidence inspected so far does **not** expose the sixteen physical PixCon output/port assignments.

The final physical output mapping must therefore come from another authoritative relationship if it is needed by FieldWiring, such as reviewed controller/network configuration or the future Controller Inventory current-assignment resolver.

## Opaque ChannelGrid Value

The repeated ChannelGrid value `2100` remains an opaque LOR field in the current parser contract. It must not be interpreted as a pixel count, channel count, output number, universe span, or controller capability until authoritative evidence establishes its meaning.

## Current Evidence Boundary

The dense-RGB investigation now distinguishes three layers:

```text
Run 50 FieldWiring snapshot
    -> current accepted browser-test data

August 20 live Master Musical Preview
    -> current LOR source structure after known edits

Controller/network configuration / Controller Inventory
    -> physical controller/output facts not represented by LOR Preview data
```

FieldWiring must not merge these layers silently.

## Next Inspection Targets

Continue raw live-Preview inspection for:

```text
WA-MegaCube
FT-MegaStar
TR-MegaTreeRGBTree
TR-MegaTreeRGBBall
```

The highest-priority questions are:

1. Does Mega Cube contain multiple raw PropClass rows sharing `Comment=WA-MegaCube`, which Run 50 consolidation flattened?
2. Does Mega Star contain multiple raw PropClass rows sharing `Comment=FT-MegaStar`, and if so what Names/ChannelGrid ranges distinguish them?
3. Do Mega Tree and Mega Ball confirm one clean raw PropClass whose ChannelGrid directly contains the 48 and 16 one-string-per-universe legs already visible in Run 50?

No renderer change should be made until those questions are answered.

## Related Documents

- [FieldWiring Dense RGB Run 50 Topology Findings — 2026-08-20](FieldWiring_Dense_RGB_Run50_Topology_Findings_2026-08-20.md)
- [FieldWiring Dense RGB Physical Controller Map — 2026-08-20](FieldWiring_Dense_RGB_Physical_Controller_Map_2026-08-20.md)
- [FieldWiring / Controller Inventory Handoff — 2026-08-20](FieldWiring_Controller_Inventory_Handoff_2026-08-20.md)
