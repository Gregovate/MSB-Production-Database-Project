# FieldWiring Dense RGB DMX Additive Change Map — 2026-08-21

| Item | Value |
|---|---|
| Status | PROPOSED CHANGE MAP — NO PARSER CODE CHANGE YET |
| Sub-project | FieldWiring / Engineering Recovery |
| Branch | `agent/fieldwiring-engineering-recovery` |
| Parser baseline | V7.0.10 |
| Scope | Additive preservation of grouped-DMX source wiring detail |

## Purpose

This document records the exact proposed additive change boundary after inspection of the current V7.0.10 parser, parser views/tests, grouped-DMX materialization behavior, PostgreSQL ingest, and reconciliation identity path.

It is a design/change map only. It does not describe an implemented schema change.

The governing terminology is defined in:

- [LOR XML to MSB Terminology Contract](../../../01_LOR_System/02_Data_Extraction/LOR_XML_to_MSB_Terminology_Contract.md)

## Existing Contract — Must Remain Unchanged

Current V7.0.10 `dmxChannels` fields are:

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

For grouped DMX Displays, `PropId` points to the existing canonical/materialized Display master `props.PropID`.

That relationship remains unchanged.

The proposed change must not alter:

- `dmxChannels.PropId` values;
- grouped-DMX master selection;
- `props.PropID` or `props.RawPropID` behavior;
- existing DMX row counts for ordinary explicitly serialized Channel Grid Rows;
- existing `Network`, `StartUniverse`, `StartChannel`, `EndChannel`, `Unknown`, or `PreviewId` values;
- Scene resolution to the canonical Display master;
- FormView/FieldWiring compatibility-view output;
- PostgreSQL reconciliation identity or `ref.display.lor_prop_id` behavior.

## Current Information Loss

Several DMX `PropClass` records can share one Display Name (`PropClass.Comment`). V7.0.10 intentionally materializes one canonical Display master and attaches every grouped DMX Channel Grid Row to that master through `dmxChannels.PropId`.

That preserves the Display relationship but does not preserve, on each `dmxChannels` row, which source `PropClass` supplied the row.

Example:

```text
Display Name (`PropClass.Comment`) = Mega Star

Channel Name (`PropClass.Name`) = MS Long Spire 1 4x150
    Channel Grid Row 1 -> U113
    Channel Grid Row 2 -> U114
    Channel Grid Row 3 -> U115
    Channel Grid Row 4 -> U116

Channel Name (`PropClass.Name`) = MS Short Spire 1 2x150
    Channel Grid Row 1 -> U129
    Channel Grid Row 2 -> U130
```

After current grouped-DMX materialization, all six rows correctly point to the same Mega Star `PropId`, but the second Channel Name and the local Channel Grid Row numbers are no longer available from `dmxChannels`.

## Proposed Additive SQLite Fields

Append the following fields to `dmxChannels` after the existing fields:

| Proposed SQLite field | Human meaning | LOR XML source | Rule |
|---|---|---|---|
| `RawPropID` | LOR Prop ID | `PropClass.id` | Store the original unscoped ID of the `PropClass` that supplied this DMX Channel Grid Row. |
| `ChannelName` | Channel Name | `PropClass.Name` | Store the LOR-authored Channel Name of the `PropClass` that supplied this row. |
| `ChannelGridRowNumber` | Channel Grid Row Number | position within `PropClass.ChannelGrid` | Store the 1-based row position local to the source `PropClass`; restart at 1 for the next `PropClass`. |

Proposed resulting table order:

```text
IntDMXChannelID       existing
PropId                existing
Network               existing
StartUniverse         existing
StartChannel          existing
EndChannel            existing
Unknown               existing
PreviewId             existing
RawPropID             new
ChannelName           new
ChannelGridRowNumber  new
```

The existing eight fields stay first and retain their current meanings.

## Why `RawPropID` Instead of Another Source-ID Name

`RawPropID` is already the parser's established field name for the LOR source `PropClass.id` on `props` and `subProps`.

Using the same field name on `dmxChannels` preserves one meaning across the parser:

