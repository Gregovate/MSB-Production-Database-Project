# Manage an Internal Work Order

[↑ Work Orders Home](README.md)

| Document Control | Value |
|---|---|
| Document Type | Operational SOP |
| System | Production Database — Work Orders |
| Task | Create, edit, schedule, or cancel native Work Orders |
| Audience | Production Crew / Managers as authorized |
| Status | CURRENT |
| Owner | Production Database Manager |
| Last Reviewed | 2026-10-21 |
| Keywords | create work order, edit, cancel, no action, due by, aging, overdue, manager |

## Create an Internal Work Order

Authorized users open [Work Orders](https://my.sheboyganlights.org/workorder/) and choose **Create Work Order**.

Enter the real known work. Do not create fake Intake for work that is already known to be an approved native Work Order.

Current creation requires:

- a valid description;
- Task Type;
- Urgency;
- one operational location (Stage or Work Area);
- **Due by**; and
- Target Year when Priority 5 **Planning** requires it.

Crew-created Work Orders may remain unassigned. Managers own dispatch/assignment.

## Manager Edit

Managers may use the Work Order **Edit** action to correct an existing open Work Order. Enter the required reason so the before/after change remains auditable.

Do not use Edit to rewrite completion history.

## Assign / Reassign

Use the separate **Assign / Reassign** action for People assignments. Assignment history is preserved.

## Due By

Managers may maintain **Due by** through the governed Work Management action where allowed.

The application shows missing-date and deadline status. **Due today is not overdue.**

Testing-linked Work Orders use the narrower deadline action; general Testing edit/cancel remains restricted by its governed boundary.

## Cancel / No Action

Managers use **Cancel / No Action** when no further physical work should occur and must enter a substantive reason.

Cancellation is not completion. Do not write completion notes that imply work was performed when it was not.

## Aging / Deadline Review

Use the Manager **Open Work Order Aging Report** for all recorded-open Work Orders, age, Due by, deadline status, priority, assignees, and exceptions. The guarded CSV exports the full report.

Creation age and Due by are different facts.

## Email / Delivery Review

Phase 2 notification delivery is live. Managers can review ticket **Email delivery status** and use **Utilities → Email template previews** for fictional no-send examples.

Utilities does not send mail or edit templates.

Do not repeat Create, Assign, Complete, Cancel, or another business action merely to force notification delivery.

See [Work Management Notifications](Phase_1_and_Phase_2_Notification_Procedure.md).
