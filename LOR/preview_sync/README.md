# LOR2DB 2-PC Preview Sync

Issue: #299 — Automate controlled LOR preview version conversion and programmer-PC synchronization.

## Source of truth

This directory is now the engineering source of truth for the launch-critical **MASTER -> LOCAL** programmer-PC preview synchronization work.

The shared Google Drive folder remains the **deployment target**:

```text
G:\Shared drives\MSB Database\UserPreviewStaging\LOR2DB_2PC_Sync
```

Do not treat files manually overwritten in that shared folder as authoritative engineering source.

## Current checkpoint

Current test checkpoint: **v0.2.1 (2026-10-04)**.

Status: **TEST / ACCEPTANCE IN PROGRESS — NOT YET PRODUCTION ACCEPTED**.

The current source snapshot is preserved as:

```text
artifacts/LOR2DB_2PC_Sync_SOURCE_v0.2.1.zip
```

SHA-256:

```text
5c518c89e328fbd3b18406f7aa51e604a56cc3acde7f5f30e067f60855e11198
```

The source ZIP contains the exact v0.2.1 text sources used to build the latest test package:
- `Update_MSB_Previews.ps1`
- `Install MSB Preview Update Shortcut.vbs`
- `README.txt`
- `VERSION.txt`
- `LOR2DB_Reports/README.txt`

The live Run 29 HTML report and runtime logs are deliberately **not** part of repository source. They are operational evidence/input and remain in the deployment folder.

## Proven behavior before v0.2.1

The earlier engineering prototype established that MASTER -> LOCAL synchronization can:
- preserve unmanaged/personal previews;
- add missing controlled PreviewIDs;
- replace substantive controlled differences;
- ignore revision-only differences;
- remain idempotent after synchronization.

The PowerShell-only programmer-facing implementation has since been tested through:
- direct Windows shortcut launch;
- Windows PowerShell 5.1 compatibility fixes;
- Run 29 discovery and source-folder validation;
- 34 controlled preview comparison;
- review UI with explicit overwrite acknowledgement;
- single-instance protection work;
- startup/progress UX work.

## Current open acceptance item

v0.2.1 was created to address slow/unresponsive startup by:
- reading each Google Drive master `.lorprev` file once per launch;
- reusing parsed records for Run evidence validation;
- moving semantic XML hashing into compiled .NET code;
- updating startup status preview-by-preview.

This performance revision still requires live acceptance before apply is authorized.

## Operating rule from this checkpoint forward

All engineering changes must be made on the #299 feature branch first. Deployment to the shared `LOR2DB_2PC_Sync` folder follows from a specific committed version/checkpoint.

Do not continue the previous pattern of generating unrelated ZIPs and manually overwriting the shared folder without a corresponding repository checkpoint.
