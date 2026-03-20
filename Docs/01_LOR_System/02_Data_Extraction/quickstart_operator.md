# MSB Preview Update — Operator Quickstart (Consolidated)

> **Goal:** Remove duplication and confusion. This is the **one** doc operators need. Deep details live in `Preview Merger — Reference` and `Reporting & History` (keep those as separate reference docs).

## Big‑picture workflow (what to do, in order)
1) **Target fixes** with `lorprev_missing_comments.csv`  
   Open `G:\Shared drives\MSB Database\database\merger\reports\lorprev_missing_comments.csv`. Focus on previews where **CommentNoSpace < CommentFilled** → they likely have **spaces** in DisplayNames.
2) **Fix previews** in Sequencer  
   Correct DisplayNames. If a prop’s **DeviceType=="None"**, blank comments are **ignored** by design.
3) **Export** the fixed previews to your user folder  
   `G:\Shared drives\MSB Database\UserPreviewStaging\<username>\*.lorprev` (wait for Drive sync).
4) **Dry‑run the merger**  
   `py preview_merger.py` → open `...\reports\lorprev_compare.csv`.
5) **Check that the preview **Key/GUID did not change**  
   If Key flips (e.g., GUID changed), it may be a **breaking change** (channel/assignment churn). Fix in Sequencer and re‑export before applying.
6) **Apply** when the compare looks good  
   `py preview_merger.py --apply` (stages the winning previews).
7) **Rebuild the LOR DB** from previews  
   `py parse_props_v6.py` (updates `lor_output_v6.db` with the new DisplayNames).
8) **Validate** against the spreadsheet  
   Compare DisplayNames in the DB export to your team’s validation sheet. Re‑iterate if mismatches remain.
9) **Notify** team on Google Chat  
   Post a short update (template below).

---

## Quick commands (Windows)
- Dry‑run merger:  
  `py preview_merger.py`
- Apply merger:  
  `py preview_merger.py --apply`
- Reports to open:  
  `G:\Shared drives\MSB Database\database\merger\reports\lorprev_missing_comments.csv`  
  `G:\Shared drives\MSB Database\database\merger\reports\lorprev_compare.csv`  
  `G:\Shared drives\MSB Database\database\merger\reports\lorprev_compare.html`
- Rebuild DB:  
  `py parse_props_v6.py`

> You shouldn’t need flags for normal runs. The scripts know the **G:** paths.

---

## What good looks like (acceptance checks)
- In **missing_comments.csv**: CommentNoSpace ≈ CommentFilled and both close to CommentTotal.
- In **lorprev_compare.csv**:
  - Role=WINNER rows mostly show **Action=noop** or intended **update-staging**.
  - **Key** is stable (e.g., `GUID:<guid>` unchanged).
  - **WinnerSha8 == StagedSha8** after a confirm dry‑run.
- After **parse_props_v6.py**, a DB spot‑check shows updated DisplayNames.

---

## Breaking‑change guardrail (GUID/Key)
- **If Key/GUID changed**, older sequences may be affected. Treat as a blocker: re‑open the preview in `formview.py`, verify channel names/assignments, fix, re‑export, and re‑run the dry‑run until the Key is stable.

---

## Common pitfalls (and fixes)
- **I exported but my file isn’t considered.**  
  Make sure it’s under `UserPreviewStaging\<username>` and Google Drive shows a green checkmark.
- **Too many “missing comments.”**  
  Check for **DeviceType=="None"** props; blank comments there are ignored and shouldn’t be “fixed”.
- **Everything says stage‑new.**  
  The staged file must be at the **top level** of `Database Previews` (no subfolders).

---

## Notification template (Google Chat)
> Room: MSB Production – Database
```
Preview updates applied ✅
• Previews touched: <list or count>
• Keys stable: <yes/no>; Breaking changes: <none or list>
• LOR DB rebuilt via parse_props_v6.py at <YYYY‑MM‑DD HH:MM local>
Please pull latest DB if you cache locally. Ping me with any mismatches.
```

---

## Keep/Remove plan (to eliminate duplicates)
- **Keep** (as reference):
  - `Preview Merger — Reference` (detailed column meanings, policies, flags)
  - `Reporting & History` (schema, queries, reporter script)
- **Replace/Delete**:
  - Remove/retire `preview_merger_documentation_pack_v_1.md` and `_v_2.md` in favor of this **Quickstart** + the two references above.
  - Keep a short index README linking to these three docs only.

---

## Appendix: where everything lives
- **Your exports**: `G:\Shared drives\MSB Database\UserPreviewStaging\<username>`
- **Staged previews**: `G:\Shared drives\MSB Database\Database Previews`
- **Reports**: `G:\Shared drives\MSB Database\database\merger\reports\*`
- **History DB**: `G:\Shared drives\MSB Database\database\merger\preview_history.db`
- **LOR output DB**: `G:\Shared drives\MSB Database\database\lor_output_v6.db`

