# Setup Scheduling Board Contract — 2026-09-17

| Document Control | Value |
|---|---|
| Document Type | Engineering Planning / Execution Contract |
| System | Production Database — Setup Session |
| Status | IMPLEMENTATION CANDIDATE — #205 disposable acceptance required |
| Owner | MSB Production Database engineering |
| Related Work | #122, #132, #145, #172, #175, #205 |
| Candidate Branch | `agent/setup-205-scheduling-board` |

## Purpose

Define the annual Setup Scheduling Board as the rolling dispatch and historical-learning layer between the reusable Setup Catalog and field execution.

The board must support near-term replanning without destroying the evidence needed to understand how Setup was actually completed. It also must support legitimate one-season work without contaminating permanent reusable knowledge.

## Three Layers of Setup Knowledge

Do not collapse these concepts:

```text
Reusable Setup Catalog
    = normal process knowledge intended to carry forward

Annual Setup Session
    = this season's work set and annual planning state
    = reusable annual occurrences + season-only work/gates

Actual execution history
    = what happened on a specific Setup Day / work period / crew lane
```

The annual Session begins from reusable knowledge but is allowed to diverge for the real season.

Actual execution is evidence. Later replanning must not erase it.

## Setup Day Number

Each annual work day has a persisted **Setup Day Number**.

The board displays:

```text
Day Number + DOW + actual Date
```

Example:

```text
Day 6 · SAT · 2026-10-10
```

Rules:

- Setup Day Number is annual operational identity, not day-of-year.
- DOW is derived from `work_date`; it is not an independent stored truth.
- Day Number follows actual/planned MSB Setup work days, not elapsed calendar days since an arbitrary season start.
- Early-access locating/layout work while the park remains open can legitimately be an early Setup Day.
- Saturday receives a visible planning cue because volunteer turnout is commonly stronger.
- Sunday is a strong avoid/warn default, not an irreversible database prohibition.
- Once a work day and actual work history exist, its Day Number is historical identity and should not be silently renumbered.

## Rolling Board

The first board has four temporary crew lanes:

```text
Crew A
Crew B
Crew C
Crew D
```

They are not person groups.

Work periods remain:

```text
MORNING
AFTERNOON
ALL_DAY
```

A crew/work-period cell can contain multiple ordered annual tasks. This is required because real tasks often take less than one shift.

Example:

```text
Day 2 / Morning / Crew A
    1. Locate Old Man Winter
    2. Locate Hwy 42
    3. Locate Front Entrance
```

The order inside the cell is planning/execution context worth preserving.

Drag/drop is the preferred fast interaction, but non-drag Schedule / Move / Up / Down / Remove controls must remain available.

`ALL_DAY` is one semantic assignment. It must not be materialized as two independent Morning/Afternoon assignments merely for display.

## Pick List Downstream Contract

The Scheduling Board decides **what work is planned for which Setup work day / crew / work period**.

Physical fulfillment is downstream from that decision.

The current schedule is the driver for the Pick List:

```text
scheduled annual work
    + authoritative physical/logistics relationships
    -> current Pick List
```

The Pick List resolves the physical requirements for scheduled work, including as applicable:

- required Displays / LOR materials;
- current Display -> Container relationships;
- required KIT/support Containers;
- Extra Materials;
- T-Posts, spacers, and other governed Setup physical requirements.

These relationships are not primarily Scheduling Board search criteria. They exist so that once work is scheduled, the operation knows what must be picked/staged for that scheduled work.

The Pick List must remain current with the schedule. Future schedule changes must flow through without requiring a second manual planning step:

- scheduling work adds its governed physical requirements to the applicable Pick List;
- moving future work moves its Pick List demand with it;
- removing/defering future work removes that demand from the current Pick List;
- authoritative requirement changes are reflected by the current Pick List projection.

The system should not require operators to maintain a second independent physical-picking plan that can drift from the Scheduling Board.

Planning is expected to occur in advance, so the current Pick List should normally already represent the upcoming scheduled work.

