# Report QC Problems, Repair Them, and Sign Off an Area

| Document Control | Value |
|---|---|
| Document Type | Operational SOP |
| System | Production Database — Setup and Deployment |
| Task | Report a problem, claim and record a repair, complete final QC |
| Audience | Production Crew and QC auditors |
| Status | CURRENT |
| Owner | MSB Production Database / Setup administrator |
| Last Reviewed | 2026-11-11 |
| Keywords | QC Check, QC Repairs Needed, repair, auditor, two-minute test, Ready for Production |

## Purpose

Keep Setup problems and their repairs together under the correct Stage or Scene. Use **QC Check** for Setup problems before the show starts. Do not submit duplicate Work Order requests. Work Orders are the repair system once the show starts.

## Before You Start

Open [Setup](https://my.sheboyganlights.org/setup/), confirm **Season 2026**, then choose **Perform Work**.

Anyone on the Production Crew can report a problem or claim a repair. No Manager approval or scheduling is needed. You can report a problem even before installation is finished.

Continue recording actual task completion under **Scheduled Work**. Unreported or unfinished required tasks prevent final QC sign-off.

## Report a Problem

1. Select **QC Check**.
2. Find and open the correct Stage or Scene under **Pick an area**. Check its name and QC task number.
3. Read the existing problems first. Use **Add an observation** on the same problem instead of reporting it again.
4. Under **Report problems**, enter what is wrong, with one problem per line. For example: `Arch 3 — all red lights out`.
5. Click **Save Problems**. Confirm each problem appears under the selected area.

## Claim and Complete a Repair

1. Select **QC Repairs Needed**.
2. Find the correct area and problem, then click **I'll Fix This**.
3. Confirm your name appears on the repair. You may leave and return later; claiming does not mean the repair is finished.
4. After doing the work, return to the same problem and enter what you repaired under **Repair notes**.
5. Click **Mark Repaired**. The problem now says **Repaired — awaiting area sign-off**.

## Complete the Final Area Check

1. In **QC Check**, open the area you are checking and click **Assign to Me** to become its auditor.
2. Check **Final QC — Ready for Production** for unfinished required tasks or repairs. These must be completed and recorded first.
3. Observe the entire area during the full two-minute test, including all repaired items. You observe the sequence; you do not need to operate it.
4. If a repaired problem still fails, open its observation controls, describe what failed, and click **Still Failing**. Report any new problem under **Report problems**.
5. Only when everything works, check **I observed the full two-minute test and confirmed this area works.**
6. Click **Ready for Production — Sign Off**. This completes the QC task and confirms its repaired findings together. There is no separate Verified button for each repair.

## Expected Result

- **White:** no unresolved findings; final QC still pending.
- **Yellow:** problems need repair or repaired problems await final area sign-off.
- **Green:** final sign-off complete. The area remains on the main list and accepts new pre-show findings.

A new problem before final sign-off keeps or turns the area yellow. Before the show starts, report new problems against the same green area. Saving a problem turns it yellow again; repair and repeat the final check. Prior sign-offs remain in history. Work Orders begin when the show starts, not when an area passes QC.

## If Something Is Wrong

- A disabled sign-off lists unfinished work or repairs. Record real completion; do not mark unfinished work complete just to clear the block.
- If a required task appears unrelated, give the Setup administrator the area and task numbers. Do not work around the block with a false report.
- If your Scene has no separate QC entry, do not choose an unrelated Scene or add a new task. Ask the Setup administrator which existing area entry covers it.
- If a save fails, read the message beside the action and correct the entry. Check whether it saved before trying again.
- Earlier Intake and Work Orders are being reviewed separately. Do not delete or recreate those reports yourself; ask the Setup administrator about a suspected duplicate.

## Related Documents

- [Perform and Report Setup Work](Perform_and_Report_Setup_Work.md)
- [Setup Operator Procedures](README.md)
- [Setup and Deployment](../README.md)

## Follow-up candidate: print findings and retained history

The report/control follow-up is in browser review, not yet deployed. Its **QC report / PDF — all findings and history** link opens a report from either QC screen. Choose **Print / Save PDF**, then **Save as PDF** in the browser print dialog. The default includes completed findings, reporters, repair claimants, repair notes, auditors and final sign-off evidence. **Outstanding only** produces a current repair list. The report is read-only; printing does not complete work. Completed area details also retain the finding history.

## Finding your assignments (candidate #489)

In **QC Repairs Needed**, **My Repairs** shows your assigned problems, including repairs awaiting area sign-off. Choose **Unclaimed** to pick up a repair, or **All Repairs** to see the park. Counts show the outstanding work in each category. Search within the chosen category by area, QC task number, finding number, person or words in the report/history. Your typed repair notes remain when switching filters.

In **QC Check**, **All Areas** lets anyone find an area to report a problem. Choose **My QC Areas** to see areas you claimed as auditor. Search also finds existing problem and repair notes. Completed areas remain in collapsed history; the full QC report includes completed findings regardless of your current filters.

This source-only follow-up is not released until its new candidate passes disposable browser review and receives release approval.


The final test task is displayed as **QC Check - Verify Stage/Scene sequence lights during the 2 minute test sequence**. Open **QC completion check** for the network and channel-order checks: a controller must register, No Conn or a flashing controller light is a failure, and channels must fire 1-2-3-4 (usually left to right) at half-second or one-second intervals. Report incorrect order and any lights that do not work.

The report action is beside the activity tabs. Assignment filters and search are together below; the filled blue filter is selected. **QC report / PDF** retains all findings and history regardless of your current filter.


If someone else claimed a repair and you completed it, open **All Repairs**, find the issue, enter what you repaired and select **Mark Repaired**. You do not have to unassign the original worker. History keeps the original claim and records you as the person completing the repair. The area auditor still performs final sign-off.

## V0.3.123 candidate (not yet deployed)

Green areas remain visible. New problems turn them yellow until repaired and signed off again. Punch list / PDF shows only repair-needed findings by default; choose Include awaiting final check or Full history as needed. Problem boxes are empty; type one problem per line.

### November 14 — correction review; Production approval withdrawn
QC Check and QC Repairs share all-word area/issue/person/notes search, explicit expandable area headers, and the same Edit Issue form. Repairs group findings once per area and initially show Unclaimed; My Repairs and All Repairs remain available. Signed-off areas stay visible in QC Check. Reporter or manager may correct description and destination within the same season before a repair has been recorded; a claim alone does not count as a completed repair. Save preserves finding identity, original reporting, claimant, correction author/time and before/after wording/location. Stale edits are rejected. Moving an unresolved issue into a signed-off area archives its prior approval and turns it yellow; no automatic approval of the source area. Both screens and reports use corrected wording. No live data corrections or deployment have occurred. Prior report layout acceptance remains valid; screen acceptance and release authorization must be renewed.

### Explicit season exception — approved scope, not production authorization
A manager can accept a specific outstanding defect for the current season and create a native Planning Work Order for off-season repair in one transaction. Enter a reason, active Work Order type and due date in the next calendar year or later. Reuse the existing Work Management command, permissions, notification intents and Work Order authority; create no annual Setup dependency. If creation fails, acceptance rolls back. Retrying an accepted issue returns its existing WO. Preserve the defect as unrepaired with approval attribution and WO reference; exclude only explicitly accepted findings from the repair blocker and repair punch list. Full history and QC area retain the accepted exception. All other work/readiness/repair requirements and auditor observation remain mandatory. A normal Work Order never waives QC. No live emails or Work Orders have been created during engineering. The existing disposable environment remains the acceptance boundary.
