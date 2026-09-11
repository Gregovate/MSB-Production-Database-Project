# Setup Planning Operating Model — 2026-09-08

| Document Control | Value |
|---|---|
| Document Type | Engineering Operating-Model Contract |
| System | Production Database — Setup Session |
| Status | CURRENT — operator-confirmed planning model |
| Owner | MSB Production Database engineering |
| Last Reviewed | 2026-09-09 |
| Related Work | Issue #122; PR #125; 2025 Historical Review / Training |

## Purpose

Preserve the actual MSB Setup planning model so future engineering work does not incorrectly turn Setup into a rigid calendar scheduler or require the operator to restate field practice from memory.

This document records current operator-confirmed rules that must shape 2026 planning, 2025 reconstruction, crew/time interpretation, task decomposition, Pick List behavior, and future scheduling behavior.

## Core Planning Model

MSB does **not** normally build a fixed long-range day-by-day Setup schedule.

The practical model is:

```text
reusable task order / prerequisites
    + work that is ready
    + volunteers actually available
    + equipment actually available
    + weather / site conditions
    + work completed or delayed on prior days
    -> identify the outstanding work that needs scheduling
    -> plan only the next few work days
    -> derive near-term material/container needs through the Pick List
    -> revise as field conditions change
```

Planning is primarily **order-driven and crew/equipment-availability-driven**, not calendar-driven.

A useful application should therefore help answer:

- What work is next in the preferred Setup order?
- What work still needs to be scheduled?
- What work is actually ready now?
- What work is blocked and why?
- How many volunteers are available today / next work day?
- Which tasks fit the available crew mix and equipment?
- Which tasks are blocked by weather, site conditions, mowing, prerequisites, missing material, or unfinished prior work?
- Which partially completed tasks need another work day?
- What Displays, Containers, trailers, and support material must be made ready for the work selected next?

Do not force every reusable task into one fixed date simply because a date field exists.

## Planning Horizon

Normal planning horizon is only a **few days at a time**.

Reasons include:

- volunteer turnout varies;
- task completion can be faster or slower than expected;
- some jobs consume more people than expected;
- equipment availability changes which work is practical;
- weather changes what can safely be done;
- material/equipment issues can move work forward or backward;
- some tasks span multiple work days;
- one day may include several small tasks or only part of one large task.

The system should preserve planned-versus-actual history, but it should not encourage false precision by filling the entire Setup season with fixed dates far in advance.

## Sunday Rule

MSB avoids scheduling Setup work on **Sundays whenever reasonably possible**.

This is an operating preference, not an absolute historical claim that no Sunday work ever occurs.

Application behavior should therefore treat Sunday as a **strong default planning avoidance / warning**, not as an irreversible database prohibition unless a later explicit rule changes this policy.

## Weather Rule

Weather is a real planning constraint.

MSB normally avoids outdoor Setup work in:

- rain; and
- high winds.

Weather should influence readiness and short-range planning. It should not be reduced to a generic free-text afterthought if the future planner can make this constraint visible to operators.

The system must still permit deliberate operator override when unusual circumstances require it; the database should not invent a hard meteorological threshold without an accepted operational rule.

## Grass-Cutting / Cord-Laying Dependency

Cord-laying has a real seasonal/site prerequisite:

> Cords should not be laid until grass cutting has stopped.

This is stronger than a generic weather note. It is a practical readiness/dependency rule for tasks such as:

```text
Lay Cords
Plug In / Power
Network Connection
```

where downstream work may depend on cord placement.

The planner should be able to represent that a task is not yet ready because mowing/grass cutting is still active, rather than scheduling the work and relying on memory to postpone it.

Do not convert this into a guessed annual calendar date. The controlling fact is **grass cutting has stopped**, not a fixed day of the year.

## Task Duration and Multi-Day Work

A reusable Setup task does **not** imply one task equals one work day.

Some tasks can take several days to complete.

