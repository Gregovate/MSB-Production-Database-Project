# LOR XML to MSB Terminology Contract

| Document control | Value |
|---|---|
| Status | CURRENT — reverse-engineered terminology reference |
| System | LOR Preview Parser / LOR2DB / FieldWiring |
| Functional baseline | `parse_props_v7_scene_parser.py` V7.0.10 |
| Initial revision | 2026-08-21 |
| Owner | MSB Database Administrator |

## Purpose

This document preserves the translation between Light-O-Rama `.lorprev` XML names and the human-readable MSB terms used in engineering, database documentation, FieldWiring, and operator discussion.

The translation is important because the Light-O-Rama XML field names do not always describe the way MSB uses the data. The most important example is `PropClass.Comment`: Light-O-Rama does not provide a separate Display Name field that matches the MSB physical-display model, so MSB uses `PropClass.Comment` as the Display Name.

This is a reverse-engineered engineering contract. It is not an official Light-O-Rama file-format specification.

The repository is the durable record of this terminology. Future implementation work should use this contract rather than inventing conversation-specific aliases.

## Core Translation Table

| LOR XML source | Current parser / SQLite field | MSB human-readable name | Meaning |
|---|---|---|---|
| `PreviewClass.id` | `previews.id` | Preview ID | LOR identity of the preview |
| `PreviewClass.Name` | `previews.Name` | Preview Name | Human/operator name of the preview |
| `PreviewClass.Revision` | `previews.Revision` | Preview Revision | LOR preview revision metadata |
| `PreviewClass.BackgroundFile` | `previews.BackgroundFile` | Background File | LOR background image/path reference |
| `PropClass.id` | `RawPropID` | LOR Prop ID | Original LOR PropClass UUID/source identity |
| preview-scoped `PropClass.id` | `props.PropID` / `subProps.SubPropID` | Parser Prop ID | Parser relational identity formed from Preview ID plus LOR Prop ID; not a permanent Display ID |
| `PropClass.Comment` | `LORComment` | Display Name | MSB physical Display name/identity label |
| `PropClass.Name` | `Name` | Channel Name | LOR-authored channel, component, or channel-configuration label |
| `PropClass.DeviceType` | `DeviceType` | Device Type | Determines how ChannelGrid data is interpreted and materialized |
| `PropClass.ChannelGrid` | parsed wiring fields | Channel Grid | LOR serialized wiring assignment structure |
| one serialized entry within `ChannelGrid` | parsed wiring row | Channel Grid Row | One DeviceType-specific wiring entry within a PropClass |
| position of a Channel Grid Row within its PropClass | not currently stored as a dedicated field | Channel Grid Row Number | Human-readable 1-based position within that PropClass; numbering restarts for the next PropClass |
| `PropClass.MasterPropId` | `MasterPropId` where applicable | LOR Master Prop ID | LOR-authored parent/master relationship |
| `PropClass.StringType` | `StringType` | String Type | LOR string-type metadata |
| `PropClass.Tag` | `Tag` | LOR Tag | LOR tag metadata |
| `PropClass.Parm1` through `Parm8` | `Parm1` through `Parm8` | LOR Parameters | Prop-specific LOR parameters whose interpretation can depend on prop/device type |

## Required Naming Rule

When discussing the XML itself, use the exact Light-O-Rama XML name.

When discussing the MSB engineering meaning, use the MSB human-readable name.

On first use where ambiguity is possible, show both names together.

Examples:

```text
Display Name (`PropClass.Comment`)
Channel Name (`PropClass.Name`)
LOR Prop ID (`PropClass.id`)
Channel Grid (`PropClass.ChannelGrid`)
```

After the translation is established in a section, prefer the human-readable MSB term unless the exact XML attribute is material to the discussion.

Do not introduce abstract substitute names when an existing XML term or established MSB term already describes the concept.

For example, prefer:

```text
Channel Grid Row Number
```

over an abstract implementation term such as:

```text
SourceGridOrdinal
```

## Critical Display Name Rule

The following translation is intentional and must remain explicit in documentation:

```text
PropClass.Comment -> Display Name
PropClass.Name    -> Channel Name
```

`PropClass.Comment` is called `Comment` by Light-O-Rama, but MSB uses it as the physical Display Name because there is no other LOR field that carries the required MSB display identity consistently.

`PropClass.Name` must not be substituted for Display Name. It is the Channel Name / LOR-authored channel or component label.

Example:

```text
LOR XML
    PropClass.Comment = "Mega Star"
    PropClass.Name    = "MS Short Spire 1 2x150"

MSB terminology
    Display Name = Mega Star
    Channel Name = MS Short Spire 1 2x150
```

Several PropClass records can therefore have the same Display Name while retaining different Channel Names.

