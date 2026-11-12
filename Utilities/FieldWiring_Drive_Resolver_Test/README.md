# FieldWiring Drive Resolver Test Harness

Status: **READ-ONLY ENGINEERING TEST**

This harness implements the first test gate defined by the [FieldWiring Drive Context Resolver Engineering Design](../../Docs/02_Production_Database/01_System_Architecture/09_Wiring_System/FieldWiring_Drive_Context_Resolver_Engineering_Design.md).

It tests whether current V7+ Preview/Scene path evidence can navigate the actual mapped Google Shared Drive hierarchy and identify the current candidate Wiring/PreviewBackground package without using the V6 database as runtime authority.

## Safety Boundary

The harness is read-only.

It does not:

- modify the SQLite snapshot;
- connect to or modify PostgreSQL;
- modify LOR previews;
- create, rename, move, or delete Google Drive folders/files;
- repair `BackgroundFile` values;
- change any Production Database relationship.

It reads:

- `fieldwiring_snapshot.db`;
- `G:\Shared drives\Display Folders`; and
- direct image filenames in candidate published folders.

### `SourceDocs` traversal guard

`SourceDocs` is a hard source-only boundary.

The normal PowerShell entry point runs `guarded_resolver_test.py`, which inspects `BackgroundFile` path text before filesystem navigation. If the pointer contains a `SourceDocs` segment, the raw pointer is retained only for reporting and navigation is truncated before `SourceDocs`.

The harness must never descend into, enumerate, open, fetch, or present files under `SourceDocs`.

A pointer into `SourceDocs` is reported as a folder-alignment/data-quality condition rather than being accepted as a published field-document endpoint.

## Default Acceptance Cases

The default run tests:

- `15-Church-CH` — direct Musical Wiring pointer;
- `05a-Mega Star-MS` — deep arbitrary image beneath a formal Substage;
- `03-Mega Cube-MC` — Scene PreviewBackground with possible Stage Wiring fallback;
- current snapshot `07-Who Characters` — stale Scene identity plus pointer entering `SourceDocs`;
- `02-Fred's Stars` — stale stored folder path requiring deterministic current hierarchy resolution; and
- Stage 15 `Root` in `Show Background Stage 15 Church` — Background/Static Stage-root resolution.

The LOR Scene formerly represented in the development snapshot as `07-Who Characters` has been corrected by the operator to `07-Who People`. That corrected name will appear in the test data after a later parser/snapshot run; an immediate parser run is not required while folder-alignment review is still underway.

## Run

From the repository root:

```powershell
.\Utilities\FieldWiring_Drive_Resolver_Test\run_resolver_test.ps1 -SnapshotPath 'C:\path\to\fieldwiring_snapshot.db'
```

If the snapshot is already at one of the auto-discovery locations, omit `-SnapshotPath`:

```powershell
.\Utilities\FieldWiring_Drive_Resolver_Test\run_resolver_test.ps1
```

Auto-discovery checks:

```text
<repo>\fieldwiring_snapshot.db
<repo>\Utilities\fieldwiring_snapshot.db
G:\Shared drives\MSB Database\database\fieldwiring_snapshot.db
```

The environment variable `FIELDWIRING_SNAPSHOT` may also identify the snapshot.

## Expanded Test

After the initial acceptance cases are understood, run all current Master Musical Preview Scenes:

```powershell
.\Utilities\FieldWiring_Drive_Resolver_Test\run_resolver_test.ps1 -AllMasterScenes
```

A single unique Scene may also be requested:

```powershell
.\Utilities\FieldWiring_Drive_Resolver_Test\run_resolver_test.ps1 -Scene '15-Church-CH'
```

## Reports

By default, the harness writes two reports to the current user's Desktop:

```text
FieldWiring_Drive_Resolver_Test_<timestamp>.txt
FieldWiring_Drive_Resolver_Test_<timestamp>.json
```

The text report is intended for operator/engineering review. The JSON report preserves the same evidence in machine-readable form for later automated tests.

Each tested Scene records:

- Preview;
- Scene;
- Stage key;
- current `BackgroundFile` pointer;
- whether the pointer is beneath the configured Shared Drive root;
- whether the allowed exact stored pointer resolves;
- current Stage root;
- resolved structured scope and resolution basis;
- applicable `BackgroundStage` or `MusicalStage` branch;
- candidate scope Wiring folder and direct published images;
- candidate scope PreviewBackground and direct images;
- Stage Wiring folder and direct published images;
- Stage PreviewBackground and direct images;
- the selected candidate under the current fallback hypothesis; and
- warnings/unresolved conditions, including blocked `SourceDocs` pointers.

## Exit Codes

```text
0 = harness ran and every tested case resolved under the current test rule
2 = harness ran correctly but at least one tested case is unresolved
1 = test could not run correctly (missing snapshot, missing Drive, schema error, etc.)
```

Exit code `2` is an engineering finding, not a reason to change data automatically. Review the report and refine the resolver contract or underlying legacy organization deliberately.

## Current Test Rule

The selection order remains explicitly **under test**:

```text
resolved Scene/Substage Wiring branch
    -> resolved Scene/Substage PreviewBackground
    -> Stage Wiring branch
    -> Stage PreviewBackground
    -> unresolved
```

Only folders containing at least one directly published `.jpg`, `.jpeg`, or `.png` file are treated as usable by the current harness. `SourceDocs` is excluded from traversal and publication entirely.

Do not promote this fallback order to final production behavior until the acceptance evidence has been reviewed and the engineering design is updated accordingly.