Required model behavior:

- one reusable task may be worked on across multiple Setup work days;
- partial progress must remain valid without marking the task complete;
- work-day planning should be able to assign/continue a task on a later day;
- historical reconstruction should not collapse several days of work into one fake completion date merely because the task has one reusable identity;
- expected duration is a planning aid, not a one-day scheduling restriction.

Where a large job naturally contains independently plannable phases, reconstruction may expose missing reusable tasks/subtasks. Do not automatically split every multi-day task; split only where field practice shows the steps are meaningfully planned, staffed, or completed separately.

## Crew Size Interpretation

Rick Hoffmann's 2025 records and other historical notes can help improve reusable planning estimates such as:

```text
normal_crew_min
normal_crew_max
expected_duration_minutes
```

but historical evidence must be interpreted carefully.

Rules:

1. A named list of people working the same task is evidence for historical crew size **only when the note reasonably ties those people to that task**.
2. A daily volunteer roster is not automatically the crew count for every task performed that day.
3. People who move between tasks during a day must not be counted as if they spent the whole day on each task.
4. Crew-size history should be used to improve a **normal/candidate range**, not to manufacture precision the notes do not support.
5. Capability/qualification information may later help explain why two crews of the same numeric size are not operationally equivalent.

## Hours / Duration Interpretation

Rick's recorded hours are useful evidence, but a person's total hours for a day are **not automatically the duration of a Setup task**.

Safe duration evidence includes:

- explicit task start/end times;
- a note that clearly says the crew spent a stated period on one task;
- a day where the source clearly establishes that essentially the entire work period was one task; or
- repeated multi-year evidence strong enough to justify a reusable estimate after review.

Unsafe inference includes:

```text
Rick worked 6 hours that day
therefore every task Rick mentioned took 6 hours
```

When several tasks occurred in one day and no allocation is given, preserve the date/participation evidence but leave exact task duration unknown.

## Reusable Task Order

Preferred Setup order is durable operational knowledge and is often more valuable than far-future calendar dates.

The planner should preserve:

- reusable task display/order;
- prerequisites/dependencies;
- readiness constraints;
- crew-size guidance;
- expected effort;
- required equipment/material; and
- partially completed work.

Then short-range work-day planning can choose from that ordered/ready set using the volunteers, equipment, and conditions actually available.

The operator must be able to depart from preferred order when real conditions justify it without destroying the reusable baseline.

## Dates Versus Order

Historical dates from the 2022 Project schedule and 2025 reconstruction are **firm evidence markers for when work happened or was planned**, but they must not be copied into future seasons as a rigid calendar.

For future planning:

- preferred order and prerequisite/readiness logic are the primary long-range planning signals;
- date-specific work is assigned only when the short planning horizon is being built;
- true external/fixed markers may still be shown as constraints or milestones when appropriate;
- the planner should not invent a date merely to make every outstanding task appear scheduled.

The historical date columns remain valuable because they help establish relative timing, sequence, and the point in the season where work commonly occurred.

## Needs Scheduling Queue

The application needs an explicit operator view of **work that still needs to be scheduled**.

This should be a **derived queue**, not another independent task list and not necessarily a new stored boolean.

Conceptually:

```text
annual task is included
AND reusable task is active
AND task is not COMPLETE / intentionally DEFERRED
AND task has no active future work-day assignment
    -> task needs scheduling
```

The queue should preserve separate operational states:

```text
NOT_READY + no future assignment
    -> Outstanding / Blocked

READY + no future assignment
    -> Ready to Schedule

IN_PROGRESS + no future assignment
    -> Needs Scheduling Again

READY / PLANNED / IN_PROGRESS + future assignment
    -> Scheduled

COMPLETE
    -> do not show in Needs Scheduling
```

This is important for multi-day work. A task that received one partial work period and remains `IN_PROGRESS` must return to **Needs Scheduling Again** when no continuation is assigned.

