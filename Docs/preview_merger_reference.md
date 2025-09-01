# Preview Merger — Reference (v1)

_Companion to **MSB Preview Update — Operator Quickstart (Consolidated)**._  
Use this when you need the **why/details** behind the workflow.

## Purpose & scope
`preview_merger.py` selects the best `.lorprev` per preview and stages it to **Database Previews**, producing CSV/HTML reports and a local‑time audit in `preview_history.db`. This doc defines the **rules, columns, and flags**.

## Required locations (Google Workspace)
- **User exports (input):** `G:\Shared drives\MSB Database\UserPreviewStaging\<username>\*.lorprev`
- **Staged previews (output):** `G:\Shared drives\MSB Database\Database Previews`
- **Reports:** `G:\Shared drives\MSB Database\database\merger\reports\*`
- **History DB (audit):** `G:\Shared drives\MSB Database\database\merger\preview_history.db`
- **Time policy:** **Local, tz‑aware** strings everywhere (no UTC).
- **Default run:** **Dry‑run**; pass `--apply` to stage files.

## Selection policy (how winners are chosen)
Default policy: **prefer‑comments‑then‑revision**
1. Highest **CommentNoSpace** (strict “real comments” score).  
2. Highest numeric **Revision**.  
3. Best fill ratio **CommentFilled / CommentTotal**.  
4. Latest **Exported** time.  
5. Deterministic path/name fallback.

Alternate policies (if enabled in your script): `prefer‑revision‑then‑exported`, `prefer‑exported`.

### DeviceType=="None" rule
When props in a preview have `DeviceType="None"` (as set in Sequencer), **blank comments are ignored** on purpose. This prevents inflating “missing comments.”

## Column dictionary — `lorprev_compare.csv`
Each row represents a **relationship** between a candidate and what’s currently staged. Keys you’ll reference most:

- **Role** – `WINNER`, `CANDIDATE`, `STAGED`, `STAGED‑ONLY`  
  - `WINNER`: the chosen user file for this Key on this run.  
  - `CANDIDATE`: other user files for the same Key.  
  - `STAGED`: current staged file matched to the Key.  
  - `STAGED‑ONLY`: staged file with no user candidate this run.
- **Key** – `GUID:<guid>` if a GUID exists; otherwise `NAME:<lowercased name>`.
- **GUID** – Parsed from `.lorprev` (blank if missing).  
  **Guardrail**: If this changes between runs, preview structure likely changed (possible breaking change).
- **Action** (on WINNER):  
  - `noop` — winner matches staged (sha equal)  
  - `update‑staging` — will overwrite staged on `--apply`  
  - `stage‑new` — no staged match exists (new preview)
- **Action** (on STAGED): `current`, `out‑of‑date`, `staged‑only`.
- **WinnerSha8 / StagedSha8** – First 8 of file SHA‑256 for quick equality check.
- **Revision / RevisionRaw** – Parsed numeric and original string.
- **Exported** – Local time the file claims it was exported (from metadata), or file mtime fallback.
- **CommentTotal / CommentFilled / CommentNoSpace** –  
  - **Total**: Count of comment slots.  
  - **Filled**: Non‑empty comments (ignoring DeviceType==None blanks).  
  - **NoSpace**: Filled comments with **no spaces** (proxy for correct DisplayName convention).
- **User / UserEmail** – Derived from subfolder or provided mapping.
- **Path / FileName** – Full source path and file name.
- **DecisionReason** – Why the winner beat other candidates (only present in some builds or logs).

### How to interpret comment coverage
- If **NoSpace ≈ Filled** and both are close to **Total**, DisplayNames are likely conforming.  
- If **NoSpace** lags **Filled**, you likely have spaces in DisplayNames.

## Column dictionary — `lorprev_missing_comments.csv`
This is a targeted list for clean‑up work.

- **Key / GUID / PreviewName** – Identification for the preview.  
- **CommentTotal / CommentFilled / CommentNoSpace** – Same definitions as above.  
- **NeedsAttention** – Heuristic flag (e.g., `NoSpace < Filled`).  
- **Notes** – May include reminders about DeviceType==None behavior.

## Breaking‑change check (Key/GUID)
- If **Key** flips from `GUID:<...>` to `NAME:<...>` or the **GUID** changes, treat it as **breaking until proven safe**.  
- Re‑open in **formview.py**, verify channel names/assignments, fix, re‑export, and re‑run the dry‑run until the Key stabilizes.

## Flags & usage
- **`--apply`** — actually stage winners, produce `.bak` when overwriting different files.  
- **`--policy <name>`** — choose an alternate selection policy (if wired in your build).  
- **`--report` / `--report-html`** — generate CSV/HTML reports (if split from default flow in your build).  
- **`--debug`** — verbose logging.  
- **Defaults** – Script knows the `G:` paths; no flags required for normal runs.

## Troubleshooting
- **My export wasn’t considered** — ensure it’s under `UserPreviewStaging\<username>` and Drive shows a green checkmark.  
- **Everything shows stage‑new** — make sure the current staged file (if any) is at the **top level** of `Database Previews`.  
- **Huge list in missing_comments** — check for DeviceType==None; blanks there are intentional and excluded.  
- **Locked files** — close SQLiteStudio, Excel, or editors that might have opened staged files during `--apply`.

## Related docs
- **MSB Preview Update — Operator Quickstart (Consolidated)** — do‑this‑now checklist.  
- **Reporting & History** — schema, canned queries, and the `report_preview_history.py` tool.

> This doc supersedes overlapping sections in the older `preview_merger_documentation_pack_v_*.md` files.

