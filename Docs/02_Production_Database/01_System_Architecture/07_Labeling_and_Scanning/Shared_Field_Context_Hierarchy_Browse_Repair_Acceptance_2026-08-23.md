# Shared Field Context Hierarchy / Browse Repair Acceptance — 2026-08-23

| Document control | Value |
|---|---|
| Status | **PRODUCTION ACCEPTED** |
| Final implementation PRs | `#40` hierarchy repair, `#41` top-level Stage evidence refinement |
| Production commit | `060de4546cbaa3cbcec7b70978d17d6db0d3ed44` |
| Canonical field-facing hierarchy entry point | `FieldWiring/Application/field_context_hierarchy.py` |
| Lower-level hierarchy builder | `FieldWiring/Application/field_context_browse.py` |
| Shared database evidence | `FieldWiring/Application/field_context_repository.py` |
| Structured-scope resolver | `FieldWiring/Application/field_context_resolver.py` |
| Procedure status | **Shared hierarchy prerequisite cleared** |

## Governing authority

This repair follows the released Google Drive architecture:

- `Docs/00_Project_Overview/00-Google_Drive.md` Revision 1.3.1;
- `Docs/00_Project_Overview/01-Google_Drive_Document_Organization_Procedure.md`;
- `Docs/01_LOR_System/02_Data_Extraction/Folder_Alignment/Folder_Alignment_Engineering_Design.md`.

The hierarchy remains:

```text
Display Folders
  -> NN-Name-XY top-level Stage
      -> optional NNa-Name-XY Sub-stage
          -> optional defined NNa-Scene
      -> optional defined NN-Scene
      -> Display/component/shared-documentation folders as applicable
```

Display/component folders are **not** Stage/Sub-stage/Scene browse nodes merely because they exist beneath a Stage or Scene. The smaller Display-folder contract remains separate.

## Defect repaired

The first shared database-context layer exposed raw `ref.stage` rows and raw LOR Scene associations as though they were the field browse hierarchy. That was incorrect.

Raw database/LOR rows are now treated only as relationship evidence. Field-facing browse is built from the released hierarchy plus the current marked filesystem roots.

Applications must not render `field_context_repository.stages()` directly as the field hierarchy.

Canonical chain:

```text
field_context_repository.stages()
    -> raw DB/LOR evidence
    -> field_context_hierarchy.resolve_field_hierarchy(repository, drive_root)
        -> field_context_browse
        -> field_context_resolver.resolve_structured_scope(...)
        -> current marked filesystem roots
        -> deduplicated Stage -> Sub-stage -> defined Scene hierarchy
        + review_required alignment evidence
```

## Final top-level Stage rule

The final production rule was refined after live acceptance using the real Stage 39 / Stage 40 cases.

A top-level field Stage is valid when:

1. one current `ref.stage` row has the Stage key;
2. one marked `NN-...` folder with that key exists directly beneath `Display Folders`.

LOR/Preview association is optional supporting evidence. It is **not** required for a physical/documentation Stage to exist.

Persisted `ref.stage.folder_path` is alignment evidence. A missing, stale, or conflicting path remains visible under `review_required`, but does not erase an otherwise uniquely identified marked field Stage.

This is important for:

```text
39-Parade Float-PF
    stage_key = 39
    marked top-level folder exists
    current LOR/Preview supporting evidence exists
    persisted folder_path is stale and remains reviewable

40-CommandCenter
    stage_key = 40
    marked top-level folder exists
    browse validity does not depend on LOR membership
    current raw Root Preview evidence, if present, collapses to the Stage root
    persisted folder_path is missing and remains reviewable
```

No Stage-number exception is hard-coded.

## Sub-stage rule

A Sub-stage is a marked `NNa-...` child beneath its owning marked `NN-...` Stage. The physical parent/child relationship provides the Stage ownership boundary.

Current accepted examples:

```text
05-Festive Trees-FT
  -> 05a-Mega Star-MS

07-Whoville-WV
  -> 07a-Who Forest-WF
```

A stale or missing Sub-stage `folder_path` remains a review finding but does not erase an otherwise unambiguous nested field scope.

## Scene rule — unchanged

The Scene contract was **not widened** during the Stage 39/40 refinement.

Per the released Folder Alignment design:

