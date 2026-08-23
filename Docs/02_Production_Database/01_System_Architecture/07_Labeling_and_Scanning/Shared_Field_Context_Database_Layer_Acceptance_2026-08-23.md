# Shared Field Context Database Layer Acceptance — 2026-08-23

| Document control | Value |
|---|---|
| Status | ARCHITECTURE ACCEPTED — production deployment pending |
| Branch | `agent/shared-field-context-database-layer` |
| Accepted candidate | `c56df80055a80cff6ff497538f1e8f6a892c8bf2` |
| Production FieldWiring baseline during acceptance | `21e9e3b1889289806ccb116b3a546cfcd129fae4` |
| Filesystem resolver | `FieldWiring/Application/field_context_resolver.py` |
| Shared database context | `FieldWiring/Application/field_context_repository.py` |
| FieldWiring task adapter | `FieldWiring/Application/repository.py` |
| Procedure status | paused until this layer is production accepted |

## Purpose

The first shared Field Context extraction correctly centralized filesystem Stage/Sub-stage/Scene resolution in `field_context_resolver.py`, but permanent Display identity and current PostgreSQL Stage/Scene/Preview relationship resolution were still embedded in FieldWiring's `repository.py`.

That repository intentionally applies FieldWiring eligibility rules such as current LOR prop/device availability. Those task rules are valid for Wiring search and presentation, but they are too narrow to be the common identity/context layer used by Procedures and other field applications.

This change separates **field identity/context eligibility** from **task eligibility**.

## Accepted Architecture

The shared chain is now:

```text
DISP:<display_id> / manual Display / Stage / Scene selection
        -> task-neutral current PostgreSQL identity/context
        -> current Display + Stage + all current Scene/Preview candidates
        -> field_context_resolver.resolve_structured_scope(...)
        -> fixed marked Stage/Sub-stage/Scene filesystem scope
        -> task adapter
```

Canonical task-neutral PostgreSQL implementation:

```text
FieldWiring/Application/field_context_repository.py
```

Canonical filesystem implementation remains unchanged:

```text
FieldWiring/Application/field_context_resolver.py
```

`resolve_structured_scope(...)` was not redesigned by this work.

## Shared Database Context Owns

The shared repository resolves current active Production Database identity and hierarchy without requiring wiring eligibility:

- permanent `ref.display.display_id`;
- current active Display name/status boundary;
- current permanent `ref.display.stage_id -> ref.stage` relationship;
- Stage key/name/current `folder_path`;
- all applicable current `ref.lor_scene_display -> ref.lor_scene` Scene memberships;
- Preview UUID/name and current Preview background/path evidence;
- Scene UUID/name/background/path evidence;
- current Scene/Preview candidate set without collapsing valid alternatives into a task-specific choice;
- controlled Display/Stage search/browse independent of controller/channel availability.

The shared layer does **not** decide whether a Display is eligible for FieldWiring, Procedures, Testing, Work Orders, or another task.

No PostgreSQL schema, migration, function, trigger, or production data was changed.

## FieldWiring Remains Narrow

FieldWiring's `repository.py` is now the Wiring-specific adapter over the shared context layer.

The normal FieldWiring Display lookup remains intentionally filtered by the existing wiring/device eligibility rules. Inventory-only Displays do not clutter the Wiring search merely because the shared layer can resolve them.

The accepted distinction is:

```text
Shared Field Context
    active Display exists and current Stage/Scene context can be resolved

FieldWiring eligibility
    Display also satisfies current Wiring-specific LOR/device requirements
```

For direct `display_id` entry, FieldWiring can now distinguish:

```text
unknown / inactive Display
    -> Display is not available for current FieldWiring

valid current Display with no applicable Wiring
    -> No applicable field wiring is available for this Display
```

This distinction is required for a future common field-home/task-selection experience.

## Regression Gate

The branch was tested from an isolated detached worktree while production remained unchanged.

Final full FieldWiring regression result at candidate `c56df80055a80cff6ff497538f1e8f6a892c8bf2`:

```text
64 passed in 2.04s
```

The suite includes tests proving:

- shared search can return active non-wired/inventory Displays;
- a Display with `device_type='None'` can retain shared Stage/Scene context;
- an active Display with no LOR prop at all can still resolve its permanent Stage;
- retired/non-current Displays are excluded from current shared context;
- shared Stage browse does not require wiring;
- the shared database result can feed the unchanged `resolve_structured_scope(...)` filesystem resolver;
- normal FieldWiring search still excludes non-wired Displays;
- direct FieldWiring entry reports `No applicable field wiring` for a valid shared Display that is not Wiring-eligible;
- all previously accepted FieldWiring tests remain green.

## Real Production-Data Acceptance — Display 807

A real active inventory Display was selected from production:

```text
display_id   807
display_name RA-SteelArch-DS-F-03
```

The shared candidate resolved live PostgreSQL facts:

```text
stage_id     55
stage_key    25
stage_name   RGB Plus Stage 25 Racing Arches Traditional
folder_path  G:\Shared drives\Display Folders\25-Racing Arches-RA
```

Current Scene/Preview candidate:

```text
scene_name    25-Racing Arches-RA
scene_uuid    1bbc0060-36a6-447c-bbf5-0aa2aa8b6502
preview_name  2026 Master Musical Preview v6.6.10 2026-08-20
preview_uuid  fcf5c29c-8d51-46c5-9ad0-cc47a97c75bd
```

Those live facts were then passed to the unchanged filesystem resolver against the mounted read-only Google tree.

Result:

```text
scope_type = SCENE
scope_root = /mnt/msb-display-folders/25-Racing Arches-RA
warnings   = []

DISPLAY 807 SHARED STRUCTURED SCOPE: PASS
```

The task-eligibility split was also proven:

```text
shared search for RA-SteelArch-DS-F-03 -> [807]
FieldWiring filtered search            -> []
FieldWiring display_context(807)       -> None
```

Direct FieldWiring request result:

```text
No applicable field wiring is available for this Display
```

This proves that **not wired** no longer means **not a valid Display/context**.

## Existing FieldWiring Equivalence — Display 312

A normal wired production Display was resolved through the candidate and compared with the unchanged production FieldWiring API.

Display `312` matched on:

- scope type;
- scope root;
- warning text;
- Wiring image list;
- context image list;
- relative image path; and
- image URL.

Result:

```text
DISPLAY 312 FIELDWIRING EQUIVALENCE: PASS
```

## Acceptance Decision

The shared PostgreSQL identity/context layer is architecture accepted because:

1. permanent Display identity resolution no longer depends on Wiring eligibility;
2. active inventory-only/non-wired Displays can resolve current Stage/Scene/Preview context;
3. all current Scene/Preview candidates are exposed rather than guessed into one task-neutral choice;
4. the production-accepted filesystem resolver is unchanged;
5. FieldWiring search/browse remains Wiring-filtered;
6. direct FieldWiring entry distinguishes valid-but-not-wired from nonexistent;
7. the complete FieldWiring regression suite passes;
8. real Display `807` proves the full shared database-to-filesystem chain;
9. wired Display `312` proves existing FieldWiring behavior remains equivalent.

Production deployment remains a separate acceptance step.

## Procedure Gate

The Procedure branch remains paused until this database-context layer is merged and production accepted.

After that gate clears, Procedure must consume the same shared repository rather than copy PostgreSQL relationship SQL into `Procedures`.

The intended Procedure chain is:

```text
permanent Display / Stage / Scene entry
    -> field_context_repository
    -> fixed database identity/context facts
    -> field_context_resolver.resolve_structured_scope(...)
    -> Procedures task adapter
```

Procedure task/document discovery remains downstream and must not introduce Wiring eligibility filters into the shared context layer.

## Related Documents

- `Field_Context_Resolution_Contract.md`
- `../09_Wiring_System/FieldWiring_Shared_Structured_Scope_Resolver_Extraction_2026-08-22.md`
- `../12_Setup_and_Deployment/00_Procedure_System_Field_Context_Handoff_2026-08-22.md`
- `../12_Setup_and_Deployment/01_Shared_Resolver_Extraction_Handoff_2026-08-22.md`
