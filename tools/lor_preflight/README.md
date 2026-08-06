# LOR Preflight Operator Interface

| Document control | Value |
|---|---|
| Status | Backend service and NAS publication mount validated; reverse-proxy route and Run 4 acceptance pending |
| Initial release / current revision | 2026-08-04 / 2026-08-05 |

## Revision history

| Date | Change |
|---|---|
| 2026-08-05 | Removed safe exact-name UUID relinks from operator review; added candidate-specific decisions, explicit green Saved/Unsaved changes state, and opt-in bulk decision mode. |
| 2026-08-05 | Corrected the production runtime environment and recorded the validated Linux service account, systemd service, loopback health check, NAS publication mount, account boundaries, and Synology Advanced Share Permissions requirement. |
| 2026-08-04 | Initial reusable interface and backend documentation. |

This directory contains the reusable browser interface for production LOR
reconciliation review. It replaces the hard-coded Run 4 mockup with a run-data
contract. The browser must be published under the protected route:

`https://my.sheboyganlights.org/lor2db/preflight/`

The browser never contains PostgreSQL credentials or writes reconciliation
tables directly. `backend.py` implements the same-origin API and invokes only
the installed `ops` views, functions, and procedures.

The backend must bind only to loopback and be exposed through the authenticated
reverse proxy at `/lor2db/preflight/api/`. It requires the Cloudflare Access
identity header and independently restricts access to the comma-separated
`LOR_PREFLIGHT_OPERATORS` allowlist. Do not expose port 8784 to the LAN or web.

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

Each displayed row remains `Not saved` until its decision and reason are
persisted. A successful save shows green `Saved`. Changing either field after
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
deployment templates. The service runs with Gunicorn on `127.0.0.1:8784`.
Configure the authenticated reverse proxy so the public path
`/lor2db/preflight/api/` maps to that loopback service with the `/api` prefix
removed. The static files remain in the NAS `lor2db/preflight` folder.

The dedicated login used by `LOR_PREFLIGHT_DATABASE_URL` needs `SELECT` on the
approved `ops` review views and only the specific reconciliation run, group,
and action columns read by the concurrency checks. Grant `EXECUTE` only on the
two decision functions, Finish/Cancel procedures, report data function, and
report publication function used by the existing publisher. It must not receive
direct write privileges on `ref`, `lor_snap`, or the reconciliation tables.
After creating the login separately with a secured password, apply
`grant_lor_preflight_app.sql` to install this exact grant set.

## Production deployment record — 2026-08-05

The application was installed on `msb-prod-db`. The deployment uses two
different credentials that happen to share the `lor_preflight_app` name:

- PostgreSQL login role `lor_preflight_app`: used by the loopback API and
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
| API listener | `127.0.0.1:8784` | `GET /health` returned `HTTP/1.1 200 OK` and `{"status":"ok","version":"V0.1.0"}`. Do not expose this port to the LAN or Internet. |
| Public static path | `https://my.sheboyganlights.org/lor2db/preflight/` | Static publication target configured; Run 4 browser acceptance remains pending. |
| NAS SMB source | `//192.168.5.4/web` | Authentication and share access validated with `smbclient`. |
| Linux mount point | `/mnt/msb-web` | systemd automount successfully activated and directory contents listed. |
| SMB credentials file | `/etc/samba/credentials/lor_preflight_app` | Stored credentials successfully authenticated after correction. Do not record the password in documentation or shell history. |
| Report output | `/mnt/msb-web/my/lor2db/reports` | Configured by `LOR_REPORT_OUTPUT_DIR`. |
| Report base URL | `https://my.sheboyganlights.org/lor2db/reports` | Configured by `LOR_REPORT_BASE_URL`; public protected-route validation remains pending. |
| Reconciliation operator | `gliebig@sheboyganlights.org` | Configured as the current sole member of `LOR_PREFLIGHT_OPERATORS`; future operators must be explicitly added. |
| Synology access group | `web_maintainers` | Normal ACL and Advanced Share Permissions both set to Read/Write. |

The reconciliation application and published reports have different access
boundaries. Only explicitly named addresses in `LOR_PREFLIGHT_OPERATORS` may
operate reconciliation. Published reports are intended for authenticated
`sheboyganlights.org` users and do not grant access to the reconciliation
controls. The corresponding Cloudflare Access policies remain to be installed
and validated.

The installed service uses these corrected production settings. The obsolete
`/opt/msb-production-database` paths and `User=msbadmin` setting must not be
restored:

```ini
User=lor-preflight
Group=msbadmin
WorkingDirectory=/opt/lor-preflight
EnvironmentFile=/etc/msb/lor-preflight-api.env
ExecStart=/opt/lor-preflight/.venv/bin/gunicorn --bind 127.0.0.1:8784 --workers 2 --timeout 240 backend:app
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

### Still pending

- Verify the authenticated reverse-proxy API route end to end.
- Complete the Run 4 browser acceptance test described below.
- Confirm static application and generated report publication through the
  public protected URLs.

Run the non-database safety tests from this directory with:

```text
python -m unittest -v test_backend.py
```

## Run 4 acceptance test

Run 4 must remain unchanged until the backend exists. Its five display rows are
the first production-flow acceptance data:

- `FE-TuneRadio-2CH-01`: choose `DEFER` during the interface test.
- `QV-Making-01`, `QV-Bright-01`, and `QV-Spirits-01`: operator selects the
  appropriate missing-from-LOR action; no action is preaccepted.
- `QV-ToolBox`: `ADD_NEW_DISPLAY` is the proposed action, still requiring
  operator acceptance.

Stage, scene, and scene-display sections must render automatically when their
review views return decision-required groups. Empty sections are omitted.
