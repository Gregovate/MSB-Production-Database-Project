# LOR Preflight Operator Interface

| Document control | Value |
|---|---|
| Status | PRODUCTION VALIDATED — Run 4 and lor2db landing page accepted |
| Initial release / current revision | 2026-08-04 / 2026-08-06 |

## Revision history

| Date | Change |
|---|---|
| 2026-08-06 | Added the `/lor2db/` landing page, current snapshot/reconciliation status API, immutable report link, and guarded Start action. Recorded completed Run 4 acceptance. |
| 2026-08-05 | Removed redundant backend `FOR UPDATE` locks that required unintended table-wide write permission; protected database functions and procedures remain the only writers and retain the authenticated operator email in the audit record. |
| 2026-08-05 | Made per-decision operator comments optional; blank comments receive a generated audit reason, and database rejections now show their primary error message. |
| 2026-08-05 | Removed safe exact-name UUID relinks from operator review; added candidate-specific decisions, explicit green Saved/Unsaved changes state, and opt-in bulk decision mode. |
| 2026-08-05 | Corrected the production runtime environment and recorded the validated Linux service account, systemd service, loopback health check, NAS publication mount, account boundaries, and Synology Advanced Share Permissions requirement. |
| 2026-08-04 | Initial reusable interface and backend documentation. |

This directory contains the reusable browser interface for production LOR
reconciliation review. It replaces the hard-coded Run 4 mockup with a run-data
contract. The browser must be published under the protected route:

`https://lortodb.sheboyganlights.org/lor2db/preflight/`

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

`https://lortodb.sheboyganlights.org/lor2db/`

The page calls the existing authenticated backend through
`/lor2db/preflight/api/`. It shows:

- the current committed snapshot, parser/ingest provenance, and row counts;
- the latest persistent reconciliation run and validation/exception state;
- the immutable report for a published run;
- **Open reconciliation** when a run is already active;
- **Start reconciliation** only when the latest snapshot is not already
  reconciled and no run is open.

The Start endpoint acquires the same advisory lock as the database Start
function, repeats eligibility inside that transaction, and captures the
current snapshot through `ops.f_start_lor_reconciliation(text)`. No request
parameter accepts an ingest number.

Parser and PostgreSQL ingest remain manual for this release. A future
app-server runner may precede this page, but it must invoke only the approved
parser/ingest commands and preserve the current prerequisite checks.

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
`ops.f_record_lor_reconciliation_action`. It returns the complete refreshed run
document as `{ "run": { ... } }`.

### `POST api/runs/{run_id}/decisions/bulk`

Body: `group_ids`, `action_type`, and `reason`. The backend calls
`ops.f_record_lor_reconciliation_bulk_action`. Every group must independently
allow the selected action. Reassociation cannot use this endpoint.

### `POST api/runs/{run_id}/cancel`

Requires a nonblank reason and a second browser confirmation. The backend calls
`ops.p_cancel_lor_reconciliation`, publishes the cancellation report, and never
runs Finish.

### `POST api/runs/{run_id}/finish`

Requires `READY_TO_FINISH`, zero unresolved groups, an unchanged final-review
`decision_version`, and a second browser confirmation. The backend calls
`ops.p_finish_lor_reconciliation` once and then invokes the existing report
publisher. This is the only production-write endpoint.

If production promotion commits but report publication fails, the run remains
`REPORTING`. Repeating Finish does not repeat P1-P4; it retries only publication.

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
| Public static path | `https://lortodb.sheboyganlights.org/lor2db/preflight/` | Secured Run 4 browser workflow production validated. |
| NAS SMB source | `//192.168.5.4/web` | Authentication and share access validated with `smbclient`. |
| Linux mount point | `/mnt/msb-web` | systemd automount successfully activated and directory contents listed. |
| SMB credentials file | `/etc/samba/credentials/lor_preflight_app` | Stored credentials successfully authenticated after correction. Do not record the password in documentation or shell history. |
| Report output | `/mnt/msb-web/my/lor2db/reports` | Configured by `LOR_REPORT_OUTPUT_DIR`. |
| Report base URL | `https://lortodb.sheboyganlights.org/lor2db/reports/` | Run 4 report and report archive links validated on 2026-08-06. |
| Reconciliation operator | `gliebig@sheboyganlights.org` | Configured as the current sole member of `LOR_PREFLIGHT_OPERATORS`; future operators must be explicitly added. |
| Synology access group | `web_maintainers` | Normal ACL and Advanced Share Permissions both set to Read/Write. |