```text
RawPropID = originating LOR Prop ID (`PropClass.id`)
```

`dmxChannels.PreviewId` is already present, so the pair:

```text
PreviewId + RawPropID
```

identifies the originating source `PropClass` within the parser snapshot.

There is no need to store a synthetic preview-scoped ID in an additional source field.

## No New Foreign Key From `RawPropID`

Do not add a foreign key from `dmxChannels.RawPropID` to `props.PropID` or `props.RawPropID`.

Reason: grouped DMX intentionally materializes only one canonical Display master in `props`. A different grouped DMX `PropClass` can legitimately supply Channel Grid Rows without becoming a separate `props` Display row.

Example:

```text
PropId    = <canonical Mega Star parser Prop ID>
RawPropID = <MS Short Spire source PropClass.id>
```

The source `RawPropID` is provenance for the wiring row, not another physical Display relationship.

## Proposed Parser Population Rule

During `process_dmx_props()` collection, retain for each DMX `PropClass`:

```text
RawPropID   = PropClass.id
ChannelName = PropClass.Name
```

While splitting that PropClass's `ChannelGrid`, enumerate only the serialized Channel Grid Rows belonging to that PropClass:

```text
ChannelGridRowNumber = 1, 2, 3, ...
```

Restart numbering at `1` when the next `PropClass` is processed.

When grouped rows are emitted to `dmxChannels`:

```text
PropId = existing canonical master PropID          # unchanged
RawPropID = originating PropClass.id               # new
ChannelName = originating PropClass.Name           # new
ChannelGridRowNumber = local Channel Grid row      # new
```

## Example Result

Assume the existing canonical Mega Star master is the first Channel Name below.

| PropId | RawPropID | ChannelName | ChannelGridRowNumber | StartUniverse |
|---|---|---|---:|---:|
| Mega Star canonical master | Prop A | MS Long Spire 1 4x150 | 1 | 113 |
| Mega Star canonical master | Prop A | MS Long Spire 1 4x150 | 2 | 114 |
| Mega Star canonical master | Prop A | MS Long Spire 1 4x150 | 3 | 115 |
| Mega Star canonical master | Prop A | MS Long Spire 1 4x150 | 4 | 116 |
| Mega Star canonical master | Prop B | MS Short Spire 1 2x150 | 1 | 129 |
| Mega Star canonical master | Prop B | MS Short Spire 1 2x150 | 2 | 130 |

The Display relationship remains one Mega Star master. The new fields recover which LOR Channel Name and Channel Grid Row supplied each DMX wiring row.

## ChannelGrid DeviceType Boundary

`ChannelGrid` field definitions are DeviceType-dependent.

This change is limited to the existing DMX parser path. It does not establish a universal ChannelGrid schema for LOR, DMX, None, or future DeviceTypes.

The existing DMX interpretation remains:

| Channel Grid position | Current DMX interpretation |
|---:|---|
| 1 | Network |
| 2 | DMX Universe (`StartUniverse`) |
| 3 | Start Channel |
| 4 | End Channel |
| 5 | `Unknown` |

The existing `Unknown` field remains unchanged because its universal LOR meaning has not been established.

## Compact ChannelGrid Rows Are a Separate Change

This first additive provenance change must not also implement compact/auto-numbered ChannelGrid expansion.

Compact examples such as the observed `2100` fifth-field pattern require a separate evidence and regression gate because expansion can intentionally add materialized DMX rows.

First prove source preservation with unchanged existing row counts. Then review compact-row expansion independently.

## SQLite View Impact

Current SQLite wiring/stage views reference explicit existing `dmxChannels` fields and join `dmxChannels.PropId` back to the canonical `props.PropID`.

The first provenance change does not require existing compatibility views to expose the new fields.

Leaving the legacy view shapes unchanged is desirable for the first change because it provides a direct regression check for FormView and existing FieldWiring consumers.

A later FieldWiring-specific read model may expose `RawPropID`, `ChannelName`, and `ChannelGridRowNumber` after the parser data is accepted.

## Parser Test Impact

