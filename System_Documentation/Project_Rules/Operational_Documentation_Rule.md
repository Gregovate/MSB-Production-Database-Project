# Production Operational Documentation Rule

| Document Control | Value |
|---|---|
| Document Type | Project Rule |
| Repository | MSB Production Database Project |
| Status | CURRENT |
| Owner | Production documentation owner / administrator |
| Last Reviewed | 2026-08-23 |

## Purpose

This rule defines Production Database-specific placement, ownership, and discovery rules for operator documentation.

The reusable writing and audience rules live in [`../Standards/Operational_SOP_Standard.md`](../Standards/Operational_SOP_Standard.md). This document owns the Production-specific rules that must not be copied into unrelated repositories.

## Ownership Before Folder Location

An operator SOP should normally live with the subsystem, project step, or business workflow that owns the task.

Do not move every Production SOP into one central folder merely because it is an operator procedure.

Examples:

- testing procedures belong with the Testing workflow;
- labeling and scan procedures belong with the workflow that owns those tasks;
- Setup/Takedown document-maintenance procedures belong with the Setup/Deployment and Display Folder documentation workflow;
- LOR operator procedures belong with the LOR workflow they operate;
- cross-system procedures belong with the business workflow that owns the end-to-end task.

The existing `Docs/02_Production_Database/02_Operational_SOPs/` tree remains valid for the procedures already owned there. It is **not** the mandatory home for every current or future Production operator SOP.

Do not mass-move existing procedures only to make the repository look uniform. Move a document only when ownership, navigation, and link updates are understood.

## Production Subsystem Documentation Layout

For a Production subsystem or documentation area that contains both operator and engineering material, use this target structure when it can be introduced safely:

```text
<Subsystem>/
├── README.md
└── docs/
    ├── operatorSOP/
    │   └── <task procedures>.md
    └── engineering/
        ├── README.md
        └── <engineering contracts, designs, handoffs>.md
```

### Subsystem `README.md` = operator/user portal

The root `README.md` is the normal user/operator navigation page.

It should answer questions such as:

- What do I need to do?
- Which current procedure applies?
- Where do I go next?
- Which live application should I use?

Do not turn the root README into an engineering recovery handoff when the same subsystem has an operator audience.

### `docs/operatorSOP/` = task procedures

Put the current operator/contributor task procedures here when the subsystem owns those tasks.

These procedures follow the reusable Operational SOP standard and remain plain-language/task-oriented.

### `docs/engineering/README.md` = engineering handoff

This is the engineering starting point for Greg, future maintainers, and engineering work sessions.

It should preserve or link to:

- current architecture;
- application/data/filesystem contracts;
- authoritative implementation sources;
- dependencies and boundaries;
- current production state where the subsystem owns that state;
- known limitations;
- recovery/resume information; and
- dated engineering/acceptance evidence where needed.

Technical contracts and implementation explanations belong under `docs/engineering/`, not in the normal operator procedure path.

### Compatibility during migration

Existing documentation has many inbound relative links. Do not break those links merely to achieve the target folder layout.

When moving a current authority:

1. create the new canonical document first;
2. update the most important current portals and links;
3. leave a short compatibility document at the old path that clearly points to the new current authority when needed;
4. repair remaining inbound links deliberately; and
5. remove the compatibility file only after current references no longer depend on it.

A compatibility pointer is not a second authority. It exists only to keep old links useful during migration.

## Operator Discovery Through `my.sheboyganlights.org`

`my.sheboyganlights.org` is the normal Production operator discovery and presentation layer.

Operators should be able to find current procedures by what they are trying to do without understanding:

- GitHub repository structure;
- PostgreSQL or database schema;
- Directus internals;
- Google Drive hierarchy beyond the folder navigation required by the task;
- application resolver architecture; or
- which repository owns the source.

The intranet may aggregate links or application entry points from different repository locations and systems, but it must not create competing editable copies of the authoritative procedure.

## Google Shared Drive / Display Folder Procedures

The Google Shared Drive named **Display Folders** is a Production engineering-document repository used by several systems, including LOR Preview Authoring, FieldWiring, and Procedure.

For operator tasks that create, move, name, archive, publish, or verify files and folders there, the operator procedure must give the concrete folder placement needed to perform the work correctly.

When relevant, state:

- the exact destination folder;
- the exact required folder or marker name;
- the visible parent/child path;
- realistic examples;
- nearby folders that must not be used;
- whether wrong placement prevents the application from finding the file; and
- how the operator verifies the result.

Do not explain the resolver, database relationships, path parsing, marker-validation implementation, API behavior, or other engineering internals in the operator instructions. Link to the responsible engineering contract instead.

## Google Drive Documentation Target Structure

The Google Drive / Display Folder documentation is the first area being migrated to the subsystem layout above.

Target:

```text
Docs/00_Project_Overview/Google_Drive/
├── README.md
└── docs/
    ├── operatorSOP/
    │   ├── Run_Folder_Alignment.md
    │   ├── Repair_Existing_Stage_Scene.md
    │   ├── Add_Verify_Marker_Files.md
    │   ├── Create_Stage_Substage_Scene_Folder.md
    │   ├── Align_Legacy_Setup_Documents.md
    │   └── Publish_Current_Setup_Instruction.md
    └── engineering/
        └── README.md
```

The operator portal may link to a task owned by another subsystem rather than duplicate it. For example, the wiring-diagram creation procedure is owned by Preview Authoring / Field Wiring and can be linked from the Google Drive operator portal.

Existing Google Drive documents at their former paths may remain temporarily as compatibility pointers while inbound links are repaired.

## Stage Setup Instructions Are a Separate Field Document Class

Field-facing Stage Setup Instructions are governed by [`Stage_Setup_Documentation_Standard.md`](Stage_Setup_Documentation_Standard.md).

They are not repository operator SOPs merely because they contain steps. They are published field instructions for crews physically installing Stages, Scenes, and related display assemblies.

The operator/contributor procedure for creating, aligning, archiving, and publishing those field instructions is separate from the field instruction itself.

## Publishing and Searchability

When a Production operator procedure is intended for routine use, maintain enough document-control metadata for future indexing and search, including:

- Document Type;
- System or workflow;
- Task;
- Audience;
- Status;
- Owner;
- Last Reviewed; and
- Keywords.

The long-term discovery goal is that an operator can search or browse `my.sheboyganlights.org` by task and reach the authoritative current procedure without needing tribal knowledge or a direct repository link supplied by an engineer.

## Historical and Engineering Material

Do not rewrite historical acceptance evidence merely to match current operator style.

Do not place dated engineering handoffs, implementation acceptance records, SQL notes, resolver designs, or runtime recovery material in the normal operator task-selection path.

Preserve those documents where they serve engineering history, recovery, or acceptance purposes and link them from engineering navigation as appropriate.

## Related Standards and Rules

- [Operational SOP Standard](../Standards/Operational_SOP_Standard.md)
- [Documentation Standards](../Standards/Documentation_Standards.md)
- [Document Control Standard](../Standards/Document_Control_Standard.md)
- [Stage Setup Documentation Standard](Stage_Setup_Documentation_Standard.md)
- [Repository Change Workflow](Repository_Change_Workflow.md)
