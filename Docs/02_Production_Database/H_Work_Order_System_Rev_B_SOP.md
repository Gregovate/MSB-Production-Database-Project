# MSB Work Order System — Operational SOP (Volunteers + Managers) (v3)

**Project:** MSB Production Operations Database  
**Owner:** Production Crew  
**Status:** Approved for rollout  
**Scope:** How people report problems, receive work, perform repairs, navigate tasks, and close work orders.

---

## 1) What a Work Order Is (for humans)

A Work Order tracks any task that requires organized work, including:

- Display repairs
- Build or setup tasks
- Shop or facility issues
- Equipment problems
- Planning items for future seasons

Work orders ensure nothing is forgotten and everyone knows what work exists and what has been completed.

---

## 2) How Work Enters the System

Work orders are created through controlled processes to ensure accurate information, proper prioritization, and clear accountability.

Most new work begins as a Work Order Request submitted through the **Work Order button on the MSB portal (my.sheboyganlights.org)**. These requests are reviewed by managers and promoted into formal work orders when action is required.

Additional work orders may be generated automatically by testing workflows or created directly by authorized managers for planned or operational tasks.

### 2.1 Problem Reporting (Google Form)

Volunteers report issues using the official reporting form.

Examples:

- Display not powering on  
- Broken frame  
- Loose wiring  
- Facility problem  
- Safety concern  
- Missing parts  
- Issue found during testing  

This creates an **Intake Record**, not a work order.

---

### 2.2 Automatic Creation from Testing

During display testing inside a container, marking a test status as:

**REPAIR W/O**

automatically creates a repair work order.

Volunteers do not manually create repair work orders from testing.

---

### 2.3 Manager-Created Work Orders

Managers may create work orders directly for planned work, infrastructure tasks, or operational needs.

---

## 3) Triage (Managers Only)

 [Work Order Intake](https://db.sheboyganlights.org/admin/content/work_order_intake)

The Work Order Intake table is a temporary triage queue.

Items remain there only while they are still under review.

After triage:
- **Delete** removes the request from intake
- **Promote** creates a work order and removes the intake record
- **Submitted** keeps the request in the intake queue for later review

Because of this, the intake table normally contains only requests that are still pending manager action or intentionally being held for later review.

All Work Order Requests are reviewed by managers before becoming operational tasks.

Requests typically enter the system through the public Work Order Request form available from:

https://my.sheboyganlights.org → Work Order button

### 3.1 Intake Notification

When a request is submitted:

• The request is stored in the Work Order Intake system  
• A triage notification email is automatically sent to managers  
• The email includes a direct link to the intake record  

Managers should review new requests promptly.

---

### 3.2 Purpose of Triage

Triage ensures requests are:

- Valid and actionable  
- Location (Stage OR Work Area) defined and correct  
- Related display identified (if applicable)  
- Task Type appropriate  
- Problem statement clear and concise  
- Notes added when needed  
- Work Area or Stage accurate  
- Appropriately prioritized (Urgency)  
- Target Year set for planning items  
- Ready for assignment  

No work should be assigned until triage is complete.

---

### 3.3 Triage Outcomes

Managers review each request and select one of the following outcomes:

### A) Delete

The request is removed when no action is required.

Typical reasons include:

- Duplicate request  
- Invalid or unclear report  
- Already resolved  
- Not actionable  
- Submitted in error  

Once deleted, the request does not enter the work order system.

---

### B) Submitted

The request remains in the intake queue for later review.

Use this status when:

- More information is needed  
- The issue is acknowledged but not yet scheduled  
- The manager is deferring a decision  
- The request is valid but low priority  

Submitted requests may be promoted later.

---

### C) Promote

The request is approved and converted into a formal Work Order.

Promotion creates the operational task that can be assigned, worked, and completed.

Only promoted items become active work orders.

---

## 4) Work Order Creation (Promotion)

When a report is promoted, a structured Work Order is created automatically.

This Work Order becomes the official task record used by volunteers and managers.

Key information includes:

- Location (Stage OR Work Area)  
- Task Type  
- Problem description  
- Supporting notes  
- Urgency (if known)  
- Related display (if applicable)  
- Target Year (for planning items)  
- Source reference to the original request  

---

### 4.1 Location Rule

Every work order must reference exactly one location:

• **Stage** — for issues on show stages  
• **Work Area** — for shop, storage, office, or facility tasks  

Both are not required and would be confusing in most situations.

---

### 4.2 After Promotion

Once promoted:

• The Work Order enters the operational system  
• Managers may assign the work immediately or later  
• Volunteers can work and update the task  
• Completion tracking becomes available  

The work order intake table will be empty when all work order requests have been prcesses exldueing submitted

## 5) Assignment (Managers Only)

Managers assign work orders based on operational needs, including:

- Skill and experience  
- Availability  
- Priority and urgency  
- Dependencies on other tasks  
- Safety considerations  
- Required tools or materials  

Assignments may occur immediately after promotion or later as planning evolves.

Multiple volunteers may be assigned to the same work order if appropriate.

### 5.1 Assignment Notification

When a work order is assigned:

• Assignment notification emails are automatically sent to the assigned person(s)  
• The email includes a direct link to the work order  
• The link opens the task in the operational system  

If a work order is already completed, additional assignments should not trigger notifications.

---

## 6) Working a Work Order (Everyone)

Assigned volunteers investigate and perform the work described.

Typical actions include:

- Inspecting the issue  
- Performing repairs or tasks  
- Testing the result  
- Updating notes with findings  

Progress notes should be brief but specific.

Examples of useful notes:

- “Replaced blown fuse and retested OK.”  
- “Broken solder joint repaired on controller output.”  
- “Connector cleaned; intermittent fault resolved.”  
- “Requires replacement part — ordered.”  

Notes help future volunteers understand what has already been attempted.

---

## 7) Completing a Work Order (Everyone)

When work is finished:

1) Open the work order  
2) Enter completion notes describing what was done  
3) Check **Repair Complete**  
4) Save the record  

