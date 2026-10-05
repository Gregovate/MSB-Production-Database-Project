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

Current test candidate: **v0.2.7 (2026-10-04)**; laptop live installation passed; LOR reopen/repeat acceptance pending; shared deployment remains unverified.

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

### Operator acceptance and taskbar retest

Greg's v0.2.3 screenshots confirm that an open Sequencer blocks continuation even
after both acknowledgements are ticked, and closing Sequencer permits the
retest-only success message. Greg explicitly confirmed that acknowledgements worked.
This establishes review/Sequencer-guard acceptance on this PC, not live apply acceptance.
The screenshot also shows a PowerShell taskbar icon despite the tree icon on the form.

The [v0.2.4 source candidate](artifacts/LOR2DB_2PC_Sync_SOURCE_v0.2.4.zip)
has SHA-256 `0d70a222d74e2f511f456a8616c6525c0d84f6f3d766fbf171c97a366b5b39d4`.
It sets process AppUserModelID `MSB.LOR.PreviewSync` before opening windows to
separate taskbar grouping from the PowerShell host. Form tree-icon assignments
remain in place. The window title identifies v0.2.4 and Updated 2026-10-04.
Windows PowerShell 5.1 compilation, eight disposable engine checks and successful
native taskbar-identity registration passed. Actual taskbar appearance remains an
operator retest item. Use the included review-only launcher on a copied library;
do not proceed to live install or rollout based on the taskbar correction alone.

Microsoft's [AppUserModelID documentation](https://learn.microsoft.com/en-us/windows/win32/api/shobjidl_core/nf-shobjidl_core-setcurrentprocessexplicitappusermodelid)
owns the Windows process taskbar identity API contract.

### Splash folder display — v0.2.5

Greg confirmed the v0.2.4 taskbar icon is correct and that full acceptance has not
yet been attempted. The supplied startup screenshot shows Windows `Not Responding`
during comparison of the first master preview; startup responsiveness is still a
launch blocker and must not be marked passed based on the eventual review screen.

The [v0.2.5 source candidate](artifacts/LOR2DB_2PC_Sync_SOURCE_v0.2.5.zip) has
SHA-256 `c92c5da939c1779bcbef723f9c7bf40c88c4161a710540bd9e622cd4ff5d69af`.
Its enlarged splash has a persistent, wrapping master-folder label separate from
per-preview progress. The label starts with accepted-source discovery feedback,
then displays the exact folder from the completed report while comparison runs.
The review-only launcher remains non-installing. This presentation change does
not fix or establish acceptance of the UI-thread comparison delay. Next steps:
verify path readability, correct the remaining startup blocking work, then resume
the pending live/two-PC acceptance gates.

### Comparison-stage feedback — v0.2.6

Greg accepted the improved splash folder display and clarified that the observed
`Not Responding` pause occurs while comparing the large Master Musical Preview
(preview 1 of 34). The screenshot already shows the correct per-preview operation.
Do not classify this as absent preview feedback or an accepted responsiveness fix.

The [v0.2.6 source candidate](artifacts/LOR2DB_2PC_Sync_SOURCE_v0.2.6.zip) has
SHA-256 `33db6a5c71933358049197779184bee5e23afdb7568705ac3da72df610fffa99`.
It additionally reports local-library reading, XML validation, identity/duplicate
checking, candidate construction and final verification. Existing per-preview
messages and persistent master-folder display remain. Windows PowerShell 5.1
compilation and the eight disposable engine checks passed. Runtime comparison
semantics are unchanged; review-only retest still exits before installation.
Large-preview UI-thread blocking and full acceptance remain unresolved.

Greg explicitly reported the v0.2.6 progress-feedback retest PASS at application
commit `125af7aaa6c956b556aa5d64ba15176afe4f6359`. This accepts the requested
feedback change only; it does not establish live apply/recovery, LOR reopen,
second-PC acceptance or resolution of the separately observed responsiveness issue.

- [Preview Merger ownership boundary](../preview_merger/README.md)
- [LOR version compatibility review](../../Docs/01_LOR_System/02_Data_Extraction/LOR_Preview_Version_Compatibility_Review.md)
- [Repository change workflow](../../System_Documentation/Project_Rules/Repository_Change_Workflow.md)

## Laptop live acceptance candidate — v0.2.7

Greg authorized using his laptop for the first live update and confirmed he saved
a separate copy of its `LORPreviews.xml`. This is bounded laptop acceptance;
Production, approved master files and G: application source remain untouched.
The laptop's observed original SHA-256 remains
`d5f4588d7b581cc34d9fd7b915df4cc9b5c3919da3f35625a202407c04b8fd6f`.

The [v0.2.7 source candidate](artifacts/LOR2DB_2PC_Sync_SOURCE_v0.2.7.zip) has
SHA-256 `32c3c0c8025ca1cd0fa9f3d2e8cd9d666f3b13ad70f556afc95dd46e04a2c024`.
It freezes the original-library and reviewed-candidate hashes before review,
blocks changed files, reparses the candidate, rechecks Sequencer before install,
and atomically captures the actual displaced original in a unique backup.
A concurrent-change backup mismatch restores the displaced original and stops.
Installed content is hash checked. Audit logs include version, deployed commit
metadata, original/current/candidate hashes and local destination. Missing or
mismatched `DEPLOYMENT.json` identity blocks the live installation.

Master files are still read once per launch; their raw hashes, identities and names
must match `_MSB_CONTROLLED_PREVIEW_MANIFEST.csv`, as well as Run 29's inventory.
This detects content changes that filename/name/revision checks alone would miss.
Normal season-start MASTER -> LOCAL authority remains unchanged. Later smart
Master Musical motion-row versus protected-channel comparison is deferred #299
work; current substantive replacements retain full warning/acknowledgement.

Windows PowerShell 5.1 checks passed for eleven disposable engine/install/recovery
cases, including stale local/candidate rejection and byte-exact backup restore.
All 34 copied master files passed report/manifest validation, and a simulated raw
hash mismatch blocked. This is not live installation or LOR reopen evidence.

The new `Update Laptop Previews - Acceptance.vbs` launcher targets the real local
library (unlike review-only retests). Greg must close Sequencer, review the complete
list, acknowledge both controls, and explicitly click Update PC Previews. Reopen
LOR after success, verify managed/personal previews, close LOR and rerun; require
no adds/replacements. Preserve backup and logs. Known long Master Musical UI-thread
pause remains open for wider rollout; this bounded acceptance does not mark it fixed.
Greg completed the first live laptop installation on YOGA-GREG at 23:14
America/Chicago, 2026-10-04, using application commit
`9f2f971f9650d7a4413886ce20a43a5d74b093d4`. The success screenshot and APPLIED log
report 8 replacements, 2 additions and 8 unmanaged identities preserved.
Independent read-only hash verification confirms installed bytes match the reviewed
candidate `efd348871a9c9924d539ba11eef76c6ce309ae64081dc92520097bc220c99a1f`
and the timestamped backup matches the original
`d5f4588d7b581cc34d9fd7b915df4cc9b5c3919da3f35625a202407c04b8fd6f`.
LOR reopen/usability, closed-LOR idempotent repeat, second PC and shared deployment
remain pending. Production and master previews were not changed.
