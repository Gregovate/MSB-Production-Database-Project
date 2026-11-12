# Operational SOP Standard

| Document Control | Value |
|---|---|
| Document Type | Reusable Documentation Standard |
| Scope | MSB repositories using the shared documentation framework |
| Status | CURRENT |
| Owner | MSB documentation governance |
| Last Reviewed | 2026-08-23 |

## Purpose

This standard defines the reusable rules for MSB operator procedures.

An Operational SOP explains **how to perform a task correctly**. It is not engineering architecture, implementation documentation, a database design, a troubleshooting handoff, or a substitute for the technical documentation that owns the system behind the task.

Repository-specific folder locations, screenshot locations, publishing paths, and local portal conventions belong in that repository's `System_Documentation/Project_Rules/` or another clearly designated local governance location.

## Audience

Write for the least-technical operator who needs to perform the task.

A current operator SOP must not require the reader to understand PostgreSQL, SQL, schemas, triggers, functions, UUID implementation details, backend architecture, APIs, resolver internals, or other engineering concepts unless that knowledge is genuinely necessary to perform the operator's task.

If the current user interface happens to be Directus or another technical platform, describe only the visible buttons, fields, labels, selections, and actions the operator must use. Do not teach the platform's internal architecture merely because it provides the screen.

## Operator Documentation and Engineering Documentation Are Different Products

Operator documentation answers:

> What do I need to do?

Engineering documentation answers:

> How does this system work, and how is it maintained or changed?

Keep those products separate.

Engineering explanation may be linked from a clearly separated **Related Engineering** or **Related Documents** section when useful, but it must not interrupt the normal task instructions or become prerequisite reading for an ordinary operator.

## Where an SOP Belongs

An SOP should normally live with the **subsystem, project step, or business workflow that owns the task**.

Examples:

- a testing task belongs with the Testing workflow;
- a labeling or scanning task belongs with the workflow that owns that operator action;
- a Setup/Takedown task belongs with the Setup/Deployment workflow rather than whichever application happens to expose the button;
- a cross-system SOP belongs to the business workflow that owns the end-to-end task, not arbitrarily to one implementation component.

Do not centralize every operator procedure into one repository folder merely because it is an SOP.

Each repository's Project Rules define its actual local placement and portal conventions.

## Operator Discovery

Repository organization exists for ownership and maintainability. Operator-facing navigation exists so people can find the correct task without understanding repository structure.

For MSB operational documentation, `my.sheboyganlights.org` is the normal discovery/presentation layer. It may aggregate links or application entry points across repositories and subsystem folders, but it must not create competing authoritative copies.

An operator should be able to find the current procedure by the task they are trying to perform without knowing whether the authoritative source is in GitHub, Google Workspace, a Display Folder, Directus, or another MSB system.

## Task Granularity

Prefer one plain-language procedure for each real operator task or decision point when the workflow can be safely divided.

Do not create one enormous manual when operators normally perform smaller independent tasks. Also do not split a normal task so finely that the operator must constantly switch documents.

A workflow portal may connect related procedures and help the operator answer:

> What am I trying to do right now?

Each procedure should contain enough information to complete its own task without requiring the operator to read the full engineering or workflow documentation first.

## Required Content

Use the following sections when they apply. Do not add empty sections merely to satisfy a template.

### Purpose

State what the task accomplishes and when the operator uses the procedure.

### Before You Start

List prerequisites that matter to the operator, such as required access, information, physical items, or a prior task that must already be complete.

Do not include engineering prerequisites the operator does not need to know.

### Procedure

Write numbered steps in the order the task is actually performed.

- Prefer one operator action per step.
- Use the exact labels and names the operator sees.
- Use **bold** for buttons, fields, menu entries, folder names, or required values when it improves scanning.
- Explain why only when the explanation prevents a likely mistake.
- Do not bury required actions inside long technical paragraphs.

### Expected Result

Tell the operator how to recognize successful completion.

### If Something Is Wrong

Include the likely failure condition and the safe next action. Link to a separate troubleshooting procedure or engineering reference when diagnosis becomes substantial.

### Related Documents

Link to related operator procedures and, when useful, the responsible engineering authority. Do not copy engineering detail into the SOP.

## File and Folder Placement Tasks

When an operator task requires placing, naming, moving, creating, or locating documents or folders, the procedure must be concrete enough that a nontechnical operator can perform the task without reverse engineering the hierarchy.

When applicable, include:

- the exact destination folder or visible navigation sequence;
- the required file or folder name;
- the expected parent/child path in plain language;
- at least one realistic correct example;
- nearby folders that are easy to confuse when confusion matters;
- required file type or naming rules that affect discovery;
- what successful placement looks like;
- how to verify the item is in the correct place and is discoverable; and
- the safe correction or escalation path when the operator is unsure.

