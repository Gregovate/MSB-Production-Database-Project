# MSB Preview → DB Workflow (v6)

_Last updated: 2025-10-01_

This guide explains the **four-stage pipeline** for maintaining the Making Spirits Bright (MSB) preview data:

1) **Merger:** collect and reconcile `.lorprev` files  
2) **Parser:** load staged previews into the v6 SQLite database  
3) **Sheet Export:** refresh the **Displays** CSV from Google Sheets  
4) **DB Compare:** compare DB vs Displays CSV and emit reports

It also defines **where artifacts live**, what each report means, and how to interpret the **ledger** vs the **manifest**.

---
# Quick Database Update Workflow

If you’ve cloned the repository  
👉 [https://github.com/Gregovate/MSB-Production-Database-Project](https://github.com/Gregovate/MSB-Production-Database-Project)  
and have **Python 3.13** (Microsoft Store version) installed, you only need to run **three scripts** to update the database.

> ⚠️ You must be signed in to Google Workspace and have the shared **G:** drive mapped to your local system.

```bash
python preview_merger.py --apply
python parse_props_v6.py
python compare_displays_vs_db.py
```

---

## Outputs and Reports

### 📁 G:\Shared drives\MSB Database\Database Previews
- **lorprev_reports.xlsx** – Complete summary of all applied changes (multiple tabs).  
- **current_previews_manifest.html** – List of all current previews, authors, and revision levels.  
  *Use this to verify your local previews match the shared versions.*

### 📁 G:\Shared drives\MSB Database\Spreadsheet
- **lor_display_compare.xlsx** – Compares database records to the legacy spreadsheet.  
  *(Temporary report until full conversion is complete.)*  
  🔹 **Important:** Each time the spreadsheet is updated, run **Export Displays CSV** from the **DB Tools** toolbar before generating this report.



## 0) Detailed Summary (what to run)

- **Dry-run (safe):**
  ```bat
  py preview_merger.py
  ```
- **Apply (stage winners, archive old):**
  ```bat
  py preview_merger.py --apply
  ```
- **Parse staged previews into DB (guided prompts for paths):**
  ```bat
  py parse_props_v6.py
  ```
- **Export Displays CSV** (from the Google Sheet using its built-in export script/process) → produce `displays_export.csv`
- **Compare DB vs CSV (guided / repo script):**
  ```bat
  py compare_displays_vs_db.py
  ```

> Tip: If Excel/HTML is open during compare or merger reports, the scripts will warn about **locked** files. Close them and re-run.

---

## 1) Merger (collect & reconcile .lorprev)

**Script:** `preview_merger.py`  
**Goal:** pick a single “winner” per preview from `UserPreviewStaging\{user}\*.lorprev`, and keep a **clean staging folder** that represents the current truth.

### Inputs (canonical)
- Users drop `.lorprev` here:
  ```
  G:\Shared drives\MSB Database\UserPreviewStaging\<username>\*.lorprev
  ```
- The top-level **staging** folder (the “current truth”):
  ```
  G:\Shared drives\MSB Database\Database Previews
  ```

### Run modes
- **Dry-run (no file changes):** shows what would be staged/updated/blocked
  ```
  py preview_merger.py
  ```
- **Apply:** stages winners into the **staging** folder and **archives** old files
  ```
  py preview_merger.py --apply
  ```

### Key outputs
All merger reports and histories live under:
```
G:\Shared drives\MSB Database\database\merger\reports\
```

You will typically see:

- `lorprev_compare.csv / .html`  
  Full comparison of candidates per preview (who won, why, quality stats).

- `current_previews_ledger.csv / .html`  
  **Ledger** of the **current** staged previews (one row per preview) + status fields; this is the “working log” you read to decide actions.

- `apply_events.csv`  
  Append-only **event log** with the last known **ApplyDate** and **AppliedBy** per preview (used to annotate the ledger).

- `current_previews_manifest.csv / .html`  
  **Manifest** (inventory) of **what is in staging right now**. No judgments, just a list.

- Optional dry-run companion files:
  - `current_previews_manifest_preview.csv / .html` (what would be there on apply)

**Archive of old staged files:**  
```
G:\Shared drives\MSB Database\database\merger\archive\<YYYY-MM-DD>\*.lorprev
```

### “How we choose a winner”
Policy default: **prefer-comments-then-revision**  
1) Most **CommentNoSpace** (i.e., comment fields filled without spaces; our “Display Name” quality proxy)  
2) Highest **Revision**  
3) Best fill ratio  
4) Latest Exported time  
5) Stable tie-break by path

Staging is blocked if:
- The preview name family is disallowed (e.g., `Show Background Stage-##` with a hyphen)  
- Comments exist but **none** are no-space (quality rule)  
- GUID mismatch against an existing staged file with the same filename

### Reading `lorprev_compare.csv`
Important columns:
- `Role` — `WINNER` (chosen file), `CANDIDATE` (not chosen), `STAGED` (what’s currently in the staging folder), or `REPORT-ONLY` (blocked from staging)
- `Action` — `stage-new`, `update-staging`, `noop`, or `needs-DisplayName Fixes` (blocked), `current`/`out-of-date` on STAGED rows
- `CommentFilled / CommentTotal / CommentNoSpace` — quality signals for Display Names
- `WinnerReason` — explains why the winner was chosen
- `Change` — `name`, `rev`, `content`, or `none` vs prior state (from history DB)

### Ledger vs Manifest (why the terms differ)
- **Manifest** = **what’s there** (snapshot inventory), e.g., `current_previews_manifest.html`
- **Ledger** = **what changed and what needs action**, e.g., `current_previews_ledger.csv`  
  - Includes per-preview **Status** and **DisplayNamesFilledPct**
  - Annotated with **ApplyDate/AppliedBy** from the event log

