# Work Order Operational SOPs

Use this page to go directly to the Work Order task you are doing now.

## Public Work Order Request Instructions

The [Submit a Work Order Request](Submit_a_Work_Order_Request.md) procedure is **public-facing** and is intended for anyone using the **Work Order Request** link at the top of `my.sheboyganlights.org`.

It does not require Production Database or Directus access. It documents both current Google Form paths:

- Park requests
- Workshop requests

### MSB Backbone Reference

The MSB Web Backbone should link directly to the public procedure rather than duplicate the instructions.

Canonical document:

`Docs/02_Production_Database/02_Operational_SOPs/Work_Orders/Submit_a_Work_Order_Request.md`

GitHub document target:

`https://github.com/Gregovate/MSB-Production-Database-Project/blob/main/Docs/02_Production_Database/02_Operational_SOPs/Work_Orders/Submit_a_Work_Order_Request.md`

Suggested Backbone link text:

**Work Order Request Instructions**

## Work Order Flow

A Work Order can enter the system in either of two ways:

1. **Work Order Request Form** -> manager triage -> active Work Order
2. **Automatically from a Test Session** -> active Work Order

A Work Order created automatically from a Test Session does **not** go through Work Order Intake triage.

After an active Work Order exists, the normal workflow is:

**Assign Work Order -> perform the work -> add Completion Notes -> mark Complete -> save**

If the Work Order was created automatically by a container Test Session, that Work Order must be completed before the related container Test Session can be closed.

## What Do You Need To Do?

| I want to... | Go to |
|---|---|
| Report a problem or request work | [Submit a Work Order Request](Submit_a_Work_Order_Request.md) |
| Review and triage a submitted request | [Triage a Work Order Request](Triage_a_Work_Order_Request.md) |
| Assign a Work Order to one or more volunteers | [Assign a Work Order](Assign_a_Work_Order.md) |
| Find and work an assigned Work Order | [Work an Assigned Work Order](Work_an_Assigned_Work_Order.md) |
| Complete a Work Order | [Complete a Work Order](Complete_a_Work_Order.md) |
| Choose urgency or target year | [Urgency and Target Year Reference](Urgency_and_Target_Year_Reference.md) |

The public Work Order Request procedure is **CURRENT**. The internal Work Order procedures remain **DRAFT** while the large legacy Work Order SOP is split and checked against the current Directus workflow.

The existing `B_Work_Order_System_SOP.md` remains temporarily as the migration source. It will be archived after all valid operator instructions have been transferred and verified.

## Related Operational Procedures

- [Test Session Operational SOPs](../Test_Sessions/README.md) — display repairs created from testing
- [Production Database Operational SOPs](../README.md)

## Related Engineering

These links are for readers who want to understand how the Work Order system works. They are not required for normal Work Order tasks.

- [Work Orders Engineering Handoff](../../01_System_Architecture/06_Work_Orders/README.md)
- [Testing System Engineering Handoff](../../01_System_Architecture/05_Testing_System/README.md)
