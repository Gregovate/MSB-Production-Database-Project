# FieldWiring Dense RGB DMX Parser Extension Checkpoint — 2026-08-21

| Item | Value |
|---|---|
| Status | INSPECTION COMPLETE — NO PARSER CODE CHANGE YET |
| Sub-project | FieldWiring / Engineering Recovery |
| Branch | `agent/fieldwiring-engineering-recovery` |
| Parser baseline | V7.0.10 |
| Purpose | Freeze the accepted additive-only DMX extension boundary and preserve the completed dependency inspection before implementation |

## Why This Checkpoint Exists

Dense-RGB recovery reached the point where a parser schema extension is required to preserve source wiring detail. Implementation must not proceed from conversational memory alone because the existing V7 parser, PostgreSQL ingest, identity model, FormView compatibility, and FieldWiring read model are tightly coupled.

This document remains the durable handoff for the extension boundary.

The dependency inspection requested by the original checkpoint is now complete. The exact proposed additive change is documented in:

- [FieldWiring Dense RGB DMX Additive Change Map](FieldWiring_Dense_RGB_DMX_Additive_Change_Map_2026-08-21.md)

The controlled XML-to-MSB terminology is documented in:

- [LOR XML to MSB Terminology Contract](../../../01_LOR_System/02_Data_Extraction/LOR_XML_to_MSB_Terminology_Contract.md)

No V7.0.10 parser code or schema has been changed yet.

## Accepted Identity Chain — Must Not Change

The current V7 parser deliberately uses preview-scoped composite IDs because raw LOR PropClass UUIDs can be reused across previews.

```text
V7 SQLite parser
    props.PropID / subProps keys
        = PreviewId:RawPropID
        = parser-local preview-scoped composite identity

PostgreSQL ingest
    ref.display.display_id
        = permanent MSB Display identity

    ref.display.lor_prop_id
        = raw LOR PropClass UUID binding
        = NOT the V7 composite parser key
```

Do not redesign this chain as part of dense-RGB recovery.

## Existing `dmxChannels` Contract — Preserve It

Current table fields:

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

`dmxChannels.PropId` currently participates in established parser/downstream relationships. For grouped DMX Displays it points to the canonical/materialized Display master composite `PropID`.

That behavior must remain unchanged unless a separate architecture review proves a defect.

The accepted implementation direction remains **additive only**: extend `dmxChannels` with source wiring provenance while leaving every existing column, value, join, key behavior, and downstream relationship intact.

## Problem Being Fixed

LOR dense-RGB authoring contains more wiring detail than current V7 DMX materialization preserves.

Controlled terminology:

```text
PropClass.Comment -> Display Name
PropClass.Name    -> Channel Name
PropClass.id      -> LOR Prop ID
PropClass.ChannelGrid -> Channel Grid
```

Current grouped-DMX processing preserves the Display/master relationship but can discard which original PropClass/Channel Name authored each DMX Channel Grid Row.

This is especially damaging for Displays such as Mega Star and Mega Cube, where multiple channel-bearing PropClasses share the same Display Name but have distinct Channel Names and local Channel Grid Rows.

## Minimum Information the Extension Must Preserve

The implementation must preserve enough source information to answer:

```text
Which materialized Display/master does this DMX relationship belong to?
Which original LOR PropClass supplied it?
What was that PropClass's Channel Name?
Which Channel Grid Row within that PropClass supplied it?
What universe/channel addressing did LOR assign?
```

### Original checkpoint candidate terminology — superseded

The original checkpoint used temporary engineering names:

```text
SourcePropId
SourceName
SourceGridOrdinal
```

Those names were intentionally marked non-final. They are now superseded by the controlled XML/MSB terminology established during the dependency inspection.

### Controlled proposed field names after inspection

The exact proposed additive SQLite fields are:

```text
RawPropID
    -> originating LOR Prop ID (`PropClass.id`)

ChannelName
    -> originating Channel Name (`PropClass.Name`)

ChannelGridRowNumber
    -> 1-based position of the serialized Channel Grid Row within that source PropClass
```

`dmxChannels.PreviewId` already exists, so:

```text
PreviewId + RawPropID
```

identifies the originating source PropClass within the parser snapshot. A second synthetic preview-scoped source-ID field is not required.

Do not add a foreign key from the new DMX `RawPropID` to `props`. Grouped DMX source PropClasses can legitimately supply wiring rows without becoming separate physical Display masters.

## Critical Channel Grid Row Number Rule

Channel Grid Row Number is local to each source PropClass and restarts at `1` for the next Channel Name.

Example:

