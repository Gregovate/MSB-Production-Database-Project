# LOR Preflight Operator Interface

| Document control | Value |
|---|---|
| Status | CURRENT — production deployed and validated through reconciliation Run 13 |
| Initial release / current revision | 2026-08-04 / 2026-09-10 |

## Revision history

| Date | Change |
|---|---|
| 2026-09-10 | Recorded that new/renamed Scene documentation-folder integrity is a LOR2DB reconciliation responsibility. The paired Windows LOR runner is the correct `G:` filesystem boundary; Folder Alignment remains a secondary audit. A controlled `scene_folder_template` and reconciliation validation/repair utility are tracked in #143. |
| 2026-08-25 | Recorded completed PRINT-SERVER V1.6.0 cutover, corrected the false Session-0 Google Drive conclusion, documented required Print Service autologon, and accepted parser V7.0.11, ingest 55, and reconciliation Run 13. |
| 2026-08-25 | Added runner V1.6.0 dual deployment profiles after the initial PRINT-SERVER Password-logon Session-0 path probe; later cold-boot validation superseded its headless conclusion. |
| 2026-08-16 | Changed the successful final production-application boundary from failure-red styling to an amber notice with standard blue confirmation controls. Cancellation and actual failures remain red. |
| 2026-08-16 | Added ingest V0.4.1 / runner V1.5.1 recovery for a Windows console encoding failure after PostgreSQL commit. The exact completed SQLite digest is reused without creating a duplicate import run, and post-commit failures can no longer claim rollback. |
| 2026-08-16 | Kept `Run parser` permanently available after successful runs and made `Review parser output` an additional action instead of a replacement. Corrected the Windows installer message so an unchanged protected token does not instruct the operator to pair the server again. |
| 2026-08-15 | Added the complete browser-operated parser-to-ingest workflow. The idempotent parser remains repeatable until the operator approves the exact displayed SQLite digest. The Windows runner then performs the fixed digest-locked PostgreSQL ingest and exposes read-only console output on the same page. Ingest never starts reconciliation automatically. |
| 2026-08-15 | Separated routine parser execution from infrequent LOR-version approval. The landing page now has distinct parser, version, and reconciliation boxes; dedicated parser and version-check pages own their respective workflows. Runner V1.4.0 preserves bounded read-only console output, records failures, rejects concurrent operations, and marks interrupted work truthfully after restart. |
| 2026-08-14 | Replaced manual runner-token commands with the root `run_lor_runner.ps1` installer. The token is generated once, protected with Windows DPAPI, paired to Linux through SSH, and verified by a non-secret fingerprint. Runner V1.3.0 logs rejected-header fingerprints; backend V0.5.1 bypasses HTTP proxies for the fixed private runner connection. |
| 2026-08-14 | Added safe `APPROVE_STAGE_CHANGE` and `ADD_NEW_STAGE` paths gated by complete frozen evidence; contradictory stage groups remain non-approvable. The browser now shows every stage-group member. Cancellation now renders a terminal proof screen, cancelled reports have no misleading required actions, and the archive shows Outcome. Current-version parser runs permit structurally compatible authoring edits while candidate runs retain their exact checked-source guard. |
| 2026-08-13 | Added the mandatory same-parser approved-version/candidate SQLite comparison. Approval now requires equal schemas and explained output differences; automatic LOR Revision increments are retained as informational evidence rather than treated as content changes. Candidate folders changed after XML review are rejected as stale. |
| 2026-08-13 | Added the LOR version-of-record, complete XML compatibility gate, validated parser controls, and Windows/G-drive runner boundary. PostgreSQL ingest remains a separate manual approval step and requires the reviewed SQLite SHA-256. |
| 2026-08-06 | Browser V0.4.3 opens the newly published run's immutable `report_url`, with the archive index only as a fallback. Backend V0.3.3 returns that URL after publication. Report framework V0.4.2 displays the authenticated Cloudflare email as the operator. Directus person resolution and role-based authorization remain a future enhancement. |
| 2026-08-06 | Enforced permanent one-to-one snapshot ownership. The landing page now continues any unfinished run first and uses the existing `import_run_id` link instead of numeric run recency. Start is hidden and rejected when the snapshot already owns any reconciliation row; cancelled and failed runs also consume their snapshot. |
| 2026-08-06 | Corrected report-writer deployment after Run 5 exposed a stale repository-layout path. Backend V0.3.1 requires the absolute deployed publisher path and verifies the file before execution. Browser V0.4.2 replaces the production-write confirmation with an explicit report-only retry when a run is already in `REPORTING`. |
| 2026-08-06 | Added the `/lor2db/` landing page, current snapshot/reconciliation status API, immutable report link, and guarded Start action. Recorded completed Run 4 acceptance. |
| 2026-08-05 | Removed redundant backend `FOR UPDATE` locks that required unintended table-wide write permission; protected database functions and procedures remain the only writers and retain the authenticated operator email in the audit record. |
| 2026-08-05 | Made per-decision operator comments optional; blank comments receive a generated audit reason, and database rejections now show their primary error message. |
| 2026-08-05 | Removed safe exact-name UUID relinks from operator review; added candidate-specific decisions, explicit green Saved/Unsaved changes state, and opt-in bulk decision mode. |
| 2026-08-05 | Corrected the production runtime environment and recorded the validated Linux service account, systemd service, loopback health check, NAS publication mount, account boundaries, and Synology Advanced Share Permissions requirement. |
| 2026-08-04 | Initial reusable interface and backend documentation. |

