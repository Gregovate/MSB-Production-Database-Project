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

A future automatic indexer should be able to discover current SOPs by scanning `02_Operational_SOPs/`, reading the Document Control table, and following the README portal structure.

## SOP Template

```markdown
# Task Name

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
```

## Writing Goal

A volunteer should be able to open the procedure, understand whether it is the right procedure, and begin the task without first learning the underlying database architecture.
