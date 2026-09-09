# Setup Smart Scheduler Workflow — 2026-09-09

| Document Control | Value |
|---|---|
| Document Type | Engineering Planning-Workflow Contract |
| System | Production Database — Setup Session |
| Status | CURRENT DESIGN DIRECTION — operator-confirmed; not yet implemented |
| Owner | MSB Production Database engineering |
| Related Work | Issue #122; Issue #132; Setup Planning Candidate Work View; Setup Pick List Tablet Workflow |

## Purpose

Define the operator-facing **smart scheduling layer** between reusable Setup task knowledge and the short-range work-day schedule.

The reusable catalog may be organized and reordered within Stage/Sub-stage/Scene because that is how operators best understand the physical Setup process. The scheduler has a different responsibility: it should continuously determine **what work is actually eligible to be considered next**, then let the operator arrange that eligible work into the next few work days.

This is intentionally not a season-long Gantt scheduler.

## Core Rule — Do Not Show Work Before It Is Available

The scheduler should not present every incomplete task as if it were a current scheduling choice.

Tasks such as:

```text
Lay Cords
Make Network Connections
Plug In / Power
Testing / final connection work
```

should remain out of the primary candidate list until their hard predecessors and accepted readiness conditions are satisfied.

Examples:

- cord-laying remains hidden until its physical prerequisites are complete and grass cutting has stopped;
- network/power connection work remains hidden until the physical work and other accepted prerequisites required for that Stage/Scene are sufficiently complete;
- a task blocked by a hard predecessor is not a normal drag target yet;
- work may still be visible in a separate blocked/dependency inspection surface so the operator can understand the full process, but it should not clutter the active scheduling board.

The main scheduler therefore answers:

> What can we actually choose from now?

not:

> What tasks exist somewhere in the season?

## Reusable Order Versus Scheduled Order

These are separate orderings.

### Reusable Stage/Scene Order

The reusable catalog should support drag-and-drop ordering within a Stage/Sub-stage/Scene.

That order captures repeatable operational knowledge such as:

- which physical step normally comes first;
- which later step should generally follow;
- how operators best visualize the work in an area.

It is a preferred baseline, not a rigid season schedule.

### Scheduler Order

The scheduler should also support drag-and-drop ordering of **currently eligible work**.

The scheduler order means:

> Of the work we can reasonably do, this is the sequence we currently want to attack.

This ordering is annual/short-range planning state and must not silently rewrite the reusable Stage/Scene baseline.

Dragging work into or within a work day should be possible where browser/tablet behavior allows it. A simpler explicit move control may remain as fallback for accessibility/mobile acceptance, but drag/drop is the desired interaction.

## Candidate Eligibility

A task should enter the active scheduler candidate set only when its accepted hard blockers are cleared.

Conceptually:

```text
annual task is incomplete
AND reusable task is active/included
AND hard predecessor requirements are satisfied
AND hard readiness conditions are satisfied
AND task is not already fully scheduled/complete
    -> eligible scheduling candidate
```

Soft constraints do not necessarily hide the task. They should remain visible as warnings/context, for example:

- heavy physical effort;
- lift/equipment requirement;
- specialized capability requirement;
- weather preference;
- unusual crew size;
- material/logistics still needing preparation.

The scheduler should help the operator make a good choice without pretending to make the final human decision.

## In-Progress Work Remains Until Complete

A task that has started but is not complete remains part of active planning.

It must not disappear merely because one work report exists.

Conceptually:

```text
IN_PROGRESS
+ not COMPLETE
+ no scheduled continuation
    -> return to scheduler candidate list
```

This supports real MSB work where a crew deliberately pauses a physically demanding task and resumes it later.

### Example — Igloo bungees

Igloo bungees are physically demanding. MSB may:

- work on some bungees today;
- stop before the task is complete;
- schedule lighter work next;
- return to the bungees one or two days later.

The system should treat that as normal planning behavior, not as an exception requiring fake task splits.

The task remains one reusable task unless field practice proves distinct reusable phases are actually planned separately.

## Heavy / Light Work Balance

The scheduler should expose enough task characteristics that the operator can deliberately mix physically demanding and lighter work.

Do not build a complicated optimization engine before the operational need is proven.

For the initial smart scheduler, it is sufficient to support a simple reusable planning characteristic such as a reviewed effort/load hint, for example:

```text
LIGHT
MODERATE
HEAVY
```

or another accepted small vocabulary.

The scheduler can then display that characteristic while the operator drag/drops eligible work into the desired order.

The system should **not automatically decide** that a heavy task must be followed by a light task. The important first step is to remove the tribal knowledge by making physical effort visible during planning.

## Partial Progress

Progress reporting must support work that is not complete.

The field workflow should allow a Captain/Manager to record:

```text
Crew size
Hours
Minutes
What was completed / what remains
Percent complete or another simple progress measure when useful
Mark complete only when actually complete
```

A percentage such as `30% complete` is useful where an operator can reasonably estimate it, but the model should not require false precision for every task.

Existing quantity/unit completion evidence should remain useful for countable work. A progress note describing what was completed and what remains is also important because it gives the next crew meaningful continuation context.

A practical UI can therefore support one or more of:

- percent complete;
- completed quantity / units;
- short `what was done / what remains` note;
- explicit completion checkbox.

Exact schema/UI design requires current implementation review; do not invent a mandatory percentage column if existing quantity/unit/progress-note semantics can meet the need more safely.

