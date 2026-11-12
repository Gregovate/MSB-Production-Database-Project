
# Preview Merger — Runbook & Reference

This tool scans user preview exports (`*.lorprev`), groups them by **preview key**, chooses a **WINNER**, compares it to the current **STAGED** copy, and writes CSV/HTML reports. With `--apply`, it will stage/copy files.

**Time**: All times shown are **local tz‑aware** with offset. The report column `Exported` replaces the old `MTimeUtc`.  
**Default policy**: `prefer-revision-then-exported` (details below). Legacy `*-mtime` names are accepted and remapped.

---

## Where to find the reports

- **CSV**: `G:\Shared drives\MSB Database\database\merger\reports\lorprev_compare.csv`  
- **HTML**: `G:\Shared drives\MSB Database\database\merger\reports\lorprev_compare.html`  
- **Missing comments CSV**: `G:\Shared drives\MSB Database\database\merger\reports\lorprev_missing_comments.csv`

> Run without `--apply` to do a dry run. The report reflects the state *at evaluation time* only. Run again after `--apply` to confirm most WINNER rows show `Action=noop`.

---

## How to read the report

Each **preview key** has up to three kinds of rows: one **WINNER** (chosen user copy), zero/one **STAGED** (current staged copy for that key, top‑level only), and other **CANDIDATE** rows (non‑winners). A tail section may contain **STAGED‑ONLY** rows (staged files with no matching winner this run).

### Column reference (what each field means)

| Column | Meaning | Tips |
|---|---|---|
| **Key** | Stable identity for the preview (usually `GUID:<guid>`) | Drives grouping and staged matching |
| **PreviewName** | Human name parsed from the preview | Report sorted by this (case‑insensitive), then Revision desc |
| **Revision** | *Raw* Revision string from the file | Policies compare the **numeric** part when present |
| **User** | Source owner (`gliebig`, `ShowPC`, etc.) or `_staging_` | `_staging_` rows describe the current staged copy |
| **Size** | File size in bytes | From filesystem |
| **Exported** | Local time the file was last written | Replaces `MTimeUtc` |
| **Change** | What changed vs the last run for this Key | `name`, `rev`, `content`, or `none` |
| **CommentsFilled** | Count of non‑empty comment entries | Before trimming spaces |
| **CommentsTotal** | Total possible comment entries | Denominator for coverage |
| **CommentNoSpace** | Count of comments still non‑empty **after trimming spaces** | Best “real comments” signal; **higher is better** |
| **Role** | `WINNER`, `CANDIDATE`, `STAGED` | One WINNER per Key; zero/one STAGED |
| **WinnerFrom** | Provenance of the winner (`USER:<name>`) | Only set on WINNER rows |
| **WinnerReason** | Why it won | e.g., `highest numeric Revision=57.0` or a tie‑breaker explanation |
| **Action** | What would happen (or did happen) | See mapping below |
| **WinnerPolicy** | Which policy chose the winner | Defaults to `prefer-revision-then-exported` |
| **Sha8** | Short hash of **this row’s** file | 8 hex chars |
| **WinnerSha8** | Short hash of the WINNER file | Helps compare at a glance |
| **StagedSha8** | Short hash of the staged file for this Key | On WINNER + STAGED rows |
| **GUID** | Parsed GUID | — |
| **SHA256** | Full content hash | — |
| **UserEmail** | Derived from user or mapping | Optional convenience |

### Interpreting **Action**

- On **WINNER** rows:  
  - `noop` — staged file exists and is byte‑identical to the winner.  
  - `update-staging` — staged exists but differs; applying will overwrite.  
  - `stage-new` — nothing matching is staged; applying will copy it in.

- On **STAGED** rows:  
  - `current` — matches the winner’s content.  
  - `out-of-date` — differs from the winner.  
  - `staged-only` — staged file with no matching winner this run (top‑level scan only).

> Tip: On the WINNER row, compare **WinnerSha8** and **StagedSha8**. If equal → `noop`. The STAGED row for the same Key should show `current` with the same `Sha8` value.

---

## Policies (`--policy`)

### Default: `prefer-revision-then-exported`
1) Choose the highest **numeric** Revision among candidates.  
2) If multiple share that highest Revision, prefer **better comments**: higher `CommentNoSpace`, then higher `CommentsFilled/CommentsTotal`.  
3) If no numeric Revision is present at all, pick the **latest Exported** time.

### Other options
- `prefer-exported` — newest **Exported** time wins outright.  
- `prefer-comments-then-revision` — prioritize comment quality first, then Revision.

*Legacy names `prefer-revision-then-mtime` and `prefer-mtime` are accepted and remapped.*

---

## How staged files are matched (non‑recursive by design)

- Only the **top level** of `staging_root` is scanned (no subfolders).
- Staged file is resolved by **Key**, then **GUID**, then the canonical filename (`default_stage_name(...)`).
- If bytes are identical: WINNER gets `Action=noop`, STAGED shows `current`.

---

## Typical seasonal workflow

1. **Dry‑run & review**
   ```bash
   py preview_merger.py --progress --show-actions
   ```
   - Check console `[summary]` and `[actions]`.
   - Open the HTML report for scanning; use CSV to filter/sort.

2. **Apply** (stage copies)
   ```bash
   py preview_merger.py --apply --progress
   ```

3. **Confirm** (expect mostly `noop`)
   ```bash
   py preview_merger.py --progress
   ```

---

## Flags recap

- Paths: `--config`, `--input-root`, `--staging-root`, `--archive-root`, `--history-db`, `--report`, `--report-html`  
- Behavior: `--policy`, `--apply`, `--force-winner KEY=PATH` (repeatable)  
- Users: `--ensure-users`, `--user-map`, `--user-map-json`, `--email-domain`  
- QoL: `--debug`, `--progress`, `--show-actions`

---

## Troubleshooting

- **No STAGED rows / all winners `stage-new`** → ensure the staged file is at the **top level** of `staging_root`. Subfolders are ignored.  
- **Indent after paste** → in VS Code: *Reindent Lines* and *Format Document*. Use spaces only.  
- **Old field names** → the report now uses `Exported`, `CommentsFilled`, `CommentsTotal`, `CommentNoSpace`.  
- **UTC warnings** → resolved; script uses local tz via `datetime.now().astimezone()`.

---

## Locations (for reference)

- Reports: `G:\Shared drives\MSB Database\database\merger\reports\`  
  - `lorprev_compare.csv`, `lorprev_compare.html`, `lorprev_missing_comments.csv`

---

*Use this README during the annual month‑long window; it’s designed so you can step back in without re‑learning internals.*
