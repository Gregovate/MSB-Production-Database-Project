# Run Folder Alignment

| Document Control | Value |
|---|---|
| Document Type | Operational SOP |
| System | Folder Alignment |
| Task | Generate and open the Documentation Alignment Worklist |
| Audience | Production documentation maintainers and Folder Alignment reviewers |
| Status | CURRENT |
| Owner | Production documentation owner / administrator |
| Last Reviewed | 2026-08-24 |
| Keywords | Folder Alignment, worklist, Google Drive, Display Folders, run_folder_check, report |

[↑ Folder Alignment](../README.md)

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

## Expected Result

A current HTML Documentation Alignment Worklist opens and shows the present parser/Google Drive comparison without changing Google Drive contents.

## Next Step

Continue with [Review the Folder Alignment Worklist](Review_Folder_Alignment_Worklist.md).

## If Something Is Wrong

- **PowerShell says Python is missing:** stop and repair the approved Python environment before continuing.
- **The SQLite file cannot be found:** verify the current parser snapshot exists before running Folder Alignment.
- **Display Folders cannot be found:** verify Google Drive for Desktop is connected and the shared drive is available.
- **The report opens but looks old:** verify the output path and report timestamp, then run again.
- **A report item is ambiguous:** do not guess at a folder move or rename. Leave it in place for human review.

## Related Engineering

- [Folder Alignment Engineering](../engineering/README.md)