The reconciliation application and published reports have different access
boundaries. Only explicitly named addresses in `LOR_PREFLIGHT_OPERATORS` may
operate reconciliation. Published reports are intended for authenticated
`sheboyganlights.org` users and do not grant access to the reconciliation
controls. The authenticated production routes were validated during Run 4
acceptance; Cloudflare Access policy management remains external to this
repository.

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

The successful final mount showed the NAS `web` share at `/mnt/msb-web`,
including the `my` directory used by the protected `lor2db` site. No further
changes to the Synology account, CIFS credentials, mount entry, or automount
units were required after that validation.

### Required Synology permission layers

Synology applies two independent permission layers to the `web` share. Both are
required for the service account:

1. **Shared Folder ACL:** `web_maintainers` must have **Read/Write**.
2. **Advanced Share Permissions:** `web_maintainers` must also have
   **Read/Write**.

Membership in `web_maintainers` and a correct normal ACL are not sufficient if
the group is absent from Advanced Share Permissions. In that condition,
authentication succeeds but connecting to `//192.168.5.4/web` fails with:

```text
tree connect failed: NT_STATUS_ACCESS_DENIED
```

Use the status returned by `smbclient` to distinguish the failure class:

| Status | Meaning |
|---|---|
| `NT_STATUS_LOGON_FAILURE` | The username/password was rejected. Verify ambiguous characters and then update the Synology account and credentials file consistently. |
| `NT_STATUS_ACCESS_DENIED` | Authentication succeeded, but the `web` share denied access. Verify both Synology permission layers above. |

The installation encountered both failures in sequence: an ambiguous password
character caused `NT_STATUS_LOGON_FAILURE`, and the missing
`web_maintainers` entry in Advanced Share Permissions then caused
`NT_STATUS_ACCESS_DENIED`. Passwords and password characters are intentionally
not recorded here.

### Safe validation sequence

Validate the stored SMB credentials and Synology authorization before testing
the systemd automount:

```bash
sudo smbclient //192.168.5.4/web \
  -A /etc/samba/credentials/lor_preflight_app \
  -c 'ls'
```

Only after that command lists the share, restart the automount and trigger it:

```bash
sudo systemctl stop 'mnt-msb\x2dweb.automount'
sudo systemctl reset-failed 'mnt-msb\x2dweb.mount'
sudo systemctl start 'mnt-msb\x2dweb.automount'
ls -la /mnt/msb-web
```

### Completed on 2026-08-06

- Applied `grant_lor_preflight_app.sql` revision V0.2.0 as
  `2026-08-06-lor-preflight-app-grants-v2`.
- Deployed `backend.py` V0.3.0 and restarted the service successfully.
- Deployed `landing/` to the protected `/lor2db/` directory.
- Validated snapshot 45 and completed Run 4 as `RECONCILED`, validation passed,
  all exception counts zero, report links present, and Start unavailable.

Start remains intentionally unexercised until a real newer snapshot is manually
parsed and ingested. Do not create a synthetic reconciliation run for that test.

Run the non-database safety tests from this directory with:

```text
python -m unittest -v test_backend.py
```

## Run 4 production acceptance record

Run 4 captured ingest 45 and completed through the secured browser workflow.
Its five display decisions were:

- `FE-TuneRadio-2CH-01`: automatic exact-name UUID relink.
- `QV-Making-01`, `QV-Bright-01`, and `QV-Spirits-01`: `SET_RECYCLED`.
- `QV-ToolBox`: `ADD_NEW_DISPLAY`.

The run finished `COMPLETED`, validation passed, and the timestamped report was
published. The report predates migration `0029`; its provenance-only P1/P3/P4
rows are retained as immutable historical evidence and are not material
production changes.
