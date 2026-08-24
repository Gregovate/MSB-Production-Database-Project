# Run Folder Alignment

| Document Control | Value |
|---|---|
| Document Type | Operational SOP |
| System | Folder Alignment |
| Task | Generate and open the Documentation Alignment Worklist |
| Audience | Production documentation maintainers and Folder Alignment reviewers |
| Status | CURRENT |
| Owner | Production documentation owner / administrator |
| Last Reviewed | 2026-08-23 |
| Keywords | Folder Alignment, worklist, Google Drive, Display Folders, run_folder_check, report |

[↑ Google Drive / Display Folder Operations](../../README.md)

## Purpose

Use this procedure to generate the current **Documentation Alignment Worklist** before repairing or reorganizing Google Drive Display Folders.

Folder Alignment is read-only. It reports what it finds; it does not move, rename, create, or delete Google Drive folders or documents.

## Before You Start

- Use the current repository working copy.
- Make sure the current V7 parser SQLite snapshot exists.
- Make sure the Google Shared Drive **Display Folders** is available as `G:\Shared drives\Display Folders` unless your approved environment uses explicit override paths.
- Do not use an old saved report when you need the current Drive state.

The current Windows defaults used by Folder Alignment are:

```text
V7 SQLite:
G:\Shared drives\MSB Database\database\lor_output_v7_scene.db

Display Folders:
G:\Shared drives\Display Folders

Report output:
G:\Shared drives\MSB Database\Database Previews V6.6.4\reports\google-drive-alignment
```

## Procedure — Windows

1. Open PowerShell in the repository root.
2. Run:

```powershell
.\run_folder_check.ps1
```

3. Let the report finish.
4. When the run succeeds, the launcher opens the newest generated HTML report automatically.
5. Confirm the report is the current run before using it as your worklist.

## What the Worklist Is For

Use the report to identify items such as:

- Stage/Sub-stage/Scene folders that match the current LOR/parser structure;
- missing or incomplete standard documentation folders;
- legacy Setup documents still waiting for review;
- current folder/path conflicts; and
- items that require human review instead of guessing.

The report is a **worklist and validator**, not permission to bulk-move everything it mentions.

## Work One Stage at a Time

After opening the current report:

1. Pick one Stage.
2. Review its Stage/Sub-stage/Scene results.
3. Use [Repair or Organize an Existing Stage / Scene](Repair_Existing_Stage_Scene.md) for the actual document/folder work.
4. Leave uncertain items unchanged and flag them for review.
5. Re-run Folder Alignment after enough changes have been made that a fresh worklist is useful.

## Expected Result

A current HTML Documentation Alignment Worklist opens and shows the present parser/Google Drive comparison without changing the Google Drive contents.

## If Something Is Wrong

- **PowerShell says Python is missing:** stop and repair the approved Python environment before continuing.
- **The SQLite file cannot be found:** verify the current parser snapshot exists before running Folder Alignment.
- **Display Folders cannot be found:** verify Google Drive for Desktop is connected and the shared drive is available.
- **The report opens but looks old:** verify the output path and report timestamp, then run again.
- **A report item is ambiguous:** do not guess at a folder move or rename. Leave it in place for human review.

## Related Engineering

- [Google Drive Engineering](../engineering/README.md)
