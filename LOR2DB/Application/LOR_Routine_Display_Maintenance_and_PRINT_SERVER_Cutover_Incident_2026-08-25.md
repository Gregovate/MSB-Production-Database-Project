# LOR Routine Display Maintenance and PRINT-SERVER Cutover Incident Record — 2026-08-25

| Document control | Value |
|---|---|
| Document type | Dated engineering incident, deployment, and production acceptance record |
| System | LOR parser, PostgreSQL ingest, reconciliation, and Windows runner |
| Date | 2026-08-25 |
| Status | CLOSED — production result verified; follow-up defects remain open |
| Owner | MSB Database Administrator |
| Production result | PostgreSQL ingest 55; reconciliation Run 13; validation PASSED |
| Operational impact | Approximately six hours to add one Display and remove one other Display from active LOR use |

## Executive Summary

The intended maintenance was routine:

1. place a formerly spare Candyland channel into service as `CL-LollipopStick-01`;
2. return `FC-MetroHeatLamp` to a nonphysical `SPARE` channel because the physical Display was recycled; and
3. preserve all permanent PostgreSQL identities and unrelated production data.

This became an approximately six-hour engineering and production recovery session. The delay was not caused by the amount of production data being changed. It exposed defects and undocumented dependencies across LOR UUID behavior, reconciliation classification, parser/ingest browser state, the Windows runner deployment, Google Drive for Desktop, Task Scheduler credentials, Linux pairing, and production-server release provenance.

The final result was correct:

| Display | Final production result |
|---|---|
| `CL-LollipopStick-01` | Existing `display_id=114` remained ACTIVE with raw LOR UUID `e52a445a-d102-4cbc-a784-b63cd29a2bd4` at Stage 17 |
| `FC-MetroHeatLamp` | Existing `display_id=724` remained RECYCLED; the current LOR source row is `SPARE` and is excluded from physical reconciliation |
| `QV-Lollipop` | New `display_id=1121` created ACTIVE with raw LOR UUID `640bad92-98c1-4cc0-a2dc-01d945743e1d` at Stage 30 |

No unrelated production Display, Stage, Scene, or relationship change was accepted.

## Intended Maintenance Contract

The maintenance demonstrated two normal channel lifecycle directions:

- `SPARE -> physical Display`: a spare channel may be renamed and placed into service without being treated as a schema change or false duplicate merely because nonphysical evidence exists elsewhere.
- `physical Display -> SPARE`: a recycled physical Display may remain in `ref.display` as RECYCLED while its former LOR channel is renamed `SPARE`; that LOR row must not reactivate or overwrite the permanent Display.

Adding/removing Displays, renaming spare channels, and editing motion-effect rows are ordinary approved-version preview maintenance. They must not be confused with parser-breaking XML schema changes caused by a new Light-O-Rama version.

## Incident Timeline and Hoops Required

### 1. Approved-version maintenance was initially blocked as a parser schema change

Normal authoring edits caused value-shape and delimiter findings such as blank/string combinations, decimal/integer values, background-image paths, and CustomGrid record counts. These are content-shape changes created by adding/removing ordinary preview objects, not necessarily a new LOR XML contract.

The approved-version compatibility gate was corrected in checker V1.4.0 so routine maintenance within approved LOR 6.6.10 could proceed while genuine schema changes remained gated separately.

### 2. Reconciliation misclassified spare/display lifecycle evidence

The initial preflight showed:

- `CL-LollipopStick-01` as `DUPLICATE_LOR_UUID`; and
- `FC-MetroHeatLamp` as a non-active Display still present in LOR.

Migration `0038_allow_spare_to_display_activation.sql` and validation `33_spare_to_display_activation_validation.sql` were created, reviewed, deployed, and passed. Migration 0038 changed classification only; it did not directly modify production Display rows. It established that SPARE/PHANTOM rows remain visible but do not contribute to physical UUID/name duplicate counts or physical identity groups.

