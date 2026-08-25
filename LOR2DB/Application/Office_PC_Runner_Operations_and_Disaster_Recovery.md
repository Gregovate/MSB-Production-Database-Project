# LOR Runner Host Operations and Disaster Recovery

| Document control | Value |
|---|---|
| Repository path | `LOR2DB/Application/Office_PC_Runner_Operations_and_Disaster_Recovery.md` |
| Document type | Engineering operations and recovery runbook |
| Status | CURRENT — temporary host pending controlled PRINT-SERVER transfer |
| Owner | MSB Database Administrator |
| Initial release / current revision | 2026-08-17 / 2026-08-25 |

## Revision History

| Date | Change |
|---|---|
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

## Approved Host Transition — Not Yet Deployed

The Office Desktop deployment is now classified as temporary/test
infrastructure. It is not the accepted permanent production host.

```text
Current temporary host: MSB-OFFICE-PC (192.168.5.55)
Approved permanent host: PRINT-SERVER (192.168.5.56)
Permanent task account: PRINT-SERVER\Print Service
Transfer status: PLANNED — NOT YET INSTALLED OR ACCEPTED
```

On 2026-08-25, closing the interactive PowerShell window that owned the Office
Desktop runner stopped TCP 8791. The LOR2DB dashboard correctly reported the
runner unavailable while the Linux API, PostgreSQL snapshot 54, and
reconciliation state remained intact. This confirmed that the Office Desktop
availability model is unsuitable for permanent production operation.

The production target is a separate, unattended PRINT-SERVER Scheduled Task.
It must start without an interactive Windows login, recover after reboot, and
remain isolated from the existing `MSB Label Service` process, task, working
directory, Python environment, credentials, logs, and printer recovery.

This section records a hosting decision, not a completed deployment. Until the
cutover acceptance gates pass, Linux remains configured for the temporary
Office Desktop runner and the website may report the runner offline when that
temporary listener is stopped.

The PRINT-SERVER host/runtime prerequisites and dual-workload isolation gates
are controlled by the
[Print Server Runtime Runbook](https://github.com/Gregovate/MSB_LabelPrintService/blob/main/docs/Print_Server_Runtime_Runbook.md).

## Dependency Summary

The currently deployed LOR2DB application spans two computers and the shared
Google Drive. This diagram describes the temporary Office Desktop deployment,
not the approved permanent target:

```text
Authenticated browser
    -> Linux LOR2DB API on msb-prod-db (192.168.5.9:8784)
    -> authenticated HTTP request from 192.168.5.9
    -> Office PC runner (192.168.5.55:8791)
    -> approved repository code and account-bound DPAPI credentials
    -> G:\ Shared Drive previews, state, reports, and SQLite output
```

The Office PC runner is required for:

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

## Current Temporary Office Desktop Components

| Component | Production requirement |
|---|---|
| Windows host | Temporary Office Desktop host; current address `192.168.5.55` |
| Windows account | Greg's logged-in account; owns the current mapped `G:` drive and DPAPI secrets |
| Repository | Current reviewed `main` checkout with a working `.venv` |
| Launcher | Repository-root `run_lor_runner.ps1` |
| Scheduled Task | `MSB LOR Operator Runner`, triggered at that user's logon |
| Listener | `192.168.5.55:8791`, private LAN only |
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
6. If `Install` says a new token was generated, run `PairServer`, install the
   pending token on Linux, and restart the API as described in the replacement
   procedure. If it says the existing server pairing remains valid, do not pair
   again.
7. Require a healthy Windows `Status`, a passing Linux backend-to-runner check,
   and the expected runner version on the LOR2DB dashboard before returning the
   service to operators.

## Normal Status Check

Run this from a normal PowerShell window in the repository root on the Office
PC:

```powershell
.\run_lor_runner.ps1 -Action Status
```

A healthy result must show:

- Scheduled Task state `Running`;
- protected runner token `AVAILABLE`;
- protected PostgreSQL ingest credential `AVAILABLE`;
- runner health `ok`; and
- runner version `V1.5.1` or the later version documented by the deployed
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

1. Sign in to the same Windows account used to install the task.
2. Wait for Google Drive to restore the `G:` mapping.
3. Confirm the current preview folder, manifest, and `runner-state.json` are
   available.
4. Run `Status`.
5. If the task is not running, run `Start` and check `Status` again.
6. If startup repeatedly fails, review:

   ```powershell
   Get-Content "$env:LOCALAPPDATA\MSB\LORRunner\runner-service.log" -Tail 60
   ```

Screen locking does not stop the task. Logging out does. The task requires an
interactive logon because the mapped Shared Drive belongs to that user
session.

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

Before deploying to `PRINT-SERVER`:

1. Verify a stable read/write path to the approved preview folders,
   `runner-state.json`, compatibility manifests, review records, and SQLite
   output from the `PRINT-SERVER\Print Service` noninteractive task context.
   A `G:` mapping visible only in an interactive desktop session is not
   sufficient.
2. Establish a separate LOR runner working directory and Python environment.
   Do not install into `C:\MSB_LabelService`, alter its Python dependencies, or
   reuse its logs or configuration.
3. Update and test `run_lor_runner.ps1` so `Install` can create the approved
   at-startup, run-whether-logged-on-or-not task under the permanent Print
   Service account. The current launcher intentionally creates an at-logon
   interactive task and therefore does not yet meet this production target.
4. Use the reserved PRINT-SERVER address `192.168.5.56` for the listener and
   restrict inbound TCP 8791 to `192.168.5.9`.
5. Create new DPAPI-protected runner and PostgreSQL credentials under the
   permanent task account. Existing Office Desktop DPAPI files are not
   portable.
6. Back up the Linux pairing environment, then re-pair it to
   `http://192.168.5.56:8791` only when the new runner is ready for controlled
   cutover.
7. Require local health, Linux API-to-runner health, dashboard availability,
   controlled parser validation, dual-task reboot recovery, and an unaffected
   physical Label Print Service test before disabling the Office Desktop
   runner.

The PRINT-SERVER host facts and workload-isolation requirements are maintained
in the
[Print Server Runtime Runbook](https://github.com/Gregovate/MSB_LabelPrintService/blob/main/docs/Print_Server_Runtime_Runbook.md).

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
| PRINT-SERVER task starts but LOR state/source paths are unavailable | Headless task cannot access a user-session Google Drive mapping | Stop the transfer; establish and verify a durable noninteractive path before pairing Linux or disabling the old runner |
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