```text
Display Name = Mega Star

Channel Name = MS Long Spire 1 4x150
    Channel Grid Row 1 -> U113
    Channel Grid Row 2 -> U114
    Channel Grid Row 3 -> U115
    Channel Grid Row 4 -> U116

Channel Name = MS Short Spire 1 2x150
    Channel Grid Row 1 -> U129
    Channel Grid Row 2 -> U130
```

Do not flatten Mega Star into one synthetic 1-N sequence across the entire Display.

A later resolved physical-controller output number is a separate derived concept and must not overwrite the source Channel Grid Row Number.

## Compact / Auto-Numbered ChannelGrid Constraint

Some current dense-RGB custom props serialize compact ChannelGrid entries rather than one explicit semicolon-delimited record for every visible LOR controller-port/string row.

Observed examples include the `2100` fifth-field pattern on Mega Cube and Whoville Matrix.

The arithmetic and LOR UI strongly support an expansion route for these specific cases, but the current parser field remains named `Unknown` because the repository does not have an authoritative universal file-format definition for that fifth value.

Therefore:

- keep the existing `Unknown` column and semantics unchanged;
- do not globally rename/redefine it during the additive provenance change;
- do not combine compact-row expansion with the first provenance patch;
- validate any compact-row expansion rule against representative current LOR UI/source evidence and tests before applying it parser-wide.

## LOR Network Configuration Is a Separate Source

Direct Show-PC inspection on 2026-08-21 established that LOR Network Preferences are stored in the current Windows user's registry, under a branch such as:

```text
HKEY_CURRENT_USER\SOFTWARE\Light-O-Rama\Shared\NetworkF420399CE04C4EC08C7ED0A2C62A1051
```

with per-universe `DMX<n>` subkeys containing values including:

```text
Uses E131
Protocol
E131 IP Address
E131 IP Address Type
E131 Send To Port
Comment
```

This is a separate source adapter from `.lorprev` parsing.

Do not couple registry extraction into the XML parser simply because FieldWiring ultimately consumes both layers.

The registry evidence also directly established that Universes `109-112` are currently inactive/unconfigured (`Uses E131 = 0`, blank target data), resolving that previous gap.

## Dense-RGB Current Physical/Authoring Context

Operator-confirmed physical controller map includes:

```text
Mega Tree       -> one HolidayCoro AlphaPix Flex 48-output system
Mega Ball       -> one physical PixCon16
Mega Cube       -> one HolidayCoro AlphaPix Flex 48-output system
Whoville Matrix -> one physical PixCon16
Mega Star       -> two physical PixCon16
```

Current LOR routing context includes:

```text
Mega Tree       U1-48    -> 10.10.5.10
Mega Ball       U49-64   -> 10.10.5.11
Mega Cube       U65-108  -> 10.10.5.12
U109-112                   inactive/unconfigured
Mega Star 1     U113-128 -> 10.10.5.15
Mega Star 2     U129-144 -> 10.10.5.16
Northern Lights U145-146 -> 10.10.5.30
Whoville Matrix U147-162 -> 10.10.5.17
Gift Conveyor   U163-167 -> 10.10.5.18
Open/Close Sign U168-169 -> 10.10.5.19
```

These routing facts are LOR configuration evidence, not permanent physical-controller identity.

## Controller Inventory Boundary

Controller Inventory remains responsible for permanent physical controller identity/current reviewed physical assignment facts, including future `ctrl_id` resolution.

Do not use any of the following as permanent controller identity:

```text
IP address
universe number/range
LOR Unit ID
network name
Display name
location
controller comment/name
```

## Wiring-System Operational Metadata Boundary

MSB-owned operational wiring metadata such as:

```text
assembly_required_at_setup BOOLEAN NOT NULL DEFAULT FALSE
```

must remain separate from LOR source data and must not be embedded into `.lorprev` parsing.

It belongs at wiring-relationship/connection grain, should carry forward through controlled reconciliation when the same relationship remains, and should be frozen into approved wiring snapshots so later changes do not rewrite history.

Exact persistent table/schema and stable wiring-relationship key remain a separate design step.

## Completed Dependency Inspection

The following V7.0.10 dependencies were inspected before any parser change:

1. **`dmxChannels` CREATE TABLE** — confirmed the existing eight-field contract and foreign keys.
2. **DMX insertion/update paths** — confirmed one logical direct `dmxChannels` insertion path in `process_dmx_props()` and no later DMX update/delete path.
3. **Grouped-DMX canonical master logic** — confirmed grouping by Display Name and deterministic master selection by lowest `(StartUniverse, StartChannel)` with scoped PropID tie-break; all grouped rows retain `dmxChannels.PropId = master PropID`.
4. **Later duplicate-master collapse** — confirmed the later demotion/deletion pass is restricted to `DeviceType='LOR'` and does not rewrite grouped-DMX masters.
5. **Scene resolution** — confirmed grouped DMX Scene members resolve to the canonical Display master rather than each XML component becoming a Display.
6. **SQLite views** — confirmed existing DMX consumers use explicit columns and the existing `PropId -> props.PropID` join, so appended fields can remain invisible to compatibility views initially.
7. **Parser tests/operator comparison** — confirmed current generic output comparison treats schema changes as blocking and does not provide a semantic grouped-DMX regression fixture.
8. **PostgreSQL ingest** — confirmed SQLite-to-PostgreSQL mapping is normalized-name based rather than positional; new SQLite columns require matching PostgreSQL columns only when propagation is approved.
9. **PostgreSQL `dmx_channels` relationship** — confirmed the existing `prop_id` FK remains tied to the canonical snapshot `props` row.
10. **Reconciliation identity** — confirmed `ref.display.lor_prop_id` continues to come from canonical `lor_snap.props.raw_prop_id`; `dmx_channels` is not part of permanent Display identity promotion.

These findings are captured in the exact [Additive Change Map](FieldWiring_Dense_RGB_DMX_Additive_Change_Map_2026-08-21.md).

## Required Regression Principle

For the same input Preview set, excluding intentionally new additive columns/materialized rows explicitly authorized by a later compact-row change:

```text
existing parser identity behavior must remain unchanged
existing non-DMX behavior must remain unchanged
existing Display master selection must remain unchanged
existing DMX row count must remain unchanged for explicitly serialized rows
existing PostgreSQL raw PropClass UUID mapping must remain unchanged
existing FormView/FieldWiring-compatible relationships must remain unchanged
```

If an additive extension unexpectedly changes an existing relationship, stop and review rather than compensating downstream.

## Next Engineering Step

The original inspection gate is complete.

The next step remains **tests before parser implementation**:

```text
1. Add a grouped-DMX regression fixture against the V7.0.10 behavior.
2. Prove existing master selection, PropId values, row counts, and existing field values.
3. Define expected RawPropID, ChannelName, and ChannelGridRowNumber values in that fixture.
4. Only after those tests exist, make the additive parser/schema change.
```

After approval and implementation:

```text
run parser regression tests
-> produce a new parser SQLite snapshot
-> inspect dense-RGB rows directly
-> confirm legacy view output is unchanged
-> update PostgreSQL dmx_channels/current-snapshot interface only after SQLite acceptance
-> build a new FieldWiring dev snapshot/read model
-> browser-test Mega Tree, Mega Cube, Mega Star, Whoville Matrix, etc.
-> review compact ChannelGrid expansion separately
```

Broad FieldWiring UX work remains out of scope until dense-RGB acceptance is complete.

## Related Durable Decisions

- [FieldWiring Dense RGB DMX Additive Change Map](FieldWiring_Dense_RGB_DMX_Additive_Change_Map_2026-08-21.md)
- [LOR XML to MSB Terminology Contract](../../../01_LOR_System/02_Data_Extraction/LOR_XML_to_MSB_Terminology_Contract.md)
- `FieldWiring_Dense_RGB_LOR_Controller_Port_Recovery_2026-08-21.md`
- `FieldWiring_E131_LOR_Controller_Definitions_2026-08-21.md`
- `FieldWiring_DMX_Table_Purpose_and_Field_Assembly_Boundary_2026-08-21.md`
- `FieldWiring_Wiring_Snapshot_Assembly_Required_Contract_2026-08-21.md`
- `FieldWiring_Dense_RGB_Physical_Controller_Map_2026-08-20.md`
- `FieldWiring_Controller_Inventory_Handoff_2026-08-20.md`

## Stop Point

At this updated checkpoint:

- the V7.0.10 dependency inspection is complete;
- the exact additive schema/change map is documented;
- the earlier temporary `Source*` terminology is superseded by `RawPropID`, `ChannelName`, and `ChannelGridRowNumber`;
- **no V7 parser code/schema change has been made for the dense-RGB provenance extension**.

The next engineering action is to create the grouped-DMX regression test before changing parser behavior.

## Revision History

| Date | Author | Change |
|---|---|---|
| 2026-08-21 | GAL / OpenAI | Completed the V7.0.10 dependency inspection, replaced temporary `Source*` terminology with the controlled LOR/MSB terms, linked the exact additive change map, and advanced the stop point to regression-tests-first with no parser code change. |
| 2026-08-21 | GAL / OpenAI | Created implementation checkpoint before dense-RGB parser extension. |
