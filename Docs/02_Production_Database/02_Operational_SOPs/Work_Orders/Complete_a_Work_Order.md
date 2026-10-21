# Complete a Work Order

[← Previous: Work an Assigned Work Order](Work_an_Assigned_Work_Order.md) | [↑ Work Orders Home](README.md) | [Next: Urgency and Target Year Reference →](Urgency_and_Target_Year_Reference.md)

| Document Control | Value |
|---|---|
| Document Type | Operational SOP |
| System | Production Database — Work Orders |
| Task | Complete a Work Order |
| Audience | Volunteers / Managers |
| Status | CURRENT |
| Owner | Production Database Manager |
| Last Reviewed | 2026-10-20 |
| Keywords | work order, complete, completion notes, repair complete, test session |

## Purpose

Use this procedure when the work described by a Work Order has been finished.

## Before You Start

Confirm the work is actually complete and the result has been checked when appropriate.

If the Work Order was created automatically by a container Test Session, remember that the related container Test Session cannot be closed until this Work Order is completed.

## Procedure

1. Open the Work Order in [Work Orders](https://my.sheboyganlights.org/workorder/).
2. Choose **Complete Work Order** at the top of the ticket.
3. Enter **Completion Notes** describing what was done. Completion Notes are required.
4. Submit the completion once.
5. Confirm the saved completion and notes. The application supplies your identity and completion time.

## Expected Result

The Work Order is recorded as complete.

The system records the completion date/time and the person completing the work.

For repair Work Orders created by display testing, the linked testing result and repair history must remain consistent. Keep the existing Testing integration enabled and verify its result; app completion alone is not proof that a Directus event Flow ran. Report a mismatch to a Manager rather than editing testing history manually.

Once all Test Session-generated Work Orders and other unresolved testing items for the container are completed, the container Test Session can be finished according to the Test Session procedure.

**Reporter email:** Phase 1 does not send the new done/canceled notice. Phase 2 delivery remains pending. Cancellation is a separate Manager action with a reason; never use completion to mean no work was done.

## If Something Is Wrong

If the work is not actually finished, do not mark the Work Order complete. Record useful progress notes and leave the Work Order open.

If a testing-related Work Order is completed but the linked test record does not update as expected, ask a manager for help rather than editing testing history manually.

## Related Documents

- [Work an Assigned Work Order](Work_an_Assigned_Work_Order.md)
- [Test Session Operational SOPs](../Test_Sessions/README.md)
- [Finish a Container Test Session](../Test_Sessions/Finish_a_Container_Test_Session.md)

---

[← Previous: Work an Assigned Work Order](Work_an_Assigned_Work_Order.md) | [↑ Work Orders Home](README.md) | [Next: Urgency and Target Year Reference →](Urgency_and_Target_Year_Reference.md)
