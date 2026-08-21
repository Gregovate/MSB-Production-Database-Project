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

The operator supplied the current LOR Prop/channel setup for the Mega Tree and Mega Star. The authoring UI explicitly models the controller-port/string rows used by each PropClass and assigns DMX universe/channel data to those rows.

For the current MSB dense-RGB Displays, controller-output relationships should therefore be recovered from the LOR channel-authoring model wherever the current source supports them. FieldWiring must not discard that information merely because the present V7 materialization does not expose an `Output` field.

This does not make a universe number a permanent physical-controller identity. Permanent hardware identity remains the responsibility of Controller Inventory / `ctrl_id`.

## Operator Authoring Contract — Comment vs Name

The operator confirmed an important authoring rule for the MSB previews:

```text
PropClass.Comment -> Display identity
PropClass.Name    -> operator-authored component / channel configuration identity
```

For dense-RGB Displays, `PropClass.Name` is not merely decorative sequencer text. The operator deliberately creates separate PropClasses for meaningful physical/logical parts of a Display and configures the channel/controller-port rows separately for each part.

Therefore FieldWiring must preserve both levels:

```text
Display
    -> PropClass component
        -> component-local controller-port/string row
            -> universe/channel addressing
```

The current V7 behavior that groups DMX rows by `LORComment` and retains only one canonical master Name is insufficient for this purpose.

### Important ordinal rule

The controller-port/string row number shown inside the LOR Prop editor is **local to that PropClass**. It can restart at `1` for the next component.

Therefore a port ordinal is not meaningful without the source PropClass identity/Name.

For example:

```text
MS Long Spire 1 4x150
    local row 1 -> U113
    local row 2 -> U114
    local row 3 -> U115
    local row 4 -> U116

MS Short Spire 1 2x150
    local row 1 -> U129
    local row 2 -> U130
```

Flattening those rows into one `FT-MegaStar` master without preserving the source component would make both components appear to have a generic row 1/row 2 and destroy the operator-authored structure.

Do not synthesize component Names later from universe ranges. Preserve the source `PropClass.Name` and `RawPropID` from LOR.

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

## Direct LOR UI Evidence — Mega Star

The Mega Star Scene visibly contains separate authored component PropClasses including:

```text
MS Center Hub Back
MS Center Hub Front
MS Long Spire 1 4x150
MS Long Spire 2 4x150
MS Long Spire 3 4x150
MS Long Spire 4 4x150
MS Short Spire 1 2x150
MS Short Spire 2 2x150
MS Short Spire 3 2x150
MS Short Spire 4 2x150
```

The Scene also contains grouping/helper entries such as the Hub groups. Those grouping objects must not be confused with the actual channel-bearing PropClasses.

All of the channel-bearing component PropClasses use:

```text
Comment: FT-MegaStar
```

while their `Name` values distinguish the parts of the Display.

### Center Hub Back

The current LOR editor shows:

```text
Name: MS Center Hub Back
Comment: FT-MegaStar
Device type: DMX
Channel entry mode: Enter a channel on every row
Separate Universe for each RGB string: enabled

local row 1 -> U139, channel 1-450
local row 2 -> U140, channel 1-450
```

This is a custom shape. Its two explicit channel rows are part of the Hub Back component and must remain associated with that exact component Name/RawPropID.

### Long Spire 1

The current LOR editor shows:

```text
Name: MS Long Spire 1 4x150
Comment: FT-MegaStar
Actual # of Controller Ports Used: 4
Exact # of RGB Nodes per Controller Port: 150
Channel entry mode: Enter channel on first row, auto-number the rest
Separate Universe for each RGB string: enabled

local row 1 -> U113, channel 1-450
local row 2 -> U114, channel 1-450
local row 3 -> U115, channel 1-450
local row 4 -> U116, channel 1-450
```

The four displayed controller-port rows correspond directly to the four DMX legs already observed in the raw `.lorprev` for this PropClass.

### Short Spire 1

The current LOR editor shows:

```text
Name: MS Short Spire 1 2x150
Comment: FT-MegaStar
Actual # of Controller Ports Used: 2
Exact # of RGB Nodes per Controller Port: 150
Channel entry mode: Enter channel on first row, auto-number the rest
Separate Universe for each RGB string: enabled

local row 1 -> U129, channel 1-450
local row 2 -> U130, channel 1-450
```

Again, the row ordinal is local to the `MS Short Spire 1 2x150` PropClass. It is not the same semantic object as local row 1 of Long Spire 1 or Hub Back.

### Mega Star source topology preserved by Name

Combining the previously inspected raw Preview with the operator authoring UI gives the current source component structure:

```text
MS Long Spire 1 4x150 -> U113-U116, local rows 1-4
MS Long Spire 2 4x150 -> U117-U120, local rows 1-4
MS Long Spire 3 4x114 -> U121-U124, local rows 1-4
MS Long Spire 4 4x150 -> U125-U128, local rows 1-4

MS Short Spire 1 2x150 -> U129-U130, local rows 1-2
MS Short Spire 2 2x150 -> U131-U132, local rows 1-2
MS Short Spire 3 2x150 -> U133-U134, local rows 1-2
MS Short Spire 4 2x150 -> U135-U136, local rows 1-2

MS Center Hub Front -> U137-U138, local rows 1-2
MS Center Hub Back  -> U139-U140, local rows 1-2
```

