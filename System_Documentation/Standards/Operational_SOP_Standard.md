# Operational SOP Standard

## Purpose

This standard defines how MSB operator procedures are created, named, placed, written, illustrated, and linked so they are easy for volunteers to use and can be indexed automatically in the future.

Operational SOPs explain **how to perform a task**. They do not replace engineering architecture or implementation documentation.

## Where SOPs Belong

Operator procedures for the Production Database belong under:

```text
Docs/02_Production_Database/02_Operational_SOPs/
```

Create or use a task-area folder beneath that portal, for example:

```text
02_Operational_SOPs/
├── Displays/
├── Label_Printing/
├── Test_Sessions/
└── Work_Orders/
```

Do not place an operator procedure inside `01_System_Architecture/` merely because the procedure uses a database feature, Directus Flow, trigger, or application.

Each task-area folder should have a `README.md` portal when it contains more than one procedure or when the folder represents an ongoing operational area.

## Operator Navigation Boundary

The normal browsing path for operators must remain operational by default.

An operator moving through README portals should normally follow:

```text
Operational SOP portal -> task-area portal -> plain-language task procedure
```

Do not place engineering documents, SQL procedures, trigger documentation, architecture handoffs, implementation notes, or other technical references in the normal operator procedure-selection table.

Engineering material may still be linked when it is useful to someone who wants to understand how the system works. Put those links in a clearly labeled section such as **Related Engineering** or **Related Documents**, separate from the normal task-navigation table.

The operator should have to deliberately choose to leave the operational documentation path and enter engineering documentation.

This boundary applies even when the engineering document describes the database behavior behind the operator task. The operator portal should answer **What do I need to do?**, while engineering navigation answers **How does this system work?**

## Task Granularity and Workflow Portals

Prefer one plain-language procedure for each real operator task or decision point rather than one large end-to-end manual when the workflow can be safely divided.

A task-area `README.md` should act as the workflow map. It should help the operator answer **What am I trying to do right now?** and lead directly to the appropriate short procedure.

For example, a testing workflow may have separate procedures for starting a test session, testing displays, handling a repair, refreshing the displays to test, resuming deferred work, and finishing a container.

Each procedure should contain enough information to complete its task without requiring the operator to read the entire workflow documentation first. Use Related Documents to connect the procedures in the normal sequence.

Do not split a task so finely that an operator must constantly switch documents to complete one normal action. The goal is understandable task-sized instructions, not the largest or smallest possible number of files.

## Workflow Navigation Inside Procedures

When a task area contains a sequence of related procedures, each procedure must make it easy to move through that workflow without returning to the GitHub folder view.

Place a compact navigation line near the **top** of the procedure and repeat it at the **bottom**.

Use this pattern when applicable:

```markdown
[← Previous: Previous Task](Previous_Task.md) | [↑ Test Sessions Home](README.md) | [Next: Next Task →](Next_Task.md)
```

Navigation rules:

- **Previous** returns to the preceding task in the documented workflow.
- **Home** returns to the task-area `README.md` portal.
- **Next** moves to the next task or reference in the documented workflow.
- The top and bottom navigation should use the same destinations.
- Do not force a false linear sequence where the workflow branches. For a branch task, use the most useful return/continuation destination and keep the task-area portal available in the middle.
- Reference documents may participate in the browse sequence when that makes the documentation easier to review, but they should not be presented as mandatory operational steps unless they truly are required.
- Manager-only procedures should not be inserted into the normal volunteer previous/next sequence unless the workflow actually requires a manager handoff.

A reader should be able to move to the previous task, return to the task-area portal, or continue to the next task from either end of a procedure.

## Print and Hard-Copy Usability

Operator procedures should be usable both digitally and as printed hard copies when practical.

A printed procedure cannot depend on clickable navigation to explain the task. The core instructions needed to perform the task must appear in the procedure itself.

For procedures likely to be printed:

- use a clear task title;
- state the purpose and intended audience;
- list anything required before starting;
- keep numbered actions in the order performed;
- make warnings and required values easy to find;
- state what successful completion looks like;
- keep essential instructions complete even when links are unavailable on paper;
- place Related Documents at the end for digital navigation and follow-up work.

Screenshots may be used when they materially help the operator identify a screen, field, or action, but a procedure should not become unusable solely because a screenshot prints poorly or is unavailable.

## Required Document Control

Every current SOP should begin with a short Document Control table using these exact field names:

| Document Control | Value |
|---|---|
| Document Type | Operational SOP |
| System | Name of the system or subsystem |
| Task | Short description of the operator task |
| Audience | Intended operator or volunteer group |
| Status | CURRENT, DRAFT, or RETIRED |
| Owner | Person or role responsible for the procedure |
| Last Reviewed | YYYY-MM-DD |
| Keywords | Comma-separated search terms |

These fields are intentionally consistent so a future documentation indexer can identify current procedures without depending only on filenames.

