# Setup Scheduling Board Contract — 2026-09-17

| Document Control | Value |
|---|---|
| Document Type | Engineering Planning / Execution Contract |
| System | Production Database — Setup Session |
| Status | PRODUCTION ACCEPTED — real 2026 annual Session and Scheduling Board live |
| Owner | MSB Production Database engineering |
| Last Reviewed | 2026-09-25 |
| Related Work | #122, #132, #145 (complete), #172, #175, #205 |
| Historical Implementation Branch | `agent/setup-205-scheduling-board` |

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

On desktop, the **Needs Scheduling** finder pane and the **Rolling Work Days** pane are independent working surfaces and must scroll vertically independently. Dragging near the top/bottom edge of either pane should auto-scroll that pane so a task can be moved across a tall board without losing the other pane's position. Responsive narrow-screen layouts may return to normal document flow.

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

For **Time** and **minimum Crew**, the operator can choose either `≤` or `≥` against one value. This supports both practical questions:

```text
Crew ≤ 3  -> what can this small crew handle?
Crew ≥ 6  -> what work needs a larger group?

Time ≤ 2h -> what can fit in a short window?
Time ≥ 4h -> what are the longer jobs?
```

Blank remains Any. A two-sided numeric range is intentionally deferred unless 2026 use demonstrates a need.

## Pre-2026 Task-Finder Authority

Before the real annual Setup Session exists, the active **Reusable Task Catalog** is the single current task-definition authority and the single current task-finder population.

The existing 2025 Session was a temporary construction/verification marker used while building the new Setup system. **There is no authoritative 2025 Setup schedule history.** It has no continuing operational planning or historical authority. It must not:

- determine whether a current reusable task is visible;
- add `NOT IN 2025` identity/badges to current work;
- supply the current reusable Plan order;
- act as a proxy for a current-year Ready / Not Ready decision; or
- force the operator into the full Reusable Task Catalog merely to edit routine planning fields.

Pre-2026 **Plan order** uses reusable Catalog order. With **All Stages / areas**, the whole-Setup `ref.setup_task.baseline_plan_order` is authoritative. When the finder is narrowed to a Stage or Site-wide scope, the operator-visible reusable step `display_order` is authoritative within that scope (for example 10/20/30/40/50), with `baseline_plan_order` as fallback. After a real annual Session exists, `ops.setup_session_task.planned_order` becomes that season's whole-Setup ordering authority.

The normal pre-2026 correction path is the compact **Edit Planning Info** dialog for crew guidance, expected Hours/Minutes, Effort, Readiness note, Weather note, Completion point, and Reusable notes. **Open Full Reusable Task** is the secondary drill-down for deeper information such as Resources, material ownership, Captain knowledge, Procedure context, and other full-record maintenance.

The pre-2026 finder does not expose annual-only states such as Deferred as primary planning filters when there is no defined operator action using them. Underlying historical/annual values remain preserved for compatibility.

## Finder Readiness Visibility and Drill-down Navigation

Readiness remains a **soft blocker**. A readiness condition does not become a hard scheduling prerequisite merely because the finder offers a readiness visibility control.

The finder may provide a **Ready only** visibility toggle so an operator can temporarily hide tasks whose current readiness state is `NOT_READY` while scanning practical candidates. Turning that visibility filter off must immediately restore those soft-blocked tasks. The control changes only what the finder shows; it does not rewrite readiness state, prerequisite state, or scheduling eligibility.

When a Manager drills from the Task Finder into a reusable task to correct durable Catalog knowledge, that drill-down must preserve the operator's planning context. Returning to the Task Finder—through either an explicit **Back to Task Finder** action or browser Back—must restore the same:

- Stage / area;
- Scene / scope;
- sort mode;
- task-name search;
- Blocking ON/OFF state;
- readiness visibility state;
- status filters;
- Time / Crew comparators and values;
- Effort filter;
- compact/expanded finder presentation; and
- practical scroll position.

The compact **Edit Planning Info** dialog is a governed editing surface. If its fields have changed and the Manager chooses **Open Full Reusable Task**, those edits must be saved successfully **before** the drill-down occurs. A failed save leaves the Manager in the compact editor; navigation must not silently discard the draft.

The full reusable task editor has **one reusable save action**. Physical Effort is reusable planning knowledge and is saved by **Save Reusable Task** together with the reusable definition fields. A separate **Save Effort** button is not part of the operator contract.

A reusable-task correction opened from the finder is therefore a temporary drill-down, not a workflow reset into the Reusable Task Catalog.