This is the FieldWiring-relevant structure that the present Display-level DMX consolidation loses.

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

The current `dmxChannels` schema does not preserve:

```text
source PropClass RawPropID
source PropClass Name
component-local controller-port/output ordinal
```

The current DMX grouping groups source rows by LOR Comment / Display Name, writes one canonical `props` master, and attaches all DMX legs to that master. This preserves universe/channel topology but loses source component Names and source-row distinctions that are required to reconstruct the author's field wiring intent.

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

## Controller Context and Physical Output Number

Current LOR Network Configuration establishes controller universe ranges such as:

```text
Mega Tree Flex 48              U1-U48
Mega Tree Ball PixCon16        U49-U64
Mega Cube Flex 48              U65-U108
Mega Star 1 PixCon16           U113-U128
Mega Star 2 PixCon16           U129-U144
Mt Crumpit / Whoville PixCon16 U147-U162
```

The Prop editor establishes the **component-local controller-port/string row** and the universe/channel assigned to that row.

These are separate facts and must not be conflated:

```text
PropClass Name + local row ordinal
    -> authored component/string relationship

LOR Network Configuration
    -> E1.31 controller context / universe range
```

For the current MSB configuration, the universe ranges and source rows form clean sequential patterns. That makes a physical controller output number potentially derivable for accepted configurations, but the derivation rule must be explicit and tested; the parser must not simply rename every DMX universe as a physical output.

For example, on Mega Star controller 1:

```text
U113-U128 are routed to Mega Star 1 PixCon16
```

while the source components divide that range into four separate Long Spire PropClasses. If an accepted MSB rule maps the first universe in the controller range to physical Output 1 and increments sequentially, then the physical output can be derived. That rule is different from the component-local row ordinal and must remain a separate field/concept.

## AlphaPix Flex 48 Boundary — Revised

The operator confirmed that the two MSB HolidayCoro AlphaPix Flex 48 systems are programmed physically inside the controller and FieldWiring cannot retrieve an internal configuration/export from them.

That remains true.

What changes is the FieldWiring consequence:

- FieldWiring does **not** need to wait for an inaccessible AlphaPix port map;
- LOR already contains the current component/controller-port/string channel setup needed to recover the authored field relationships;
- LOR Network Configuration supplies the controller routing/range context; and
- Controller Inventory supplies permanent physical controller identity and assignment.

Thus the working architecture is:

```text
LOR Prop/channel setup
    -> source PropClass component
    -> component-local controller-port/string row
    -> universe/channel addressing

LOR Network Configuration
    -> controller routing context / universe range

Controller Inventory
    -> permanent ctrl_id / exact model / current assignment

FieldWiring
    -> joins those facts into the field hookup
```

The inaccessible internal AlphaPix programming is not a blocker when the LOR authoring model already expresses the component/output relationships required by FieldWiring.

## Parser / Read-Model Work Now Required

Before changing the parser, define and test the minimum materialization needed to preserve:

```text
Display identity / LOR Comment
source PropClass RawPropID
source component Name
component-local controller-port/string ordinal
DMX universe/channel row
source Preview/run provenance
```

For compact auto-numbered DMX grids, the parser/read model also needs a controlled way to materialize the implied component-local controller-port rows rather than one row per raw semicolon segment only.

Any later physical-controller output number derived from LOR Network Configuration must be a separate resolved value; it must not replace or overwrite the source component-local ordinal.

The current parser's Display-level DMX master may remain useful for Display identity, but it must not destroy the source component/output detail FieldWiring needs.

No PostgreSQL schema design or parser edit is authorized by this finding alone. The next engineering step is to inspect the exact current V7 DMX materialization code and tests, then propose the smallest backward-compatible change.

## Supersession

Where earlier FieldWiring dense-RGB notes say that exact output/port relationships for these Displays must remain unresolved solely because the physical controller's internal mapping cannot be inspected, this finding supersedes that conclusion.

Where earlier discussion treats `PropClass.Name` as expendable after matching to a Display Comment, this finding also supersedes that assumption for dense-RGB FieldWiring. The operator-authored component Name is part of the wiring contract and must be preserved.

The remaining questions are about **recovering and preserving LOR's own component/controller-port/channel model**, then resolving that against the applicable E1.31 controller context without collapsing the two levels.

## Related Documents

- [FieldWiring Dense RGB Controller Port Mapping Boundary — 2026-08-21](FieldWiring_Dense_RGB_Controller_Port_Mapping_Boundary_2026-08-21.md)
- [FieldWiring Dense RGB Raw Preview Component Findings — 2026-08-21](FieldWiring_Dense_RGB_Raw_Preview_Component_Findings_2026-08-21.md)
- [FieldWiring Whoville Matrix CustomGrid Findings — 2026-08-20](FieldWiring_Whoville_Matrix_CustomGrid_Findings_2026-08-20.md)
- [FieldWiring Dense RGB Physical Controller Map — 2026-08-20](FieldWiring_Dense_RGB_Physical_Controller_Map_2026-08-20.md)
- [FieldWiring / Controller Inventory Handoff — 2026-08-20](FieldWiring_Controller_Inventory_Handoff_2026-08-20.md)
