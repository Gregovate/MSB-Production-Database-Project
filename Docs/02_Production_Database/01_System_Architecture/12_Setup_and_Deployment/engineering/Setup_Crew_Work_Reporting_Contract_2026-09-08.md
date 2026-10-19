# Setup Crew Work Reporting Contract — 2026-09-08

| Document Control | Value |
|---|---|
| Document Type | Engineering Workflow Contract |
| System | Production Database — Setup Session |
| Status | CURRENT — operator-confirmed execution/reporting requirement |
| Owner | MSB Production Database engineering |
| Last Reviewed | 2026-09-08 |
| Related Work | Issue #122; Issue #132; PR #125 |

## Purpose

Define how actual Setup work should be reported in the field so the planner preserves useful historical effort without becoming a rigid project-management or timesheet system.

This contract is based on operator-confirmed field practice and the current Setup execution implementation.

## October 19, 2026 — Display installation is part of Setup task completion, NOT Container unloading

**Operator-approved requirement and season boundary — #122, #132 Report Work, #175 Perform Work, and #88 movement evidence.** This corrects an important previous design interpretation: **Pick / Container movement / park drop / physical Stage-group unloading are logistics that bring Displays TO the park FOR Setup. They do not complete the task that installs those Displays, do not prove show-position placement, and must not be treated as a completion note or as automatic credit for the installation task.**

The actual field sequence is `Pick → park transport/drop → physical unload → perform applicable Setup task → scan each installed Display at its final show position → report/verify that installation task's completion`. Ordinary emptied shipping Containers return to Workshop/Home; protected Standalone/singular Display-Pallet Containers physically remain for show-placement or move to their own intended show position. Movement and task-progress evidence remain different data facts, even when the same operator performs them.

### 2026 launch — intentional learning exception, not a retrospective defect in completed work reports

In 2026 Greg intentionally **did not require a Display scan before an installation task could be reported complete**, to let volunteers learn the new Setup system. This was an explicit rollout compromise, **not** proof that the resulting Display GPS/status is trustworthy. Preserve the accepted 2026 Report Work/progress/completion history and do not retroactively reject, reopen or rewrite completed tasks for absence of a new scan criterion. Continue accepting work reports under installed 2026 rules.

**Urgent 2026 visibility/recovery:** Build a read-only discrepancy view from current annual installation work scope, current `#88` Display event/association state, and source/user-reported work history. Distinguish (a) **independently scanned/verified at show position**, (b) **work reported complete but installation location unverified**, (c) **erroneous group detach at Container drop**, (d) **still with Container / not unloaded**, (e) **location known only by named Stage or approximate GPS**, and (f) **explicit exception/field check needed**. The absence of a scan must mean `Not verified by scan`, **not** `Not installed`; the task's 100% report remains work evidence, not spatial verification. Provide a prioritized field-check list with actual Display Names, related task/Stage and best current observation, preserving later valid individual scans. The field crew may voluntarily scan already-installed Displays at their real locations now; the resulting valid Display observation supersedes an older wrong location, while the older event and its context remain in history. Manager corrections for erroneously attached/detached objects remain guarded under existing #88/#418; no bulk assignment of one Container drop point or Stage-centroid GPS to all Displays.

### 2026 recovery-scan reasonableness / one physical unit despite two IDs

Current 2026 field location cleanup is **voluntary** and must not retroactively invalidate Report Work. A later properly attributed and verified `DISP:` field observation may supersede older Container-drop/inferred location evidence without erasing its history. Check current Display identity, actual Setup Stage, old source/age/accuracy, active attachment state, any queued older scans and existing later installation evidence. Large displacement may be a legitimate correction of a known bad Container unload; distance is a **review warning**, not proof that the new scan is wrong. Same item observed repeatedly does not create additional task-installed Display counts; distinct valid observations may remain in audit history.

