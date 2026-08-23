# Procedure Handoff — Shared Field Context Hierarchy / Browse Repair — 2026-08-23

| Document control | Value |
|---|---|
| Status | CURRENT ENGINEERING HANDOFF — production deployment pending |
| Repair branch | `agent/shared-field-context-hierarchy-browse-repair` |
| Accepted candidate | `b1d897cf2b4d157ebf8a713c8dcc939726012df0` |
| Procedure branch | `feature/setup-takedown-procedures` — remain paused until production acceptance |

## Why Procedure is paused again

Procedure browser acceptance exposed a defect in the shared browse contract, not in Procedure task/document discovery.

The shared database repository's raw `stages()` result contains `ref.stage` and LOR Scene evidence. That evidence must not be rendered directly as the field Stage/Sub-stage/Scene hierarchy.

The released Google Drive architecture remains authoritative:

```text
Display Folders
  -> NN-Name-XY Stage
      -> optional NNa-Name-XY Sub-stage
          -> optional defined NNa-Scene
      -> optional defined NN-Scene
```

A raw LOR Scene is not automatically a field/documentation Scene.

## Canonical shared browse entry point

After this repair is production accepted, Procedure Stage browsing must consume:

```text
FieldWiring/Application/field_context_hierarchy.py
    resolve_field_hierarchy(repository, drive_root)
```

The lower-level shared hierarchy builder is:

```text
FieldWiring/Application/field_context_browse.py
```

The existing structured-scope resolver remains unchanged:

```text
FieldWiring/Application/field_context_resolver.py
    resolve_structured_scope(...)
```

The shared database repository remains the source of current DB/LOR evidence:

```text
FieldWiring/Application/field_context_repository.py
```

## Required chain after resume

```text
permanent Display identity / field browse request
    -> field_context_repository
    -> raw current DB/LOR evidence
    -> field_context_hierarchy.resolve_field_hierarchy(...)
    -> actual marked Stage -> Sub-stage -> defined Scene browse tree
    -> selected resolved field scope
    -> Procedure task adapter
    -> Setup / Takedown / Inspection discovery
```

Do not present `repository.stages()` directly.

## Governing behavior

The repaired hierarchy:

- labels Stage/Sub-stage/Scene nodes from the actual resolved folder basename;
- nests `05a` and `07a` beneath their owning top-level Stages;
- creates a child Scene only when the existing structured-scope resolver resolves a raw LOR Scene to one distinct marked prefixed child scope;
- collapses `Root` and Stage-binding Master Musical scenes to the Stage root rather than creating duplicate choices;
- deduplicates by the resolved marked filesystem root;
- excludes `90–94` from normal physical browse;
- suppresses top-level `39/40` from normal browse while their current DB/filesystem alignment remains unsafe;
- surfaces stale/missing/conflicting path evidence under `review_required` rather than guessing.

## Acceptance evidence

Synthetic regression:

```text
74 passed in 2.09s
```

Live read-only production-data acceptance:

```text
normal Stage count: 27
review-required count: 36
SHARED FIELD HIERARCHY LIVE ACCEPTANCE: PASS
```

Representative cases accepted:

- Stage 15 Church: Stage root only; raw `15-Church-CH` and `Root` do not create child Scenes;
- Stage 07: `07a-Who Forest-WF` nested under `07-Whoville-WV`;
- Stage 13: exactly four defined marked child Scene scopes;
- Stage 21: `21-SnowballBears` child Scene, `21-Sliding Penguins` Stage-root evidence;
- Stage 25: same-name Racing Arches LOR Scene collapses to the Stage root;
- Stage 39/40: review-only rather than guessed;
- Stage 90–94: absent from normal physical browse;
- inventory Display 807: shared identity/context preserved while FieldWiring remains unavailable;
- normal wired Display 312: candidate output exactly equivalent to unchanged production FieldWiring.

## Procedure resume rule

Do not modify Procedure code as part of this shared repair.

After the repair is merged and production accepted:

1. merge current `origin/main` into `feature/setup-takedown-procedures`;
2. preserve the existing accepted Procedure browser/orchestration/document work;
3. replace raw shared Stage browse consumption with `field_context_hierarchy.resolve_field_hierarchy(...)`;
4. retain permanent Display lookup through `field_context_repository.py`;
5. keep Procedure task/document discovery downstream of resolved field scope.

Do not:

- copy PostgreSQL relationship SQL into Procedures;
- treat every raw LOR Scene as a browse Scene;
- use `ref.stage.stage_name` as the field-facing Stage label;
- invent a second Stage/Sub-stage/Scene resolver;
- alter FieldWiring eligibility or search;
- add schema for the browse repair;
- silently guess Stage 39/40 alignment.

## Related acceptance record

See:

`../07_Labeling_and_Scanning/Shared_Field_Context_Hierarchy_Browse_Repair_Acceptance_2026-08-23.md`
