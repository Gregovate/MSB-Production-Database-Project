# Work Order Operational SOPs

| Document Control | Value |
|---|---|
| Document Type | Operator Portal |
| System | Production Database — Work Orders / Work Management |
| Audience | Production Crew, Managers, request reporters |
| Status | CURRENT |
| Owner | Production Database Manager |
| Last Reviewed | 2026-10-21 |
| Keywords | work orders, work management, create, intake, triage, assign, due by, work note, complete, cancel, clarification, email |

Open the current protected application:

[**Open Work Orders**](https://my.sheboyganlights.org/workorder/)

The live Production application is **Work Management V1.1.2-manager-utilities**. It is the normal operator interface for current Work Orders. PostgreSQL remains the Work Order system of record and Directus remains the user/role/policy authority.

## What Do You Need To Do?

| I need to... | Go to |
|---|---|
| Report a problem or request work | [Submit a Work Order Request](Submit_a_Work_Order_Request.md) |
| Review Public Intake or Setup Task Feedback | [Triage a Work Order Request](Triage_a_Work_Order_Request.md) |
| Create, edit, cancel, or review internal Work Orders | [Manage an Internal Work Order](Manage_an_Internal_Work_Order.md) |
| Assign or reassign work | [Assign a Work Order](Assign_a_Work_Order.md) |
| Work something assigned to me | [Work an Assigned Work Order](Work_an_Assigned_Work_Order.md) |
| Complete finished work | [Complete a Work Order](Complete_a_Work_Order.md) |
| Choose urgency, planning year, or understand Due by | [Urgency, Target Year, and Due By](Urgency_and_Target_Year_Reference.md) |
| Understand Work Management email and reporter follow-up | [Work Management Notifications](Phase_1_and_Phase_2_Notification_Procedure.md) |

## Current Entry Paths

A ticket enters Work Management through one of these governed paths:

1. **Public Work Order Request** → Work Order Intake → Manager review.
2. **Authorized internal Create Work Order** → native active Work Order.
3. **Test Session repair** → native active repair Work Order; no Intake triage.
4. **Setup Report Correction / Task Feedback** → retained correction Intake for Manager review; promote only when actual repair/work is required.

Do not create a duplicate Work Order because an existing request, repair, or correction is difficult to find.

## Production Crew

Production Crew can use Work Management, subject to their current Directus role/policy, to:

- open **My Assigned Work Orders**;
- review Work Orders they created;
- create internal Work Orders where authorized;
- add a **Work Note** without closing the Work Order;
- complete assigned work with substantive Completion Notes; and
- review submitted feedback where available.

Crew do not perform Manager Intake triage or assignment/reassignment.

## Managers

Managers use Work Management to:

- review all Work Orders and Manager queues;
- review **Public Intake** and **Task Feedback** separately;
- create native Work Orders;
- promote and assign approved Intake;
- assign/reassign one or more People;
- edit an existing open Work Order with a reason;
- cancel/no-action an open Work Order with a reason;
- set or maintain **Due by** where allowed;
- review unassigned work, Testing work, open-work aging, deadlines, and CSV;
- request reporter clarification and review replies; and
- review email delivery status and the no-send email-template Utilities page.

## Email Is Part of the Live Workflow

The Phase 2 notification system is now live. Work Management owns current notification delivery for the migrated events, including assignment, clarification/reply, and reporter outcome messages where there is an eligible recipient.

Managers can see delivery state. **Queued, missing recipient, failed, or in-progress/uncertain are not successful delivery.** Do not repeat the underlying business action merely to force another email.

See [Work Management Notifications](Phase_1_and_Phase_2_Notification_Procedure.md).

## Testing Repairs

Test Session repair Work Orders remain authoritative native Work Orders. Completion must preserve the existing Testing integration. Do not manually rewrite Testing history to work around a Work Order mismatch.

## Related Procedures

- [Test Session Operational SOPs](../Test_Sessions/README.md)
- [Production Database Operational SOPs](../README.md)
- [Work Orders Engineering](../../01_System_Architecture/06_Work_Orders/README.md)
