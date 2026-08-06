## [v6.2] – 2025-09-03

### Added

- Per-run ledger artifacts on --apply: current_previews_ledger.csv and .html (grouped by Author, sorted by PreviewName) with Status, DisplayNamesFilledPct, ApplyDate, AppliedBy.
- Run ledger file: append-only apply_events.csv capturing Key, PreviewName, Author, Revision, Size, Exported, ApplyDate, AppliedBy.
- “Applied this run” export: applied_this_run.csv is written when any winners are staged in the current run (easy email attachment for teammates).
- Console breadcrumbs: [script] running: … (path of the script in use) and [ledger] … lines after emits.

### Changed

- ApplyDate format unified to match Exported (uses ymd_hms(...)), including for backfilled rows.
- Ledger emission order: ledger/backfill now run before the conflicts exit so artifacts are produced even when conflicts are detected.

### Fixed

- Blocked winners (comment fields present but commentsNoSpace == 0) are prevented from staging and clearly labeled via Action = needs-DisplayName Fixes; these rows surface under “Work Needed” in reports.

### Notes

- Backfill helper backfill_apply_events(...) populates missing ApplyDate/AppliedBy for current winners using preview_history.db (runs→staging_decisions) or staged file mtimes; idempotent and safe.
- Artifacts are written under the standard reports/ directory next to lorprev_compare.*.

## [v6.1] – 2025‑09‑01

### Added
- History DB schema (batches, changes) and writer in preview_merger.py
- HTML/CSV reporting via --report (tools/report_preview_history.py)
- Documentation pack (user guide, reporting, code comments)

### Changed
- Dry‑run output now saves to tmp/preview_merger_dryrun.csv

### Fixed

- Respect 'do not process blank comment' rule consistently in merger path

## 2025-08-25

### Added
- Preview-scoped IDs to avoid cross-preview collisions: `{PreviewId}:{RawId}`; subprop IDs `{master_id}-{UID}-{Start:02d}`; `DeviceType=None` group IDs `{PreviewId}:none:{LORComment}`.
- Wiring views v6 (`preview_wiring_map_v6`, `preview_wiring_sorted_v6`) with columns: `Source`, `Channel_Name`, `Display_Name`, `Suggested_Name`, `Network`, `Controller`, `StartChannel`, `EndChannel`, `Color`, `DeviceType`, `LORTag`.

### Changed
- **LOR single-grid**: group by `LORComment`; master = lowest `StartChannel`; others → `subProps`.
- **Manual subprops**: *promote first* occurrence per `LORComment` to `props`; subsequent remain `subProps`. If child grid is missing, inherit master’s channels.
- **DeviceType=None**: aggregate by `LORComment` (one `props` row per comment per preview; `Lights = sum(Parm2)`); included in wiring views as `Source='PROP'`.

### Preserved
- `Name` (Channel Name) and `LORComment` (Display Name) are never rewritten by the parser.