### Status Rules

- `CURRENT` — approved procedure for present use.
- `DRAFT` — being written or tested; not yet the authoritative operator procedure.
- `RETIRED` — retained only when there is a reason to preserve it outside the archive.

Superseded procedures should normally be moved to the archive rather than left mixed with current operator instructions.

## Required SOP Structure

Use the sections below when they apply. Do not add empty sections merely to satisfy the template.

### 1. Purpose

State what the task accomplishes and when the operator would use the procedure.

### 2. Before You Start

List prerequisites that matter to the operator, such as required access, information, physical items, or another task that must already be complete.

Do not include engineering prerequisites the operator does not need to know.

### 3. Procedure

Write numbered steps in the order the task is actually performed.

- One operator action per step whenever practical.
- Use the labels and names the operator sees on screen.
- Use **bold** for buttons, fields, menu entries, and required values when it improves scanning.
- Explain why only when the explanation prevents a likely mistake.
- Do not bury required actions inside long paragraphs.

### Operator Language

Use the exact system or interface term when the operator needs to recognize it on screen, but explain what it means in plain language the first time the meaning matters.

For example, keep field names such as **Display ID**, **Container ID**, **Frame ID**, and **Print Label** because those are the names shown in Directus. Avoid unnecessary engineering language when a simpler operator description is enough.

When screenshots show greyed-out fields that are read-only, say so when that prevents the operator from trying to edit them.

### 4. Expected Result

Tell the operator how to recognize successful completion.

### 5. If Something Is Wrong

Include only likely failure conditions and the safe next action. Link to a troubleshooting procedure when troubleshooting becomes substantial.

### 6. Related Documents

Link to related operator procedures and, when useful, the responsible engineering subsystem. Do not duplicate engineering detail in the SOP.

## Screenshots

Follow [Working with Screenshots](../../Docs/0_Contributing/13_Working_with_Screenshots.md) for image storage and screenshot practices.

Documentation images are stored in the shared:

```text
Docs/images/
```

A screenshot should support a specific nearby instruction. Avoid placing a collection of screenshots at the end of a document without explaining what each one shows.

Use descriptive alternative text:

```markdown
![Directus Display menu](../../../images/directus-display-menu.png)
```

The relative path must be calculated from the SOP's actual folder location.

## Naming SOP Files

Use a descriptive task name that tells the reader what the procedure accomplishes.

Preferred examples:

```text
Complete_Display_Metadata_After_LOR_Import.md
Complete_Work_Order.md
Print_Container_and_Display_Labels.md
```

Do not depend on a letter or number prefix to explain what the file contains. Existing lettered procedures may remain until they are naturally revised.

## Portal and Indexing Requirements

When adding a new current SOP:

1. Place it under the correct `02_Operational_SOPs/<Task_Area>/` folder.
2. Add or update that task area's `README.md` so the procedure is directly discoverable.
3. Update `02_Operational_SOPs/README.md` when a new task-area folder is introduced.
4. Use the required Document Control fields.
5. Use a clear H1 title and descriptive filename.
6. Add meaningful `Keywords` for likely operator searches.
7. Verify all relative links and images.
8. Keep engineering detail in the responsible engineering documents and link to it when useful.
9. Keep the normal operator browse path operational; place engineering links in a separate related-information section rather than the task-selection table.
10. For multi-step workflow documentation, add previous/home/next navigation at both the top and bottom of each task procedure.

A future automatic indexer should be able to discover current SOPs by scanning `02_Operational_SOPs/`, reading the Document Control table, and following the README portal structure.

## SOP Template

```markdown
# Task Name

[← Previous: Previous Task](Previous_Task.md) | [↑ Task Area Home](README.md) | [Next: Next Task →](Next_Task.md)

| Document Control | Value |
|---|---|
| Document Type | Operational SOP |
| System | Production Database — Subsystem |
| Task | What the operator is doing |
| Audience | Operators / Volunteers / Managers |
| Status | CURRENT |
| Owner | Responsible role |
| Last Reviewed | YYYY-MM-DD |
| Keywords | keyword one, keyword two, keyword three |

## Purpose

Briefly explain what this procedure accomplishes.

## Before You Start

- Required access or information
- Required prior task, if any

## Procedure

1. First operator action.
2. Second operator action.
3. Continue in task order.

## Expected Result

Describe what success looks like.

## If Something Is Wrong

Describe the safe next action for likely problems.

## Related Documents

- [Related procedure](relative-link.md)
- [Engineering subsystem](../../01_System_Architecture/subsystem/README.md)

---

[← Previous: Previous Task](Previous_Task.md) | [↑ Task Area Home](README.md) | [Next: Next Task →](Next_Task.md)
```

## Writing Goal

A volunteer should be able to open the procedure, understand whether it is the right procedure, and begin the task without first learning the underlying database architecture.