The queue should sort primarily by reusable/annual preferred order, while visibly surfacing readiness blockers, crew guidance, equipment needs, and other reasons an operator may intentionally choose a different next task.

## Pick List / Staging Boundary

**`Staging to Park` is not a reusable Setup task.**

Historical staging existed because MSB did not have a reliable way to know which Containers/Displays/material had to leave the workshop, in what sequence, or by when.

The current architecture can derive that need from the actual Setup work:

```text
preferred task order / near-term scheduled tasks
    -> required Displays / support Containers / equipment
    -> current Container relationships and locations
    -> Pick List / logistics priority
    -> items moved/prepared for the park
```

Therefore:

- do not create or retain a generic `Staging to Park` reusable task merely to represent material preparation;
- Pick List/logistics should own determining which Containers/items must be made ready and moved;
- the strongest `needed by` signal is a real near-term scheduled work date;
- when an item has not yet been given a date, preferred task order/readiness can still establish Pick List priority without fabricating one;
- old 2022 staging/load/unload rows remain useful reconstruction evidence but must be reviewed for Pick List/logistics ownership rather than automatically becoming reusable Setup tasks.

Specific physical operations that are genuinely separate field work may still be real tasks. The rule removes the **generic staging abstraction**, not every legitimate unload/delivery/setup operation.

## Mixed-Stage Container Mobilization

A Container or trailer that carries material for **more than one Setup Stage/scope** must be treated differently from a normal single-scope Container.

The planner/Pick List should be smart enough to detect this from authoritative current Container contents and task/material relationships whenever that data is represented. A special manual `mixed-stage` flag should not be required merely to restate relationships the database can already derive.

Conceptually:

```text
near-term task requires Display/material X
    -> X is in Container C
    -> Container C also carries material for other Setup Stages/scopes
    -> C has not yet been mobilized for this Setup Session
    -> surface the Container-level mobilization/logistics action
    -> move the whole Container/trailer when the first carried item is needed
```

This rule applies generally to mixed-stage Containers/trailers, not only to one named trailer.

Important distinction:

- **mobilize the whole mixed-stage Container/trailer at first demand** is the common rule;
- **what happens after arrival** may differ by Container and must come from real field practice.

Examples of different post-arrival behavior can include:

```text
FULL UNLOAD
    all carried material is unloaded and becomes park-available

MOBILE / PARK STORAGE
    Container/trailer is moved to the park and continues to hold some or all material

SPECIAL TRANSFORMATION
    Container/trailer is unloaded because the trailer/container itself becomes part of a later Setup task
```

Do not infer the post-arrival handling mode merely because a Container is mixed-stage. That behavior needs authoritative Container/logistics knowledge. The Arch Trailer is an established example where the trailer itself has a later Setup role after its cargo is unloaded; that is separate from the general mixed-stage detection rule.

The Pick List / planner must therefore distinguish:

```text
normal single-scope material pick
mixed-stage Container mobilization
Container-specific unload / park-storage / transformation behavior
```

Once a mixed-stage Container has been mobilized for the annual Setup Session, later tasks that use other contents on the same Container should not trigger duplicate workshop staging/mobilization. Their material should be treated according to the Container's current annual position/unload state.

If some important Container contents are not represented as `ref.display` or another authoritative structured relationship, that is a data gap to capture; the planner must not pretend it can derive mixed-stage behavior from data that does not exist.

## Missing Tasks / Missing Steps in Production

The 2025 reconstruction is expected to expose many missing Setup steps.

A historical note may reveal that the current Production reusable task is:

- missing an entire plannable task;
- missing a prerequisite;
- too broad and hiding separately staffed phases;
- too narrow and duplicating one practical task;
- missing a readiness rule;
- missing material/container context;
- missing electrical/network/cord/test follow-up work; or
- missing completion criteria.

Do not force newly discovered real work into `annual_notes` merely to avoid changing the reusable catalog.

