# Setup Material Completeness Audit — 2026-09-20

| Document Control | Value |
|---|---|
| Document Type | Engineering Implementation Contract |
| System | Production Database — Setup and Deployment |
| Issue | #145 |
| Status | IMPLEMENTATION CANDIDATE — NOT PRODUCTION ACCEPTED |
| Owner | MSB Production Database engineering |
| Last Reviewed | 2026-09-20 |

## Purpose

Provide the Manager-level whole-Catalog acceptance surface required before #145 can complete its disposable 2026 seed proof.

The candidate audits two existing authorities without replacing them:

1. current LOR-resolved Display ownership from the accepted #141 assignment layer;
2. physical Kit Box -> reusable task relationships from `ref.setup_task_container_support` / `relationship_type='KIT'`.

## Display / LOR ownership

The audit must reuse the installed #141 `field_context` / assignment resolver and emit each effective Stage/real-Scene material scope once.

Accepted complete behavior remains:

- one implicit material-bearing task may own the whole scope;
- explicit multi-task ownership is complete only when every current resolved Display has exactly one valid owner;
- missing, invalid, duplicate, stale, or unscoped material ownership remains Manager review work;
- LOR remains current Display-membership authority;
- the audit never writes Display ownership.

Ordinary correction remains the existing Manager **Display Ownership** surface.

## Kit assignment coverage

Physical Kit Boxes remain `ref.container.container_type_id=2`. Reusable task assignment remains many-to-many through `relationship_type='KIT'`.

The audit distinguishes:

```text
ASSIGNED_ACTIVE
INACTIVE_OBSOLETE_ONLY
REVIEWED_SHARED_NON_TASK
UNASSIGNED_UNRESOLVED
```

Active and inactive relationships are shown separately. Multiple active reusable task assignments are valid.

## Reviewed shared/non-task disposition

Migration candidate `051_add_setup_material_completeness_audit.sql` adds:

```text
ref.setup_kit_assignment_disposition
ref.set_setup_kit_assignment_disposition(text,integer,boolean,text)
```

This state means only:

> An authorized Setup Manager deliberately reviewed this physical Kit-typed Container for reusable task-assignment completeness and determined that it is intentionally shared/non-task stock.

It is not:

- a fake task assignment;
- a Container-type change;
- expected Kit contents;
- a physical inventory count;
- an Extra Material source;
- annual Setup state; or
- #206 Pick List/movement state.

The command requires existing Manager authority through `ref.setup_management_actor(..., false)`. An active disposition requires a nonblank Manager review reason, stamps Manager person identity and review time, and refuses to activate while any current task -> KIT relationship exists.

If a task assignment is later created while an old disposition remains active, the audit surfaces a **disposition conflict** instead of inferring or silently correcting state.

## Candidate Manager surface

Protected route:

```text
/setup/material-audit/
```

Protected Manager API:

```text
GET   /api/setup/material-audit
PATCH /api/setup/material-audit/kits/{container_id}/shared-non-task
```

The browser defaults to **Exceptions only**, provides whole-Catalog summary counts, and links Managers to existing Display Ownership, reusable-task Kit assignment, and Kit Inventory surfaces.

## Acceptance gate

Before #145 final Catalog acceptance:

```text
Display REVIEW_REQUIRED scopes = 0
Display missing / invalid / duplicate / stale = 0

Kit INACTIVE_OBSOLETE_ONLY = 0
Kit UNASSIGNED_UNRESOLVED = 0
Kit disposition conflicts = 0
```

`REVIEWED_SHARED_NON_TASK` is an accepted deliberate exception.

No real 2026 Setup Session may be created by this work.