## Annual Candidate States

The board distinguishes at least:

```text
READY_TO_SCHEDULE
BLOCKED
NEEDS_SCHEDULING_AGAIN
SCHEDULED
WAITING_ON_WORK_ORDER
COMPLETE
```

Meaning:

- **Ready to Schedule** — incomplete annual work whose annual prerequisites are satisfied and which has no future assignment.
- **Blocked** — annual prerequisite is incomplete.
- **Needs Scheduling Again** — actual progress exists / task is IN_PROGRESS but no future continuation is scheduled.
- **Scheduled** — one or more future unworked assignments exist.
- **Waiting on Work Order** — a Work-Order gate is waiting for the authoritative Work Order to complete.
- **Complete** — Setup completion is recorded or an accepted Work-Order gate is satisfied.

Blocked work may be deliberately scheduled by a Manager when policy permits, but the warning must remain visible.

## Historical Assignment Identity and Stickiness

A scheduled work occurrence needs stable identity independent of the annual task.

Conceptually:

```text
annual task
    -> scheduled assignment
       Setup Day
       work date
       shift
       crew lane
       sort order
       planned crew
       actual evidence
```

Before actual work exists, a future assignment may be:

- moved to another day;
- moved to another shift or crew lane;
- reordered within a lane; or
- removed back to Needs Scheduling.

Once actual work/progress exists for the assignment:

- its work day, shift, crew lane, and sequence become historical;
- the assignment may not be moved or deleted;
- unfinished work receives a new continuation assignment.

This rule is database-authoritative, not merely a browser convention.

## Season-Only Annual Tasks

A one-off annual task does **not** belong in `ref.setup_task` merely because the scheduler needs to place it.

Season-only work is created and maintained in the selected annual Setup Session.

It participates in:

- annual order;
- annual prerequisites;
- scheduling;
- Work Order linkage;
- progress/completion where applicable; and
- historical reporting.

It does not automatically appear in any later Setup Session.

A season-only task can become reusable only through a later explicit reusable-reconciliation decision.

`inactive reusable task` and `season-only annual task` are different states and must not substitute for one another.

## Annual Task Snapshot

An annual occurrence retains the planning fields used for that season rather than continuously dereferencing mutable reusable values.

The annual snapshot includes the applicable task name, scope, task type, normal crew guidance, expected duration, completion point, readiness/weather guidance, and annual notes.

This enables a truthful comparison later:

```text
what reusable knowledge said when the season was planned
vs.
what the annual season actually used
vs.
what happened in the field
```

The reusable Catalog remains separately editable under its normal Manager authority.

## Annual Dependencies

Annual dependencies are session-scoped.

Reusable prerequisites seed the annual dependency graph when annual occurrences are created.

Managers may then:

- preserve the seeded relationship;
- add annual-only dependencies;
- insert season-only tasks/gates into the chain; or
- remove/change an annual dependency without rewriting the reusable prerequisite graph.

Circular annual dependencies fail closed.

## Magic Igloo Acceptance Case

The current inactive reusable placeholders:

```text
Task 224 — See Work Order 372
Task 225 — See Work Order 156
```

are not the intended permanent model.

The 2026 annual plan needs:

```text
Layout / Erect Frame / Strap Down
    -> 2026-only weld repair / Work Order 372
    -> Install Skins and Bungees
    -> 2026-only manufacturer skin repair / Work Order 156
    -> Install Lighting, Cameras, Mats, Signs, and Finish Setup
```

The two repair gates:

- exist only in the 2026 annual Session;
- are linked to real `ops.work_order` identities;
- participate in annual prerequisite logic;
- remain visible in 2026 history; and
- do not seed the next season unless explicitly promoted.

Work Order owns repair lifecycle. Setup owns annual sequence and dependency meaning.

A linked Work Order gate may be considered satisfied from authoritative Work Order completion without copying the repair lifecycle into Setup.

## Reusable Planning Summary Boundary