### 3. A copied LOR prop retained an old UUID despite becoming a different design

The Stage 30 Santa's Station lollipops had been copied from an older Candyland preview. Candyland was later redesigned from the spiral matrix to a square matrix, but LOR retained the copied UUID. The QV and CL objects were now different physical/display designs while still sharing raw UUID evidence.

Generating a new UUID was the correct source repair. The Stage 30 lollipop prop set was copied within the QV preview and the original set was deleted. This created one new master raw UUID and three new subprop UUIDs:

- master: `640bad92-98c1-4cc0-a2dc-01d945743e1d`;
- subprop: `98cebbb4-1b2b-483e-b1e2-18d089a931d9`;
- subprop: `99f63813-8907-4492-b91b-f87842f240be`;
- subprop: `73ddd360-9934-4154-ac2e-d91fbd66ecf8`.

The Candyland UUID remained only on `CL-LollipopStick-01`.

### 4. Snapshot 54 had already been ingested before the repaired source was parsed

Parser V7.0.11 had produced and ingested snapshot 54 before the QV UUID repair. No reconciliation run had been started, so production was unchanged, but the workflow correctly prevented silently replacing or backing out a completed PostgreSQL snapshot.

The operator returned to the dashboard and deliberately produced a new parser result rather than attempting to mutate snapshot 54.

### 5. The temporary Office PC runner failed as a production dependency

The runner had been tested on `MSB-OFFICE-PC` at `192.168.5.55:8791`. Closing the PowerShell window stopped the listener. The Linux API and PostgreSQL remained healthy, but the website could no longer start parser/version operations.

This confirmed that the Office PC was acceptable only as a temporary test/rollback host. It was not a reliable permanent production runtime.

### 6. PRINT-SERVER required a complete isolated deployment

The permanent runner was installed on:

```text
Host: PRINT-SERVER
Address: 192.168.5.56
Windows account: PRINT-SERVER\Print Service
Repository: C:\MSB_LORRunner
Virtual environment: C:\MSB_LORRunner\.venv
Scheduled Task: MSB LOR Operator Runner
Runner: V1.6.0
```

The existing Label Print Service remained isolated in `C:\MSB_LabelService` with its own Python process, task, logs, configuration, and printer recovery.

Deployment required:

- cloning reviewed commit `2d896206857d7c4fa1c6e05083dcbe9a4cfe7823`;
- creating an isolated Python environment;
- installing `psycopg2-binary==2.9.10`;
- passing 40 parser/runner tests;
- creating a Private-profile firewall rule for TCP 8791 restricted to remote `192.168.5.9`;
- installing a Password-logon, Highest, at-startup task with a one-minute delay;
- creating new account-bound DPAPI runner and PostgreSQL credentials; and
- verifying local authenticated health.

### 7. Windows credential and execution-policy behavior impeded installation

The repository launcher could not initially run because PowerShell script execution was disabled. A process-scoped `ExecutionPolicy Bypass` was required.

The graphical Windows credential prompt became inaccessible/off-screen and could not be selected with Alt-Tab. The first install attempt therefore persisted some credentials but stopped when the Windows task password was blank. A console `Read-Host -AsSecureString` prompt was required to complete the task installation.

This exposed two launcher defects:

- installation can partially persist state before the Scheduled Task is successfully created; and
- an existing protected token is incorrectly treated as proof that Linux pairing remains valid, even after a partial install or host transfer.

### 8. Pairing required SSH trust, three distinct credentials, and exact release provenance

Pairing involved three different credentials that must not be confused:

1. the PostgreSQL `msbadmin` ingest password stored with Windows DPAPI;
2. the Windows `PRINT-SERVER\Print Service` account password supplied only to Task Scheduler; and
3. the Linux `msbadmin` SSH/sudo password used to transfer and install pairing material.

The initial SSH transfer failed even after host-key review. A direct SSH connection was used to establish the host relationship, after which `PairServer` transferred the pending token successfully.