```text
NN-Name   -> Scene candidate under owning NN Stage
NNa-Name  -> Scene candidate under owning NNa Sub-stage
unprefixed non-Root name -> Display/group evidence, not automatic Scene
Root -> owning Stage root, not a child folder
```

A LOR Scene becomes a browse Scene only when the existing structured-scope resolver resolves it to one distinct marked, correctly prefixed child scope.

If the LOR Scene resolves to the owning Stage/Sub-stage root, it remains relationship/context evidence on that root and does not create a duplicate child browse choice.

Therefore:

- `Root` never creates a duplicate Scene;
- `15-Church-CH` and `25-Racing Arches-RA` remain Stage-root evidence;
- `21-Sliding Penguins` remains Stage-root evidence;
- `21-SnowballBears` is a distinct Scene;
- Stage 13 exposes only its four defined marked child Scene scopes;
- unprefixed Display/group folders are not promoted into the hierarchy resolver.

The source-folder marker approves a structurally resolved Stage/Sub-stage/Scene context. A marker by itself does not classify an arbitrary child folder as a Scene.

## Field-facing labels

The resolved current Google Drive folder basename is the field-facing label. `ref.stage.stage_name` remains database/LOR metadata and is not field label authority.

Examples:

```text
15-Church-Bells-CH
07-Whoville-WV
07a-Who Forest-WF
13-Winter Wonderland-WW
21-Polar Bear Playground-PB
25-Racing Arches-RA
39-Parade Float-PF
40-CommandCenter
```

## Review behavior

Unsafe or stale alignment evidence is surfaced rather than silently repaired.

Representative production findings include:

```text
05a PERSISTED_SUBSTAGE_PATH_REVIEW_REQUIRED
07a PERSISTED_SUBSTAGE_PATH_REVIEW_REQUIRED
39  PERSISTED_STAGE_PATH_REVIEW_REQUIRED
40  PERSISTED_STAGE_PATH_REVIEW_REQUIRED
90-94 DATABASE_STAGE_NOT_IN_FIELD_HIERARCHY
```

Stages 90–94 remain outside normal physical browse.

## Regression and live acceptance

Final shared/FieldWiring regression suite:

```text
74 passed
```

Representative live cases passed against production PostgreSQL and the read-only `/mnt/msb-display-folders` mount:

- Stage 15 Church Stage-root deduplication;
- Stage 07 with nested `07a`;
- Stage 13 defined Scene set;
- Stage 21 defined Scene behavior;
- Stage 25 Stage-root deduplication;
- Stage 39 normal browse with stale path review;
- Stage 40 normal browse with missing path review and LOR-optional Stage validity;
- Stage 90–94 normal-browse exclusion;
- inventory Display 807 shared-context preservation with FieldWiring eligibility still downstream;
- wired Display 312 equivalence with unchanged production FieldWiring behavior.

Final production acceptance:

```text
SHARED FIELD HIERARCHY LOR-OPTIONAL STAGE ACCEPTANCE: PASS
Production commit: 060de4546cbaa3cbcec7b70978d17d6db0d3ed44
Shared Field Context hierarchy refinement: DEPLOYED AND VERIFIED
```

## Runtime characteristic

Building the resolved hierarchy walks the read-only Google/rclone tree and is materially slower than returning raw PostgreSQL rows. That is expected because filesystem structure and markers are part of the field-browse contract.

A future consumer may cache or refresh the resolved hierarchy at an appropriate boundary, but performance work must not fall back to raw database rows or weaken ambiguity/review handling.

## Scope preserved

This work did not:

- modify Procedures;
- widen FieldWiring search;
- change permanent `display_id` resolution;
- remove inventory-only Display support;
- change FieldWiring eligibility filters;
- redesign `resolve_structured_scope(...)`;
- create PostgreSQL schema/data changes;
- move or rename Google Drive folders;
- promote Display/component folders into the Stage/Sub-stage/Scene resolver;
- invent hierarchy rules outside the released Google Drive and Folder Alignment documents.

## Acceptance decision

The shared field hierarchy browse contract is now production accepted. Procedure engineering may resume after refreshing `feature/setup-takedown-procedures` from current `main` and replacing raw Stage browse consumption with `field_context_hierarchy.resolve_field_hierarchy(...)`.