## Work Duration Is Required

The current Setup progress form does not collect elapsed hours/minutes. This is a confirmed gap tracked by issue #132.

Each actual work period should record at least:

```text
crew_count
elapsed duration
progress evidence
complete/not complete
```

The field UI should make duration easy to enter, for example:

```text
Crew size: 4
Hours: 2
Minutes: 30
Progress: about 30%; south-side bungees complete, north side remains
[ ] Task complete
```

This matters for both historical reconstruction and future planning because repeated progress rows can safely establish:

- how many separate work periods a task needed;
- total elapsed work time;
- person-hours / crew-hours;
- how progress changed between work periods;
- better reviewed reusable crew/duration guidance for later years.

Do not collapse several work periods into one fabricated start/end interval.

## Scheduler Display Direction

A useful first scheduling board should be compact and decision-oriented.

For each eligible task, show only the information needed to choose next work, such as:

```text
Stage / Scene
Task
current progress
preferred-order context
crew guidance
expected duration
physical effort hint
required equipment/capability
notable logistics consequence
```

Blocked downstream tasks such as cords/network should not fill this main board before they become eligible.

The full task/dependency structure remains available in the reusable catalog or a dependency-inspection view.

## Example Operator Flow

```text
Open Setup -> Scheduler

AVAILABLE NOW
  Magic Igloo — Install Bungees
    IN PROGRESS — 30%
    HEAVY
    Crew 3–4
    Estimated remaining effort shown if reviewed evidence supports it

  Elf Choir — Setup Conductor & Notes
    LIGHT/MODERATE
    Crew 3–4

  Candyland — Tree Benches
    MODERATE
    Crew guidance ...

Lay Cords does not appear yet because mowing/readiness is not satisfied.
Network connection tasks do not appear yet because their hard predecessors are not satisfied.

Operator drag/drops:
  1. Magic Igloo bungees
  2. Elf Choir conductor/notes
  3. Candyland tree benches

Then assigns only the work that fits the next work day(s).
```

After field reporting:

```text
Magic Igloo bungees: 55% complete, still not complete
    -> remains/returns as eligible planning work when no continuation is scheduled

Elf Choir conductor/notes: COMPLETE
    -> leaves scheduler
    -> downstream tasks may become eligible
```

The candidate set should naturally change as completion/readiness changes.

## Relationship to Pick List

Only scheduled/selected near-term work should create actionable Pick List demand.

The scheduler may preview notable logistics consequences before selection, but scheduling the task is what should normally drive the executable Pick List.

This keeps planning simple:

```text
eligible work
    -> operator chooses/order work
    -> assign near-term day
    -> Pick List resolves required Containers/Displays
    -> field execution reports progress
    -> scheduler eligibility recalculates
```

## Initial Complexity Guardrail

Do not begin by implementing automatic optimization for:

- fatigue balancing;
- perfect crew assignment;
- weather forecasting;
- duration packing;
- critical-path analysis;
- automatic Stage sequencing.

The first useful smart behavior is simpler and more valuable:

1. hide work that is not actually eligible yet;
2. explain important soft constraints on eligible work;
3. preserve in-progress work until completion;
4. allow operator drag/drop ordering of eligible work;
5. allow near-term work-day assignment;
6. capture crew, elapsed time, and partial progress;
7. recalculate what becomes eligible next.

This matches actual MSB decision-making without turning Setup into conventional project-management software.

## Current Gap

As of this design record:

```text
reusable Stage/Scene drag/drop order        = existing/partially available; verify exact current behavior before changes
smart eligibility-filtered scheduler        = NOT IMPLEMENTED
scheduler drag/drop order                    = NOT IMPLEMENTED / requires browser acceptance
effort/load hint                             = NOT IMPLEMENTED / design review required
percent/partial progress UX                  = PARTIAL — quantity/units/note exist; exact percent behavior requires review
per-work-period hours/minutes                = NOT IMPLEMENTED — tracked by #132
continuation candidate behavior              = design requirement / not yet accepted in Production
```

Do not describe these as current Production capabilities until separately implemented, reviewed, and deployed.

## Acceptance Direction

A useful first smart-scheduler release should prove:

1. hard-blocked downstream work does not clutter the active scheduling board;
2. tasks appear automatically when hard predecessors/readiness become satisfied;
3. reusable Stage/Scene order and annual scheduler order remain separate;
4. eligible work can be manually reordered, preferably by drag/drop;
5. in-progress work remains available for later continuation until explicitly complete;
6. partial progress can be recorded without forcing completion;
7. field reports capture crew size and elapsed hours/minutes;
8. progress history makes `what was completed / what remains` clear;
9. the operator can deliberately mix heavy and light work without needing an automatic optimization engine;
10. completing work causes newly eligible downstream work to flow naturally into the scheduler; and
11. scheduling selected work feeds the Pick List without requiring duplicate staging logic.

## Related Durable Sources

- [Setup Planning Operating Model](Setup_Planning_Operating_Model_2026-09-08.md)
- [Setup Planning Candidate Work View](Setup_Planning_Candidate_Work_View_2026-09-09.md)
- [Setup Pick List Tablet Workflow](Setup_Pick_List_Tablet_Workflow_2026-09-09.md)
- GitHub issue #122 — Setup planning / Pick List / movement umbrella
- GitHub issue #132 — Captain work-report duration and multi-day effort capture
