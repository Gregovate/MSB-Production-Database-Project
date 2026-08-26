# LOR Runner Host Operations and Disaster Recovery

| Document control | Value |
|---|---|
| Repository path | `LOR2DB/Application/Office_PC_Runner_Operations_and_Disaster_Recovery.md` |
| Document type | Engineering operations and recovery runbook |
| Status | CURRENT — PRINT-SERVER production deployment accepted 2026-08-25 |
| Owner | MSB Database Administrator |
| Initial release / current revision | 2026-08-17 / 2026-08-25 |

## Revision History

| Date | Change |
|---|---|
| 2026-08-25 | Corrected the false Session-0 Google Drive conclusion; recorded the required Print Service autologon, completed V1.6.0 cutover, reboot/parser/ingest/Run 13 acceptance, and remaining startup limitations. |
| 2026-08-25 | Recorded the initial PRINT-SERVER Session-0 path probe and added the V1.6.0 `PrintServerUnattended` installation and cutover procedure. |
| 2026-08-25 | Recorded the Office Desktop as a temporary/test host and PRINT-SERVER as the approved permanent production host; added transfer prerequisites and acceptance boundary. |
| 2026-08-17 | Initial controlled runbook for installation, restart, credential recovery, network failure, and replacement-PC transfer. |

## Purpose

This runbook defines the Windows runner-host dependency behind the
browser-operated LOR parser, version checker, and PostgreSQL ingest. It covers
the current temporary Office Desktop deployment, normal status and restart
actions, Windows recovery, credential recovery, and controlled transfer to the
approved permanent PRINT-SERVER host.

This is not a normal operator procedure. Authorized operators use the LOR2DB
website. Use this document only to maintain or recover the engineering service
boundary behind that website.

## Approved Production Host — Deployed and Accepted 2026-08-25

The Office Desktop deployment is retained only as disabled rollback material.
The accepted production runtime is:

```text
Rollback host: MSB-OFFICE-PC (192.168.5.55)
Production host: PRINT-SERVER (192.168.5.56)
Permanent account: PRINT-SERVER\Print Service
Repository: C:\MSB_LORRunner
Listener: 192.168.5.56:8791
Runner: V1.6.0
Transfer status: PRODUCTION ACCEPTED
```

Closing the interactive Office Desktop runner had stopped TCP 8791 while the
Linux API and PostgreSQL remained healthy. The replacement was therefore
deployed as a separate PRINT-SERVER runtime, isolated from the existing
`MSB Label Service` process, task, working directory, Python environment,
credentials, logs, and printer recovery.

Linux is paired to `http://192.168.5.56:8791`. Parser V7.0.11, PostgreSQL
ingest 55, reconciliation Run 13, report publication, final `ref.display`
verification, a post-autologon reboot, and a physical Display label through the independent Label Print Service all passed on 2026-08-25.

### Google Drive Cold-Boot Gate — INITIAL PROBE INVALID; AUTOLOGON ACCEPTED

A temporary Password-logon Session-0 task initially reported `GDrivePresent=True`
and found every required `G:` path. That test ran while a desktop session had
already mounted Google Drive and did not prove cold-boot availability.

The first true reboot disproved the conclusion. Before interactive login:

- PRINT-SERVER, SSH, and the Label Print Service were available;
- Google Drive `G:` was absent;
- the LOR task exited with result 1;
- no TCP 8791 listener existed; and
- the runner log identified the missing `runner-state.json`.

Starting `GoogleDriveFS.exe --startup_mode` in Session 0 did not mount `G:`
and caused path checks to hang. This deployment of Google Drive for Desktop
requires an interactive Print Service session.

Microsoft Sysinternals Autologon was deliberately enabled for
`PRINT-SERVER\Print Service`. PRINT-SERVER is physically controlled, and this
availability/security tradeoff was accepted by the MSB Database Administrator.
The credential value is not recorded in Git. Autologon uses an LSA secret, but
local administrators can still recover it.

