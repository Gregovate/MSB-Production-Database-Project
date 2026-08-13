# LOR Preview Parser Architecture

| Document control | Value |
|---|---|
| Status | CURRENT — engineering architecture |
| System | LOR Preview Parser / LOR2DB Ingest |
| Functional baseline | `parse_props_v7_scene_parser.py` V7.0.8 |
| Current revision | 2026-08-13 |
| Owner | MSB Database Administrator |

## Purpose

This document defines the engineering architecture and processing rules implemented by the MSB Light-O-Rama preview parser.

The parser converts approved Light-O-Rama `.lorprev` preview files into a complete, disposable SQLite snapshot used by the LOR2DB ingest process. This document exists so the engineering decisions behind the parser are not dependent on comments inside Python source code or developer memory.

The current implementation is:

`Docs/01_LOR_System/02_Data_Extraction/Parser/parse_props_v7_scene_parser.py`

The initial content was derived from V7.0.7. V7.0.8 adds the website-runner
contract, atomic publication, full output validation, and complete provenance.
Future parser changes must be reviewed against this architecture.

## System Boundary

The parser is the boundary between the Light-O-Rama preview-file format and the structured MSB data pipeline.

```text
Approved .lorprev files
        |
        v
LOR Preview Parser
        |
        v
lor_output_v7_scene.db
        |
        v
LOR2DB PostgreSQL Ingest
        |
        v
immutable lor_snap snapshot
        |
        v
LOR2DB reconciliation
```

The parser understands Light-O-Rama preview structure. PostgreSQL ingest does not parse `.lorprev` XML; it consumes the SQLite snapshot produced by this parser.

## Core Engineering Principles

### Complete snapshot

Every parser run rebuilds the SQLite database from the complete approved preview set. The SQLite database is disposable working data, not a historical database.

A new run therefore represents one complete parser snapshot rather than a set of incremental edits.

### Source files are read-only

The parser reads `.lorprev` files. It does not modify the approved preview files.

The approved preview source is controlled separately from the parser. The source folder used for a production snapshot is preserved as parser provenance and is later carried into the LOR2DB workflow.

### Physical display identity is not scene identity

A Light-O-Rama Scene is a sequencing or presentation workspace. A Scene is not a physical display and does not replace the Preview or Prop identity model.

The parser therefore preserves the global PreviewClass/PropClass universe and adds Scene membership as a separate relationship.

### Preserve LOR source identity

The parser maintains two different identities for materialized props:

- the exact or occurrence-qualified LOR source identity in `RawPropID`;
- the parser-scoped relational identity in `PropID` or `SubPropID`.

These identities serve different purposes and must not be collapsed into one field.

### Fail rather than silently corrupt identity

Ambiguous or unresolved identity conditions are treated as errors. Examples include PropID collisions, missing raw identities, unresolved nonblank Scene members, duplicate Preview identities, and ambiguous physical inventory masters.

The parser is intentionally conservative because silent data corruption would flow into PostgreSQL reconciliation and permanent production identities.

## Naming Contract

The parser preserves the following LOR-to-MSB meanings:

| LOR source | Parser field | MSB meaning |
|---|---|---|
| `PreviewClass.id` | `previews.id` | Preview identity |
| `PreviewClass.Name` | `previews.Name` | Preview/operator name |
| `PreviewClass.BackgroundFile` | `previews.BackgroundFile` | Preview background reference |
| `PropClass.id` | `RawPropID` | LOR source PropClass identity |
| scoped/materialized PropClass identity | `PropID` / `SubPropID` | Parser relational identity |
| `PropClass.Comment` | `LORComment` | Display Name |
| `PropClass.Name` | `Name` | Channel Name / sequencer label |
| `PropClass.DeviceType` | `DeviceType` | LOR, DMX, or None |
| `ChannelGrid` data | wiring columns | network/controller/channel data |

The parser does not treat the LOR channel `Name` as the physical Display Name. The physical Display Name is derived from the LOR `Comment` field.

That distinction is a core contract shared with Preview Authoring and downstream database logic.

## Preview Discovery and Preflight

The production parser works on a folder containing `.lorprev` files.

Before the SQLite schema is rebuilt, preflight validation is intended to detect structural or identity conditions that would make the snapshot unsafe. Current V7 behavior preserves the V6.8.3 guardrails including:

- Preview UUID uniqueness across the input set;
- duplicate PropClass GUID detection within a preview;
- ambiguous `DeviceType=None` master detection;
- visibility of the number of `.lorprev` files discovered.

Preflight must occur before destructive SQLite setup so a bad input set does not replace the previous usable snapshot with a partially built database.

## PreviewClass Processing

The parser searches the XML tree at any depth for an element whose tag ends in `PreviewClass`. This allows namespace-qualified and non-qualified tag names.

For each preview the parser materializes:

- Preview ID;
- Stage ID derived from the preview name;
- preview Name;
- Revision;
- Brightness;
- BackgroundFile;
- exact source filename.

`SourceFilename` is important audit evidence. It allows the parser snapshot and later reconciliation report to identify the exact `.lorprev` file used for each preview row.

## Stage Identification

Stage identity is derived from preview and Scene names rather than maintained as a separate LOR object.

The current parser accepts the established MSB stage conventions:

- `NN` prefix forms;
- `NNa` sub-stage prefix forms;
- names containing `Stage NN`;
- names containing `Stage NNa`;
- Show Animation names containing a one- or two-digit animation stage number.

Numeric stage values are normalized to two digits and an optional alphabetic suffix is retained in lowercase.

Examples include `07`, `07a`, `17`, and `90`.

If no valid stage token exists, the parser leaves StageID null rather than inventing one.

## PropClass Materialization

Light-O-Rama PropClass rows are not copied blindly one-for-one into `props`. The parser materializes the XML into physical-display and wiring records according to the engineering rules below.

### Standard LOR props

For channel-based LOR props, the parser establishes one canonical physical display master in `props` and places subordinate wiring components in `subProps` when required.

The physical grouping logic uses the Display Name (`LORComment`) where the LOR structure represents several wiring rows as one physical display.

Canonical master selection is deterministic. The current reconciliation helper favors the lowest controller identity/channel ordering within the preview/display grouping so repeat runs produce the same master relationship.

### SPARE rows

Rows intentionally identified as spare channels are not grouped into another physical display merely because names or comments overlap. Spare-channel handling remains a special case to prevent unused channel definitions from altering inventory identity.

### Manual subprops

LOR rows carrying `MasterPropId` represent an explicit LOR parent-child relationship.

The parser preserves the useful physical distinction rather than blindly treating every manual subprop as non-inventory. Where a manually related row represents a separately named physical item, parser materialization can promote the appropriate record to a `props` master while retaining additional legs/components as `subProps`.

Missing subordinate grid data may inherit the master's wiring data where the LOR structure indicates that the subordinate item uses the same channels.

### Multi-grid LOR props

One LOR PropClass can contain multiple wiring legs.

The parser preserves one physical master in `props`. When `IndividualChannels` indicates separately meaningful legs, those legs are materialized in `subProps` with their own wiring values.

When `IndividualChannels` is false, the multiple grids represent one physical one-plug unit and are not automatically turned into separate physical inventory records.

Multi-grid grouping is based on the source PropClass identity rather than Display Name alone. This prevents unrelated props with reused comments from being merged together.

### DMX props

DMX is represented by a `props` master plus channel/universe rows in `dmxChannels`.

The parser preserves the parent display identity while splitting multiple DMX wiring legs into their channel records.

Several XML DMX components that describe one physical display may resolve to one canonical display master. Scene membership is therefore resolved against the materialized display identity, not assumed to be one XML row equals one production display.

### DeviceType=None

`DeviceType=None` represents non-wired or otherwise undetermined LOR inventory/layout objects and requires special handling.

The parser distinguishes physical inventory from layout helpers and supports materialized physical fan-out when one LOR source object represents multiple physical instances.

For a fanned-out source, each physical occurrence receives:

- its own materialized `PropID`;
- an occurrence-qualified `RawPropID` using `-01`, `-02`, and subsequent suffixes;
- a separately materialized physical row.

The unsuffixed LOR UUID is preserved only when the source materializes as one non-fanned record.

Blank-comment `DeviceType=None` layout helpers are not treated as physical Scene display members.

## Identity Model

### RawPropID

`RawPropID` preserves the LOR source PropClass UUID or the physical occurrence identity derived from that UUID.