The production server's existing `/opt/fieldwiring` checkout was protected, on an unrelated deployment-reconnaissance branch, and contained a different pairing-installer hash. It was not changed. The exact installer from merged commit `2d89620` was staged separately:

```text
/tmp/lor-runner-pairing-v1.6.0-2d89620/install_lor_runner_pairing.py
SHA256 348e0bfb2976dfa12547213e78d275e0edbfde143a65c7faae7bbfd5f3adde9e
```

The installer:

- backed up `/etc/msb/lor-preflight-api.env`;
- installed `LOR_RUNNER_URL=http://192.168.5.56:8791`;
- reported only a non-secret credential fingerprint;
- removed the pending plaintext token; and
- deferred the API restart until the compatible backend was confirmed.

### 9. A successful Session-0 path probe produced a false headless conclusion

A temporary Password-logon Scheduled Task reported:

```text
SessionId=0
UserInteractive=False
GDrivePresent=True
required G: paths=True
```

That probe ran while an interactive desktop session had already mounted Google Drive. It did not prove cold-boot availability.

The first real reboot disproved the conclusion:

- PRINT-SERVER responded to ping and SSH;
- the Label Print Service started successfully without login;
- the LOR task exited with result 1;
- no TCP 8791 listener existed; and
- its log reported that `G:\Shared drives\MSB Database\LOR Version Reviews\runner-state.json` was missing.

Starting `GoogleDriveFS.exe --startup_mode` in Session 0 created processes but did not mount `G:`; path probing then hung. Google Drive for Desktop requires an interactive user session for this deployment.

### 10. Automatic Windows login became an explicit production dependency

Because PRINT-SERVER is in a physically locked office and the Print Service credential is controlled onsite, Microsoft Sysinternals Autologon was accepted for `PRINT-SERVER\Print Service`.

Autologon stores the credential as an LSA secret rather than a plaintext Winlogon password, but local administrators can still recover it. This is a deliberate security/availability tradeoff.

The accepted startup chain is now:

```text
Windows boot
  -> automatic Print Service desktop logon
  -> Google Drive for Desktop mounts G:
  -> MSB LOR Operator Runner starts or is restarted after G: is ready
  -> listener becomes available at 192.168.5.56:8791
```

The Label Print Service remains independently capable of starting before login. Only the LOR runner requires the interactive Google Drive mount.

A second reboot passed:

- automatic login completed;
- `G:` became visible;
- the LOR task and listener returned;
- unauthenticated direct health returned the expected 401;
- authenticated Linux API-to-runner status passed; and
- the LOR2DB dashboard reported runner V1.6.0 with no runner error.

### 11. The production parser succeeded, but the browser displayed stale console evidence

The controlled parser run completed successfully:

```text
Parser version: V7.0.11
Host/account: Print Service@PRINT-SERVER
SQLite SHA256: 92b02f2f3f2f66986e5a88ef9e35fa01bb9b9a99a7293533e35899e57c554ddd
Previews: 33
Scenes: 92
Props: 1157
Subprops: 1315
DMX: 508
Scene/prop rows: 2263
Validation: PASSED
```

The page displayed the new SQLite digest but retained console text from the previous parser run. The actual parser activity was verified through the authenticated dashboard API and by opening the exact SQLite file read-only on PRINT-SERVER.

Direct SQLite evidence confirmed:

- four new QV UUIDs;
- no cross-preview CL/QV lollipop UUID collision; and
- the former HeatLamp raw identity now had `FC 23-14 SPARE` / `SPARE`.

### 12. Parser and ingest action buttons required two separate clicks

The operator observed that both parser and ingest controls appeared to require clicking, waiting, and clicking again before the page visibly advanced. This was not a double-click. The first request could already have started work while the page failed to show a reliable pending/running state.

For reconciliation Start, repeating the click was specifically avoided because a duplicate request could create/supersede attempts. The safe workaround was one click, wait, then refresh before considering another action.

