# Procedure Subsystem — Shared Field Context Database Layer Handoff — 2026-08-23

| Document control | Value |
|---|---|
| Status | **CURRENT ENGINEERING HANDOFF — shared database context production accepted; Procedure gate cleared** |
| Shared DB-context implementation | `FieldWiring/Application/field_context_repository.py` |
| Merge PR | `#37` |
| Production deployment commit | `decb4eb7030a35bab3fc2e778fcf271463044044` |
| Procedure branch | `feature/setup-takedown-procedures` — refresh/rebase onto current `main` before resuming |

## Why this handoff exists

Procedure browser engineering correctly reused the production-accepted filesystem resolver, but exposed a remaining upstream coupling: permanent Display ID -> current Stage/Scene/Preview relationship resolution was still embedded in FieldWiring's `repository.py` and subject to Wiring-specific eligibility filters.

That was not an acceptable shared boundary for Procedures. A valid inventory Display may need Setup/Takedown documentation even when it has no controller/channel assignment and therefore no FieldWiring package.

That gap is now closed and production accepted.

## Canonical shared database context

The task-neutral implementation is:

```text
FieldWiring/Application/field_context_repository.py
```

It owns current active Display identity plus current Stage/Scene/Preview relationship facts.

The production-accepted filesystem resolver remains:

```text
FieldWiring/Application/field_context_resolver.py
```

The common chain is now:

```text
DISP:<display_id> / manual Display / Stage / Scene entry
        -> field_context_repository
        -> Display + Stage + Scene/Preview candidate facts
        -> field_context_resolver.resolve_structured_scope(...)
        -> fixed marked structured scope_root
        -> Procedure adapter
```

Procedure must not copy these PostgreSQL queries into a Procedure-owned repository.

## Shared versus task-specific eligibility

The governing rule is:

```text
Shared Field Context
    resolves every current active Display and its available hierarchy facts
    without requiring Wiring eligibility

FieldWiring
    keeps current Wiring-specific search/browse/device eligibility downstream

Procedures
    may use wired or non-wired Displays when the resolved structured scope
    owns current Setup/Takedown/Inspection documentation
```

Therefore an inventory-only steel arch is a valid Procedure entry even when FieldWiring correctly reports no applicable wiring.

## Real production acceptance fixture

Production Display:

```text
807  RA-SteelArch-DS-F-03
```

Shared database result:

```text
stage_id     55
stage_key    25
stage_name   RGB Plus Stage 25 Racing Arches Traditional
folder_path  G:\Shared drives\Display Folders\25-Racing Arches-RA
scene_name   25-Racing Arches-RA
preview      2026 Master Musical Preview v6.6.10 2026-08-20
```

The unchanged shared filesystem resolver returned:

```text
scope_type = SCENE
scope_root = /mnt/msb-display-folders/25-Racing Arches-RA
warnings   = []
```

At the same time:

```text
shared Display search -> includes 807
FieldWiring search     -> excludes 807
FieldWiring direct     -> No applicable field wiring is available for this Display
```

This is the required distinction between **valid field context** and **task availability**.

## Acceptance evidence

Detached candidate regression:

```text
64 passed in 2.04s
```

Normal wired Display `312` remained equivalent to the unchanged production FieldWiring API before merge.

After PR `#37` merged, production `/opt/fieldwiring` was advanced to:

```text
decb4eb7030a35bab3fc2e778fcf271463044044
```

Production regression and service verification:

```text
64 passed in 2.05s
fieldwiring.service = active
{"data_mode":"postgres","status":"ok","version":"V0.2.0"}
```

Post-deployment checks:

```text
DISPLAY 807 FIELDWIRING TASK SEPARATION: PASS
DISPLAY 807 SHARED FIELD CONTEXT: PASS
DISPLAY 312 FIELDWIRING POST-DEPLOY: PASS
Shared Field Context database layer: DEPLOYED AND VERIFIED
```

The shared database-context layer is therefore **production accepted**.

## Procedure resume rule — Gate cleared

The previous pause is now cleared.

Before substantive Procedure browser/database orchestration resumes:

1. refresh/fetch current `main`;
2. rebase or deliberately merge `feature/setup-takedown-procedures` onto current `main`;
3. preserve the already accepted Procedure second-caller filesystem adapter work;
4. use the canonical shared `field_context_repository` for permanent Display/Stage/Scene/Preview facts;
5. pass those facts into the unchanged `field_context_resolver.resolve_structured_scope(...)`;
6. keep Procedure task/document discovery downstream.

Preserve this architecture:

```text
shared DB context
    -> shared filesystem scope
    -> Procedure task adapter
    -> Procedures/Setup | Takedown | Inspection
```

Do not:

- widen FieldWiring search to every inventory Display;
- apply `device_type`/controller/channel eligibility to Procedure identity lookup;
- copy FieldWiring SQL into Procedures;
- redesign `resolve_structured_scope(...)`;
- create a second Stage/Scene filesystem resolver;
- create new schema merely to support this shared read path.

## Related documents

- `../07_Labeling_and_Scanning/Shared_Field_Context_Database_Layer_Acceptance_2026-08-23.md`
- `00_Procedure_System_Field_Context_Handoff_2026-08-22.md`
- `01_Shared_Resolver_Extraction_Handoff_2026-08-22.md`
