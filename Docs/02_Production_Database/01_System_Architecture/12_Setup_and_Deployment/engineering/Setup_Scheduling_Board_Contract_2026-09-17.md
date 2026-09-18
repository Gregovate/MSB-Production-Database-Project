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

Each Setup work day has its own temporary crew lanes.

A newly created work day starts with one default crew:

```text
Crew A
```

The Manager may use **Add Crew** for that work day to create Crew B, Crew C, Crew D, Crew E, and additional crews as needed. Unused crews do not consume board space, and different work days may have different crew counts.

There is no fixed four-crew business limit.

Crew identity must be explicit at work-day scope rather than inferred only from scheduled assignments, because an empty newly-added crew must exist before work is assigned to it.

These are scheduling crews, not person groups.

The operator-facing work periods are:

```text
AM
PM
```

MSB normally has a non-work lunch hour from **12:00–1:00**.

A crew/work-period cell can contain multiple ordered annual tasks. This is required because real tasks often take less than one shift.

Example:

```text
Day 2 / AM / Crew A
    1. Locate Old Man Winter
    2. Locate Hwy 42
    3. Locate Front Entrance
```

The order inside the cell is planning/execution context worth preserving.

Long work is scheduled once and consumes working-time capacity from the shift where it starts. If an AM task exceeds the remaining AM capacity, it continues after the 12–1 lunch gap and consumes the corresponding PM capacity.

Conceptually:

```text
AM task duration
  -> consume remaining AM work minutes
  -> lunch 12–1 does not count as task duration
  -> overflow continues in PM
  -> remaining PM capacity is reduced
```

The board should not have a dedicated **All Day** column. A Church-scale task may visually continue across AM and PM while remaining one scheduled work item.

Existing historical `ALL_DAY` rows may remain as compatibility/history evidence; the new scheduling UX should be shift/capacity based rather than create new work merely to fill a third All Day lane.

Drag/drop is the preferred fast interaction, but non-drag Schedule / Move / Up / Down / Remove controls must remain available.

## Annual Work Finder / Selector

The original operator sketch defines the primary planning dimensions for selecting work:

```text
Task List | Time | Crew | Effort
Sort/Select by Name, Crew Effort
```

The annual work finder must therefore support planning by:

- **Task / Name**;
- **Time** — expected duration/time requirement;
- **Crew** — minimum crew size (`normal_crew_min` / annual snapshot equivalent); and
- **Effort** — physical effort level (`LIGHT`, `MODERATE`, or `HEAVY`).

This is not merely a free-text task-name search. The scheduler must be able to sort/filter/select work using the available time, **minimum crew size**, and physical-effort characteristics of the task. The full normal crew range may still be displayed as context, but the Crew selector itself is keyed to the minimum crew requirement.

Stage/Scene and annual Work Order context may be exposed as supplemental search/filter context, but they do not replace the original Task / Time / Crew / Effort selector.

## Crew Fatigue / Consecutive HEAVY Work

Physical effort is reusable task knowledge:

```text
LIGHT
MODERATE
HEAVY
```

The scheduler should avoid assigning **HEAVY work back-to-back to the same work-day crew**.

The rule is sequence- and crew-specific:

- HEAVY -> HEAVY on the same crew should produce a visible planning warning;
- HEAVY work on different crews does not conflict merely because it occurs on the same day or period;
- consecutive HEAVY tasks stacked within one crew/period should also warn;
- a HEAVY Morning assignment followed by HEAVY Afternoon work for the same crew should warn.

This rule depends on explicit work-day crew identity. It is not enough to know that two HEAVY tasks occur on the same date.

The warning should help the Manager choose LIGHT or MODERATE work after HEAVY work when practical. It is a scheduling avoidance/warning rule, not a database hard prohibition unless a later policy explicitly makes it one.

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

The preferred physical-readiness target is **the day before the scheduled work date**. For work scheduled on date D, #206 should normally derive a staged-by target of D-1 and distinguish whether the required material is merely picked, already in the park, or actually staged/ready for the work.

This is an operational preference rather than a rigid calendar prohibition. Earlier staging is valid, later exceptions may be necessary, and schedule changes must never erase physical movement/staging facts that already occurred.

## Shift-Level Crew Availability — Baby-Step Model

A work-day crew is a temporary scheduling lane, not a roster.

The number of people available to that crew may change across the lunch boundary. For example:

```text
Crew A
  AM planned availability = 6
  PM planned availability = 4
```

The scheduler may capture these as **optional numeric planning estimates** at work-day crew + shift scope.

Do not schedule named volunteers in this release. Do not require person-to-crew membership, individual availability calendars, or automatic volunteer assignment.

The original **Crew** finder dimension means task minimum crew size. When a shift-level planned headcount is known, the board may compare it to the task minimum and show a warning if the task appears understaffed. Missing planned headcount never blocks scheduling.

Actual crew count is execution evidence and remains owned by Report Work.

The existing assignment-level `planned_crew_count` is not the preferred operator model for new #205 scheduling because it would require repeating the same shift availability on every task. Preserve compatibility where necessary, but model new planning around work-day crew + shift availability.

2026 should remain a learning season. More detailed volunteer/crew planning should be considered only after actual institutional evidence demonstrates a need.

## Shift Capacity / Spillover

Expected duration is working time used for planning capacity.

The scheduler should show when the ordered work for a crew fills the available AM or PM work minutes.

A task may begin in AM and carry into PM. The same task's PM continuation is not a second independent task assignment and must not produce a false same-task HEAVY -> HEAVY fatigue warning.

