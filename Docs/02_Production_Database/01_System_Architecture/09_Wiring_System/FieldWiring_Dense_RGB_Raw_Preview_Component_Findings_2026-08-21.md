# FieldWiring Dense RGB Raw Preview Component Findings — 2026-08-21

| Item | Value |
|---|---|
| Status | ENGINEERING FINDING — raw live Preview inspection |
| Sub-project | FieldWiring |
| Live source | `2026 Master Musical Preview v6.6.10 2026-08-20.lorprev` |
| Run 50 note | The live source is newer than Run 50 and must not be described as the exact Run 50 source state |
| Schema status | No schema, parser, or renderer change authorized by this finding |

## Purpose

This note records raw Light-O-Rama source evidence for `WA-MegaCube` and `FT-MegaStar` during dense-RGB FieldWiring recovery.

The findings answer a key architecture question: some dense-RGB source structure needed for field presentation is present in the `.lorprev`, but the current DMX materialization consolidates same-Display source rows onto one canonical master and therefore loses source-component names even though the universe/channel legs remain.

The operator-confirmed physical controller map remains separate and controls physical hardware count/model:

```text
Mega Cube -> one physical 48-output AlphaPix controller
Mega Star -> two physical PixCon16 controllers
```

No permanent controller identity is inferred from universe numbers.

## Mega Cube — `WA-MegaCube`

The live Preview contains **three** raw `PropClass` rows sharing the same Display Comment.

### Front

```text
Name: MC Mega Cube Front
DeviceType: DMX
StringType: RGB
IndividualChannels: False
Tag: RGB Matrix 20x40
MaxChannels: 300
SeparateIds: True
ChannelGrid: Regular,73,1,300,2100,
```

Nested shape:

```text
ShapeName: Custom
CustomWidth: 40
CustomHeight: 20
CustomGrid cells: 800
Unique identifiers: 800
Identifier range: 1-800
No missing identifiers
```

### Left

```text
Name: MC Mega Cube Left
DeviceType: DMX
StringType: RGB
IndividualChannels: True
Tag: RGB Matrix 20x40
MaxChannels: 300
SeparateIds: True
ChannelGrid: Regular,65,1,300,2100,
```

Nested shape:

```text
ShapeName: Custom
CustomWidth: 40
CustomHeight: 20
CustomGrid cells: 800
Unique identifiers: 800
Identifier range: 1-800
No missing identifiers
```

### Top

```text
Name: MC Mega Cube Top
DeviceType: DMX
StringType: RGB
IndividualChannels: True
Tag: RGB Matrix 20x40
MaxChannels: 300
SeparateIds: True
ChannelGrid:
  Regular,93,1,300,2100,
  Regular,101,1,300,2100,
```

Nested shape:

```text
ShapeName: Custom
CustomWidth: 40
CustomHeight: 40
CustomGrid cells: 1600
Unique identifiers: 1600
Identifier range: 1-1800
Missing identifier range: 801-1000
Used logical blocks: 1-800 and 1001-1800
```

### Current V7 materialization consequence

The current Run 50 materialization exposes one canonical master Prop named `MC Mega Cube Left` and four DMX legs starting at Universes:

```text
65
73
93
101
```

The raw live Preview proves those four address starts originated from three distinct source components:

```text
Left  -> 65
Front -> 73
Top   -> 93 and 101
```

Therefore the current DMX consolidation preserves address topology but loses the source component labels `Front` and `Top` from the normal materialized master/DMX-leg relationship.

This is a concrete example where the current parser/read model is too Display-centric for ideal dense-RGB field presentation even though the source Preview contains useful component structure.

### Logical section evidence

The raw shapes contain:

```text
Front: 800 pixels
Left:  800 pixels
Top:  1600 pixels
Total: 3200 pixels
```

Arithmetic strongly supports 100-pixel logical sections:

```text
3200 pixels / 100 pixels = 32 logical sections
```

The current four ChannelGrid address starts are also consistent with four 800-pixel logical blocks:

```text
Left  -> one 800-pixel block
Front -> one 800-pixel block
Top   -> two 800-pixel blocks
```

As with the Whoville custom matrix, the repeated fifth ChannelGrid value `2100` remains opaque. The arithmetic `300 + 2100 = 2400 channels = 800 RGB pixels` is compelling but does not authorize redefining that field.

The operator-confirmed physical controller is a 48-output AlphaPix. The source evidence therefore suggests thirty-two 100-pixel-equivalent logical sections are currently used, leaving physical capacity that may be unused or allocated differently. **The exact AlphaPix physical port numbers are not proven by this source inspection.**

## Mega Star — `FT-MegaStar`

The live Preview contains **ten** raw `PropClass` rows sharing the same Display Comment.

### Long spires

Four source components provide sixteen logical DMX legs:

```text
MS Long Spire 1 4x150 -> Universes 113-116
MS Long Spire 2 4x150 -> Universes 117-120
MS Long Spire 3 4x114 -> Universes 121-124
MS Long Spire 4 4x150 -> Universes 125-128
```

