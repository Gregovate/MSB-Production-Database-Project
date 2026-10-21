# Work Management Notifications

| Document Control | Value |
|---|---|
| Document Type | Operational SOP |
| System | Production Database — Work Management |
| Audience | Managers, Production Crew, reporters |
| Status | CURRENT — Production Phase 2 |
| Owner | Production Database Manager |
| Last Reviewed | 2026-10-21 |
| Keywords | email, assignment, clarification, reporter reply, outcome, delivery status, missing recipient, utilities |

## Current Production Status

Work Management Phase 2 notification delivery is live in Production as part of **V1.1.2-manager-utilities**.

The governed mail worker is enabled. The deployment recorded SMTP acceptance and confirmed Inbox receipt during release validation. The two legacy duplicate email Flows retired by the cutover remain inactive; unrelated non-mail Directus operations and the separate Setup daily email schedule remain preserved.

This does **not** mean every event has an eligible recipient or that SMTP acceptance proves Inbox delivery for every message.

## Notification Types

Current Work Management templates cover:

- **New Work Order Request / Intake** → Manager recipients.
- **Setup Task Feedback** → Manager recipients with task context.
- **Assignment** → assigned recipient(s), including Due by.
- **More Information** → original reporter with a protected same-ticket response link.
- **Reporter Reply** → accountable correction owner or question author.
- **Done / Canceled / Disposition Outcome** → original reporter.

## Request More Information

1. Open the original Intake/Task Feedback ticket.
2. Use the clarification action and enter one specific question.
3. Submit once.
4. Review **Email delivery status**.
5. The eligible reporter opens the protected link and uses **Reply to clarification** on that same Intake.
6. Review the reply in ticket activity and continue triage.

Email replies sent back to the mailbox are not ingested as ticket replies.

## Assignment Notification

When an assignment event has an eligible recipient, Work Management creates the governed assignment message using the current assignee and **Due by** information.

Do not repeat Assign/Reassign simply to resend a message.

## Reporter Outcome

When a ticket reaches an authorized final business outcome, the original reporter is the intended reporter-notification recipient where eligible.

The message must reflect the real result. **Cancellation / No Action is not completion.**

## Delivery Status

Managers can see email delivery state on the selected ticket.

Interpret states conservatively:

- **SMTP accepted** = relay accepted the message; it is the positive transport result recorded by the sender.
- **Queued / held** = not yet successful delivery.
- **Missing recipient** = no eligible address/access; Manager follow-up is required.
- **Failed** = send failed; investigate/follow up.
- **In progress / uncertain** = do not assume success and do not automatically repeat the business action.

The system intentionally does not blindly retry uncertain claimed sends.

## Manager Utilities

Managers can open **Utilities** and expand **Email template previews**.

The page shows fictional no-send previews of the reviewed templates. It does not send mail and does not edit Production templates.

Template source changes remain controlled repository/configuration changes.

## If Email Does Not Arrive

1. Check the ticket's delivery status.
2. Confirm the intended recipient.
3. If status is missing/failed/uncertain, perform approved manual follow-up and escalate the delivery problem.
4. Do **not** repeat Create, Promote, Assign, Complete, Cancel, or another business action merely to trigger another email.
5. Do not mark an event delivered based only on a queued database record.

## Boundaries

- Directus still owns user/role/policy authorization.
- PostgreSQL/Work Management own current Work Order lifecycle and notification event state.
- The Setup daily report email is separate and unchanged.
- All-event recipient coverage and long-running worker observation remain operational follow-up; do not invent delivery success where no evidence exists.

## Related Procedures

- [Triage a Work Order Request](Triage_a_Work_Order_Request.md)
- [Assign a Work Order](Assign_a_Work_Order.md)
- [Complete a Work Order](Complete_a_Work_Order.md)
- [Manage an Internal Work Order](Manage_an_Internal_Work_Order.md)
