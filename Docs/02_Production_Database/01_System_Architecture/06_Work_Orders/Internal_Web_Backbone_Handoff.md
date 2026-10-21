# Work Orders — Internal Web Backbone handoff

| Control | Value |
|---|---|
| Status | IN PROGRESS — source reconciliation in PR #438; Backbone publication unverified |
| Reviewed | 2026-10-21 |
| Source owner | MSB Production Database, #419 |
| Runtime owner | MSB Server Management, #81 |
| Navigation owner | MSB Internal Web Backbone, PR #27 |

## Operator destinations

- Application: https://my.sheboyganlights.org/workorder/
- Canonical SOP portal: [Work Order Operational SOPs](../../02_Operational_SOPs/Work_Orders/README.md).
- Notification instructions: [Work Management Notifications](../../02_Operational_SOPs/Work_Orders/Phase_1_and_Phase_2_Notification_Procedure.md).

Phase 2 V1.1.2-manager-utilities is installed, migrations 002/003 applied and mail
scheduled. See [release evidence](../../../../WorkOrders/Acceptance/Phase_2_Completion_Checkpoint.md).
PR #438 corrects the current instructions; merge it before relying on refreshed
Work Order SOP links. PR #437 separately improves Setup instruction discovery.

## Requested Backbone change

Replace both old Assigned Work Orders and Repair Work Orders from Testing
shortcuts with one recolored **Work Orders** button to `/workorder/` on Apps;
use the same destination on Production. This is Greg's latest direction and
supersedes the old retain-Testing-shortcut instruction. The application owns
Manager/Crew views. Keep Testing runtime, records, Flows and authorization intact.

Do not duplicate SOP content, expose engineering history as normal task choices,
change identity/authorization, or redeploy the Work Orders service for this edit.
Backbone PR #27 owns source, visible page versions, live-file reconciliation,
controlled publication and protected-browser acceptance. The supplied live Apps
blob hash was `c43abe79e54223101d3819b9f9b23e64bd807204`; it differed from the
then-current Git source and is not publication proof.

## Verification and return handoff

Verify exactly one Work Orders button, requested color, correct protected URL,
working canonical SOP links and preserved unrelated navigation on each affected
page. Record the deployed page versions and live result in Backbone #27, then
return that evidence to this handoff and #419 before marking navigation VERIFIED.
All-event mail receipt coverage and long-running worker observation remain
separate operational follow-up; do not claim them from a portal publication.
