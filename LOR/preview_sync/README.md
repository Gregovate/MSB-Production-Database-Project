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

Current test candidate: **v0.2.2 (2026-10-04)**; live deployment remains unverified.

Frozen previous checkpoint: v0.2.1 at `5e08db5374826b91c4b372044f013dcb3d9f9bbd`.

Status: **TEST / ACCEPTANCE IN PROGRESS — NOT YET PRODUCTION ACCEPTED**.

The previous source snapshot is preserved unchanged as:

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

## Current acceptance findings and resume point

Remote reconnaissance confirmed #300 is open/draft at the frozen v0.2.1 SHA,
with current `main` at `bb45a9cea4205d7382745ab550a6f73d1cc771db`.
The checkpoint contains current main (zero main-only commits).
Phase 1 is standalone MASTER -> LOCAL only: consume existing accepted LOR2DB
report/manifest evidence; never call Production services, run ingest, alter
approved-version state, or write controlled master previews. Phase 2 remains deferred.

The [v0.2.2 source candidate](artifacts/LOR2DB_2PC_Sync_SOURCE_v0.2.2.zip)
has SHA-256 `32da4f1510889dda55a9bd430af8bf8310380b8c015b2bdbb0d34b4ae83e855e`.
It corrects two reproduced Windows PowerShell 5.1 defects:

- The compiled semantic reader needs explicit `System.Xml.dll` and
  `System.Core.dll` references. The v0.2.1 compiler statement fails before startup UI.
- `File.Replace(..., $null)` binds to an invalid empty backup pathname on this host.
  The candidate supplies the timestamped backup pathname explicitly; the disposable
  test proves that backup bytes match the original and installed bytes match the candidate.

The [disposable checkpoint test](artifacts/Test-Checkpoint.ps1) loads only the
archive's compiler statement and function definitions; it does not execute the
top-level updater, acquire the real instance lock, open UI, or touch G:/local LOR.
Run with Windows PowerShell 5.1 and the v0.2.2 archive/hash arguments. All eight
checks passed: controlled replacement/addition, unmanaged raw-fragment preservation,
comparison without input mutation, original-byte backup, atomic install, idempotent
second comparison, revision-only NOOP, and duplicate controlled identity blocking.
These are synthetic engine results, not live or two-PC acceptance.

Deployment/apply is still blocked pending:

1. Read access to the G: deployment/report/master inputs. Greg confirmed the folder
   exists on this PC, but this session receives access denied even after read permission
   was granted. Do not interpret that error as evidence the folder is absent.
2. Recover and verify the existing `MSB Preview Update Tree v2.ico` from deployment.
   Neither committed source archive contains it; the installer requires it.
3. Review unresolved apply protections before live writes: LOR closure is currently
   operator acknowledgement only; input XML/candidate can change while review is open;
   install does not revalidate the reviewed input/candidate immediately before replacement;
   reports validate names/revisions/file membership, not master content hashes;
   shared logs omit before/after file hashes and application commit identity.
4. Verify responsive startup, foreground review and second-click blocking against the
   specific committed candidate, then copied-library apply/recovery and LOR reopen.
5. Record exact deployed commit and per-file hashes, existing report identity, per-PC
   results, unmanaged preservation, backup/restore, and idempotent second run before rollout.

No G: deployment, real local-library write, LOR2DB state change, or Production operation
was performed in this continuation. #299 remains open and #300 remains draft.
Do not classify v0.2.2 as accepted for programmer rollout until the remaining gates pass.

## Related authorities

- [Preview Merger ownership boundary](../preview_merger/README.md)
- [LOR version compatibility review](../../Docs/01_LOR_System/02_Data_Extraction/LOR_Preview_Version_Compatibility_Review.md)
- [Repository change workflow](../../System_Documentation/Project_Rules/Repository_Change_Workflow.md)