The full reusable task editor keeps the established dirty-edit protection. If reusable or annual fields are dirty, browser Back, **Back to Task Finder**, Setup-tab changes, season changes, and other internal navigation must use the same explicit **Save and continue / Discard and continue / Stay on this task** decision. Browser-history routing with `pushState` / `popstate` is not allowed to bypass that warning.

Setup tab/view navigation should participate in browser history so Back/Forward can move between Setup views instead of unexpectedly abandoning the operator's current Setup workflow after internal navigation.

## Scheduler Planning-Info Correction

The Scheduling Board is often where missing/TBD planning knowledge becomes obvious.

Before actual work exists, a Manager may use **Edit Planning Info** directly from the scheduler to correct:

- minimum/normal crew guidance;
- expected duration;
- physical effort;
- readiness condition;
- weather note;
- completion point.

For reusable-origin work, this is an explicit reusable-knowledge correction.

- **Before the real annual Session exists**, Edit Planning Info updates the reusable Catalog only. The 2025 construction-marker rows are not rewritten merely to support current planning.
- **After a real annual Session exists**, the accepted annual planning command may refresh that current season's annual snapshot together with the reusable knowledge where the workflow explicitly calls for both.

For season-only work, the correction remains annual-only.

Once actual work exists, the annual planned context is historical and the scheduler must no longer rewrite it. Later reusable lessons belong through governed post-season/reconciliation workflows.

## Scheduling Audit Visibility

Scheduling and reusable planning edits are accountability-sensitive. The Scheduling UI must therefore expose the existing database audit identity in a compact operator-readable form rather than requiring backend forensics.

At minimum, Manager-facing planning/task context should make available:

```text
Created <time> by <person>
Last updated <time> by <person>
```

The displayed identity must come from the governed database audit fields and must reflect the authenticated person who actually performed the write. A changed `updated_at` paired with a stale prior `updated_by` / `updated_by_person_id` is a database audit failure, not acceptable UI behavior.

This requirement does not mean every Setup screen must display all six audit columns. Scheduling exposes the useful human summary because knowing who changed planning information and when is operationally important.

Historical attribution that predates an audit defect is not part of the 2026 Scheduling launch repair. The launch-critical requirement is correct attribution for writes going forward.

## Chronological Setup Day Number

Normal operator use does not manually assign Setup Day Number.

For future unworked days, the scheduler automatically assigns/resequences Setup Day Number by `work_date`, regardless of insertion order.

Example:

```text
added first:  Oct 5
added second: Oct 8
added later:  Oct 1
```

must display/number chronologically:

```text
Day 1 — Oct 1
Day 2 — Oct 5
Day 3 — Oct 8
```

Once actual work exists, historical day identity is preserved. Only the mutable future range is resequenced.

## Crew Fatigue / Consecutive HEAVY Work

Physical effort is reusable task knowledge:

```text
LIGHT
MODERATE
HEAVY
```

When a Crew Captain is known, the advisory fatigue signal follows that named working person across the rolling schedule, including across work days.

Rules:

- HEAVY -> HEAVY for the same Captain should produce a visible planning warning;
- HEAVY work under different Captains does not conflict merely because it occurs on the same day or nearby days;
- consecutive HEAVY tasks stacked under one Captain/crew should warn;
- a HEAVY assignment at the end of one work day followed by HEAVY work for the same Captain on the next work day should warn when those are consecutive assignments in that Captain's schedule;
- when Captain is TBD, fall back only to conservative same-work-day crew sequence warning rather than inventing person continuity;
- the same long HEAVY task carrying across lunch remains one assignment and must not warn against itself.

The warning should help the Manager choose LIGHT or MODERATE work after HEAVY work when practical. It is advisory, not a scheduling prohibition.

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

## Work-Day Crew Captain

A work-day crew may have one optional Captain for that Setup day.

The Captain is a working person and is intentionally lighter-weight than a roster:

```text
Crew A
  Captain = Tom
  AM planned availability = 6
  PM planned availability = 4
```

The system does **not** need the other five names.

If planned crew size is 1, the Captain effectively identifies the one planned person without creating a roster.

Captain rules:

- Captain is optional and never blocks scheduling;
- one Captain applies to the whole work-day crew in this release;
- Crew Captain is annual scheduling context, not a permanent team;
- once actual work exists for that crew, changing the Captain would rewrite history and is therefore blocked;
- Production Crew reporting authority remains role-based and must not depend solely on Captain assignment.

