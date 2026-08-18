# FieldWiring Engineering Recovery and Compatibility Contract

| Document control | Value |
|---|---|
| Status | DRAFT — architecture recovery / implementation gate |
| Sub-project | FieldWiring |
| Predecessor | FormView 0.3.1 |
| Current revision | 2026-08-17 |
| Owner | MSB Database Administrator |
| Code/schema change status | HOLD until this recovery contract and data contract are reviewed |

## Purpose

This document records the recovered engineering contract that must be understood before replacing or extending FormView.

The replacement application is named **FieldWiring**. FieldWiring is intended to preserve the proven field-wiring behavior of FormView while removing the field user's dependency on a Windows desktop application, a mapped `G:` drive, and direct SQLite access.

This document is deliberately written before implementation. It does not authorize a schema change, a FormView change, or a web-application implementation.

## Current Project Decisions

The following decisions are accepted for this sub-project:

1. The replacement application is named **FieldWiring**.
2. FieldWiring must be accessible through a web browser and usable from practical field devices such as tablets and phones.
3. FormView remains an active transitional production application until FieldWiring has been proven against the current production workflow and an explicit cutover is accepted.
4. FieldWiring must not become an independent wiring/topology-authoring system. LOR remains authoritative for show wiring topology.
5. The Production Database is the intended operational data source for FieldWiring. A second independent operational SQLite database must not become the new source of truth.
6. No application-code or database-schema change is authorized by this recovery work alone.
7. Every printable/hard-copy FieldWiring report must display an explicit expiration date/time and must also be invalidated by a newer approved wiring data build or Preview merge.

## Recovery Evidence and Current Authorities

The recovery is based on the current repository implementation and controlled documentation, especially:

| Source | Role |
|---|---|
| `LOR/FormView/FormView.py` | Current FormView application behavior and query logic |
| `LOR/FormView/FormViewApp.bat` | Current deployment/launcher behavior |
| `LOR/FormView/README.md` | Application build/deployment contract |
| `Docs/01_LOR_System/04_FormView/FormView_Engineering_Architecture.md` | Recovered FormView engineering authority |
| `Docs/01_LOR_System/04_FormView/FormView_Operator_Procedure.md` | Current production operator workflow |
| `Docs/01_LOR_System/01_Preview_Authoring/D_Create_Wiring_Backgrounds..md` | Preview/background authoring and Stage-folder contract |
| `Docs/01_LOR_System/02_Data_Extraction/LOR_Preview_Parser_Architecture.md` | Current V7 parser contract |
| `Database/Basic_Query_Tools_Dev/postgres_create_views_lor_snap.sql` | Existing PostgreSQL wiring/reporting view implementation |
| `LOR2DB/02_Reconciliation/reconciliation/migrations/0020_expose_current_snapshot_provenance.sql` | Current snapshot/provenance interface |
| `Docs/02_Production_Database/01_System_Architecture/09_Wiring_System/README.md` | Production Database Wiring subsystem boundary |

The FormView engineering document remains the authority for historical/current FormView behavior. This document owns the FieldWiring conversion contract and does not replace the FormView history.

## Recovered FormView System Role

FormView is a read-only presentation application over parser-produced LOR data plus Stage wiring images.

The proven historical path is:

```text
Approved LOR Previews
        |
        v
LOR Preview Parser
        |
        +--> SQLite Preview / Prop / SubProp / DMX data
        |        |
        |        +--> wiring helper views
        |
        +--> Preview.BackgroundFile
                 |
                 v
         Stage Wiring filesystem
                 |
                 v
              FormView
                 |
                 +--> Wiring View
                 +--> Stage View
                 +--> Programming View
                 +--> CSV exports
                 +--> disposable printable HTML
```

FormView does not author controller/channel assignments. It presents and reduces LOR-authoritative wiring information into a field-usable form.

## Current FormView Source and Deployment

The current source is:

```text
LOR/FormView/FormView.py
```

The current application version is `0.3.1`.

It is a Python/Tkinter Windows desktop application packaged with PyInstaller as:

```text
FormViewSA.exe
```

The canonical production executable is documented as:

```text
G:\Shared drives\MSB Database\Apps\FormView\current\FormViewSA.exe
```

`FormViewApp.bat` checks the shared drive, production SQLite database, and canonical executable; copies the executable to a local per-user cache; enforces a single running instance; and launches that cached executable.

The launcher does not copy the production SQLite database locally.

## FormView Data Inputs

### SQLite database

FormView resolves its SQLite source in this order:

1. a valid `MSB_DB_PATH` environment variable;
2. `G:\Shared drives\MSB Database\database\lor_output_v6.db`;
3. a `lor_output_v6.db` file beside the script/executable; or
4. an operator-selected SQLite file.

