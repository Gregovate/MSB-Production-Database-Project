# Production Operational Documentation Rule

| Document Control | Value |
|---|---|
| Document Type | Project Rule |
| Repository | MSB Production Database Project |
| Status | CURRENT |
| Owner | Production documentation owner / administrator |
| Last Reviewed | 2026-08-24 |

## Purpose

This rule defines Production Database-specific placement, ownership, discovery, image-asset, migration, and intranet-handoff rules for operator and engineering documentation.

The reusable writing and audience rules live in [`../Standards/Operational_SOP_Standard.md`](../Standards/Operational_SOP_Standard.md). This document owns the Production-specific rules that must not be copied into unrelated repositories.

## Ownership Before Folder Location

An operator SOP should normally live with the subsystem, project step, or business workflow that owns the task.

Do not move every Production SOP into one central folder merely because it is an operator procedure.

Examples:

- testing procedures belong with the Testing workflow;
- labeling and scan procedures belong with the workflow that owns those tasks;
- Google Drive document-maintenance procedures belong with the Google Drive / Display Folder workflow;
- Folder Alignment procedures for generating/reviewing the alignment worklist belong with Folder Alignment;
- LOR operator procedures belong with the LOR workflow they operate;
- cross-system procedures belong with the business workflow that owns the end-to-end task.

The existing `Docs/02_Production_Database/02_Operational_SOPs/` tree remains valid for the procedures already owned there. It is **not** the mandatory home for every current or future Production operator SOP.

Do not mass-move existing procedures only to make the repository look uniform. Move a document only when ownership, navigation, image references, inbound links, and intranet impact are understood.

## Production Subsystem Documentation Layout

For a Production subsystem or documentation area that contains both operator and engineering material, use this target structure when it can be introduced safely:

```text
<Subsystem>/
├── README.md                  operator/user portal
├── operatorSOP/
│   ├── README.md              operator procedure index
│   └── <task procedures>.md
├── engineering/
│   ├── README.md              engineering handoff
│   ├── Internal_Web_Backbone_Handoff.md
│   └── <engineering contracts, designs, handoffs>.md
└── images/                    subsystem-owned repository documentation images
```

Create only the branches the subsystem actually needs. A category/overview folder that does not own operator tasks or engineering work does not need empty `operatorSOP/`, `engineering/`, or `images/` directories merely for symmetry.

### Subsystem `README.md` = operator/user portal

The root `README.md` is the normal user/operator navigation page when the subsystem has an operator audience.

It should answer questions such as:

- What do I need to do?
- Which current procedure applies?
- Where do I go next?
- Which live application should I use?

Do not turn the root README into an engineering recovery handoff when the same subsystem has an operator audience.

### `operatorSOP/` = task procedures

Put current operator/contributor task procedures here when the subsystem owns those tasks.

The `operatorSOP/README.md` is the operator procedure index for that subsystem. It may link to a procedure owned by another subsystem, but it must not create a duplicate current authority.

### `engineering/README.md` = engineering handoff

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

Technical contracts and implementation explanations belong under `engineering/`, not in the normal operator procedure path.

## Subsystem Image Ownership

Repository documentation images must be owned by the subsystem that uses them.

For converted subsystems, store screenshots, diagrams, and supporting repository-documentation images under:

```text
<Subsystem>/images/
```

Do not continue adding unrelated subsystem assets to a global `Docs/images/` bucket merely for convenience.

When converting a subsystem that already uses images:

1. inventory every image reference in the current operator and engineering documents being converted;
2. identify the actual image file and confirm which subsystem owns it;
3. move/copy the asset into the owning subsystem's `images/` folder using a stable descriptive filename;
4. update every current Markdown/reference link that points to the old image location;
5. verify the rendered/document link after the move;
6. search for remaining current references to the old image path; and
7. do not delete a shared old image until all current consumers have been identified and migrated.

