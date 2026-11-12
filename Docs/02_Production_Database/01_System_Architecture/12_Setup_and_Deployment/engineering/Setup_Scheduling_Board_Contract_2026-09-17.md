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

## Local calendar authority — DBG-2026-021 (2026-11-08)

**Established requirement: all MSB operator dates/times and business calendar
boundaries use America/Chicago, including DST.** Host, PostgreSQL connection,
and browser timezone defaults are not business authority. This is a defect
correction under #122/#205 with #132 reporting, not a new timezone preference.

Normal Work Day creation accepts today and later; Historical Day correction
accepts strictly earlier dates. Report Work and Manager correction accept actual
work dates through today, never tomorrow. All three boundaries must agree.
Date-only work_date/performed_on values stay literal calendar dates; never shift
or rewrite them. Instant transport/storage may remain timezone-aware UTC;
operator presentation converts instants to Chicago. UTC arithmetic used solely
to preserve date-only values is not UTC business-day classification.

At 2026-11-09T01:30Z, the business date is 2026-11-08 (19:30 CST).
The existing Chicago browser helper permits November8, while migration069's
session-dependent current_date insert guard rejects it in a UTC session.
Historical UI correctly caps entry at November7, leaving no valid entry route.
This source mismatch is confirmed at main 897a9ab1175402adcfc3ac12223830f3b9bbd663;
live TimeZone/function settings still require read-only verification.

### Implementation boundary

- Add a new migration; do not rerun/edit installed 061/069. Pin TimeZone on the
  four existing insert/historical/report/correction functions to America/Chicago.
  Preserve their bodies, signatures, owners, ACLs, SECURITY DEFINER/search_path,
  management/crew checks, auditing, history locks and transaction behavior.
  Function-scoped configuration restores the caller setting on return and
  avoids changing global PostgreSQL, role, database or service configuration.
- Use an explicit Chicago-aware Python date for both report API validators.
  Use explicit Chicago dates in material-readiness and audit-season queries.
- Reuse existing Chicago browser date logic; correct remaining host-dependent
  board dates/countdowns, standalone pick-date defaults, season defaults and
  displayed timestamps. Preserve timezone-aware movement/offline payloads.
- Historical dialog copy must say normal entry includes today. Preserve input
  on rejection. No relabeling today's actual work as yesterday or tomorrow.
- Preserve existing reports/assignments and actual-date reporting independently
  of the original scheduled date. No bulk repair is authorized by this change;
  other reported entry discrepancies require per-record evidence.

### Required acceptance and release

Test the same instant with UTC and Chicago hosts/connections and a non-Chicago
browser. Cover winter UTC rollover (Nov8 19:30 CST), summer rollover, immediately
before/after Chicago midnight, both DST transitions and the local year boundary.
Normal insertion must accept today/tomorrow and reject yesterday; historical
must accept yesterday and reject today/tomorrow; reports/corrections accept
today and reject tomorrow. Include a Sunday (the reported Nov8 case); warnings
must not become a prohibition on recording actual work.

On one current-Production disposable clone: create the missing local day,
confirm one default Crew A, assign legitimate clone-only test work/captain,
record actual crew/minutes/progress/note on that day, reload and prove the
saved date and history. Test an existing assignment with a different actual
work date without moving the original assignment. Retry/duplicate-day behavior,
authorization, historical audit and partial-work continuation remain protected.
Compare business/history fingerprints across migration: configuration-only SQL
must not rewrite any business rows. Inspect function proconfig/ACLs before/after.

Use the existing reusable Setup disposable launcher, port8898, and the same
prepared clone through browser review. Candidate must carry a distinct matching
client/server release identity. This is DATABASE-CHANGING because functions
change: existing Server Management maintenance/freeze/snapshot/migration/ONLINE
procedure applies only after exact candidate review and explicit deployment
authorization. No Production deployment or operator acceptance is asserted here.

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

A report resolves that assignment for its work day, including a partial or zero-duration report. Remaining annual work returns through the existing Needs Rescheduling / Priority Continuation backlog. It does not keep the reported historical day unfinished while waiting for a future continuation.

For historical-day visibility, completed means all assignments have reports, not that every annual task reached 100%. Such past days may collapse and appear through the Completed filter in both Plan / Schedule and Perform Work. A started timestamp, lock flag, or completion of the annual task elsewhere does not substitute for a report on this occurrence.

Reported assignment badges use that occurrence's reported percentage: **INCOMPLETE — Work Reported** or **COMPLETE — Work Reported**. A past assignment without a report is **LATE — NO WORK REPORTED**. Show a prominent red warning on the assignment and a day-level late count; unresolved late days remain expanded. Provide the existing Report Work path and retain governed removal for unworked assignments. Never unlock or erase execution history to remove a warning.