## ChannelGrid Is DeviceType-Dependent

`PropClass.ChannelGrid` is a serialized LOR wiring structure. Its row layout and field meanings are not universal.

MSB reverse engineering has established that ChannelGrid must be interpreted in the context of `PropClass.DeviceType`.

Do not document a ChannelGrid field as having one universal meaning across all DeviceTypes unless that behavior has been independently established.

### DeviceType = LOR

For the currently supported LOR channel form, a Channel Grid Row is interpreted approximately as:

| Position | MSB interpretation |
|---:|---|
| 1 | Network |
| 2 | Controller / Unit ID (`UID`) |
| 3 | Start Channel |
| 4 | End Channel |
| 5 | Unknown LOR grid field |
| 6, when present | Color |

The parser currently materializes these values into the LOR wiring fields on `props` / `subProps`.

### DeviceType = DMX

For the currently supported DMX form, a Channel Grid Row is interpreted approximately as:

| Position | MSB interpretation |
|---:|---|
| 1 | Network |
| 2 | DMX Universe (`StartUniverse`) |
| 3 | Start Channel |
| 4 | End Channel |
| 5 | Unknown LOR grid field |

The parser materializes DMX Channel Grid Rows into `dmxChannels`.

### DeviceType = None

`DeviceType=None` does not use the same channel-addressing contract as LOR or DMX and must not be forced into either ChannelGrid interpretation.

Its parser path is primarily concerned with inventory/layout materialization and physical fan-out rules.

## Channel Grid Row Number

When a PropClass contains multiple Channel Grid Rows, the human-readable row number is local to that PropClass.

Numbering starts at `1` for the first Channel Grid Row and restarts at `1` when the next PropClass begins.

Example:

```text
Display Name = Mega Star

Channel Name = MS Long Spire 1 4x150
    Channel Grid Row 1 -> Universe 113
    Channel Grid Row 2 -> Universe 114
    Channel Grid Row 3 -> Universe 115
    Channel Grid Row 4 -> Universe 116

Channel Name = MS Short Spire 1 2x150
    Channel Grid Row 1 -> Universe 129
    Channel Grid Row 2 -> Universe 130
```

Do not flatten those rows into one synthetic 1-N sequence across the entire Display. A later physical-controller output number is a separate derived concept.

## Grouped DMX Terminology

For grouped DMX Displays, several `PropClass` records can share one Display Name (`PropClass.Comment`). The current V7.0.10 parser intentionally materializes one canonical Display master in `props` and attaches all grouped DMX wiring rows to that master through `dmxChannels.PropId`.

That existing master relationship is a parser/database relationship and is separate from the source terminology preserved in the XML.

Example source:

```text
PropClass.Comment = Mega Star
PropClass.Name    = MS Long Spire 1 4x150

PropClass.Comment = Mega Star
PropClass.Name    = MS Short Spire 1 2x150
```

Human-readable interpretation:

```text
Display Name = Mega Star

Channel Name = MS Long Spire 1 4x150
    Channel Grid Rows ...

Channel Name = MS Short Spire 1 2x150
    Channel Grid Rows ...
```

Dense-RGB parser recovery must preserve this source distinction without changing the existing canonical Display relationship.

## Documentation Maintenance Rule

Reverse-engineering discoveries made during engineering work are part of the system knowledge and must be captured in the repository.

When a discovery clarifies an existing contract:

1. update the existing durable documentation additively where practical;
2. preserve existing correct content rather than rewriting the document from scratch;
3. distinguish confirmed behavior from hypotheses or proposed implementation;
4. preserve the XML-to-MSB translation so future engineers do not have to rediscover terminology from parser code or old conversations;
5. do not change implemented schema descriptions to describe proposed fields before those fields are actually implemented.

The conversation in which a fact was discovered is not the durable authority. The repository documentation is.

## Related Documents

- [LOR Preview File Structure Specification](LOR_Preview_File_Structure_Specification.md)
- [LOR Preview Parser Architecture](LOR_Preview_Parser_Architecture.md)
- [LOR SQLite Output Database Structure](LOR_SQLite_Output_Database_Structure.md)
- [FieldWiring Dense RGB Parser Extension Checkpoint](../../02_Production_Database/01_System_Architecture/09_Wiring_System/FieldWiring_Dense_RGB_Parser_Extension_Checkpoint_2026-08-21.md)

## Revision History

| Date | Author | Change |
|---|---|---|
| 2026-08-21 | GAL / OpenAI | Established the durable XML-to-MSB terminology translation, documented Display Name = `PropClass.Comment`, Channel Name = `PropClass.Name`, and recorded that ChannelGrid interpretation is DeviceType-dependent and its row numbering is local to each PropClass. |
