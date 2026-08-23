# Procedure Shared-Context Orchestration Acceptance — 2026-08-23

| Document control | Value |
|---|---|
| Status | **ACCEPTED ENGINEERING CHECKPOINT — read-only orchestration, not deployed** |
| Branch | `feature/setup-takedown-procedures` |
| Shared DB context | `FieldWiring/Application/field_context_repository.py` |
| Shared filesystem resolver | `FieldWiring/Application/field_context_resolver.py` |
| Procedure orchestration | `Procedures/Application/procedure_context.py` |
| Procedure task adapter | `Procedures/Application/procedure_documents.py` |

## Purpose

This checkpoint records acceptance of the Procedure database-context orchestration layer after the production-accepted shared Field Context database prerequisite was merged into the Procedure branch.

The Procedure subsystem now consumes the shared task-neutral database context directly rather than FieldWiring's wiring-filtered repository and does not copy PostgreSQL relationship SQL into Procedure-owned code.

## Accepted chain

```text
permanent Display / manual Stage/Scene selection
    -> FieldContextRepository
    -> current Display + Stage + Scene/Preview candidate facts
    -> Procedure orchestration
    -> field_context_resolver.resolve_structured_scope(...)
    -> fixed marked scope_root
    -> Procedure task adapter
    -> Procedures/Setup | Procedures/Takedown | Procedures/Inspection
```

The orchestration layer does not query PostgreSQL itself and does not implement another filesystem resolver.

## Inventory-only Display behavior

A valid current inventory Display does not need controller/channel or FieldWiring eligibility to reach Procedures.

The tests include an inventory-only steel-arch-style Display that contains only shared Display/Stage/Scene/Preview facts and successfully resolves a Setup document.

This preserves the production-accepted distinction:

```text
Shared Field Context
    valid current Display and hierarchy facts

FieldWiring eligibility
    separate downstream Wiring decision

Procedure eligibility
    separate downstream Procedure document availability
```

## Context candidate behavior

The shared database repository intentionally returns all current Scene/Preview candidates rather than making a task-neutral guess.

Procedure orchestration preserves that contract:

- zero candidates may use the current Stage scope;
- exactly one candidate may be used directly;
- multiple candidates without an explicit selection return `CONTEXT_SELECTION_REQUIRED`;
- an explicit Preview/Scene selection must match exactly one current shared candidate;
- whole-Stage browse remains an explicit operator choice even when Scene candidates exist.

Procedure does not import FieldWiring's Preview/context preference rules.

## Automated acceptance evidence

Procedure adapter + orchestration tests:

```text
17 passed in 0.53s
```

Complete FieldWiring + Procedure regression:

```text
81 passed in 2.74s
```

This confirms that the new Procedure orchestration is green and the production-accepted shared FieldWiring/context behavior remains regression-clean on the Procedure branch.

## Accepted behaviors

This checkpoint accepts:

- use of `FieldContextRepository` as the Procedure identity/context source;
- inventory-only/non-wired Display lookup as valid Procedure context;
- Stage-level fallback when a current Display has no Scene/Preview candidate;
- explicit Scene/Preview choice when multiple current candidates exist;
- explicit whole-Stage browse;
- exact validation of requested Preview/Scene candidates;
- no direct PostgreSQL SQL in Procedure orchestration;
- no dependency on FieldWiring wiring eligibility;
- no change to `resolve_structured_scope(...)`;
- no new schema.

## Not yet accepted

This checkpoint does not yet accept or deploy:

- a Procedure Flask/browser service;
- Procedure HTTP API routes;
- PDF/image HTTP serving;
- protected `my.sheboyganlights.org` routing;
- Scan-hub Procedure actions;
- Procedure production runtime configuration.

## Next engineering gate

The next layer is a thin read-only HTTP/backend shell over the accepted orchestration.

The backend must not accept arbitrary filesystem paths. Current PDF/image requests must be re-resolved through the accepted Procedure chain and may serve only filenames rediscovered in the current direct task result.

That design keeps `Archive`, `SourceDocs`, traversal paths, and stale arbitrary files outside the normal HTTP address space.