This directory contains the reusable browser interface for production LOR
reconciliation review. It replaces the hard-coded Run 4 mockup with a run-data
contract. The browser is published under the protected route:

`https://my.sheboyganlights.org/lor2db/preflight/`

The browser never contains PostgreSQL credentials or writes reconciliation
tables directly. `backend.py` implements the same-origin API and invokes only
the installed `ops` views, functions, and procedures.

The production backend binds to the restricted application address
`192.168.5.9:8784` and is exposed only through the authenticated reverse proxy
at `/lor2db/preflight/api/`. It requires the Cloudflare Access
identity header and independently restricts access to the comma-separated
`LOR_PREFLIGHT_OPERATORS` allowlist. Do not expose port 8784 to the LAN or web.

## lor2db landing page

Publish the files in `landing/` at:

`https://my.sheboyganlights.org/lor2db/`

The page calls the existing authenticated backend through
`/lor2db/preflight/api/`. Its separate function boxes show:

- the normal repeatable **Run LOR parser** workflow;
- the explicit parser review and **Ingest to PostgreSQL** step whenever a
  successful parser output has not yet been ingested;
- the current approved LOR version and a link to the separate infrequent
  **Check new version** workflow;
- PostgreSQL reconciliation status, with no action button when no action is
  valid;
- the current reconciled PostgreSQL snapshot, parser/ingest provenance, and
  row counts;
- the persistent reconciliation run that owns or blocks the current snapshot;
- the immutable report for a published run;
- **Continue previous reconciliation** whenever any run is unfinished;
- **Start reconciliation** only when the current snapshot has no matching row
  in `ops.lor_reconciliation_run` and no other run is unfinished.

`lor_snap.import_run_id` to `ops.lor_reconciliation_run.import_run_id` is a
permanent one-to-one relationship. `COMPLETED`, `COMPLETED_WITH_EXCEPTIONS`,
`CANCELLED`, `FAILED`, and historical `SUPERSEDED` runs all consume their
captured snapshot. A cancelled
run follows the documented emergency cancellation procedure, including removal
of its disposable snapshot, so another attempt requires a newly parsed and
ingested snapshot. Migration `0030_enforce_one_reconciliation_per_snapshot.sql`
enforces both snapshot uniqueness and the single-unfinished-run rule in
PostgreSQL; the browser and backend enforce the same contract for a clear
operator experience.

Unfinished means every nonterminal lifecycle state: `STARTING`, `PREFLIGHT`,
`AWAITING_DECISIONS`, `READY_TO_FINISH`, `PROMOTING`, `VALIDATING`, and
`REPORTING`. The database Start function returns that existing run before it
can create anything. `REPORTING` retries publication only; the earlier states
continue from their persisted run and never create a replacement attempt.

The Start endpoint acquires the same advisory lock as the database Start
function, repeats eligibility inside that transaction, and captures the
current snapshot through `ops.f_start_lor_reconciliation(text)`. No request
parameter accepts an ingest number.

The parser page is published at `/lor2db/parser/`. It permits repeated
production SQLite builds, shows the last result, and displays the runner's
bounded read-only console record. A parser failure retains the last valid
SQLite database. Only one runner operation is accepted at a time; a second
request is rejected rather than queued.

