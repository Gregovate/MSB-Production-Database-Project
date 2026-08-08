# Preview Merger Architecture

| Document Control | Value |
|---|---|
| Status | CURRENT — engineering architecture; implementation review still required |
| System | LOR Preview Merger |
| Current workflow model | Master Musical Preview |
| Current revision | 2026-08-08 |
| Owner | MSB Database Administrator |

## Purpose

The Preview Merger exists to protect the controlled Light-O-Rama preview set when multiple programmers work independently.

Each programmer works from an isolated local preview. Those copies are independent development islands. A programmer may make a valid change without knowing that another programmer has also changed the same preview or shared content. Directly replacing the controlled master with one programmer's local file can therefore discard someone else's work.

The Preview Merger provides the controlled comparison and review layer between individual programmer exports and the approved master preview set.

Its core responsibility is not simply copying files. Its responsibility is to preserve preview integrity, expose conflicting or ambiguous changes before they reach the master, and provide evidence of what was reviewed and accepted.

## System Position

```text
Programmer preview copies
        |
        v
UserPreviewStaging
        |
        v
Preview Merger
        |
        v
Controlled Master Preview Set
        |
        v
Approved .lorprev source set
        |
        v
LOR Preview Parser
        |
        v
LOR2DB Ingest -> Reconciliation -> Reporting
```

The Preview Merger protects the source material that eventually feeds the production parser. It is upstream of LOR2DB and must not bypass the approved-preview controls.

## Core Engineering Requirements

The following requirements survive from the original Preview Merger design and remain valid regardless of implementation technology.

### Isolated authoring

Programmers do not edit the controlled master preview directly. Each programmer works from an isolated preview copy and exports candidate changes to their own staging location.

### Controlled master authority

There must be one clearly designated master authority for the preview set.

Historically the Show PC held the master preview set. During the LOR 6.6.4/V7 development period the Office PC became the designated master. Authority must be deliberately transferred; it must never be inferred from whichever copy appears newest.

`Master_Musical_Preview` is the stable logical role for the musical-preview master. Dated exported files are snapshots, not permanent identities.

### Dry comparison before apply

Comparison must occur before any controlled master file is changed.

A normal workflow begins with a dry comparison. Apply is a separate, deliberate action after review.

### Conflict visibility

The merger must surface enough evidence to identify conflicting or ambiguous changes before apply. Historically this included preview identity, revision, content quality, hashes, source contributor, filename, and decision reason.

### Deterministic decisions

Given the same candidate files and the same controlled master state, the comparison should produce the same result. Hidden or order-dependent winner selection is not acceptable.

### Idempotency

After an approved change is applied, a second comparison against the resulting master should report no additional change for that same input. Historically this was represented as `noop`.

A successful apply that cannot be reproduced as a no-op on the next comparison is not considered proven.

### Auditability

The system must preserve enough evidence to answer:

- who supplied a candidate preview;
- which candidate was selected;
- what master file was compared;
- why a candidate was selected or rejected;
- whether a conflict was detected;
- what changed during an applied run;
- what controlled preview state resulted.

The implementation of that audit trail may change. The requirement does not.

## Historical Architecture — Pre-PostgreSQL Preview Merger

The original merger was developed before the current PostgreSQL/LOR2DB production workflow existed.

At that time the Preview Merger had to provide its own durable history and reporting system. It used a separate SQLite database named:

`preview_history.db`

That database was not the parser output database. It was a dedicated Preview Merger audit database.

The historical design tracked four major concepts:

| Historical table | Engineering purpose |
|---|---|
| `runs` | One record for each comparison/apply execution and the policy used |
| `file_observations` | Candidate files seen during the run, including contributor, preview identity, revision, SHA-256, path, filename, and exported time |
| `staging_decisions` | The selected action for each preview, including winner, staged name, decision reason, conflict flag, and staged/skipped/archived result |
| `preview_state` | Last known staged state for each preview identity |

The historical database also exposed reporting views such as run summaries, contributors by run, and files staged in a run.

