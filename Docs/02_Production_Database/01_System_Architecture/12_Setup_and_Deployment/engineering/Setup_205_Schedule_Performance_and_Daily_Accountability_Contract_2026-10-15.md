# #205 Setup Schedule Performance and Daily Manager Accountability — Engineering Contract

| Document Control | Value |
|---|---|
| System | Production Database — Setup / Plan Schedule / Perform Work |
| Status | ENGINEERING CONTRACT — pending reconciliation and acceptance |
| Owner | MSB Production Database Setup engineering |
| Governing authority | #122 release gates; #205 Scheduling Board |
| Related authorities | #132 Report Work, #175 Perform Work, #172 Report Correction, #206 material readiness |
| Last reviewed | 2026-10-15 |

This document is the controlled engineering authority for whole-Setup schedule KPIs, reporting reconciliation, daily exception follow-up, Manager notifications, and deep-link acceptance. PRs **consume** this contract; neither issue comments nor PR descriptions replace it. Production behavior remains whatever was separately accepted/deployed; descriptions below are required target behavior, not claims of completed implementation.

## Problem and operator goal

The application can look healthy because work is scheduled or reported partially while significant work is unfinished, unreported, not ready, or unschedulable. The priority is to determine how much Setup is finished, what remains, which work requires attention, whether actual completion pace meets the hard deadline, and what Managers must do today. Partial/missing labor estimates cannot suppress task-based visibility or masquerade as total remaining effort.

2026-10-14 operator evidence: 294 annual tasks, 63 effectively completed, 231 remaining, 36 calendar days through November 19. 2026-10-15 Plan/Schedule screenshot: 294 total, 72 complete, 25 scheduled, 13 in progress, 12 need rescheduling; Perform Work Captain-filtered to one of 122 scheduled assignments. These are *dated UI observations*, not independently reconciled live PostgreSQL counts. The change from 63 to 72 must not be presumed correct or incorrect without row-level proof. Sample digest 8 missing / 5 need scheduling / 3 blocked is illustrative, **not** observed Production data.

## Authoritative sources and boundaries

- Annual task identity and included/deferred/completed state: `ops.setup_session_task` annual rows as projected by existing Setup scheduling repository; deduplicate `setup_session_task_id`. Include season-only work. Complete means effective annual completion including accepted linked Work Order gate logic. 90% remains unfinished.
- Scheduling: `ops.setup_work_day`, `ops.setup_work_day_task`, crew/Captain and shift identities. One task can have many distinct historical and future occurrences; never turn assignment count into annual-task count.
- Reporting: `ops.setup_task_progress` and occurrence-specific `work_report_count` / `reported_percent_complete` projection, including supported legacy workday/task/shift matching. A partial report satisfies reporting for that *occurrence*, not annual completion.
- Annual date and completed evidence: `actual_completed_at`, completion-marked progress/workday and linked Work Order date. Existing completion command may derive `actual_completed_at` from `recorded_at`; late entry cannot silently be treated as workday completion for actual pace. Reconcile read-only against real current-Production clone.
- Blockers: existing prerequisite graph and `prerequisites_complete`, linked open Work Order gate, and independently recorded `readiness_state=NOT_READY`. `board_status` alone is not a blocker truth source: scheduled and continuation branches can take precedence before readiness checks.
- Hard deadline: existing `setupAnnualMilestoneDates` Complete Setup (November 19 in 2026). America/Chicago operational dates for workday/reports, independent of client host timezone.
- Plan/Schedule and Perform Work consume **one global KPI classifier** for whole-Setup counts, regardless of Captain-filtered task view. Do not leak Manager-only information to unauthorized roles.

## Required dashboard hierarchy — both screens

1. Total / Confirmed Complete / Remaining annual tasks. Explicitly display deferred count and forecast exclusion. Remaining = total minus effective complete; scheduled remains unfinished.
2. Attention required: past assignments unreported, incomplete work needing continuation, independently blocked and NOT READY, Captain TBD and approaching workday risks.
3. Recorded recent task completions/day and required completions/day, both **calendar-day** and **potential workday**; dated and qualified projected finish versus hard deadline.
4. Contextual scheduled, in progress, first-time unscheduled, partial, deferred. Labor estimates, actual hours, planned hours and coverage secondary; never show known partial labor as season total.

All counts need linked lists with human task name, Stage/Scene, Captain, assignment/shift/date, progress and precise reason. Categories can overlap; do not add their counts together as a partition. Where possible, show both **occurrence count** (missing reports) and distinct annual tasks affected.

### Explicit classifiers

| KPI | Classification | Next action |
|---|---|---|
| Complete | Annual `effective_complete` true | Inspect completion evidence |
| Remaining | Annual task not effectively complete | Review planning status |
| Scheduled | Unfinished and active unworked schedule occurrence | Open dated crew/shift assignment |
| In progress | Annual execution in progress and not complete | Review reported percentage |
| Needs rescheduling | Unfinished started work with no active continuation assignment | Manager schedule continuation |
| Needs first scheduling | Unstarted included nondeferred annual work with no active assignment | Manager schedule backlog |
| Past / no report | Historical scheduled occurrence, date before today Chicago, zero occurrence work reports | Captain follow-up; unresolved even if task later rescheduled/completed |
| Reported incomplete | Historical occurrence has report but annual task incomplete | Inspect remaining work and continuation |
| Partial | Annual task reported progress >0 and <100 and not effectively complete | Retain visible progress, do not count complete |
| Hard blocked | Unfinished with incomplete hard prerequisite or unresolved Work Order gate | Show exact edge/WO and responsible resolution |
| NOT READY | Unfinished with readiness_state NOT_READY | Show readiness reason separately; may coexist with scheduled/hard blocked |
| Deferred | Annual work intentionally deferred and not effectively complete | Disclose in remaining; explicitly exclude from active required pace |
| Captain TBD | Scheduled or unreported assignment lacking a named Captain | Manager assign or correct crew responsibility |

Overdue/no-report is *not* proof of zero field work; likewise a 100% annual task does not retroactively supply missing scheduled work-period reports. **Exception with explicit Manager-confirmed NO WORK:** an original occurrence with no actual work/report may be moved to a future workday using the existing guarded assignment-move command; the active assignment then no longer qualifies as LATE on its former date, while the original date/crew/shift and Manager actor remain recorded in `ops.setup_schedule_event` (migration 069). This does not create a work report or claim progress. Where actual work/history exists, the original occurrence remains locked and a new continuation must be scheduled. Never automatically infer no work, suppress a genuinely unreported occurrence, delete actual history or bypass erroneous saved 1% reports.

### Deadline and workday semantics

- Calendar denominator = dates remaining until hard deadline under explicitly stated end-date inclusion rule; both actual and required calendar averages include zero-completion days.
- Potential workday denominator = future dates excluding Sundays, using the **same inclusion rule** as calendar days. These are potential capacity dates, *not verified staffed dates*.
- Actual scheduled workday count = distinct future `ops.setup_work_day` dates. Because scheduling is rolling horizon, absence of future dates is not proof of no available labor; do not use scheduled-day count as the entire season denominator.
- Recent workday average = task completions dated to eligible non-Sunday dates / number of eligible non-Sunday dates in the explicit recent window (including zero days); report Sunday completions separately, not silently omit them from calendar pace.
- Avoid mixing calendar-day productivity and workday denominators. Explicitly label 7-day sampling window and assumptions; distinguish recorded timestamp from actual completed work date.
- Projection is **task-count based**, inherently inaccurate where tasks vary in size. Do not show a green/on-track classification with missing/unverified completion dates, low sample coverage or insufficient evidence. Display the confidence limitation and counted/undated totals.
- Also disclose incomplete duration/crew/labor estimate coverage, and observe that future staffing/weather/equipment availability may change the forecast.

## Mandatory reconciliation before KPI acceptance

Using a disposable snapshot of current Production, independently audit:
1. Annual in-scope IDs by origin and deferral status; compare both screen totals and complete/remaining.
2. Completion evidence for each annual effective-complete task; confirm the October 14→15 observed +9 completions by ID and dates or flag discrepancy.
3. Historical assignment list joined to report evidence, including duplicates, mixed reported/unreported days, late submissions, partial/100%, legacy matches, rescheduled continuations and Captain TBD.
4. Blocked scheduled and unscheduled tasks regardless of `board_status`; distinguish hard predecessor/WO from soft readiness.
5. Past scheduled day filters: the existing Unfinished filter is **day-level**; mixed days can show COMPLETE — Work Reported cards. Do not silently reinterpret as a task-level filter. Improve terminology and drilldown.
6. Preserve reported historical associations and audited correction: October 7 D9 Captain Tom Shircel Crew B-to-existing-Crew A known discrepancy, then verify erroneous duplicate crew B can be removed only through a separate governed correction. Do not mutate under this KPI work without independent approval.
7. Verify date arithmetic across Chicago DST, Sundays, past deadline, no scheduled future workdays, zero progress, late entries and unavailable dates.
8. Compare backend projections to UI counts on both screens and email's source query; no independent inconsistent KPI implementations.

## Daily Manager reconciliation and email

Every past scheduled workday must be reviewed on the following operational day. Authorized Managers receive **one consolidated daily exception digest** containing unresolved historical missing reports, reported-but-incomplete work with no continuation, upcoming blocked/NOT READY scheduled work, and Captain TBD. Show original work date, Stage/Scene and *human task name*, named Captain or TBD, crew/shift, last report/progress, current continuation/date, reason and required action. Carry unresolved exceptions forward daily until correctly reported, rescheduled, or otherwise resolved via existing governed operation. Sending/opening email is not resolution.

Use existing authenticated Setup links, direct to the exact task/assignment/report correction/scheduling target. Deep links must expand hidden/collapsed days, preserve normal filters and permissions, and not invent URL parameters until navigation contract is tested. Captain name links should lead to an authorized list of that Captain's outstanding items, not disclosure of private contact information. Avoid links pointing to general landing pages where the user must search again.

Mail recipients, Manager authorization, digest timing, sender, deployment scheduler, retry/deduplication key, recipient delivery audit and errors must come from a documented existing MSB notification/host contract, after reconnaissance. Current Directus **WOI Request Triage Email** flow is for work_order_intake creates; do not repurpose it or generate fake Work Orders to send Setup digest. Mail dispatch is a separate authorized implementation/deployment gate; **none is currently activated**.

Resolution path: named Captain submits/corrects original report under #132, Manager creates appropriate continuation under #205, resolves #172 work-order gate or readiness issue at its owner, or performs a separately authorized historical correction; retain audit and original occurrence. Daily Manager email should not automatically email Captains without explicit approval. Protect all data and links with existing Setup authentication.

## Acceptance and implementation ownership

- #205 owns schedule classifications, Manager exception worklist, deadline KPI and daily Manager accountability interface; #132 retains Report Work persistence, #175 Perform Work, #172 Work Order Intake notification, #122 release authority.
- Existing source implementation draft PR #394 is **not accepted**. Some counts/drilldown and preliminary forecast code exists but is not reconciled against real Production completion dates, historic obligations or mail integration. Engineering MUST test its calculations against this contract and correct discrepancies; the PR cannot redefine contract to match existing code.
- Full Setup/FieldWiring affected tests, cross-view and deep-link regression, same current-Production disposable acceptance and browser review on governed 8898 with CLEAN EXIT. Version/source SHA and acceptance gates per #122/Server Management. No Production mutation without explicit operator approval.
- Test high-risk cases: task 90% not finished; same annual task across 3 assigned days; missed report after rescheduling/completion; Captain TBD; blocked but scheduled; soft readiness; zero reports vs report with zero duration; deferred; Sunday; zero productive weekdays; late reported completion; duplicate digest invocation; send failure/retry; link authorization and collapsed-day target focus.
- Never represent sample UI counts or mock-email totals as current Production facts.

## Evidence and authority

- #205 operating model and October 14–15 operator findings, subordinate to #122.
- Existing `Setup/Application/setup_scheduling_board_repository.py`, `setup_scheduling_board.js`, `setup_next_pass.js`; #132 report record model and #172 triage integration.
- Controlled parent portal: [Setup engineering README](README.md). This document supersedes contradictory KPI requirements recorded only in PR descriptions or chat, but does not alter unrelated accepted Setup behavior.


## Read-only Production reconnaissance — execution order and evidence (2026-10-15)

**Gate:** these are SELECT-only diagnostic queries. Run against the authoritative 2026 Setup PostgreSQL source using an existing permitted read-only connection. Do not create a session, edit 2026 data, backfill progress, reschedule, mutate history or alter Production. Capture the server timestamp/time zone, exact queries, record counts and redacted detail in a controlled acceptance report, then reconcile classifications here. Prefer existing documented database query tooling and credentials; do not improvise server shell/connection strings.

### A. Verify schema and session before querying work

```sql
BEGIN READ ONLY;
SELECT now() AS server_now,
       now() AT TIME ZONE 'America/Chicago' AS chicago_now,
       current_database() AS database_name,
       current_user AS query_actor;
SELECT table_schema, table_name, column_name, data_type
FROM information_schema.columns
WHERE (table_schema, table_name) IN (
 ('ops','setup_session'), ('ops','setup_session_task'),
 ('ops','setup_work_day'), ('ops','setup_work_day_task'),
 ('ops','setup_work_day_crew'), ('ops','setup_task_progress'))
ORDER BY table_schema, table_name, ordinal_position;
ROLLBACK;
```