Captain TBD must be conspicuous in Perform Work's crew heading and in the first Plan / Schedule column under the crew heading, in addition to the assignment-card warning. Capacity indicators do not replace missing-Captain warnings.

Operational date boundaries use America/Chicago with daylight-saving rules, independent of server UTC or browser timezone. The fixed Updated footer identifies a source revision; it is not the operational date.

Operator clarification and implementation tracking: #205, PR #324 (2026-10-09). These requirements are not a claim that the correction is already deployed.

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

### Creation-surface rule

The creation surface determines the intended identity deliberately:

- **Scheduling Board -> Add Task** must ask the Manager to choose either **Reusable Setup Task — every year** or **Season Task Only — this season**. There is no implicit default because the two choices have different identity/lifetime semantics.
- **Reusable Task Catalog -> Add Task** is inherently a reusable-task creation workflow. A task created there is assumed to be reusable and is created in `ref.setup_task`.
- Choosing **Reusable Setup Task** from the Scheduling Board hands off to the same governed reusable Catalog creation workflow; it does not create a separate kind of reusable task.
- Choosing **Season Task Only** creates only the annual/session-scoped row and never creates a reusable Catalog row.

This separation is intentional: the Scheduling Board can create either kind because planning may discover either durable recurring work or a one-season exception, while the Reusable Task Catalog itself represents permanent reusable Setup knowledge.

It participates in:

- annual order;
- annual prerequisites;
- scheduling;
- Work Order linkage;
- progress/completion where applicable; and
- historical reporting.

It does not appear in any later Setup Session.

**Season-only is a permanent identity boundary.** A `SEASON_ONLY` annual task remains in that season for its entire lifetime. It is never converted, promoted, copied, or written back into `ref.setup_task`, and it is never a source for future-season seeding.

If annual experience shows that comparable work should recur in later seasons, an authorized Manager may separately create a new reusable Catalog task through the normal governed reusable-task workflow. That new reusable task is a different reusable identity; the original season-only annual task remains unchanged as historical evidence in its original season.

`inactive reusable task` and `season-only annual task` are different states and must not substitute for one another.

## Annual Task Snapshot

An annual occurrence retains the planning fields used for that season rather than continuously dereferencing every mutable reusable value.

**Task name is the exception for reusable-origin work.** A reusable task has one canonical current name in `ref.setup_task.task_name`. Every operator-facing annual/scheduler surface must show that current reusable name so the Catalog, Task Finder, scheduled assignment, prerequisite display, Work List, Report Work, and related downstream surfaces cannot drift into competing labels for the same `setup_task_id`.

While an annual Session is **PLANNING** or **ACTIVE**, a reusable rename must also synchronize the linked `ops.setup_session_task.annual_task_name` in that same open season. This keeps the stored annual occurrence and every downstream consumer aligned, not merely the current browser presentation.

```text
rename reusable task
    -> ref.setup_task.task_name
    -> same reusable setup_task_id in PLANNING/ACTIVE annual Session
    -> annual_task_name updated to the same value
```

Once a season is **COMPLETE**, its annual name is historical and must not be rewritten by a later reusable rename. The separate `HISTORICAL_VERIFICATION` construction/review Session is likewise not a current-season synchronization target.

`ops.setup_session_task.annual_task_name` remains independently authoritative for **SEASON_ONLY** work because those rows have no reusable source task.

The annual snapshot continues to preserve season planning values such as scope, task type, normal crew guidance, expected duration, completion point, readiness/weather guidance, and annual notes.

This enables a truthful comparison later without creating two current names for one reusable task:

```text
current reusable task identity/name
+
same-season synchronized annual identity label
+
what annual planning guidance was used
vs.
what happened in the field
```

A reusable rename is therefore a durable identity-label correction, not an annual planning override. The scheduler does not provide a separate reusable-name editor; Managers rename reusable work through the Reusable Task Catalog / governed reusable-task edit path. The database synchronizes the same-season annual label, and operator reads also resolve the current reusable name defensively so stale data cannot reintroduce a second label.

### Season rollover authority

Do not create a separate Setup-only calendar rollover flag. Annual operational season identity already belongs to `ref.season`, including `season_year`, start/end dates, and `active_flag`.

For Setup annual-name synchronization, however, the definitive freeze boundary is **creation of the next non-historical Setup Session**. Changing `ref.season.active_flag` prepares/identifies the operational year; it does not by itself freeze the prior Setup annual occurrence.

The intended rollover is deliberate:

```text
current newest non-historical Setup Session
    = current Setup season for reusable-name synchronization

no 2027 Setup Session exists
    -> 2026 remains current/open for cleanup
    -> reusable renames continue synchronizing into 2026

activate/prepare 2027 in ref.season
    -> 2027 becomes a valid operational season target
    -> 2026 still remains current for Setup until the 2027 Setup Session exists

create/seed 2027 Setup Session
    -> 2027 becomes the current Setup season
    -> 2026 reusable-name synchronization stops
    -> 2026 annual identity/name is frozen as prior-year history
```

