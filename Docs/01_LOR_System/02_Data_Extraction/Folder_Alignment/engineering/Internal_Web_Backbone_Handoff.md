# Internal Web Backbone Handoff — Folder Alignment

| Handoff | Value |
|---|---|
| Source subsystem | Folder Alignment |
| Source repository | `Gregovate/MSB-Production-Database-Project` |
| Target repository | `Gregovate/MSB-Internal-Web-Backbone` |
| Status | PENDING IMPLEMENTATION |
| Last Reviewed | 2026-08-24 |

## Purpose

This handoff tells `MSB-Internal-Web-Backbone` how operator discovery must change after Folder Alignment receives its own operator/engineering documentation split.

The intranet is a task-oriented navigation/presentation layer. Folder Alignment remains authoritative for its operator procedures and engineering behavior.

## Stable Source Entry Point

The canonical Folder Alignment operator portal is:

```text
Docs/01_LOR_System/02_Data_Extraction/Folder_Alignment/README.md
```

## Operator Tasks To Expose

The intranet should make these Folder Alignment tasks findable to the people who maintain Preview/Display Folder documentation:

- Run Folder Alignment
- Review the Folder Alignment worklist

After review, the operator should be routed to the owning Google Drive / Display Folder procedure for any human folder/document change.

## Suggested Intranet Placement

Folder Alignment is a Production maintenance/authoring tool, not a normal field-crew application.

A reasonable task path is:

```text
Production
└── LOR / Preview Work or Documentation Maintenance
    └── Folder Alignment
```

The exact label may follow the Backbone's current Production vocabulary, but navigation should be based on what the maintainer is trying to do rather than on parser/database internals.

## Normal Workflow Presented To The User

```text
Run Folder Alignment
        |
        v
Review worklist
        |
        v
Choose one Stage / issue
        |
        v
Open the responsible Google Drive maintenance procedure
```

Do not present report implementation, SQLite structure, classification algorithms, or Python code as normal operator choices.

## Search / Index Metadata

When the Backbone supports documentation indexing, use the operator document-control fields and prioritize `CURRENT` operator content.

Useful search concepts include:

- Folder Alignment
- Documentation Alignment Worklist
- Google Drive alignment
- Display Folders
- Stage folder repair
- Scene folder repair
- legacy Setup migration

## Engineering Exclusion

Do not place these in normal operator navigation:

```text
Folder_Alignment/engineering/
```

or the implementation files in the subsystem root.

Engineering documentation remains available through a deliberately separate engineering path.

## Images

Folder Alignment repository documentation images, if/when needed, belong under:

```text
Docs/01_LOR_System/02_Data_Extraction/Folder_Alignment/images/
```

Do not add future Folder Alignment screenshots to a global `Docs/images/` bucket.

## Acceptance Criteria For Backbone

The Backbone side is complete when:

1. the intended maintainer can find Folder Alignment by task-oriented Production navigation;
2. **Run Folder Alignment** and **Review the Folder Alignment Worklist** are discoverable;
3. Google Drive maintenance actions link to their Google Drive owning procedures rather than duplicate copies;
4. engineering/code material is not in normal operator choices;
5. the deployed page has the required visible Backbone version indicator; and
6. the live intranet result is verified using the Backbone controlled deployment/reconciliation process.

## Verification State

Update this handoff to `IMPLEMENTED` when the Backbone source change is complete and to `VERIFIED` only after the deployed intranet navigation has been checked.
