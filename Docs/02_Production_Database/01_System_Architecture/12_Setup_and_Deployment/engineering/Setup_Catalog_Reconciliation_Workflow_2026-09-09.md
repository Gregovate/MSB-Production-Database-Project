# Setup Catalog Reconciliation Workflow — 2026-09-09

| Document Control | Value |
|---|---|
| Document Type | Engineering Reconstruction / Reconciliation Contract |
| System | Production Database — Setup Session |
| Status | CURRENT DESIGN DIRECTION — operator-confirmed; not yet implemented |
| Owner | MSB Production Database engineering |
| Related Work | Issue #122; PR #125; 2022 Project schedule; Rick 2025 reconstruction; Setup Smart Scheduler |

## Purpose

Define the next reconstruction step after the 2025 verification queue is cleared: reconcile the historical spreadsheet-derived task inventory against the current reusable Setup catalog so missing reusable work can be added without duplicating tasks that already exist or are now organized under current Scenes.

The spreadsheet is historical/reconstruction evidence. The current Production reusable catalog is the existing identity baseline. Neither source should be blindly copied over the other.

## Reconciliation Inputs

Use together:

```text
current Production reusable Setup catalog
+ current Stage / LOR Scene organization
+ recovered 2022 Project schedule
+ Rick 2025 actual-work evidence
+ operator corrections / current field knowledge
```

Historical source fields that remain materially useful include:

- date / relative seasonal timing;
- source task order;
- predecessor information;
- named crew / crew-size evidence where tied to the task;
- explicit duration evidence;
- equipment/resources;
- physical Setup notes;
- actual 2025 partial/completion evidence.

Historical dates are important as **ordering/timing evidence**, not as fixed dates for future seasons.

## Normalize Current Scope Before Matching

Historical work may have been recorded at Stage level even though the current LOR organization now contains a Scene that better represents the work.

Therefore matching must first resolve the most appropriate **current Stage / Scene scope**, then compare task identity within that current scope.

Operator-confirmed example:

```text
Traditional Christmas
  -> Frying Santa Scene
      -> Deer
      -> Frying Santa
      -> Kingsbury Sign
```

Historical references to Deer, Frying Santa, or Kingsbury must not automatically create separate Stage-level tasks merely because the old source lacked the current Scene grouping.

For each spreadsheet candidate, reconciliation should distinguish:

```text
MATCH EXISTING
    same practical reusable task already exists in the correct current scope

MOVE SCOPE
    task exists but is attached to Stage/Scene scope that no longer reflects the current organization

CREATE
    real reusable work is missing from the catalog

RENAME / ENRICH
    reusable identity exists but historical evidence improves its wording, crew, duration, equipment, completion point, readiness, or notes

MERGE / SPLIT REVIEW
    historical/current task boundaries differ and need operator judgment

LOGISTICS MERGE
    historical rows represent shared-container/Pick-List behavior rather than independent permanent reusable tasks

HISTORICAL ONLY / ROUTE ELSEWHERE
    evidence should not become a normal reusable Setup task

AMBIGUOUS
    preserve as a question; do not guess
```

## Scope-Move UI Gap

Current browser drag/drop/reorder behavior is useful within one Stage/Scene container but does not support moving a reusable task from:

```text
Stage -> Scene
Scene -> Stage
Scene A -> Scene B
```

The database foundation already contains governed reusable task scope support through `ref.set_setup_task_scope(...)` and Stage/Scene FK validation.

The practical UI should therefore provide an explicit **Move task to...** control during reconciliation rather than depending only on cross-container drag/drop.

Desired interaction:

```text
Move task to:
  Stage 23 — Traditional Christmas
    [Stage level]
    Frying Santa
    <other current scenes>
```

This operation changes reusable scope only. It must not create a new task identity or rewrite historical evidence.

Cross-group drag/drop may be considered later, but an explicit move command is safer and clearer for reconstruction.

## Not Every Display Needs Its Own Setup Task

A permanent Display identity does **not** imply a permanent reusable Setup task.

Create a separate reusable task when the work is meaningfully independent in field planning, for example when it has one or more of:

- separate prerequisites/readiness;
- separate crew/equipment needs;
- independent scheduling;
- separate partial-progress/continuation behavior;
- distinct logistics/container consequence;
- distinct completion point;
- durable operator knowledge that would otherwise remain tribal.

