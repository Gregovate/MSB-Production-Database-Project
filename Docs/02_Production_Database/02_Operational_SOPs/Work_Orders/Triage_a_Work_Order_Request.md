# Triage a Work Order Request

[← Previous: Submit a Work Order Request](Submit_a_Work_Order_Request.md) | [↑ Work Orders Home](README.md) | [Next: Assign a Work Order →](Assign_a_Work_Order.md)

| Document Control | Value |
|---|---|
| Document Type | Operational SOP |
| System | Production Database — Work Orders |
| Task | Review and triage a submitted Work Order Request |
| Audience | Managers |
| Status | CURRENT |
| Owner | Production Database Manager |
| Last Reviewed | 2026-09-26 |
| Keywords | work order intake, triage, promote, submitted, delete |

## Purpose

Use this procedure to review a human-reported Work Order Intake record, including the public Work Order Request Form and authenticated Setup **Report Correction**, and decide whether it should become an active Work Order or remain an Intake-only correction finding.

Work Orders created automatically by a Test Session are already active Work Orders and do **not** go through this triage process.

## Procedure

1. Open **Work Order Intake**.
2. Open the request that needs review.
3. Confirm the request is valid and actionable.
4. Review the submitted source context and correct the information needed for the Work Order, including when applicable:
   - Stage or Work Area;
   - related Display;
   - Task Type;
   - problem description;
   - supporting notes;
   - Urgency; and
   - Target Year.
5. For a request that may be promoted, review the submitted Priority and assign the correct Work Order Urgency using [Urgency and Target Year Reference](Urgency_and_Target_Year_Reference.md). Setup Report Correction records may instead be resolved through the responsible Setup/data/Procedure/GIS/engineering surface without promotion.
6. Choose the appropriate triage outcome:
   - **Delete** — no Work Order or retained Intake action is required;
   - **Submitted** — keep the request in intake for later review; or
   - **Promote** — create an active Work Order.
7. Save the record.

## Location Rule

A Work Order uses one operational location: **Stage** or **Work Area**, as appropriate to the task.

## Expected Result

- **Delete** removes a request that should not become work.
- **Submitted** leaves the request in the intake queue.
- **Promote** creates the operational Work Order that can be assigned, worked, and completed.

## If Something Is Wrong

If the request does not contain enough information to make a safe decision, leave it **Submitted** until the missing information is resolved.

## Related Documents

- [Assign a Work Order](Assign_a_Work_Order.md)
- [Urgency and Target Year Reference](Urgency_and_Target_Year_Reference.md)
- [Test Session Operational SOPs](../Test_Sessions/README.md)

---

[← Previous: Submit a Work Order Request](Submit_a_Work_Order_Request.md) | [↑ Work Orders Home](README.md) | [Next: Assign a Work Order →](Assign_a_Work_Order.md)