For the 2026 -> 2027 transition, cleanup may therefore continue through the off-season until the 2027 planning Session is actually created. Do not introduce a January 1 trigger merely to force rollover.

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
- never seed a later season or convert into reusable Catalog identities.

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
- creation of a separate reusable Catalog task when annual evidence proves that a recurring task is needed.

A season-only annual identity itself is never promoted or converted. Annual history remains evidence even when a proposed reusable change is rejected or deferred.

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

## 2026-10-05 tablet launch-debug candidate (not Production accepted)

DBG-2026-001/002/003 are being reviewed together: passive COMPLETE SETUP countdowns, direct board/task panel navigation at <=1100 CSS pixels, and a visible In Progress execution-status filter. Existing annual/history/authorization and desktop scroll boundaries remain authoritative. [Candidate scope and acceptance checklist](../../../../../Setup/Acceptance/Setup_205_Tablet_Launch_Debug_Candidate.md) records the exact branch, local validation and pending disposable/tablet acceptance. Production acceptance above does not accept this candidate.


## PR #324 day summaries and reporting accountability (candidate)

Both schedule screens summarize AM and PM as crews / people / tasks. Count a crew once per shift even when it has multiple tasks; planned people include the Captain. Missing counts remain TBD, and legacy All Day task counts remain explicit. Task counts refer to the assigned shift; existing cross-lunch carryover/capacity warnings remain authoritative. Do not add AM and PM people into unique daily attendance.

Perform Work places Captain-scoped LATE / UNREPORTED tasks before normal day sections, using the existing signed-in Captain default and authorization. Each entry directly names the assigned Captain, task, date, crew and shift, with Report Work navigation. Missing Captain identity is CAPTAIN TBD. This detailed accountability list is Perform Work only; existing Manage Schedule navigation supports replanning. Schedule retains prominent late counts and task warnings.

Historical actual person-hours sum the existing reported person-minutes, independently of Show completed. They are labor, not unique volunteers. Actual crew counts can differ by report and must not be summed as headcount. Reported partial work resolves the historical occurrence while remaining annual work needs continuation. No people calendar or extra reporting fields are introduced.

### Final operator preview corrections

Minimum required people are separate from entered planned staffing: each scheduled crew needs at least one person, or its largest sequential task minimum when available. Separate crew requirements add; sequential tasks do not multiply headcount. Captain TBD never implies no staffing demand.

Scheduling requires an operator estimate of time, minimum crew size and effort. Missing estimates open the existing Planning Info editor before placement; save estimates and retry scheduling. Rough estimates are acceptable, fabricated defaults are not. Existing history locks remain enforced. Multi-move validates missing estimates before any assignment mutation.

Keep the existing rescheduling badge colors and priority ordering. Badge text is NEEDS RESCHEDULING — <percentage>% COMPLETE, or NEEDS RESCHEDULING — WORK INCOMPLETE if unavailable. Remove the redundant PRIORITY CONTINUATION banner. KPIs remain deferred by operator direction.

Historical exception: the existing database rejects edits to annual planning once actual work exists. Such continuation tasks remain schedulable with an explicit missing-estimate warning; enforcing new estimates there requires separately governed support and is not silently bypassed in this UI-only release.


## November 9 PR478 — bounded governed release after local-calendar acceptance

The accepted V0.3.106 browser review and migration 079 are **DATABASE-CHANGING**,
even though the migration only adds function-local America/Chicago TimeZone
settings to four existing commands. Preserve every command body, owner, ACL,
existing configuration and all annual/report/audit rows. A passing preview or
source merge must not be mistaken for live installation.

Deploy migration 079 with the **existing** Server Management #37 maintenance
controller and `setup_maintenance_deploy.py`, using the PR478 exact-candidate
release profile. Its immutable target/candidate/migration identifiers, current
live Setup source, reviewed SQL and controller state must all pass first.
Preflight is read-only; the approved mutation runs only after freeze proof and
validated rollback snapshot. Validate source, function settings, original row
fingerprints, health and ONLINE return before declaring server PASS. No
calendar-date change authorizes rewriting historical labor reports.

The related Perform Work QC/history search and `performed_on` labor-attribution
findings remain independently owned by #205/#122; do not silently combine
them into this already accepted date-migration release or require new reports
to conceal stale historical exceptions.

## November 11 — existing crew staffing in Schedule Annual Task (#205)

The scheduling dialog permits staffing entry for existing crews, including unknown
AM/PM counts and a Captain selected through the inline add picker who already has
a crew that day. Existing confirmed counts prefill; unknown stays blank until
entered. The count includes the Captain and applies to all tasks for that crew
and period. The dialog explains this shared scope. Cancel writes nothing.

