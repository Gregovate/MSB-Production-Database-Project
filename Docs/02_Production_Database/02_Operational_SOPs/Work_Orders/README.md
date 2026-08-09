# Work Order Operational SOPs

Use this page to go directly to the Work Order task you are doing now.

## Work Order Flow

A Work Order can enter the system in either of two ways:

1. **Work Order Request Form** -> manager triage -> active Work Order
2. **Automatically from a Test Session** -> active Work Order

A Work Order created automatically from a Test Session does **not** go through Work Order Intake triage.

After an active Work Order exists, the normal workflow is:

**Assign Work Order -> perform the work -> add Completion Notes -> mark Complete -> save**

If the Work Order was created automatically by a Test Session, that Work Order must be completed before the related container Test Session can be closed.

## Public Work Order Request Instructions

The [Submit a Work Order Request](Submit_a_Work_Order_Request.md) procedure is **public-facing**. The Work Order Request is available from the top of `my.sheboyganlights.org` and may be used by anyone without Directus or Production Database access.

The procedure documents both current form paths:

- Park
- Workshop

It also includes a plain-language reference for the numbered Priority field. The submitted Priority is an intake estimate; a manager reviews it and assigns the correct Work Order Urgency during triage.

### MSB Backbone Reference

The MSB Backbone repository should link to the authoritative public procedure rather than duplicate its instructions.

**Canonical repository path:**

`Docs/02_Production_Database/02_Operational_SOPs/Work_Orders/Submit_a_Work_Order_Request.md`

**Suggested public link text:** **Work Order Request Instructions**

## What Do You Need To Do?

| I want to... | Go to |
|---|---|
| Report a problem or request work | [Submit a Work Order Request](Submit_a_Work_Order_Request.md) |
| Review and triage a submitted request | [Triage a Work Order Request](Triage_a_Work_Order_Request.md) |
| Assign a Work Order to one or more volunteers | [Assign a Work Order](Assign_a_Work_Order.md) |
| Find and work an assigned Work Order | [Work an Assigned Work Order](Work_an_Assigned_Work_Order.md) |
| Complete a Work Order | [Complete a Work Order](Complete_a_Work_Order.md) |
| Choose urgency or target year | [Urgency and Target Year Reference](Urgency_and_Target_Year_Reference.md) |

The task-sized procedures above are **CURRENT** and are the released procedures for the current Work Order workflow.

## Known Follow-Up

The public Google Work Order Request form has an attached **Apps Script**. Before changing question titles, answer values, or branching behavior, inspect that script for dependencies on the current form structure.

A future form improvement is to add the urgency meanings directly beside the numbered Priority field while preserving the values expected by the existing intake process and attached Apps Script.

This form improvement is not required to complete the documentation audit.

## Archived Legacy SOPs

The former lettered Work Order documents have been removed from normal operator navigation and preserved under:

`archive/operational_sops/Work_Orders/`

The archived long-form SOP is historical reference only. The CURRENT task-sized procedures on this page are authoritative for normal operations.

## Related Operational Procedures

- [Test Session Operational SOPs](../Test_Sessions/README.md) — display repairs created from testing
- [Production Database Operational SOPs](../README.md)

## Related Engineering

These links are for readers who want to understand how the Work Order system works. They are not required for normal Work Order tasks.

- [Work Orders Engineering Handoff](../../01_System_Architecture/06_Work_Orders/README.md)
- [Testing System Engineering Handoff](../../01_System_Architecture/05_Testing_System/README.md)