Lunch from 12:00–1:00 is a normal non-work gap and is not counted as task duration.

If actual work remains incomplete after its planned duration or planned day, execution remains incomplete and a later continuation may be scheduled. Planned duration does not imply completion.

Current 2026 planning communication gives a practical morning pattern: Production Team huddle at about 8:30, arrival/work start in the park around 8:45–9:00, lunch around noon, and PM work resuming around 1:00. The board may therefore use **about 3 working hours before lunch** as an advisory AM spillover cue.

This is not a hard time-clock rule and does not establish a PM end time. The scheduler may show that known expected AM work extends past lunch into PM, but it must not block work or fabricate an exact end-of-day capacity.

## Annual Readiness Conditions

Readiness is separate from hard predecessors.

A hard predecessor means another annual Setup task must be complete first.

A readiness condition means an outside/site condition must be true before the task is normally schedulable, for example:

- Festive Trees wait for leaf fall;
- Post Office animatronics wait for Area 4 bathroom winterization;
- Santa's Workshop animatronics wait for Area 1 / Office winterization;
- cord-laying work waits for grass cutting to be complete in the applicable park section;
- city access / asphalt work may delay when park work can begin.

Reusable `readiness_note` preserves the durable condition text. Each annual occurrence has its own readiness state:

```text
READY
NOT_READY
```

A reusable task with no readiness condition begins the annual Session READY. A reusable task with a nonblank readiness condition begins NOT_READY until a Manager confirms the outside condition is satisfied.

The scheduler must:

- show the readiness condition and annual state prominently;
- keep NOT_READY work out of the normal Available Now list;
- keep it visible/searchable in Outstanding / Blocked;
- let a Manager mark the annual condition Ready or Not Ready;
- never substitute a guessed date for the condition;
- preserve hard-predecessor state independently.

Blocked work may still be deliberately placed by a Manager under the existing warning-based planning rule when operational judgment requires it.

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

- **Ready to Schedule** — incomplete annual work whose hard predecessors are satisfied, annual readiness is READY, and which has no future assignment.
- **Blocked** — a hard predecessor is incomplete or the annual readiness condition is NOT_READY.
- **Needs Scheduling Again** — actual progress exists / task is IN_PROGRESS but no future continuation is scheduled.
- **Scheduled** — one or more future unworked assignments exist.
- **Waiting on Work Order** — a Work-Order gate is waiting for the authoritative Work Order to complete.
- **Complete** — Setup completion is recorded or an accepted Work-Order gate is satisfied.

Blocked work may be deliberately scheduled by a Manager when policy permits, but the warning must remain visible.

## Schedule -> Work Packet -> Actual Report Work

The annual schedule is **planning intent**, not actual execution truth.

The Setup execution flow has three distinct layers:

```text
Scheduling Board
    -> publish/release selected work as a Work Packet
    -> Production Crew performs field work
    -> Report Work records what actually happened
```

The published Work Packet is an execution artifact derived from the current annual/scheduled context. Printable/offline/currentness behavior is owned by #175.

Report Work is authoritative for actual execution evidence and is owned by #132.

Plan and actual may legitimately differ because of volunteer turnout, weather, equipment, readiness, early/late completion, or field decisions. The system must not require operators to rewrite schedule history merely to make the plan match actual execution.

When actual work matches a scheduled assignment, retain the stable assignment link/context.

When legitimate annual work is performed that was not on the planned/published packet, Report Work must still be able to preserve the actual work occurrence and its annual-task/work-day/shift/crew context without fabricating a prior schedule assignment.

This separation is intentional institutional evidence:

```text
planned / published
    versus
actual execution
```

Future reconciliation may use that evidence to propose reusable guidance changes, but actual execution never automatically overwrites reusable Catalog knowledge.

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

1. active reusable tasks seed as reusable-origin annual snapshots, including reviewed physical effort;
2. a season-only task can be created without creating a reusable Catalog row;
3. annual dependencies can include a season-only task and reject cycles;
4. Setup Day Number persists while DOW derives from the date;
5. each new work day begins with exactly one default Crew A;
6. a Manager can add additional crews for that work day, including Crew E and beyond without a fixed four-crew ceiling;
7. optional planned crew availability can differ between AM and PM for the same crew;
8. multiple ordered tasks can occupy one crew/shift;
9. the same annual task is planned only once on a work day; long work may continue across lunch/into PM without fabricating a duplicate schedule assignment;
10. the operator-facing board uses AM/PM rather than a dedicated All Day column while preserving legacy All Day history;
11. the work finder supports Task / Time / minimum Crew / Effort and separates available work from blocked/outstanding work;
12. reusable readiness conditions seed annual READY / NOT_READY state correctly and a Manager can toggle annual readiness without changing the reusable condition text;
13. same-crew HEAVY -> HEAVY is surfaced as an advisory warning only;
14. future unworked assignments can move/reorder/remove;
15. actual/progress evidence locks historical assignment identity;
16. unfinished work can receive a later continuation assignment;
17. the Magic Igloo Work Order gate pattern can be represented;
18. linked Work Order completion can satisfy the annual gate without copying Work Order lifecycle;
19. a disposable next-season seed omits season-only work;
20. the reusable Planning Summary remains reusable-only;
21. #132/#172/#175 can identify the exact annual assignment/context needed for downstream reporting/publication without #205 taking ownership of those workflows; and
22. no Production mutation occurs until the exact candidate passes disposable regression/browser acceptance and the governing Server Management runbook is retrieved in the deployment thread.