This architecture is important because it documents the engineering requirements that existed before PostgreSQL: provenance, deterministic decisions, history, conflict evidence, and the ability to explain what was applied.

The current system must preserve those requirements, but it does **not** automatically follow that the separate historical SQLite audit database should remain the long-term implementation.

## Historical Selection and Comparison Logic

The prior implementation used preview identity and content evidence to compare candidates with the staged master.

Important historical mechanisms included:

- GUID-based preview identity when available;
- name-based fallback when GUID identity was unavailable;
- revision comparison;
- exported time as a later tie-breaker;
- SHA-256 comparison to prove file equality;
- contributor/source-path tracking;
- comment coverage checks;
- explicit decision reasons;
- `WINNER`, `CANDIDATE`, `STAGED`, and `STAGED-ONLY` roles;
- `noop`, `update-staging`, and `stage-new` actions;
- blocking review when preview identity unexpectedly changed.

One historical winner policy was `prefer-comments-then-revision`, which favored strong Display Name comment coverage before revision and other tie-breakers. That policy reflected the cleanup work being performed at the time and must not be assumed to be the final current production policy without review.

The engineering principle to preserve is that winner selection must be explainable and deterministic.

## Why Preview Identity Matters

The merger historically treated unexpected GUID/key changes as a potential breaking change.

That remains an important guardrail because a preview may appear visually similar while its underlying identity or structure has changed in a way that affects sequences, parser interpretation, or downstream relationships.

A changed preview identity must therefore be reviewed rather than treated as a routine newer-file replacement.

The exact identity checks used by the current merger must be reviewed against the current `.lorprev` specification and V7 parser architecture.

## Master Musical Preview Model

The current workflow has been simplified from the earlier V6 operating model.

Historically, programming relied on separate `RGB Plus Stage xx` preview files associated with individual musical previews. That created additional master-preview synchronization work and contributed to the need for more complicated per-preview comparison and staging behavior.

The current model uses **Master Musical Preview** as the shared musical-preview authority.

This changes the operational workflow substantially:

- the merger should no longer assume that every musical preview requires its own independently maintained RGB Plus Stage preview;
- the Master Musical Preview becomes the shared musical-preview source that must be protected from accidental overwrite;
- stage-specific and other approved previews still require controlled handling where they remain separate source files;
- old V6 instructions that describe rebuilding or synchronizing a separate RGB Plus Stage preview for each musical preview are obsolete.

This simplification reduces the number of independent master files that must be reconciled while preserving the central requirement: programmers must not overwrite the controlled master with isolated local copies.

## Current PostgreSQL / LOR2DB Boundary

The current production data pipeline now provides PostgreSQL snapshot provenance, reconciliation history, operator decisions, validation, and immutable reconciliation reports downstream of the parser.

That is a major change from the environment in which `preview_history.db` was created.

The Preview Merger still needs its own evidence for events that occur **before parsing**, including candidate comparison and master-preview changes. However, the current design should be reviewed to determine which historical audit functions should remain local to the merger and which would duplicate controls now provided by PostgreSQL/LOR2DB.

The design goal is not to preserve a separate SQLite database merely because one existed historically. The design goal is to preserve the engineering requirements without maintaining duplicate sources of truth.

### Information that remains merger-specific

At minimum, the merger must still be able to explain pre-parser events such as:

- contributor/source of each candidate;
- candidate and master file identity;
- comparison result;
- conflict or ambiguity;
- selected winner;
- applied master-file change;
- before/after content hash or equivalent evidence;
- time and operator responsible for apply.

### Information already handled downstream

LOR2DB now separately records and reports the parser/ingest snapshot, reconciliation decisions, production promotion, validation, and reconciliation report publication.

Preview Merger history should not attempt to become a second reconciliation database.

## Relationship to the Parser

The Preview Merger and parser have different responsibilities.

The Preview Merger decides **which approved preview files are allowed into the controlled source set**.

The parser interprets those approved `.lorprev` files and materializes the structured SQLite snapshot.

The Preview Merger must not silently transform parser-required XML structure merely to make comparison easier.

Changes to LOR file structure must be evaluated using the current LOR preview file compatibility process before merger comparison logic is assumed compatible.