For normal materialized records it is the source XML `PropClass.id`.

For physical fan-out it becomes the source UUID plus an occurrence suffix such as `-01` or `-02`.

`RawPropID` is the identity handed downstream so reconciliation can distinguish source identity changes from stable MSB production display identity.

### PropID and SubPropID

LOR can reuse a raw PropClass UUID in different previews. The parser therefore uses preview-scoped relational identifiers for its working database.

Conceptually:

```text
<PreviewId>:<RawPropId>
```

These scoped identifiers protect SQLite relationships from cross-preview collisions.

The scoped parser key is not a replacement for RawPropID and is not the permanent production `display_id`.

### Permanent production identity

Permanent display identity is established and maintained downstream in PostgreSQL. The parser must never infer that a changed LOR UUID means a physical display is automatically a new production display.

That decision belongs to LOR2DB reconciliation.

## Scene Architecture

### Preview-level Scenes

Only preview-level Scenes contained in the `.lorprev` file are database-authoritative for this pipeline.

Sequence-level Scenes are sequencing helpers and are intentionally excluded because they are not part of the approved Preview export contract used to build the production snapshot.

The `scenes` table preserves every preview-level LOR `<Scene>` row. Its row
count is therefore a raw LOR count, not the count of operational documentation
Scenes. Folder Alignment owns the separate deterministic classification:

- `NN-Name-XY` — Stage root;
- `NNa-Name-XY` — Sub-stage root;
- `NN-Name` or `NNa-Name` — true Scene/documentation group;
- unprefixed non-`Root` name — Display or shared Display/group locator;
- `Root` — owning Background Preview Stage marker where that rule applies.

These classifications are hooks for wiring, setup, takedown, and inspection
procedure discovery. They do not change parser extraction or physical display
identity.

### Positional Scene structure

LOR V6.6 preview Scenes are represented by Scene markers followed by PropClass rows.

The parser therefore reads the XML in document order:

1. encounter a Scene marker;
2. make it the current Scene;
3. assign following PropClass rows to that Scene;
4. continue until the next Scene marker.

Scene membership is positional; the parser does not require each PropClass to contain a Scene foreign-key attribute.

### Scene metadata

The `scenes` table stores the LOR Scene identity and useful presentation metadata including:

- SceneID;
- PreviewId;
- derived StageID;
- Name;
- derived SceneSection;
- BackgroundFile;
- HScroll;
- VScroll;
- Zoom;
- CreateGridView.

A null Scene StageID is valid for miscellaneous/default Scenes.

### Scene membership resolution

Raw positional XML membership is not written directly into production-facing relationships.

The parser resolves each Scene PropClass against the records actually materialized in `props` or `subProps`.

This is required because one XML row can fan out into several physical records, several DMX XML components can consolidate onto one master, and layout helpers may not represent inventory.

`scene_lor_props` stores the resolved current membership and includes:

- PreviewId;
- materialized PropID;
- materialized RawPropID;
- SceneID;
- PreviewStageID;
- SceneStageID;
- positional ordinal;
- role/source metadata.

`UNIQUE (PreviewId, PropID)` prevents the same materialized prop from being assigned to multiple Scenes in one preview snapshot.

If a nonblank Scene PropClass cannot be resolved to a materialized record, the parser fails rather than silently dropping it.

## SQLite Snapshot Schema

Every run builds a new sibling temporary database. It recreates the
parser-owned objects inside that build, runs every audit, executes every
published view, and atomically replaces the requested SQLite file only after
validation passes. Failure preserves the last known-good published SQLite.

### `parser_run`

Contains provenance for the single current parser execution:

- ParserVersion;
- StartedAt;
- CompletedAt;
- Actor;
- HostName;
- SourcePreviewFolder;
- SQLiteDatabasePath;
- Status.
- RunMode (`PRODUCTION`, `VERSION_CHECK`, or `TEST`);
- SourceLORVersion;
- ParserSHA256;
- SourceManifestSHA256;
- CompatibilityManifestSHA256 (the approved complete XML contract);
- ValidationStatus and ValidationDetail.

Because the SQLite file is disposable, parser_run intentionally contains only the provenance for the current snapshot.

### `previews`

One row per parsed PreviewClass, including source filename and derived StageID.

