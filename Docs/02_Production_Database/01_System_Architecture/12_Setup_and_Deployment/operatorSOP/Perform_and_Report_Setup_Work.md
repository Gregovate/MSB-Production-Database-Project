# Perform and Report Setup Work

| Document Control | Value |
|---|---|
| Document Type | Operational SOP |
| System | Production Database — Setup and Deployment |
| Task | Perform scheduled Setup work and report actual work |
| Audience | Production Crew, Captains, Setup Managers |
| Status | CURRENT |
| Owner | MSB Production Database / Setup administrator |
| Last Reviewed | 2026-09-26 |
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
2. Use the **Captain** dropdown.
3. Choose your name to see only work assigned to crews you Captain.
4. Choose **All scheduled work** when you need to see the full field schedule.

When a logged-in person is a Captain on scheduled work, Setup may start with that Captain selected. If you explicitly choose **All scheduled work** or another Captain, Setup remembers that choice for that user and season.

Scheduled work is grouped by:

- Setup Day;
- AM / PM;
- Crew;
- Captain; and
- scheduled task order.

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

If the procedure appears wrong or incomplete, do not silently change the work history to make it fit. Tell a Manager and preserve the correction for the field-correction workflow.

## Report Work

Use **Report Work** after work has actually been performed.

Enter:

1. **Work completed on** — the date the crew actually did the work.
   - It defaults to the scheduled assignment date.
   - Change it when the work happened on a different day.
2. **Crew size** — the actual number of people who worked the task.
3. **Hours** and **Minutes** — the actual elapsed work period.
4. **% complete** — the cumulative percent complete after this work period.
5. **What was done / what remains** — required when the task is not 100% complete.
6. **Add quantity detail (optional)** — use only when countable detail is useful.

Then click **Save Work Report**.

### Scheduled date and actual work date are different facts

Do not change the schedule just to make it agree with the actual report.

Example:

```text
Scheduled assignment:  September 23
Work completed on:     September 24
```

That is valid. The schedule records the plan; **Work completed on** records what actually happened.

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

## Report Correction

The **Report Correction** button is visible but is not yet enabled.

For now, tell a Manager when a field condition, procedure, material relationship, data value, or other Setup information needs correction.

The durable field-correction / triage workflow is owned separately and will be enabled under the existing correction-intake workstream.

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
- If the task/procedure/material/data is wrong, preserve the correction with a Manager; do not invent replacement data merely to make the screen look complete.
- If the application does not behave as described, stop before entering duplicate or guessed information.

## Related Documents

- [Setup and Deployment](../README.md)
- [Setup Manager Review Guide](../../../02_Operational_SOPs/Setup/Setup_Session_Manager_Review_Guide.md)
- [Setup Operator Procedure Index](README.md)