Before changing V7.0.10 behavior, add a grouped-DMX regression fixture that proves:

1. multiple DMX `PropClass` rows sharing one Display Name produce one canonical `props` master;
2. existing master selection is unchanged;
3. every existing `dmxChannels.PropId` remains the canonical master;
4. existing DMX row count remains unchanged for explicitly serialized rows;
5. existing DMX field values remain unchanged;
6. `RawPropID` identifies the source `PropClass.id` for every row;
7. `ChannelName` preserves the source `PropClass.Name`;
8. `ChannelGridRowNumber` starts at 1 and restarts for each source `PropClass`;
9. existing SQLite wiring views retain the same columns and rows;
10. non-DMX parser output is unchanged.

The current generic parser-output comparison treats table schema differences as blocking when comparing same-parser compatibility outputs. It is not a substitute for this parser-version regression test because this change intentionally extends the `dmxChannels` schema.

## PostgreSQL Ingest Impact

Current ingest maps SQLite and PostgreSQL columns by normalized name rather than by ordinal position.

Therefore adding SQLite fields alone does not require positional ingest changes, but PostgreSQL will not preserve the new values until matching additive columns exist on `lor_snap.dmx_channels`.

Proposed PostgreSQL names, if propagation is approved after SQLite validation:

```text
raw_prop_id
channel_name
channel_grid_row_number
```

The existing PostgreSQL `prop_id` remains the canonical Display/master parser ID and must not change.

Before PostgreSQL propagation, inspect and control the authoritative definition of `lor_snap.v_current_dmx_channels` so the new source fields can be exposed deliberately without changing existing consumer-view contracts.

## Reconciliation Identity Impact

No reconciliation change is proposed.

Display reconciliation continues to derive permanent LOR identity from the canonical `lor_snap.props` row:

```text
props.prop_id     -> scoped source occurrence / source_prop_id
props.raw_prop_id -> ref.display.lor_prop_id
```

The new `dmxChannels.RawPropID` is wiring-row provenance only. It must not become a candidate permanent Display identity.

## Implementation Sequence After Approval

```text
1. Add grouped-DMX regression tests against V7.0.10 behavior.
2. Extend SQLite dmxChannels with the three additive fields.
3. Populate the fields only in process_dmx_props().
4. Bump parser version under the existing controlled versioning process.
5. Run parser tests and same-input regression checks.
6. Build a new SQLite snapshot.
7. Inspect dense-RGB rows directly for Mega Star, Mega Cube, Mega Tree, and Whoville Matrix.
8. Confirm all existing view outputs/relationships remain unchanged.
9. Only then extend lor_snap.dmx_channels and its current-snapshot interface if PostgreSQL propagation is required.
10. Build the FieldWiring development read model from the accepted data.
11. Review compact ChannelGrid expansion as a separate controlled change.
```

## Stop Conditions

Stop and review if the provenance change causes any unapproved change to:

- canonical DMX master selection;
- existing `PropId` values;
- existing DMX row count;
- existing universe/channel values;
- existing parser relationships;
- Scene membership;
- FormView compatibility output;
- reconciliation source identity;
- non-DMX parser output.

## Related Documents

- [FieldWiring Dense RGB Parser Extension Checkpoint](FieldWiring_Dense_RGB_Parser_Extension_Checkpoint_2026-08-21.md)
- [LOR XML to MSB Terminology Contract](../../../01_LOR_System/02_Data_Extraction/LOR_XML_to_MSB_Terminology_Contract.md)
- [LOR Preview Parser Architecture](../../../01_LOR_System/02_Data_Extraction/LOR_Preview_Parser_Architecture.md)
- [LOR SQLite Output Database Structure](../../../01_LOR_System/02_Data_Extraction/LOR_SQLite_Output_Database_Structure.md)

## Revision History

| Date | Author | Change |
|---|---|---|
| 2026-08-21 | GAL / OpenAI | Created the exact additive change map after V7.0.10 dependency inspection; replaced conversation-specific source/component terminology with the controlled LOR/MSB terms `RawPropID`, `ChannelName`, and `ChannelGridRowNumber`. |
