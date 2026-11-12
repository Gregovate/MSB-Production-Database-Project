# Shared Field Context Database Layer Acceptance — 2026-08-23

| Document control | Value |
|---|---|
| Status | **PRODUCTION ACCEPTED** |
| Architecture branch | `agent/shared-field-context-database-layer` |
| Merge PR | `#37` |
| Production deployment commit | `decb4eb7030a35bab3fc2e778fcf271463044044` |
| Accepted candidate | `c56df80055a80cff6ff497538f1e8f6a892c8bf2` |
| Filesystem resolver | `FieldWiring/Application/field_context_resolver.py` |
| Shared database context | `FieldWiring/Application/field_context_repository.py` |
| FieldWiring task adapter | `FieldWiring/Application/repository.py` |
| Procedure gate | **CLEARED — refresh/rebase Procedure branch onto current `main` before resuming** |

## Purpose

The original shared Field Context work centralized filesystem Stage/Sub-stage/Scene resolution in `field_context_resolver.py`, but permanent Display identity and current PostgreSQL Stage/Scene/Preview relationship resolution were still embedded in FieldWiring's `repository.py` and therefore coupled to Wiring-specific eligibility.

That coupling was too narrow for shared field context. A valid inventory Display may need Setup/Takedown documentation even when it has no controller/channel assignment and no FieldWiring package.

This work separates **field identity/context eligibility** from **task eligibility**.

## Production-Accepted Architecture

```text
DISP:<display_id> / manual Display / Stage / Scene selection
        -> task-neutral current PostgreSQL identity/context
        -> Display + Stage + all current Scene/Preview candidates
        -> field_context_resolver.resolve_structured_scope(...)
        -> fixed marked Stage/Sub-stage/Scene filesystem scope
        -> task adapter
```

Canonical shared database implementation:

```text
FieldWiring/Application/field_context_repository.py
```

Canonical filesystem implementation remains:

```text
FieldWiring/Application/field_context_resolver.py
```

`resolve_structured_scope(...)` was not redesigned by this work.

No PostgreSQL schema, migration, function, trigger, or production data was changed.

## Shared Database Context Owns

The shared repository resolves current active Production Database identity and hierarchy without requiring Wiring eligibility:

- permanent `ref.display.display_id`;
- current active Display identity;
- current `ref.display.stage_id -> ref.stage` relationship;
- Stage key/name/current `folder_path`;
- current `ref.lor_scene_display -> ref.lor_scene` memberships;
- Preview UUID/name and current Preview path evidence;
- Scene UUID/name/background/path evidence;
- the current Scene/Preview candidate set without forcing a task-neutral Preview choice;
- Display and Stage search/browse independent of controller/channel availability.

The shared layer does **not** decide whether a Display is eligible for FieldWiring, Procedures, Testing, Work Orders, or another task.

## FieldWiring Remains Narrow

`FieldWiring/Application/repository.py` is the Wiring-specific adapter over the shared context layer.

The normal FieldWiring Display lookup remains intentionally filtered by the existing Wiring/device eligibility rules. Inventory-only Displays do not clutter the Wiring search merely because the shared layer can resolve them.

The accepted distinction is:

```text
Shared Field Context
    current Display exists and current Stage/Scene facts can be resolved

FieldWiring eligibility
    Display also satisfies current Wiring-specific LOR/device requirements
```

For direct `display_id` entry, FieldWiring now distinguishes:

```text
unknown / inactive Display
    -> Display is not available for current FieldWiring

valid current Display with no applicable Wiring
    -> No applicable field wiring is available for this Display
```

## Detached Regression Acceptance

Candidate regression was run from an isolated detached server worktree while production remained unchanged.

Final candidate result:

```text
64 passed in 2.04s
```

The suite proves, among other cases:

- shared search can return active non-wired/inventory Displays;
- a Display with `device_type='None'` can retain shared Stage/Scene context;
- an active Display with no LOR prop can still resolve its permanent Stage;
- retired/non-current Displays are excluded;
- shared Stage browse does not require wiring;
- the shared database result can feed the unchanged `resolve_structured_scope(...)` filesystem resolver;
- normal FieldWiring search still excludes non-wired Displays;
- direct FieldWiring entry reports `No applicable field wiring` for a valid shared Display that is not Wiring-eligible;
- all previously accepted FieldWiring tests remain green.

## Real Production-Data Acceptance — Display 807

Real active inventory Display:

```text
display_id   807
display_name RA-SteelArch-DS-F-03
```

Shared PostgreSQL context resolved:

```text
stage_id     55
stage_key    25
stage_name   RGB Plus Stage 25 Racing Arches Traditional
folder_path  G:\Shared drives\Display Folders\25-Racing Arches-RA
scene_name   25-Racing Arches-RA
scene_uuid   1bbc0060-36a6-447c-bbf5-0aa2aa8b6502
preview_name 2026 Master Musical Preview v6.6.10 2026-08-20
preview_uuid fcf5c29c-8d51-46c5-9ad0-cc47a97c75bd
```

Those facts were passed to the unchanged filesystem resolver against the mounted read-only Google tree:

```text
scope_type = SCENE
scope_root = /mnt/msb-display-folders/25-Racing Arches-RA
warnings   = []

DISPLAY 807 SHARED STRUCTURED SCOPE: PASS
```

Task-eligibility separation was also proven:

```text
shared search for RA-SteelArch-DS-F-03 -> [807]
FieldWiring filtered search            -> []
FieldWiring display_context(807)       -> None
```

Direct FieldWiring result:

```text
No applicable field wiring is available for this Display
```

This proves that **not wired** no longer means **not a valid Display/context**.

## Existing FieldWiring Equivalence — Display 312

Normal wired production Display `312` was resolved through the candidate and compared with the unchanged production FieldWiring API.

Resolver/image values matched, including scope type, scope root, warning text, Wiring image list, context image list, relative image path, and image URL.

```text
DISPLAY 312 FIELDWIRING EQUIVALENCE: PASS
```

## Production Deployment Acceptance

PR `#37` merged the shared database-context layer to `main`.

The production `/opt/fieldwiring` checkout was then advanced to:

```text
decb4eb7030a35bab3fc2e778fcf271463044044
```

The complete FieldWiring/shared-context suite was rerun in the production checkout:

```text
64 passed in 2.05s
```

The service restarted successfully:

```text
fieldwiring.service = active
{"data_mode":"postgres","status":"ok","version":"V0.2.0"}
```

Post-deployment production checks:

```text
FieldWiring search for RA-SteelArch-DS-F-03 -> []
Direct FieldWiring display_id=807           -> HTTP 400 / No applicable field wiring
DISPLAY 807 FIELDWIRING TASK SEPARATION: PASS

Display 807 shared scope:
scope_type = SCENE
scope_root = /mnt/msb-display-folders/25-Racing Arches-RA
warnings   = []
DISPLAY 807 SHARED FIELD CONTEXT: PASS

Display 312:
scope_type = STAGE
scope_root = /mnt/msb-display-folders/15-Church-Bells-CH
wiring image = RGB Plus Prop Stage 15 Church-Tagged.jpg
DISPLAY 312 FIELDWIRING POST-DEPLOY: PASS
```

Result:

```text
Shared Field Context database layer: DEPLOYED AND VERIFIED
```

## Acceptance Decision

The shared PostgreSQL identity/context layer is **production accepted** because:

1. permanent Display identity resolution no longer depends on Wiring eligibility;
2. active inventory-only/non-wired Displays can resolve current Stage/Scene/Preview context;
3. current Scene/Preview candidates are exposed without a task-neutral guess;
4. the production-accepted filesystem resolver remains unchanged;
5. FieldWiring search/browse remains Wiring-filtered;
6. direct FieldWiring entry distinguishes valid-but-not-wired from nonexistent;
7. the complete production suite passes;
8. real Display `807` proves the database-to-filesystem shared chain;
9. wired Display `312` proves FieldWiring remains operational after deployment.

## Procedure Gate — Cleared

The Procedure prerequisite is now cleared.

Before resuming `feature/setup-takedown-procedures`, refresh it against current `main`. Procedure must consume this same shared repository rather than copy PostgreSQL relationship SQL into `Procedures`.

The required Procedure chain is:

```text
permanent Display / Stage / Scene entry
    -> field_context_repository
    -> current database identity/context facts
    -> field_context_resolver.resolve_structured_scope(...)
    -> Procedures task adapter
```

Procedure task/document discovery remains downstream and must not introduce Wiring eligibility filters into shared identity/context resolution.

## Related Documents

- `Field_Context_Resolution_Contract.md`
- `../09_Wiring_System/FieldWiring_Shared_Structured_Scope_Resolver_Extraction_2026-08-22.md`
- `../12_Setup_and_Deployment/00_Procedure_System_Field_Context_Handoff_2026-08-22.md`
- `../12_Setup_and_Deployment/01_Shared_Resolver_Extraction_Handoff_2026-08-22.md`
- `../12_Setup_and_Deployment/03_Shared_Field_Context_Database_Layer_Handoff_2026-08-23.md`