The version-check page is published at `/lor2db/version-check/`. It shows the
current approved LOR version and exact preview-folder path, resolves a candidate
only beneath the configured versioned preview root, and runs the XML check,
approved-version baseline, candidate parser, and SQLite comparison in order.
Approval returns to the landing page with the new approved version and folder
and marks the production parser as requiring a deliberate rebuild.

PostgreSQL ingest remains a separate, explicit operator approval. The parser
page starts only the fixed digest-locked ingest operation after the operator
approves the exact displayed SQLite SHA-256. The browser cannot supply a path,
command, database account, or executable, and ingest never starts
reconciliation automatically.

## Scene documentation-folder integrity gate

A new or renamed LOR Scene can change more than PostgreSQL Scene identity. When the Scene is a controlled field/documentation scope, Setup, Procedures, FieldWiring, and other consumers depend on the corresponding Google Drive Scene root and required source-folder markers.

The **mandatory integrity gate belongs inside LOR2DB reconciliation**, at the point where the Scene addition/rename is already being reviewed. It must not be implemented primarily in Setup or deferred until Folder Alignment.

The Linux LOR2DB backend cannot inspect `G:`. The existing paired Windows runner is therefore the correct filesystem component:

```text
LOR2DB reconciliation candidate
    -> backend calls fixed runner operation
    -> PRINT-SERVER runner inspects G:\Shared drives\Display Folders
    -> expected owning Stage/Sub-stage + Scene folder resolved
    -> required scaffold/marker check returned to reconciliation
```

For a Scene that requires its own controlled documentation root, reconciliation must not reach successful Finish while the expected folder/marker structure is missing or ambiguous. The operator message should identify the exact missing folder/marker rather than surfacing later as a resolver/material mismatch.

A controlled `scene_folder_template` is also required. The reconciler should be able to offer a governed repair/create operation using that template when the expected Scene root is absent or incomplete. The browser must never accept arbitrary filesystem paths from the operator; the runner derives the destination from frozen reconciliation evidence and the controlled template.

Folder Alignment remains a useful secondary read-only audit and broad worklist. It does not replace this LOR2DB gate.

Tracked in #143.

## LOR version-check workspace

The infrequent version workflow is intentionally gated:

1. Select the new LOR version. The runner resolves only `Database Previews
   V<version>` beneath its configured preview root.
2. Run the parser-independent complete XML compatibility check.
3. If the check fails, review the recorded parser modifications required and
   update the parser.
4. The guided page builds the approved-version comparison baseline in isolated
   `VERSION_CHECK` mode. Routine authoring changes in the approved folder are
   allowed only when the live XML remains structurally compatible with its
   retained approved manifest; parser-breaking contract changes are rejected.
5. The guided page runs the candidate parser into a separate `VERSION_CHECK` SQLite file. The
   runner verifies that the candidate folder still matches the just-reviewed
   XML manifest, then compares both SQLite schemas and authoritative content.
6. LOR-generated `Revision` changes are recorded as informational. Preview
   identity metadata changes require review; authoritative prop, channel,
   Scene, or membership differences block approval until explained.
7. Record one engineering resolution that addresses every XML and SQLite
   output finding.
8. Approve the version only after the XML check, both parser runs, and output
   comparison pass or all review findings are resolved. The previous version
   folder remains unchanged.
9. Return to the landing page. The approved version and preview-folder path now
   identify the new source, while production SQLite is explicitly marked for
   rebuild.
10. Use the normal parser page to run the current parser in `PRODUCTION` mode.
   Inspect the resulting SQLite as often as needed; no ingest is automatic.
11. Review the production parser output, approve its displayed SHA-256, and use
    **Ingest to PostgreSQL** on the parser page.

The raw SQLite `scenes` count is labeled **raw LOR Scene rows**. Operational
true Scenes are classified by Folder Alignment naming rules and are not a
parser table-count interpretation.

### Windows runner deployment boundary

The production runner is deployed on `PRINT-SERVER` at
`192.168.5.56:8791` under `PRINT-SERVER\Print Service`. Its isolated
repository is `C:\MSB_LORRunner`, and runner V1.6.0 uses the
`PrintServerUnattended` profile. The former Office Desktop deployment is
disabled rollback material only.