Correct placement may be a **functional operational control** when an application discovers content from an established folder hierarchy. In that case, say plainly when putting the item in the wrong folder will prevent the application from finding or using it.

Do **not** explain resolver algorithms, database relationships, marker-validation implementation, APIs, or application internals unless that explanation is necessary for the operator to perform the task.

## Operator Language

Use plain language and the terms the operator actually sees.

Good:

> Place the current wiring diagram in the Stage's `Wiring\BackgroundStage` folder.

Not appropriate in the operator steps:

> The Wiring folder is an application-facing filesystem contract consumed by the structured-context resolver.

The second statement may be correct engineering documentation, but it does not help an ordinary operator complete the placement task.

## Warnings

Warnings should prevent likely mistakes rather than explain general engineering theory.

Examples:

- **Do not rename this folder.**
- **Do not place the current PDF in `Archive`. It will not be shown as the current procedure.**
- **Do not move an LOR background image until the related LOR reference has been reviewed.**

## Print and Hard-Copy Usability

When a procedure may be printed, the core task instructions must remain usable without clickable navigation.

Use clear titles, ordered steps, visible warnings, required values, completion guidance, and a visible reviewed/current date when appropriate.

## Document Control

Every current SOP should carry consistent metadata so people and future indexing tools can identify its purpose and status.

Use these fields unless a repository-specific project rule defines an equivalent controlled representation:

| Document Control | Value |
|---|---|
| Document Type | Operational SOP |
| System | System, subsystem, or business workflow |
| Task | Short description of the operator task |
| Audience | Intended operator or volunteer group |
| Status | CURRENT, DRAFT, or RETIRED |
| Owner | Person or role responsible for the procedure |
| Last Reviewed | YYYY-MM-DD |
| Keywords | Comma-separated search terms |

### Status Rules

- `CURRENT` — approved procedure for present use.
- `DRAFT` — being written or tested; not current operator authority.
- `RETIRED` — intentionally retained outside the archive for a specific reason.

Superseded material should normally be archived rather than left mixed with current operator instructions.

## Navigation

Normal operator navigation must remain task-oriented.

Do not place engineering handoffs, SQL documentation, architecture documents, implementation notes, or historical acceptance records in the normal operator task-selection path.

When a set of procedures forms a normal sequence, provide useful previous/home/next navigation or an equivalent workflow navigation method. Do not force a false linear sequence when the workflow branches.

## Screenshots and Supporting Images

Use screenshots only when they materially help the operator identify a screen, field, folder, or action.

- Keep the screenshot close to the instruction it supports.
- Use descriptive alternative text where the publishing format supports it.
- Do not make a procedure unusable when a screenshot is unavailable or prints poorly.
- Store images according to the repository's local Project Rules; this reusable standard does not define a repository-specific image path.

## Naming

Use a descriptive title and filename that tell the reader what the task accomplishes.

Do not depend on an unexplained number or letter prefix to communicate the purpose of a new procedure.

Existing legacy names may remain until the document is naturally revised or migrated under an approved project-specific cleanup.

## Indexing and Searchability

Current SOPs should be discoverable from their metadata and workflow context rather than filename alone.

At minimum, maintain useful values for:

- System;
- Task;
- Audience;
- Status;
- Owner;
- Last Reviewed; and
- Keywords.

A future indexer or intranet search may aggregate SOPs from multiple folders and repositories. That discovery layer must point to the authoritative procedure rather than create another editable copy.

## Reusable SOP Template

```markdown
# Task Name

| Document Control | Value |
|---|---|
| Document Type | Operational SOP |
| System | System / Subsystem / Workflow |
| Task | What the operator is doing |
| Audience | Operators / Volunteers / Managers |
| Status | CURRENT |
| Owner | Responsible person or role |
| Last Reviewed | YYYY-MM-DD |
| Keywords | keyword one, keyword two, keyword three |

## Purpose

Briefly explain what this task accomplishes.

## Before You Start

- Required access, information, or prior task

## Procedure

1. First operator action.
2. Second operator action.
3. Continue in task order.

## Expected Result

Describe what success looks like.

## If Something Is Wrong

Give the safe next action for likely problems.

## Related Documents

- [Related operator procedure](relative-or-published-link)
- [Related engineering authority](relative-or-published-link)
```

## Writing Goal

A volunteer should be able to open the procedure, determine that it is the correct task, follow the instructions, and recognize successful completion without first learning the underlying application or database architecture.