Save reuses the existing crew-with-tasks transaction and governed crew/assignment
commands. For an existing crew the server reads and validates its day, preserves
the other period and Captain, and updates only the selected period together with
the assignment. Assignment rejection rolls back staffing. No actual work reports,
Captain permissions, or historical movement protections change. The new-crew and
group-drop paths retain their prior behavior. Regression must exercise editable
unknown/known counts, reused Captains, invalid counts, cross-day rejection and
rollback on assignment failure; protected disposable browser review is required.

### Same-day assignment catch-up — November 11 review correction

Ready to Schedule describes readiness and absence of future scheduling; it does
not prove absence of a past assignment. Schedule Annual Task names the selected
annual task and checks for an existing assignment on the selected day. Show that
assignment's date, period and Captain before Save, with Open existing assignment
and Report Work / review report actions. Reported history remains immovable;
unworked assignments can use the existing edit path. No duplicate assignment is
created. Changing to a different day allows normal continuation or retrospective
scheduling. Catch-up reporting uses the existing Manager record report handler,
including completed-day/assignment visibility, without fabricating schedules or
removing historical guards. A duplicate-day guard remains authoritative for races.

### Scheduling backlog versus work awaiting reports — November 11

An active assignment remains scheduled even after its work date passes. Missing
reports do not return it to Ready to Schedule or prove it needs continuation.
Future scheduling takes precedence. Reported IN_PROGRESS work without a future
assignment is Needs Rescheduling even when older occurrences await reports.
Otherwise classify tasks with active unreported assignments as SCHEDULED before
readiness classification. Keep them in Perform Work for catch-up; exclude from
the default scheduling backlog and schedulable printout. An explicitly selected
Scheduled finder filter may still inspect them. Hard-blocker visibility must not
bypass this separation. Cancelled days do not reserve an assignment.

Reported unfinished tasks with no future assignment remain eligible for
continuation, independently of older occurrences awaiting reports. Never-scheduled tasks remain eligible under
existing readiness/prerequisite rules. Completed tasks retain completion. Preserve
the full assignment/report data and catch-up actions; this is classification, not
a data repair, automatic completion, new report, or reassignment.

### Perform Work task identity — November 11 review

Past-assignment review rows and collapsed Perform Work headings display the
same reusable Task number used in the scheduling Catalog beside the task name.
Season-only tasks without a reusable identity display Annual Task plus their
annual identity, explicitly distinguished. Each dated occurrence retains its own
assignment/report identity; repeated names or dates must not be merged. This is
presentation only and does not alter scheduling or report behavior.

When one task has several dated assignments awaiting review, repeat its visible
Task number and name alongside each date/crew/period; retain distinct report
actions for the original assignment identities. Label a shared percentage
Overall task progress, never imply that percentage was reported on each day.

### Prevent unresolved-assignment duplication — November 11

Before creating any new dated occurrence, resolve outstanding unreported active
assignments for that annual task: Report Work for actual work; Move existing
assignment after confirming no work occurred; or Unschedule unworked assignment.
Continuation remains allowed after prior work is reported and no other active
occurrence awaits reporting. Completed annual tasks cannot receive new scheduling.
All existing reported history remains untouched. No automatic completion, report,
merge or deletion is permitted, including the eight audited review cases.

UI checks cover Schedule and both task-drop paths. The common database INSERT
boundary independently enforces this for all writers, including legacy creation
commands and API callers. A BEFORE INSERT trigger serializes creation per annual
task with a row lock, excludes cancelled days, matches assignment-linked and
legacy date/shift-linked reports, and rejects unresolved occurrences with an
actionable message. It does not run on assignment UPDATE, so governed unworked
moves/removals remain available. Changes to reported history keep existing guards.
Migration080 changes command enforcement only; existing assignments are retained.

Scheduled board cards must also display the same Task/Annual Task identity in
their title, not only Perform Work and the scheduling dialog. This is necessary
to distinguish Task178 Tent/Sign from Task184 Stands/Wraps during acceptance.

The scheduling dialog explicitly labels Edit existing assignment versus Schedule
Annual Task. Editing shows original date, period, crew/Captain and states that
Save updates that same assignment rather than creating another occurrence.

### Explicit no-work confirmation for editing a past assignment

Opening an existing assignment is not permission to move work that occurred.
Before any change of date, shift or crew on a past unreported assignment, the
operator must explicitly confirm no work was performed. The dialog shows a
separate confirmation and Report Work action. Without confirmation, preserve
inputs, do not save placement or staffing, and state the required decision inside
the dialog. Planned crew-size-only correction does not imply moving actual work
and remains allowed. Past unreported drag/drop moves require the same explicit
no-work confirmation. Existing report/history command guards remain authoritative.