### Additive reusable Captain learning

When a crew with Captain Tom is assigned a reusable task whose existing reusable Captains do not include Tom, the scheduler may prompt:

> Tom is Captain of Crew A but is not currently a reusable Captain for this task. Add/promote Tom as a reusable task Captain?

If confirmed:

- add/promote Tom through the governed reusable Captain command;
- do **not** delete, demote, or replace any existing Captain;
- if Tom was already ALTERNATE or ADVISOR for that task, explicit confirmation may promote Tom to CAPTAIN;
- if Tom is already CAPTAIN, no prompt is required.

This is explicit additive institutional learning, not automatic overwrite.

The prompt must make the two decisions clear. If the assignment is already being scheduled, declining reusable learning means **keep the schedule only**; it does not remove the Crew Captain from the scheduled crew context. Generic OK/Cancel controls should therefore be accompanied by explicit wording such as “OK = Add/promote reusable Captain; Cancel = Keep schedule only.”

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

The original **Crew** finder dimension means task minimum crew size. When a shift-level planned headcount is known, the board compares it to the task minimum and shows a prominent **SHORT CREW** warning if the task appears understaffed.

A known shortage requires an explicit **OK / Cancel** confirmation before the assignment is created or moved. The prompt states planned crew, task minimum, and shortage. OK proceeds and preserves the visible SHORT CREW warning; Cancel leaves the assignment unchanged. This is still advisory rather than a hard prohibition. Missing planned headcount or missing task minimum does not fabricate a warning.

If the same placement also violates readiness or hard-predecessor guidance, combine the known warnings into one deliberate confirmation where practical rather than presenting a chain of unrelated popups.

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

Blocked work may still be deliberately placed by a Manager under the existing warning-based planning rule when operational judgment requires it. Once deliberately scheduled, its **planning bucket is SCHEDULED** even though readiness/predecessor warnings remain visible on the assignment. It must not remain simultaneously in the unscheduled/blocked finder pool.

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

- **Ready to Schedule** — incomplete annual work whose hard predecessors are satisfied, annual readiness is READY, and which has no unworked assignment.
- **Blocked** — an unscheduled task whose hard predecessor is incomplete or whose annual readiness condition is NOT_READY.
- **Needs Scheduling Again** — actual progress exists / task is IN_PROGRESS but no future continuation is scheduled.
- **Scheduled** — one or more unworked schedule assignments exist. This includes a missed prior assignment with no actual work, because it remains movable planning intent rather than execution history.
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

## Rolling Historical-Day Visibility and Continuations

The default board is action-oriented.

By default, show:

- current/future work days; and
- prior work days that still have unresolved scheduling/execution consequences.

A prior work day whose assigned work is fully resolved is hidden from the default board but remains available under a control such as **Show prior / completed work days**. Hiding is presentation only; historical rows are never deleted.

Prior-day rules:

```text
past assignment + no actual work
    -> still movable planning intent
    -> may be moved to current/future day

past assignment + actual work + complete
    -> immutable history
    -> prior day may leave default board

past assignment + actual work + incomplete
    -> immutable historical occurrence
    -> annual task becomes Needs Continuation
    -> create a distinct current/future continuation assignment
```

If started/incomplete work has no continuation scheduled yet, the prior day remains visible by default (or equivalently must remain strongly surfaced as unresolved). Once a future continuation exists, the old historical day may leave the default board and remain available through the history toggle.

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

Before actual work exists, an unworked assignment remains planning intent even if its planned date has already passed. It may be:

- moved to another day;
- moved to another shift or crew lane;
- reordered within a lane; or
- removed back to Needs Scheduling.

Once actual work/progress exists for the assignment:

- its work day, shift, crew lane, and sequence become historical;
- the assignment may not be moved or deleted;
- unfinished work receives a new continuation assignment.

This rule is database-authoritative, not merely a browser convention.

## 2026 Task Deletion Boundary

2026 is the first authoritative Setup-history year. Planning state is not historical execution evidence.

Until real work is reported against a task, an authorized Manager must be able to fully delete it even if it has already been seeded into the 2026 annual Session, ordered, assigned to a work day/crew, or connected by planning-only dependencies.

For an unworked reusable task, governed deletion may remove:

- the reusable Catalog definition;
- its unworked 2026 annual occurrence;
- planning-only work-day assignments; and
- annual/reusable planning dependencies owned by that task.

For an unworked 2026-only task, governed deletion may remove the annual occurrence and its planning-only relationships.

