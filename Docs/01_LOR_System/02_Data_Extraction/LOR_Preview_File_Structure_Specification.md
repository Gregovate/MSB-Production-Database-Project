# LOR Preview File Structure Specification

| Document control | Value |
|---|---|
| Status | CURRENT — reverse-engineered engineering reference |
| Baseline | Approved Light-O-Rama `.lorprev` manifest for LOR 6.6.10 |
| Current revision | 2026-08-21 |
| Owner | MSB Database Administrator |

## Purpose

This document describes the `.lorprev` file structure that the current MSB parser depends on.

Its primary purpose is compatibility review. When Light-O-Rama releases a new version, a representative preview exported by the new version must be compared against this baseline before the production parser is assumed compatible.

This is a reverse-engineered specification. It documents the structure and attributes that the functional MSB parser currently observes or depends on. It is not an official Light-O-Rama file-format specification.

Where the parser does not consume an element or attribute, this document does not claim that the element is unimportant to Light-O-Rama itself.

## Baseline and Authority

The current production parser is:

`Docs/01_LOR_System/02_Data_Extraction/Parser/parse_props_v7_scene_parser.py`

Functional parser baseline:

`V7.0.10`

Known-good LOR preview baseline:

`Light-O-Rama 6.6.10`

The parser source is the implementation authority for materialization. The
approved XML manifest is the compatibility authority for the complete exported
structure, including fields the parser does not currently use. The manifest is
created and compared by `Parser/lor_version_checker.py`.

Human-readable source-field translations used by MSB are controlled separately in [LOR XML to MSB Terminology Contract](LOR_XML_to_MSB_Terminology_Contract.md).

## File Type

A `.lorprev` file is XML.

The MSB parser uses Python `xml.etree.ElementTree` and deliberately searches by tag suffix, such as:

- `PreviewClass`
- `Scene`
- `PropClass`

This makes the parser tolerant of namespace-qualified tag names as long as the local element names remain unchanged.

A change to namespaces alone may therefore be harmless, while a change to the local element name or hierarchy may affect parsing.

## Parser-Visible Structural Model

The current parser treats the preview file conceptually as:

```text
XML document
|
+-- PreviewClass
|   +-- preview metadata
|
+-- Scene marker
|   +-- Scene metadata
|
+-- PropClass
+-- PropClass
+-- ...
|
+-- Scene marker
|   +-- Scene metadata
|
+-- PropClass
+-- PropClass
+-- ...
```

The exact XML can contain additional elements. The important V7 behavior is that Scene membership is derived from document order: a Scene marker establishes the current Scene and the following PropClass elements belong to that Scene until another Scene marker is encountered.

The parser does not require Scene membership to be represented as a direct Scene foreign-key attribute on each PropClass.

## PreviewClass

### Role

`PreviewClass` represents the preview-wide definition and is the global LOR prop/control universe for that `.lorprev` file.

The parser searches the complete XML tree and accepts a `PreviewClass` element at any depth.

### Attributes consumed by the parser

| Attribute | Parser use |
|---|---|
| `id` | Preview identity; stored as `previews.id` |
| `Name` | Preview/operator name and source for derived StageID |
| `Revision` | Preview revision |
| `Brightness` | Preview brightness metadata |
| `BackgroundFile` | Background image reference |

The parser additionally records the actual `.lorprev` filename as `SourceFilename`; that value comes from the filesystem, not from a PreviewClass attribute.

### Master Musical identity and operator version name

The Master Musical Preview has two intentionally different identity layers:

- `PreviewClass.id` is its stable machine identity and does not change merely
  because the file is renamed;
- the Master Musical filename and `PreviewClass.Name` include the LOR version
  and working date so operators can identify the correct version to use.

When channels, props, Displays, Scenes, or other Master Musical content change,
the version/date name may be advanced while the stable PreviewID remains the
same. The parser preserves the exact filename in `SourceFilename`. Compatibility
checking matches the logical preview by PreviewID and separately reports the
human-facing version/date filename change for review.

### Compatibility risks

The parser can be affected if a new LOR release:

- renames `PreviewClass`;
- changes or removes `id`;
- changes the meaning or format of `Name`;
- changes the `Revision` representation;
- relocates preview identity into another structure;
- stops exporting the expected preview-level object.

## Preview Naming and Stage Extraction

StageID is an MSB-derived value, not a separate trusted LOR identifier.

The current parser recognizes stage tokens in names using the established MSB conventions:

- prefix form such as `07-...`;
- sub-stage prefix form such as `07a-...`;
- embedded `Stage 07`;
- embedded `Stage 07a`;
- Show Animation names containing an animation stage number.

A LOR release that changes how preview names are stored can therefore break StageID derivation even if the XML remains valid.

## Scene

### Role

A `Scene` is a sequencing/presentation workspace or camera view. It is not a physical display identity.

