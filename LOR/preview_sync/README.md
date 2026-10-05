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

Current test candidate: **v0.2.3 (2026-10-04)**; live deployment remains unverified.

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
2. Include the recovered [tree/star icon](artifacts/MSB%20Preview%20Update%20Tree%20v2.ico)
   when building the next committed runtime package. Neither existing source archive
   contains it; the installer requires it. The supplied icon loads as 32 x 32.
3. Review unresolved apply protections before live writes: process detection is
   limited to verified `LORSequencer` and legacy `LORSequenceEditor` executable names;
   input XML/candidate can change while review is open;
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

## Copied-input acceptance — 2026-10-04

Greg supplied local copies of the Run 29 HTML report, shortcut icon and complete
`Database Previews V6.6.12` folder including its extraction manifest. G: itself
remains inaccessible to this session; copied-input validation does not establish
the state of the current G: deployment.

Using Windows PowerShell 5.1 and v0.2.2 application commit
`318d74b17805435c4e8dd4f72d6ea6f094420d42`:

- Report parser recognizes completed Run 29 and its 34 source previews.
- Copied master matches report filenames, names, revisions and count.
- All 34 master files match the supplied manifest's raw SHA-256 values;
  manifest PreviewIDs/names match the parsed files, with no duplicate manifest filenames.
- Local library contains 40 previews: 21 current, 3 revision-only NOOP,
  8 controlled replacements, 2 controlled additions, 8 unmanaged identities preserved.
- Candidate re-comparison requires zero additions/replacements.
- Live local XML SHA-256 before and after comparison is identical:
  `d5f4588d7b581cc34d9fd7b915df4cc9b5c3919da3f35625a202407c04b8fd6f`.
- Read/compare/validate plus second candidate comparison took 27.640 seconds
  against copied files. This does not measure G: access or prove GUI responsiveness.

The [copied-input result](artifacts/acceptance-v0.2.2-run29.json) records input
and candidate hashes. Raw report/XML/master files remain operational inputs and
are not committed. Candidate XML and action CSV remain local acceptance evidence.
No real-library install or Production write was performed. Remaining resume point:
complete the apply protections above, then test exact committed runtime startup,
single-instance behavior, copied-library recovery, LOR reopen and both PCs.

## Acknowledgement retest candidate — v0.2.3

The [v0.2.3 source archive](artifacts/LOR2DB_2PC_Sync_SOURCE_v0.2.3.zip) has
SHA-256 `8d018cd611829ff108fc45eba2a75bc8bd65a09edead1b7a0e6002319e7aee19`.
It includes the recovered icon and comparison-only acknowledgement launcher.
Raw Run 29 HTML remains an operational input and is excluded from the archive.

- Review explicitly names `C:\lor\CommonData\LORPreviews.xml`.
- Both closure and change acknowledgement are mandatory for additions or replacements.
- Review continuation and actual install both check for `LORSequencer` or
  `LORSequenceEditor`; the installed `LORSequencer.exe` name was verified on this PC.
- `-ReviewOnly` exercises the review and blocking checks, logs the result and exits
  before installation. The supplied retest launcher passes a separate copied library.
- Eight disposable engine checks plus running Sequencer, running legacy editor and
  no-Sequencer guard cases passed in Windows PowerShell 5.1.

Retest the actual UI with Sequencer open (continuation must block), then close it,
acknowledge both checkboxes and require the retest-only success message. No live-file
apply is authorized by this retest. Remaining apply protections and two-PC/live
acceptance listed above are still required before rollout. Visible retest date/version
are recorded in `VERSION.txt`; application source identifies v0.2.3.

## Related authorities

- [Preview Merger ownership boundary](../preview_merger/README.md)
- [LOR version compatibility review](../../Docs/01_LOR_System/02_Data_Extraction/LOR_Preview_Version_Compatibility_Review.md)
- [Repository change workflow](../../System_Documentation/Project_Rules/Repository_Change_Workflow.md)