The system automatically records:

• Completion date and time  
• Person completing the work  

Completion notes are required because future repairs often depend on historical information.

Examples:

- “Replaced failed power supply and verified operation.”  
- “Repaired broken wire at base and sealed connector.”  
- “Rebuilt frame support and reinstalled sign mount.”  

---

## 8) Automatic Repair Loop from Testing

Some work orders originate from container display testing.

When a tester marks a test result as:

**REPAIR W/O**

the system automatically generates a repair work order linked to the testing record.

When that repair work order is completed:

• The testing system is updated automatically  
• The test status changes to reflect the successful repair  
• Repair notes are preserved with the testing history  

Volunteers do not need to manually update testing records after completing the repair.

---

## 9) Navigation and Finding Work

The operational system contains many data tables. Users should rely on curated navigation tools rather than browsing raw data.

### Volunteers typically use:

- [Aging Repair Work Orders](https://db.sheboyganlights.org/admin/content/work_order?bookmark=104)
  - System Generated Work Orders from Testing
  - No Completion Date
  - Sorted from Oldest to Newest
- [Work Orders with Assignments](https://db.sheboyganlights.org/admin/content/work_order?bookmark=100)
  - List is sortable by Assignee
  - Work order may appear more than once if assigned to multiple people
- Personal bookmarks  
- Filtered task views  
- Testing workflows  

Volunteers are not expected to navigate all the work orders.

---

### Managers typically use:

- [Work Order Intake](https://db.sheboyganlights.org/admin/content/work_order_intake)
- [All Unassigned Work Orders](https://db.sheboyganlights.org/admin/content/work_order?bookmark=105) 
- Urgent work views  
- Custom filters and bookmarks  

---

## 10) Urgency and Target Year

### 10.1 Urgency Codes

Urgency indicates how quickly work should be addressed:

1 — Immediate / critical  / Most used for weather disasters during the show
2 — High  
3 — Normal  
4 — Low  
5 — Planning

Leave blank if unsure; managers may adjust during triage.

---

### 10.2 Target Year

Target Year identifies planning work intended for a future season.

Examples:

- Major rebuild planned for next year  
- Deferred maintenance  
- New display construction  

Planning items may have low urgency but still require tracking.

---

## 11) Manager Review Practices

### Daily (during active season)

Managers should:

- Review new intake requests  
- Check urgent work orders  
- Monitor unassigned tasks  
- Resolve blockers  
- Follow up on incomplete repairs  

---

### Periodic (off-season or planning periods)

Managers should:

- Review Target Year planning items  
- Close outdated or resolved tasks  
- Ensure completion notes are adequate  
- Clean incorrect or duplicate records  

---

## 12) System Behavior Summary

Current operational capabilities include:

• Intake via Google Forms  
• Manager triage workflow  
• Promotion to formal work orders  
• Manager assignment of tasks  
• Automated notifications for assignments  
• Automatic creation of repair work orders from testing  
• Completion tracking with audit history  

The system is designed to ensure:

- Work is not lost  
- Responsibilities are clear  
- Progress is visible  
- Historical repairs are documented  

---

## Change Log

### 2026-03-14 — Operational Model Shift to Intake → Triage → Promotion

Major redesign of how work enters the system.

Key changes:

• Work orders now originate primarily from Google Form intake  
• Managers must triage all intake requests before work begins  
• Only promoted requests become operational work orders  
• Intake notifications sent automatically to managers  
• Intake records remain separate from operational tasks  

Operational impact:

• Volunteers report problems without needing to structure tasks  
• Managers control prioritization and data quality  
• Reduces duplicate or unclear work orders  

---

### 2026-03-13 — Assignment Workflow and Notifications Implemented

Assignment capabilities added to operational workflow.

Key changes:

• Managers can assign one or more volunteers to a work order  
• Assignment emails sent automatically upon save  
• Direct links provided for quick task access  
• Notifications suppressed for already-completed work  

Operational impact:

• Volunteers receive clear direction without searching the system  
• Managers retain flexibility to assign immediately or later  

---

### 2026-03-12 — Testing Integration Activated

Repair workflow integrated with container display testing.

Key changes:

• Test result **REPAIR W/O** automatically creates a repair work order  
• Repair completion updates testing status automatically  
• Repair notes preserved in testing history  

Operational impact:

• Eliminates manual transfer of repair information  
• Creates a closed loop between testing and repairs  
• Ensures no repair items are lost  

---

### 2026-03-10 — Completion Tracking Standardized

Completion workflow updated for reliability and audit accuracy.

Key changes:

• Repair Complete checkbox controls closure  
• Completion timestamp recorded automatically  
• Completing user recorded automatically  
• Manual backfill allowed for historical repairs  

Operational impact:

• Prevents undocumented “silent closures”  
• Improves long-term maintenance history  

---

**End Operational SOP**