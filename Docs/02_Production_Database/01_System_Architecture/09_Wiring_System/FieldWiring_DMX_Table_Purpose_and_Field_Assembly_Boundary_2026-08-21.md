# FieldWiring DMX Table Purpose and Field Assembly Boundary — 2026-08-21

| Item | Value |
|---|---|
| Status | OPERATOR-CONFIRMED ENGINEERING FINDING |
| Sub-project | FieldWiring |
| Scope | DMX parser materialization vs field-installation presentation |
| Schema status | Parser DMX schema extension is allowed for design/review; no implementation committed by this finding |

## Purpose

This record preserves the original reason the parser carries DMX channels separately from ordinary LOR physical wiring and clarifies how FieldWiring should consume that data.

The DMX channel materialization must preserve the technical LOR topology needed to understand dense-RGB Displays without forcing internal/prewired pixel wiring into normal park hookup instructions.

## Display Identity Boundary

A dense-RGB Display remains one `ref.display` identity even when its LOR authoring contains many channel-bearing PropClasses.

Example:

```text
FT-MegaStar = one Display
```

Its component PropClasses such as:

```text
MS Center Hub Back
MS Center Hub Front
MS Long Spire 1 4x150
MS Short Spire 1 2x150
...
```

must **not** become separate `ref.display` rows merely because each component has its own channel setup.

The intended hierarchy is:

```text
ref.display / LOR Comment
    -> source PropClass component / Name
        -> component-local channel/controller-port rows
            -> universe/channel addressing
```

`PropClass.Comment` continues to bind the one Display identity. `PropClass.Name` preserves the operator-authored component/channel configuration identity.

## Why DMX Is Separate in the Parser

The operator originally carried DMX channels in a separate parser table for two reasons:

1. Dense-RGB/E1.31 channel topology is technically important and must be preserved.
2. Much of that wiring is internal to a Display and is already wired to a controller before the Display reaches the park, so it should not automatically appear as ordinary physical field wiring.

The separate DMX table is therefore not an accidental side table. It is an intentional boundary between:

```text
LOR technical channel topology
```

and

```text
field connections volunteers actually need to make
```

The parser may be changed to retain additional DMX source information when required. The DMX table remains the correct parser-owned place for that source detail.

## Current Parser Grain

The current V7 `dmxChannels` materialization preserves the Display-level master relationship and raw DMX legs with fields equivalent to:

```text
IntDMXChannelID
PropId
Network
StartUniverse
StartChannel
EndChannel
Unknown
PreviewId
```

Current DMX grouping uses LOR Comment / Display identity, selects one canonical `props` master, and attaches all DMX legs from same-Display source PropClasses to that master.

That behavior preserves universe/channel topology but currently loses source-component information required by FieldWiring, including:

- source `PropClass.RawPropID`;
- source `PropClass.Name`;
- source ChannelGrid segment/order; and
- component-local controller-port/string ordinal.

## Minimum DMX Source Detail That Must Survive

The parser/read model should be able to retain, at minimum:

```text
Display/master PropId
source PropClass RawPropID
source PropClass Name
raw ChannelGrid segment ordinal
component-local controller-port/string ordinal or range
Network
StartUniverse
StartChannel
EndChannel
existing raw/opaque ChannelGrid value(s)
PreviewId / provenance
```

This does not require changing the one-Display identity model.

### Backward-compatible design direction

The preferred design direction is to preserve the current raw DMX-leg grain where practical and add enough source metadata to reconstruct the authored output rows, rather than destroying current semantics merely to create a flattened physical-wiring table.

For compact/auto-numbered LOR rows, a raw segment may represent more than one visible component-local controller-port row. The DMX materialization may therefore need fields such as a starting component-local row and row count, or an equivalent controlled representation, so a downstream view can expand the authored rows without losing the original raw ChannelGrid evidence.

Exact field names and expansion semantics still require code/test review before implementation.

## Field Assembly Is Not a Parser Fact

Whether a DMX/output relationship should appear in normal FieldWiring instructions depends on how the Display is assembled in the park. That is **not** a fact the LOR parser should invent or encode from channel data.