If several Displays are normally installed as one practical job, one reusable task may reference all of them through `ref.setup_task_display`.

The task catalog should model **work**, not mirror `ref.display` row-for-row.

## Locate and Layout Prerequisite Layers

Historical review has exposed two important planning steps that are underrepresented in the current catalog.

### Locates

Purpose: identify underground/network/power/reference infrastructure needed before physical placement.

### Layout

Purpose: mark/establish the actual Display/panel/tree/arch positions so install crews know where physical items go.

These are distinct concepts where field practice supports both.

Typical dependency direction:

```text
Locate required infrastructure
    -> Layout / mark Display positions
        -> Physical install / assembly
            -> Lay Cords when readiness allows
                -> Power / Network connection
                    -> Testing / finish
```

Do not automatically manufacture Locate or Layout tasks for every Stage/Scene. Reconciliation should flag them where historical/current operator evidence shows they are real reusable work.

For the future smart scheduler, true prerequisites such as Locate/Layout should keep downstream installation tasks out of the active candidate pool until the prerequisite is complete.

## Historical Dates as Ordering Evidence

For reconstruction, preserve at least:

```text
2022 planned date/order
2025 actual date(s)
```

These can be used to propose relative reusable order and to identify work that typically happens earlier/later in the season.

Do not convert them into a fixed future calendar.

When evidence conflicts, retain the evidence and flag the preferred order for operator review.

## Crew, Duration, and Equipment Evidence

Historical crew/resource/duration data should travel with the reconciliation row.

Use it as follows:

- explicit crew tied to a task -> crew-size evidence;
- explicit time range/task duration -> duration evidence;
- named equipment (SkyTrak, boom lift, trailer, etc.) -> resource evidence;
- one historical occurrence does not automatically become the reusable normal value;
- repeated evidence/operator confirmation can support `normal_crew_min`, `normal_crew_max`, `expected_duration_minutes`, and reusable resource relationships.

## Arch Trailer / Shared-Container Rows

Historical per-Stage Arch Trailer unload rows should remain visible during reconciliation, but they must be classified against the accepted mixed-stage logistics model.

Container 34 / Arch Trailer has current operator-confirmed unload/access order:

1. Racing Arches
2. Polar Bear Arch
3. Candyland Arch
4. Icicle Tunnel Arches
5. Stars
6. Food Collection Arches

The future Pick List/logistics system may execute unload by one selected Stage, multiple Stages, or all remaining contents without scanning every Display.

Therefore old per-Stage unload rows may represent **execution scopes of one shared-container logistics operation**, not necessarily six permanent reusable tasks.

Keep them in the reconciliation sheet until the final catalog/Pick-List boundary is accepted; do not silently delete them or blindly create six permanent task identities.

## Reconciliation Workbook Direction

The merged workbook should make the current database comparison explicit. Recommended columns include:

```text
current DB task id
current Stage
current Scene
spreadsheet/historical task
historical date(s)
historical relative order
2022 predecessor
crew evidence
duration evidence
equipment evidence
proposed current Stage
proposed current Scene
proposed reusable task name
match/action
existing-task enrichment proposal
prerequisite proposal
review note
```

Primary operator filters should be:

```text
CREATE
MOVE SCOPE
MERGE / SPLIT REVIEW
LOGISTICS MERGE
AMBIGUOUS
```

Rows already matched cleanly to the current database should remain traceable but should not dominate the review workload.

## Current Next Step

1. Export a fresh read-only snapshot of the current Production reusable Setup catalog after the 2025 verification pass.
2. Merge that snapshot into the reconstruction workbook.
3. Normalize historical candidates to current Stage/Scene scope.
4. Auto-classify strong matches versus missing/wrong-scope candidates.
5. Preserve date/order/crew/duration/equipment evidence beside each candidate.
6. Operator reviews only unresolved CREATE / MOVE / MERGE / LOGISTICS / AMBIGUOUS rows.
7. Build a controlled non-Production reconstruction candidate.
8. Browser-review and acceptance before any Production mutation.

## Related Durable Sources

- Setup Planning Operating Model — 2026-09-08
- Setup Planning Candidate Work View — 2026-09-09
- Setup Smart Scheduler Workflow — 2026-09-09
- Setup Pick List Tablet Workflow — 2026-09-09
- Issue #122 — Setup Session planning / Pick List / movement umbrella
- Issue #132 — Captain work-report duration and multi-day effort capture
