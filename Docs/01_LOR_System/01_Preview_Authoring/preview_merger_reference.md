# Preview Merger Reference

| Document control | Value |
|---|---|
| Process status | ACTIVE — required preview-integrity control |
| Implementation status | REVIEW REQUIRED before production apply |
| Current master | Office PC during LOR 6.6.4/V7 development |
| Current revision | 2026-08-06 |

## Why this exists

Every programmer works on an isolated LOR preview on their own PC. Their
working folder is a comparison source, not authority to overwrite the master.
The Preview Merger exists to compare all candidate exports, expose conflicts,
apply only reviewed changes, preserve history, and prove idempotence with a
second `noop` run.

Historically the Show PC held the master. During LOR 6.6.4 and V7 development,
the Office PC is the designated master. Authority may move back only through a
deliberate handoff after development is complete.

## Required locations

- Programmer exports:
  `G:\Shared drives\MSB Database\UserPreviewStaging\<username>\*.lorprev`
- Controlled preview set:
  `G:\Shared drives\MSB Database\Database Previews`
- Current consolidated reports/history location used by the recovered code:
  `G:\Shared drives\MSB Database\Database Previews\reports`
- Default operation: dry-run. `--apply` changes the controlled set and is
  blocked until the recovered implementation passes the V7/6.6.8 review in
  `LOR/preview_merger/README.md`.

## Review sequence

1. Confirm each export is in the correct programmer folder.
2. Run `preview_merger.py` without `--apply`.
3. Review `compare.csv`, `missing_comments.csv`,
   `all_staged_comments.csv`, `excluded_winners.csv`,
   `current_previews_ledger.csv`, and `revision_mismatches.csv` as available.
4. Use preview filenames for operator review. Retain Key/GUID for database
   correlation, but never make the operator identify a preview from GUID alone.
5. Treat identifier changes, revision conflicts, older candidates, unexpected
   semantic changes, and incomplete comments as review conditions.
6. Resolve conflicts and rerun the dry comparison.
7. Apply only after the report is clean and the implementation guardrails have
   been approved for the current environment.
8. Run again and require `noop` for every applied preview.

## Comparison fields

- **Role:** `WINNER`, `CANDIDATE`, `STAGED`, or `STAGED-ONLY`.
- **Action:** `noop`, `update-staging`, `stage-new`, `current`,
  `out-of-date`, or `staged-only`.
- **PreviewName/FileName:** required human-readable identity for review.
- **Key/GUID:** machine correlation; identifier changes require investigation
  because copied/imported LOR snapshots may receive new IDs.
- **WinnerSha8/StagedSha8:** quick content equality check.
- **Revision/RevisionRaw:** parsed and original revision values.
- **Exported:** LOR export time, with file time used only as a fallback.
- **CommentTotal/CommentFilled/CommentNoSpace:** comment coverage and naming
  quality indicators. Blank comments on `DeviceType="None"` are intentionally
  excluded.
- **Path/StagedPath:** exact programmer candidate and controlled-set paths.

## Selection and safety

The recovered code currently defaults to `prefer-exported`, although older
documentation described `prefer-comments-then-revision`. This is not a settled
production policy. The V7/6.6.8 review must validate the selection order and
turn on the appropriate regression safeguards before any production apply.

The current code also has:

```python
REQUIRE_CORE_DIFF = False
REQUIRE_AUTHOR_NEWER = False
```

That is the most permissive profile. It must not be silently accepted as the
production configuration.

## Relationship to V7

The approved controlled preview set is the only valid input to
`LOR/ingest/parse_props_v7_scene_parser.py`. V7 imports preview-level (`P`)
scenes from `.lorprev`; sequence-level (`S`) scenes are intentionally excluded.
The SQLite snapshot then serves FormView compatibility needs and PostgreSQL
snapshot ingest according to their documented contracts.

Detailed implementation ownership and the LOR 6.6.8 compatibility checklist
are in [LOR Preview Merger](../../../../LOR/preview_merger/README.md).

