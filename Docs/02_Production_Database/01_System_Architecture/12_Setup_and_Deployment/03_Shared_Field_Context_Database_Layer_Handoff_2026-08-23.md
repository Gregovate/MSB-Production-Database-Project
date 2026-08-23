# Procedure Subsystem — Shared Field Context Database Layer Handoff — 2026-08-23

| Document control | Value |
|---|---|
| Status | CURRENT ENGINEERING HANDOFF — production deployment of shared DB context pending |
| Shared DB-context branch | `agent/shared-field-context-database-layer` |
| Accepted candidate | `c56df80055a80cff6ff497538f1e8f6a892c8bf2` |
| Procedure branch | `feature/setup-takedown-procedures` — remain paused until production acceptance |

## Why this handoff exists

Procedure browser engineering correctly reused the production-accepted filesystem resolver, but exposed a remaining upstream coupling: permanent Display ID -> current Stage/Scene/Preview relationship resolution was still embedded in FieldWiring's `repository.py` and subject to Wiring-specific eligibility filters.

That is not an acceptable shared boundary for Procedures. A valid inventory Display may need Setup/Takedown documentation even when it has no controller/channel assignment and therefore no FieldWiring package.

This handoff records the new shared database-context layer that must be used when Procedure engineering resumes.

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

The combined common chain is:

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

Therefore an inventory-only steel arch can be a valid Procedure entry even when FieldWiring correctly reports no applicable wiring.

## Real acceptance fixture

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

The unchanged shared filesystem resolver then returned:

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

## Regression evidence

Complete FieldWiring + shared-context candidate suite:

```text
64 passed in 2.04s
```

Normal wired Display `312` was also compared against the unchanged production FieldWiring API and remained equivalent at the resolver/image boundary.

## Procedure resume rule

Do not resume substantive Procedure browser/database orchestration until this shared database-context layer is merged and production accepted.

After production acceptance, resume `feature/setup-takedown-procedures` by refreshing/rebasing it onto current `main` and replacing any planned FieldWiring-repository dependency with the canonical shared context repository.

Preserve the already accepted Procedure second-caller boundary:

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
- create new schema merely to support this first shared read path.

## Related documents

- `../07_Labeling_and_Scanning/Shared_Field_Context_Database_Layer_Acceptance_2026-08-23.md`
- `00_Procedure_System_Field_Context_Handoff_2026-08-22.md`
- `01_Shared_Resolver_Extraction_Handoff_2026-08-22.md`
