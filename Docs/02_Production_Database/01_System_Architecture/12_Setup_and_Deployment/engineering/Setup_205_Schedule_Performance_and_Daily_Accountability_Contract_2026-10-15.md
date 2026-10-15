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

Overdue/no-report is *not* proof of zero field work; likewise a 100% annual task does not retroactively supply missing scheduled work-period reports. Historical original assignment date, Captain/crew/shift and reporting obligation must survive rescheduling. No automatic correction, completion, history deletion or waiver.

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
- **Resolution:** actual progress report on historical assignment clears that occurrence's missing-report warning; partial report can leave the annual task unfinished and requiring rescheduling. Replanning must never clear the missing report. If no work took place, Manager must reconcile the originally unworked assignment using an existing governed operation and preserve correct history; do not auto-dismiss.
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