The accepted boot dependency is automatic Print Service login, Google Drive
startup and `G:` mount, then LOR runner availability. A cold reboot after
Autologon passed local listener, authenticated Linux API, dashboard, controlled
parser, ingest 55, and Run 13 acceptance. The temporary probe task and files
were removed.

Launcher V1.6.0 now implements two explicit deployment profiles:

| Profile | Host model | Task model | Default listener |
|---|---|---|---|
| `OfficeInteractive` | Temporary recovery | At user logon / Interactive / Limited | `192.168.5.55:8791` |
| `PrintServerUnattended` | Approved permanent target | At startup after one minute / Password / Highest | `192.168.5.56:8791` |

The unattended profile refuses installation or startup unless the computer is
`PRINT-SERVER` and the current identity is
`PRINT-SERVER\Print Service`. The password is requested through a Windows
credential prompt and is supplied only to Task Scheduler; it is not stored in
the repository, command line, runner state, or service log.

The PRINT-SERVER host/runtime prerequisites and dual-workload isolation gates
are controlled by the
[Print Server Runtime Runbook](https://github.com/Gregovate/MSB_LabelPrintService/blob/main/docs/Print_Server_Runtime_Runbook.md).

## Dependency Summary

The deployed LOR2DB application spans two computers and the shared Google Drive. This diagram describes the accepted PRINT-SERVER production deployment:

```text
Authenticated browser
    -> Linux LOR2DB API on msb-prod-db (192.168.5.9:8784)
    -> authenticated HTTP request from 192.168.5.9
    -> PRINT-SERVER runner (192.168.5.56:8791)
    -> reviewed C:\MSB_LORRunner code and account-bound DPAPI credentials
    -> interactive Print Service session mounts G:\
    -> Shared Drive previews, state, reports, and SQLite output
```

The PRINT-SERVER runner is required for:

- LOR-version candidate detection and compatibility checks;
- routine production parser execution and console capture; and
- the fixed digest-locked PostgreSQL ingest.

The Office PC runner is not required for:

- reviewing or finishing an already-started reconciliation;
- applying its database-controlled P1–P4 phases;
- publishing a reconciliation report;
- viewing an existing report; or
- normal PostgreSQL and Directus operation.

If the runner is offline, do not assume PostgreSQL or an open reconciliation is
down. The parser/version/ingest controls are unavailable, but an already
committed snapshot and an already-started reconciliation remain on the Linux
and PostgreSQL side.

## Current PRINT-SERVER Production Components

| Component | Production requirement |
|---|---|
| Windows host | PRINT-SERVER; reserved address `192.168.5.56` |
| Windows account | `PRINT-SERVER\Print Service`; owns the interactive Google Drive mount and DPAPI secrets |
| Repository | `C:\MSB_LORRunner`, reviewed `main` checkout with isolated `.venv` |
| Launcher | Repository-root `run_lor_runner.ps1` |
| Scheduled Task | `MSB LOR Operator Runner`, startup trigger, Password logon, Highest, one-minute delay |
| Listener | `192.168.5.56:8791`, private LAN only |
| Firewall | Inbound TCP 8791, Private profile, remote address `192.168.5.9` only |
| State | `G:\Shared drives\MSB Database\LOR Version Reviews\runner-state.json` |
| SQLite output | `G:\Shared drives\MSB Database\database\lor_output_v7_scene.db` |
| Runner token | `%LOCALAPPDATA%\MSB\LORRunner\runner-token.dpapi` |
| PostgreSQL ingest password | `%LOCALAPPDATA%\MSB\LORRunner\postgres-ingest-password.dpapi` |
| Service log | `%LOCALAPPDATA%\MSB\LORRunner\runner-service.log` |
| Linux environment | `/etc/msb/lor-preflight-api.env`, mode `0640`, owner `root`, group `msbadmin` |
| Linux API service | `lor-preflight-api.service`, user `lor-preflight`, group `msbadmin` |

Both DPAPI files are bound to the Windows account that created them. Treat them
as local encrypted state, not portable backups. Copying them to another PC or
running the task under another account will not recover their plaintext.

## Credential Prompts Are Different

Three prompts can appear during installation. They are not interchangeable:

| Prompt or command | Credential required | Purpose |
|---|---|---|
| `Install` or `ConfigureIngest` asks for the PostgreSQL ingest password | PostgreSQL database account `msbadmin` password | Lets the fixed ingest child connect to PostgreSQL |
| `PairServer` invokes `ssh msbadmin@192.168.5.9` | Linux server account `msbadmin` password | Transfers the new pairing token to the server |
| Linux command begins with `sudo` | Linux server account `msbadmin` password | Authorizes protected environment installation or service restart |

Never use the runner bearer token at any of these password prompts.

## Initial Installation or Rebuild

Use these steps for the first controlled install on a PC or after rebuilding
Windows. A replacement PC must also follow the transfer controls later in this
document.

1. Sign in as the Windows account that will permanently run the listener.
2. Clone or update the repository and create the repository-root `.venv`.
   Install the parser and fixed-ingest dependencies and pass the release's
   parser/application/reporting tests.
3. Confirm the authoritative Shared Drive state already exists. Do not create a
   replacement state file:

   ```powershell
   $statePath = "G:\Shared drives\MSB Database\LOR Version Reviews\runner-state.json"
   Test-Path -LiteralPath $statePath
   $state = Get-Content -LiteralPath $statePath -Raw | ConvertFrom-Json
   Test-Path -LiteralPath $state.current_preview_folder
   Test-Path -LiteralPath $state.current_manifest_path
   ```

   All three checks must return `True`, and the state must show the expected
   approved LOR version and preview folder.
4. In an elevated PowerShell window, install the inbound Private-profile
   firewall rule for TCP 8791, restricted to remote address `192.168.5.9`. The
   replacement-PC procedure contains the exact command.
5. Return to a normal PowerShell window under the permanent runner account and
   run from the repository root:

   ```powershell
   .\run_lor_runner.ps1 -Action Install
   .\run_lor_runner.ps1 -Action Status
   ```

   `Install` creates or retains the DPAPI runner token, requests the PostgreSQL
   ingest password only when needed, registers the logged-in-user Scheduled
   Task, and starts the listener.
6. Determine pairing from the deployed host, token fingerprint, and Linux
   environment—not merely from whether a local protected token exists. A
   partial install can retain a token before the task is usable. For a new host,
   rotated token, or uncertain pairing state, run `PairServer`, install the
   pending token on Linux, compare non-secret fingerprints, restart the API,
   and verify authenticated backend-to-runner health.
7. Require a healthy Windows `Status`, a passing Linux backend-to-runner check,
   and the expected runner version on the LOR2DB dashboard before returning the
   service to operators.

## Normal Status Check

Run this from a normal PowerShell window in `C:\MSB_LORRunner` on PRINT-SERVER:

```powershell
.\run_lor_runner.ps1 -Action Status
```

A healthy result must show:

- Scheduled Task state `Running`;
- protected runner token `AVAILABLE`;
- protected PostgreSQL ingest credential `AVAILABLE`;
- runner health `ok`; and
- runner version `V1.6.0` or the later version documented by the deployed
  release.

The displayed credential fingerprint is not a secret. It is safe to use when
confirming that Windows and Linux hold the same pairing token. Never display or
copy the token itself.

## Normal Restart or Repository Upgrade

Do not restart while the parser or ingest is running.

1. Pull the reviewed repository change on the Office PC.
2. Run the release's required Python tests and PowerShell syntax check.
3. From the repository root, run:

   ```powershell
   .\run_lor_runner.ps1 -Action Install
   ```

4. When an existing protected token is retained, do not run `PairServer`.
5. Run `Status` and require a healthy local result.
6. Confirm the LOR2DB dashboard shows the same runner version.

`Install` safely stops only the managed runner process whose command line
matches this repository, listener address, and port. It refuses to stop an
unrelated process and refuses to reinstall during a recorded parser or ingest
operation.

For a deliberate stop or start:

```powershell
.\run_lor_runner.ps1 -Action Stop
.\run_lor_runner.ps1 -Action Start
.\run_lor_runner.ps1 -Action Status
```

Normally the Scheduled Task starts the runner automatically at user logon.

## After a Reboot or Windows Update

1. Confirm Sysinternals Autologon completed for `PRINT-SERVER\Print Service`.
2. Wait for Google Drive for Desktop to mount `G:`.
3. Confirm the current preview folder, manifest, and `runner-state.json` are
   available.
4. Run `Status` from `C:\MSB_LORRunner`.
5. If the task attempted startup before `G:` was ready, verify no managed
   listener is running, then run `Start` once and check `Status`.
6. Verify authenticated Linux API-to-runner health and the LOR2DB dashboard.
7. If startup fails, review:

   ```powershell
   Get-Content "$env:LOCALAPPDATA\MSB\LORRunner\runner-service.log" -Tail 60
   ```

Screen locking does not stop the runner. Logging out removes the interactive
Google Drive mount and makes parser/ingest operations unavailable. The Label
Print Service remains independent and does not require this login.

The runner currently exits when `G:` is late rather than retrying. That is a
known engineering defect; do not repeatedly start tasks without first checking
the listener and service log.

## Restore the PostgreSQL Ingest Credential

Use this when the PostgreSQL password changed, the DPAPI ingest file is missing,
or Windows reports that it cannot decrypt the stored credential:

```powershell
.\run_lor_runner.ps1 -Action ConfigureIngest
```

Enter the PostgreSQL `msbadmin` password at the secure prompt. The launcher
stores it with account-bound DPAPI, restarts the managed runner, and never sends
the password to the browser or Linux API. Finish with `Status`.

## Replace or Transfer the Office PC

Changing the Office PC is a controlled service transfer. The following items
break until the transfer is completed:

- the Linux API's configured runner IP and bearer token;
- the Windows firewall rule if the replacement uses a different address;
- the Scheduled Task, local repository, Python environment, and service log;
- both account-bound DPAPI credential files; and
- access to the approved `G:` paths if Google Drive is not installed and mapped
  for the new logged-in account.

The shared `runner-state.json`, approved manifest, preview folders, parser
reports, and SQLite output remain recoverable because they live on the Shared
Drive. Do not initialize a replacement runner state over the existing file.

### PRINT-SERVER transfer gate

The generic replacement procedure below describes the existing
logged-in-user runner design. It must **not** be executed unchanged for the
approved PRINT-SERVER transfer.

Transfer requirements and current status:

1. **CORRECTED 2026-08-25:** The initial Session-0 path probe was a false
   positive caused by an already-mounted desktop `G:`. Cold boot proved the
   mapping is interactive. The accepted production control is Print Service
   Autologon followed by Google Drive startup; a future durable noninteractive
   source path would remove this dependency.
2. **DEPLOYMENT STEP:** Establish a separate LOR runner working directory and Python environment.
   Do not install into `C:\MSB_LabelService`, alter its Python dependencies, or
   reuse its logs or configuration.
3. **IMPLEMENTED IN V1.6.0:** The reviewed `PrintServerUnattended` profile
   creates an at-startup, Password-logon, Highest task under the permanent
   Print Service account and retains the Office interactive rollback profile.
4. **DEPLOYMENT STEP:** Use the reserved PRINT-SERVER address `192.168.5.56` for the listener and
   restrict inbound TCP 8791 to `192.168.5.9`.
5. **DEPLOYMENT STEP:** Create new DPAPI-protected runner and PostgreSQL credentials under the
   permanent task account. Existing Office Desktop DPAPI files are not
   portable.
6. **CUTOVER STEP:** Back up the Linux pairing environment, then re-pair it to
   `http://192.168.5.56:8791` only when the new runner is ready for controlled
   cutover.
7. **ACCEPTANCE STEP:** Require local health, Linux API-to-runner health, dashboard availability,
   controlled parser validation, dual-task reboot recovery, and an unaffected
   physical Label Print Service test before disabling the Office Desktop
   runner.

The PRINT-SERVER host facts and workload-isolation requirements are maintained
in the
[Print Server Runtime Runbook](https://github.com/Gregovate/MSB_LabelPrintService/blob/main/docs/Print_Server_Runtime_Runbook.md).

### PRINT-SERVER controlled installation

Run these commands locally on `PRINT-SERVER` while signed in as
`PRINT-SERVER\Print Service`. Use a separate elevated PowerShell window only
for the firewall rule.

1. Create the isolated working tree and virtual environment:

   ```powershell
   Set-Location C:\
   git clone `
       https://github.com/Gregovate/MSB-Production-Database-Project.git `
       C:\MSB_LORRunner

   Set-Location C:\MSB_LORRunner
   git switch main
   git pull --ff-only

   & "C:\Program Files\Python\python.exe" -m venv .venv
   .\.venv\Scripts\python.exe -m pip install --upgrade pip
   .\.venv\Scripts\python.exe -m pip install psycopg2-binary==2.9.10
   ```

2. Validate the reviewed release before creating credentials or tasks:

   ```powershell
   [scriptblock]::Create((Get-Content .\run_lor_runner.ps1 -Raw)) |
       Out-Null

   .\.venv\Scripts\python.exe -m unittest discover `
       -s .\Docs\01_LOR_System\02_Data_Extraction\Parser `
       -p "test_*.py"
   ```

   All tests must pass. Do not install the task from an uncommitted or dirty
   working tree.

3. In an elevated PowerShell window, create the isolated inbound firewall
   rule:

   ```powershell
   New-NetFirewallRule `
       -DisplayName "MSB LOR Runner 8791" `
       -Direction Inbound `
       -Action Allow `
       -Profile Private `
       -Protocol TCP `
       -LocalAddress 192.168.5.56 `
       -LocalPort 8791 `
       -RemoteAddress 192.168.5.9 `
       -Program "C:\MSB_LORRunner\.venv\Scripts\python.exe"
   ```

   Do not modify the Label Service task, firewall behavior, Python runtime, or
   `C:\MSB_LabelService`.

4. Back in the normal Print Service PowerShell window, install and verify the
   new runner:

   ```powershell
   Set-Location C:\MSB_LORRunner

   .\run_lor_runner.ps1 `
       -Action Install `
       -DeploymentProfile PrintServerUnattended

   .\run_lor_runner.ps1 `
       -Action Status `
       -DeploymentProfile PrintServerUnattended
   ```

   `Install` prompts separately for the PostgreSQL `msbadmin` ingest password
   and the Windows `PRINT-SERVER\Print Service` task password. Do not confuse
   those credentials. Do not pair Linux until local status shows task
   `Running`, both DPAPI-protected credentials `AVAILABLE`, health `ok`, and
   runner `V1.6.0`.

5. Confirm the installed task contract:

   ```powershell
   (Get-ScheduledTask -TaskName "MSB LOR Operator Runner").Principal |
       Format-List UserId,LogonType,RunLevel

   (Get-ScheduledTask -TaskName "MSB LOR Operator Runner").Triggers |
       Format-List *
   ```

   Require `Print Service`, `Password`, `Highest`, an at-startup trigger, and a
   one-minute delay.

Historical note: installation alone did not complete the cutover. Linux re-pairing, cold-reboot/autologon recovery, parser, ingest 55, Run 13, and Label Service isolation were all required and passed before production acceptance.

### Transfer procedure

1. Stop the old runner after confirming no parser or ingest is running:

   ```powershell
   .\run_lor_runner.ps1 -Action Stop
   ```

   If the old PC is unavailable, keep it powered off or disconnected from the
   network. Do not allow it to return with the old listener active after the
   replacement is paired.

2. Preserve the existing Shared Drive data, especially:

   - `LOR Version Reviews\runner-state.json`;
   - the current approved manifest;
   - the approved versioned preview folder;
   - parser/version reports; and
   - `database\lor_output_v7_scene.db`.

3. On the replacement PC, install Git, Python, Google Drive, and the approved
   LOR software version. Clone the repository, recreate the repository-root
   `.venv`, install the Python dependencies required by the parser and fixed
   PostgreSQL ingest, and pass the release's parser/application/reporting test
   commands before installing the service.
4. Sign in as the Windows account that will permanently run the service and
   confirm every path referenced by the existing `runner-state.json` resolves.
5. Give the replacement a reserved private IPv4 address. If it will not retain
   `192.168.5.55`, record the new address for the Linux pairing step.
6. In an elevated PowerShell window, create an inbound firewall rule restricted
   to the database server:

   ```powershell
   New-NetFirewallRule `
       -DisplayName "MSB LOR Runner 8791" `
       -Direction Inbound `
       -Protocol TCP `
       -LocalPort 8791 `
       -RemoteAddress 192.168.5.9 `
       -Action Allow `
       -Profile Private
   ```

7. In a normal PowerShell window under the permanent runner account, install
   the runner. Supply the replacement PC's address when it differs:

   ```powershell
   .\run_lor_runner.ps1 `
       -Action Install `
       -RunnerHost 192.168.5.55
   ```

   `Install` generates a new runner token and prompts once for the PostgreSQL
   ingest password because DPAPI files are not portable.
8. Pair the newly generated token to Linux:

   ```powershell
   .\run_lor_runner.ps1 `
       -Action PairServer `
       -RunnerHost 192.168.5.55
   ```

9. On `msb-prod-db`, install the pending pairing. Use the replacement PC's
   actual address. A permanent repository clone is not required on the server,
   but the installer must be the reviewed file from the same deployed release.

   If a current repository checkout or release staging tree is already present,
   run its reviewed installer by path:

   ```bash
   sudo python3 LOR2DB/Application/install_lor_runner_pairing.py \
     --runner-url http://192.168.5.55:8791
   sudo systemctl restart lor-preflight-api.service
   ```

   If the server has no checkout, transfer only
   `LOR2DB/Application/install_lor_runner_pairing.py` from the reviewed Windows
   checkout into an operator-owned mode-`0700` staging directory, compare its
   SHA-256 on both computers, and invoke that verified file by absolute path.
   Do not download an unreviewed copy directly onto production.

10. Confirm that the non-secret fingerprint printed on Linux matches Windows.
11. Run Windows `Status`, verify Linux API health, and confirm the LOR2DB
    dashboard reports the expected runner version.
12. Run a parser only after checking that the approved LOR version and preview
    source shown by the website are unchanged. Do not perform an ingest merely
    to test the replacement.
13. Remove or disable the old listener and its firewall rule before returning
    the old PC to unrelated use.

If the previous PC failed during a parser or ingest, treat the operation as
interrupted. Check the website's durable operation record and, for ingest, the
completed SQLite digest in PostgreSQL before retrying. A console or network
failure after database commit must reuse the existing import rather than create
a duplicate snapshot.

Replace `192.168.5.55` in these commands with the reserved replacement address
when the address changes. Do not leave the Linux environment pointed at the old
computer.

## Linux Verification Without Exposing the Token

Run the following on `msb-prod-db`. It reads the protected environment as the
service account and prints only runner status and version:

```bash
sudo -u lor-preflight /opt/lor-preflight/.venv/bin/python - <<'PY'
import os
import sys
from pathlib import Path

for line in Path("/etc/msb/lor-preflight-api.env").read_text(
    encoding="utf-8"
).splitlines():
    line = line.strip()
    if not line or line.startswith("#") or "=" not in line:
        continue
    key, value = line.split("=", 1)
    if key in {"LOR_RUNNER_URL", "LOR_RUNNER_TOKEN"}:
        os.environ[key] = value

sys.path.insert(0, "/opt/lor-preflight")
import backend

health = backend.runner_request("health")
print("Backend-to-runner status:", health.get("status"))
print("Backend-to-runner version:", health.get("version"))
PY
```

## Failure Matrix

| Symptom | Likely boundary | Safe action |
|---|---|---|
| Temporary Office Desktop runner is unavailable after reboot | No interactive logon or `G:` not restored | Sign in, restore `G:`, then run `Status`; do not represent this as the permanent production design |
| PRINT-SERVER task starts but LOR state/source paths are unavailable | Autologon/Google Drive did not mount `G:` before prerequisites ran | Verify the Print Service desktop session and `G:` first; inspect the runner log; start one managed instance only after paths exist |
| Scheduled Task is `Ready`, no listener exists | Task exited during prerequisite or credential check | Review service log, fix the named prerequisite, run `Start` |
| Port 8791 belongs to an unrelated process | Listener conflict | Do not kill it through the launcher; identify and resolve the conflict |
| Local health passes but Linux times out | Firewall, wrong runner IP, or network path | Verify Private profile, firewall remote address, listener address, and Linux `LOR_RUNNER_URL` |
| Linux receives `401` | Windows and Linux pairing tokens differ | Run `PairServer`, install the pending token on Linux, restart the API, and compare fingerprints |
| Protected token cannot be decrypted | Different Windows account or damaged DPAPI file | Reinstall with `-RotateToken`, pair Linux again, and verify fingerprints |
| Ingest credential cannot be decrypted | Different account, missing file, or password change | Run `ConfigureIngest` |
| State or current manifest is missing | Shared Drive or incorrect state path | Stop; restore the authoritative Shared Drive file. Never initialize over production state |
| Runner stopped during parser/ingest | Windows logout, update, process failure, or network loss | Confirm no child process remains; restart runner; interrupted work must be reviewed and deliberately rerun |

## Security and Recovery Rules

- Never paste the bearer token into chat, shell history, documentation, or a
  browser request.
- Never copy DPAPI files to another computer or Windows account as a recovery
  method.
- Never broaden port 8791 to the Internet or the full LAN. Restrict it to
  `192.168.5.9` on the Private profile.
- Never initialize over the existing production `runner-state.json`.
- Never perform a production ingest merely as a connectivity test.
- Never rotate the runner token unless Linux will be paired again immediately.
- Back up `/etc/msb/lor-preflight-api.env` before manual recovery changes; the
  pairing installer already creates a timestamped backup.

## Related Documents

- [LOR Preflight Operator Interface](README.md)
- [LOR Parser and Compatibility Tools](../../Docs/01_LOR_System/02_Data_Extraction/Parser/README.md)
- [LOR2DB Ingest](../01_Ingest/README.md)
- [LOR Production Import and Reconciliation Procedure](../02_Reconciliation/00_LOR_Production_Import_and_Reconciliation_Procedure.md)
- [PRINT-SERVER Runtime Runbook](https://github.com/Gregovate/MSB_LabelPrintService/blob/main/docs/Print_Server_Runtime_Runbook.md)
- [2026-08-25 Routine Display Maintenance and PRINT-SERVER Cutover Incident Record](LOR_Routine_Display_Maintenance_and_PRINT_SERVER_Cutover_Incident_2026-08-25.md)
