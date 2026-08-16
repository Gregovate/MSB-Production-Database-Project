# LOR Preflight Operator Interface

| Document control | Value |
|---|---|
| Status | CURRENT code; web ingest workflow deployed; V0.6.1 action-clarity hotfix pending deployment |
| Initial release / current revision | 2026-08-04 / 2026-08-16 |

## Revision history

| Date | Change |
|---|---|
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

PostgreSQL ingest remains separate and manual. No browser page starts ingest,
and the Linux API never executes a user-supplied path or command.

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
11. Supply its displayed SHA-256 to the separate manual PostgreSQL ingest.

The raw SQLite `scenes` count is labeled **raw LOR Scene rows**. Operational
true Scenes are classified by Folder Alignment naming rules and are not a
parser table-count interpretation.

### Windows runner deployment boundary

`Docs/01_LOR_System/02_Data_Extraction/Parser/lor_operator_runner.py` runs on the
restricted Office PC under the logged-in Greg account because that session owns
the Shared Drive mounted as `G:`. It listens on the internal interface only and
requires a bearer token shared with the Linux API. Production already has an
approved 6.6.10 state and must retain it. Never run `init` over that state.

Use only the repository-root launcher. `Install` generates one random token,
protects it with Windows DPAPI, and registers the **MSB LOR Operator Runner**
task at Greg's logon. It never starts the parser. `PairServer` transfers the
same token over SSH to a mode-0600 pending file without displaying or placing
the secret in command history.

