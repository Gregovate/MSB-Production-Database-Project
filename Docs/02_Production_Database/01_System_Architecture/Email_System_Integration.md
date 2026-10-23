# Email System Integration

| Document Control | Value |
|---|---|
| Document Type | Cross-system engineering integration contract |
| Status | CURRENT ownership; separate deployed senders remain pending consolidation |
| Owner | Production Database engineering — consumer/data integration |
| Shared email-system owner | MSB Server Management engineering |
| Last Reviewed | 2026-10-22 |

## One email-system owner

[MSB Email System Engineering](https://github.com/Gregovate/MSB-Server-Management/blob/main/docs/server/MSB_Email_System_Engineering.md) is the single authority for shared email delivery. [Server Management #97](https://github.com/Gregovate/MSB-Server-Management/issues/97) owns its unfinished consolidation and cross-consumer reliability work. Greg directed this ownership correction on October 22, 2026.

Setup #205 and Work Management #419 own notification business behavior, not independent mail platforms. #122 coordinates Setup launch/release effects; it does not own the organization-wide email service. Server #81 owns Work Management runtime, not all email. Printer alerts (#96 / LabelPrintService #36) are another consumer of the same authority.

## Database and application responsibilities

This repository retains authoritative PostgreSQL identities, business events, recipient eligibility, templates/content, ticket/task links, application authorization, business audit and schema/functions/migrations. The shared owner defines delivery semantics; Database engineering implements any required PostgreSQL contracts here. Shared objects remain indexed through [Database Foundation](01_Database_Foundation/README.md).

Applications consume truthful delivery outcomes and make failures visible. Notification links do not create accounts or grant permissions. No fake Work Orders/Intake records may be created to send Setup reminders or printer alerts.

**Relationship class:** external supporting service. PostgreSQL remains authoritative for business records; the existing receipt/claim stores remain delivery evidence until deliberately migrated. Email unavailability does not erase business records, complete work or transfer lifecycle ownership. Work Management remains year-round and independent of Setup.

## Current compatibility implementations

- Setup daily digest source remains in `Setup/Acceptance/manager_mail_pilot/`, with existing private installed files, seasonal schedule and filesystem receipts. See [October22 engineering evidence](12_Setup_and_Deployment/engineering/Setup_205_Manager_Mail_Recovery_2026-10-22.md).
- Work Management transport currently remains in `WorkOrders/Application/mail_delivery.py`, `mail_store.py` and `mail_worker.py`, backed by migration003. See [Work Order engineering](06_Work_Orders/Work_Order_System_Design.md).
- These are existing implementations under the shared owner, not proof that a common sender is deployed. Do not move source or migrate delivery state solely because ownership changed.
- Earlier Setup Directus proposals and Work Order-specific transport descriptions are historical/consumer details where they conflict with the October22 shared ownership decision. Current business requirements and recorded acceptance remain preserved.

## Change and release coordination

Read the canonical Server Management authority before introducing or changing shared delivery/retry/queue/recovery mechanisms. Coordinate that work under #97, and retain consumer-specific work under #205/#419. Do not fork another transport implementation or revive a retired duplicate Directus mail path.

The shared authority owns the failure-state/retry contract and consolidation acceptance; this file does not duplicate those policies. Preserve all existing receipts, event identities, approved audiences and non-mail Flow behavior through a reviewed per-consumer cutover.

Active PR #418/#413 digest content work must retain its scope and reconcile newer accepted reliability fixes; its previous mail-ownership wording does not create a second shared system owner.

This documentation change authorizes no Production migration, sender/timer/Flow change, outbound message or resend. Consolidation implementation and Production acceptance remain tracked under #97.

## Related engineering

- [System architecture portal](README.md)
- [Setup engineering](12_Setup_and_Deployment/engineering/README.md)
- [Work Orders engineering](06_Work_Orders/README.md)
- [Canonical shared email authority](https://github.com/Gregovate/MSB-Server-Management/blob/main/docs/server/MSB_Email_System_Engineering.md)

## Revision history

| Date | Change |
|---|---|
| 2026-10-22 | Established consumer/data boundary and reciprocal link to the single Server Management email owner. |
