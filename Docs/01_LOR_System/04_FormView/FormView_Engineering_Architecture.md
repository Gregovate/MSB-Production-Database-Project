# FormView Engineering Architecture

| Document control | Value |
|---|---|
| Status | ACTIVE — recovered engineering contract |
| System | FormView |
| Current application version | 0.3.1 |
| Proven production data model | V6 SQLite |
| V7 status | Compatibility intended, not yet operationally validated |

## Purpose

This document records the recovered engineering design and compatibility contract of FormView.

FormView was the working MSB field-documentation system used during the 2025 setup season. It predates the PostgreSQL production architecture and must be understood on its own terms.

FormView combines two authoritative inputs:

1. structured Light-O-Rama Preview data materialized into SQLite by the LOR parser; and
2. Stage wiring images stored in the established Stage filesystem and located through the Preview `BackgroundFile` path.

It converts those inputs into practical field wiring information, on-screen visual references, CSV exports, and disposable printable HTML documents.

FormView is not part of PostgreSQL ingest and does not depend on PostgreSQL.

## System Role

Within the LOR system, the major responsibilities are separate:

```text
Individual programmer previews
        |
        v
Preview Merger
approval / merge control
        |
        v
Approved official previews
        |
        v
Data Extraction / Parser
        |
        +--------------------------+
        |                          |
        v                          v
SQLite wiring data          PostgreSQL ingest
        |
        v
FormView
        |
        v
Field wiring documentation
```

The parser is the interpretation layer for LOR data. FormView is the interpretation and presentation layer for Wiring.

## Original Design Intent

FormView was created to answer the practical field question:

> What does a setup technician need to see in order to connect the physical Displays to the correct controllers and channels?

The LOR data model contains more detail than a field technician normally needs. It includes Props, SubProps, programming relationships, shared circuits, tags, device metadata, and other information necessary for sequencing and engineering.

FormView deliberately reduces and presents that information in a field-oriented form while retaining access to the full detailed wiring view when internal/controller-panel work requires it.

The application also binds the electrical information to the Stage wiring drawings so the technician can see both the connection table and a visual map of where the named channels are located.

## Historical Implementation

The current source revision history confirms the following development sequence.

### August 2025

FormView began as a Tkinter wiring viewer for the parser-produced `lor_output_v6.db` database.

Early functionality included wiring inspection, sorting, CSV export, spare suppression, and display filtering.

### October 15, 2025

Version 0.2.0 added **Field wiring mode** for per-Stage field leads.

This established the important distinction between:

- practical field connections; and
- the fuller internal/shared wiring relationships represented in LOR.

### October 23, 2025

Printable HTML was added with the Preview background image taken from `previews.BackgroundFile` and embedded into the generated document.

The same development period added:

- the Stage / Preview-oriented interface;
- visible image-path information;
- controller/channel-oriented default sorting; and
- Open Folder behavior.

### October 28–31, 2025

The wiring UI was refined for field clarity.

The application added:

- on-screen background images;
- Show Image control;
- image scaling;
- multiple-image paging and navigation; and
- additional wiring images in printable output.

### October 30, 2025

Stage View was implemented.

### November 5, 2025

Programming View was implemented using the same Stage / Preview selection pattern.

## Primary Data Flow

The recovered data flow is:

```text
LOR Preview
    |
    | Preview metadata
    | Prop / SubProp / DMX wiring
    v
LOR parser
    |
    +--> previews
    |      - id
    |      - Name
    |      - StageID
    |      - Revision
    |      - BackgroundFile
    |
    +--> props / subProps / dmxChannels / groups
    |
    +--> parser-created wiring and Stage views
            |
            v
         FormView
            |
            +--> Stage / Preview selection
            +--> BackgroundFile lookup
            +--> wiring-image discovery
            +--> field-wiring reduction
            +--> CSV export
            +--> printable HTML
```

## Stage / Preview Picker

The **Stage / Preview** picker is FormView's primary operating-context selector.

The picker is populated from:

```sql
SELECT Name
FROM previews
ORDER BY Name COLLATE NOCASE;
```

Therefore the operator is selecting an LOR Preview name, not directly selecting a Stage filesystem folder.

That selected Preview provides the context for both:

- the structured wiring rows; and
- the filesystem relationship through `BackgroundFile`.

The same Preview-selection pattern is reused by Programming View.

## Operational Preview Types

Two Stage Preview types matter significantly to field use:

- **Show Background Stage**
- **RGB Plus Prop Stage / Musical Stage context**

These represent different Stage wiring contexts. A technician who selects the wrong Preview type may correctly see a valid wiring table that does not contain the Display they expect to install.