```powershell
.\run_lor_runner.ps1 -Action Install
.\run_lor_runner.ps1 -Action PairServer
.\run_lor_runner.ps1 -Action Stop
.\run_lor_runner.ps1 -Action Status
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

The task runs while Greg remains logged in, including while the screen is
locked. After a Windows update or reboot, the runner remains unavailable until
Greg signs in and `G:` is restored. This is an explicit availability boundary:
the website reports the runner offline, while command-line parser operation,
the existing SQLite snapshot, PostgreSQL, and reconciliation remain unaffected.

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

The backend reads `ops.v_lor_reconciliation_run_review`,
`ops.v_lor_reconciliation_group_review`, and the four installed entity review
views. It must return persisted effective decisions when the page is reopened.

Safe `UUID_CHANGED_SAME_NAME` candidates do not appear in this response. After
the uniqueness, collision, ACTIVE-status, singleton-group, and exact-name
guards pass, migration `0028_auto_approve_safe_uuid_relinks.sql` retains the
frozen row as `AUTO_APPROVED`; P2 updates the LOR link only when Finish runs.

Each displayed row remains `Not saved` until its decision is persisted. The
operator comment is optional; a blank comment receives a generated audit
reason. A successful save shows green `Saved`. Changing either field after
that immediately shows `Unsaved changes` and disables final review until the
row is saved again. Bulk selectors remain hidden until the operator explicitly
enables bulk decision mode.

### `POST api/runs/{run_id}/groups/{group_id}/decisions`

Body:

```json
{
  "action_type": "DEFER",
  "reason": "Investigate unexpected UUID change after Run 3.",
  "expected_action_id": null
}
```

The backend verifies the authenticated operator, run status, run/group
relationship, allowed action, and optimistic `expected_action_id`; then calls
the appropriate protected recorder. Display/scene decisions use
`ops.f_record_lor_reconciliation_action`; evidence-gated stage decisions use
`ops.f_record_lor_stage_authority_action`, and the existing multi-preview
preservation choice uses its dedicated stage recorder. It returns the complete
refreshed run document as `{ "run": { ... } }`.

Stage candidates include the complete frozen `members` array and the browser
renders every member. `APPROVE_STAGE_CHANGE` appears only when all members
resolve to one permanent `stage_id` and agree on the proposed metadata.
`ADD_NEW_STAGE` appears only when one authoritative source defines one new
stage key/name/folder/order. Contradictory groups expose neither action.

### `POST api/runs/{run_id}/decisions/bulk`

Body: `group_ids`, `action_type`, and `reason`. The backend calls
`ops.f_record_lor_reconciliation_bulk_action`. Every group must independently
allow the selected action. Reassociation cannot use this endpoint.

### `POST api/runs/{run_id}/cancel`

Requires a nonblank reason and a second browser confirmation. The backend calls
`ops.p_cancel_lor_reconciliation`, publishes the cancellation report, and never
runs Finish. Its response includes the immutable cancellation `report_url`,
snapshot-removal proof, and `production_changed: false`. The browser replaces
the editable page with a terminal **Reconciliation cancelled** screen and an
explicit **Safe to close browser: YES** result.

### `POST api/runs/{run_id}/finish`

Requires `READY_TO_FINISH`, zero unresolved groups, an unchanged final-review
`decision_version`, and a second browser confirmation. The backend calls
`ops.p_finish_lor_reconciliation` once and then invokes the existing report
publisher. This is the only production-write endpoint.

If production promotion commits but report publication fails, the run remains
`REPORTING`. The landing page must present **Continue previous reconciliation**;
the run page presents **Retry report publication**. Repeating Finish does not
repeat P1-P4; it retries only publication.

### `POST api/runs/{run_id}/report`

Retries report publication only for a run in `REPORTING`. This endpoint never
repeats Cancel, Finish, or P1-P4 and returns the run's actual terminal status
plus immutable `report_url`. It is used for both completed production updates
and cancellations whose initial report publication failed.

## Deployment boundary

Use `lor-preflight-api.service.example` and `lor-preflight-api.env.example` as
deployment templates. The validated production service runs with Gunicorn on
`192.168.5.9:8784`.
Configure the authenticated reverse proxy so the public path
`/lor2db/preflight/api/` maps to that restricted service with the `/api` prefix
removed. The static files remain in the NAS `lor2db/preflight` folder.

The dedicated login used by `LOR_PREFLIGHT_DATABASE_URL` needs `SELECT` on the
approved `ops` review views and only the specific reconciliation run, group,
and action columns read by the concurrency checks. Grant `EXECUTE` only on the
two decision functions, Finish/Cancel procedures, report data function, and
report publication function used by the existing publisher. It must not receive
direct write privileges on `ref`, `lor_snap`, or the reconciliation tables.
After creating the login separately with a secured password, apply
`grant_lor_preflight_app.sql` to install this exact grant set.

## Web ingest incremental deployment order

This release changes the Windows runner, Linux API, and NAS browser files. It
requires no PostgreSQL migration, grant change, runner-token rotation, or
runner re-pairing. The Office PC records the existing PostgreSQL ingest
password once in a Windows DPAPI-protected file; the password is never sent to
the browser or Linux API.

1. Back up the runner launcher/state and the deployed Linux/static application
   files; record their hashes.
2. Pull the reviewed commit on the Office PC and run the parser/runner and
   application tests plus PowerShell and JavaScript syntax checks.
3. Run `run_lor_runner.ps1 -Action Install`. Retain the existing runner token,
   enter the PostgreSQL `msbadmin` password once at the secure prompt, and
   verify runner V1.5.0. Do not run `PairServer`.
4. Deploy backend V0.6.1, restart `lor-preflight-api.service`, and verify its
   health response plus the existing backend-to-runner connection.
5. Publish the complete `landing/` tree, including `parser/` and
   `version-check/`, to `/mnt/msb-web/my/lor2db/`. Preserve the existing
   `preflight/` and `reports/` trees.
6. Verify that parser review approval is tied to the displayed digest, the
   ingest button is disabled until that approval is checked, and both parser
   and ingest consoles load. Do not run a production ingest during deployment
   acceptance.

PostgreSQL ingest remains password-protected, digest-locked, and explicitly
operator-approved. The browser starts only the fixed ingest operation and
cannot provide a path, command, database account, or executable.

## Historical V0.5.1 combined deployment order

This release intentionally deploys the reconciliation corrections and the
already-implemented Version Check / Run Parser controls as one acceptance
unit. Do not deploy only the static page or only `backend.py`.

1. Back up the current application files and record their hashes.
2. Apply
   `0032_add_safe_stage_authority_and_terminal_cancel.sql`, then run
   `27_safe_stage_authority_and_cancel_terminal_validation.sql`.
3. Apply
   `0033_approve_stage_key_changes_with_stable_aliases.sql`, then run
   `28_complete_stage_decision_evidence_validation.sql`.
4. Reapply `grant_lor_preflight_app.sql` V0.3.1 so the restricted API role can
   read the evidence-gating predicates and invoke the stage decision recorders
   in addition to its existing entry points.
5. On the approved Windows host, deploy the canonical parser directory,
   including runner V1.3.0, version checker, parser V7.0.10, tests, and the root
   runner launcher. Retain the existing `runner-state.json` whose current
   approved LOR is 6.6.10; do not initialize over it. Run launcher `Install`
   and `PairServer`; do not manually create or paste a token.
5. On `msb-prod-db`, run `install_lor_runner_pairing.py`, confirm its fingerprint
   matches Windows, deploy backend V0.5.1 and report publisher V0.5.0 together,
   and restart `lor-preflight-api.service`.
6. Publish `landing/` plus the `preflight` HTML/CSS/JavaScript files to the NAS
   web path.
7. Verify the Linux `/health` response, Windows runner health, dashboard runner
   status, cancellation terminal flow, archive Outcome column, and a no-write
   stage decision review before production use.

PostgreSQL ingest remains password-protected, digest-locked, and manual. This
deployment does not add a browser ingest endpoint.

## Production deployment and acceptance record — 2026-08-05 through 2026-08-06

The application was installed on `msb-prod-db`. The deployment uses two
different credentials that happen to share the `lor_preflight_app` name:

- PostgreSQL login role `lor_preflight_app`: used by the restricted API and
  restricted by `grant_lor_preflight_app.sql`.
- Synology local user `lor_preflight_app`: used only to mount the NAS `web`
  share so the application can publish static files and reconciliation reports.

Do not assume that changing one credential changes the other. Their passwords
are managed independently and must not be stored in this repository.

The Linux runtime account is a third, separate identity:

- Linux system user `lor-preflight`: runs the Gunicorn API service with no
  interactive login. Its primary group is `msbadmin`, which permits access to
  the deployed application, protected environment file, and NAS-backed report
  directory. It does not authenticate to PostgreSQL or Synology directly.

### Confirmed production components

| Component | Production value | Validation on 2026-08-05 |
|---|---|---|
| Application host | `msb-prod-db` (`192.168.5.9`) | Host confirmed during deployment. |
| Application working directory | `/opt/lor-preflight` | Installation and validation commands were run from this directory. |
| Python virtual environment | `/opt/lor-preflight/.venv` | The service account successfully executed its Python interpreter and Gunicorn. |
| Linux runtime account | `lor-preflight`, primary group `msbadmin`, shell `/usr/sbin/nologin` | Read and execution checks passed for the environment, backend, virtual environment, and report directory. |
| Runtime environment file | `/etc/msb/lor-preflight-api.env`, owned by `root:msbadmin`, mode `0640` | PostgreSQL URL, operator allowlist, report output directory, and report base URL configured without exposing credentials. |
| systemd service | `lor-preflight-api.service` | Installed, verified, enabled at boot, and active with two Gunicorn workers. |
| API listener | `192.168.5.9:8784` | Backend V0.3.0: `GET /health` returned `{"status":"ok","version":"V0.3.0"}` on 2026-08-06. Do not expose this port to the Internet. |
| Public static path | `https://my.sheboyganlights.org/lor2db/preflight/` | Secured Run 4 browser workflow production validated. |
| NAS SMB source | `//192.168.5.4/web` | Authentication and share access validated with `smbclient`. |
| Linux mount point | `/mnt/msb-web` | systemd automount successfully activated and directory contents listed. |
| SMB credentials file | `/etc/samba/credentials/lor_preflight_app` | Stored credentials successfully authenticated after correction. Do not record the password in documentation or shell history. |
| Report output | `/mnt/msb-web/my/lor2db/reports` | Configured by `LOR_REPORT_OUTPUT_DIR`. |
| Report publisher | `/opt/lor-preflight/publish_lor_reconciliation_report.py` | Configured explicitly by `LOR_REPORT_PUBLISHER_PATH`; the backend and publisher are deployed together. |
| Report base URL | `https://my.sheboyganlights.org/lor2db/reports/` | Run 4 report and report archive links validated on 2026-08-06. |
| Reconciliation operator | `gliebig@sheboyganlights.org` | Configured as the current sole member of `LOR_PREFLIGHT_OPERATORS`; future operators must be explicitly added. |
| Synology access group | `web_maintainers` | Normal ACL and Advanced Share Permissions both set to Read/Write. |