The following do **not** by themselves block deletion:

- annual membership;
- planned order;
- planned date;
- crew/work-day assignment;
- readiness state;
- prerequisite/dependency links.

Material ownership/assignment is **not** disposable planning state. Preserve the existing operator rule: a task that still owns or has assigned physical material must not be deleted until those relationships are explicitly resolved through the existing material-assignment workflow. At minimum this includes governed Display ownership and KIT/support Container assignments; any later physical-material assignment authority must follow the same rule.

The normal 2026 delete command must fail closed when such material assignments remain. It must not silently discard material ownership as cleanup. The Manager first moves/reassigns/clears the material, then retries deletion.

Once actual work/progress/completion or other accepted task execution evidence exists, hard delete must also fail closed and preserve the 2026 record.

No browser direct table DML is permitted; deletion remains an explicit governed Manager action.

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

## Migration / Live Boundary

Migration 050 was the #205 foundation and was intentionally incapable of creating the real 2026 Setup Session by itself. The historical #145 Catalog/seed gate was completed, the governed #122 launch path subsequently created the real 2026 Session, and Production scheduling is now live.

Current authority:

```text
Reusable Catalog = durable recurring knowledge
2026 annual Session = current planning/execution state
schedule assignment = planning intent
reported work = execution history
#206 = physical material-demand / Pick List authority
```

Do not recreate the annual Session, restore pre-launch `2026 = absent` assumptions, or make schedule drag/drop mutate physical movement truth.

## Acceptance Direction / Preserved Contract

Disposable acceptance must prove at minimum:

1. active reusable tasks seed as reusable-origin annual snapshots, including reviewed physical effort;
2. a season-only task can be created without creating a reusable Catalog row;
3. annual dependencies can include a season-only task and reject cycles;
4. future unworked Setup Day Numbers resequence chronologically by work date while historical day identity remains fixed;
5. each new work day begins with exactly one default Crew A;
6. a Manager can add/remove empty crews and reuse the first available crew identity, including Crew E and beyond without a fixed four-crew ceiling;
7. optional planned crew availability can differ between AM and PM for the same crew;
8. a work-day crew may have one optional Captain, and Captain identity becomes historical once actual work exists;
9. confirmed Crew Captain learning adds/promotes reusable Captain knowledge without deleting existing Captains, while declining learning clearly keeps schedule/crew context only;
10. multiple ordered tasks can occupy one crew/shift;
11. the same annual task is planned only once on a work day; long work may continue across lunch/into PM without fabricating a duplicate schedule assignment;
12. the operator-facing board uses AM/PM rather than a dedicated All Day column while preserving legacy All Day history;
13. left finder and right scheduling board scroll independently on desktop and drag-edge auto-scroll supports tall boards;
14. the work finder supports Task / Time / minimum Crew / Effort, human Stage/Scene/readiness/resource/WO context, and ≤/≥ comparators for Time and minimum Crew;
15. reusable readiness conditions seed annual READY / NOT_READY state correctly and a Manager can toggle annual readiness without changing the reusable condition text;
16. deliberately scheduled blocked/NOT_READY work moves to the SCHEDULED planning bucket while retaining its visible warnings;
17. browser fixtures preserve real readiness state rather than fabricating readiness;
18. pre-execution **Edit Planning Info** can correct reusable + annual planning knowledge, but becomes locked once actual work exists;
19. known SHORT CREW placement requires an explicit combined warning/confirmation but remains schedulable after OK;
20. same-Captain HEAVY -> HEAVY is surfaced as an advisory warning across the Captain's ordered assignments; different Captains do not warn merely for proximity;
21. future/current unworked assignments can move/reorder/remove;
22. a missed prior unworked assignment remains movable planning intent rather than becoming fake history;
23. prior resolved days are hidden from the default rolling board and recoverable through a history toggle;
24. actual/progress evidence locks historical assignment identity;
25. unfinished historical work becomes Needs Continuation and can receive a distinct later continuation assignment;
26. the Magic Igloo Work Order gate pattern can be represented;
27. linked Work Order completion can satisfy the annual gate without copying Work Order lifecycle;
28. a disposable next-season seed omits season-only work;
29. the reusable Planning Summary remains reusable-only;
30. #132/#172/#175 can identify the exact annual assignment/context needed for downstream reporting/publication without #205 taking ownership of those workflows; and
31. no Production mutation occurs until the exact candidate passes disposable regression/browser acceptance and the governing Server Management runbook is retrieved in the deployment thread.
