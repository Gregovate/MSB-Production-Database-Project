# Setup Resolver Canonical Documentation Root Repair — 2026-08-28

| Document control | Value |
|---|---|
| Status | ENGINEERING FIX / REGRESSION VERIFIED |
| Repository | `Gregovate/MSB-Production-Database-Project` |
| Branch | `agent/setup-resolver-canonical-document-root` |
| Starting `main` | `d504716c0039526f4e6d42b9229548d286b8361a` |
| Deployed Procedure baseline | `9a19639ae0af6cd5bbaf162fe236e14c1b88722d` |
| Production Procedure PR | #45 — `agent/procedure-shared-field-context-integration` |

## Defect

The established field hierarchy contains:

```text
G:\Shared drives\Display Folders\
└── 07-Whoville-WV\
    ├── Procedures\Setup\
    └── 07a-Who Forest-WF\
        └── Procedures\Setup\
```

Top-level Stage 07 Setup documents resolved correctly. Whole Sub-stage 07a Setup lookup did not. The operator message expected:

```text
G:\Shared drives\Display Folders\07-Whoville-WV\07a-Who Forest\Procedures\Setup
```

instead of the established physical Sub-stage root:

```text
G:\Shared drives\Display Folders\07-Whoville-WV\07a-Who Forest-WF
```

`07a-Who Forest-WF` is a **Sub-stage**. It is not a Scene. A Scene may separately use an `07a-...` name beneath that Sub-stage, so no prefix directory search is permitted.

## Reconnaissance findings

### Wiring path

FieldWiring loads current Stage, Scene, Preview, and `BackgroundFile` facts and calls:

```text
FieldWiring/Application/field_context_resolver.py
    resolve_structured_scope(...)
```

The shared resolver validates the persisted Stage/Sub-stage anchor on the mounted filesystem. When that stored path is stale, Wiring can recover the owning top-level Stage from the exact current LOR `BackgroundFile`, walk that supplied path upward, and stop at the nearest valid marked structured scope. For 07a this reaches:

```text
07-Whoville-WV\07a-Who Forest-WF
```

Only after that root is fixed does Wiring append its task branch.

### Procedure path before repair

The Procedure browser correctly used the shared Stage/Sub-stage hierarchy for navigation, but the selected owner was reduced to `stage_id` / key / label in the browser request. `resolve_stage_procedure()` then reloaded the raw `ref.stage` item and passed its `folder_path` into the Procedure document adapter.

For a whole Sub-stage selection there is intentionally no selected Scene/Preview context, so there was no `BackgroundFile` pointer available to let `resolve_structured_scope()` recover from a stale stored path.

The shared operator-message formatter did not invent the bad path. On unresolved scope it displayed the `database_folder_path` supplied in the diagnostic and appended `Procedures\Setup`. Therefore the observed `07a-Who Forest` path came from stale persisted path evidence reaching Procedure resolution.

### Second shared-evidence issue found during trace

The fast shared hierarchy accepted a persisted `folder_path` whenever its basename began with the Stage/Sub-stage key. That made a stale-but-plausible value such as:

```text
...\07a-Who Forest
```

outrank unambiguous current LOR path evidence containing:

```text
...\07a-Who Forest-WF\...
```

This was not a filesystem scan problem. It was an evidence-precedence problem in the shared hierarchy model.

## Repaired shared contract

The shared contract is now:

```text
Production Database identity / Stage relationship
        +
current LOR BackgroundFile path evidence
        |
        v
shared field hierarchy owner/path evidence
        |
        v
shared structured-scope resolver validates marked physical root
        |
        +--> FieldWiring appends Wiring/<branch>
        |
        +--> Procedure appends Procedures/<task>
```

When one unique current LOR path identifies a different Stage/Sub-stage owner folder than a syntactically plausible persisted `folder_path`, the LOR owner path wins for shared hierarchy `scope_path_evidence`. This matches the existing structured resolver behavior that already lets Wiring recover from stale persisted paths.

Procedure does not accept a filesystem path from the browser. Server-side Procedure orchestration rebuilds the shared hierarchy from the same current repository facts, finds the selected Stage/Sub-stage by permanent `stage_id`, overlays only the shared `scope_path_evidence` into the temporary resolver input, and still lets `resolve_structured_scope()` validate the directory and source-folder marker.

The raw database Stage object remains unchanged in the returned Procedure result for provenance.

## Files changed

```text
FieldWiring/Application/field_context_hierarchy.py
Procedures/Application/procedure_context.py
Procedures/Application/test_procedure_context.py
Docs/02_Production_Database/01_System_Architecture/12_Setup_and_Deployment/10_Setup_Resolver_Canonical_Documentation_Root_2026-08-28.md
```

No PostgreSQL schema, parser, V6 SQLite data, Google Drive folder names, QR payloads, or unrelated application code were changed.

## Regression cases

The added Procedure regressions explicitly reproduce a stale persisted 07a path while current LOR path evidence points through the established `07a-Who Forest-WF` folder.

They prove:

1. Stage 07 resolves to `07-Whoville-WV\Procedures\Setup`.
2. Sub-stage 07a resolves to `07-Whoville-WV\07a-Who Forest-WF\Procedures\Setup`.
3. The Wiring shared structured resolver and Setup resolve the identical `07a-Who Forest-WF` documentation root.
4. A marked Scene named `07a-SomethingElse` beneath the Sub-stage remains a Scene and is not substituted for Sub-stage 07a.
5. The raw stale database `folder_path` remains visible as provenance while Procedure uses the shared canonical path for resolution.
6. Existing Procedure document tests continue to prove multiple direct current PDFs are returned deterministically.
7. Existing Procedure document tests continue to prove `Archive`, `SourceDocs`, and nested files are excluded from normal current Procedure results.
8. Existing shared resolver and FieldWiring scope tests remain in the regression gate.

## Verification

Focused shared hierarchy / structured resolver / Wiring scope / Procedure document / Procedure context regression:

```text
56 passed in 0.31s
```

Complete FieldWiring + Procedure application regression:

```text
pytest -q FieldWiring/Application Procedures/Application
161 passed in 1.04s
```

Both runs completed successfully on the feature branch. The temporary branch-only GitHub Actions verification workflow used to execute these tests was removed after the complete regression passed and is not part of the proposed production change.

## Deployment boundary

This document records an engineering repair only. The existing production Procedure service remains on the accepted deployed commit until this branch is reviewed, merged, deployed to the Procedure runtime checkout, restarted, and field-accepted against the real mounted Display Folders tree.