The current parser uses preview-level Scenes exported in `.lorprev` files. Sequence-level Scenes that exist only inside sequences are outside this production preview contract.

### Attributes consumed by the parser

| Attribute | Parser use |
|---|---|
| `id` | Scene identity |
| `Name` | Scene name; source for derived Scene StageID and SceneSection |
| `BackgroundFile` | Scene background reference; published separately and as the effective background in `scene_displays_vw` |
| `HScroll` | Horizontal view state |
| `VScroll` | Vertical view state |
| `Zoom` | Zoom/view state |
| `CreateGridView` | Scene/grid presentation metadata |

The parser derives `SceneSection` from the Scene name. It does not expect SceneSection as a required source attribute.

### Positional membership rule

The current parser walks the XML in document order.

When it encounters a Scene:

1. that Scene becomes the current Scene;
2. the Scene ordinal starts at zero;
3. following PropClass rows are associated with that Scene;
4. the next Scene marker ends the previous positional block.

This ordering is a critical compatibility dependency.

A future LOR release that nests PropClass differently, moves Scene markers to a separate index, adds explicit membership references, or changes ordering semantics must be reviewed before production use.

## PropClass

### Role

`PropClass` is the primary LOR source object from which the parser materializes physical display masters, subordinate components, DMX channels, inventory fan-out, and Scene membership.

One PropClass does not always equal one production display row. The parser applies engineering materialization rules after reading the XML.

### Core attributes consumed or preserved

| Attribute | Meaning in MSB parser |
|---|---|
| `id` | Raw LOR PropClass UUID/source identity / LOR Prop ID |
| `Name` | Channel Name / sequencer label |
| `Comment` | Display Name |
| `DeviceType` | Device classification such as LOR, DMX, None |
| `BulbShape` | Prop presentation metadata |
| `DimmingCurveName` | Dimming-curve metadata |
| `IndividualChannels` | Determines whether multiple wiring legs are independently materialized |
| `LegacySequenceMethod` | Preserved LOR metadata |
| `MaxChannels` | Channel/count metadata; also relevant to some inventory fan-out behavior |
| `Opacity` | Prop presentation metadata |
| `MasterDimmable` | Prop metadata |
| `PreviewBulbSize` | Preview presentation metadata |
| `MasterPropId` | LOR parent/master relationship for manually related props/subprops |
| `SeparateIds` | Preserved LOR metadata |
| `StartLocation` | Prop metadata |
| `StringType` | Prop/string metadata |
| `TraditionalColors` | Traditional color metadata |
| `TraditionalType` | Traditional prop metadata |
| `EffectBulbSize` | Effect/presentation metadata |
| `Tag` | LOR tag metadata used by downstream reporting/naming logic |
| `Parm1` through `Parm8` | Prop parameters preserved by parser |
| `Lights` | Light-count metadata |
| `ChannelGrid` | Encoded wiring/grid data whose field meanings depend on DeviceType |

The parser's SQLite schema preserves these values so downstream logic does not need to reopen the XML.

### Naming contract

The following distinction is critical:

```text
PropClass.Comment -> Display Name
PropClass.Name    -> Channel Name
PropClass.id      -> LOR Prop ID
```

A future LOR version that changes the meaning, source, or availability of these attributes can change physical-display matching or source wiring provenance even if the parser continues to execute.

Use [LOR XML to MSB Terminology Contract](LOR_XML_to_MSB_Terminology_Contract.md) for the controlled translation between exact XML names and MSB human-readable terms.

## PropClass Identity

The raw XML `PropClass.id` is not sufficient as the only database key because LOR can reuse PropClass IDs across different previews.

The parser therefore maintains:

- `RawPropID` — source LOR identity;
- `PropID` / `SubPropID` — preview-scoped parser identity.

For physical `DeviceType=None` fan-out, the materialized RawPropID is occurrence-qualified with suffixes such as `-01`, `-02`, and so on.

Compatibility review must pay particular attention to any LOR change in UUID generation, reuse, persistence, parent references, or copy/paste behavior.

## ChannelGrid

### Role

`PropClass.ChannelGrid` carries serialized wiring information. MSB reverse engineering has established that the row structure must be interpreted in the context of `PropClass.DeviceType`; ChannelGrid does **not** have one universal field definition across all DeviceTypes.

The parser derives DeviceType-specific values such as:

- Network;
- controller UID for LOR-style rows;
- StartUniverse for DMX rows;
- StartChannel;
- EndChannel;
- additional/unknown grid values;
- Color where present.

Do not assign a universal meaning to a serialized ChannelGrid position unless that meaning has been established for each DeviceType in scope.

### Current LOR interpretation

For the currently supported LOR form, a serialized Channel Grid Row is interpreted approximately as:

