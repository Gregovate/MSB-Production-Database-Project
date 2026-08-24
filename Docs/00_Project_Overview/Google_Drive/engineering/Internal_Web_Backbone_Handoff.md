# Internal Web Backbone Handoff — Google Drive / Display Folder Operations

| Handoff | Value |
|---|---|
| Source subsystem | Google Drive / Display Folder Operations |
| Source repository | `Gregovate/MSB-Production-Database-Project` |
| Target repository | `Gregovate/MSB-Internal-Web-Backbone` |
| Status | PENDING IMPLEMENTATION |
| Last Reviewed | 2026-08-24 |

## Purpose

This handoff tells `MSB-Internal-Web-Backbone` how operator discovery must change after the Google Drive / Display Folder documentation conversion.

The intranet remains a navigation/presentation layer. It must not create a second editable authority for these procedures.

## Stable Source Entry Point

The canonical operator portal is:

```text
Docs/00_Project_Overview/Google_Drive/README.md
```

Normal intranet navigation should prefer this subsystem portal or task-level presentation derived from its current operator procedures rather than old Project Overview document paths.

## Operator Tasks To Expose

The Production intranet should make these tasks findable in plain language:

- Repair or organize an existing Stage / Scene folder
- Add or verify MSB Display Folder marker files
- Create a new Stage / Sub-stage / Scene documentation folder
- Align a legacy Setup document
- Publish a current Setup instruction
- Run Folder Alignment
- Review the Folder Alignment worklist
- Create or update a field wiring diagram

Folder Alignment and wiring-diagram tasks are linked from the Google Drive portal but remain authoritative in their owning subsystems. Do not duplicate those procedures into Google Drive content merely for intranet presentation.

## Suggested Intranet Placement

These maintenance tasks are primarily contributor/production-maintainer tasks rather than normal field-crew actions.

They should be discoverable under a task-oriented Production area such as:

```text
Production
└── LOR / Preview Work or Documentation Maintenance
    └── Display Folder / Google Drive maintenance
```

Exact labels may follow the Backbone's current Production navigation vocabulary, but the user should not need to understand repository paths or resolver architecture.

Field users looking for current Setup/Takedown/Inspection or Wiring content should continue to use the production applications:

```text
https://my.sheboyganlights.org/procedures/
https://my.sheboyganlights.org/fieldwiring/
```

Do not replace those application entry points with repository-document links.

## Search / Index Metadata

When the Backbone supports documentation indexing, use current operator document-control metadata such as:

- `Document Type`
- `System`
- `Task`
- `Audience`
- `Status`
- `Owner`
- `Last Reviewed`
- `Keywords`

Normal search results must prioritize `CURRENT` operator procedures and portals.

## Engineering Exclusion

Do not place these in the normal operator task-selection path:

- `Google_Drive/engineering/`
- Google Drive path-resolution contracts
- resolver/database implementation details
- Field Context engineering contracts
- server/runtime handoffs
- historical acceptance/recovery evidence

Engineering material may be available through an explicitly separate engineering path for maintainers.

## Old Links / Compatibility

The older Project Overview paths are compatibility pointers during migration, including the former Google Drive organization procedure, marker procedure, and Stage/Sub-stage/Scene scaffold.

Backbone changes should target the new canonical subsystem portal/procedure locations. Do not build new navigation around compatibility paths.

## Images

Repository documentation images for this subsystem belong under:

```text
Docs/00_Project_Overview/Google_Drive/images/
```

Do not assume a global `Docs/images/` authority for new Google Drive documentation assets.

This is separate from runtime Google Drive folders such as `Procedures\Setup\images`.

## Acceptance Criteria For Backbone

The Backbone side is complete when:

1. a user can find the Google Drive / Display Folder maintenance area by task-oriented Production navigation;
2. the current operator tasks above are discoverable without browsing GitHub hierarchy;
3. normal field Setup/Wiring paths still route to the production Procedures and Field Wiring applications;
4. engineering documents are not mixed into normal operator task choices;
5. no new navigation depends on the old compatibility paths;
6. the deployed page has the required visible Backbone version indicator; and
7. the live intranet change has been verified using the Backbone's controlled deployment/reconciliation rules.

## Verification State

Update this handoff to `IMPLEMENTED` when the Backbone source change is complete and to `VERIFIED` only after the deployed intranet navigation has been checked.
