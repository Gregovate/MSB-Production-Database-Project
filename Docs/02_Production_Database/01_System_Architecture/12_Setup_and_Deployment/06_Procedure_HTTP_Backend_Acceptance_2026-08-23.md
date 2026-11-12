# Procedure HTTP Backend Acceptance — 2026-08-23

| Document control | Value |
|---|---|
| Status | **ACCEPTED ENGINEERING CHECKPOINT — read-only HTTP/API backend, not deployed** |
| Branch | `feature/setup-takedown-procedures` |
| Shared DB context | `FieldWiring/Application/field_context_repository.py` |
| Shared filesystem resolver | `FieldWiring/Application/field_context_resolver.py` |
| Procedure orchestration | `Procedures/Application/procedure_context.py` |
| Procedure adapter | `Procedures/Application/procedure_documents.py` |
| HTTP backend | `Procedures/Application/backend.py` |

## Purpose

This checkpoint records acceptance of the first read-only Procedure HTTP/API backend layered over the already accepted shared Field Context and Procedure orchestration components.

The backend does not contain copied PostgreSQL relationship SQL, another Stage/Scene resolver, or direct task-folder discovery logic. It delegates those responsibilities to the accepted shared/application layers.

## Accepted HTTP contract

The backend exposes:

```text
/api/health
/api/displays?q=...
/api/displays/<display_id>/context
/api/stages
/api/procedures
/api/procedure/document
/api/procedure/image
```

`/api/displays` and `/api/displays/<display_id>/context` use the task-neutral `FieldContextRepository`. Inventory-only/non-wired Displays are therefore valid browser identity/context entries.

`/api/procedures` resolves through:

```text
FieldContextRepository
    -> Procedure context orchestration
    -> resolve_structured_scope(...)
    -> Procedure task adapter
```

## File-serving boundary

Document/image endpoints never accept a filesystem path as the authority for what may be served.

The client supplies the current field identity/task context plus one filename. The backend then re-runs the current Procedure resolution and serves the file only when that exact filename is rediscovered in the current direct document/image result.

This means normal HTTP addressing cannot turn these into current Procedure assets:

```text
Procedures/<task>/Archive/...
Procedures/<task>/SourceDocs/...
../SourceDocs/...
arbitrary stale filesystem paths
```

The selected file is additionally verified as a direct child of the current resolved task root or its controlled `images` child.

## Configuration boundary

The Procedure backend uses Procedure-prefixed runtime configuration:

```text
PROCEDURE_DATABASE_DSN
PROCEDURE_DEV_SNAPSHOT
PROCEDURE_DRIVE_ROOT
PORT
```

This allows a separate Procedure service/runtime while both FieldWiring and Procedures consume the same production-accepted shared code.

No new PostgreSQL schema is required.

## Automated acceptance evidence

Backend-specific suite:

```text
python -m pytest .\Procedures\Application\test_backend.py -q
...............                                                                        [100%]
15 passed in 0.55s
```

Complete Procedure suite:

```text
python -m pytest .\Procedures\Application -q
................................                                                       [100%]
32 passed in 0.37s
```

Combined FieldWiring + Procedure regression:

```text
python -m pytest .\FieldWiring\Application .\Procedures\Application -q
...................................................................................... [ 89%]
..........                                                                             [100%]
96 passed in 2.84s
```

## Accepted behaviors

This checkpoint accepts:

- task-neutral Display search including inventory-only/non-wired Displays;
- task-neutral Display current-context lookup;
- controlled Stage/Scene browse data from the shared repository;
- Procedure resolution through the accepted orchestration layer;
- explicit `CONTEXT_SELECTION_REQUIRED` behavior when current candidates are ambiguous;
- direct current PDF serving by rediscovered filename;
- direct supporting-image serving by rediscovered filename;
- rejection of `Archive` files;
- rejection of `SourceDocs` files;
- rejection of traversal-style filenames;
- rejection of `whole_stage` on Display entry;
- preservation of all accepted FieldWiring/shared-context regressions.

## Not yet accepted

This checkpoint does not yet accept or deploy:

- the operator HTML/JavaScript browser presentation;
- protected `my.sheboyganlights.org` Procedure routing;
- Procedure production systemd/runtime configuration;
- Scan-hub Procedure actions;
- generated/offline Procedure publication behavior.

## Next gate

The next gate is the thin operator browser client over this accepted API.

The browser must not contain PostgreSQL SQL, filesystem scope logic, task-folder discovery logic, or arbitrary Drive paths. It should present the API results using permanent Display/Stage/Scene identity and provide explicit context choice when required.