| Position | MSB interpretation |
|---:|---|
| 1 | Network |
| 2 | Controller / Unit ID (`UID`) |
| 3 | Start Channel |
| 4 | End Channel |
| 5 | Unknown LOR grid field |
| 6, when present | Color |

### Current DMX interpretation

For the currently supported DMX form, a serialized Channel Grid Row is interpreted approximately as:

| Position | MSB interpretation |
|---:|---|
| 1 | Network |
| 2 | DMX Universe (`StartUniverse`) |
| 3 | Start Channel |
| 4 | End Channel |
| 5 | Unknown LOR grid field |

The fifth field remains documented as unknown because a universal authoritative LOR meaning has not been established.

### Multiple serialized rows

Where `ChannelGrid` contains multiple explicit semicolon-delimited entries, each serialized entry is a **Channel Grid Row**.

For source-provenance purposes, Channel Grid Row Number is local to the owning PropClass:

```text
first serialized row  -> Channel Grid Row 1
second serialized row -> Channel Grid Row 2
...
next PropClass         -> restart at Channel Grid Row 1
```

Do not flatten row numbering across all PropClasses that share one Display Name.

### Multi-grid behavior

The parser recognizes cases where one PropClass contains multiple wiring legs. The serialized grid data can represent more than one leg, and the parser separates those legs according to DeviceType and `IndividualChannels` behavior.

For LOR props, multiple legs can become `subProps` while preserving one physical master.

For DMX, grid legs become rows in `dmxChannels`.

A change in ChannelGrid serialization is high risk because the parser can still find the PropClass while silently misreading wiring data.

For a future LOR compatibility review, ChannelGrid should always be compared using raw XML examples from equivalent props exported by both LOR versions.

### Compact/auto-numbered ChannelGrid evidence

Some current dense-RGB custom props use a compact ChannelGrid serialization rather than one explicit semicolon-delimited entry for every controller-port/string row visible in the LOR UI.

Observed examples include a `2100` fifth-field pattern on Mega Cube and Whoville Matrix. Current arithmetic and LOR UI evidence support additional reverse engineering, but the fifth field remains `Unknown` in the current parser because its universal semantics have not been established.

Compact-row expansion is therefore not part of the first grouped-DMX source-provenance change. It requires its own evidence and regression gate because expansion can change materialized DMX row counts.

## DeviceType

The current parser has explicit engineering paths for the observed values:

- `LOR`;
- `DMX`;
- `None`.

A new or renamed DeviceType value must be treated as a compatibility change until its semantics are understood.

### LOR

LOR channel-based props use controller/network/channel data and may materialize one master plus subordinate wiring legs.

### DMX

DMX props use universe/channel-oriented wiring and materialize Channel Grid Rows separately from the physical Display master.

### None

`None` is used for non-wired/undetermined inventory or layout objects and cannot be treated as simply another channel type.

Some source objects fan out into multiple physical inventory records. Blank-comment None objects can be layout helpers and are excluded from display-level Scene membership.

## MasterPropId and Manual Subprops

`MasterPropId` is a LOR source relationship and is important to manually constructed prop/subprop arrangements.

The parser does not assume every child relationship is merely drawing detail. It applies the Display Name and materialization rules to determine whether a child represents a separately meaningful physical item or a subordinate component.

Compatibility review must verify that future LOR versions preserve the same parent-ID semantics and that copied/edited preview objects still use MasterPropId in the expected way.

## DMX Representation

The parser preserves a physical DMX Display master in `props` and materializes DMX Channel Grid Rows in `dmxChannels`.

### Grouped DMX behavior

Several DMX source PropClasses can share one Display Name (`PropClass.Comment`). V7.0.10 groups those source rows by Display Name, chooses one canonical Display master, and attaches all grouped DMX Channel Grid Rows to the canonical master through `dmxChannels.PropId`.

That behavior means:

```text
one Display Name
    -> one canonical materialized props master
    -> many dmxChannels rows
```

while multiple source PropClasses can still have distinct:

```text
PropClass.id   -> LOR Prop ID
PropClass.Name -> Channel Name
ChannelGrid    -> local Channel Grid Rows
```

### Current V7.0.10 source-detail limitation

The current `dmxChannels` row retains the canonical Display/master relationship and DMX addressing, but it does not separately retain which grouped source PropClass supplied that row.

For dense-RGB Displays, this can lose the originating LOR Prop ID, Channel Name, and local Channel Grid Row Number even though the correct Display master remains intact.

The proposed additive parser extension would preserve those values as `RawPropID`, `ChannelName`, and `ChannelGridRowNumber`. Those fields are **not implemented in V7.0.10** and are documented in [FieldWiring Dense RGB DMX Additive Change Map](../../02_Production_Database/01_System_Architecture/09_Wiring_System/FieldWiring_Dense_RGB_DMX_Additive_Change_Map_2026-08-21.md).

