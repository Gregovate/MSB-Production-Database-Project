# Review and Correct the 2025 Setup History

| Document Control | Value |
|---|---|
| Document Type | Operator Procedure |
| System | Production Database — Setup and Deployment |
| Task | Review and correct the 2025 Setup history |
| Audience | Authorized Setup reviewers and managers |
| Status | CURRENT — live 2025 review plus current reusable-task development |
| Owner | MSB Setup administrator |
| Last Reviewed | 2026-09-09 |
| Keywords | Setup, 2025, historical review, training, reusable task, resources, verification |

## Purpose

Use the real 2025 Setup Session to preserve/correct 2025 history while improving reusable Setup knowledge before the 2026 Setup Session is created.

Changes are real Production changes. The reusable catalog reconstruction was accepted in Production on 2026-09-09, and current PostgreSQL is now the working source for task development.

```text
active reusable tasks    = 185
total reusable rows      = 187
reusable prerequisites   = 0
2026 Setup Sessions      = 0
```

Historical spreadsheets/schedules remain evidence; they are not a parallel ongoing task master.

## Open the Setup Application

Use:

```text
https://my.sheboyganlights.org/setup/
```

Sign in through the normal MSB Google/Cloudflare Access login when prompted.

## Confirm You Are Working in 2025

At the top of the Setup application, confirm the selected session is:

```text
2025 — Historical Verification
```

For this session:

```text
allowed operational dates = 2025 only
```

The browser limits operational dates to 2025 and the database independently enforces the same rule. Audit/update timestamps remain the real current recording time.

## Understand the Two Kinds of Changes

### 2025 annual history

These changes describe what happened or was planned in 2025. Examples include:

- verification/reconciliation state;
- actual crew count or duration when known;
- actual start/completion information when known;
- annual notes;
- 2025-specific planned order; and
- 2025 work-day/scheduling information when useful for reconstruction.

### Reusable Task knowledge

These changes describe how MSB normally performs Setup work. Examples include:

- task name and active state;
- Park Infrastructure / Stage / Scene scope;
- normal local sequence/order;
- normal crew size and expected duration;
- Physical Effort;
- prerequisites/readiness;
- equipment/resources and quantities;
- completion point; and
- other reusable instructions that should carry forward.

Reusable Task changes are permanent Setup knowledge and may become part of future seasons.

## Review / Reconciliation States

Current states are:

```text
UNVERIFIED
NEEDS_CORRECTION
VERIFIED
ASSIGNED
```

- `UNVERIFIED` — not yet sufficiently reviewed.
- `NEEDS_CORRECTION` — known to need work.
- `VERIFIED` — accepted annual record after review.
- `ASSIGNED` — accepted as belonging to its current reusable task definition.

`ASSIGNED` is a reconciliation state, not an execution/completion state. Assigned items leave the default actionable queue but remain available through the Assigned filter.

Reassigning/merging an annual item to a different reusable task remains a separate governed workflow.

## Add Missing Reusable Tasks

If real Setup work is missing, Managers may add a reusable task when the work should normally exist beyond one historical occurrence.

Use the correct scope:

```text
Park Infrastructure / no LOR Stage
Stage-level / General
Scene
```

Use **Add Task Here** or **Copy** where appropriate.

Do not create a reusable task for ordinary transport merely because an old schedule recorded it. Example: `Bring Frosty to park` remains logistics evidence; the missing reusable work is physical `Set Up Frosty`.

## Review Resources, Effort, Prerequisites, and Readiness

For reusable tasks, check whether practical requirements are represented correctly:

- lifts/vehicles/trailers/tools;
- powered stake pounders or other recurring resources;
- Physical Effort where known;
- predecessor tasks that must complete first; and
- readiness conditions that block work even when predecessors are complete.

The current prerequisite set is intentionally empty after reconstruction. Rebuild dependencies deliberately and distinguish hard predecessor, preferred order, and readiness condition. Do not invent dependencies merely to fill fields.

Current confirmed example: `Set Up Frosty` must be added and must precede the applicable Stars setup work.

## Procedures and Instructions

Where a Setup task has a current published Setup procedure, the application may show that procedure and, for authorized Managers, the editable source used to maintain it.

If an editable procedure is corrected, the current published PDF must also be updated before the instruction is treated as current.

## Ask Questions and Make Suggestions

Report things such as:

- information that is hard to understand;
- missing information needed to make a Setup decision;
- awkward or repetitive steps;
- task organization that does not match real work;
- resources or prerequisites that are difficult to represent;
- missing search/filter/navigation behavior; and
- ideas that would make 2026 planning or field work easier.

Issue #133 separately tracks Stage-level ↔ Scene drag/drop. The limitation is non-blocking because governed scope editing still exists.

## What Reviewers Cannot Do

Normal reviewers/managers cannot:

- create the 2026 Setup Session; or
- promote an annual order into the reusable future baseline unless they have Administrator authority.

Pick List generation and Container/Display movement/scanning writes are not part of the current live workflow.

## What Successful Review Looks Like

A useful review leaves:

- 2025 annual facts corrected where evidence exists;
- uncertain information left UNVERIFIED or marked NEEDS CORRECTION;
- accepted annual-to-reusable identity mappings marked ASSIGNED where appropriate;
- missing reusable tasks added directly to the current PostgreSQL catalog;
- reusable task scope, resources, effort, prerequisites/readiness, order, and normal expectations improved where the change should carry forward;
- no fake records created only for testing; and
- no 2026 Session created before the catalog/predecessor model is ready.

## Related Documents

- [Setup operator procedures](README.md)
- [Detailed Manager Review Guide](../../../02_Operational_SOPs/Setup/Setup_Session_Manager_Review_Guide.md)
- [Setup engineering handoff](../engineering/README.md)
