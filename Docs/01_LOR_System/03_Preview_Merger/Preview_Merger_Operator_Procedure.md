# Preview Merger Operator Procedure

| Document Control | Value |
|---|---|
| Status | DRAFT — NOT YET APPROVED FOR PRODUCTION APPLY |
| System | LOR Preview Merger |
| Current workflow model | Master Musical Preview |
| Current revision | 2026-08-08 |
| Owner | MSB Database Administrator |

## Purpose

This procedure describes the intended operator workflow for reviewing programmer preview changes before they are allowed into the controlled master preview set.

The current Preview Merger software still requires engineering review before production `--apply` use. Until that review is complete, this document defines the required operating principles and review sequence, but it does **not** authorize production apply.

## Important Rule

**Never replace the controlled master preview with a programmer's local preview file.**

Each programmer works from an isolated copy. Another programmer may have made valid changes that are not present in your copy.

The Preview Merger exists to compare those independent changes before the controlled master is changed.

## Current Preview Model

The current workflow uses **Master Musical Preview** as the shared musical-preview authority.

The previous V6 workflow that relied on separate `RGB Plus Stage xx` previews for individual musical previews is obsolete and must not be followed as current operating guidance.

However, the approved production preview set still contains other previews that must remain independently managed because they serve different operational purposes.

| Preview Type | Purpose | Current Status |
|---|---|---|
| **Master Musical Preview** | Primary programming preview for musical sequences. This is the shared musical-preview authority and replaces the former requirement for separate `RGB Plus Stage xx` musical previews. | Current production workflow |
| **Show Background Stage xx** | Individual stage previews required to build and schedule background sequences for each stage. | Required |
| **Show Animation xx** | Individual previews required to build and schedule animation sequences for the show. | Required |
| **Show Stage 39 - Parade Float** | Specialized preview for the Parade Float. It does not follow the normal musical/background/animation preview pattern and is intentionally maintained as a separate approved preview. | Required engineering exception |

The merger must protect all of these independently managed preview classes while avoiding a return to the obsolete per-musical-preview synchronization model.

### Preview Classes

```text
                Individual Programmer Preview
                           |
                           v
                   Preview Merger
                           |
          +----------------+----------------+
          |                |                |
          v                v                v
     Master Musical   Show Background   Show Animation
        Preview         Stage xx             xx
          |                |                |
          |                |                |
          +----------------+----------------+
                           |
                           v
             Approved Production Preview Set
                           |
          +----------------+----------------+
          |                                 |
          v                                 v
 Show Stage 39 - Parade Float           LOR2DB Ingest
   (engineering exception)
```

**Engineering note:** `Show Stage 39 - Parade Float` is intentionally maintained as a separate approved preview because its physical installation and programming requirements differ from the standard show preview classes. It should not be removed or folded into another preview class merely because it appears to be an exception.

## Current Production Status

The merger implementation is under review before this season's programming workflow begins.

Do not run a production apply merely because the launcher or `--apply` option exists.

Current engineering review still needs to confirm:

- the exact controlled master location;
- which previews are independently managed under the Master Musical Preview model;
- final winner/comparison policy;
- current report locations;
- audit/history implementation;
- LOR 6.6.8 compatibility;
- idempotent dry-run/apply behavior.

## Intended Operator Workflow

### 1. Work only from your own preview copy

Make preview changes in your normal isolated working copy.

Do not open the controlled master and save your changes directly into it.

### 2. Export your candidate preview

Export the completed preview to your assigned programmer staging location.

Historically this location has been under:

`G:\Shared drives\MSB Database\UserPreviewStaging\<username>`

The final production procedure will confirm the current exact location before apply is approved.

Wait for Google Drive synchronization to complete before comparison.

### 3. Run a dry comparison

The first merger run must be a dry comparison.

Do not begin with apply.

The dry comparison should identify:

- the candidate file;
- the current controlled master file;
- preview identity;
- revision information;
- content/hash differences;
- conflicts or ambiguous changes;
- the proposed winner/action;
- the reason for that decision.

### 4. Review the result

Do not approve a change based only on a higher revision number or newer file date.

Review anything that indicates:

- changed preview GUID/identity;
- conflicting changes from multiple programmers;
- unexpected filename or preview-name changes;
- missing or changed Display Names;
- structural changes;
- an unexpected new preview;
- a proposed overwrite that cannot be explained.

If the comparison is unclear, stop and resolve the conflict before the controlled master is changed.

### 5. Confirm the correct master role

For musical preview work, confirm that the proposed change is being evaluated against the **Master Musical Preview** workflow rather than the obsolete separate `RGB Plus Stage xx` model.

Do not create or update separate musical-stage previews merely because the old V6 procedure instructed operators to do so.

Stage-specific Background and Animation previews, and the `Show Stage 39 - Parade Float` engineering exception, remain independently managed and must continue to be protected by the merger workflow.

### 6. Apply only after engineering approval

**Current status: production apply is not yet approved.**

Once engineering review is complete, the final procedure will identify the approved apply method and required operator checks.

The intended rule is that apply is a separate deliberate action after the dry comparison has been reviewed.

### 7. Prove idempotency

After an approved apply, immediately run the comparison again.

The newly applied preview should report no further change (`noop` or the equivalent current status).

If the second comparison still proposes a change, stop. The apply result has not been proven stable.

### 8. Use only the approved master set for parsing

Only the controlled, reviewed master preview set may feed the production parser.

Do not point the parser at a programmer staging folder or an unreviewed local export.

The current parser/ingest workflow is documented under [LOR2DB Ingest](../../../LOR2DB/01_Ingest/README.md).

## What the Old V6 Procedure No Longer Controls

The previous operator quickstart included steps that are now obsolete or superseded, including:

- running `parse_props_v6.py`;
- rebuilding `lor_output_v6.db` as the production handoff;
- validating production updates against the old spreadsheet workflow;
- maintaining separate RGB Plus Stage previews for each musical preview;
- treating the old Preview Merger SQLite history database as the production database system.

Those instructions are retained as engineering history only.

The current downstream production path is the V7 parser, LOR2DB ingest, reconciliation, validation, and reporting workflow.

## Stop Conditions

Stop without applying if any of the following occurs:

- preview identity changes unexpectedly;
- the comparison cannot explain why one candidate should win;
- multiple programmers changed the same logical preview in incompatible ways;
- the Master Musical Preview relationship is unclear;
- the comparison reports an unexpected structural or LOR-version change;
- reports are missing or incomplete;
- the merger implementation behaves differently from the approved procedure;
- LOR version compatibility has not been established;
- the post-apply comparison is not a no-op.

## LOR Version Changes

Do not use a preview exported by a newly released LOR version as production merger input until compatibility has been reviewed.

The engineering compatibility procedure is:

[LOR Preview Version Compatibility Review](../02_Data_Extraction/LOR_Preview_Version_Compatibility_Review.md)

## Related Systems

| System | Relationship |
|---|---|
| [LOR Preview Authoring](../01_Preview_Authoring/README.md) | Provides the authoring rules used before a programmer exports a candidate preview. |
| [Preview Merger implementation](../../../LOR/preview_merger/README.md) | Software used to compare, review, report, and eventually apply approved candidates. |
| [LOR Data Extraction](../02_Data_Extraction/README.md) | Documents how approved `.lorprev` files are interpreted after the merger workflow. |
| [LOR2DB Ingest](../../../LOR2DB/01_Ingest/README.md) | Begins the production database pipeline after the approved preview set is parsed. |

## Related Documents

- [Preview Merger Architecture](Preview_Merger_Architecture.md)
- [LOR Preview Version Compatibility Review](../02_Data_Extraction/LOR_Preview_Version_Compatibility_Review.md)