Therefore the Preview type is part of the operational identity, not merely a naming preference.

## `BackgroundFile` Contract

The LOR Preview stores a `BackgroundFile` path. The parser carries that value into `previews.BackgroundFile`.

FormView resolves the selected Preview with a lookup equivalent to:

```sql
SELECT BackgroundFile
FROM previews
WHERE Name = ? OR StageID = ?
LIMIT 1;
```

The selected `BackgroundFile` performs several roles:

1. it identifies the primary visual wiring image;
2. its containing directory becomes the active published wiring-image directory;
3. it supplies the path shown in the FormView UI;
4. it supplies the directory used by Open Folder; and
5. it provides the starting point for additional-image discovery.

This means `BackgroundFile` is not merely LOR cosmetic metadata. It is a filesystem locator in the field-documentation architecture.

## Stage Wiring Filesystem Contract

A typical Stage structure is:

```text
G:\Shared drives\Display Folders\StageID-StageName-Prefix\
└── Wiring\
    ├── BackgroundStage\
    │   ├── published field images
    │   └── SourceDocs\
    └── MusicalStage\
        ├── published field images
        └── SourceDocs\
```

FormView does not independently walk the entire Stage folder and decide whether the operator needs `BackgroundStage` or `MusicalStage`.

Instead:

```text
selected Preview
      |
      v
previews.BackgroundFile
      |
      v
parent directory of that image
      |
      v
active published wiring-image directory
```

Therefore the LOR Preview's external background path is what connects Preview identity to the correct wiring-documentation branch.

The recovered Preview Authoring procedure defines the operator side of this contract. This document defines the engineering side.

## Additional Image Discovery

The primary `BackgroundFile` is Page 1.

FormView searches the **same directory** for additional published images.

Supported image extensions are:

- `.jpg`
- `.jpeg`
- `.png`

If the primary filename contains a Stage token, FormView prefers files with the same Stage number. Its Stage-token matching accepts forms such as:

```text
Stage 21
Stage-21
Stage_21
Stage:21
```

The resulting image list is de-duplicated and alphabetically ordered with the primary background kept first.

FormView does not recursively scan `SourceDocs`.

### Consequence

The active `BackgroundStage` or `MusicalStage` published-image directory must remain clean. Extra or obsolete images can become visible or printable field-documentation pages.

Source and working material belongs under `SourceDocs` or another non-published location.

## Image Navigation

FormView maintains an ordered image-page list for the selected Preview.

The UI supports:

- previous image;
- next image;
- Page X/Y display;
- Show Image on/off;
- image scale from 0.2x to 2.0x; and
- keyboard navigation shortcuts.

The currently active image path is reflected in the Image field.

This allows dense or physically large Stages to use more than one drawing without creating a separate application workflow.

## Open Folder

Open Folder uses the currently displayed image path and opens its containing directory with the Windows shell.

Conceptually:

```text
G:\...\Wiring\BackgroundStage\SomeImage.jpg
        |
        v
G:\...\Wiring\BackgroundStage\
        |
        v
Windows Explorer
```

This is another reason the `BackgroundFile` path and published directory structure are contractual dependencies.

## SQLite Dependency Matrix

| FormView function | SQLite dependency | Type |
|---|---|---|
| Stage / Preview picker | `previews` | table |
| Background path/image | `previews.BackgroundFile` | table field |
| Standard Wiring View | `preview_wiring_sorted_v6` | view |
| Field Wiring View | `preview_wiring_fieldlead_v6` | view |
| Stage View | `stage_display_list_all_v1` | view |
| Programming Props | `props` + `previews` | tables |
| Programming Groups | `groups` + `previews` | tables |

## Parser-Created Wiring Views

The V6 parser creates the following wiring-view stack used by or supporting FormView:

```text
props + subProps + dmxChannels + previews
                |
                v
preview_wiring_map_v6
                |
                v
preview_wiring_sorted_v6
                |
                v
preview_wiring_fieldmap_v6
                |
                +--> preview_wiring_fieldlead_v6
                +--> preview_wiring_fieldonly_v6
                +--> preview_wiring_circuit_rollup_v6
```

### `preview_wiring_map_v6`

Base normalized wiring map combining master Prop, SubProp, and DMX materializations.

### `preview_wiring_sorted_v6`

Presentation-ready sorted wiring map. This is the source FormView uses when Field Wiring mode is off.

### `preview_wiring_fieldmap_v6`

Classifies/reduces the normalized wiring information into field/internal relationships.

### `preview_wiring_fieldlead_v6`