Confirm actual installed schema. This preflight must precede all later parameterized queries and determines whether session date/season fields and completion/report fields differ from the source definitions. Read-only transaction must not be silently continued past a SQL error.

### B. Annual-task status cross-check — after verifying column names

```sql
BEGIN READ ONLY;
SELECT s.setup_session_id, s.season_year,
       count(*) FILTER (WHERE t.included_flag) AS included,
       count(*) FILTER (WHERE t.included_flag AND t.execution_status = 'COMPLETE') AS status_complete,
       count(*) FILTER (WHERE t.included_flag AND t.execution_status = 'IN_PROGRESS') AS status_in_progress,
       count(*) FILTER (WHERE t.included_flag AND t.execution_status = 'DEFERRED') AS status_deferred,
       count(*) FILTER (WHERE t.included_flag AND t.execution_status <> 'COMPLETE') AS not_status_complete
FROM ops.setup_session AS s
JOIN ops.setup_session_task AS t USING (setup_session_id)
WHERE s.season_year = 2026
GROUP BY s.setup_session_id, s.season_year;
ROLLBACK;
```

`execution_status` is **not** identical to effective completion (completed linked Work Order gates count too). Compare this query to the repository's existing effective-completion projection before claiming screenshot totals should match.

### C. Past scheduled assignments and report evidence — after verifying schema

```sql
BEGIN READ ONLY;
SELECT wd.work_date,
       a.setup_work_day_task_id, a.setup_session_task_id, a.shift_code,
       a.setup_work_day_crew_id, c.crew_code, c.captain_person_id,
       t.annual_task_name AS task_name, t.execution_status,
       t.actual_completed_at,
       count(DISTINCT p.setup_task_progress_id) AS report_count,
       max(p.percent_complete) AS highest_reported_percent,
       min(p.recorded_at) AS earliest_report_entry,
       max(p.recorded_at) AS latest_report_entry
FROM ops.setup_work_day_task AS a
JOIN ops.setup_work_day AS wd USING (setup_work_day_id)
JOIN ops.setup_session_task AS t USING (setup_session_task_id)
LEFT JOIN ops.setup_work_day_crew AS c
  ON c.setup_work_day_crew_id = a.setup_work_day_crew_id
LEFT JOIN ops.setup_task_progress AS p
  ON p.setup_work_day_task_id = a.setup_work_day_task_id
  OR (p.setup_work_day_task_id IS NULL
      AND p.setup_work_day_id = a.setup_work_day_id
      AND p.setup_session_task_id = a.setup_session_task_id
      AND p.shift_code = a.shift_code)
WHERE wd.work_date < (now() AT TIME ZONE 'America/Chicago')::date
  AND t.setup_session_id = (
    SELECT setup_session_id FROM ops.setup_session
    WHERE season_year = 2026
    ORDER BY setup_session_id DESC LIMIT 1)
GROUP BY wd.work_date, a.setup_work_day_task_id, a.setup_session_task_id,
         a.shift_code, a.setup_work_day_crew_id, c.crew_code,
         c.captain_person_id, t.annual_task_name,
         t.execution_status, t.actual_completed_at
ORDER BY wd.work_date DESC, a.setup_work_day_task_id;
ROLLBACK;
```

Verify the progress primary-key column and installed legacy association contract before running. This is a **historical occurrence** audit. Filter `report_count=0` *after* recording all rows, and separately identify zero-duration but valid progress reports, future continuation records and cancelled workdays. Do not call a task overdue merely because an intentionally cancelled day remains in history.

### D. What the resulting audit must reconcile

- Exact annual total vs inclusion flag and effective completion, with detail for the observed October 14 63 → October 15 72 change.
- Past assignment no-report, reported-partial, reported-complete but annual incomplete, completed annual task with missing prior occurrence report.
- Report `recorded_at` vs associated `work_date`, highlighting late-entry lag and questionable annual `actual_completed_at`.
- One annual task with several assignment records; same Captain/shift unexpectedly repeated across crews; known D9 Crew B/A exception.
- Independent prerequisite, linked Work Order and NOT_READY flags for **scheduled as well as unscheduled** tasks; only use the repository's effective completion semantics for whole-Setup results.
- Original missed date retained even when subsequent continuation was scheduled. Label reporting-unknown separately from confirmed-unfinished.
- Keep personal names in authorized internal reports; redact them from public PR logs when necessary.

**Stop before remediation:** no data repair, mail service activation, schema changes, job schedules or Production deployment are authorized by reconnaissance. The audit will determine which source projection, UI classifier, workflow or recorded history requires a separately governed correction.


## Verified read-only Production query observations — October 15, 09:06 CDT

**Evidence provenance:** operator-supplied Q1–Q6 output from `msb` queried as `msbadmin`; query time 2026-10-15 09:06:41 America/Chicago. These are **observations**, not authorized corrections. Full raw query output remains with operator; preserve the exact source in subsequent acceptance capture.

