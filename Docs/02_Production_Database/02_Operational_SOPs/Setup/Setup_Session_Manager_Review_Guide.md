# Setup Session Manager Review Guide

## Purpose

Use this guide while reviewing the Setup Session browser candidate and the reconstructed 2025 Setup work plan.

The current candidate is primarily for:

- reviewing and correcting reusable Setup tasks;
- verifying reconstructed 2025 annual information;
- reviewing Stage sequence, crew/time expectations, equipment/resources, prerequisites, and Setup Procedures;
- identifying missing tasks or relationships before Production rollout.

Scheduling, Pick Lists, and field movement/scanning are not yet active in this browser candidate. Do not infer those workflows from the current placeholder screens.

## Reusable task versus annual task

A **Reusable Task** describes practical work that normally exists every Setup season. Examples include erecting a structure, positioning a trailer, unloading a shared trailer, hanging lights, or completing electrical/network connections.

Reusable information includes normal crew size, expected duration, equipment/resources, completion point, readiness/weather notes, Stage, and normal within-Stage sequence.

The **2025 Annual Historical Actual** is the 2025 occurrence of that reusable work. Annual notes, actual crew, actual duration, and verification state belong to the annual record and do not redefine the reusable task.

## Verify a 2025 task

Open a task from the **2025 Verification** queue and review both sides of the task detail.

Use the verification states as follows:

- **UNVERIFIED** — nobody has accepted the reconstruction yet.
- **VERIFIED** — the reusable definition and 2025 information are a reasonable representation of the work.
- **NEEDS CORRECTION** — something must be corrected before the task is accepted.

Correct the reusable task definition when the normal recurring work is wrong. Correct the annual review when only the 2025 facts are wrong.

## Stage sequence

The reusable task sequence numbers such as `10`, `20`, `30`, and `40` describe the normal precedence **within one Stage**.

Example:

```text
Magic Igloo
10  Erect frame
20  Install skins
30  Finish lighting / cameras / signs
```

These numbers are useful planning precedence. They do **not** mean the entire Setup day is one serial task list.

Managers may reorder reusable tasks within a Stage by dragging them in the Reusable Task Catalog or by using the up/down controls. The application renumbers the Stage sequence in increments of 10.

## Parallel work and future daily scheduling

Setup routinely uses parallel crews. A work day may have one crew on Stow Storm while another works on Elf Choir and another handles support/logistics.

The planned scheduling model is:

- work date;
- shift: **Morning**, **Afternoon**, or **All Day**;
- multiple parallel tasks/crews within a shift;
- a task may appear on more than one date/shift when the practical job spans multiple days.

A reusable task's Stage sequence remains useful as normal precedence even when the actual schedule differs.

## Multi-day tasks and readiness

Do not split a practical task merely because it spans more than one work day.

Example: Festive Trees can remain one reusable task even though canopy wrapping may continue across multiple shifts/days. The annual task remains **IN_PROGRESS** until the practical task is actually complete.

Readiness is separate from precedence. Festive Trees should remain **NOT_READY** until the leaves have fallen from the trees. Once that external condition is satisfied, a Manager can make it **READY** for scheduling when the scheduling workflow is implemented.

## Prerequisites

A prerequisite means work cannot practically proceed until another reusable task is complete. Prerequisites may cross Stage boundaries.

Example: the Arch Trailer unload circuit is a serial logistics chain feeding parallel installation work:

```text
Unload Racing Arches
  -> Unload Polar Bear Arch
  -> Unload Candyland Arch
  -> Unload Icicle Tunnel arches
  -> Unload 24 Stars
  -> Unload Food Collection arches
  -> Arch Trailer available for Who House support
```

Installation crews can begin work after their material is unloaded while the trailer continues to the next destination.

The full Arch Trailer drop-off circuit normally takes about **90 minutes total with 2 people**. Do not treat each unload stop as a separate one-hour labor estimate.

Dependency editing is not exposed in the current browser candidate. During review, flag missing or incorrect prerequisites for correction before field scheduling is accepted.

## Copy a reusable task

Use **Copy** when a new task is substantially similar to an existing reusable task.

The review candidate copies:

- reusable task definition fields;
- normal crew/time expectations;
- readiness/weather/reusable notes;
- structured equipment/resource assignments.

It intentionally does **not** copy:

- prerequisites/dependencies;
- annual history or verification state.

Review the new task before using it. A copied task receives a new reusable task identity.

## Equipment and resources

Use **Equipment / Resources Needed** for structured recurring requirements such as lifts, vehicles, trailers, and tools. Quantity and Required/Preferred status belong here rather than being buried only in notes.

Equipment requirements are part of the reusable task definition because they are needed for future planning and schedule conflict checks.

## Setup Procedures

The task detail shows the current published Setup PDF when one is available.

Managers may also see the editable Google Docs source. `SourceDocs` is preferred; `Archive` is the accepted compatibility fallback for existing 2025 source material.

The field PDF and editable source serve different purposes:

- published PDF = current field instruction;
- editable Google Doc = Manager-maintained source used to revise the published procedure.

## Pick Lists — planned workflow

The future Pick List is generated from the tasks selected for a work day/shift:

```text
scheduled Setup tasks
  -> required Displays/assets
  -> current Display-to-Container assignments
  + supplemental required/support KIT Containers
  -> deduplicate shared Containers/trailers
  -> show why each physical item is needed
```

A Pick List replaces manual material bookkeeping. It does **not** automatically replace a real Prepare/Load task if people genuinely spend meaningful labor preparing, organizing, or loading material.

Shared Containers such as Container 34 / Arch Trailer must appear once on a Pick List with all relevant reasons rather than as duplicate Container rows.

## Completion view — planned workflow

The future field-execution view should default to incomplete work so completed tasks stop cluttering the active list. Operators/Managers should be able to switch among:

- Incomplete;
- Completed;
- All.

Completing one day's work on a multi-day task must not complete the entire annual task unless the practical task is actually finished.

## Movement and scanning — planned workflow

Scanning identifies the physical object. Setup Session owns the business meaning of the action.

Examples of permanent identifiers include:

```text
DISP:<display_id>
CONT:<container_id>
LOC:<location_code>
```

A scan alone must not create a destructive movement event merely because two identifiers were scanned in sequence. Setup must present the intended action and ask for the appropriate confirmation.

The current browser candidate does not yet expose the audited movement command layer.

## Browser-review safety

When using the disposable browser-review harness at `127.0.0.1:8794`, changes are written only to the disposable PostgreSQL clone and are removed during cleanup. They are not Production edits.

Use the browser review to learn the workflow, test Manager actions, and identify corrections. Production installation remains a separate acceptance gate.
