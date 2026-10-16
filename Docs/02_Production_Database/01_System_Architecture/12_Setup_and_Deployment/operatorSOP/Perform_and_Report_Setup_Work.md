# Perform and Report Setup Work

| Document Control | Value |
|---|---|
| Document Type | Operational SOP |
| System | Production Database — Setup and Deployment |
| Task | Perform scheduled Setup work and report actual work |
| Audience | Production Crew, Captains, Setup Managers |
| Status | V0.3.70 operator SOP candidate — current Production may have older controls |
| Owner | MSB Production Database / Setup administrator |
| Last Reviewed | 2026-10-15 |
| Keywords | Setup, Perform Work, Captain, Report Work, partial work, procedure, Print Task |

## Purpose

Use **Perform Work** when you are ready to do scheduled Setup work in the field and record what actually happened.

This screen uses the real 2026 Setup schedule. It keeps the original scheduled assignment separate from the actual work you report.

## Before You Start

- Open [**Setup**](https://my.sheboyganlights.org/setup/).
- Confirm the Season is **2026**.
- Use **Perform Work** for field execution.
- If you need to change the schedule before work starts, use **Plan / Schedule**.

## Find Your Scheduled Work

1. Open **Perform Work**.
2. The Captain filter defaults to the signed-in person when that person is a Captain on scheduled work.
3. The normal field view hides completed assignments and shows scheduled / in-progress work.
4. Turn on **Show completed** only when you need completed assignments added back into the current Captain view.
5. Choose **All scheduled work** when you need the same view across every Captain.

**Show completed** and **All scheduled work** are independent controls:

- **Show completed** changes assignment status visibility;
- **All scheduled work** changes Captain scope globally.

Changing the Captain dropdown affects the current view. A fresh login/session re-evaluates the signed-in Captain default from current schedule/access context.

Scheduled work is grouped by:

- Setup Day;
- AM / PM;
- Crew;
- Captain; and
- scheduled task order.


## Labor Summary

The Perform Work summary answers two different questions and keeps them separate:

- **Planned labor** shows the planned person-hours for the current Captain scope, including work that may still be scheduled/in progress. It remains visible even when **Show completed** is off.
- **Actual labor** shows reported person-hours for the current Captain scope.
- **Completed-work variance** compares only completed assignments: completed actual person-hours minus completed planned person-hours.

Future scheduled work does not reduce or distort completed-work variance.

When a completed assignment needed for the comparison is missing a plan estimate, **Completed-work variance** remains **TBD** and the screen identifies how many completed assignments are missing the estimate.

The variance detail shows the completed comparison, for example:

```text
Completed: 18 hr actual vs 16 hr planned
```


## Open a Task

Select the task you are working on.

The task may show:

- the scheduled day / shift / crew / Captain;
- completion and readiness information;
- Equipment / Resources;
- current material / location context;
- the current published Setup Procedure; and
- Progress history.

A readiness note is planning information. If legitimate work was actually performed, use **Report Work** to record the actual work.

## Print the Task Cover Sheet

Use **Print Task** when paper is useful in the field.

The cover sheet identifies the selected scheduled task and includes current task context plus an area for handwritten notes/corrections/problems.

The printed sheet is a field aid. The current Setup application and current published procedure remain the operating authority.

## Open the Current Procedure

Under **Published Setup Procedure**, open the current procedure when the task has one.

If the procedure appears wrong or incomplete, do not silently change the work history to make it fit. Use **Task Feedback** to preserve the field finding for Manager triage.

## Manager-only reschedule when no work happened (V0.3.70 candidate; not yet live)

**Only after the #205 candidate has been accepted and installed:** A Manager can open the affected original task on **Perform Work**, select **Reschedule · No work performed**, choose a current/future Setup Day and existing/new Crew, confirm that NO work happened, then verify the new scheduled day. This is a schedule move with an audit trail—not a work report. The original assignment no longer counts as late after a successful audited move.

If weather or staffing prevents **several tasks in the same AM/PM shift** from happening, a Manager can select **Reschedule unworked AM/PM tasks** on that shift to move the eligible tasks together. The move succeeds together or stops entirely if any task has recorded actual work.

If any actual work happened, **do not** claim no work. Report actual time and progress for that original occurrence, then schedule a continuation for what remains. A saved 1% report still counts as history until separately corrected by an authorized Manager; it cannot be silently moved away. Only Manager access can change these schedules.

**This capability and the screen layout are still a disposable browser candidate**; Production may continue to show older controls until the approved deployment. Do not use this section to infer that a command exists on the live screen.

## Planned volunteers versus actual people who worked (V0.3.73 candidate, not yet live)

The **Plan / Schedule** AM/PM crew count is a working estimate, not an attendance report. Managers may adjust it as volunteers arrive or change crews. A count of **1** means the Captain working alone. A **blank** count means no Captain-led crew is confirmed for that shift; the named Captain may be elsewhere. Do not enter a zero to represent a blank.

A blank crew count does **not** erase the task or its expected duration. You may schedule work while estimates are still unknown; the Scheduling Board will show those planning gaps for later review. Planned **task-hours** are time required for the task, while estimated **person-hours** also require a known crew count and may be marked **TBD**.

When reporting completed work, enter the **actual number of volunteers who worked on that task**, including the Captain only if the Captain worked, plus the actual elapsed Hours and Minutes. The Report Work record is the actual history. Editing planned crew size never changes a saved work report.

## Report Work

Use **Report Work** after work has actually been performed.

Enter:

1. **Date work actually happened** — the date the crew actually did the work.
   - It defaults to the scheduled assignment date.
   - Change it when the work happened on a different day.
2. **Actual crew size** — the actual number of people who worked the task.
3. **Hours** and **Minutes** — the actual elapsed work period. These are equal-sized inputs side by side in the proposed V0.3.70 form; enter both the real hours and remaining minutes.
4. **Whole task % complete** — the cumulative percent complete after this work period.
5. **What was done / what remains** — required when the task is not 100% complete.
6. **Add quantity detail (optional)** — use only when countable detail is useful.

Then click **Save Work Report** and confirm both the scheduled date and the date work actually happened. Cancel preserves your entries.

### Scheduled date and actual work date are different facts

Do not change the schedule just to make it agree with the actual report.

Example:

```text
Scheduled assignment:  September 23
Work completed on:     September 24
```

That is valid. The schedule records the plan; **Date work actually happened** records what actually happened.

## If You Get an Email Saying a Work Report Is Missing

This means the computer has no report for one of your scheduled work assignments. **It does not mean you did nothing wrong or that no work happened.** The Manager needs to know what actually happened.

1. Read the email and check the **task name**, **Setup Day/date**, **crew**, and **morning or afternoon**. Make sure it is your assignment.
2. Open [Setup](https://my.sheboyganlights.org/setup/) and sign in if asked. Confirm **Season 2026**.
3. Click **Perform Work**.
4. In the **Captain** dropdown, select your name. A Manager who is helping can choose **All scheduled work**.
5. Locate the **same date, crew, shift, and task** from the email. If a past day is folded up or not displayed, ask a Manager to help reveal the historical assignment rather than reporting against the wrong task.
6. Click the task to open it, then choose **Report Work**.
7. For **Date work actually happened**, enter the date the crew **actually did the work**, even when it is different from the scheduled date.
8. Enter the **real number of people** under **Actual crew size** and the **actual Hours and Minutes** the work took.
9. Enter **Whole task % complete** for the *whole task*: **100** means truly finished. If some work remains, enter the best honest percent and describe **What was done / what remains**. Optional quantity details are only for things you can count.
10. Review the entries, click **Save Work Report**, and confirm the new entry appears under **Progress history**.
11. If work is unfinished, tell the Manager what remains. The Manager needs to schedule another work assignment; submitting a partial report does not automatically reschedule it.

**If no one worked on that assignment:** do not enter fake work, time, or a percentage to make the warning disappear. Tell the Manager the assignment was not worked; the Manager must review the plan.

**If somebody already reported the work or the report is wrong:** do not add a duplicate. Ask a Manager to inspect **Progress history** and use **Correct report** where appropriate.

**If you cannot find your name, day, task or the Report Work button:** contact the Manager instead of guessing. The Manager can check your schedule and whether your account has the correct access.

## Partial Work and Continuation

If the report is below 100%, the annual task remains **In Progress**.

Once actual work has been reported against a scheduled assignment, that worked occurrence is historical evidence and should not be moved to another day just to represent remaining work.

For remaining work:

1. Return to **Plan / Schedule**.
2. Schedule the same annual task again as a new future assignment.
3. Choose the appropriate Work Day / shift / Crew / Captain.
4. Move or reassign that future continuation as plans change, until actual work is reported against it.

A continuation may use a different Captain from the earlier worked assignment.

## Correct a Mistaken Work Report — Managers

Managers can correct an existing report without creating a duplicate report.

1. Open the task in **Perform Work**.
2. Find the entry under **Progress history**.
3. Open **Correct report**.
4. Correct the actual date, crew, Hours/Minutes, percent complete, notes, or optional quantity detail.
5. Click **Save Correction**.

The correction updates the existing report and preserves its history/audit information.

Do not enter a second work report solely to repair a data-entry mistake.

## Task Feedback

Use **Task Feedback** when the scheduled work exposes a field condition, Procedure problem, material relationship, data discrepancy, or other Setup information that may need correction.

1. Open the scheduled task in **Perform Work**.
2. Click **Task Feedback**.
3. Enter a concise **What did you find?**
4. Optionally enter a **Suggested correction / evidence**.
5. Click **Task Feedback**.

Setup automatically preserves the known scheduled context, including the annual task, reusable source task when one exists, exact scheduled assignment, Setup Day/date/shift/Crew/Captain, Stage/Scene, current Procedure identity when available, authenticated reporter, and submission time.

The report goes to **Work Order Intake** as **Submitted** for Manager triage. Reporting a correction does **not** create an active Work Order and does not directly change the reusable Catalog, Kit, Procedure, LOR, schedule, or other durable business data.

A Manager decides whether the finding should be deleted/no action, remain Submitted, be promoted to an active Work Order, or be corrected through the appropriate Setup/data/Procedure/GIS/engineering surface.

## Expected Result

After a work report is saved:

- the Progress history shows the actual work;
- partial work remains **In Progress**;
- 100% completes the annual task;
- the worked scheduled occurrence remains historical;
- remaining partial work can be scheduled again as a new future assignment.

## If Something Is Wrong

- If the wrong task was scheduled and no work has been reported yet, correct the assignment in **Plan / Schedule**.
- If the work report itself was entered incorrectly, ask a Manager to use **Correct report**.
- If the task/procedure/material/data is wrong, use **Task Feedback**; do not invent replacement data merely to make the screen look complete.
- If the application does not behave as described, stop before entering duplicate or guessed information.

## Related Documents

- [Setup and Deployment](../README.md)
- [Setup Manager Review Guide](../../../02_Operational_SOPs/Setup/Setup_Session_Manager_Review_Guide.md)
- [Setup Operator Procedure Index](README.md)