This is a correctness and auditability defect, not cosmetic polish.

### 13. Snapshot 55 and reconciliation Run 13 completed successfully

The reviewed output was ingested once:

```text
import_run_id=55
ingest script=V0.4.2
SQLite SHA256=92b02f2f3f2f66986e5a88ef9e35fa01bb9b9a99a7293533e35899e57c554ddd
previews=33
scenes=92
props=1157
sub_props=1315
dmx_channels=508
scene_lor_props=2263
field_wiring=2191
status=PASSED
```

Read-only pre-reconciliation evidence showed:

- `CL-LollipopStick-01`: `EXACT_MATCH`;
- HeatLamp source row `SPARE`: `EXCLUDED_NONPHYSICAL`; and
- `QV-Lollipop`: the only review item, `NEW_DISPLAY_CANDIDATE`.

Reconciliation Run 13 completed and published its immutable report:

```text
Captured ingest: 55
Final status: COMPLETED
Validation: PASSED
Report framework: V0.6.1
```

Post-commit PostgreSQL verification produced the final rows recorded in the Executive Summary.

## Final Production Acceptance

The change is accepted because all of the following passed:

- approved-version parser validation;
- exact SQLite digest verification;
- raw PropClass UUID completeness;
- DMX source-detail completeness;
- PostgreSQL ingest 55;
- pre-reconciliation identity classification;
- reconciliation Run 13 database validation;
- immutable report publication;
- exact final `ref.display` row verification;
- PRINT-SERVER local runner health;
- authenticated Linux API-to-runner health;
- dashboard runner state;
- automatic-login reboot recovery; and
- isolation from the existing Label Print Service; and
- a successful physical Display label printed by the Label Service after reboot.

## Unresolved Engineering Defects

The production data change is closed. The following engineering work remains:

1. Parser and ingest controls must submit once, immediately disable, expose a durable operation ID/state, and never rely on a second click.
2. Parser/ingest console evidence must be bound to the exact activity ID and SQLite digest displayed for approval.
3. The runner must distinguish token existence from confirmed Linux pairing state.
4. Runner installation must be transactional or explicitly recoverable after a failed task-password step.
5. Task-password prompting must work in a normal console and not depend on an inaccessible GUI credential window.
6. PRINT-SERVER startup must wait/retry for the Google Drive mount after autologon instead of exiting permanently when `G:` is late.
7. Cold-boot acceptance must be required before documenting any mapped-drive path as headless/unattended.
8. Unknown API routes must return a truthful 404 rather than being converted into a generic internal-error response.
9. The operator workflow needs a bounded maintenance path so adding one Display and recycling one Display cannot reasonably consume six hours.

These defects are to be tracked as GitHub issues linked to this permanent incident record.

## Security and Evidence Notes

- No bearer token, Windows password, PostgreSQL password, or Linux password is recorded here.
- Credential fingerprints are non-secret comparison evidence, but raw tokens remain excluded.
- The Office PC runner files remain available only as controlled rollback material; it must not listen concurrently with PRINT-SERVER.
- The protected production checkout under `/opt/fieldwiring` was not modified during pairing.
- Production environment backups created during pairing must follow the normal protected-server retention policy.

## Related Documents

- [LOR Runner Host Operations and Disaster Recovery](Office_PC_Runner_Operations_and_Disaster_Recovery.md)
- [LOR Preflight Operator Interface](README.md)
- [Run an LOR Production Update](../../Docs/02_Production_Database/02_Operational_SOPs/LOR2DB/Run_an_LOR_Production_Update.md)
- [Migration 0038](../02_Reconciliation/reconciliation/migrations/0038_allow_spare_to_display_activation.sql)
- [Validation 33](../02_Reconciliation/reconciliation/validation/33_spare_to_display_activation_validation.sql)
- [PRINT-SERVER Runtime Runbook](https://github.com/Gregovate/MSB_LabelPrintService/blob/main/docs/Print_Server_Runtime_Runbook.md)