The database selection capability is important for compatibility testing and must not be confused with production authority.

### Preview picker

The Wiring View Stage/Preview picker is populated by:

```sql
SELECT Name
FROM previews
ORDER BY Name COLLATE NOCASE;
```

The operator therefore selects an **LOR Preview**, not a Stage filesystem folder.

The selected Preview is the common context for both the wiring rows and the wiring-image relationship.

## Stage / Preview Context Is Operational Identity

At least two Preview contexts are operationally significant:

- **Show Background Stage**; and
- **RGB Plus Prop Stage / Musical Stage**.

They are not interchangeable views of the same data. A technician can choose the correct physical Stage but the wrong Preview context and therefore see valid wiring that does not contain the Display being installed.

FieldWiring must preserve this distinction in a field-friendly way. A future UI may group Preview choices under a Stage, but it must not collapse distinct Preview contexts into one ambiguous Stage result.

## `BackgroundFile` Resolution Contract

The selected Preview's wiring image is resolved by FormView with logic equivalent to:

```sql
SELECT BackgroundFile
FROM previews
WHERE Name = ? OR StageID = ?
LIMIT 1;
```

The returned path is normalized and becomes the primary image path.

The `BackgroundFile` value performs several jobs:

1. identifies the primary wiring image;
2. identifies the active published wiring-image directory through the image's parent directory;
3. drives the image displayed on screen;
4. drives the Open Folder action; and
5. establishes the starting directory for additional wiring-image discovery.

`BackgroundFile` is therefore an integration pointer, not merely Preview appearance metadata.

## Stage Wiring Filesystem Contract

The established Stage organization is typically:

```text
G:\Shared drives\Display Folders\<StageID>-<StageName>-<Prefix>\
└── Wiring\
    ├── BackgroundStage\
    │   ├── current published wiring images
    │   └── SourceDocs\
    └── MusicalStage\
        ├── current published wiring images
        └── SourceDocs\
```

FormView does not search the complete Stage tree to decide whether a Background or Musical wiring folder applies.

The actual resolution is:

```text
selected Preview
      |
      v
Preview.BackgroundFile
      |
      v
parent directory of that file
      |
      v
active published wiring-image directory
```

That relationship is the proven bridge between LOR Preview identity and the correct Stage documentation branch.

The published directory must remain separate from source/working material. `SourceDocs` is not part of the normal published image scan.

## Additional Wiring Image Discovery

The primary `BackgroundFile` is Page 1.

FormView then scans only the same directory for additional files with these extensions:

```text
.jpg
.jpeg
.png
```

If the primary filename contains a Stage token, the image scan is filtered to the same Stage number. The implemented token matching accepts separators such as spaces, hyphens, underscores, and colons around the Stage number.

If no Stage token is found in the primary filename, FormView falls back to the allowed images in that directory.

The final image list is de-duplicated, alphabetically ordered, and forced to keep the primary `BackgroundFile` first.

This behavior explains why obsolete or unrelated images must not be left in an active published wiring folder.

## Wiring Data Contract

FormView's normal detailed wiring source is:

```text
preview_wiring_sorted_v6
```

Its field-oriented source is:

```text
preview_wiring_fieldlead_v6
```

The field-lead view intentionally returns one practical lead row per:

```text
Preview + Network + Controller + StartChannel + Display
```

This is not the same as one row per controller channel. More than one physical Display may legitimately share a circuit, and those separate Display relationships must remain visible.

### Field Wiring mode

Field Wiring mode defaults ON.

When `preview_wiring_fieldlead_v6` exists, FormView uses it. If the helper is missing, FormView falls back to the detailed map and warns the operator.

The field reduction is therefore a data-contract feature, not merely a visual hide/show option.

### Displays only

The optional Displays-only filter applies:

```text
Source = 'PROP'
```

### Hide SPAREs

Hide SPAREs defaults ON and suppresses rows whose Display Name or Channel Name includes `SPARE`.

### Normal field columns

The Wiring View preserves these distinct concepts:

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

The most important field distinction is:

- `Channel_Name` = LOR/sequencer channel label used by the wiring drawing;
- `Display_Name` = physical Display identity/name derived from the LOR Comment.

FieldWiring must not merge those concepts.

### Sorting

Normal wiring work is controller/plug oriented.

The default order is:

```text
Controller -> StartChannel -> Display_Name
```

Controller sorting is hexadecimal-aware.

## Wiring Images and On-Screen Use

FormView supports:

- visible image path;
- primary and additional image paging;
- Page X/Y display;
- previous/next navigation;
- Show Image on/off; and
- image scaling from 0.2x through 2.0x.

These functions are part of the proven field workflow. FieldWiring does not need to copy the Tkinter controls literally, but the browser experience must provide equivalent practical access to multi-page wiring drawings and readable detail.