## LOR Version Compatibility

A new Light-O-Rama version can affect both the parser and Preview Merger.

The parser may depend on XML structure, attributes, scene positioning, device types, and identifiers. The Preview Merger may independently depend on preview identity, revisions, comments, hashes, timestamps, and other parsed metadata.

Therefore a successful parser compatibility review does not automatically prove that Preview Merger comparison logic is still correct.

For a new LOR version:

1. Compare the new `.lorprev` structure against the documented baseline.
2. Evaluate parser impact.
3. Evaluate Preview Merger identity/signature/comparison impact.
4. Test only against copied preview files.
5. Do not alter the controlled master until compatibility is documented.

See [LOR Preview Version Compatibility Review](../02_Data_Extraction/LOR_Preview_Version_Compatibility_Review.md).

## Current Implementation

The current/recovered implementation is under:

[Preview Merger implementation](../../../LOR/preview_merger/README.md)

The implementation preserves significant historical comparison, reporting, history, and idempotent-merge work, but it requires review before production apply.

Known implementation issues include:

- V6 database references remain in parts of the merger code;
- older parser-facing assumptions remain in `lor_core.py`;
- some launchers and report paths reflect older folder layouts;
- the historical apply-policy defaults require review;
- the Master Musical Preview simplification is not fully reflected in the old operator workflow;
- LOR 6.6.8 compatibility has not yet been established.

The presence of code in the active tree does not by itself make an `--apply` run production-approved.

## Current Development Requirements

Before the Preview Merger is approved for this season's production programming workflow, engineering review must establish:

1. the current master-preview authority and exact controlled source locations;
2. the Master Musical Preview workflow and which remaining previews are independently managed;
3. the current comparison/winner policy;
4. the required conflict and identity guardrails;
5. the minimum audit evidence that must survive each comparison/apply;
6. whether `preview_history.db` is retained, replaced, or reduced now that PostgreSQL/LOR2DB exists;
7. current report locations and operator-facing report format;
8. LOR 6.6.8 compatibility;
9. dry-run and apply idempotency tests;
10. the final operator procedure.

## Historical Source Material

The original Preview Merger documents remain valuable as engineering history because they record the reasons behind the system and the controls that were required before PostgreSQL.

Important historical sources include:

- Preview Merger Reference (v1);
- MSB Preview Update — Operator Quickstart (Consolidated);
- Reporting & History (v1) — `preview_history.db`;
- archived Preview Merger documentation packs and earlier implementation revisions.

Historical operational commands, paths, parser versions, and database instructions must not be copied into current procedures unless independently verified against the current implementation.

## Related Systems

| System | Relationship |
|---|---|
| [LOR Preview Authoring](../01_Preview_Authoring/README.md) | Defines the human authoring rules for previews that eventually enter the merger workflow. |
| [LOR Data Extraction](../02_Data_Extraction/README.md) | Documents the `.lorprev` contract, parser architecture, SQLite output, and LOR-version compatibility review. |
| [LOR2DB Ingest](../../../LOR2DB/01_Ingest/README.md) | Consumes the parser-generated SQLite snapshot after the approved master preview set has been parsed. |
| [LOR2DB Reconciliation](../../../LOR2DB/02_Reconciliation/README.md) | Controls production promotion and validation after ingest. |
| [Preview Merger implementation](../../../LOR/preview_merger/README.md) | Current software/development tree for comparison, reporting, and apply logic. |

## Related Documents

- [Preview Merger Operator Procedure](Preview_Merger_Operator_Procedure.md)
- [LOR Preview File Structure Specification](../02_Data_Extraction/LOR_Preview_File_Structure_Specification.md)
- [LOR Preview Parser Architecture](../02_Data_Extraction/LOR_Preview_Parser_Architecture.md)
- [LOR Preview Version Compatibility Review](../02_Data_Extraction/LOR_Preview_Version_Compatibility_Review.md)
- [LOR SQLite Output Database Structure](../02_Data_Extraction/LOR_SQLite_Output_Database_Structure.md)
