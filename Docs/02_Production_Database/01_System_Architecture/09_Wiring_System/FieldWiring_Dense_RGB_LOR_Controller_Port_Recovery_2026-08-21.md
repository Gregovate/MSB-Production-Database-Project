# FieldWiring Dense RGB LOR Controller-Port Recovery — 2026-08-21

| Item | Value |
|---|---|
| Status | OPERATOR-CONFIRMED ENGINEERING FINDING |
| Sub-project | FieldWiring |
| Source | Current LOR 6.6.10 Prop/channel authoring UI plus live `.lorprev` evidence |
| Scope | Dense RGB / DMX controller-output recovery |
| Schema status | No schema, parser, ingest, or renderer change authorized by this finding |

## Purpose

This finding corrects the earlier recovery assumption that exact dense-RGB controller outputs were necessarily unavailable from Light-O-Rama and had to remain unresolved until controller-internal configuration could be inspected.

The operator supplied the current LOR Prop/channel setup for the Mega Tree. The authoring UI explicitly models the physical/logical controller-port rows used by the prop and assigns DMX universe/channel data to each row.

For the current MSB dense-RGB Displays, controller output relationships should therefore be recovered from the LOR channel-authoring model wherever the current source supports them. FieldWiring must not discard that information merely because the present V7 materialization does not expose an `Output` field.

This does not make a universe number a permanent physical-controller identity. Permanent hardware identity remains the responsibility of Controller Inventory / `ctrl_id`.

## Direct LOR UI Evidence — Mega Tree

Current Mega Tree Prop:

```text
Name: MT Mega Tree RGB Tree 48 x 100-360
Comment: TR-MegaTreeRGBTree
Device type: DMX
Actual # of Controller Ports Used: 48
Exact # of RGB Nodes per Controller Port: 100
Separate Universe for each RGB string: enabled
Max channels per Universe: 512
```

The LOR channel table is indexed by controller-port/string row. The visible portion directly shows:

```text
Port/row 33 -> Start Universe 33 -> channels 1-300
Port/row 34 -> Start Universe 34 -> channels 1-300
...
Port/row 48 -> Start Universe 48 -> channels 1-300
```

The graphical prop also labels the 48 controller-port/string positions `1` through `48`.

Therefore, for this prop, LOR directly establishes the controller-output/string row and its DMX addressing. This is not an inference from controller IP or from a separate workbook.

The raw live `.lorprev` independently contains 48 `ChannelGrid` entries at Universes 1-48, each channels 1-300. The raw order is consistent with the 48 LOR controller-port rows.

## Current V7 Loss

The current V7 parser documentation and implementation treat DMX `ChannelGrid` semicolon-delimited entries as `dmxChannels` legs and store:

```text
PropId
Network
StartUniverse
StartChannel
EndChannel
Unknown
PreviewId
```

The current `dmxChannels` schema does not preserve a controller-port/output ordinal.

The current DMX grouping also groups source rows by LOR Comment / Display Name, writes one canonical `props` master, and attaches all DMX legs to that master. This preserves universe/channel topology but can lose source component Names and source-row distinctions that are useful to FieldWiring.

Therefore the current limitation is primarily a **parser/read-model materialization gap**, not a lack of LOR source information.

## Compact / Auto-Numbered ChannelGrid Evidence

Some custom props do not serialize one semicolon entry per visible controller-port row.

Examples already inspected:

```text
Mega Cube Left:
  Regular,65,1,300,2100,
  custom grid = 800 pixels

Mega Cube Front:
  Regular,73,1,300,2100,
  custom grid = 800 pixels

Mega Cube Top:
  Regular,93,1,300,2100,;
  Regular,101,1,300,2100,
  custom grid = 1600 pixels

Whoville Matrix:
  Regular,147,1,300,2100,Red;
  Regular,155,1,300,2100,
  custom grid = 1600 pixels
```

The LOR authoring UI exposes the relevant channel mode as:

```text
Enter channel on first row, auto-number the rest
Separate Universe for each RGB string
```

For the observed 100-node-per-port pattern:

```text
100 RGB pixels × 3 channels = 300 channels per controller port
```

and the compact raw value gives:

```text
300 + 2100 = 2400 channels
2400 / 300 = 8 controller-port rows
```

This is strongly consistent with each `...,300,2100,...` segment representing one explicitly stored first row plus seven auto-numbered 300-channel rows, i.e. eight controller-port rows total.

This interpretation matches the already observed geometry:

```text
800-pixel custom block  -> 8 × 100-pixel controller-port rows
1600-pixel custom block -> 2 × 8 rows -> 16 controller-port rows
```

### Important precision

This finding does **not** redefine the fifth raw `ChannelGrid` field (`2100`) as a universal schema meaning for all LOR props. The current parser still calls it `Unknown`, and the repository does not have an official LOR file-format contract for that field.