If one image is legitimately shared across multiple subsystems, choose one authoritative owner and let the other subsystem link to that asset, or deliberately duplicate only when independent ownership is actually required. Do not create accidental competing copies.

This repository-image rule is separate from runtime/content image folders inside Google Drive such as:

```text
Procedures\Setup\images
Procedures\Takedown\images
```

Those are field-content locations, not Git documentation-asset locations.

## Compatibility During Migration

Existing documentation has many inbound relative links. Do not break those links merely to achieve the target folder layout.

When moving a current authority:

1. create the new canonical document first;
2. move/rehome any owned image assets and repair the document's image links;
3. update the most important current portals and links;
4. leave a short compatibility document at the old path that clearly points to the new current authority when needed;
5. repair remaining inbound links deliberately;
6. verify the Internal Web Backbone impact; and
7. remove the compatibility file only after current references no longer depend on it.

A compatibility pointer is not a second authority. It exists only to keep old links useful during migration.

## Internal Web Backbone Handoff Is Required

Every subsystem converted to the operator/engineering documentation structure must include:

```text
<Subsystem>/engineering/Internal_Web_Backbone_Handoff.md
```

when the subsystem has operator tasks, portals, application entry points, or search/navigation behavior that `my.sheboyganlights.org` must expose or may already expose.

The handoff must tell `Gregovate/MSB-Internal-Web-Backbone` at minimum:

- the canonical operator portal;
- current task choices that should be discoverable;
- stable application entry points that should remain preferred over repository deep links;
- useful document-control/search metadata;
- engineering/historical paths that must be excluded from normal operator navigation;
- old/compatibility links that should not become new intranet dependencies;
- subsystem image-path implications when relevant; and
- acceptance criteria for deployed intranet verification.

The source subsystem remains authoritative. The Backbone handoff is an integration contract, not a copied operator manual.

A subsystem documentation conversion is not fully closed until the Backbone state is recorded as one of:

- `PENDING` — handoff exists but Backbone has not implemented it;
- `IMPLEMENTED` — Backbone source has been updated;
- `VERIFIED` — the deployed intranet navigation/search result has been checked.

## Documentation Conversion Tracker

Repository-wide conversion must proceed one subsystem at a time after the Google Drive / Folder Alignment proof is accepted.

Track progress in:

[`Documentation_Subsystem_Conversion_Tracker.md`](Documentation_Subsystem_Conversion_Tracker.md)

Do not rely on chat history to remember which subsystem is converted, partially converted, or still legacy.

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

## First Proof Conversion — Google Drive and Folder Alignment

The first controlled conversion covers two related but separately owned subsystems.

### Google Drive / Display Folder Operations

```text
Docs/00_Project_Overview/Google_Drive/
├── README.md
├── operatorSOP/
│   ├── README.md
│   ├── Repair_Existing_Stage_Scene.md
│   ├── Add_Verify_Marker_Files.md
│   ├── Create_Stage_Substage_Scene_Folder.md
│   ├── Align_Legacy_Setup_Documents.md
│   └── Publish_Current_Setup_Instruction.md
├── engineering/
│   ├── README.md
│   └── Internal_Web_Backbone_Handoff.md
└── images/
```

### Folder Alignment

```text
Docs/01_LOR_System/02_Data_Extraction/Folder_Alignment/
├── README.md
├── operatorSOP/
│   ├── README.md
│   ├── Run_Folder_Alignment.md
│   └── Review_Folder_Alignment_Worklist.md
├── engineering/
│   ├── README.md
│   └── Internal_Web_Backbone_Handoff.md
├── images/
└── <working implementation files>
```

The operator portals may link to tasks owned by another subsystem rather than duplicate them. For example, the Google Drive portal links to Folder Alignment for worklist generation/review and to Preview Authoring / Field Wiring for wiring-diagram creation.

Existing documents at former paths may remain temporarily as compatibility pointers while inbound links are repaired.

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