For a synthetic Standalone or singular integral Display-Pallet, a `CONT:` and `DISP:` label may identify **one physical show object**. Both identities, if present, must resolve to the same canonical Display/Container relationship and only **one** installation confirmation, not a second required physical scan. Some field objects have just one usable tag; the workflow must support that exact existing identity. A multi-Display pallet with a show-base remaining on site is different: each removable Display is verified individually, while the base/container retains its own show-position observation. See the [owning #88 reasonableness and Container role contract](Setup_88_Pick_Mode_Movement_Design_2026-09-29.md#october-19-follow-up--verified-2026-recovery-scans-and-physical-container-role-boundaries). 2027 install-scanning acceptance must check both label variants, missing label fallback, physical uniqueness and independent cargo-vs-show-base records.

### October 19 — task-scoped no-label exception and simple installation confirmation

The operator has confirmed that **Church Bells include physically unlabelable Displays** for which QR adhesion/geometry is impossible; manually searching a phone for each Display is not a viable Setup completion mechanism. The future 2027 task verification must therefore support **two distinct evidence channels** while preserving one installed/verified physical-Display identity:

- **Scannable Display:** after scanning the permanent `DISP:` label, ask a clear **"Is [Display Name] in its final show position?" Yes / No** question (or equally explicit one-tap verified-installation action in task-linked fast mode). Successful Yes is per-Display evidence with actual Stage/position, original actor/time and scan provenance. Already-`DETACHED` is NOT exempt from the question. No does not count installed.
- **Physically unlabelable Display:** choose the actual Setup **task/Scene**, display its authoritative human Display Names and required scope, and permit accountable rapid **group/individual visual confirmation** with selective exceptions for missing/not installed. Record `VISUALLY_VERIFIED — NO PHYSICAL QR` against the actual Display IDs and responsible authorized operator/time; do not fabricate HID scans or invent individual exact GPS. No generic `Mark all` across unrelated Scenes/Stages. The physical reason for missing label and the group's membership must be reviewable in the existing task context.
- **Synthetic Standalone or integral pallet:** if one physical Display has both Container and Display IDs, one authorized scan of either supported physical label must resolve the single object and count once; type/pairing ambiguity fails safely instead of marking two installed objects.

**2026 is nonblocking.** Greg confirms every GG Display is physically installed in its final position and Rich recorded GG scans on Oct19. A Manager-reviewed **scoped attestation of those existing per-Display scan events** can satisfy a new optional 2026 verification record without reissuing or inventing individual scans; later valid source events and missing identities must be respected. This is user-reported field reality awaiting read-only current Production event reconciliation, not automatic batch GPS promotion.

The governing #88 [field Yes/No and C009 evidence](Setup_88_Pick_Mode_Movement_Design_2026-09-29.md#october-19-operator-simplification--final-position-yesno-gg-existing-scans-c009-identity-and-unlabelable-displays) owns event/location semantics. The **Report Work installation task** owns the verification requirement and its coverage accounting. Do not alter 2026 completed task reports or impose a future scan gate retroactively.

### 2027 Setup — required per-Display confirmation tied to the *installation task*

For tasks whose accepted **reusable task completion point is actual installation of identified Displays**, completion verification must be integrated into **Perform Work / Report Work** (not left as an unrelated optional Record Location action). Before marking that installation task **verified complete**, the system requires **one accepted installation-position scan for every Display actually required by that task's reviewed annual scope**, or a separately documented, authorized per-Display damaged-label/accessibility exception. Installation-task identity, not entire Stage membership or Container manifest alone, determines the required coverage. Do not impose this gate on unrelated Logistics / Unload Container / Support / Prep tasks with no Display-installation completion point.

- The crew can scan each Display **as it is installed**, directly from the ongoing task/crew context or a fast continuous scanning screen bound to that task; avoid an extra after-the-fact inventory and avoid a repeated form/confirmation on each ordinary good scan.
- Recognize canonical `DISP:` and protected Standalone/singular Display-Pallet `CONT:` identities through existing QR/Scan/#88 capture and associated Display identity, without ever falsely detaching the protected unit. Scanned actual Display Names must be shown; unknown/wrong-task/duplicate identity must be detected without counting twice.
- Record a **task-associated installed-at-show-position attestation** separate from generic `DISPLAY_MOVE`, `DETACHED` or inferred Container GPS. Preserve actual task, annual Session, named Stage/show-position context, capture actor, original time, device, GPS and accuracy when available, previous/superseded location provenance and idempotency. **Do not automatically infer installation** from unloading, a Stage assignment, generic scan, task 100% or nearest GPS reference. Confirmation of actual position must be clear and fast.
- If live GPS is unavailable/poor, accept a reviewed appropriate named Stage/site-location observation with explicit unknown/approximate coordinate status rather than manufacturing a GPS location. A verified installation count is a physical-scan/exception count, not a count of precise survey points.
- **Progress and physical verification remain distinct:** crews must still be able to report actual time, quantity and partially completed work. A physically finished task lacking required scans is **Work reported complete — installation verification pending**, not automatically **verified complete** and not an assertion that unscanned Displays are absent. Final verification requires all expected Display scan records or individually reviewed exceptions; retain both report time and later verification time/actor.
- Offline field scanning and interrupted/back-to-back events must retain the selected Setup task/Container context, unique client event IDs and capture chronology; pending scans display as **queued/unverified until accepted sync**, never silently counted as server-verified. A later valid direct Display scan takes precedence for its current position over older unload/inferred Container evidence, but must never overwrite original observations/history.
- Provide the Captain a compact task-linked **Installed / Pending / Exception** list of readable Display Names and counts; show exactly which scans block verified completion, with direct field-recovery action rather than a database administrative procedure. Correct damaged/unreadable QR paths must be explicitly audited, not a blanket “Mark all installed” shortcut.

**Engineering ownership:** #122 defines the end-to-end setup completion gate; #132 Report Work owns progress/completion reporting integration; #175 Perform Work owns the field execution/scan handoff; #88 owns observed movement and installed-position event authority; #113 reuses scanner/tablet HID and offline mechanisms; #171 consumes Display current positions for map display only; #230 maintains canonical Container/Display reference identities. Reuse existing application, task/material resolver, seasonal event model and role-scoped audit; no competing task-completion, map or scanning ledger. Determine the smallest safe existing-schema support and role policy through reconnaissance **before** prescribing a new SQL table or status.

**Acceptance / release gate:** Regress 2026 as nonblocking. For 2027, demonstrate one real-scanned Display/task, 16/32-Display group (all/partial), multi-day partial task, missing/wrong/duplicate QR, protected Standalone Container placement, intentional 2026 old wrong unload vs later valid position, GPS unavailable, offline replay and idempotent sync, actual task-specific required Display membership, verification only after complete evidence and authorized exception handling. Run full Setup/Field Wiring and the existing Server Management disposable/browser/real rugged-tablet/Zebra acceptance; no Production deployment or new mandatory 2026 rule without separate authorization.

## Non-Linear Stage Planning

A Stage is organization and context. It is **not** a completion gate.

MSB does not normally finish every task for one Stage and then move sequentially to the next Stage.

The practical field model is:

```text
preferred task order / prerequisites
    + people available now
    + relevant skills / experience available
    + equipment / trailers / lifts available
    + weather / site readiness
    + work already partially completed
    -> choose the best useful work that can be performed now
```

Consequences:

- crews may work on several different Stages during the same day;
- a Stage may remain partially complete while work begins elsewhere;
- a multi-day task may be paused and resumed later;
- equipment availability may cause a later-ranked task to be worked before an earlier task;
- volunteer availability may cause smaller or differently-skilled jobs to be selected;
- the planner must preserve preferred order without treating it as a mandatory sequential waterfall.

This is a major reason Setup is not equivalent to a conventional project-management system.

## Work Reporting Responsibility

The normal field expectation is that the **Captain of the crew** records the work performed for that crew/task period.

The report must be easy enough to complete from the field without reconstructing the day later.

The authenticated reporter identity should be captured automatically through the existing actor/audit boundary. The Captain should not have to type their own name into every report.

Managers may retain governed override/report capability.

## Current Implemented Progress Model

The current Setup execution design already supports durable **multi-period progress** through:

```text
ops.setup_task_progress
```

Current progress evidence includes:

```text
setup_session_task_id
setup_work_day_id
shift_code
crew_count
completed_quantity
completed_units
progress_note
marks_task_complete
recorded_at
created_by_person_id / audit identity
```

The current protected browser form asks for:

```text
Crew size
Completed quantity (optional)
Which units / what was completed (optional)
Progress note
Mark task complete
```

The current API and governed command record crew size and progress detail but do **not** record elapsed work duration for each progress period.

That is the current gap.

## Required Per-Progress Duration

Each progress/work report should record:

```text
actual crew size
elapsed work duration
what was accomplished / progress detail
whether the task is now complete
```

Duration belongs on the **individual progress/work-period record**, because one reusable task can span multiple days and multiple crews.

Recommended database representation:

```text
duration_minutes integer > 0
```

Recommended field UI can remain human-friendly:

```text
Crew size   [ 6 ]
Hours       [ 2 ]
Minutes     [ 30 ]
```

or an equivalent simple duration control.

The application can convert that to total minutes before saving.

Do not require the Captain to fabricate exact clock start/end timestamps when the meaningful fact is simply that the crew worked the task for about 2 hours 30 minutes.

## Why Annual Task Duration Alone Is Not Enough

`ops.setup_session_task.actual_duration_minutes` exists at the annual-task level, but one scalar value cannot faithfully represent this real pattern:

```text
Day 1: Crew 6 works 2h 30m — partial
Day 3: Crew 4 works 1h 15m — partial
Day 6: Crew 5 works 45m — complete
```

The durable source should be the individual progress rows.

If an annual total is useful, it should be derived or deliberately summarized from those progress rows rather than overwriting the evidence of each work period.

## Elapsed Duration vs Person-Hours

These are different measures.

Example:

```text
crew size = 6
elapsed duration = 2.5 hours
```

means:

```text
elapsed crew-task duration = 2.5 hours
person-hours                = 15.0 hours
```

Both can be useful for future planning, but they must not be confused.

Useful derived measures include:

```text
total elapsed crew-task minutes = SUM(duration_minutes)
person-hours                    = SUM(crew_count * duration_minutes) / 60
work periods                    = COUNT(progress rows)
```

The reusable planning estimate should not be automatically overwritten by one atypical work period.

## Captain Reporting UX

The reporting interaction should be available directly from the current crew/task execution view.

Target field workflow:

1. Captain opens the assigned/current task.
2. Selects **Report Work** or equivalent.
3. Enters actual crew size.
4. Enters hours/minutes worked.
5. Optionally records quantity/units and a short progress note.
6. Checks **Task Complete** only if the reusable task's completion point was actually reached.
7. Saves once.

The app should automatically know:

- authenticated reporter;
- current Setup Session;
- task identity;
- current/selected work day when available.

The Captain should not need to navigate raw Setup tables or re-enter context the application already knows.

## Multi-Day Tasks

A progress report does not imply completion.

Required behavior:

- multiple progress records may exist for one annual task;
- each record has its own crew size and duration;
- a task remains `IN_PROGRESS` until explicitly completed;
- later crews can continue the same task;
- previous progress history remains visible;
- total effort can be derived from all progress periods.

## Historical Reconstruction

Rick Hoffmann's 2025 notes can help populate or estimate:

- actual crew size;
- actual work period duration where explicitly supported;
- partial progress;
- completion date/state;
- reusable normal crew range;
- reusable expected duration.

Do not convert a person's whole-day recorded hours into a task duration when that day included several tasks.

Where the historical evidence supports separate work periods, preserve them as separate evidence rather than collapsing them into one fake task duration.

## Authorization Boundary

The existing Setup execution model already distinguishes field execution from broad Manager maintenance. Current migration 009 states that progress/completion commands are available to Managers or a person explicitly assigned as CAPTAIN/ALTERNATE for the reusable task.

Keep that governed model.

The browser/API should not broaden direct table DML merely to add duration reporting.

## Acceptance Criteria

A complete implementation should prove:

- positive per-progress duration validation;
- duration appears in progress history;
- repeated progress reports can be recorded across several work days for one task;
- Captain/Alternate/Manager execution authorization remains intact;
- authenticated reporter identity is stamped automatically;
- partial progress does not mark a task complete;
- task completion remains explicit;
- elapsed duration and person-hours can be derived separately;
- no artificial start/end timestamps are required for ordinary duration reporting; and
- no sequential Stage-completion rule is introduced.

## Related Durable Sources

- [Setup Planning Operating Model](Setup_Planning_Operating_Model_2026-09-08.md)
- [Setup engineering portal](README.md)
- [2025 Live Review Work Ledger](Setup_2025_Live_Review_Work_Ledger_2026-09-08.md)
- GitHub issue #122
- GitHub issue #132
- GitHub PR #125