The parser should preserve the technical channel topology consistently. FieldWiring presentation should decide which parts are field-actionable based on reviewed Display/setup context.

The operator supplied the following current field-assembly distinctions.

### Mega Tree

```text
Controller: HolidayCoro AlphaPix Flex 48-output system
Field condition: 48 ribbons are installed/connected as part of park setup
```

This is an exception to the general prewired-DMX pattern. FieldWiring needs the LOR controller-port/ribbon relationships because volunteers make these connections in the park.

### Mega Star

```text
Display: FT-MegaStar
Controller(s): built into the standalone Display
Field condition: completely standalone / internal controller wiring
```

The detailed DMX topology remains valuable engineering data, but it should not automatically become a long list of park plug-in instructions when those internal connections are not made during setup.

### Mega Cube

```text
Controller: HolidayCoro AlphaPix Flex 48-output system
Field condition: Display is assembled in the park
```

FieldWiring needs component-aware DMX/output information because park assembly requires meaningful connection guidance.

### Mt. Crumpit / Whoville Matrix

```text
Controller: attached to the Display
Field condition: permanently wired
```

Its DMX/custom-grid topology remains engineering evidence. Normal FieldWiring should not imply that volunteers must reconnect every internal matrix output during park setup.

### Open/Close Sign — New 2026

```text
Controller context: PixCon16
Status: new 2026; not installed yet
Expected field condition: likely assembled/connected to the controller in the park
```

This should remain provisional until the actual installation method is confirmed. If park assembly is required, FieldWiring will need to surface the applicable DMX/output relationships.

## Items Not Classified by This Finding

This finding does not assign a field-installation status to every E1.31/DMX Display.

In particular, do not infer the installation behavior of Mega Ball, Gift Conveyor, Northern Lights, or other DMX/E1.31 contexts from this note unless separately confirmed.

## FieldWiring Presentation Rule

FieldWiring should separate two concepts:

```text
Engineering topology
    -> always recoverable/inspectable when needed

Field hookup
    -> only connections that the setup crew actually makes in the park
```

A dense-RGB Display may therefore have rich DMX engineering detail while showing only a small number of normal field actions — or none — when the controller and internal outputs are permanently built into the Display.

This distinction is one of the reasons the DMX table should not simply be merged into the traditional LOR physical-wiring model.

## Controller Inventory Boundary

Controller Inventory continues to supply permanent physical controller identity and current assignment.

It must not replace the LOR DMX component/channel structure, and the parser must not manufacture multiple controller or Display identities from component/channel rows.

The combined model is:

```text
LOR / parser DMX table
    -> current Display/component/channel topology

Controller Inventory
    -> permanent ctrl_id / model / current assignment

Display/setup context
    -> whether the connection is field-actionable

FieldWiring
    -> presents the appropriate field hookup while retaining engineering detail
```

## Next Engineering Step

Before code changes:

1. inspect the current V7 DMX insertion/grouping code and current tests;
2. define the smallest backward-compatible `dmxChannels` schema extension that preserves source PropClass identity/Name and component-local row context;
3. validate compact auto-numbered ChannelGrid behavior against representative LOR UI/source examples;
4. decide whether expanded controller-port rows belong directly in `dmxChannels` or in a derived parser view while preserving raw-leg evidence; and
5. only then implement and generate a new parser/development snapshot for FieldWiring acceptance.

Do not alter `ref.display` identity as part of this work.

## Related Documents

- [FieldWiring Dense RGB LOR Controller-Port Recovery — 2026-08-21](FieldWiring_Dense_RGB_LOR_Controller_Port_Recovery_2026-08-21.md)
- [FieldWiring Dense RGB Raw Preview Component Findings — 2026-08-21](FieldWiring_Dense_RGB_Raw_Preview_Component_Findings_2026-08-21.md)
- [FieldWiring Dense RGB Controller Port Mapping Boundary — 2026-08-21](FieldWiring_Dense_RGB_Controller_Port_Mapping_Boundary_2026-08-21.md)
- [FieldWiring Dense RGB Physical Controller Map — 2026-08-20](FieldWiring_Dense_RGB_Physical_Controller_Map_2026-08-20.md)