The no-work confirmation must have a minimum 24px checkbox aligned beside its
statement and a minimum 44px clickable label. Resolving one historical assignment
must not silently resolve other dated occurrences: each requires actual reporting
or an explicit no-work unschedule decision.

Perform Work collapsed cards and past-assignment review entries must identify
stage key/name and scene, or explicitly Stage-level/Site-wide, before Report Work.
Use the owning annual task scope when the assignment projection lacks fields.

### Inspect explicit NOT READY tasks from the Action Center

The NOT READY count must open a matching list derived from the same k.notReady
collection, including unscheduled tasks outside the upcoming seven-day window.
Each row shows Task/Annual Task number, name, Stage/Scene and readiness note,
with the existing guarded Review readiness action. Opening the count expands
and focuses the list; no writes or email occur. Completed/deferred tasks follow
the existing KPI classifier and must not leak into this unfinished-work list.

### Complete outstanding-task inventory

The Manager Action Center must expose every incomplete annual task, including
deferred tasks explicitly labeled Deferred. A complete outstanding-task list
uses k.incomplete once per annual task and shows Task/Annual Task number, name,
Stage/Scene, execution/scheduling/readiness state, documented readiness reason
and current blocker reasons. Existing planning navigation remains authoritative.
All task-bearing Action Center sections, including shift workload task lists,
show task numbers consistently. Exception counts remain overlapping subsets;
no readiness flag or work report is inferred or changed from note wording.

Action Center readiness navigation must use the annual state controls, not the
reusable Planning Info editor. Unstarted work uses Annual Readiness (state and
reason). Started work retains historical-note protection and may explicitly
confirm Mark ready through the existing readiness-state command. Rows expose
separate scheduling and exact dated Report Work actions; all duplicate/history
guards remain in effect. Planning Info is separately labeled as task guidance.

### Past-work reporting presentation

Past Perform Work days are reporting follow-up, not staffing forecasts. Suppress
planned crew/minimum/estimated labor, effort/short-crew badges, shift capacity
and staffing/overload warnings for past dates. Show actual reported totals only
in past day summaries. Retain captain, task identity/scope, date/period, report
status and exact report/no-work actions. Crew lane is unnecessary in past
follow-up labels. Today/future staffing presentation and stored history stay
unchanged. Actual crew/time entry remains available inside Report Work.

Report Work must be visible in every collapsed Perform Work assignment summary.
Completed assignments instead show Review Work History. Use the same existing
exact-assignment handler and avoid duplicate reporting buttons. Clicking this
action opens the report form without toggling the card closed. Other secondary
actions remain inside the expanded card.

### PR482 accepted release profile

Accepted application37a02e2d9460d115e1d7255833b264a6bb5d8d80/V0.3.111
is deployed by a profile of setup_maintenance_deploy.py using the existing #37
maintenance/snapshot/preservation/ONLINE sequence. Reuse CalendarRelease ONLINE,
whole-business-row fingerprint and isolated regression gates, and the existing
exact Git-blob transport/foreground Windows SCP+SSH wrapper. No new infrastructure.
Release tooling is merged separately from the pinned accepted application identity.
Current live source is captured in the journal, required clean and an ancestor
of the accepted source; the Setup database delta must be exactly migration080.
Any other baseline/delta stops before maintenance. Apply only080 after freeze and
snapshot validation; verify exact function body, owner, fixed search path, revoked
PUBLIC execution and enabled BEFORE INSERT row trigger. No Production test rows.
Preserve all business rows and the shared checkout. Failure retains journal and
snapshot; never automatically retry, invent inverse SQL or reopen writers.

### Perform Work theme contrast

Daily staffing summaries must pair the existing --card background with --text,
not an undefined --surface fallback and inherited text. Shift-status banners
must use paired --warning/--warning-soft or --success/--success-soft tokens.
The same rendered current-day summary and status cases must be checked under
explicit light/dark themes and OS-preferred dark mode before acceptance.
This is presentation only; calculations, reporting and scheduling do not change.

Theme follow-up release reuses the accepted305 source-only installer with a
pinned profile: fdf1549e accepted application,37a02e2 rollback, unchanged V111.
Existing forward ancestry, no-Database-delta, exact UI date, detached regression,
fingerprint, Setup-only promotion/restart/health, source rollback and cleanup
remain authoritative. Current shared source is captured for drift detection,
never promoted. Reuse committed-byte transport and foreground SCP+SSH wrapper.
No SQL, migration replay, Node, new infrastructure or database rollback archive.
Briefly pause Setup edits for the existing source-only preservation interval.


## November 11 — Post-PR483 final QC discovery first phase (#122/#205)

**Source baseline:** PR482 migration080 and its frozen business-history guard;
PR483 theme contrast fix `3ee52204e64e9d14bc7a9e2306a736645855f0ae`.
Do not replace or bypass these controls.