The downstream DMX contract currently depends on correct extraction of:

- Network;
- StartUniverse;
- StartChannel;
- EndChannel;
- other grid metadata.

If a future LOR release changes universe representation, channel numbering, ChannelGrid serialization, or the relationship between PropClass and grid data, PostgreSQL wiring output can become incorrect without an obvious XML parse failure.

## Background Images and View Metadata

The parser preserves background references from PreviewClass and Scene where available.

Background images are operationally important to FormView and visual setup workflows, even though they are not physical display identity.

Compatibility review should therefore check both the XML attribute and the path/filename behavior produced by the new LOR release.

## XML Elements Not Used by the Parser

A `.lorprev` file may contain elements and attributes that the MSB parser does not consume.

These must not automatically be classified as irrelevant.

During a new-version review, all additions, removals, hierarchy changes, and attribute changes should be recorded, even when the current parser ignores them. A newly added element can indicate that LOR moved information out of an old structure or introduced a new relationship that changes the meaning of data the parser already consumes.

## Structural Assumptions That Can Break the Parser

The highest-risk assumptions are:

1. A PreviewClass can still be found by tag name.
2. Preview identity remains in `PreviewClass.id`.
3. Prop objects remain identifiable as `PropClass`.
4. `PropClass.id`, `Name`, and `Comment` retain their current meanings.
5. ChannelGrid retains a parseable wiring representation.
6. ChannelGrid DeviceType-specific meanings remain stable.
7. explicit Channel Grid Row ordering remains meaningful within a PropClass.
8. `DeviceType` values retain their current meanings.
9. `MasterPropId` retains its parent relationship semantics.
10. preview-level Scenes remain available in `.lorprev` exports.
11. Scene-to-Prop membership remains positionally recoverable from document order.
12. Scene and Prop identities remain stable enough to resolve positional Scene rows to materialized records.

A parser run that completes successfully does not prove that these assumptions still hold.

## Recommended Baseline Test Preview

For future LOR-version comparisons, maintain or create a representative baseline preview containing examples of every parser-sensitive structure:

- ordinary single-grid LOR prop;
- multi-grid LOR prop with individual channels;
- multi-grid one-plug LOR prop;
- manually related MasterPropId/subprop example;
- SPARE channel example;
- DMX prop with multiple explicit Channel Grid Rows;
- grouped DMX example with multiple PropClasses sharing one Display Name but different Channel Names;
- representative dense-RGB compact ChannelGrid example retained for review even while its expansion semantics remain unresolved;
- DeviceType=None single inventory object;
- DeviceType=None physical fan-out object;
- blank-comment layout helper;
- preview-level Scenes;
- a Scene with null/non-stage classification;
- sub-stage naming such as `07a`;
- Show Animation naming;
- background image references;
- tags and representative Parm fields.

The most useful comparison is the **same logical preview exported from both the known-good LOR release and the new release**. That minimizes false differences caused by authoring changes.

## Compatibility Review Output

When a new `.lorprev` version is examined, update a comparison record containing at least:

| Area | Existing baseline | New version | Changed? | Parser impact | Action |
|---|---|---|---|---|---|
| PreviewClass | | | | | |
| Scene | | | | | |
| PropClass | | | | | |
| ChannelGrid | | | | | |
| DeviceType | | | | | |
| MasterPropId | | | | | |
| DMX | | | | | |
| Scene membership ordering | | | | | |
| Identity behavior | | | | | |

Use the controlled procedure in [LOR Preview Version Compatibility Review](LOR_Preview_Version_Compatibility_Review.md).

## Approved Baseline Manifest

The approved baseline is no longer limited to the parser's consumed fields.
`lor_version_checker.py` creates a complete machine-readable manifest from all
approved previews and stores the deep-preview contract. The Windows runner
preserves that manifest with the Current LOR version record.

Reverse-engineering discoveries affecting this specification must follow the reusable [Documentation Maintenance Rule](../../../System_Documentation/Standards/Documentation_Maintenance_Rule.md).

## Revision History

| Date | Author | Change |
|---|---|---|
| 2026-08-21 | GAL / OpenAI | Documented the controlled XML-to-MSB naming translation, DeviceType-dependent ChannelGrid field meanings, local Channel Grid Row Number rule, compact dense-RGB ChannelGrid evidence/uncertainty, grouped-DMX source-detail limitation, and proposed additive provenance boundary while retaining V7.0.10 as the implementation baseline. |
| 2026-08-13 | GAL / OpenAI | Established the complete all-preview XML manifest, V7.0.8 ownership path, and parser-independent compatibility authority. |
| 2026-08-08 | GAL / OpenAI | Created the standalone reverse-engineered `.lorprev` structure specification from the functional V7.0.7 parser and documented the structural assumptions required for future LOR-version compatibility review. |