The first, second, and fourth long-spire rows use four 450-channel legs each. Long Spire 3 uses four 342-channel legs, matching its source `Parm2=114` rather than 150.

### Short spires

Four source components provide eight logical DMX legs:

```text
MS Short Spire 1 2x150 -> Universes 129-130
MS Short Spire 2 2x150 -> Universes 131-132
MS Short Spire 3 2x150 -> Universes 133-134
MS Short Spire 4 2x150 -> Universes 135-136
```

### Center hubs

Two custom source components provide four additional DMX legs:

```text
MS Center Hub Front -> Universes 137-138
MS Center Hub Back  -> Universes 139-140
```

Each hub PropClass contains a custom `19 x 19` shape with 361 cells and 301 unique values including zero placeholders. The used numbering includes low values and a second block beginning above 1000; these custom shapes are source geometry and should not be mechanically converted into physical port identity without further review.

### Total source topology

The raw Preview therefore contains:

```text
16 long-spire legs
 8 short-spire legs
 4 center-hub legs
-------------------
28 DMX legs total
```

This exactly matches the 28 current V7 DMX legs exposed for `FT-MegaStar` at Universes 113-140.

### Current V7 materialization consequence

The current materialization chooses the smallest-address source row as the canonical master:

```text
MS Long Spire 1 4x150
```

and attaches all twenty-eight DMX legs to that master. The universe/channel topology survives, but the other nine source component Names are lost from the normal Display-level DMX wiring rows.

This proves the parser is flattening field-useful component names for Mega Star.

## Mega Star physical-controller split

Operator-confirmed physical configuration:

```text
Mega Star -> two physical PixCon16 controllers
```

The live Preview presents a very strong candidate split:

```text
Universes 113-128 -> 16 logical legs
Universes 129-140 -> 12 logical legs
```

This aligns naturally with two PixCon16 controllers:

```text
controller context 1 -> 16 used outputs
controller context 2 -> 12 used outputs, 4 outputs potentially unused
```

However, this raw Preview evidence does **not by itself prove** that physical PixCon controller 1 owns Universes 113-128 or that controller 2 owns 129-140, nor does it prove that physical Output N equals the Nth universe in each block. Those physical-port relationships still require reviewed controller/network configuration or the future Controller Inventory current-assignment resolver.

## Dense-RGB problem categories now established

The investigation now exposes at least three distinct dense-RGB source patterns.

### 1. Simple one-leg-per-string source

Examples:

```text
Mega Tree
Mega Ball
```

LOR/V7 already preserves one clean DMX leg per logical string/ribbon.

### 2. Source-rich but parser-flattened Display

Examples:

```text
Mega Cube
Mega Star
```

The live Preview contains meaningful component Names and separate ChannelGrid rows, but the current DMX consolidation collapses them onto one canonical Display master. Address topology survives; source-component labels do not.

### 3. Custom-grid source without physical-port identity

Example:

```text
Whoville Matrix
```

The Preview contains the complete custom pixel topology and DMX address blocks, but not explicit PixCon16 physical port assignments.

These categories must not be forced into one universal dense-RGB derivation rule.

## Parser / read-model implication

The current parser behavior is not necessarily wrong for Display-level identity, but it is insufficient for ideal dense-RGB field presentation where the source component Name is useful.

A future controlled change may need to preserve, in some form, the source DMX component/leg identity such as:

```text
Display identity
source PropClass identity
source component Name
ChannelGrid leg / universe-channel topology
```

That possibility must be discussed separately. This finding does **not** authorize a parser schema change, PostgreSQL schema change, or re-ingest.

FieldWiring must also remain compatible with the Controller Inventory return handoff: source component structure from LOR and permanent physical controller `ctrl_id` / current port assignment are separate layers.

## Current evidence boundary

```text
LOR live Preview
    -> Display/component/string geometry and DMX/E1.31 addressing

Current V7 materialization
    -> Display-level consolidated topology

Controller/network configuration / Controller Inventory
    -> permanent physical controller identity and exact physical port assignment
```

FieldWiring should combine these layers without pretending any one of them contains all controller facts.

## Related Documents

- [FieldWiring Dense RGB Run 50 Topology Findings — 2026-08-20](FieldWiring_Dense_RGB_Run50_Topology_Findings_2026-08-20.md)
- [FieldWiring Dense RGB Live Preview / Run 50 Source-Drift Boundary — 2026-08-20](FieldWiring_Dense_RGB_Live_Preview_Source_Drift_2026-08-20.md)
- [FieldWiring Whoville Matrix CustomGrid Findings — 2026-08-20](FieldWiring_Whoville_Matrix_CustomGrid_Findings_2026-08-20.md)
- [FieldWiring Dense RGB Physical Controller Map — 2026-08-20](FieldWiring_Dense_RGB_Physical_Controller_Map_2026-08-20.md)
- [FieldWiring / Controller Inventory Handoff — 2026-08-20](FieldWiring_Controller_Inventory_Handoff_2026-08-20.md)
