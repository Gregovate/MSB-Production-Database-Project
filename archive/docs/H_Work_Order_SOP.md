# MSB Work Order System — Operational SOP (Volunteers + Managers) (v1)
**Project:** MSB Database (Production Ops)  
**Owner:** Greg (Production Crew)  
**Status:** Final — approved for rollout once DB UI is live  
**Scope:** How people use the work order system day-to-day. (No database internals.)

---

## 1) What a Work Order is (for humans)
A Work Order is how we track any work item, including:
- Display repairs
- Setup/build tasks
- Facility issues (ramps, roofs, doors, etc.)
- Shop tasks (dust collector, tools, benches)
- Office/admin tasks
- Planning items (target year)

Work orders prevent “tribal knowledge” and make sure nothing is lost.

---

## 2) Who can do what
### 2.1 Everyone (authenticated users)
- Can create work orders
- Can add notes/progress
- Can complete work orders they finish

### 2.2 Managers (ref.person.manager = true)
- Everything above, plus:
- Can assign work orders (at creation or later)
- Can triage and prioritize

---

## 3) Creating a Work Order (Everyone)
### 3.1 Create steps
1) Open Work Orders
2) Click **New Work Order**
3) Pick the location:
   - If it’s on a park stage: select the **Stage**
   - If it’s not on a stage: select the **Work Area** (Office, Wood Shop, Command Center, Food Bank Facility, etc.)
4) Select **Task Type** (Repair / Build / Setup / Design / etc.)
5) Enter:
   - **Problem** (what’s wrong / what needs to be done)
   - **Notes** (details: what you saw, conditions, suspected cause)
6) Optional fields:
   - **Display** (if it’s display-related)
   - **Photo link** (if you have one)
   - **Urgency** (if you know it; otherwise leave blank)
   - **Target Year** (if this is a plan item)

7) Click **Save**

### 3.2 Location rule (important)
A work order must have exactly one location:
- Stage OR Work Area (not both)

---

## 4) Assigning Work Orders (Managers only)
### 4.1 Assign at creation time
If a manager is creating the work order and already knows who should do it:
- add assignee(s) before saving.

### 4.2 Assign after creation
Managers regularly review:
- Unassigned Open work orders
- Urgent Open work orders
- Target Year plan lists

Then assign work accordingly.

---

## 5) Working a Work Order (Everyone)
### 5.1 Add progress notes
As you investigate or work:
- add/update notes with what you tried and what you found.
- keep it brief but specific (parts replaced, connectors cleaned, tests run).

### 5.2 Good note examples
- “Found broken solder joint at controller output 7. Reflowed. Retested OK.”
- “Replaced fuse with 5A. Suspect short near prop base. Needs follow-up.”
- “Dust collector bag full; emptied and checked filter. Airflow restored.”

---

## 6) Completing a Work Order (Everyone)

### 6.1 Completion workflow

When you finish the work:

1) Open the work order
2) Enter **Completion Notes** (what was done)
3) Check **Repair Complete**
4) Save

When **Repair Complete** is checked, the system automatically records:

• `date_completed` = current date/time  
• `completed_by_person_id` = the logged-in user

This happens automatically in the database.

If a historical repair is being backfilled, managers may manually enter the completion date and person before checking **Repair Complete**. The system will **not overwrite existing values**.

---

### 6.2 Completion notes requirement

Completion notes are required because “done” without details is useless for future repairs and training.

Examples:

- “Replaced failed SSR board on channel 3. Retested OK.”
- “Repaired broken wire at prop base and resealed connector.”
- “Replaced 4 LED strings and verified full sequence test.”

---

## 7) Automatic Display Repair Workflow

Some work orders are created automatically from the **display testing system**.

When a tester marks a display test result as:


REPAIR


the system automatically creates a repair work order.

When that repair work order is completed:

1. The system detects the completion automatically.
2. The associated testing record is updated.
3. The display test status changes to:


OK_REPAIRED


The testing notes are updated to include the repair notes while preserving the original testing notes.

This creates a closed repair loop between:


Testing → Repair Work Order → Completed Repair → Testing Updated


Volunteers do **not** need to update the testing system manually after a repair.

---

## 10) System Status

Current operational capabilities:

• Work order creation  
• Work order completion tracking  
• Automated display repair workflow from testing  
• Automatic completion stamping via database trigger  

Work still in development:

• Manager assignment workflow improvements  
• Email notifications for assigned work orders  
• Intake integration with legacy Google Forms  

The repair workflow between **display testing and work orders is fully operational.**

---

## 7) Urgency vs Target Year (How to use them)
### 7.1 Urgency (1–4)
Use when it needs near-term attention:
- 1 = immediate / show-stopper
- 2 = high
- 3 = normal
- 4 = low

Leave blank if you’re unsure (manager can triage later).

### 7.2 Target Year (e.g., 2026)
Use for planning items:
- “Rebuild for 2027”
- “Replace worn frames in 2026”
It may have no urgency — that’s fine.

---

## 8) Suggested Manager routines
### Daily (in-season)
- Review “Urgent Open”
- Review “Unassigned Open”
- Assign work and follow up on blockers

### Weekly
- Review “Target Year plan” lists
- Close stale items or add clarifying notes
- Ensure completed items have good completion notes

---

## 9) Rules of thumb (keeps the system clean)
- If it’s display-related, link the display if possible.
- Use Stage when the issue is on a stage; use Work Area otherwise.
- Don’t assign unless you’re a manager.
- Always complete with completion notes.

---

## Change Log

This document reflects the operational procedures for volunteers and managers using the MSB Work Order System.

---

### 2026-03-10 — Repair Workflow Operational + Testing Integration

Operational procedures updated to reflect the completed repair workflow integration.

Key changes:

• Work order completion now uses **Repair Complete checkbox** instead of a manual "Complete" button  
• Completion date and user identity are automatically recorded by a PostgreSQL trigger  
• Historical repairs may be backfilled without overwriting manually entered completion data  

Display testing integration:

• Display testing automatically generates repair work orders when a test result is `REPAIR`  
• Completing the repair work order automatically updates the testing record  
• `display_test_session.test_status` automatically updates to `OK_REPAIRED`  
• Repair notes are prepended to the testing record while preserving original test notes  

Operational impact:

• Volunteers only need to enter **completion notes** and check **Repair Complete**  
• No manual updates to the display testing system are required after repairs  
• Repair tracking is now fully automated between testing and work order systems  

System status: **Repair workflow operational. Assignment and notification workflow still under development.**

---

**End Operational SOP**