### `props`

Materialized display masters and their relevant LOR attributes and wiring fields.

### `subProps`

Materialized subordinate components linked to a props master while retaining their own raw identity and wiring information.

### `dmxChannels`

DMX wiring legs/universe-channel data linked to the materialized prop master.

### `scenes`

Preview-level Scene/workspace metadata.

### `scene_lor_props`

Resolved current Scene-to-materialized-prop membership.

## Wiring and Reporting Views

The parser preserves the established wiring/reporting contract used by FormView and other downstream workflows.

The legacy `_v6` view names remain compatibility dependencies even though the current parser is V7 and the current SQLite database is scene-aware.

These compatibility names do not make the V6 parser current.

The parser also creates Scene validation/reporting views including the current Scene membership and display-level Scene reporting contract.

Business-facing reporting should consume `scene_displays_vw` rather than
treating raw `scene_lor_props` PropID membership as a Directus business object.
That view publishes `SceneBackgroundFile`, `PreviewBackgroundFile`, and the
effective `BackgroundFile` so missing-path audits remain available without
losing the source level.

## Parser Provenance

The parser records enough information for the PostgreSQL ingest to prove where a snapshot came from:

- parser version;
- parser start and completion time;
- operating-system actor;
- workstation/host;
- source preview folder;
- SQLite database path;
- parser completion status;
- source `.lorprev` filename for each preview.

The PostgreSQL ingest must consume this provenance rather than reconstructing or guessing it later.

## Validation and Fail-Fast Rules

The parser is expected to stop or fail the run when data cannot be materialized safely.

Critical safeguards include:

- duplicate Preview UUID preflight;
- duplicate PropClass identity detection within a preview;
- PropID collision detection;
- ambiguous physical-master detection;
- nonblank RawPropID requirement on every `props` and `subProps` row;
- unresolved nonblank Scene member failure;
- final Scene-membership integrity audit;
- deterministic rebuilding of Scene membership to prevent stale assignments.

Collision and diagnostic reports exist to make failures reviewable rather than hidden.

## Relationship to LOR2DB Ingest

The parser's output is the input contract to `LOR2DB/01_Ingest/postgres_ingest_from_lor_sqlite_v7.py`.

The parser is responsible for interpreting LOR structure and producing normalized SQLite data.

The PostgreSQL ingest is responsible for copying the completed parser snapshot and its provenance into append-only `lor_snap` storage.

The ingest must not reinterpret `.lorprev` XML or replace parser identity logic.

## Relationship to Reconciliation

The parser and ingest create source evidence. They do not decide permanent production identity changes.

LOR2DB reconciliation compares the immutable snapshot with current production data, records operator decisions where required, and controls production promotion.

In particular, a changed RawPropID with the same physical display can be reconciled without creating a new permanent display identity.

## Compatibility Contract

The current functional baseline was developed and validated against the LOR 6.6.4 preview format.

A newer LOR version must not be assumed compatible merely because the parser runs without raising an exception. Structural changes can cause silent omissions or different materialization.

Every new LOR release must be reviewed using:

- [LOR Preview File Structure Specification](LOR_Preview_File_Structure_Specification.md)
- [LOR Preview Version Compatibility Review Procedure](LOR_Preview_Version_Compatibility_Review.md)

## Change-Control Rule

Changes to any of the following require engineering review and corresponding documentation updates:

- LOR XML element/attribute interpretation;
- naming contract;
- stage extraction;
- prop/subprop materialization;
- DeviceType handling;
- raw/scoped identity rules;
- Scene interpretation or membership resolution;
- SQLite table contract;
- parser provenance;
- validation/fail-fast behavior;
- compatibility views consumed downstream.

Do not change these behaviors solely to accommodate one unusual preview without first deciding whether the source preview is wrong or the architecture genuinely needs to change.

## Revision History

| Date | Author | Change |
|---|---|---|
| 2026-08-13 | GAL / OpenAI | Documented V7.0.8 atomic publication, full output validation/provenance, canonical ownership, background-path view fields, and the Folder Alignment/raw Scene-row boundary. |
| 2026-08-08 | GAL / OpenAI | Created standalone V7 parser engineering architecture from the functional V7.0.7 implementation and preserved V7 design decisions previously embedded in source comments and project history. |