**Actual source of final QC:** The 2026 `ops.setup_session_task` annual
tasks matching *Plug in Network to controller and watch display against
2 minute Test show*. Production read-only evidence found 38 distinct annual
tasks with 27 never scheduled. Each may be Stage-, Scene-, or
incompletely-scoped; exact `setup_session_task_id` is identity.
Repeated titles under the same Stage must not be collapsed.

**First bounded implementation:** Add a `QC Check` selector to existing
Setup **Perform Work**. It draws from `setup_scheduling_board_repository.board`
authoritative annual tasks rather than `board.assignments`. Search matches
annual task ID, reusable task ID, Stage, Scene, title and status, even when
there is no scheduled work day or assigned crew. Render exact annual task,
current execution state, assignment-history count and unmet-prerequisite
indicator. Preserve existing Scheduled Work controls/reporting, PR482 no-work
guard and PR483 dark/light theme styles. This is READ ONLY and deliberately
does **not** indicate QC PASS from annual `COMPLETE`, nor create synthetic
work assignments. New JS/CSS asset pins separate the preview from stale
browser cache.

**Not an accepted QC system yet:** Saving authenticated auditor self-claims,
one/many detailed findings, repair self-claims, repair records, two-minute
retest and final QC signoff requires a governed PostgreSQL and protected
backend transaction. Preserve historical Intake observations with audited
many-to-many links rather than destructive migration or duplicate native
Work Orders. Never mistake Issue #419 Work Order promotion for pre-opening QC.
INTAKE-86 has already been separately promoted by operator; reconcile
84/85/87 against Racing Arches final annual QC #598 only by explicit Manager
confirmation, preserving original reporter and section-level evidence.

**Acceptance:** Source gates plus actual disposable current-Production
Manager/Crew browser review must show all 38 tasks including all 27
unscheduled, search by exact task and Scene, no scheduling mutation, and
controls with contrast/legibility in light and dark. No Production release
of a partial QC system without express operator acceptance.


## November 11 — QC persistent findings implementation candidate (081, #122/#205)

**Correction to previous first-phase boundary:** PR485 now also contains a
*NOT YET APPROVED / NOT DEPLOYED* governed clone-only QC persistence
candidate. It remains an explicit three-view workflow inside existing
**Perform Work**:
- **Scheduled Work** unchanged (PR482 reports/no-work and PR483 theme).
- **QC Check** searches all 38 annual two-minute test-show tasks independent
  of scheduled assignments. An authorized Crew member can report a problem
  on the exact annual QC task before final readiness, add corroborating
  observations to previous findings, or self-assign as QC auditor without
  creating a calendar, crew, Captain or work report.
- **Report Fixes** shows the same unresolved findings across Stage/Scene.
  A Crew member can claim a repair, record repair notes, and mark
  `AWAITING_RETEST`. An authorized Crew tester records a functional retest
  pass or fail. The finding is `VERIFIED` only on recorded retest pass.
  A failed retest reopens the same finding rather than creating another.

**Governed storage:** `ops.setup_qc_auditor`, `ops.setup_qc_finding`,
`ops.setup_qc_event`, `ops.setup_qc_intake_link` are supplemental
task-scoped evidence, NOT a duplicate annual-task master. Migration
`081_add_unscheduled_setup_qc_findings.sql` grants no direct application
QC/Intake table writes or reads. Only signed-in Manager/Production Crew
via `ref.setup_execution_actor` can mutate narrow
`ops.setup_qc_command`; independent SQL-owned authorized read
projections support client UI. All events preserve person/time; browser
displays timestamps in America/Chicago.

**Legacy Intake reconciliation:** A Manager-only original-Intake view shows
unpromoted 2026 Intake, Stage and raw original problem details.
The Manager creates exact distinct QC findings and deliberately links each
applicable original Intake ID to one or several existing QC findings after
confirming same physical failure. Many original reports can link to the same
finding. Original source rows are not deleted or updated by QC.
The GFCI Intake promoted separately by operator must remain Work Orders,
must never create another QC repair, and is rejected if already promoted.
Original Intake preservation and duplicate suppression require clone proof.

**Safety boundary:** Claiming an audit or marking repaired NEVER marks the
Setup annual task `COMPLETE` or records final two-minute QC PASS.
The final approval stage and prerequisite/report gate are NOT yet implemented
in this source and must not be represented as complete. Final QC approval
requires a separately reviewed guarded implementation using the existing
dependency graph and current report evidence. No 080 migration replay.
No Production deployment from draft PR485 without accepted disposable
081 migration, precise browser workflows in both themes, Crew/Manager
negative authorization, source preservation and explicit operator approval.

