# LOR2PC deployment preparation and rollback

Filename: DEPLOYMENT_AND_ROLLBACK.md · Revision 2 · 2026-10-27
Owner: #81 accepted-source API; #299 PC application; Server Management runtime
Status: NOT AUTHORIZED FOR PRODUCTION EXECUTION

## Authorities read

Server Management main `063d5fbc53e1ae3549de5e22f8e452e7b734ba3c`:
`docs/server/02 LOR Pre-Flight Application Deployment.md` and
`docs/server/Protected_Flask_Application_Service_Deployment.md`.
Application authority: `LOR2DB/Application/README.md` records the later accepted
lor-preflight account, protected environment, publisher and NAS mount.
Project rule: `System_Documentation/Project_Rules/Runbook_First_Production_Rule.md`.

RUNBOOK GAP FOUND: the server's LOR-specific document still describes initial
V0.1.0 deployment. It does not cover the new role-resolver grant, current-source
module, loopback browser handoff, or rollback of a source-only LOR update.
This application document records the required release boundaries; the runtime candidate and selective rollback are now in Server Management draft PR #102. They remain undeployed and subject to current-clone/browser gates.
Do not improvise a live deployment from the old initial-install instructions.

## Read-only prerequisite

`Inspect-LOR2PC-Production.sh` is intended to run on msb-prod-db as msbadmin.
It checks the existing service, fingerprints the deployed backend/publisher,
checks the accepted NAS mount, and queries source/permission evidence inside
`BEGIN READ ONLY`. It never reads or prints environment-file credentials,
changes files/grants, restarts services or calls parser/ingest/reconciliation.
Greg ran the corrected transport successfully. The service, mount, accepted-source and missing-privilege results are recorded in ../evidence/production-preflight-2026-10-27.json.
Its expected container/database names must match the existing accepted runtime.
A nonzero result is HOLD; do not retry by weakening permissions.

Capture the exact source SHA, service runtime, backend version, source run,
digest availability and role-resolver privilege before constructing deployment.
The digest must come from the frozen accepted run, never today's G: files.

Inspect Cloudflare separately: allow Production Crew to reach `/lor2db/pc/` and
the read-only current-source route while all existing mutation routes continue
to enforce the administrator allowlist. A broad page-policy reduction must not
be mistaken for backend authorization. Do not alter live policy in this step.

## Reviewed release sequence — production approval still required

1. Pass exact-candidate Windows engine, transport and browser tests. Retain the
   already accepted Show-PC engine result at 717cfc4e; candidate 1.0.2 changes the
   transport helper, metadata and comparison-only gate and requires its own tests.
2. Reconcile the above runtime runbook gap in Server Management. Record explicit
   approval for service/static deployment, database permission change, and any
   Cloudflare policy change separately. No PC apply is part of this release.
3. Under the Server #37 maintenance procedure, require freeze proof and verified
   rollback snapshot. Capture prior function EXECUTE privilege; apply only
   migration `0043_grant_lor2pc_source_reader.sql`. It grants one read-only role
   resolver to the existing API role. Validate and return ONLINE using the
   governing maintenance runbook. Do not run all historical grant scripts.
4. Stage exact committed `backend.py` and `current_source.py` under
   `/opt/lor-preflight` together. Back up both prior files (record a previously
   absent module explicitly), their owner/mode and SHA-256. Existing publisher,
   environment file, pairing token and runner remain unchanged; verify their
   fingerprints before/after. Preserve the deployed publisher rather than
   replacing it from an older checkout. Restart only lor-preflight-api.service
   according to the reconciled source-update procedure.
5. Require health V0.6.6, 401 without identity, and current-source accepted
   evidence from a trusted proxy-authenticated request. Verify a crew login can
   read source and cannot invoke administrator operations. No ingest or Finish
   operation is used as an acceptance test.
6. Back up NAS `/mnt/msb-web/my/lor2db/index.html` and any existing `pc/` files.
   Publish only the committed landing index and `lor2db.js` plus `pc/index.html` and `handoff.js`;
   exclude tests. Existing preflight API proxy already covers current-source;
   no new backend listener or firewall opening is intended. Require mount and
   destination identity before writes; do not populate an unmounted directory.
7. Prepare the exact PC candidate with `Prepare-LOR2PC-Candidate.py` from a clean
   committed checkout. Its metadata explicitly disables apply. Install the
   per-user launcher only with approval, recording previous protocol registration
   and retaining the previous immutable application directory.
8. Use the crew browser page to launch the COMPARISON-ONLY updater. Browser local
   network/protocol prompts must be handled normally; never disable security.
   Require latest accepted source, expected controlled inventory and clean-PC
   ADD approximately 34 / REPLACE 0, preserving default/store entries. Compare
   actual local-library hash before and after: it must be identical.
9. Stop after comparison. A separate explicit live-apply candidate/approval and
   LOR reopen + repeat ADD 0 / REPLACE 0 are still required for production release.

## Rollback boundaries

- Permission: if this release introduced EXECUTE, revoke only that EXECUTE grant
  in the governed database maintenance window; do not revoke a pre-existing
  privilege. Do not drop or replace the shared Setup capability function.
- API: restore exact backed-up files/owners/modes, remove current_source.py only
  if it was absent before this deployment, restart only the LOR service and
  require the recorded prior health version. Do not restore another app's files.
- NAS: restore only named files from the immediate pre-release backup; remove
  newly created named PC files only if absent before. Preserve reports/logs.
- Access policy: restore the captured prior policy through its owning control
  plane if changed; retain the API administrator guard throughout.
- PC launcher: restore the prior HKCU msb-lor2pc registration, or remove only the
  key introduced by this installation. Keep evidence/application directories.
  Comparison-only operation has no LOR-library rollback because it never applies.

On any failure, stop, preserve report/backup paths, execute only the recorded
applicable rollback, and verify LOR2DB plus unrelated existing apps remain healthy.
Do not report deployment PASS until protected browser and rollback evidence exist.