The primary FormView Field Wiring source.

It returns one lead row per practical **Display/circuit** relationship within the selected Preview.

This is intentionally more precise than saying "one row per controller channel." Multiple Displays may legitimately share the same physical circuit, so more than one Display row can remain on one controller/channel.

### `preview_wiring_fieldonly_v6`

Convenience field-only slice created by the parser. It is not the primary FormView Field Wiring query.

### `preview_wiring_circuit_rollup_v6`

Per-circuit audit/analysis rollup. It is parser support data rather than the normal FormView field display.

## Why Field Wiring Suppresses Rows

The detailed LOR model may contain multiple records that participate in one practical physical connection.

Those records may exist because of:

- SubProps;
- shared circuits;
- logical sequencing structure;
- internal Display wiring; or
- programming relationships.

Those relationships are useful when designing or building internal panel/Display wiring but are distracting to a setup technician whose job is to connect a Display to a controller.

Field Wiring therefore suppresses subordinate/internal rows while preserving one useful lead row for each Display/circuit relationship.

The normal production operating mode is **Field wiring mode ON**.

## Wiring View Columns

The on-screen Wiring View uses:

```text
Controller
StartChannel
Channel_Name
Display_Name
Network
Source
ConnectionType
DeviceType
LORTag
```

The practical meanings are:

### Controller

The LOR controller UID / Unit Identifier.

### StartChannel

The controller channel / plug number used for the connection.

### Channel_Name

The LOR sequencer channel name. The visual wiring drawing uses these names to identify physical locations.

### Display_Name

The physical Display identity. This is necessary because one controller may serve multiple Displays.

### Network

The LOR network that must be assigned to the controller.

### Source

Metadata identifying the underlying source relationship, such as `PROP` or `SUBPROP`.

### ConnectionType

Field/internal classification metadata.

### DeviceType

Device metadata derived from LOR.

### LORTag

Sequencing/programming metadata. It is useful as a secondary engineering cross-check but is not normally needed by the setup crew.

## Wiring View Filters

### Field wiring mode

Default: ON.

When the required field-lead view exists, FormView reads `preview_wiring_fieldlead_v6`.

If Field Wiring is turned off, FormView reads the full `preview_wiring_sorted_v6` map and shows the detailed relationships.

If the selected database does not contain the field-lead view, FormView falls back to the standard map and warns the user that the field helpers are missing.

### Displays only

Applies:

```text
Source = 'PROP'
```

This narrows the result to master Display/Prop rows and can help identify which controller belongs to which Display when a Stage contains many controller relationships.

### Hide SPAREs

Default: ON.

Suppresses rows whose Display Name or Channel Name contains `SPARE`.

Spare channels are intentionally unused controller/sequencer channels and must not be treated as field connections.

## Sorting

The default field-oriented sorting is Controller, then StartChannel, then Display Name.

Controller sorting is hexadecimal-aware.

Clicking the Controller or Channel headings changes the sort while retaining deterministic tie-breaking.

This reflects the way a technician typically works through a physical controller one plug/channel at a time.

## Stage View

Stage View is a separate read-only reporting function.

It consumes:

```text
stage_display_list_all_v1
```

The parser builds that view from a Stage reporting stack that includes:

```text
stage_display_assets_v1
stage_display_inventory_only_v1
stage_display_assets_all_v1
stage_display_list_all_v1
```

Stage View groups information by Stage, then Preview, then Display and identifies inventory-only records that have no wiring.

It can export a printable Stage display listing.

## Programming View

Programming View was added later and uses the same Stage / Preview selection concept.

Unlike Wiring View and Stage View, Programming View does not depend on a dedicated parser reporting view. It directly queries:

- `props` joined to `previews`; and
- `groups` joined to `previews`.

It presents Stage ID, Stage Name, record type, name, and tag and can export CSV or printable HTML.

Programming View extends FormView but does not redefine the wiring architecture.

## CSV Export

CSV export writes the currently displayed Wiring View rows and full on-screen column set to a spreadsheet-compatible file.

The CSV reflects the current Preview and current filter mode. Therefore a CSV exported with Field Wiring enabled is different from a CSV exported with Field Wiring disabled.

CSV is useful for engineering review and analysis. It is not the normal field-installation document.

## Printable Wiring HTML

Printable HTML is the field-document output.

The document contains:

- selected Preview name;
- exact generation timestamp;
- current image path;
- current/primary image;
- additional discovered wiring images when present;
- field wiring table;
- row count; and
- database path used to generate the output.

The printable wiring table deliberately omits some of the richer UI metadata. Current HTML output hides:

- `LORTag`
- `ConnectionType`

The normal printed table therefore emphasizes:

```text
Controller
StartChannel
Channel_Name
Display_Name
Network
Source
DeviceType
```

### Embedded primary image

The currently selected primary image is read from disk and Base64-encoded into the HTML as a data URI.

This makes the primary image self-contained inside the saved HTML document.

### Additional images

Additional discovered images are added before the wiring table as separate figures/pages when more than one image exists for the Preview.

The current source builds those additional image tags from the discovered file paths. The generated document therefore depends on those additional files remaining accessible when the HTML is rendered unless/until this behavior is changed and validated.

This distinction should be preserved in future maintenance: the primary image is explicitly Base64-embedded; the additional-image helper currently emits file-based image references.

## Disposable Document Lifecycle

Printable HTML and hard-copy output are **temporary field working documents**, not permanent records.

The document prints a prominent warning equivalent to:

```text
Printed: <timestamp> — Use immediately. Discard if not printed "today".
```

The footer also states that paper copies expire as soon as a new database build or Preview merge occurs.

Operational intent:

- do not laminate the wiring printout;
- do not archive it as permanent wiring instructions;
- do not reuse an old copy during a later setup;
- generate a current copy when needed; and
- discard the hard copy when setup work is complete.

This ensures that LOR changes propagate into newly generated field instructions instead of technicians relying on stale wiring paperwork.

Any replacement must preserve a clear stale-document mechanism.

## Current Deployment Architecture

FormView is a Windows desktop application written in Python/Tkinter and packaged with PyInstaller as:

```text
FormViewSA.exe
```

The canonical deployed executable is:

```text
G:\Shared drives\MSB Database\Apps\FormView\current\FormViewSA.exe
```

Production users start the application with `FormViewApp.bat`.

The launcher:

1. requires a mapped `G:` drive;
2. verifies the production SQLite database exists;
3. verifies the canonical shared executable exists;
4. copies/updates **the executable** into `%LOCALAPPDATA%\MSB\FormView\`;
5. enforces a single running FormView instance; and
6. launches the cached executable.

The launcher does **not** currently copy the SQLite database locally.

## Database Selection and Testability

FormView resolves a database in this order:

1. `MSB_DB_PATH` environment variable when present and valid;
2. the standard production shared-drive path;
3. a `lor_output_v6.db` located beside the script/executable; or
4. an operator file-picker selection.

The Wiring View also provides **Choose DB...** so another SQLite model can be selected deliberately for testing.

Production operation must use the current approved production SQLite database.

The database picker is important because it allows compatibility testing without changing the application first.

## Current Production Limitation

FormView requires a Windows workstation with access to the MSB `G:` shared drive.

The production data source is currently:

```text
G:\Shared drives\MSB Database\database\lor_output_v6.db
```

The wiring images referenced by `BackgroundFile` also resolve through the Stage shared-drive filesystem.

Therefore the current system has significant field limitations:

- Windows-only client;
- mapped-drive dependency;
- direct SQLite-file dependency; and
- direct filesystem dependency for Stage wiring assets.

These limitations are architectural constraints of the current application, not defects in the field-wiring logic itself.

## V6 / V7 Compatibility State

### V6

V6 is the proven FormView production model.

FormView was used successfully during the 2025 setup season against the V6 SQLite database and `_v6` wiring views.

### V7

The V7 scene parser was designed to preserve the established wiring materialization and FormView compatibility while adding scene-aware data.

Equivalent wiring views exist in the V7 scene-aware SQLite output.

However, FormView has **not yet been operationally tested against V7**.

Therefore the accepted status is:

```text
V6: proven / production-used
V7: compatibility intended / not validated
```

Do not describe V7 compatibility as complete until an end-to-end FormView validation has been performed.

## Required V7 Compatibility Test

Before FormView is pointed to a V7 database for production use, validate at minimum:

1. Choose DB opens the V7 SQLite file.
2. Stage / Preview picker populates correctly.
3. Show Background and RGB Plus/Musical Stage contexts remain distinct.
4. `BackgroundFile` resolves correctly.
5. primary image displays.
6. additional image discovery and paging work.
7. Open Folder opens the correct published-image directory.
8. standard Wiring View works.
9. Field Wiring mode produces the expected reduced Display/circuit rows.
10. Displays Only works.
11. Hide SPAREs works.
12. sorting remains correct.
13. Stage View works.
14. Programming View works.
15. CSV export works.
16. printable HTML works.
17. printed row counts and controller/channel relationships match known-good expectations.

Only after this test passes should V7 be called validated for FormView.

## Authority Boundaries

### LOR owns

- Preview identity and name;
- Preview revision;
- `BackgroundFile` reference;
- controller assignments;
- channel assignments;
- network/DMX topology;
- Prop/SubProp relationships; and
- sequencing/programming structure.

### Stage wiring filesystem owns

- published wiring images;
- visual installation information;
- source engineering drawings; and
- supporting field-reference material.

### Parser owns

- LOR extraction;
- normalization;
- SQLite table materialization;
- wiring views;
- field-wiring derivation; and
- Stage reporting views.

### FormView owns

- database selection;
- Stage / Preview selection;
- field-oriented presentation;
- filters and sorting;
- image navigation;
- Open Folder convenience;
- CSV export; and
- disposable printable HTML generation.

FormView is not the authority for controller/channel assignment and must not reinterpret or silently correct LOR wiring.

## Contractual Dependencies Versus Conventions

### Contractual dependencies

- Preview identity;
- Stage / Preview naming distinction used operationally;
- `previews.BackgroundFile`;
- external Preview background path;
- correct `BackgroundStage` / `MusicalStage` published-image directory relationship;
- clean published-image directory;
- SQLite tables and views listed in this document;
- Windows/shared-drive access in the current application; and
- disposable-current-state print behavior.

### Supporting conventions

The exact authoring tools used to create the wiring image are not part of the FormView contract.

Draw.io, PaintShop Pro, Inkscape, GIMP, photographs, or other tools may be used as long as the resulting published images satisfy the filesystem contract.

## Future Replacement Objective

The planned successor is intended to preserve the proven FormView wiring behavior while removing the field user's dependency on Windows, a mapped `G:` drive, and direct SQLite access.

The intended access model is:

```text
Browser / tablet / phone
        |
        v