**Disposable test:** Existing Server Management browser preview on port 8898
pins candidate SHA and restores a fresh current-Production clone, applies
081 on that clone, runs
`Setup/Acceptance/setup_122_qc_disposable_acceptance.sql` within
a transaction rolled back, then permits protected browser review. No
Production writes. Test with #598 Racing Arches NOT_READY/unscheduled,
multiple findings and differing reporters; demonstrate the repair queue
shares identical finding IDs. Do not promote historical Intake for this test.


## November 11 — Final #122 QC interpretation and corrective engineering checkpoint (PR485)

**This section supersedes the incorrect "Intake FORM, not Intake workflow" interpretation previously appended to this contract.** The operator had already established the following design in #122 and #205; it must not be reconstructed from chat.

**The same annual QC task is accessible throughout Setup.** QC findings may be reported at initial power-up, during installation or final test, even if the existing annual task is unscheduled or NOT_READY. A report does not require an auditor claim. No new Work Day, assignment, Work Order, or Intake record is created by QC feedback.

**Setup → Perform Work has exactly three modes:** (1) Scheduled Work — preserve current normal installation and work-reporting behavior; (2) QC Check — select Stage/Scene and exact annual QC task, show existing distinct findings first, permit auditor self-assignment, add a new detailed failure or an observation to an existing finding, and later perform functional verification; (3) QC Repairs Needed (formerly Report Fixes) — all outstanding QC findings across the park, grouped by Stage/Scene and exact annual QC task; worker claims a finding, documents the actual repair, marks it repaired, and the same finding awaits retest. Claiming and repairing must not mark the QC task passed.

**Historical reconciliation is required before operational cutover, and separate from new QC reporting.** Preserve original Intake reporters, raw detail, notes, evidence, timestamps and communications. Authorized Manager must review and associate an existing Intake with one or more distinct QC findings through audited, many-to-many links; overlapping reports may link to the same finding. Racing Arches Stage 25 QC #598 includes separate Tom Shircel INTAKE-85 observations on arches 3, 4, 8, 9 and 11, with Paul Neils INTAKE-84 and Rich Neerhof INTAKE-87 corroborating only the actual overlaps after Manager confirmation. INTAKE-86 GFCI stays in its already-promoted independent Work Order, not the QC repair queue. Do not automatically convert Intake, create duplicates or infer a PASS.

**Normal QC is an optional two-person radio process:** command-center operator starts and calls out the actual two-minute LOR sequence, and one or more field auditors watch the indicated Displays/sections and record results. One person may perform both roles. Inspection sequence is controller/channel order and generally left to right where actual approved Wiring/sequence evidence establishes that physical order. Show the expected channel/Display mapping from authoritative Field Wiring, record explicit exceptions and exact sequence/version when known. Do not invent a mapping or assume channel number alone defines physical position. These details are distinct from and must not block early fault reporting.

**Two independent state machines:** a finding moves OPEN → CLAIMED → AWAITING_RETEST → VERIFIED or OPEN (failed retest); the annual test separately moves from ineligible to test-ready/in-progress/final PASS only after verified prerequisites, required actual test evidence and unresolved finding checks. Neither READY nor COMPLETE on the annual task means final QC PASS. Final approval control remains unfinished and must fail closed.

**Current PR485 engineering status:** restored Manager historical Intake review and link controls in QC Check while leaving new direct QC reports independent of any Intake read; preserved 081 governed task/finding/event/intake-link tables. Source must receive exact-SHA CI, current-Production disposable 081 acceptance and Crew/Manager browser PASS in light/dark before merge or Production approval. A read-only historical reconciliation inventory and operator-confirmed classification are mandatory before any data backfill. PR485 is DRAFT/HOLD; no Production mutation.


## November 11 — PR485 resumed engineering after d432cdd8

PR485 remains **DRAFT/HOLD**, not browser accepted or released. Current main
`c91a5b20385cd8ecec83ef14524378fd6b9153e8` adds only PR482/483 closeout
records relative to the candidate base; those records are reconciled without
changing the QC design. The last comment's `36071f09` is obsolete: later
commits added repair ownership, auditor retest gates, restored Manager
historical links and original evidence, and Stage identity checks.

Confirmed review gaps in d432cdd8: five stale asset-pin regression assertions;
QC data cached for the season (other workers' new findings were invisible on
view reentry); SQL required a note for merely claiming a repair while the
client invented one; unlinked Intake leaked through the Crew snapshot despite
the Manager-only review contract. The corrected candidate uses one-click
note-free claim commands with a database-owned claim audit event. Actual
repair/retest/observation notes remain mandatory. View entry refreshes shared
findings, and Manager source-link inventory is invalidated after linking.
Linked original evidence remains readable to repair Crew; unlinked inventory
and reconciliation stay Manager-only. New QC uses familiar findings and
optional suggested-correction/evidence fields on the same direct QC command.