## Existing Output Behavior

### CSV

FormView exports the currently displayed rows and current filter context. CSV is an engineering/analysis convenience output rather than the normal hard field instruction.

### Printable wiring HTML

The Wiring View printable HTML includes:

- selected Preview;
- generated/printed timestamp;
- wiring image path;
- the selected/primary image;
- additional discovered images;
- simplified wiring table;
- row count; and
- database path.

The current primary image is Base64-embedded. Additional images are currently referenced with local `file:///` paths, so multi-image HTML is not completely self-contained.

That implementation detail should **not** be preserved as a limitation. FieldWiring hard reports must remain usable without a mapped drive and without depending on a workstation-local filesystem path.

### Current stale-document behavior

The current Wiring View report warns operators to use the print immediately and discard it if it was not printed on the current day. It also states that paper copies expire when a newer database build or Preview merge occurs.

This disposable-document principle is contractual.

## FieldWiring Hard-Report Expiration Requirement

Every FieldWiring hard report, including any printable HTML or PDF produced by the browser application, must show currentness information prominently.

At minimum, the report must display:

```text
Generated: <absolute local date/time>
Expires:   <absolute local date/time>
```

To preserve the present FormView semantics, the default hard-copy expiration is the end of the local calendar day on which it was generated.

A hard copy also expires immediately if a newer approved wiring snapshot or Preview merge supersedes the data before that time.

The report should therefore also identify enough source provenance to determine what generated it, such as the current LOR snapshot/import run and applicable Preview identity/revision.

The expiration notice must be conspicuous on the printed output, not available only in browser metadata.

This rule applies to **all hard reports produced by FieldWiring**, not only the primary Wiring View.

## Other FormView Functions

FormView 0.3.1 also contains:

### Stage View

A read-only Stage -> Preview -> Display report based on:

```text
stage_display_list_all_v1
```

It identifies Displays with no wiring and can generate a Stage display listing.

### Programming View

A read-only Preview-oriented view over Props and Groups with Tags. It reads `props` and `groups` joined to `previews` and exports CSV/HTML.

These functions must remain inventoried during the transition.

FieldWiring is not automatically required to absorb every unrelated FormView function into its first browser release. However, FormView cannot be retired while an operational function still depends on it unless that function has an accepted replacement or is explicitly retired by decision.

## Current PostgreSQL Readiness

The Production Database already contains important portions of the historical FormView contract.

### Current Preview data

`lor_snap.v_current_previews` exposes the current LOR Preview rows, including:

- Preview identity;
- Stage ID;
- Preview name;
- revision;
- `background_file`; and
- source filename/provenance.

### Wiring views

The repository already contains PostgreSQL versions of the established wiring-view stack, including:

```text
lor_snap.preview_wiring_map_v6
lor_snap.preview_wiring_sorted_v6
lor_snap.preview_wiring_fieldmap_v6
lor_snap.preview_wiring_fieldlead_v6
lor_snap.preview_wiring_circuit_rollup_v6
lor_snap.preview_wiring_fieldonly_v6
```

The `_v6` names are compatibility names. Their presence does not make the V6 parser or V6 ingest current.

### Scene-aware data

The current V7 parser and production model also carry Scene identity and Scene background-file information.

That Scene capability may eventually improve FieldWiring navigation and document resolution. It is **not** evidence that historical FormView was Scene-driven. Historical FormView 0.3.1 is Preview-driven.

Scene-based routing must therefore be treated as a separately validated extension, not silently substituted for the recovered Preview contract.

## Authority Boundary

### LOR owns

- Preview identity and revision;
- Preview `BackgroundFile` reference;
- controller assignments;
- channel assignments;
- network/DMX topology;
- Prop/SubProp relationships; and
- sequencing/programming structure.

### Stage wiring/document storage owns

- published wiring images;
- source engineering drawings; and
- supporting visual field-reference material.

### Parser/LOR2DB owns

- extraction of approved LOR data;
- snapshot/provenance generation;
- normalized wiring materialization; and
- controlled promotion into PostgreSQL.

### Production Database owns

- current shared operational data;
- permanent MSB identities;
- database-owned relationships; and
- the data interface consumed by FieldWiring.

### FieldWiring owns

- browser-based navigation;
- field-oriented presentation;
- filters/sorting appropriate to field work;
- wiring-image viewing/navigation;
- report/export generation; and
- visible data-currentness/expiration information.

FieldWiring must not silently reinterpret or correct LOR controller/channel topology.

## Required Compatibility Behaviors

The following behavior must be preserved or deliberately migrated and validated before FieldWiring can replace the corresponding FormView wiring function:

1. Clear Stage and Preview operating context.
2. Preservation of distinct Show Background and RGB Plus/Musical Preview contexts.
3. Stable link from the selected Preview/context to the correct wiring documentation.
4. `BackgroundFile` behavior or a controlled successor mapping with equivalent traceability.
5. Primary plus multiple supporting wiring images.
6. Separation of published field images from source/working files.
7. Field-lead reduction of internal/shared LOR relationships.
8. Preservation of legitimate multiple-Display shared circuits.
9. Controller UID and channel/plug-oriented presentation.
10. Separate Channel Name and Display Name concepts.
11. Network visibility.
12. Spare-channel suppression.
13. Practical image paging and readable zoom/scaling.
14. Access to related wiring assets without requiring Windows Explorer.
15. CSV/data export where operationally useful.
16. Portable/self-contained or server-hosted hard reports with no mapped-drive dependency.
17. Visible generation/source provenance.
18. Explicit hard-copy expiration date/time and immediate supersession by newer approved data.
19. LOR/PostgreSQL authority rather than manual wiring transcription.
20. Browser access without a mapped `G:` drive or direct SQLite file access.

## FormView Coexistence and Retirement Gate

FormView remains maintained as the production fallback during FieldWiring development.

Do not change FormView merely to simplify the replacement project unless a separate FormView maintenance need is identified and validated.

Do not point production users away from FormView until comparison testing proves the replacement behavior.

A minimum replacement validation should compare known-good Stages/Previews between FormView and FieldWiring for:

- Preview list/context;
- wiring rows;
- field-lead reduction;
- shared circuits;
- SPARE suppression;
- controller/channel sort;
- background image selection;
- additional image set and order;
- row counts;
- generated report content; and
- expiration/currentness markings.

If Stage View or Programming View still requires FormView, FormView remains available until those dependencies are separately resolved.

## Known Gaps Before Implementation

The recovery establishes the behavior to preserve, but several implementation questions remain open and must be resolved without guessing:

1. **Browser image delivery:** `G:\...` paths cannot be consumed directly by a normal browser client. A controlled server-side resolution/serving method is required.
2. **Published-image identity:** determine whether FieldWiring continues to derive the published image directory from `BackgroundFile`, or whether PostgreSQL stores/resolves a durable controlled successor reference while preserving traceability to the LOR source path.
3. **Live Production Database verification:** verify the current deployed PostgreSQL wiring views and grants against the repository definitions before treating them as the FieldWiring API contract.
4. **Authentication/authorization:** determine the browser application's access model and least-privilege database/API path.
5. **Implementation repository:** the Wiring subsystem permits a dedicated application repository; choose the implementation boundary only after the data contract is accepted.
6. **Scene-aware navigation:** determine where V7 Scene relationships improve field navigation without breaking the proven Preview context.
7. **Hard-report format:** decide whether FieldWiring produces HTML, PDF, or both, while applying the same explicit expiration/currentness rules to every hard report.
8. **FormView V7 validation:** FormView's V7 compatibility remains a separate validation task if FormView is to be pointed at V7 during the transition.

None of these gaps authorizes a schema change yet.

## Gate to FieldWiring Design / Implementation

Before application code or schema changes begin:

1. Review and accept this recovered compatibility contract.
2. Verify the live PostgreSQL objects that can satisfy the contract without schema changes.
3. Define the read-only FieldWiring data contract/query surface.
4. Define how published Stage wiring images will be resolved and securely served to browsers.
5. Define representative FormView-vs-FieldWiring acceptance cases.
6. Only then identify genuine data/schema gaps, if any.
7. Any schema change must be separately justified by a demonstrated requirement that existing objects cannot satisfy.

## Intended Future Data Flow

The target direction is:

```text
Light-O-Rama
      |
      v
LOR Preview Parser / LOR2DB
      |
      v
PostgreSQL Production Database
      |
      +--> current wiring data + provenance
      +--> permanent MSB identities/relationships
      |
      v
FieldWiring service/application
      |
      +--> browser / tablet / phone
      +--> current wiring images
      +--> disposable, expiring hard reports
```

The exact browser technology is intentionally not selected by this recovery document.

## Related Documents

- [Wiring System](README.md)
- [FormView Engineering Architecture](../../../01_LOR_System/04_FormView/FormView_Engineering_Architecture.md)
- [FormView Operator Procedure](../../../01_LOR_System/04_FormView/FormView_Operator_Procedure.md)
- [Create Wiring Backgrounds for Stage Previews](../../../01_LOR_System/01_Preview_Authoring/D_Create_Wiring_Backgrounds..md)
- [LOR Preview Parser Architecture](../../../01_LOR_System/02_Data_Extraction/LOR_Preview_Parser_Architecture.md)
- [Database Foundation](../01_Database_Foundation/README.md)
- [LOR2DB Ingest](../02_LOR2DB_Ingest/README.md)