### Reading `current_previews_ledger.csv`
Columns you’ll use most:
- `PreviewName` — the staged preview
- `Author` — source user (from winner)
- `Revision` — staged revision
- `Exported` — file’s local mtime
- `ApplyDate` / `AppliedBy` — last known apply timestamp & machine/host
- `Status`:
  - **Ready to Apply** — (dry-run context) clean comments & action indicates stage/update
  - **Already Applied** — staged equals winner (`noop`)
  - **Work Needed** — conflict/blocked/quality issues, or report-only
- `DisplayNamesFilledPct` — `(CommentNoSpace / CommentTotal) * 100`

---

## 2) Parser (staged → SQLite v6)

**Script:** `parse_props_v6.py`  
**Goal:** load the **currently staged** previews into `lor_output_v6.db` (v6 schema), including **wiring views**.

### Inputs
- Staging folder (from Step 1):
  ```
  G:\Shared drives\MSB Database\Database Previews
  ```

### Run
```bat
py parse_props_v6.py
```
You’ll be prompted for:
- **DB path** (default):  
  `G:\Shared drives\MSB Database\database\lor_output_v6.db`
- **Preview folder** (default):  
  `G:\Shared drives\MSB Database\Database Previews`

The parser will:
- Rebuild tables: `previews`, `props`, `subProps`, `dmxChannels`
- Populate v6 **wiring views**, e.g.:
  - `preview_wiring_map_v6` (joins master + sub-props)
  - `preview_wiring_sorted_v6` (sorted for controller/network/channel outputs)

> After this step, the **database** represents the current staged truth.

---

## 3) Export “Displays” CSV from Google Sheets

**Goal:** refresh the authoritative **Displays** table from the team’s Google Sheet.

- Use the spreadsheet’s export script/process to produce:
  ```
  displays_export.csv
  ```
- Place it in the agreed location (or note its full path when the compare script asks for it).

> This CSV is the “sheet truth” we reconcile against the database.

---

## 4) DB Compare (DB vs Displays CSV)

**Script:** `compare_displays_vs_db.py`  
**Goal:** compare `lor_output_v6.db` to `displays_export.csv` and emit Excel/CSV/HTML reports that show **matches**, **mismatches**, and **orphans**.

### Run
```bat
py compare_displays_vs_db.py
```
When prompted:
- **Database path** → `G:\Shared drives\MSB Database\database\lor_output_v6.db`
- **Displays CSV path** → path to `displays_export.csv`
- **Output Excel path** → folder for the merged Excel workbook

### Outputs you’ll see
- A **compare report CSV/HTML** summarizing:
  - **Exact matches** (Display Name alignment between DB and Sheet)
  - **Mismatches** (names normalized but values differ)
  - **Orphans** (present in DB but not in Sheet, or vice-versa)
- A **merged Excel** workbook (helper script ties multiple reports together) under the output folder you chose

> If the tool indicates **report files locked**, close Excel and re-run.

---

## Where everything lands (cheat sheet)

- **Staging (current truth):**  
  `G:\Shared drives\MSB Database\Database Previews\*.lorprev`

- **Merger reports & ledgers:**  
  `G:\Shared drives\MSB Database\database\merger\reports\`
  - `lorprev_compare.csv / .html`
  - `current_previews_ledger.csv / .html`
  - `apply_events.csv`
  - `current_previews_manifest.csv / .html`
  - `current_previews_manifest_preview.csv / .html` (dry-run)

- **Merger archive:**  
  `G:\Shared drives\MSB Database\database\merger\archive\<YYYY-MM-DD>\*.lorprev`

- **Primary DB (v6):**  
  `G:\Shared drives\MSB Database\database\lor_output_v6.db`

- **Displays CSV (from Google Sheet):**  
  `displays_export.csv` (exported by the sheet’s script; give this path to the compare script)

- **DB vs Sheet comparison outputs (Excel/CSV/HTML):**  
  Where you told `compare_displays_vs_db.py` to write its outputs (often alongside the reports folder or a per-run subfolder)

---

## How to “use” the ledger after a dry-run

1) Open `current_previews_ledger.html` (or `.csv`)  
2) Filter rows by **Status**:
   - **Work Needed** → address name family issues, GUID mismatches, or comment/quality problems  
   - **Ready to Apply** → safe to stage (if not already applied)  
   - **Already Applied** → no action  
3) When satisfied, rerun the merger with `--apply` to stage winners and archive stale files.  
4) Re-parse → re-export → re-compare.

---

## Common pitfalls & fixes

- **Excel/HTML locked:** Close any open report or Excel workbook and re-run.
- **Hyphenated stage names:** `Show Background Stage-##` is rejected; rename to `Show Background Stage ##`.
- **Blank or low-quality comments:** If `CommentTotal > 0` but `CommentNoSpace = 0`, the candidate is **blocked** (we require clean, no-space Display Names).
- **GUID mismatch vs existing staged file:** Don’t overwrite — investigate, then resolve the name/GUID conflict.
- **Multiple candidates tie:** The policy falls back to rev/time/path; check `WinnerReason` in `lorprev_compare.csv` to understand the decision.

---

## FAQ

**Q: Why both a ledger and a manifest?**  
**A:** Manifest answers “what’s there (now)?” Ledger answers “what changed/what’s needed?” We need both views for clean ops and accountability.

**Q: What columns matter most for quality?**  
- `CommentNoSpace` / `CommentTotal` → Display Name health  
- `Status` in the ledger → your next step  
- `WinnerReason` → why a candidate was chosen

**Q: Where do I see who/when applied?**  
- `ApplyDate` & `AppliedBy` columns in `current_previews_ledger.csv` (populated from `apply_events.csv`).

---

