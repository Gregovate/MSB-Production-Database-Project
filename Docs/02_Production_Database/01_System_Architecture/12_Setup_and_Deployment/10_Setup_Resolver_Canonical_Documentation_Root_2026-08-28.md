# Setup Resolver Canonical Documentation Root Repair — 2026-08-28

| Document control | Value |
|---|---|
| Status | PRODUCTION DEPLOYED / LIVE ACCEPTED |
| Repository | `Gregovate/MSB-Production-Database-Project` |
| Engineering branch | `agent/setup-resolver-canonical-document-root` |
| Starting `main` | `d504716c0039526f4e6d42b9229548d286b8361a` |
| Merged Production Database commit | `718fe0d2ccdee0c99225680ee2048e9d29a767e8` |
| Production Database PR | #91 — `agent/setup-resolver-canonical-document-root` |
| Previous shared production checkout | `d0acdfb7d781ab7cc43edfd348dc7eb6285fd358` |
| Accepted shared production checkout | `718fe0d2ccdee0c99225680ee2048e9d29a767e8` |
| Live acceptance date | 2026-08-28 |

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

## Engineering verification

Focused shared hierarchy / structured resolver / Wiring scope / Procedure document / Procedure context regression:

```text
56 passed in 0.31s
```

Complete FieldWiring + Procedure application regression on the feature branch:

```text
pytest -q FieldWiring/Application Procedures/Application
161 passed in 1.04s
```

Both runs completed successfully on the feature branch. The temporary branch-only GitHub Actions verification workflow used to execute these tests was removed after the complete regression passed and is not part of the production change.

## Production deployment and acceptance — 2026-08-28

PR #91 was merged to `main` as:

```text
718fe0d2ccdee0c99225680ee2048e9d29a767e8
```

The shared production checkout on `msb-prod-db` was verified at:

```text
d0acdfb7d781ab7cc43edfd348dc7eb6285fd358
```

before deployment.

The server remote uses a narrow fetch refspec for `agent/fieldwiring-server-deployment-reconnaissance`, so `git fetch origin main` updated `FETCH_HEAD` but did not advance the stale local `origin/main` tracking ref. The deployment gate was corrected to verify the actual remote `refs/heads/main` with `git ls-remote` and fetch the exact approved target.

A detached candidate worktree at the exact merged target was tested using the production Python environment. The first invocation reached 100% but pytest then attempted to restore `/home/msbadmin` after running as `fieldwiring`, producing a shutdown permission error. The candidate was rerun from inside the candidate worktree and completed cleanly:

```text
161 passed in 2.47s
```

The live checkout was then advanced fast-forward-only:

```text
d0acdfb7d781ab7cc43edfd348dc7eb6285fd358
    ->
718fe0d2ccdee0c99225680ee2048e9d29a767e8
```

Both shared-checkout services were restarted:

```text
fieldwiring.service
msb-procedures.service
```

Immediate health passed:

```text
FieldWiring: {"data_mode":"postgres","status":"ok","version":"V0.2.0"}
Procedures:  {"data_mode":"postgres","status":"ok","version":"V0.1.0"}
```

The first live filesystem/API acceptance wrapper resolved the repaired hierarchy correctly but attempted direct mounted-folder enumeration as `msbadmin`, which lacks `msb-docs-read` traversal rights. That check failed with `PermissionError`. A wrapper control-flow flaw also allowed later commands to print an acceptance message after that failure. That result was explicitly rejected and not used as production acceptance.

Final acceptance was rerun with direct filesystem validation under the `fieldwiring` runtime account and strict failure semantics outside a conditional context.

### Final live hierarchy acceptance

```text
Stage 07:          07-Whoville-WV
Sub-stage 07a:     07a-Who Forest-WF
07a scope type:    SUBSTAGE
07a path evidence: G:\Shared drives\Display Folders\07-Whoville-WV\07a-Who Forest-WF
Stage 07 stage_id: 37
07a stage_id:      59
```

FieldWiring and Procedure returned the same `07a-Who Forest-WF` label and the same canonical path evidence.

### Stage 07 Setup

Resolved root:

```text
/mnt/msb-display-folders/07-Whoville-WV/Procedures/Setup
```

Direct mounted PDFs and Procedure API PDFs matched exactly:

```text
07 - Whoville.pdf
07b - Mount Crumpit .pdf
```

### Sub-stage 07a Setup

Resolved root:

```text
/mnt/msb-display-folders/07-Whoville-WV/07a-Who Forest-WF/Procedures/Setup
```

Direct mounted PDFs and Procedure API PDFs matched exactly:

```text
07a - Who Forest Trees Setup Instructions.pdf
```

Final production result:

```text
FILESYSTEM / API AGREEMENT: PASS
SHARED ROOT AGREEMENT: PASS
FINAL PRODUCTION ACCEPTANCE: PASS
DEPLOYMENT ACCEPTED
```

The accepted shared production checkout is now:

```text
718fe0d2ccdee0c99225680ee2048e9d29a767e8
```

The immediate application rollback point is:

```text
d0acdfb7d781ab7cc43edfd348dc7eb6285fd358
```

Server/runtime authority and the complete deployment record are maintained in `Gregovate/MSB-Server-Management`, including `docs/server/Setup_Resolver_Canonical_Root_Production_Acceptance_2026-08-28.md`.