- 2026 `ops.setup_session` = ID **2**, status `PLANNING` (the actual live annual session is already in use; don't infer inactivity from this state label).
- Annual snapshot: **294** annual/included; **72** `execution_status=COMPLETE`; **13** `IN_PROGRESS`; **0** `DEFERRED`; **222** not `COMPLETE`. Status-count equivalence with `effective_complete` must still be checked for Work Order gates.
- All thirteen `IN_PROGRESS` tasks have progress records; reported maxima: task 276 95%, 373 90%, 533 90%, 436 90%, 469 80%, 531 80%, 425 75%, 417 66%, 364 60%, 485 50%, 499 50%, 348 50%, 363 15%. They are **not complete**. Prior Q5 output showed historical assignment counts, not verified active continuation counts; cannot claim exactly 13 need rescheduling without proper assignment-state query.
- Operator-supplied Q3 lists **102 historical assignment occurrences** before Chicago Oct 15, of which **8 with zero matched reports**, affecting **8 distinct annual tasks**:
  - Oct13: assignment 100 task293, Crew B / Captain person25, morning; assignment101 task295, Crew B / person25, morning; assignment102 task296, Crew B / person25, afternoon.
  - Oct14: assignment41 task546, Crew E / person25, morning; assignment103 task352, Crew D / person36, morning; assignment104 task300, Crew D / person36, afternoon; assignment145 task363, Crew F / person17, morning; assignment153 task541, Crew C / person31, afternoon.
  - This is a *candidate historical no-report queue*; recheck cancelled-day and actual-work/scheduling semantics and resolve person IDs through authorized ref.person before notifying. Task363 is IN_PROGRESS from an earlier report yet has an Oct14 unreported occurrence.
- Operator-supplied Q6 lists **103 progress reports**: **63 same-date** entry and associated work date, **34 reported after work date**, **6 with a future associated work_date relative to report entry**. Negative differences include tasks550 and269 with Oct16 associated dates from Oct13, and others 274,273,266; identify possible rescheduling/early entry vs incorrect history before conclusion.
- Three entries show lag >=7 days: task533 +7, task291 +15, task324 +17. Date-entry lag means `recorded_at` is not a reliable proxy for physical work date.
- All completed-task rows returned in Q6 show **NULL `actual_completed_at`** despite completion-marked progress records. Diagnose whether task-based KPI must resolve the completion-marked report's linked work_date, rather than relying on the annual timestamp, and whether that absence is valid by design or a defect. Do NOT silently backfill.
- D9 Crew B/A historical correction is still separate and unresolved. Treat as an explicit audit exception.
- Workday readiness, hard prerequisite coverage, linked Work Order completion, definitive unworked continuation, date provenance and Manager notification recipients remain **unverified**.

**Required follow-up:** Inspect existing repository projection's `unworked_assignment_count` and report matching contract, compare to the 12 needs-rescheduling count seen on the Oct15 UI, and run a bounded hard-block/readiness query. Derive names through existing `ref.person` without exposing private contact details in public evidence. Never present Q6 report-date counts as 7-day *unique annual task completion* pace: the rows can include repeated reports for one annual task.

**Implementation defect to check in PR #394:** its preliminary KPI model uses `actual_completed_at` or linked Work Order completed date, so these completed task rows are undated. The conservative `INSUFFICIENT DATA` warning is right, but the final actual pace must use verified physical workday evidence (at most one completion per annual task) rather than assuming no recorded work.


## Operator directive — daily training and recipient split (2026-10-15)

Greg requires daily **actionable follow-up for missing reports**, and the notification itself must teach the recipient how to enter the work report. **Deliver to Managers AND directly to the named Captain only if that Captain has a verified active `@sheboyganlights.org` email identity and current access.** Do not assume `captain_person_id` implies an email address, assume a personal email may be used, or broadcast all Captains' assignments to every Captain. Manager digest covers ALL relevant exceptions; Captain notice covers ONLY that Captain's own missing reporting occurrences. When a Captain has no qualifying organizational address, no linked identity, or Captain TBD, route action to the Managers. Names must come from `ref.person` identity data and existing secure application authorization; verify actual recipient mapping before any send. Repeated notices must be consolidated and idempotent per day, with recorded delivery failure.

### Captain notice — required readable wording and action

Subject: **MSB Setup — Please report your work from [day/date]**

Message must identify exact scheduled **Task name**, Stage/Scene, **Setup Day + work date**, crew and AM/PM, named Captain, and one authenticated link to that exact **Report Work** occurrence (or a fully labeled fallback link to Perform Work until deep-link action is accepted). This is a training notification, not blame or automatic accusation of no work.

**Plain-language step-by-step instructions (must reflect current operator SOP and verified UI):**
1. Open the link and sign in with your MSB account if asked.
2. Confirm the season says **2026**, then open **Perform Work**.
3. Select your name in the **Captain** dropdown, or select **All scheduled work** if a Manager is helping.
4. Find the exact **Setup Day**, **task name**, **crew** and **AM/PM** shown above. If the day is collapsed or the assignment is hidden, use the provided historical-item link/focus behavior; don't choose a similar task by mistake.
5. Open the task. Select **Report Work**.
6. Enter **Work completed on** (the day the crew *actually worked*, even if different from the planned workday), actual **Crew size**, and **Hours**/**Minutes** actually worked.
7. Enter cumulative **% complete**: enter **100** only if the whole task is done. If unfinished, enter the actual cumulative percent and write **What was done / what remains** clearly. Optional quantity only for countable work.
8. Check all values and choose **Save Work Report**.
9. Check the task's **Progress history** to verify the report was saved. If unfinished, tell the Manager what remains so they can schedule a new work assignment; reporting does not create the continuation automatically.
10. If **no work happened**, do **not** fabricate time, percent or a fake work report. Tell your Manager that the assignment must be reviewed/replanned. If a report is wrong, ask a Manager to use **Correct report**, not a duplicate report. If the task/procedure/data is wrong, use the separate **Report Correction** flow.

Maintain a direct link to the current [Perform and Report Setup Work SOP](../operatorSOP/Perform_and_Report_Setup_Work.md) with this exact field and action sequence. On-screen deep link must be validated in protected browser; no fabricated query string or email send before that acceptance.

### Daily email categories and actions

- **Manager digest:** each unreported past occurrence; each incomplete task with no continuation (including the **13** Q7 `IN_PROGRESS` rows with zero current/future assignments, subject to exact active-unworked verification); upcoming hard and soft readiness blockers; Captain TBD/recipient unmapped. Manager decisions are report follow-up, actual reschedule/continuation, or governed correction. Names and dates are mandatory.
- **Captain targeted reminder:** their own outstanding unreported assignments, using the training steps above. Never send future dates, other Captains' work, or duplicate notices. Don't ask Captains to change schedules or invent reports.
- **Resolution:** actual progress report on historical assignment clears that occurrence's missing-report warning; partial report can leave the annual task unfinished and requiring rescheduling. Replanning a different continuation must never hide a possibly unreported historical occurrence. **But when a Manager explicitly confirms no work took place on the original unworked assignment, moving that exact assignment through the governed audited update clears the old-date LATE condition**, because there is no work to report and the move audit retains the prior plan. Do not auto-dismiss or invent an empty/1% work report.
- **Daily follow-up:** previous workday and *all still-unresolved earlier days*, with Chicago date boundary and an explicit deduplication/delivery log.

### New evidence from Q7 and Q8

- Q7 (operator-supplied Oct15) returned **13 IN_PROGRESS annual tasks**, each with **zero current-or-future dated assignments**. That is a bounded initial view, not proof that all 13 meet the application's exact `unworked_assignment_count` classifier (which also accounts for historical actual evidence). **The displayed 12 needs-rescheduling vs 13 in-progress difference requires an item-by-item projection reconciliation**; don't assert one task has a continuation without evidence.
- Q8 (operator-supplied) returned **55 unfinished tasks** matching `NOT_READY` readiness and/or a linked Work Order gate. This is not a hard-block count and not 55 imminent actionable delays. For example #548 seasonal deer rut and #339 November 1 are planned date restrictions; separate future temporal readiness from currently blocking imminent work. #546 Replace Light Pole 8 Outlet Box is PLANNED with linked gate #416 not complete; #543 MAS Skin Repair linked WO #156; #542 WO372 Magic Igloo Weld Repairs linked WO372. Verify whether scheduled work bypasses readiness warning and whether notes are stale or contradicted by field activity before auto-escalation.
- Manager notifications need **priority escalation**, especially scheduled future days with unresolved prerequisites/NOT_READY, but cannot turn every season-later readiness note into a daily crisis. Show days-until-scheduled, blocker type, age, action owner and reason.


## Operational failure mode: schedule being used to trigger Pick List (October 15 operator report)

**New operator evidence, not yet independently measured:** Rick has been adding tasks to Plan/Schedule to generate #206 physical Pick List demand even when actual available crews/linear time make the plan impossible. Overload warnings, required crew sizes and linear duration estimates were already introduced. Overcommitted dates create unworked past assignments, avoidable Captain report escalations, Manager rescheduling work and a falsely healthy forward plan. Do **not** treat this solely as a Captain training or notification failure; avoid punishing people for a demand-generation workflow problem.

**Existing accepted design capability verified:** The controlled `operatorSOP/Rolling_Pick_List_and_Pick_Delay.md` documents **Manager Early-Pick Demand** on **Manager Material Status** (#206): it requests physical material without creating annual task scheduling, and separate Pick Delay / Resume Pick functionality exists. This is already a Production-accepted route. Early pick is currently one-item-at-a-time, not bulk. We must investigate whether discoverability, workflow friction, authorization, material eligibility or volume limitations cause use of fake scheduling. Do not invent another demand model or reopen #206's accepted inventory/movement semantics without proof.

### Required engineering analysis before changing either subsystem

1. Read-only investigate historical workdays: scheduled task count, planned min crew/linear duration per AM/PM/crew, capacity and overload override records, actual assignment reports and workday completion. Identify dates where plan exceeded physically plausible capacity; do not infer intent from data or attribute blame to an individual.
2. Separate **true execution commitments** from **logistics-only early material demand**. Verify Manager Material Status can fulfill the actual physical request without fabricated Setup assignments, and document limitations with reproducible examples and operator review.
3. Quantify administrative churn: missed/unreported assignment count, reported-but-incomplete without continuation, moved future assignments and repeated task appearances. Preserve historical original assignment/report evidence and audit.
4. User-facing Manager dashboard must expose impossible-looking upcoming schedules before the shift: linear AM/PM overcapacity, missing duration or crew estimate, short-crew warning, hard prereq/NOT_READY, and task's existing current Pick List demand source. Display warning alongside real workforce availability where known, not a fictitious implied staffing pool.
5. The daily accountability digest must distinguish a Captain not filing a report from a scheduled assignment that was never realistically intended for actual execution. If no work happened, obtain Manager disposition using governed existing processes, not a fake zero-hour report or automatic completion. Preserve the original schedule facts.
6. Operator training should teach: **Need material early? Use Manager Material Status → Early-Pick Demand. Need crew work? Use Plan/Schedule. Worked? Use Report Work. Unfinished? Schedule continuation.** Link existing SOP; do not invent another Pick List or mutate material/movement state from merely scheduling.
7. Any improvement to bulk logistics picking belongs under #206 as the owning material source, with #122 integration; workload/overcommitment controls remain #205. This cross-boundary observation is part of this controlled contract; PR #394 must consume it and must not claim operator acceptance before tested.
8. Do not silently auto-reschedule or reclassify old tasks, send accusation-style emails, or alter Production history. Investigate first, then show Greg an operator-safe browser candidate for testing.

**Decision boundary:** allow explicit Manager override of overload only under existing documented governance, but display a clear unsustainable schedule signal and record override evidence. Do not equate schedule size with progress toward the deadline. No Production authorization from this discovery.


## Operator clarification — Tom/Rick boundaries and capacity constraints (2026-10-15)

Greg clarified that **Manager Early-Pick Demand was intentionally not communicated broadly**. Material staging space was constrained, and the early-pick override had caused operational problems. Greg deliberately trained **Tom**, who typically manages materials, as its limited operator. **Rick primarily manages people/crew scheduling and needs a very simple computer workflow.** Do not assume Rick was expected to know or use Manager Material Status, call it a failure to follow training, broaden override permissions, or tell Rick to create material overrides. Prior generic advice to train every scheduler on Early-Pick Demand is **superseded**.

**Revised engineering responsibilities and questions:**
- Rick's primary interface remains **Plan / Schedule** for believable crew commitments. Help him see time/crew overload clearly with plain-language next actions; do not make him perform material inventory or logistics management.
- Tom's material workflow must respect **physical staging space** and the existing #206 override safety rules. A requested early pull can be inappropriate simply because there is nowhere safe to put the items. Check storage/staging capacity and existing picked/moved material before proposing any change to override workflow.
- Need for materials ahead of scheduled execution must flow via a clear **Rick-to-Tom request/coordination path**, not by inserting fictitious work assignments. Investigate whether a lightweight request/status handoff can reuse current #206 data and existing communication; do not implement a new logistics entity or imply authorization yet.
- Before any change, reconcile actual schedule overload and report obligations. A schedule set up to generate Pick List demand is a **workflow/system design signal**, not grounds to blame Captain, Rick, or Tom.
- Daily Manager/Captain reporting reminders should distinguish true scheduled field commitments from inaccurate logistics-driven assignments; obtain Manager disposition before treating every historical no-report as Captain failure.
- Operator language must be concise and explicit for users with limited computer familiarity. Keep Manager scheduling actions separate from material authority. Do not show controls that promise staging/pick capacity which has not been measured.

These are owner-provided operational facts/constraints, **not a grant of Production change authorization**. Reconcile with #122 and #206 without reopening established physical Pick List or movement semantics unnecessarily.


## Discoverability defect — contextual operator help (2026-10-15)

Greg confirms operators are not reading existing documentation, in significant part because it is too hard to find even for an experienced Manager. A separate internal web-page workstream crawls repository README.md operator documentation to populate a **static** instruction site. That discoverability system is not currently contextual to controls in Setup and is a separate project; do not redesign or overwrite that workstream here.

**Required Setup engineering contract:** Provide *in-context help entry points* at the application action where a person needs them, e.g. Plan/Schedule workload/overload and rescheduling; Perform Work historical/partial/no-work reporting; Report Work date/crew/time/percent; Pick List and Manager Material Status (with role-specific wording); KPI Action Required and email follow-up. Each entry must give very short, plain-language, field-matched numbered steps (suitable for first-time operators), and link to the **existing authoritative operator SOP**. Do not duplicate and independently maintain long help prose across the app, SOP and internal portal.

**Source-of-truth and integration rules:**
- Controlled `operatorSOP` documentation owns approved procedure wording; Setup engineering documentation owns how the app presents and links it. PR consumes these authorities.
- Inspect existing Setup help entry points and actual SOP URLs/repository publication contract before choosing links, embedded content, versioning or assets. Do not guess that a GitHub raw README link works in the protected app or that the internal portal route is stable.
- Design for Android tablets, keyboard and desktop; label Help beside the corresponding field/action, preserve task and form state, do not navigate away and discard unsaved reports. Accessible close/back and explicit screen context are mandatory.
- Role-based clarity: Rick needs realistic workload/scheduling and simple rescheduling; Tom owns materials; Captains need simple actual-work reporting; Managers need cross-crew discrepancy resolution. Don't expose a material override instruction to a role that isn't authorized for it.
- Help for the Manager daily email follows the real Report Work procedure; clickable links target the right historical occurrence and do not require a person to search through general documentation.
- Verify SOP accuracy and app version together as part of release acceptance. No new standalone documentation portal or competing CMS by default.
- Cross-project coordination: the static internal web/README crawler can remain a documentation index. The Setup app must own contextual Help at its own actions; confirm integration contract with the separate internal-web workstream before implementing.

**Status:** operator requirement/documentation correction only. Contextual help controls have **not** been implemented or accepted in PR #394; review separate UI ownership and #122 gates before scope/integration changes.


## Bounded Report Work usability and Randy acceptance gate — October 15

Greg's investigation found a separate but causal reporting usability defect. Existing **About** copy is too technical and little read. Scattered question-mark (`?`) help controls have not been consistently implemented. The **Hours, Minutes, actual Crew size** inputs visually blend into their surroundings, and operators miss the Minutes input. Failure to report needs both a follow-up prompt **and clear corrective instructions**. This is a bounded improvement to the existing #175/#132 Report Work UI, not authorization for an application-wide redesign.

**Implementation requirements (preserve report commands/history):**
- Make actual Crew size, elapsed Hours and **Minutes**, cumulative % complete and actual work date visibly distinct, labeled at the field, and ordered in plain language. Minutes must not appear as an inconspicuous secondary control. Check tablet layout, focus order, labels and input affordances; do not change persistence units or silently default Minutes to zero when omitted.
- Show short `?` contextual instructions at key controls using a **consistent visual, keyboard and touchscreen pattern**. About remains optional overview, never prerequisite for correctly entering a report. Use the controlled Perform and Report Setup Work SOP as the reference for actual steps.
- Validate required inputs with **specific field-level correction messages**, retaining entered values and showing exactly what needs attention rather than a generic submission error. Do not force a 100% complete report or invent time/crew numbers.
- In historical missing-report notifications, link to the exact protected occurrence and a short Report Work walkthrough; Manager contact instruction for a workday when no work occurred. Do not auto-clear missing history because an annual task was later marked complete.
- Preserve existing supported historical Report Work/Correct report split, no duplicate reports, authorization, actual-work-date semantics and #122 scheduling handoff.

**Operator acceptance — Randy as suggested first-time usability tester:** Present a realistic historical missing-report example, a partial task requiring Minutes, a 100%-complete task, and a no-work/incorrect-report situation. Without coaching, Randy should be able to find the exact assignment, enter actual date, crew size, Hours **and Minutes**, percentage and what remains, save, and verify Progress history. Confirm that he can find help at the point of need and distinguish when to ask a Manager instead of saving invented data. Record each stumbling point as an acceptance finding. Greg's proposed heuristic “if Randy understands it, others should” is a practical pilot gate, not a claim of universal accessibility; subsequently verify on the real field tablet and with intended operators.

**Status:** engineering requirement and acceptance gate, not a tested correction. #175/#132 own the reporting surface; #205 consumes/reporting accountability, #122 owns integration. PR #394 must not silently broaden into a redesign; coordinate a bounded reporting UI candidate and reconcile shared changes before release.

## October 15 release sequencing decision — Production before Randy field feedback

Greg explicitly directs that Randy **not** be pulled from current park Setup for a prolonged pre-release design review. Revise earlier “Randy first-time usability tester” language as follows: **Randy's usability feedback is a POST-DEPLOYMENT field-feedback activity, not an acceptance prerequisite for this bounded release.** Do not interpret this as a waiver of #122's automated, disposable, protected browser, CLEAN EXIT, exact-candidate or Greg approval gates. Technical acceptance remains mandatory; Greg reviews/approves deployment, then Randy can use the new controls during his normal work and suggest refinements. Do not claim Production authorization for an untested candidate.

**Bounded first release target:** reliable on-screen global Setup KPIs/action queues, correct overdue versus partial/reporting semantics, clearer Report Work Crew size/Hours/**Minutes** and concise field-adjacent help. Preserve established workflow/persistence. Email sender/recipient/scheduler/digest infrastructure is a separately accepted subsequent slice if not fully tested in time; do not hold the first operational improvements hostage to it. Deep links should only ship when verified. Every unfinished item remains explicit in this contract and #205. Avoid new design meetings or broad redesign. Do not use sample query results as live status.


## October 15 release scope correction — mandatory email and Container Empty training

Greg explicitly rejects deferring daily email workflows: **daily Manager digest and targeted Captain overdue-report reminders are mandatory deliverables**. Earlier provisional wording saying mail might follow a later first-screen release is superseded. Do not declare the accountability release complete without verified outbound Manager and Captain email, eligible recipient resolution, secure assignment links, delivery error/audit handling and a daily schedule. Captains without authorized organizational addresses escalate to Managers. Email contents must include the actual simple step-by-step Report Work SOP, including no-work Manager escalation, not fabricated reports. Do not claim the service exists today; still requires technical implementation, test, documented runner and separate activation approval.

**Additional launch-critical operator gap — #88 Record Location / Container Empty:** the field process was intended to capture where a Container was placed, whether it remained loaded, and what Displays were unloaded. People do not understand the sequence. The #88 guided reconciliation authority is `Setup/Acceptance/Setup_88_Contents_Reconciliation_Candidate.md` with draft PR #309, not a verified current Production release. Its definitions:
- Choose **Empty** when the physical Container has nothing left; reconcile last recorded contents against the **prior** observation; Return Empty uses canonical Home without Workshop GPS.
- Choose **Not Empty** when it still contains Displays. Either affirm all last recorded Displays remain; select remaining **human Display Names** (unselected inferred at prior observation); or flag unknown contents. The special explicit physical HERE unload flow is distinct and names/groups are verified at this stop.
- Choose **Not Sure** when unable to identify; record location and flag uncertainty without guessing physical detaches.
- A Container with zero recorded Display count is not automatically physically empty. Standalone/singular Display-Pallet restrictions, special trailer partial unloads, offline checks and guarded history remain.

**Mandatory next steps for #88 separate from #205:**
1. Read actual Production deployment identity and current installed Record Location controls before writing instructions that imply features are live. Reconcile current main and open #309 against #122; do not deploy a stale branch.
2. Establish a short **in-app task-context Help** flow (scan Container → confirm location → choose Empty/Not Empty/Not Sure → select named remaining Displays when needed → review HERE vs PRIOR meaning → save → confirm result; Return Empty at actual Home). Wording must match installed controls and be readable by an untrained crew member. Link the authoritative, maintained operator SOP; no second standalone help source.
3. Verify protected browser and physical Android/Zebra operation on a governed disposable candidate, including ambiguous partial unloads and Manager review. Do not auto-update physical state from vague human answers.
4. Preserve #88 movement ownership and #122 release authority; no redesign of #206 Pick List from this need.

**Prioritization:** #205 whole-Setup KPI plus two daily mail audiences AND #88 practical Container Empty assistance are operational requirements; maintain coherent separate implementation/acceptance gates rather than hiding missing items behind the candidate PR. Production modifications remain unauthorized until governed review and explicit approval.


## Captain email transparency, unmapped assignments and iPhone usability — October 15

**Operator clarification:** Managers must not be surprised by Captain email escalation. Each daily Manager digest must explicitly report which Captain reminders were attempted, accepted by the mail provider, failed, suppressed, or not eligible, together with the corresponding outstanding assignment(s). A message accepted by a provider is **not proof of inbox delivery, reading, or task completion**. Never label a merely queued message as delivered. Manager summary must distinguish:
- **Captain assigned + verified active sheboyganlights.org email:** eligible for Captain reminder; show recipient name/organizational address as authorized, original assignment ID/date, attempt timestamp and provider status, and Manager-visible follow-up state.
- **Captain TBD / missing crew Captain assignment:** no Captain recipient; prominent Manager-only action to identify/assign responsibility, without guessing.
- **Named Captain lacking a verified organizational address or app authorization:** Manager-only action to resolve identity/access or contact through approved channels; no automatic email to a personal address.
- **Mail attempt failed or address rejected:** Manager-visible delivery failure, retry policy, and unresolved reporting obligation, not a silent success.
- **Report subsequently entered:** mark reporting exception resolved from authoritative progress evidence, not from message-open status; preserve notification history and original scheduling evidence.

Manager digest should contain a concise **Captain reminder ledger** (sent/accepted, failed, not sent: TBD, not sent: no eligible organizational account), counts plus exact task/date/Captain drilldowns. Captain reminder itself contains only that Captain's own outstanding work and simple step-by-step Report Work directions. Prevent accidental send to an unrelated person with a similar name. Use identity/person reference and governed Setup Manager access; investigate recipient/transport audit persistence before implementation. Do not invent database tables or provider delivery guarantees without design approval.

**iPhone/Safari field defect risk:** Greg does not have an iPhone test device, and iPhone users report more difficulty than Android users. Do not assume Android/desktop acceptance proves iOS behavior. Record specific reproduced failures before asserting causes. Candidate review must cover mobile Safari on iPhone for email deep links through MSB/Cloudflare authentication, Captain selection/historical day reveal, scroll/focus, Report Work input visibility and numeric keyboards (especially **Minutes**), validation, saving, help controls, and Return Empty/Not Empty/Not Sure on Record Location as applicable. Account for in-app mail browsers, session redirect and back navigation without losing unsaved data. Check responsive touch targets, visible labels, keyboard overlays and viewport behavior. Prefer existing test-device access or a coordinated real-iPhone operator validation; don't require Greg to purchase a device or claim simulator tests equal physical-device proof. If an exact iOS defect cannot yet be reproduced, track it explicitly and do not block unrelated technically safe fixes indefinitely—separate the device-acceptance risk and follow the #122 release decision.

**Acceptance:** Manager can answer *who was reminded, who was not eligible, why, and what remains unreported* from one protected dashboard/digest. Capture authorized test evidence for eligible, TBD, no organizational email, provider failure, late report after reminder, rerun idempotence and a real iPhone reporting/navigation trial. No production email sending or device testing is claimed by this documentation change.


## Notification suppression: completed Report Work — explicit acceptance rule

**Greg's October 15 directive:** **If the applicable scheduled assignment has a valid saved Report Work submission marking the work 100% complete, send NO missing-report email to its Captain or Managers for that resolved occurrence.** The general daily Manager digest may still include other unresolved assignments, tasks and blockers; it must not falsely list this resolved occurrence as missing or request the Captain report it again.

Evaluate authoritative progress evidence **immediately before constructing/sending** reminders, not just from a stale snapshot. Matching must use the canonical assignment identity plus the established legacy workday/task/shift fallback; ensure report correction has been applied and no superseded/invalid evidence is mistaken for the current result. A valid report at less than 100% also satisfies that occurrence's *reporting* obligation and must not trigger a **missing-report** email; it may instead produce a distinct Manager **unfinished/no continuation** action. An annual 100% task without a report for a separate historical assignment does not automatically assert that the other occurrence was reported: reconcile that historical evidence separately to prevent duplicate/false reminders.

The Manager's notification ledger must distinguish **resolved before send (suppressed)** from **actually sent**. Do not deliver a Captain reminder merely because it was queued before a 100% report arrived. Once 100% is confirmed and saved, no more reminders for that resolved reporting obligation; do not equate work completion with historical notification delivery.

Mandatory tests: report saved at 100% before daily batch; report corrected to 100%; report submitted while digest is queued; reported partial on that occurrence; multiple assignments for the same annual task; undated or mismatched reports; manager digest suppresses resolved item but retains unrelated open items. Production email activation remains unapproved.


## Manual early reminder from Perform Work — October 15 decision

Managers require a **Request Report** action on a past scheduled assignment with no valid work report, available directly in **Perform Work**, without waiting for the automatic 4:00 AM America/Chicago digest. The request is a Manager-only communication action, not an edit to the historical assignment or task completion.

- Recheck canonical occurrence reporting evidence and current Manager authorization immediately before sending. Disable/remove action if a valid report exists (partial or 100%); no false missing-report email.
- Show human task name, original workday, shift/crew and mapped Captain, verified `@sheboyganlights.org` destination, and a brief confirmation before sending. If Captain TBD, no verified organizational email, or access mismatch, do not send; show Manager-only follow-up needed.
- Send an exact occurrence-based, protected Report Work link and plain-language instructions from the controlled operator SOP. No report should ever be fabricated automatically.
- Persist Manager requester, request time, occurrence, recipient identity, provider acceptance/failure and next action in the same authoritative notification audit used by the 4:00 AM job. Display it in Manager notification history.
- Avoid duplicate Captain mail: one consolidated reminder per Captain/day covering unresolved occurrences; if a manual request was sent the same local calendar day, the 4:00 AM batch does not duplicate that Captain/occurrence reminder. Recheck outstanding occurrences in case reports arrived meanwhile.
- Manual request does not resolve the issue; only authoritative saved reporting evidence or a separately governed Manager historical disposition can resolve it.
- Test repeated button clicks, simultaneous Managers, retries/provider failure, partial/100% report just before send, multiple assignments, Captain identity missing, and timezone-day rollover; keep protected UI authorization and idempotent provider send semantics.

Status: **approved requirement only**. The Request Report button, notification backend, outbox/audit and scheduler are not yet implemented or deployed. Preserve #205/#132/#122 ownership and run governed acceptance before Production activation.


## Dedicated Setup Action Center and self-email — October 15 clarification

**Operator direction:** Provide a separate protected **Setup Action Center** landing page for Manager reporting accountability, rather than burdening Perform Work with the full notification ledger. Retain a discoverable contextual link from Perform Work/Plan-Schedule to the Action Center, preserving the current task/assignment when supplied. This is a focused Manager operational surface, not a competing Scheduling Board or another reporting database.

Sections: historical missing reports (with original assignment and Captain), incomplete work needing rescheduling, upcoming blocked/NOT READY assignments, Captain TBD/no eligible organizational address, and Manager-visible email history (queued/accepted/failed/suppressed). Allow Managers to select missing-report occurrences and request reminder emails subject to existing send-time, deduplication, report-state and access checks. Include a preview of the daily 4:00 AM Manager digest.

**Email report to myself:** The authenticated Manager may generate and email the *current Manager Action Center digest* solely to their own verified MSB organizational email. This is a safe preview/copy and may be used for testing and training, but must not send Captain reminders, suppress future real alerts, resolve exceptions, reset the daily scheduler, or be mistaken for provider delivery proof. The preview/self-send must be clearly differentiated from **Send Captain reminders** and from the automatic daily digest in the UI and audit. No arbitrary recipient input; no emailing protected data to a personal account. Preserve link access authorization and avoid duplicate notifications from double clicks.

**Acceptance:** protected page is navigable and understandable on mobile; sections link to exact assignments/Manager actions; self-email to signed-in Manager only; Captain dispatch requires explicit action; delivery ledger distinguishes self-copies, daily digests and Captain reminders; fresh source check before dispatch; no effects on work reports, annual task completion or physical movements. Daily Manager/Captain notifications remain mandatory; this landing page does not replace them.

**Status:** Engineering requirement, not implemented or authorized for Production.


## Navigation defect — Back unexpectedly exits Setup (October 15)

Greg reports inconsistent page-to-page navigation: using Back sometimes takes the operator out of Setup entirely. This is an active field usability defect, not merely an instruction deficiency. Identify whether the failure concerns browser-history Back, application-provided Back controls, or both; reproduce rather than assuming cause.

**Required behavior:** Navigating among Plan / Schedule, Perform Work, Report Work, Setup Action Center, Record Location, Pick List and related Setup detail views must provide a consistent, discoverable route back to the previous relevant Setup screen without unexpectedly leaving the application. A direct email deep link with no in-app predecessor must have an explicit safe **Return to Setup** destination rather than relying on browser history. Preserve selected year, Captain filter and relevant assignment/task context where safely supported, while respecting authentication/access gates. Do not silently lose unsaved work in forms. Explicit external navigation remains permitted when deliberately selected.

**Engineering reconnaissance/acceptance:** Inventory existing links/routes/history push/replace behavior, buttons labeled Back/Return, history popstate handling, direct-link paths and authentication redirects. Test repeated page transitions, reload, first-entry deep link, browser Back/Forward, iPhone Safari including mail-in-app browser, Android Chrome, desktop, expired sessions, collapsed-day reveal and unsaved Report Work forms. Avoid blindly calling `history.back()` without a verified Setup predecessor. Do not replace the existing site-wide navigation or redesign the internal-web portal; application owns safe internal navigation.

**Status:** reported operator defect/acceptance requirement only. No root cause verified, code fix, browser acceptance or deployment is claimed. Cross-screen navigation implementation should be reconciled under #122 with the owning Setup application surfaces; PR #394 consumes this contract for its new Action Center and KPI links.


## DBG — 2026-10-15 Perform Work missing assignment cards (urgent, launch-blocking)

Greg's protected browser screenshot `image(20261015-155223).png` shows **Client V0.3.62** in its header, day 13 and 14 past-work summaries, red no-report banners, crew/shift labels and green linear-hours workload panels, **but no visible individual task cards / Report Work buttons between crew workload panels and the next shift/day**. Operator reports that Perform Work has lost access to reporting. This is a launch-blocking operator defect and needs isolated immediate verification/correction ahead of extended KPI, notification or navigation enhancements.

**Version discrepancy:** separately accepted PR #391 scheduled-search change is documented as V0.3.65. The screenshot is **V0.3.62**, so do **not** infer that PR #391 caused this or assume current main is deployed in the screenshot. Verify actual host Setup source/version, browser HTTP/cache/asset identities and location of screenshot (Production vs other context) through authorized read-only evidence. Preserve #122 deployment ledger and runbook.

**Source facts:** current `setup_next_pass.js` still has `nextPerformAssignmentCard` with a `next-report-work` button. `renderNextExecution` scopes assignments using `nextPerformCaptainScopedAssignments` and `nextFilterPerformAssignments` (Show completed off hides occurrence with `work_report_count>0`) before grouping by day/shift/crew and mapping `crewItems.map(nextPerformAssignmentCard)`. The day-level workload summary can coexist with a filtered assignment population and is NOT proof the cards are rendered/visible. Need DOM/JS and actual browser reproduction to distinguish absent data, filter hiding, HTML structure and CSS visibility. Use actual effective Captain selection and Show completed state in the screenshot.

**Mandatory targeted checks:**
1. Identify actual Production version+SHA (server and served asset), browser version, query params/cache; do not downgrade or alter Production to debug.
2. With known affected unreported assignment #41/#103/#104/#145/#153 from October 14, compare API scheduling-board assignments/report counts vs Perform Work filtered assignment list. Verify ALL Captains and target Captain scope plus Show completed off/on. Never assume annual `COMPLETE` = historical occurrence reported.
3. Inspect DOM: `.next-perform-assignment` existence, visibility, parent `hidden`, CSS computed display, shift grouping, malformed nesting, delegated button listeners, console/network failures and keyboard access. Specifically test a past unreported assignment and a future unworked assignment.
4. Reproduce exact broken behavior against deployed/previous accepted SHA and candidate with focused regression. Restore individual assignment cards and actual Report Work initiation without changing reports, PostgreSQL, annual state, crew assignments or scheduling; no broad redesign.
5. Add a regression asserting named assignment cards appear underneath AM/PM crew workload banners with Report Work action usable, including mixed past reported/unreported workdays, Captain filter and Show completed, explicit historical day collapse behavior.
6. Governing #122 runbook: full affected regression, single current-Production disposable browser review (port 8898, CLEAN EXIT), Greg authorization, then controlled source-only release with an exact version/commit and health verification.

**No root cause yet established** and no remediation performed by this documentation entry. Randy PR #391 cannot be designated responsible merely because its time coincided. Separate this hotfix from broader unaccepted PR #394 KPI scope; preserve other working source/branch changes.


## DBG follow-up — refresh restores visible assignment cards (Oct 15)

Greg refreshed Perform Work after screenshot `image(20261015-155223).png` (Client V0.3.62, crew/workload summaries visible but no individual task cards). Follow-up screenshot `image(20261015-155502).png` now shows **Client V0.3.65**, visible assignment cards for the Oct14 late `Place Polar Express Engine` and Oct16 scheduled tasks, including 4.5/3.0 linear-hours overload. Thus **missing cards is not reproduced after refresh**; no verified evidence that PR391 removed the card renderer. Suspected stale browser assets / mismatched client version; cause remains unproven until cache/loading/version chain is inspected. Do not implement a speculative reporting-code rollback.

Acceptance still requires expanding a visible task and verifying **Report Work** actually opens, plus hard-refresh, stale-tab, navigation-return, and iPhone Safari checks. Investigate whether server/client source identity, asset caching or stale open tabs can leave old code running without an update/reload prompt. A readable version-mismatch/reload warning may be needed, but do not add one without inspecting existing dirty-edit/version protection. No Production change or root-cause assertion from screenshots alone.

## Manager roster change and required next implementation gate — October 15

Greg is adding **Don Martens** as a Setup Manager while the operational corrections are in development. Do not modify personnel, group membership, email accounts, or roles as part of this engineering note; Greg owns the current role addition. **Manager digest recipients must be selected dynamically from current authorized Setup Manager identities at send time**, resolving verified active organizational email and access status through the governed identity source. No hardcoded Greg/Tom/Don list and no assumption that merely creating a person record grants Manager privileges. Once Don's Manager authorization and eligible organizational email are verified by the notification service, he must be included without a code change.

Testing must cover Manager added after job configuration, Manager removed/revoked, missing mailbox, duplicates, disabled identity and permissions at job execution; fail closed and log recipients/not-eligible outcomes without leaking other Manager or Captain data. The self-email target must be the signed-in verified Manager only. Manager notifications must identify sent/failed/suppressed Captain reminders. No mail activation until the authoritative recipient source, existing transport, scheduling and idempotent audit are demonstrated in disposable/browser acceptance.

**Work remains open:** PR #394 presently implements a draft UI-only KPI calculation, not an accepted release, Manager email service, Captain email service, Action Center or Report Work help. Document this distinction in the release checklist and do not treat these additions as complete solely because they appear in engineering notes. The stale-browser false alarm (V0.3.62→V0.3.65 refresh) is closed as an observed local issue; no rollback should be introduced.

## October 15 scope correction — Container Locate split from #205

Greg confirms discussion with Tom exposed additional operational problems in **Container Locate / Record Location / Container Empty**. These are a **separate launch debug under commanding issue #122**, with implementation ownership under **#88**. **Do not implement Container Locate workflow, Empty/Not Empty/Not Sure controls, or their operator help as part of KPI/email PR #394.** Earlier cross-system observations in this document are background/dependency evidence only, not #205 implementation requirements. Preserve all facts already recorded, but move detailed investigation and acceptance to the #88 controlled engineering authority and the #122 launch-debug checklist. Tom's exact findings have not yet been supplied; do not invent defects or corrective logic. #205 remains focused on KPI, schedule credibility, reporting usability, Action Center, Manager/Captain notifications and navigation within those screens.

## October 15 bounded source implementation — Report Work field clarity

On PR #394's isolated branch, the **existing** `setup_next_pass.js` Report Work form now visibly distinguishes Actual crew size, Hours worked, Minutes worked and whole-task % complete, with numeric inputmode and contextual hints. The prior default `value="0"` for Minutes was removed to require deliberate entry; existing required validation and `submitNextProgress` persistence path are preserved. `setup_next_pass.css` adds high-contrast, minimum 44px input targets, distinct Minutes styling and two-column mobile layout. A focused source-regression test is in `Setup/Application/test_132_report_work_visibility_candidate.py`. Two changed JS/CSS files were read back from the branch; JS syntax parsed and targeted source assertions passed in connector V8 on 2026-10-15.

**Not accepted:** pytest/full Setup suite not yet run, shared HTML asset pins/release version not advanced, real form/browser/Android/iPhone checks not performed, source-only deployment not performed. This bounded #132/#175 implementation is subordinate to #122 acceptance; remaining #205 Action Center and Manager/Captain mail backend are unimplemented and must not be presented as shipped.

## Report Work date error prevention and correction — October 15

Greg reports having personally recorded hours against the wrong date because the date is easily missed. **Read the live behavior carefully:** the current `loadNextTaskExecution` initializes `next-performed-on` from the scheduled workday (`day.work_date` / `assignment.work_date`), not necessarily today's date. The user's observed default may result from a particular entry path or UI version; do not rewrite that fact as a confirmed today-default defect. Actual `performed_on` may differ from either.

**Bounded required correction:** prominently label and visually distinguish **Date work actually happened**, show scheduled assignment date separately, and require an explicit date confirmation on Save Work Report with both dates visible. This must preserve all entered values when the confirmation is declined and must not silently substitute today's or scheduled date. Manager `Correct report` already exists in current source, including `performed_on` PATCH to the original progress record; ensure this correction can be found from the task's Progress history, verify permission and actual ability to save it in a protected browser, and add short field-level guidance for asking a Manager rather than claiming no correction is possible.

**Regression acceptance:** scheduled vs actual mismatch; same-day correct report; late-entered report; iPhone date control; confirmation cancel; Manager correct existing report without duplicate; persisted corrected date reflected in history and historical KPI. Avoid new schema or backfill without evidence. No Production mutation authorized.


## Notification transport verified as existing capability; email appearance reviewed before activation

Greg confirms MSB already successfully uses email for **Work Order Intake triage** and **Work Order assignment**. Controlled Work Order engineering documentation names Directus Flows `WOI Request Triage Email` and `Work Order Email Assignees`. This proves a working **existing email capability**, NOT that the Setup daily-scheduler/digest or its recipient/query/send/audit contract already exists. Reuse the documented Directus mail infrastructure after inspecting its current Flow configuration and safe host-to-Directus invocation. Do not fabricate Work Orders/Intake rows or disrupt their existing event triggers merely to emit Setup reminders.

**Acceptance sequencing clarified by Greg:** implement/test Manager and Captain send paths using controlled recipient/test data; permit **Email to Myself** to the signed-in authorized Manager; review actual rendered email formatting, human task names, secure links, and novice instructions with Greg **when ready**, before enabling unattended 4:00 AM delivery. Do not require a new discussion of SMTP infrastructure or separate provider without evidence it is needed. Keep test sends distinct from production digests and preserve send audit, no-duplicate and completed-report suppression rules. Manager recipient membership remains dynamic from People (including Don after authorization verification).


## THREAD RESTART CHECKPOINT — 2026-10-15 18:20 CDT — NOT TEST READY

**Use this as the next-thread starting point.** The controlled engineering document (this file) is authoritative; conversation and PR descriptions are not specifications. Greg has explicitly authorized continuing engineering and wants a *tested browser candidate* urgently. Do not ask to revisit settled requirements or imply background work continues after the chat stops.

### Identity and authority

- Repository: `Gregovate/MSB-Production-Database-Project`; commanding #122, implementing #205; #132/#175 own Report Work.
- Draft PR: [#394](https://github.com/Gregovate/MSB-Production-Database-Project/pull/394); branch `fix/205-setup-deadline-kpis-20261015`; checked source HEAD **`b7aeb979ee7469f278a0ab9e18cc93457bc36c00`** before this documentation commit. Determine NEW exact HEAD after checkpoint commit.
- Baseline comparison checked earlier: main additions were People/Identity documentation with no direct source-file overlap. **Refresh main again at restart**; inspect actual changed paths and reconcile concurrent edits without overwriting GIS or People work. Do not use stale commit count as evidence of code conflict.
- Controlled engineering source: this file, linked from the Setup engineering README; linked Report Work operator SOP contains simple missed-report steps. Release runbooks and governed 8898 same-clone disposable/browser flow remain under #122.
- Container Locate / Empty operational problems reported by Tom are explicitly **separate #122 debug/#88**, not KPI PR #394. Stale browser V0.3.62 missing cards resolved by refresh to V0.3.65; no reporting rollback.

### Verified operator data — not a fresh live status

- October 15 09:06 CDT read-only PostgreSQL, `msb`, session 2, 2026: 294 included annual tasks, 72 `COMPLETE`, 222 not complete, 13 `IN_PROGRESS`, 0 deferred.
- 8 past scheduled assignments missing reports; 13 in-progress tasks with zero current/future dated assignments in operator Q7 (the UI showed 12 needs rescheduling; authoritative `unworked_assignment_count` reconciliation is required). Q8 identified 55 not-ready and/or WO-gated unfinished tasks—not all imminent blockers.
- Completion report entry date differs from workday in many rows and `actual_completed_at` was blank in returned completed records. **Current draft KPI forecast cannot claim on-track**; need unique annual task completion evidence by real `performed_on` / workday, rather than `recorded_at`.
- Calendar/workday future averages, excluding Sundays only for potential capacity, were added in source. Rolling future scheduled days are not the full workday capacity calendar.

### Current implementation — source committed, NOT accepted

- `Setup/Application/setup_next_pass.js`: shared `setup205DeadlineKpiModel` and `setup205DeadlineKpiHtml`, render in Perform Work; totals, readiness, scheduled/rescheduling, no-report/partial lists and tentative calendar/potential-workday pace. `setup_scheduling_board.js` renders the shared KPI. Review classifiers against contract before treating counts as reliable.
- Report Work source corrected: prominent actual crew size, Hours, **Minutes**, percent; Minutes no longer quietly defaults to zero; high contrast and mobile styles in `setup_next_pass.css`.
- Date field now labeled **Date work actually happened**, scheduled date shown separately, and Save Work Report asks explicit date confirmation after validation. Existing Manager `Correct report` PATCH path was discovered; verify actual browser operation, including completed tasks and report correction.
- Source tests created/updated: `test_205_deadline_action_kpis.cjs` and `test_132_report_work_visibility_candidate.py`. Connector V8 parsing and focused source assertions passed; **full pytest/Node regressions have NOT run** and the protected disposable browser is **NOT started**. Tests newly added in last commit `b7aeb979` were committed but not full-suite executed.
- No release version/HTML asset pin finalization, no browser `BROWSER REVIEW READY`, no CLEAN EXIT, no Greg Production approval, no Production deployment.

### Major unfinished implementation (do not claim otherwise)

1. Protected **Manager Setup Action Center** page with data API sourced from authoritative annual task/assignment/report classifications; actionable lists, Captain TBD/organizational-email exceptions, rescheduling/readiness, notification status, secure exact-assignment deep links, safe self-email.
2. **Daily 4:00 AM America/Chicago** Manager digest and eligible Captain reminders. Reuse existing Directus email transport demonstrated for Work Order Triage and Work Order assignment; do not invent a second SMTP stack or trigger fake Work Orders. Sender orchestration, dynamic authorized Manager recipients (including Don Martens when verified in People), verified Captain organization email matching, idempotence, audit/provider error and retry are not implemented.
3. **Manager Request Report** immediate action, deduplicated against daily sends. If an occurrence has ANY valid report, including partial/100%, suppress **missing-report** reminders. Separate incomplete/no continuation Manager attention stays. No automatic personal email, no duplicate work report, no email for Captain TBD or missing eligible organization account. Self-email is to authenticated Manager only, without Captain side effects.
4. Completion-date data trust, reliable forecast, historical reporting correction/disposition, missing-report classification under actual worked/scheduled evidence and direct-action links.
5. Contextual `?` help and consistency, operator navigation/back safeguards, device/iPhone Safari acceptance. No broad app redesign. Any unknown iPhone defect must be reproduced before asserting cause.

### Next engineering execution — do not substitute discussion

1. Refresh current `main`, review #122 latest release checkpoint, #205 and changed-files overlap; reconcile PR #394 deliberately, preserve unrelated GIS/People branches/worktrees and current accepted #391 search behavior.
2. Complete the missing Action Center and mail backend **against this controlled contract**. Inspect actual Directus Flow/identity runtime contract before mail integration. Keep outward sending **disabled by default**, and use authorized test recipients for test dispatch; don't activate 4 AM job or send mass emails prior to Greg's actual email format approval.
3. Repair KPI completion-date logic from authoritative workday/actual performed-on evidence; ensure one completion per annual task, no false green; compare actual SQL and both screens.
4. Execute focused and full Setup regressions, publish exact source SHA/version+asset pins, then existing one-clone 8898 disposable/browser acceptance under #122 with Greg. Test Randy after release at Greg's direction, not as a prerequisite.
5. Prepare exact release approval and governed Production installation only after all gates pass. Record tested/deployed identities in controlled documentation, then close out.

**Status at checkpoint:** still substantial unimplemented functionality. Don't tell Greg this is ready to test or that you will keep working in the background. The original operator priority is working software and email tests, not additional specification debate.

## October 15 resumed engineering — draft PR #394 remains NOT TEST READY

The resumed #205 implementation is deliberately on the existing draft branch, subordinate to #122, and does **not** authorize email dispatch, migration, Production mutation, or deployment. Current `main` was refreshed against commit `6122d7923c2a07eb6b278225cf71cafc4704d349`: newer People/Identity and reusable-preview tooling were identified; no affected Setup KPI application-source overlap was identified. Retain their changes and all GIS work when integrating the branch.

New source work after the 18:20 checkpoint:
- Scheduling Board PostgreSQL projection derives `completion_work_date` and `completion_date_source` from 100%-marked actual `ops.setup_task_progress.performed_on` evidence or a completed linked Work Order. Existing `actual_completed_at` remains visible but is **not substituted** for the reported physical work date; no Production backfill has been performed. One effective-complete annual task can contribute only once to a 7-day pace. Unverified, future-dated, or low-sample completion evidence cannot give a green forecast.
- A missed historical assignment no longer counts as a current/future continuation merely because it remains `unworked`. Existing Chicago-local date and canceled-day semantics are applied. Day View filters are now explicitly labeled **Days needing reports** / **Fully reported days**; these are day-level filters.
- Whole-Setup KPIs moved above secondary Perform Work labor data. Both Schedule and Perform Work expose the same Manager-gated Action Center with original missing-report occurrences, incomplete work needing continuation, imminent readiness exceptions, and Captain TBD. UI action links consume existing guarded Setup navigation and in-app report/schedule dialogs; exact navigation requires browser proof.
- Report Work actual date, crew, Hours, Minutes, percent, explicit save-date confirmation and existing Manager progress correction remain in the draft. A stale source test expecting the superseded date label was corrected.
- Manager digest and Captain training **wording previews** are present in the Manager Action Center, marked **NO EMAIL SENT**. They are not a notification service, auditable send path, live recipient eligibility check, automatic 04:00 schedule, or direct authenticated assignment email link. Existing Directus `WOI Request Triage Email` and `Work Order Email Assignees` flows remain untouched; their Work Order-specific event triggers must not be repurposed.

Evidence to date: connector V8 JavaScript parse and executable shared classifier/Action Center regression fixture PASS, focused static Report Work/source checks PASS. No local full Python suite, remote GitHub CI PASS, Production-clone reconciliation, disposable acceptance, browser `BROWSER REVIEW READY`, operator review, or `CLEAN EXIT` is claimed. A PR-scoped full Setup and FieldWiring GitHub Actions workflow has been committed; record its actual result separately.

**Open release gates:** (1) integrate a protected Setup-specific Directus mail trigger and durable idempotent send/delivery/error audit using verified current runtime/config; (2) dynamic eligible Manager/Captain recipient resolution and exact-assignment links plus authorized self-email/test send; (3) compare live-clone 2026 `effective_complete` and completion `performed_on` row IDs, the observed 12/13 continuation discrepancy, eight no-report occurrences and independent hard/soft readiness; (4) exact final version/client asset pins/footer, full Setup/FieldWiring regression; (5) current-Production one-clone browser review on 8898 with CLEAN EXIT and Greg acceptance. **Production remains unchanged by this source work.**

### Integrated source regression outcome — October 15, 18:40 CDT

The first exact PR GitHub CI run #38824813269 failed with five hard-coded historical source-contract assertions (continuation counted `unworked` instead of current/future, and legacy day labels). No application exception was identified from these five. After updating the owning assertions to the approved #205 semantics, the next integrated GitHub Actions run #38824971449 on source commit `12ddd455e56bda4cad2aabc9a1a2925d66952896` passed:

- full Setup/Application suite **779 passed**;
- full FieldWiring/Application suite **202 passed**; and
- executable Node shared #205 KPI classifier, provenance and Manager Action Center tests **PASS**.

This is CI source regression only, not a PostgreSQL-clone/Production-browser test. A passing merge-ref CI checkout does not assert Production has been upgraded. The draft's browser/runtime version remains the previously accepted V0.3.65 until a final candidate is pinned and tested. The 04:00 daily email dispatcher, self-send, actual delivery audit and recipient eligibility are **not** implemented/accepted. Do not check any Production readiness box.

## October 15 Directus Flow implementation continuation — candidate, unactivated

Greg authorized the engineering approach: reuse the existing **Directus mail service** by adding a dedicated Setup notification trigger rather than treating notifications as Work Orders or introducing a second SMTP stack. Current Directus documentation confirms `items.create` Event Hook Flows and Send Email operations. Incoming webhook triggers are public by design, so this design **does not use a webhook trigger**.

**Implemented in draft PR #394, source only:**

1. Proposed migration **074** adds restricted `public.setup_notification_outbox`, canonical per-recipient/day `message_key`, validated real current Person↔active Google Directus authorization, immutable recipient/body, and atomic `setup_notification_coverage` unique on Chicago operational date + recipient Person + original assignment. An inserted record is only `QUEUED`, never falsely marked delivered.
2. New `setup_notification_service.py` creates consolidated Manager and per-Captain plans from current 2026 board/report evidence, reevaluates Manager eligibility on each dispatch, excludes stale/invalid/inactive/nonorganizational recipients, suppresses reportful/cancelled/future assignments, and omits already-covered reminders. Delivery uses only a dedicated authenticated, local-loopback Directus **Items API** on `setup_notification_outbox`; no fake Work Order Intake, no SMTP client, no publicly callable webhook.
3. New protected `setup_notification_api.py` exposes Manager-only preview, test-send **Email to Myself** for the signed-in verified Manager only, and targeted Manager **Request Report** for an original missing-report occurrence. Outbound self-test, request and daily queue permissions are *separately disabled* unless `SETUP_NOTIFICATION_TEST_SEND_ENABLED`, `SETUP_NOTIFICATION_REQUEST_SEND_ENABLED`, or `SETUP_NOTIFICATION_DAILY_ENABLED` is explicitly set to `1` respectively.
4. `setup_205_daily_notifications.py` is a runnable dry-run/queue entrypoint but **not installed** as the accepted 4:00 AM America/Chicago scheduler. The scheduled server runner remains a Server Management integration/authorization gate.
5. Controlled [Directus notification engineering handoff](Setup_205_Directus_Notification_Transport_2026-10-15.md), read-only `setup_205_directus_mail_flow_recon_readonly.sql`, and rollback-only `setup_205_notification_outbox_disposable_validation.sql` provide installation and acceptance authority. Actual Directus Event Hook flow options, Send Email operation and success/failure delivery audit must be reconciled against the installed runtime and provisioned inactive for disposable tests **before** activation.

**Latest isolated source evidence:** [GitHub Actions run #38826902283](https://github.com/Gregovate/MSB-Production-Database-Project/actions/runs/38826902283) at source `c3b5f4c037f76d829280f2f83575e73d1c031138`: 795 Setup tests PASS, 202 FieldWiring PASS, shared Node #205 PASS. Later documentation-only commit does not change tested application behavior. These tests include synthetic Manager/Captain separation and cross-path suppression; they **do not execute migration 074 against real PostgreSQL or send email through Directus**.

**Still mandatory:** installed Directus mail-flow reconnaissance and inactive new Flow configuration, clone migration 074 and security SQL acceptance, actual authenticated Send Email + failure/delivery report, Manager self-email format approval, Captain privacy, exact-record browser deep links, source/client version+asset pin and full #122 one-clone 8898 browser review/CLEAN EXIT. No 4:00 AM task enabled, no Production migration or runtime change, and no Production readiness claim.

## October 15 operational priority reset — email implementation PAUSED

At Greg's explicit direction, stop notification work and **prioritize working Setup operations**. The unaccepted Directus mail bridge, candidate migration 074, sender/outbox APIs, scheduler and related mail-only documentation are preserved only on `hold/205-directus-notifications-20261015`; additive source commit `36577e82e4269aac427eda43bbe836ec36f1d3a7` removed them from PR #394 without rewriting history or touching Production. No 4:00 AM job or test send.

Current actionable application candidate: `V0.3.66-setup-action-center`, source `e4ed6ff13d6e16e9d8a6ed5278c1d81ee2d00eaa`, with current `main` People/preview changes explicitly merged via two-parent merge `c411806d50bd7388edcf5a4313c99d34d1b44ee0`. No GIS or movement work was altered.

**Source verification:** [Actions #38831054784](https://github.com/Gregovate/MSB-Production-Database-Project/actions/runs/38831054784) passed **779 Setup**, **202 FieldWiring**, shared #205 KPI/Action Center and exact delegated navigation Node checks. This now includes visible blocked/task reasons with Manager navigation; original missed Report Work occurrence reveal; true future continuation; active-day Captain TBD; next-seven-day AM/PM/All Day linear-hour overload; both dates confirmed on Report Work save; completed annual-task history guidance; no ambiguous deadline status after November 19; refreshed client/server identity and cache pins.

**Browser and real-data gate remains OPEN:** review [the source-only V0.3.66 exact-candidate handoff](../../../../../Setup/Acceptance/Setup_205_KPI_Action_Center_Disposable_Candidate_2026-10-15.md). Read-only reconcile real 2026 annual effective-completion IDs/dates, previously observed 12 vs 13 needs-continuation discrepancy and 8 no-report occurrences; then current-Production disposable acceptance, single protected 8898 browser/operator review and CLEAN EXIT under #122. **Do not claim Production readiness or mutate live data.**

## October 15/16 — #205 disposable browser SQL bind 500 resolved in source, operator retest pending

Greg's V0.3.66 8898 current-Production-clone browser screenshot exposed a Scheduling Board GET HTTP 500, independently confirmed in the retained Flask log `/tmp/Setup_Disposable_Browser_Preview_Flask_20261016T021107.log`. Flask traced `setup_scheduling_board_repository.py:146` -> `psycopg2` cursor execute -> `IndexError: tuple index out of range`. The parameterized annual-task query included a SQL comment `/* Current 100% work evidence, one date per annual task. */`; psycopg2 processes literal percent markers even inside SQL comments, attempting a second bind with only the one Session ID argument. The fault occurs **before PostgreSQL executes the SELECT**. It is source code, not corruption or an absent migration, and does not justify Production schema/data changes.

Corrected the comment to eliminate the literal percent; retained the real SQL completion predicate and existing WO semantics. Added executable source-contract tests to protect all board parameterized queries against unescaped SQL percent markers. Following the mandatory release identity rule, the materially corrected candidate is `V0.3.67-setup-action-center`, synchronized client/server and cached assets. Strengthened governed Setup disposable-browser runner to read the actual `/api/setup/scheduling-board?season_year=2026` against its cloned database **before** printing READY, report task/workday counts without private data and fail with retained Flask error on HTTP 500. No GIS code, mail sender, Work Order Flow, SQL migration, or Production server change.

**Source PASS:** [Actions #38840185514](https://github.com/Gregovate/MSB-Production-Database-Project/actions/runs/38840185514) at exact application/tooling candidate `dbf4487ac7b94ced7dd5d2f8fd9cb5f69457ee8c`: **790 Setup, 202 FieldWiring, executable Node #205 KPI/navigation**. This includes real GIS preview acceptance and browser preflight script syntax tests. Later docs commits are not application changes.

**Pending, not accepted:** original broken 8898 session is operator-REJECTED. Greg must complete existing foreground preview cleanup and record actual Production-after proof, then fast-forward only the **laptop** isolated `C:\lor\ImportExport\VSCode-205-kpi-review` checkout; run reusable current-Production disposable acceptance and browser preview both pinned to `dbf4487...`, version `V0.3.67-setup-action-center`, `-MigrationPaths @()`. The real clone includes any previously installed accepted migrations; no additional #205 migration is needed. Verify Scheduling Board data, actual completed/remaining counts, 12-vs-13 continuation discrepancy, Report Work and operator browser after reaching READY; require CLEAN EXIT and operator approval before #122 Production release. Controlled [exact handoff](../../../../../Setup/Acceptance/Setup_205_KPI_Action_Center_Disposable_Candidate_2026-10-15.md).

## October 15/16 follow-up — no Crew Save, drop directly onto a workday to create Crew

**Operator decision:** a separate Save button for choosing Captain and AM/PM headcounts is a repeated source of lost work. Existing *Save* behavior is replaced by explicit autosave on Captain/shift-headcount field change (with inline Saving/Saved/Not saved, no silent loss on API failure, serial in-flight saves, and a guarded task drop that waits for an accepted staffing update). Manager authorization, historical work record locks, duplicate-Captain/shift restrictions and short-crew warnings stay intact; the existing audited `ops.update_setup_work_day_crew` function and protected PATCH route are reused.

**Day-first scheduling improvement:** visible AM/PM `Drop here · New Crew` strips precede the long crew list within each day's grid. Drop an unscheduled task on the desired AM/PM strip or selected existing assignment group on the date; protected endpoint creates the crew and places all tasks **atomically** through the existing approved SQL scheduling functions, so failure leaves original assignments and no orphan destination crew. Existing mixed AM/PM assignments retain individual shifts (including when dragged to an existing crew on another workday). Legacy All Day assignments are refused rather than silently reinterpreted. New crew Captain/headcount can be assigned afterward by autosave. This is not yet the requested broader calendar-month view or automatic weather rescheduling.

**Candidate:** `V0.3.68-scheduling-workspace` at exact source SHA `a7572c56d783244dc384a7a4fdb371852c08a241`, draft PR #394. [GitHub regression #38848810539](https://github.com/Gregovate/MSB-Production-Database-Project/actions/runs/38848810539) PASS **803 Setup**, **202 FieldWiring** and Node #205 classifier/action/crew-save/group-drag checks. No new PostgreSQL migration; source has **NOT** passed current-Production disposable/browser approval. The broader October 15 review is still **REJECTED** (1% progress bug, confusing KPIs/Action Center, Report Work layout, field-context HTTP 404, sticky day headers/visibility, feedback/help). Do not deploy or claim Production readiness; mail remains paused.


## OPTIONAL FUTURE CONCEPT — Day-first Setup scheduling and compact completed history (2026-10-15/16 operator review)

**Disposition: DISCUSSION / POSSIBLE IMPROVEMENT ONLY. Not approved implementation, not accepted architecture, and not part of the currently authorized V0.3.68 candidate.** Preserve this option for the next deliberate #205 scheduling design review under #122, rather than losing it in a chat or silently modifying the deployed workflow.

**Operator's original mental model:** Schedule on a **calendar/workday first**; later assign the day's work among Captains, crews and AM/PM shifts. The current Scheduling Board is organized around pre-created crew/shift "buckets," forcing the operator to create a destination before a task can be dropped, even when weather or volunteer availability forces moving a group several days. The recently developed \`Drop here · New AM/PM Crew\` feature creates an immediate destination crew and places tasks; **it does not implement a truly unassigned day-level task**. Do not conflate the two capabilities.

**Potential future behavior to evaluate, without assuming a database schema:**

1. **Calendar / date is the first drop target.** A Manager may place an unscheduled annual task on a chosen Setup Work Day **without** already picking a Crew or Captain. Record it visibly under a workday-specific **Awaiting crew assignment** queue (or comparable explicit state), then drag or assign it to an existing or new Crew and AM/PM shift when volunteers are known. Work on the day and crew/shift allocation are **distinct decisions**.
2. **Day header is a useful compact summary and navigation surface.** Provide a small, scannable list of *work needing action* on that day (unassigned, unfinished and original occurrences with no report, correctly distinguished), task count, crew count and access to the full day. Clicking an entry should navigate to the exact task/day/crew context. Do not embed all task cards or technical labor details in the header; avoid a second cluttered dashboard.
3. **Reported/completed assignments use collapsed history by default in the active scheduling view.** They may have many lines of Captain, labor, readiness and estimated-duration details consuming large amounts of space on busy multi-crew days. Display a compact count/summary with an intentional expand/review action for authorized historical correction and audit. A mixed day with some completed cards should not show those cards merely because the *day-level* "Unfinished" filter is selected. Distinguish (a) day-level reporting state, (b) individual assignment/report state, and (c) whole-annual-task completion. Preserve immutable actual work and progress history; a 100%-reported assignment must not hide a different unfinished continuation.
4. **Move work between dates quickly.** Drag onto a target date (potentially in a calendar or persistent date strip), with a clear drop highlight, visible outcome and direct follow-up to assign the receiving day/crew. Support weather/volunteer disruptions without requiring placeholder crews or fake 1% progress. Preserve existing AM/PM assignment shift for cross-day multi-selection; deliberate same-day shift changes remain explicit. Never treat "planned but not performed" as evidence that real work was completed.
5. **Make busy workdays distinguishable and readable.** Strong bounded day backgrounds, sticky day identity, optional focused workday view, subtle consistent Crew A/B/C accents independent of Captain identity, and enough real schedule canvas to see multiple crews. Warning colors must continue to signal real capacity/readiness problems rather than crew identity.
6. **Single-entry safety and audit.** If day-level unassigned work is added, evaluate how to represent it in the existing PostgreSQL annual-task/assignment/event authority **before** altering schema or flows. Requirements include no duplicate annual assignment for a day, authorization, audited day/crew transitions, preserved actual report history and atomic failure recovery. Determine whether an existing status/relationship can represent an unassigned day, or whether a separately authorized migration is necessary; **do not fabricate an "Unassigned" crew as a hidden workaround**.

**Decision still open:** Whether a calendar-first day queue is the best next design, what the compact day header should display, and whether collapsing historical cards plus the already proposed direct-new-crew drop supplies enough benefit without a new persisted assignment state. The operator was thinking aloud; further scope and acceptance must be explicitly agreed before design/code changes.

**Acceptance criteria for any later approved slice (not satisfied):** realistic 5+ crew workday, AM/PM mixed selection, multi-day reschedule and bad-weather half-day cancellation, late/unreported vs completed distinctions, read-only/no-write preview of historic detail, field tablet and laptop viewport, clean undo/failure case, full #122 governed disposable/browser review. Keep the current rejected V0.3.67 feedback and unaccepted V0.3.68 branch status distinct from this optional design. Daily email work remains paused.

## Mandatory #205 browser acceptance — Manager reschedule from Perform Work, not late (October 15/16)

**Greg's test requirement, not an optional future UX idea.** An authorized Setup Manager must be able to reschedule an original scheduled assignment **directly from Perform Work**, after affirming that **no work was performed** on its original date. This is essential when weather, available volunteers or fill-in priorities disrupt the daily plan. Do **not** force a Captain or Manager to enter fabricated elapsed time or a fictitious progress percentage to clear a LATE banner. Existing `#175 Perform Work`, `#132 Report Work` and `#205 Scheduling Board` authority remain distinct.

- Manager-only `Reschedule · No work performed` action is present on the original assignment card (outside optional field-context request). Captain/Production Crew without Setup Manager access cannot initiate it. A field-context HTTP 404 may affect printing/report instructions but cannot block the Manager's schedule correction.
- Manager chooses a current/future existing Setup Work Day and its destination Crew/AM or PM. Option to **Create a new crew** uses the existing atomic new-crew-and-task operation. For new crew, preserve original AM/PM; for a selected existing crew, Manager may explicitly choose shift. The destination must belong to the same annual Setup Session and not be cancelled. If no eligible dates exist, offer clear direction to Add Work Days in Plan / Schedule; **do not invent a day or Crew**.
- Display the original task name, work date, Crew and shift and require explicit confirmation: `NO WORK WAS PERFORMED`. On successful server-side `ops.update_setup_work_day_assignment` or its existing atomic crew-creation wrapper, the original work occurrence is **moved**, so the original day and global past-no-report count no longer show this assignment as LATE. The target date/crew/shift gains it. Retain `ops.setup_schedule_event` **ASSIGNMENT_MOVED** audit with original and destination values and actor (migration 069). Do not rewrite the original date into an actual performed date or create a progress row.
- A valid work report, started/completed actual state, or accidental previously saved 1% progress entry makes the original assignment **historical_locked**. The UI must not offer this move; protected SQL must reject a forged request or a report arriving between screen load and submission. Incorrect 1% records require a distinct authorized forensic/correction decision, **never** silent deletion or override of actual history.
- On API error, denied permission, cancelled confirmation or unsaved destination staffing, leave the original assignment and LATE warning unchanged. Never claim success or hide the warning merely because the user clicked Reschedule; reload current authoritative board only after a successful write.
- **Operator browser test:** select a weather-affected past unreported task in Perform Work, confirm no work, choose a future day/Crew, move; assert exact new assignment, no old-date LATE card or aggregate warning for that item, no created Report Work, and the audit event. Test future unworked task, Manager vs Captain, no dates, new Crew, cancelled day, fake 1% record, concurrent Captain report protection, form cancel, browser refresh, and the 404 context case. Verify moving the other assignments from a weather-lost half-day does not require invented reports. Do not conflate a grouped weather-disruption workflow with this confirmed **single-assignment** Manager action.

**Implementation boundary:** reuse existing audited `ops.update_setup_work_day_assignment` and Manager-authorized Scheduling Board API, no new schema/migration. User-visible application build must advance beyond V0.3.68 under the release-identity rule. V0.3.67 operator review remains REJECTED; green source tests or earlier `CLEAN EXIT` do not accept the new behavior. Require governed current-Production disposable acceptance and 8898 browser review, specific Manager move/no-work evidence and `CLEAN EXIT` before any Production approval. Mail remains paused.

## ONE integrated candidate for operator-rejected October 15 review — V0.3.70 (latest checkpoint)

**Greg's controlling correction: "no it all needs to be together."** This supersedes every prior suggestion to release small pieces of PR #394 while the source screens still exhibit defects already rejected in the protected browser review. The protected V0.3.67 browser review was **REJECTED** for oversize Manager Action Center obscuring Scheduling Board, tiny/misaligned Report Work Crew/Hours/Minutes fields, missing field ? help, confusing KPI overlap/late semantics, accidental 1% progress, disappearing/locked reporting and cross-day scheduling complications. Later V0.3.68/V0.3.69 incremental source commits did **not** lift that rejection.

**Single draft source candidate now implemented for coordinated acceptance:** `V0.3.70-unified-setup-review`, source checkpoint `fa07150740e98460944306893d6cdf07a5af02c0`. Further changes through this documentation checkpoint are source-test SOP/record changes only. [Integrated CI #38854157408](https://github.com/Gregovate/MSB-Production-Database-Project/actions/runs/38854157408) PASS **816 Setup tests, 202 FieldWiring tests, Node #205 KPI/Action Center/no-work reschedule/crew autosave/mixed-shift tests**. **This is not proof of browser or Production readiness.**

Unified source changes on the same PR:

- Short read-only whole-Setup progress/remaining/deadline/pacing strip on Schedule and Perform Work. Technical KPIs and exception lists now exist **only under a separate Manager-only Action Center tab**, with role-controlled route/history and own-data reload; no long collapsible report can displace scheduling. Categories now say "Need attention" and explain why NOT READY, blocked, unstarted/no-future-work, partial and continuation counts overlap; task-count projections are explicitly tentative.
- Existing Report Work form uses responsive equal Hours/Minutes field sizing and a large Crew field, ordered with actual work date, true whole-task percent and notes. The **1% invented default is removed**; field-level accessible `?` help provides short plain steps for date, Crew, Hours, Minutes, cumulative percent and notes and links the existing authoritative SOP without clearing unsaved input. **Task Feedback** replaces misleading field-facing "Report Correction" but retains the distinct #172 Work Order Intake/Manager triage; actual Manager historical **Correct report** is unchanged.
- A missing reusable field-context/resource/procedure endpoint (including previously observed 404 or absent reusable ID on season-only task) no longer prevents Report Work from loading. A failed authoritative **progress-history** fetch still blocks, rather than assuming zero previous work and risking fabricated progress.
- Active Scheduling Board defaults hide **fully reported days** and reported individual task cards, separately. Busy mixed days show unreported work and compress entirely reported crew rows, with an explicit "Show reported task cards" toggle and exact task-search reveal. Alternating day boundaries and a sticky day header restore clear day identity.
- Existing crew Captain and AM/PM staffing changes auto-save with explicit result; no Save button, no silent lost edits. Drop on New AM/PM Crew strips creates Crew and moves selected tasks atomically. Mixed AM/PM day-to-day drag preserves each shift; recorded historical work remains protected.
- In **Perform Work** Managers can explicitly confirm "No work performed" and move the **same original unworked assignment** to a future day/crew, clearing the original old-date LATE status **only after audited success**, with no fake report. Half-day weather/staffing disruption can move all eligible unworked assignments in an AM/PM shift as **one atomic group**, preserving shift and rollback on actual-work locks; new Crew also supported by the existing atomic API. No schema migrations added; migration 069 move-audit runtime requires governed clone verification.

**Mandatory ONE end-to-end acceptance:** [V0.3.70 integrated candidate checklist](../../../../../Setup/Acceptance/Setup_205_KPI_Action_Center_Disposable_Candidate_2026-10-15.md) owns source SHA/version, all screen/crew/time/help/access/overdue/move/history/current-Production clone cases, one protected 8898 browser pass, data fingerprint and **CLEAN EXIT**. Do not ask Greg to review a separate form preview or a separate management page feature preview. Fix failures within the one candidate and rerun on a new exact SHA only when ready. Full source tests do not certify CSS rendered geometry or human usability.

**Unresolved, not silently waived:** previous accidentally persisted 1% progress records require an authorized *historical data audit/correction*, no Production repair performed; real 2026 task-count reconciliation is still pending. Full **calendar-first unassigned workday staging**, day-header mini task list and permanent crew colors were expressly recorded as **possible improvements**, not approved as part of this rescue correction. Notification mail remains paused on the separate hold branch. The full #122 Production release gate remains shut.


## October 16 V0.3.70 first-pass operator rejection — required integrated correction

**Authority:** Greg's actual disposable 8898 browser review of exact application `fa07150740e98460944306893d6cdf07a5af02c0` on draft PR #394. **Status: OPERATOR REJECTED — requirements to implement together before a new candidate and browser acceptance.** Screenshots are operator evidence, not proof of current Production values; this section supersedes any earlier classification of these items as merely optional decoration. Preserve current historical scheduling/reporting protections and all #122 release gates. Do not deploy, invent a migration, or activate mail.

### Workspace layout, visual identity, actions

1. **Three usable scroll areas and board-first focus.** Preserve the left task/backlog pane, right Scheduling Board pane, and their intended independent scrolling. When scrolling inside the board, the large global Setup header, KPI/toolbar panel, and other persistent top furniture must scroll out of the active work area rather than consume board height. Retain only a high-contrast, board-local sticky **current Setup Day** header at the top of the right pane. No overlap or inaccessible task cards on desktop, field tablet, or mobile; screen-specific scrolling must not force the operator to scroll a nested pane to dismiss global furniture.
2. **Crew identity by letter.** Consistently assign Crew A/B/C/D (and further established letters as applicable) distinct, accessible colors along the left crew/lane identification bar, with that identity repeated consistently wherever the crew appears for the same day. Do not use color alone; retain letter and Captain name. Differentiate adjacent workday boundaries more clearly than the present pale blue/gray blocks; sticky day label must remain legible in light and dark modes.
3. **Action Center affordances.** The top `Manager Action Center` navigation must be a visually unmistakable, standard semantic button. Every actionable `Plan continuation`, `Report Work`, `Move / Reschedule`, blocker navigation and equivalent Action Center control must use distinguishable standard button styling in light and dark modes; non-action labels remain plain text. Do not convert every static count or explanation into an action.
4. **Meaningful Report Work form.** Retain the accepted matched-size Hours/Minutes layout and blank initial percent. Change user-facing `People who worked` to a numeric **Number of volunteers** / **Actual crew size** (count, including Captain if worked); do not implement a person picker. Audit six contextual `?` helpers for actual field-specific guidance, keyboard/screen-reader operation and relevance; remove or correct redundant/unhelpful help rather than sprinkling decorative question marks. Preserve actual date versus scheduled date, historical correction, and reporting authorization safeguards.

### Manager exception resolution and intelligent no-work movement

5. Every late/unreported Perform Work assignment must expose two distinct, visible paths: **Report / follow up** when work may have happened but was not reported, and Manager-only **Reschedule — No work performed** when Manager explicitly confirms no work occurred. Do not clear LATE merely because someone opens a dialog or because a different occurrence has a report. Preserve original occurrence and audit; actual-work and historical locks remain authoritative.
6. Style the confirm `Move unworked assignment` action as an appropriately contrasted semantic button in both themes. On opening, search eligible **future** workdays for a crew with the **same original Captain**, and propose that matching destination first, with date, crew and preserved shift displayed. Do not silently commit a suggestion; Manager must confirm. If no suitable matching crew exists, provide governed day/crew creation or selection **with the same Captain preselected**, allowing a valid new workday if supported by existing authorized commands. Never invent a placeholder Captain or crew; do not move an assignment to an incompatible shift or erase history. Treat other-Captain destinations as an explicit, visible Manager override, if permitted.

### Shift capacity semantics — correct overload classifications

7. The existing per-shift `9.0 / 3.0 linear hours` overload warning can be misleading where the same crew has usable PM availability. Separate **AM shift-only pressure** from **whole-day overload**. Determine whether a scheduled AM task is eligible to continue into PM under the existing scheduling/assignment contract, whether the **same Crew/Captain** is actually available, and whether PM already contains work. Only subtract genuinely available PM capacity, not theoretical empty time for an unrelated crew or an unstaffed PM shift. Where eligible same-day continuation fits, show an informative `AM exceeds typical window; PM capacity may absorb ...` warning, not the categorical whole-day `OVERLOADED` error. When shift policy, available staffing or task splitability is unverified, display **requires scheduling review** with the specific assumption; never silently convert an AM assignment to ALL_DAY or create a fictitious PM assignment.
8. Restore a concise, visible **AM available / PM available / total available** capacity presentation per crew/day, grounded in existing planned counts, shift windows and task duration, clearly indicating unknown estimates and unspecified actual staffing. Capacity warnings must never imply that a crew with blank PM size is definitely available. Compare same-day available hours to actual planned task-hours before assigning a red overload state.

### Integrated regression and disposition

9. Add executable tests for scroll/focus behavior, sticky day and crew color consistency, dark/light contrast classes, button affordance/navigation, numeric crew count and useful help, Captain-preferring reschedule selection including no match/other Captain/historical-lock cases, and AM-to-PM capacity where PM is free, busy, unstaffed, or prohibited by task constraints. Reuse existing APIs/data models unless an actual schema gap is proved.
10. Implement all approved corrections **together in existing draft PR #394** following source reconnaissance and the established versioning rule. Run full Setup + FieldWiring regression, one current-Production disposable clone and protected 8898 browser review; require Greg's explicit reacceptance and CLEAN EXIT before the separate #122 release gate. The first-pass V0.3.70 browser images/counts are **rejection evidence only**, not acceptance evidence.


## October 16 V0.3.71 engineering progress — exact source-verified, NOT browser accepted

- Existing PR #394 has new candidate app SHA `58af4ea3079efe1585314a63329b77b95f31cb4f`, version `V0.3.71-operator-review-corrections`. [CI run 38897393929](https://github.com/Gregovate/MSB-Production-Database-Project/actions/runs/38897393929) PASS: 821 Setup tests, 202 FieldWiring tests and existing executable #205 Node checks. Regressions here establish source compatibility, **not** appearance, accessibility, actual 2026 database classification or operator acceptance.
- Current source refinements: workday borders/sticky right-pane day header, crew A-F identity stripes, right board planning header scrolls off the active workspace; theme-aware Action Center and no-work button treatments; actual volunteer-count wording; conditional AM pressure rather than categorical overload when a staffed PM crew may absorb work; future same-Captain crew suggestion, and Manager-guarded original Captain assignment during the existing atomic create-crew-and-move transaction. Historical reported assignments remain locked; NO WORK confirmation and schedule audit remain required.
- **Boundaries and remaining operator acceptance:** PM continuation is conditional; an AM assignment is not silently converted into PM or All Day. Availability cannot be inferred from unstaffed PM/unknown estimates. The create-new-*date* fallback is not implemented by the atomic new-*crew on existing day* action; use existing Work Day creation, and do not falsely label that enhancement finished. `?` help usability and every Action Center button's light/dark contrast still require hands-on review. Persistent global Setup navigation outside the right-pane scrolling area also needs actual tablet/desktop acceptance. Do not mark original first-pass rejection resolved from source CI.
- The documented browser handoff in `Setup/Acceptance/Setup_205_KPI_Action_Center_Disposable_Candidate_2026-10-15.md` runs **one clone** through the existing browser launcher (full Python regression → one current-Production snapshot → protected 8898 preview → CLEAN EXIT), not a separate disposable acceptance followed by another clone. PR remains draft. No migrations, mail activation or Production mutation.

## October 16 second operator review — V0.3.71 rejected (live disposable browser)

**Evidence:** six operator screenshots; CLEAN EXIT not yet claimed for this second review. These are defects to fix on the existing draft PR #394, not optional new concepts or acceptance. Current Production remains untouched. Do not infer the cause of a failed save solely from its visible status.

- **P0: Captain/crew count autosave:** Crew A D16 entered AM count 3; status `Not saved — correct or retry the field`; refresh loses the value. This is a failed persistence command, not cosmetic feedback. Verify actual API/SQL error, distinguish historical-work lock/role/validation from transport failure, preserve the unsaved draft, provide a reliable retry/error detail, and prove a legitimate crew-size edit survives re-fetch. Do **not** bypass SQL protection of historical actual assignments or fake a green Saved state. Autosave failure must remain visible.
- **Layout:** Day 16 workday summary/header bleeds beyond the right board viewport, including at the bottom of page. Prevent horizontal/vertical clipping and overflow; day header and sticky surfaces must stay inside the owning scroll region, with both shift columns accessible.
- **Capacity:** Crew A D16 has AM 9 h versus typical 3 h, empty PM cards, but planned PM crew size blank; current red OVERLOADED label is misleading as a final whole-day verdict. Distinguish shift-duration pressure, unconfirmed staffing, potential uncommitted afternoon continuation and truly provable full-day overload. Do not invent staffed PM crew or silently move AM tasks. State the specific decision required; retain visible AM and PM available time.
- **Navigation and Action Center:** Top `Manager Action Center` CTA still renders as pale outline rather than a prominent primary button. Action Center report links are blue but embedded awkwardly inside paragraphs and break lines unpredictably. Arrange consistent compact, aligned action cards/rows with standard light/dark semantic button classes; maintain task/date/crew identity and click targets.
- **Reschedule provenance:** An original assignment for Rick Hoffman on D15 was presented with future `Crew A · Captain TBD`, not matching Rick. No matching future crew must default to a neutral **Create crew for Rick** action rather than an unrelated named/TBD crew. Search all eligible future days for the same Captain, preserving source Captain identity when creating a destination crew. If no existing future day/crew qualifies, the UI must offer a governed new workday-and-crew creation path or clearly require that step without falsely claiming it is automated. Never assign a different Captain silently. All work-history locks and actor audit remain intact.

**Acceptance:** Reproduce failed-save mode with a real disposable DB command/response; prove successful legitimate save persists on refresh. Test future same-Captain / no same-Captain / no future workday and canceled day, and CSS at actual desktop/tablet widths in light/dark modes. Entire candidate must pass Setup/FieldWiring/Node and ONE disposable browser clone with operator review and CLEAN EXIT before any release approval.


### Second-review source correction checkpoint — still blocked on live crew PATCH cause

- Draft PR #394 source head `5f050d94f647ee6f3219b296d19e441a5faf4450` is CI green at [run 38900948780](https://github.com/Gregovate/MSB-Production-Database-Project/actions/runs/38900948780): 822 Setup Python tests, FieldWiring full suite and #205 Node checks PASS. This **does not establish that Crew A AM headcount persists after refresh**; it is NOT an accepted replacement for the second rejected V0.3.71 preview.
- Implemented guarded improvements: display the actual failed crew PATCH/API error beside the edit, add failed-save-only retry, listen to numeric change and blur while preserving existing no-rerender/serialized updates; never return false success; default no-work reschedule to a future same-Captain crew if present, otherwise to `NEW_CREW` with original Captain preserved in one atomic transaction rather than an unrelated/TBD crew. The new-workday atomic path remains unresolved. Styled the **actual** KPI Action Center control, action list rows, and right-pane day/header overflow rather than only the navigation tab.
- **P0 still OPEN:** Need the actual failed Crew A D16 PATCH response and the server's installed `ops.update_setup_work_day_crew` behavior. Migration 050 explicitly rejects planned AM/PM crew-count edits after real work evidence for that shift, and protects Captain changes when any actual work exists. That policy must not be bypassed. Other possible server/permission/validation causes cannot be inferred from screenshots. Must reproduce in governed disposable current-Production clone, distinguish expected immutable history from an unexpected save defect, correct the proven cause (or provide authorized correction workflow), then prove persistence after full board reload. No Production data repair. Do not promote a new candidate solely on CI.
- Re-evaluate whether red overload warning can claim a **whole-day** failure when the PM count is blank; preserve potential PM scheduling opportunity without inventing an assigned PM crew. Regression fixture for this exact case and full desktop/tablet overflow acceptance remain required.


### Second-review source checkpoint — CI green, P0 not independently resolved

PR #394 app/source commit `4df41db72d2d27176a30ea660620b6922b113211`; [source CI #38901289450](https://github.com/Gregovate/MSB-Production-Database-Project/actions/runs/38901289450) PASS Setup/FieldWiring jobs. Later documentation commits must not be used as an application SHA. Fixes include same-Captain New Crew default instead of another Captain/TBD, visible API error and retry after failed autosave, actual Action Center CTA/button layout, containing day header within right-pane viewport, and classifying AM overflow with unconfirmed PM crew as scheduling pressure rather than proven whole-day overload. **These have not received live 8898 browser acceptance.**

**P0 blocked awaiting source-specific evidence:** The user observed a failed planned AM crew count save and loss of value on refresh. The database's established `ops.update_setup_work_day_crew` function can reject count changes after work/progress was recorded (historical lock); whether that or another error caused this specific failed PATCH is unknown. The exact rejected response for `PATCH /api/setup/scheduling-board/crews/{crewId}` is required to classify and fix it without breaching history. New app display of the error is diagnostic, **not a claimed persistence repair**. Do not issue final release candidate or ask user to repeat an entire clone before this is resolved. New-date and new-crew atomic movement is not implemented in this source; do not claim it is.

### Post-CLEAN EXIT evidence recovery — do not ask operator to reopen rejected browser

The V0.3.71 second-pass disposable browser was **closed by the operator** after testing. No browser Network/DevTools response can be presumed available. Earlier assistant instructions asking the operator to fetch the failed Crew PATCH response from that closed tab were incorrect; do not repeat the test solely for this purpose.

The existing governed `Setup/Acceptance/setup_disposable_browser_preview_server.sh` **retains** the preview report under `$HOME/setup-acceptance-reports/Setup_Disposable_Browser_Preview_<stamp>.txt` and the preview Flask log under `/tmp/Setup_Disposable_Browser_Preview_Flask_<stamp>.log`, and prints their exact paths during CLEAN EXIT. Before requesting another clone, use the prior recorded report/path and authorized **read-only** server log inspection if available. A Flask access log may identify failed PATCH/status, but handled SQL exceptions return a JSON body through `setup_scheduling_board_api.py`; that JSON error text is **not guaranteed to be present** in the server access log. Do not claim the precise SQL rejection is known without evidence.

P0 verification requirement remains: distinguish immutable historical assignment protection from an unexpected crew-size save failure, then prove a legitimate editable crew count persists across readback/refresh in a single governed disposable clone. Do not weaken historical protection and do not claim a new source-only PASS solves the live failure.