The recovery implementation must validate the expansion rule against representative current LOR authoring examples before changing parser-wide semantics.

For the current dense-RGB cases, however, the UI behavior plus the raw arithmetic provides a concrete, testable route to recover the controller-port rows instead of treating the compact entry as one physical output.

## Controller Context and Output Number

Current LOR Network Configuration establishes the relevant controller universe ranges:

```text
Mega Tree Flex 48              U1-U48
Mega Tree Ball PixCon16        U49-U64
Mega Cube Flex 48              U65-U108
Mega Star 1 PixCon16           U113-U128
Mega Star 2 PixCon16           U129-U144
Mt Crumpit / Whoville PixCon16 U147-U162
```

For the inspected current props, each physical/logical output string uses at most one DMX universe and `Separate Universe for each RGB string` is the operative LOR channel model.

This supports recovering output rows from the LOR channel setup rather than from inaccessible AlphaPix internals.

Examples supported by current evidence:

```text
Mega Tree:
  Outputs 1-48 -> U1-U48

Mega Ball:
  16 logical output rows -> U49-U64

Mega Star controller 1:
  16 output rows -> U113-U128

Mega Star controller 2:
  12 currently used rows -> U129-U140
  U141-U144 have no currently identified Mega Star source legs

Whoville Matrix:
  two compact 800-pixel blocks beginning U147 and U155
  -> 16 × 100-pixel output rows across U147-U162
```

Mega Cube requires component-aware expansion because the source contains multiple PropClasses and gaps within the controller universe range:

```text
Left  -> block beginning U65
Front -> block beginning U73
Top   -> blocks beginning U93 and U101
```

Do not label the unexplained U81-U92 range as unused until all current source props using the Mega Cube controller context have been checked.

## AlphaPix Flex 48 Boundary — Revised

The operator confirmed that the two MSB HolidayCoro AlphaPix Flex 48 systems are programmed physically inside the controller and FieldWiring cannot retrieve an internal configuration/export from them.

That remains true.

What changes is the FieldWiring consequence:

- FieldWiring does **not** need to wait for an inaccessible AlphaPix port map;
- LOR already contains the current controller-port/string channel setup needed to recover the field output relationships for these authored props;
- LOR Network Configuration supplies the controller routing/range context; and
- Controller Inventory supplies permanent physical controller identity and assignment.

Thus the working architecture is:

```text
LOR Prop/channel setup
    -> controller-port/string row
    -> universe/channel addressing

LOR Network Configuration
    -> controller routing context / universe range

Controller Inventory
    -> permanent ctrl_id / exact model / current assignment

FieldWiring
    -> joins those facts into the field hookup
```

The inaccessible internal AlphaPix programming is not a blocker when the LOR authoring model already expresses the output relationships required by FieldWiring.

## Parser / Read-Model Work Now Required

Before changing the parser, define and test the minimum materialization needed to preserve:

```text
Display identity / LOR Comment
source PropClass RawPropID
source component Name
controller-port/output ordinal
DMX universe/channel row
source Preview/run provenance
```

For compact auto-numbered DMX grids, the parser/read model also needs a controlled way to materialize the implied controller-port rows rather than one row per raw semicolon segment only.

The current parser's Display-level DMX master may remain useful, but it must not destroy the source component/output detail FieldWiring needs.

No PostgreSQL schema design or parser edit is authorized by this finding alone. The next engineering step is to inspect the exact current V7 DMX materialization code and tests, then propose the smallest backward-compatible change.

## Supersession

Where earlier FieldWiring dense-RGB notes say that exact output/port relationships for these Displays must remain unresolved solely because the physical controller's internal mapping cannot be inspected, this finding supersedes that conclusion.

The remaining questions are about **recovering and preserving LOR's own controller-port/channel model**, not obtaining an AlphaPix Flex 48 configuration export.

## Related Documents

- [FieldWiring Dense RGB Controller Port Mapping Boundary — 2026-08-21](FieldWiring_Dense_RGB_Controller_Port_Mapping_Boundary_2026-08-21.md)
- [FieldWiring Dense RGB Raw Preview Component Findings — 2026-08-21](FieldWiring_Dense_RGB_Raw_Preview_Component_Findings_2026-08-21.md)
- [FieldWiring Whoville Matrix CustomGrid Findings — 2026-08-20](FieldWiring_Whoville_Matrix_CustomGrid_Findings_2026-08-20.md)
- [FieldWiring Dense RGB Physical Controller Map — 2026-08-20](FieldWiring_Dense_RGB_Physical_Controller_Map_2026-08-20.md)
- [FieldWiring / Controller Inventory Handoff — 2026-08-20](FieldWiring_Controller_Inventory_Handoff_2026-08-20.md)