The reconciliation application and published reports have different access
boundaries. Only explicitly named addresses in `LOR_PREFLIGHT_OPERATORS` may
operate reconciliation. Published reports are intended for authenticated
`sheboyganlights.org` users and do not grant access to the reconciliation
controls. The authenticated production routes were validated during Run 4
acceptance; Cloudflare Access policy management remains external to this
repository.

### Future Directus operator integration

The current release authenticates the operator with Cloudflare Access and
authorizes the email through `LOR_PREFLIGHT_OPERATORS`. The API retains that
email in `acted_by_application`, and reports display it as the human operator.
The PostgreSQL service account may still appear in the underlying `acted_by`
column; it is not the human operator.

A future enhancement should map the authenticated email to the established
Directus person/actor identity using the label-printing pattern, and should use
Directus roles and permissions as the reconciliation authorization source. It
must not add manual operator entry to the API. This enhancement is intentionally
outside the current release.

The installed service uses these corrected production settings. The obsolete
`/opt/msb-production-database` paths and `User=msbadmin` setting must not be
restored:

```ini
User=lor-preflight
Group=msbadmin
WorkingDirectory=/opt/lor-preflight
EnvironmentFile=/etc/msb/lor-preflight-api.env
ExecStart=/opt/lor-preflight/.venv/bin/gunicorn --bind 192.168.5.9:8784 --workers 2 --timeout 240 backend:app
```