Use the reconstruction process to improve the reusable task model where the evidence is clear. Unknown shorthand remains a question rather than being converted into a new task by guesswork.

## Recurring Setup Work Families

The 2025 review has already identified recurring practical work families such as:

```text
Locates
physical build / placement / assembly
Lay Cords
Plug In / Power
Network Connection
Testing
```

These families are useful for recognizing missing steps and dependencies, but they are **not mandatory templates** that must be generated for every Stage.

A Stage may combine or omit a family where the physical process truly differs.

## 2025 Rick Spreadsheet Review Window

For the current reconstruction pass, use Rick's two 2025 spreadsheets primarily for the period:

```text
2025-09-30 through Thanksgiving 2025
```

Entries outside that Setup-season window may be ignored unless a specific later question deliberately reopens them.

The spreadsheets are evidence sources, not authoritative normalized task definitions. Their shorthand must be interpreted against current Production tasks, Procedures, Stage/Scene context, and operator knowledge.

## Reconstruction Buckets

For each spreadsheet finding, classify evidence before entering it:

### 1. 2025 annual historical fact

Examples:

- date work occurred;
- actual crew tied to that work;
- explicit duration/time range;
- actual completion/partial-completion note.

### 2. Reusable Setup knowledge

Examples:

- normal crew range;
- expected duration;
- preferred task order;
- readiness/weather rule;
- prerequisite;
- material/container requirement;
- repeatable task step or missing reusable task.

### 3. Ambiguous / question

Examples:

- shorthand that could refer to several Displays/tasks;
- `???`, `maybe`, `I think`, `no idea`;
- names not clearly tied to a specific task;
- daily hours without task allocation;
- unclear completion state.

Do not promote bucket 3 into Production fact without review.

## Relationship to People / Capabilities

Crew planning today is largely based on who is actually available, but crew composition matters in addition to headcount.

The separately documented global People / Capability / Qualification work (issue #130) is intended to preserve knowledge such as electrical, welding, networking, panel-building, equipment qualifications, and task-specific experience.

Future Setup planning may consume that global capability data to help answer whether the available volunteers are suitable for the next task. Setup must not create a competing person/skill catalog.

## Engineering Consequences

Future Setup engineering must preserve these rules:

1. do not build a rigid season-long scheduler;
2. plan a few days ahead and support frequent replanning;
3. make preferred order and prerequisites first-class;
4. provide a derived **Needs Scheduling** queue for outstanding unscheduled work;
5. return incomplete multi-day work to **Needs Scheduling Again** when no continuation is assigned;
6. treat historical dates as strong evidence markers without making them the primary future planning structure;
7. move generic `Staging to Park` responsibility to Pick List/logistics derived from scheduled/ordered task needs;
8. derive mixed-stage Container/trailer mobilization from authoritative contents/task relationships where possible;
9. mobilize a mixed-stage Container/trailer when the first carried item is needed, without duplicating later staging for other contents already at the park;
10. keep Container-specific full-unload/mobile-storage/transformation behavior distinct from the general mixed-stage detection rule;
11. treat Sunday as a strong avoidance preference, not an absolute ban;
12. expose weather and site-readiness constraints;
13. represent grass-cutting completion as a cord-laying readiness dependency rather than a guessed date;
14. support tasks spanning multiple work days and partial progress;
15. treat historical crew/hours as evidence, not automatic exact values;
16. use 2022/2025 evidence to identify missing reusable tasks/steps when evidence supports them; and
17. keep annual historical facts separate from reusable planning knowledge.

## Related Durable Sources

- [Setup engineering portal](README.md)
- [2025 Live Review Work Ledger](Setup_2025_Live_Review_Work_Ledger_2026-09-08.md)
- [Setup Session Production Engineering Handoff](Setup_Session_Production_Engineering_Handoff_2026-09-07.md)
- GitHub issue #122
- GitHub PR #125
- Global People / Capability / Qualification work: issue #130