The candidate identity is **V0.3.113-qc-review**, migration081 only. All changes
remain inside PR485. Final annual PASS is still unavailable. No automatic
historical conversion, Production migration, or release is authorized.

Validation additions reuse the existing Engineering Compliance workflow:
Python launches Chromium directly against the actual candidate HTML/scripts
with fixture API responses, exercising both roles, exact #483/#598 form
rendering, routing, same finding IDs, claim/repair/retest, fresh shared data,
and theme styles. This has no Node dependency and is a DOM regression only,
not PostgreSQL or operator acceptance. The existing Server Management reusable
8898 preview remains the sole operator-review mechanism. Its dedicated
launcher discovers worktrees and explicitly says **writable disposable
review**. The workstation needs PowerShell/Git/SSH; no Node installation.

The rollback SQL additionally checks real Crew/Manager boundaries, direct
reports before auditor claims, note-free claiming, ownership/evidence
rejections, linked original evidence, promoted Intake rejection, and complete
protected-row fingerprints for annual tasks, scheduling, ordinary work
reports, Intake and Work Orders. Fixture links are disposable tests only,
not Manager confirmation of actual historical defects. Live clone SQL and
protected browser checks remain required, including both themes and CLEAN
EXIT. Local sandbox Chromium cannot start (socket permission denied), so no
local browser PASS is claimed. Hosted DOM regression and current-Production
clone acceptance must be recorded separately before another review handoff.


## November 11 — Missing historical Stage and promoted-repair reconciliation

Operator read-only evidence after failed preview `20261112T010110` proves
QC598 is season2026, annual_stage_id55 (Stage key25 is not its database ID).
Intake84/85/86/87 all have NULL stage_id and target_year; their November10
local timestamps satisfy the current season predicate. Intake86 is promoted;
84/85/87 are unpromoted. The prior combined Stage/year error incorrectly
suggested a season mismatch. Null source Stage is missing classification,
not evidence of a contradictory Stage.

A Manager may deliberately link an unpromoted, same-season historical report
whose Stage is missing to the exact selected annual QC task, with the existing
required rationale. Show missing Stage explicitly and require that Manager
review; never fill in or rewrite the original Intake row. A populated source
Stage that differs from the task remains rejected. Promoted Intake remains
blocked from creating a second active QC repair. The source review must show
unassigned-Stage candidates so those links can actually be made.

The operator reports that other Setup problems have since been promoted into
Work Orders, leaving repair visibility split. The intended operational owner
remains Setup QC: report a problem in QC Check, see existing findings before
reporting again, and claim/repair those identical findings in Report Fixes.
Historical Intake is source evidence, not a second new-report workflow.
Before cutover, inventory original Intake plus resulting Work Orders/status
and work evidence; Manager confirms exact physical defects/overlaps and one
active repair owner. Do not automatically delete, close, undo promotion,
backfill duplicate findings, or discard existing repair evidence. The operator subsequently clarified the phase boundary below; the earlier
INTAKE86 independent-Work-Order exception is superseded for pre-show repairs. Multiple reports are not automatically four defects
or one defect; preserve section-specific observations and link real overlaps.

The failed candidate94f02567 passed1001/15-skipped application and232 additional
tests, then migration081; clone acceptance failed on the assumed positive
INTAKE85 link. Browser never started. Production fingerprint and live SHA
were unchanged, exit3. Report:
`/home/msbadmin/setup-acceptance-reports/Setup_Disposable_Browser_Preview_20261112T010110.txt`.
Retain the failed local review worktree. Corrected source needs new exact-SHA
checks and disposable review; DRAFT/HOLD remains, final annual PASS closed.


### Explicit operator phase boundary — supersedes earlier Work Order exception

The visible annual QC task list is the required entry point, not a replacement
list to build. Open the exact Stage/Scene annual QC task to report a problem
or add evidence to an existing finding. Display those findings under that
same task and in the shared Report Fixes queue. Production Crew claims and
records repairs against the same finding IDs.

**Before the show starts, Setup QC owns QC problems and repairs. Work Orders
do not become the repair workflow until the show starts.** This supersedes
prior wording retaining a promoted pre-show repair as an independent active
Work Order, including the earlier INTAKE86 exception. Promotion is historical
evidence, not authorization to split pre-show repair ownership. Preserve all
original Intake, reporter, timestamps, Work Order history and repair evidence.
Inventory and explicitly reconcile already-promoted pre-show reports into
the QC workflow with one active repair owner. No automatic deletion, reversal,
or duplicate live repair is authorized. The current duplicate-prevention
block on linking promoted Intake must remain closed until that controlled
reconciliation is implemented and accepted; it is an unfinished cutover gate,
not the final intended business rule. No date-based or automatic show-start
handoff has been designed or authorized here.
