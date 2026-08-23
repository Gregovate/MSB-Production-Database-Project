# Procedure Handoff — Shared Field Context Hierarchy / Browse Repair — 2026-08-23

| Document control | Value |
|---|---|
| Status | **PRODUCTION ACCEPTED — PROCEDURE RESUME GATE CLEARED** |
| Final implementation PRs | `#40`, `#41` |
| Production commit | `060de4546cbaa3cbcec7b70978d17d6db0d3ed44` |
| Procedure branch | `feature/setup-takedown-procedures` — refresh from current `main` before continuing |

## Why this handoff exists

Procedure browser acceptance exposed a defect in the shared browse contract, not in Procedure task/document discovery.

Raw `ref.stage` rows and raw LOR Scene associations are relationship evidence. They are not the field-facing Stage/Sub-stage/Scene browse hierarchy.

The released Google Drive and Folder Alignment contracts remain authoritative.

```text
Display Folders
  -> NN-Name-XY Stage
      -> optional NNa-Name-XY Sub-stage
      -> optional defined NN-Name / NNa-Name Scene
      -> Display/component/shared-documentation folders as applicable
```

Display/component folders are not hierarchy browse nodes merely because they exist beneath a Stage or Scene.

## Canonical shared browse entry point

Procedure Stage browsing must consume:

```text
FieldWiring/Application/field_context_hierarchy.py
    resolve_field_hierarchy(repository, drive_root)
```

Supporting shared components remain:

```text
field_context_repository.py
    current permanent Display / Stage / LOR relationship evidence

field_context_browse.py
    lower-level filesystem hierarchy grouping

field_context_resolver.py
    resolve_structured_scope(...)
```

Do not present `repository.stages()` directly.

## Required Procedure chain

```text
permanent Display identity / field browse request
    -> field_context_repository
    -> raw current DB/LOR evidence
    -> field_context_hierarchy.resolve_field_hierarchy(...)
    -> actual marked Stage -> Sub-stage -> defined Scene hierarchy
    -> selected resolved field scope
    -> Procedure task adapter
    -> Setup / Takedown / Inspection discovery
```

## Final accepted hierarchy behavior

### Top-level Stage

One current `ref.stage.stage_key` plus one matching marked top-level `NN-...` folder is sufficient to establish the field Stage.

LOR/Preview association is optional supporting evidence. Missing/stale/conflicting `ref.stage.folder_path` remains visible under `review_required`, but does not erase an otherwise unique marked physical/documentation Stage.

Accepted real cases:

```text
39-Parade Float-PF
    normal Stage
    current LOR/Preview evidence present
    stale folder_path reported for review

40-CommandCenter
    normal Stage
    browse validity does not depend on LOR context presence or absence
    current Root Preview evidence, if present, collapses to Stage root
    missing folder_path reported for review
```

### Sub-stage

`05a` and `07a` are nested beneath their owning Stages, not top-level peers. Stale/missing persisted Sub-stage paths remain review findings.

### Scene — unchanged

The released Folder Alignment naming/classification contract remains in force:

```text
NN-Name  -> Scene candidate beneath owning Stage
NNa-Name -> Scene candidate beneath owning Sub-stage
Root -> owning Stage root
unprefixed non-Root -> Display/group evidence, not automatic Scene
```

A Scene browse node exists only when the existing structured-scope resolver resolves the current LOR Scene evidence to one distinct marked correctly prefixed child scope.

The marker approves the already-resolved structural scope. A marker alone does not turn an arbitrary Display/component folder into a Scene.

Examples preserved:

- Stage 15: `15-Church-CH` / `Root` collapse to Stage root;
- Stage 13: exactly four defined marked Scene scopes;
- Stage 21: `21-SnowballBears` is a Scene, while `21-Sliding Penguins` collapses to Stage root;
- Stage 25: same-name Racing Arches Scene collapses to Stage root;
- Stages 90–94 remain outside normal physical browse.

## Production acceptance evidence

```text
74 passed
SHARED FIELD HIERARCHY LOR-OPTIONAL STAGE ACCEPTANCE: PASS
Production commit: 060de4546cbaa3cbcec7b70978d17d6db0d3ed44
Shared Field Context hierarchy refinement: DEPLOYED AND VERIFIED
```

Identity/task separation also remains accepted:

- inventory Display `807` resolves shared field context;
- FieldWiring normal search still excludes `807`;
- direct FieldWiring for `807` reports no applicable wiring;
- wired Display `312` remains equivalent to production FieldWiring behavior.

## Procedure resume rule

The shared hierarchy prerequisite is now cleared.

Before further Procedure work:

1. fetch current `origin/main`;
2. merge current `origin/main` into `feature/setup-takedown-procedures`;
3. preserve the existing accepted Procedure browser/orchestration/document work;
4. replace raw Stage browse consumption with `field_context_hierarchy.resolve_field_hierarchy(...)`;
5. retain permanent Display lookup through `field_context_repository.py`;
6. keep Procedure task/document discovery downstream of resolved field scope.

Do not:

- copy PostgreSQL relationship SQL into Procedures;
- render `repository.stages()` directly;
- treat every raw LOR Scene as a field Scene;
- promote Display/component folders into the hierarchy resolver;
- use `ref.stage.stage_name` as the field-facing Stage label;
- invent a second Stage/Sub-stage/Scene resolver;
- alter FieldWiring eligibility/search;
- add schema for this browse contract;
- silently repair stale `folder_path` evidence.

## Runtime note

Resolved hierarchy construction reads the mounted Google/rclone tree and is slower than raw PostgreSQL browse. Procedure may later use an appropriate cache/refresh boundary, but caching must preserve this resolved hierarchy contract.

## Related acceptance record

See:

`../07_Labeling_and_Scanning/Shared_Field_Context_Hierarchy_Browse_Repair_Acceptance_2026-08-23.md`