Google Drive for Desktop did not mount `G:` in a true pre-login Session-0
cold boot. The accepted production configuration therefore uses controlled
automatic login for the Print Service account so Google Drive can mount the
approved preview, state, review, and SQLite paths. The runner currently exits
if it checks prerequisites before `G:` is ready; recovery requires verifying
the mount and starting one managed instance. This limitation is tracked for
engineering correction.

Production retains the approved 6.6.10 state. Never run `init` over that
state.

Use only the repository-root launcher. `Install` generates one random token,
protects it with Windows DPAPI, and registers the **MSB LOR Operator Runner**
task using the selected deployment profile. It never starts the parser.
`PairServer` transfers the same token over SSH to a mode-0600 pending file
without displaying or placing the secret in command history.

```powershell
.\run_lor_runner.ps1 -Action Install
.\run_lor_runner.ps1 -Action PairServer
.\run_lor_runner.ps1 -Action Stop
.\run_lor_runner.ps1 -Action Status
```

The temporary Office deployment defaults to `OfficeInteractive`. The approved
PRINT-SERVER command is explicit:

```powershell
.\run_lor_runner.ps1 `
    -Action Install `
    -DeploymentProfile PrintServerUnattended
```

`Install` safely replaces an existing managed runner, including an orphaned
runner process left listening after its Scheduled Task has exited. It will stop
only a Python listener whose command line matches this repository's runner,
host, and port. It refuses to interrupt a parser recorded as `RUNNING` and
refuses to terminate an unrelated process using port 8791. `Stop` applies the
same checks without reinstalling the task.

From the repository root on `msb-prod-db`, consume the pending token with:

```bash
sudo python3 LOR2DB/Application/install_lor_runner_pairing.py
```

The installer backs up `/etc/msb/lor-preflight-api.env`, atomically installs
`LOR_RUNNER_URL` and `LOR_RUNNER_TOKEN`, preserves its ownership/mode, reports
the same non-secret fingerprint as Windows, and deletes the pending plaintext
file. The reverse proxy continues to expose only the Linux LOR2DB API; do not
publish port 8791 to the Internet.

The production task is independent of an open PowerShell window. Screen
locking does not stop it. Logging out removes the interactive Google Drive
mount and makes parser/version/ingest operations unavailable until automatic
or manual Print Service login restores `G:`.

The accepted host is `PRINT-SERVER` (`192.168.5.56`) with a separate
at-startup, Password-logon, Highest Scheduled Task under
`PRINT-SERVER\Print Service`. The existing Label Print Service remains a
separate pre-login-capable workload. Production acceptance on 2026-08-25
included local and Linux health, dashboard availability, cold reboot with
Autologon, controlled parser V7.0.11, ingest 55, reconciliation Run 13,
immutable report publication, exact final Display verification, and a successful physical Display label through the independent Label Print Service after reboot.

Installation, restart, credential recovery, network requirements, and transfer
to a replacement host are controlled by the
[Runner Operations and Disaster Recovery](Office_PC_Runner_Operations_and_Disaster_Recovery.md)
runbook. Do not improvise token transfer or copy DPAPI files to another account
or computer.

The complete deployment and workflow incident is preserved in
[LOR Routine Display Maintenance and PRINT-SERVER Cutover Incident — 2026-08-25](LOR_Routine_Display_Maintenance_and_PRINT_SERVER_Cutover_Incident_2026-08-25.md).

## Required API

### `GET api/runs/{run_id}`

Returns the frozen run and all decision-required groups. `candidates` may
contain display, stage, scene, or scene-display groups using the same row shape.

```json
{
  "run_id": 4,
  "import_run_id": 45,
  "status": "AWAITING_DECISIONS",
  "candidates": [{
    "group_id": 7590,
    "entity_type": "DISPLAY",
    "entity_key": "LOR_PROP:dcc13d29-7850-4991-b101-68cee4d4d922",
    "classification_label": "New Display Candidate",
    "operator_message": "LOR display QV-ToolBox is not present in ref.display.",
    "allowed_actions": ["ADD_NEW_DISPLAY", "CORRECT_SOURCE_REQUIRED", "DEFER"],
    "proposed_action": "ADD_NEW_DISPLAY",
    "effective_action_id": null,
    "effective_action_type": null,
    "effective_reason": null,
    "current_display_name": null,
    "proposed_display_name": "QV-ToolBox",
    "facts": [{"label": "Stage", "value": "30"}]
  }]
}
```