my.sheboyganlights.org
        |
        v
PostgreSQL-backed application
        |
        +--> current wiring data
        +--> Stage/document relationships
```

This is a replacement objective, not the historical FormView architecture.

A future system must not be considered equivalent merely because it can display a wiring table.

## Replacement Requirements

Any future replacement must preserve or deliberately migrate the following proven behavior:

1. Stage / Preview as a clear operator context.
2. The Show Background versus RGB Plus/Musical Stage distinction.
3. Stable linkage between the selected Preview/Stage and the correct wiring documentation.
4. The `BackgroundFile` relationship or a controlled successor identity mapping.
5. Multiple supporting wiring images.
6. Clean separation between published field images and source/working files.
7. Field Wiring reduction of internal/shared relationships.
8. Preservation of legitimate multiple-Display shared circuits.
9. Controller UID and channel/plug oriented presentation.
10. Channel Name and Display Name as separate concepts.
11. Network visibility.
12. spare-channel suppression.
13. image navigation and usable image scaling.
14. practical access to related wiring-documentation assets.
15. CSV/data export where useful.
16. self-contained or equivalently portable field documentation.
17. conspicuous generation/currentness information.
18. a disposable field-document lifecycle that discourages stale permanent copies.
19. authoritative LOR/PostgreSQL data rather than ad-hoc manual transcription.
20. browser-based field access without requiring a mapped shared drive.

## Relationship to the Future Setup / Procedure System

This document does not define the future Setup/Procedure architecture.

It does establish a proven identity pattern:

```text
Stage / Preview identity
        |
        v
known Stage documentation context
        |
        v
purpose-specific field information
```

The future Setup/Takedown instruction system may reuse this principle through a different pipeline. That design should preserve the identity strengths demonstrated by FormView without rewriting FormView history as though PostgreSQL or Google Docs were part of the original 2025 implementation.

## Engineering Evidence

This recovered contract is based on:

- `LOR/FormView/FormView.py` current source and embedded revision history;
- `LOR/FormView/FormViewApp.bat`;
- FormView build scripts and application README;
- parser-created SQLite wiring and Stage views;
- October/November 2025 implementation history;
- the recovered Preview Authoring wiring-background procedure;
- a production FormView screenshot;
- detailed and Field Wiring printable HTML artifacts from Stage 21; and
- operator walkthrough of actual production use.

Where behavior is not proven, this document identifies it as unvalidated rather than assuming compatibility.

## Related Documents

- [FormView Operator Procedure](FormView_Operator_Procedure.md)
- [FormView subsystem portal](README.md)
- [Create Wiring Backgrounds for Stage Previews](../01_Preview_Authoring/D_Create_Wiring_Backgrounds..md)
- [LOR Data Extraction Engineering](../02_Data_Extraction/README.md)
- [FormView application/build README](../../../LOR/FormView/README.md)
