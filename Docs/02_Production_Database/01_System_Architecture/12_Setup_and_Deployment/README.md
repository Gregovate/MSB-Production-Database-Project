# Setup and Deployment

| Document Control | Value |
|---|---|
| Document Type | Operator / User Portal |
| System | Production Database — Setup and Deployment |
| Audience | MSB reviewers, managers, and Setup operators |
| Status | CURRENT |
| Owner | MSB Production Database / Setup administrator |
| Last Reviewed | 2026-09-22 |
| Keywords | Setup, reusable task, verification, Display Ownership, Kit, Extra Materials, T-Post, prerequisites |

Use this page to decide **what you are trying to do in Setup** and where to go next.

## Open Setup

```text
https://my.sheboyganlights.org/setup/
```

The current shared review is **2025 — Historical Verification** and uses real Production data.

There is not yet a real 2026 Setup Session. The work now is to clean up the reusable Setup tasks so the 2026 schedule starts with good information.

## What Do You Need to Do?

| I need to... | Start here |
|---|---|
| Finish reviewing tasks that still need work | [Review and Correct the 2025 Setup History](operatorSOP/Review_2025_Setup_History.md) |
| Learn the Setup Manager controls | [Setup Manager Review Guide](../../02_Operational_SOPs/Setup/Setup_Session_Manager_Review_Guide.md) |
| Review what should be in a Kit | Open **Kit Inventory** from Setup |
| Count or correct T-Post stock | Open **T-Post Inventory** from Setup |
| Review a current Setup procedure | Open the procedure shown for the selected task |
| Change task order | Drag the task to where it belongs |
| Add a prerequisite | Hold **Shift** and drag the later task onto the task that must happen first |
| Assign many Displays to the correct task | Open **Display Ownership**, select several Displays, and move them together |

## Fast Things Worth Knowing

### Reorder tasks by dragging

To change the normal task order, **drag the task to where it belongs**.

**Do not renumber every task by hand.**

Normal drag = move/reorder a task.

### Add a prerequisite with Shift-drag

A prerequisite is work that must happen before another task can start.

1. Hold **Shift** before pressing the mouse button.
2. Start with the **later task**.
3. Drag it onto the **task that must happen first**.
4. Release.

**Normal drag = move a task.**  
**Shift-drag = add a prerequisite.**

### Copy a similar task

Use **Copy** / **Copy Task** when you need a new task that is similar to an existing one.

A copied task is only a starting point. Open the new task and review its name, Stage/Scene, crew, time, readiness, weather, completion point, notes, resources, materials, and other details before treating it as finished.

## Before You Mark a Task Verified

Use the **Verification Queue** and choose **Unverified** to find work that still needs review.

Before clicking **Mark Verified**, ask:

- Should this task exist every year?
- Is **Active Reusable Task** correct? If normal yearly work is inactive, it will not be included when a future Setup Session is created.
- Is the normal crew size entered?
- Is the expected time entered?
- Are the prerequisites correct?
- Are the needed Displays assigned to the correct task?
- Are the needed Kit Boxes assigned?
- Are Extra Materials and Equipment / Resources complete enough for planning?
- Are the important Setup notes accurate?
- Are the current Setup instructions still correct?

If something is unknown, **do not guess**. Leave it for review or use **Unverified Items / Remainders** where that is the correct place.

## Final Completeness Check — Material Audit

Use **Material Audit** before the real 2026 Setup Session is created.

It checks whether important Setup information is complete. It does **not** decide whether the work itself is correct.

Pay special attention to:

- **Future Session Readiness** — tasks that are not active will not be included in a future Setup Session.
- **Display / LOR Ownership** — Displays that still need to be assigned to the correct Setup Task.
- **Kit Assignment Coverage** — Kits or support Containers that still need a task assignment or a clear review reason, such as shared/bulk stock.

Use the correction button in the audit to go back to the place that needs work.

If the audit shows something that does not make sense, fix the real information. Do not enter a fake assignment just to clear the audit.

## Important Task Fields for Planning

The screen currently uses these field names:

- **Completion point** — **Done when.** What must be true before the Captain can call the task finished?
- **Readiness note** — **Can start when.** What must happen before this task can begin? This matters when work is scheduled.
- **Weather note** — **Weather limits.** Enter weather conditions that can delay or stop the work.
- **Reusable notes** — **Important setup notes.** Keep useful year-to-year warnings, gotchas, and crew knowledge here.

Examples:

- **Readiness note:** Wait until grass cutting is complete before laying cords.
- **Weather note:** Do not use the high lift when wind is over 10 mph.
- **Completion point:** Cords are plugged in and tested.
- **Reusable notes:** Install the Racing Arch harness before the arches. Start with the Y at the outbound end.

Old copy/reconstruction history is not useful Captain information. Clean it out when you know the durable instruction that should remain.

## Display Ownership

Use **Display Ownership** when the same Stage or Scene has more than one Setup Task that works with Displays.

The question is simple:

> Which Setup Task is responsible for each Display?

If there is only one Setup Task using the Displays, you normally do not need to assign them one by one.

To move several Displays at once:

- Click one Display to select it.
- Hold **Ctrl** on Windows or **Cmd** on a Mac and click to add/remove individual Displays.
- Hold **Shift** and click to select a range in the same task column.
- Drag any selected Display to the correct task. The selected group moves together.
- For a large list, use **Move selected to** and **Move selected** instead of dragging a long distance.

When the screen says **Coverage complete**, every Display in that review has a task.

Display Ownership only says which Setup Task is responsible for the Display. It does not move the Display to another Container or change its LOR Stage/Scene.

## Equipment / Resources vs Extra Materials

Use **Equipment / Resources** for tools, equipment, vehicles, and other reusable things needed to do the work.

Examples: pliers, adjustable wrenches, lifts, ToolCat.

Use **Extra Materials Required by This Task** for materials the job needs.

Examples: T-Posts, spacers, bungees, stakes, bases.

### Where the material comes from

**Expected Source Containers** tell the crew where the material should normally be found.

That is different from the task requirement:

- **Task Extra Material** = what the job needs.
- **Expected Source Container** = where the crew should expect to find it.

## Kit Boxes and Kit Inventory

### Kit Boxes

Use **Kit Boxes** on the task to choose the physical Kit that supports the work.

A Kit may support more than one task.

Do not assign the bulk T-Post or spacer stock Containers as Kits just because material comes from them.

### Kit Inventory

Open:

```text
https://my.sheboyganlights.org/setup/kit-inventory/
```

Use Kit Inventory to review what should normally be in a physical Kit.

Keep these two ideas separate:

- **Expected** = what should normally be in the Kit.
- **On Hand** = what somebody actually counted.

**Do not enter an expected quantity as On Hand unless somebody physically counted it.**

If an item is still unclear, leave or update it under **Unverified Items / Remainders** rather than guessing.

The current goal is **review and correction**, not a complete warehouse inventory.

## T-Post Inventory

Open:

```text
https://my.sheboyganlights.org/setup/t-post-inventory/
```

T-Post Inventory is separate from Kit Inventory.

The list separates shared/bulk T-Post stock from T-Posts intentionally stored with a Kit or Display.

Use **Count physical stock** only when somebody is actually counting or adjusting physical stock.

A task can require T-Posts even when those posts come from shared stock instead of a Kit.

## Spacers

Shared/bulk spacer stock is separate from Kit contents.

Some Kits legitimately contain fitted/custom spacers for that work. Do not assume every spacer belongs in the bulk spacer Containers.

## If Something Does Not Make Sense

Do not work around bad information just to make the screen look complete.

If a task, Display assignment, Kit, material requirement, T-Post source, spacer source, or procedure clearly does not make sense, stop and flag it for review.

## More Help

- [Setup operator procedures](operatorSOP/README.md)
- [Review and Correct the 2025 Setup History](operatorSOP/Review_2025_Setup_History.md)
- [Setup Manager Review Guide](../../02_Operational_SOPs/Setup/Setup_Session_Manager_Review_Guide.md)
- [Engineering documentation](engineering/README.md) — for maintainers, not normal operator work
