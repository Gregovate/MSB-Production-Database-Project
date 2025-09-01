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