The environment file must include the deployed publisher path:

```ini
LOR_REPORT_PUBLISHER_PATH=/opt/lor-preflight/publish_lor_reconciliation_report.py
```

Deploy both Python files before restarting the service. A backend-only copy is
incomplete and will leave a committed reconciliation run in `REPORTING`:

```bash
sudo install -o root -g msbadmin -m 0640 backend.py /opt/lor-preflight/backend.py
sudo install -o root -g msbadmin -m 0640 publish_lor_reconciliation_report.py \
  /opt/lor-preflight/publish_lor_reconciliation_report.py
sudo systemctl restart lor-preflight-api.service
sudo systemctl status lor-preflight-api.service --no-pager
```

After deployment, verify the file and backend version before retrying Finish:

```bash
sudo -u lor-preflight test -r /opt/lor-preflight/publish_lor_reconciliation_report.py
curl -s http://192.168.5.9:8784/health
```

The V0.5.1 health response must report `V0.5.1`. Retrying Finish for a run already in
`REPORTING` does not execute P1-P4 again; it retries report publication only.

The successful final mount showed the NAS `web` share at `/mnt/msb-web`,
including the `my` directory used by the protected `lor2db` site. No further
changes to the Synology account, CIFS credentials, mount entry, or automount
units were required after that validation.

### Required Synology permission layers

Synology applies two independent permission layers to the `web` share. Both are
required for the service account:

1. **Shared Folder ACL:** `web_maintainers` must have **Read/Write**.
2. **Advanced Share Permissions:** `web_maintainers` must also have **Read/Write**.

If either layer is read-only, the Linux mount may succeed but report publication will fail with a permission error.
