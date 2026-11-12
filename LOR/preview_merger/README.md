# LOR Preview Merger

| Document control | Value |
|---|---|
| Process status | ACTIVE — required preview-integrity control |
| Implementation status | REVIEW REQUIRED before production apply |
| Current master location | Office PC |
| Current approved LOR version | 6.6.10 |
| Current revision | 2026-08-17 |

## Purpose

Every LOR programmer has an isolated preview on their own PC. Those copies are
independent development islands and cannot safely overwrite one another. Each
programmer exports completed work to their own folder under
`UserPreviewStaging`; the Preview Merger compares those candidates with the
controlled master set and produces review evidence before any master file is
changed.

V7 replaced the parser and snapshot contract. It did not remove this
multi-programmer integrity requirement.

## Master authority

- Historically, the Show PC held the master preview set.
- The **Office PC is the designated master** for the approved LOR 6.6.10
  production preview set.
- The Show PC must not be described or used as current authority until
  development is complete and responsibility is deliberately transferred.
- `Master_Musical_Preview` is the stable logical role. Dated exported files are
  snapshots, not permanent identities.

## Mandatory operating contract

1. A programmer edits only their isolated preview copy.
2. The programmer exports to their own working folder:
   `G:\Shared drives\MSB Database\UserPreviewStaging\<username>`.
3. Run a dry comparison; do not begin with `--apply`.
4. Review filenames, revisions, identifiers, semantic differences, missing
   comments, and conflicts. `revision_mismatches.csv` must show human-readable
   preview filenames; Key/GUID remains available for database identity work.
5. Resolve ambiguous or conflicting changes before altering the master set.
6. Apply only the reviewed winners to the controlled staging/master set.
7. Run the comparison again. The second run must report `noop` for the applied
   files; otherwise the process is not proven idempotent.
8. Only the approved master set may feed the V7 parser.

No programmer may directly replace the controlled master with their local copy.

## Current implementation and blockers

The recovered implementation is kept here because it embodies the prior
comparison, reporting, history, and idempotent-merge work. It is not approved
for an unattended or production `--apply` run until it is reviewed against the
current V7/LOR environment.

Known blockers include:

- `preview_merger.py` still contains V6 database references.
- `lor_core.py` describes a V6 parser-facing field model.
- `REQUIRE_CORE_DIFF` and `REQUIRE_AUTHOR_NEWER` are currently `False`, the most
  permissive apply profile. The intended production guardrails must be decided
  and validated before apply.
- Some launchers and report paths reflect older folder layouts.
- Any version after LOR 6.6.10 requires a new controlled compatibility review.

Until those blockers are closed, the ownership, isolation, dry-run review, and
controlled-master rules remain mandatory, but the recovered script must not be
assumed safe merely because it exists in the active tree.

## Files

| File | Role |
|---|---|
| `preview_merger.py` | Candidate discovery, comparison, staging, and audit logic |
| `lor_core.py` | Shared preview/signature comparison helpers |
| `merge_reports_to_excel.py` | Combines merger CSV outputs into the review workbook |
| `report_preview_history.py` | Produces reports from the merger history database |
| `run_preview_merger_dryrun.cmd` | Dry-run launcher |
| `run_preview_merger_apply.cmd` | Apply launcher; blocked pending review above |
| `report_preview_history.cmd` | History-report launcher |
| `open_reports_folder.cmd` | Opens the report folder |

Current Preview Merger engineering and operator documentation is maintained in the
[Preview Merger documentation portal](../../Docs/01_LOR_System/03_Preview_Merger/README.md).

## New LOR version compatibility boundary

Every version after approved LOR 6.6.10 is a separate compatibility project.
Do not update the master set, production parser, PostgreSQL ingest, or
reconciliation based on an assumption that a later release is schema-compatible.

The compatibility branch must:

1. Preserve the approved LOR 6.6.10 preview manifest and V7 outputs as the baseline.
2. Export representative previews from the new version to a separate versioned location.
3. Compare XML elements, attributes, identifiers, scenes, preview-level versus
   sequence-level scene behavior, props, subprops, DMX, backgrounds, and channel
   data.
4. Run the V7 parser only against the isolated candidate inputs.
5. Compare SQLite schema, row counts, identities, relationships, warnings,
   omissions, collisions, and unassigned records with the baseline.
6. Review Preview Merger field/signature logic against any XML changes.
7. Preserve the V7 snapshot contract and LOR 6.6.10 compatibility unless a
   controlled database change is explicitly approved.
8. Leave production ingest and reconciliation unchanged until compatibility is
   demonstrated and documented.
