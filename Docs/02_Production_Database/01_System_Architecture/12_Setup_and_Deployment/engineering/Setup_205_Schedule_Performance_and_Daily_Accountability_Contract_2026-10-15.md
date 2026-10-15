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
