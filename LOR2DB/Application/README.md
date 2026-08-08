# LOR Preflight Operator Interface

| Document control | Value |
|---|---|
| Status | PRODUCTION VALIDATED — Run 4 and lor2db landing page accepted |
| Initial release / current revision | 2026-08-04 / 2026-08-06 |

## Revision history

| Date | Change |
|---|---|
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
`/lor2db/preflight/api/`. It shows:

- the current committed snapshot, parser/ingest provenance, and row counts;
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
`REPORTING`. The landing page must present **Continue previous reconciliation**;
the run page presents **Retry report publication**. Repeating Finish does not
repeat P1-P4; it retries only publication.

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

The health response must report `V0.3.3`. Retrying Finish for a run already in
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
