# FieldWiring DMX Table Purpose and Field Assembly Boundary — 2026-08-21

| Item | Value |
|---|---|
| Status | OPERATOR-CONFIRMED ENGINEERING FINDING |
| Sub-project | FieldWiring |
| Scope | DMX parser materialization vs field-installation presentation |
| Schema status | Parser DMX schema extension is allowed for design/review; no implementation committed by this finding |

## Purpose

This record preserves the original reason the parser carries DMX channels separately from ordinary LOR physical wiring and clarifies how FieldWiring should consume that data.

The DMX channel materialization must preserve the complete technical and physical connection topology needed to understand and, if necessary, rebuild dense-RGB Displays. A connection being permanently wired or already assembled before the Display reaches the park does **not** make that wiring disposable or irrelevant to FieldWiring.

The separate question is whether the park setup crew must make that connection during normal installation.

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

The operator originally carried DMX channels in a separate parser table because dense-RGB/E1.31 channel topology is technically important but does not behave the same as ordinary LOR field wiring.

Much of the DMX wiring is built into a Display or completed before the Display reaches the park. Other DMX Displays require substantial assembly and connection work in the park. The parser therefore needs to preserve all DMX topology without assuming that every channel row represents a park-install action.

The separate DMX table is an intentional boundary between:

```text
complete LOR DMX / dense-RGB connection topology
```

and

```text
how those connections are presented and acted on during park setup
```

The first must always be retained. The second depends on the physical installation method of the Display.

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

## Park Installation Action Is Not a Parser Fact

Whether a DMX/output relationship is physically connected during normal park setup is **not** a fact the LOR parser should invent or encode from channel data.

The parser should preserve the complete technical and physical connection topology consistently.

FieldWiring should then distinguish between:

```text
connection exists / how it is wired
```

and

```text
what the setup crew must do with that connection today
```

A prewired connection must remain visible and reconstructable in FieldWiring even when the normal setup action is simply `PREWIRED / NO PARK CONNECTION REQUIRED` or an equivalent presentation state.

The operator supplied the following current field-assembly distinctions.

### Mega Tree

```text
Controller: HolidayCoro AlphaPix Flex 48-output system
Field condition: 48 ribbons are installed/connected as part of park setup
```

FieldWiring needs the complete LOR controller-port/ribbon relationships because volunteers make these connections in the park.

### Mega Star

```text
Display: FT-MegaStar
Controller(s): built into the standalone Display
Field condition: completely standalone / internal controller wiring is already completed
```

The detailed DMX topology is still part of FieldWiring. It must remain available so an engineer can understand, troubleshoot, repair, or reconstruct the physical connections between the built-in controller outputs and the Hub/Spire components.

The difference is only that those connections are normally **already made before park setup**. The standard setup presentation should not instruct volunteers to disconnect and reconnect all internal outputs, but it must not hide or discard the wiring map.

### Mega Cube

```text
Controller: HolidayCoro AlphaPix Flex 48-output system
Field condition: Display is assembled in the park
```

FieldWiring needs the complete component-aware DMX/output information, and much of it is directly field-actionable because park assembly requires meaningful connection guidance.

### Mt. Crumpit / Whoville Matrix

```text
Controller: attached to the Display
Field condition: permanently wired
```

Its DMX/custom-grid output topology remains part of the physical wiring record and must remain available in FieldWiring so the matrix can be diagnosed, repaired, or reconstructed correctly.

During ordinary park setup the internal controller-to-matrix connections are already complete, so the presentation should identify them as prewired rather than presenting them as new park hookup tasks.

### Open/Close Sign — New 2026

```text
Controller context: PixCon16
Status: new 2026; not installed yet
Expected field condition: likely assembled/connected to the controller in the park
```

This should remain provisional until the actual installation method is confirmed. Regardless of the final installation method, its DMX/output topology must remain preserved; only the normal setup action/presentation changes.

## Items Not Classified by This Finding

This finding does not assign a field-installation action to every E1.31/DMX Display.

In particular, do not infer the installation behavior of Mega Ball, Gift Conveyor, Northern Lights, or other DMX/E1.31 contexts from this note unless separately confirmed.

Their physical wiring topology must still be preserved.

## FieldWiring Presentation Rule

FieldWiring should separate two concepts without hiding either one:

```text
Physical wiring topology
    -> what connects to what
    -> always retained and available

Installation action
    -> whether that connection must be made in the park
    -> examples: CONNECT IN PARK / PREWIRED / VERIFY-REFERENCE
```

The exact status vocabulary is not yet controlled by this finding, but the concept is required.

A dense-RGB Display such as Mega Star or Mt. Crumpit may therefore show a complete controller-output/component wiring map while also making clear that the connections are normally prewired and require no park hookup action.

A Display such as Mega Tree or Mega Cube can use the same underlying wiring data while emphasizing the connections that must actually be made during installation.

FieldWiring must not equate `not normally connected in the park` with `do not show the wiring`.

This distinction is one of the reasons the DMX table should not simply be merged into the traditional LOR physical-wiring model.

## Controller Inventory Boundary

Controller Inventory continues to supply permanent physical controller identity and current assignment.

It must not replace the LOR DMX component/channel structure, and the parser must not manufacture multiple controller or Display identities from component/channel rows.

The combined model is:

```text
LOR / parser DMX table
    -> complete current Display/component/channel/output topology

Controller Inventory
    -> permanent ctrl_id / model / current assignment

Display/setup context
    -> installation action: park-connected vs prewired vs other reviewed state

FieldWiring
    -> always retains the wiring map
    -> presents the appropriate setup action without hiding the underlying connection
```

## Next Engineering Step

Before code changes:

1. inspect the current V7 DMX insertion/grouping code and current tests;
2. define the smallest backward-compatible `dmxChannels` schema extension that preserves source PropClass identity/Name and component-local row context;
3. validate compact auto-numbered ChannelGrid behavior against representative LOR UI/source examples;
4. decide whether expanded controller-port rows belong directly in `dmxChannels` or in a derived parser view while preserving raw-leg evidence; and
5. only then implement and generate a new parser/development snapshot for FieldWiring acceptance.

Do not alter `ref.display` identity as part of this work.

Do not add a park-installation-action field to the parser DMX table merely to drive presentation. The parser owns topology; the installation action belongs to reviewed Display/setup/FieldWiring context.

## Related Documents

- [FieldWiring Dense RGB LOR Controller-Port Recovery — 2026-08-21](FieldWiring_Dense_RGB_LOR_Controller_Port_Recovery_2026-08-21.md)
- [FieldWiring Dense RGB Raw Preview Component Findings — 2026-08-21](FieldWiring_Dense_RGB_Raw_Preview_Component_Findings_2026-08-21.md)
- [FieldWiring Dense RGB Controller Port Mapping Boundary — 2026-08-21](FieldWiring_Dense_RGB_Controller_Port_Mapping_Boundary_2026-08-21.md)
- [FieldWiring Dense RGB Physical Controller Map — 2026-08-20](FieldWiring_Dense_RGB_Physical_Controller_Map_2026-08-20.md)