The existing **Reusable Setup Catalog Planning Summary** remains a reusable-Catalog review artifact.

It intentionally projects active reusable tasks and should not be expanded to include every inactive historical row.

The annual Scheduling Board/report is a separate projection of the annual work set:

```text
reusable annual occurrences
+ season-only annual work
+ annual schedule / actual history
```

## Learning Back Into the Reusable Catalog

Annual execution should improve future Setup, but must not rewrite the Catalog automatically.

Required lifecycle:

```text
annual plan + actual execution
    -> reusable-change candidates
    -> Manager review
    -> explicit confirmation
    -> selected reusable changes applied
```

Candidate changes may include:

- reusable relative order;
- prerequisites;
- normal crew guidance;
- expected duration;
- reusable task boundary split/merge;
- material/resource guidance; or
- promotion of a season-only task that proved recurring.

Annual history remains evidence even when a proposed reusable change is rejected or deferred.

No blanket regeneration of the Reusable Catalog from one year's schedule is acceptable.

## Production Crew Reporting / Proposal Boundary

Issue #205 does not replace Report Work or field-observation/Work Order intake.

Current ownership:

- **#132** — actual Setup work reporting and Production Crew execution/reporting authorization;
- **#172** — durable Production Crew observation/improvement intake and Manager triage;
- **#175** — governed Setup correction / Work Order handoff;
- **#205** — annual schedule/assignment identity and context.

Production Crew may directly save legitimate execution facts such as:

- actual crew size;
- elapsed work duration when #132 implements it;
- progress/quantity;
- what was completed / remains; and
- explicit task completion.

Those facts do not require Manager confirmation merely because they may later inform reusable guidance.

When Production Crew proposes a durable change they cannot authorize, the handoff must preserve known context rather than ask them to recreate it:

- Setup Session;
- annual task;
- reusable source task when applicable;
- Setup Day Number and date/DOW;
- scheduled-assignment identity;
- shift and crew lane;
- Stage/Scene;
- authenticated reporter;
- actual work evidence;
- current reusable value being questioned; and
- proposed correction/evidence.

The proposal does not directly mutate reusable knowledge.

Some older controlled Setup documents still contain the superseded Captain/Alternate-only work-report authorization wording. #132/#172/#175 implementation/closeout must reconcile those documents. #205 must preserve the data/context needed for the accepted Production Crew workflow and must not reintroduce the obsolete restriction.

## Migration Boundary

Migration 050 is the #205 candidate foundation.

The existing schedule tables currently have no accepted real 2026 operational schedule, so #205 can correct scheduling identity/constraints before the first real annual launch.

Migration 050 must nevertheless be safe against any existing historical/review rows and must not create the real 2026 Setup Session.

The real 2026 Session remains gated by #145 FINAL and the accepted disposable 2026 seed proof.

## Acceptance Direction

Disposable acceptance must prove at minimum:

1. active reusable tasks seed as reusable-origin annual snapshots;
2. a season-only task can be created without creating a reusable Catalog row;
3. annual dependencies can include a season-only task and reject cycles;
4. Setup Day Number persists while DOW derives from the date;
5. Crew D is valid and an unsupported lane is rejected;
6. multiple ordered tasks can occupy one crew/shift;
7. one annual task can have distinct Morning and Afternoon assignments on the same work day when needed;
8. future unworked assignments can move/reorder/remove;
9. actual/progress evidence locks historical assignment identity;
10. unfinished work can receive a later continuation assignment;
11. the Magic Igloo Work Order gate pattern can be represented;
12. linked Work Order completion can satisfy the annual gate without copying Work Order lifecycle;
13. a disposable next-season seed omits season-only work;
14. the reusable Planning Summary remains reusable-only;
15. #132/#172/#175 can identify the exact annual assignment/context needed for reporting and correction proposals; and
16. no Production mutation occurs until the exact candidate passes disposable regression/browser acceptance and the governing Server Management runbook is retrieved in the deployment thread.
