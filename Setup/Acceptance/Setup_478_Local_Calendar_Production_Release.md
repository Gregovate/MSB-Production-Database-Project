# PR478 — Governed 2026 Setup local-calendar Production release

**Authority:** #122 / #205 / #132; Server Management
`Production_Database_Change_Deployment_Runbook.md` and
`Production_Database_Maintenance_Mode.md`.
**Classification:** DATABASE-CHANGING; one reviewed function-local migration 079.
**Application:** Setup V0.3.106-local-calendar.
**Accepted source:** `df5aedd897aa967e1c567dd9d53e40da1712f308`.
**Merged target:** `e1d5c9d9d5ef5a8c59f0381ea559d240aed1c30b`.
**Prior live source:** `85769c951429cec6faa1ed8ae627501bb8ba028b` (operator browser-preview receipt).
**Status:** release runner engineering candidate — NO LIVE DEPLOYMENT.

## Why this release is independent of #479

The exact source candidate of PR478 already passed 4 GitHub workflows,
current-Production disposable migration/validation and the operator's local-date
browser exercises. Operator's retained terminal receipt is
`Setup REUSABLE DISPOSABLE BROWSER PREVIEW: CLEAN EXIT`,
`PR478 ACCEPTANCE RUNNER PASS`.
PR478 then merged without application/schema changes. #479 search/history
presentation changes and #205 QC/labor attribution defects are explicitly excluded.
No unreviewed feature/source should be combined into migration 079.

## Existing deployment mechanism

`setup_478_local_calendar_release.py` is a narrowly reviewed **profile of the
existing** `setup_maintenance_deploy.Deploy`, not a new maintenance runner.
The existing orchestrator owns the cooperative deployment lock, maintenance
controller, freeze proof, validated rollback snapshot, frozen business-row
fingerprints, source promotion, return to ONLINE, fail-closed STOP and retained
report. The profile pins the candidate, merge commit, tree, migration blob,
prior live Setup SHA and exact version; verifies existing service/backup state;
proves that the four existing function bodies, owners, privileges and existing
settings are preserved except for newly added America/Chicago TimeZone.
Production SQL validation is read-only except the one approved migration, which
runs only inside the controller's maintenance interval.

`setup_478_transport.py` uses the already-established committed-blob transport;
`run_setup_478_local_calendar_release.ps1` uses a fixed explicit MSB Database
checkout path, detached temporary worktree, single SCP and foreground SSH/sudo.
It never assumes the user's current PowerShell directory, does not change
their main/GIS/counter worktrees, and does not require Node.js on Windows.
The PowerShell `-ReleaseSha` argument must be the exact **merged and reviewed
release-tooling commit**, distinct from the pinned accepted application SHA.

## Execution gates

1. Full Setup and engineering-compliance CI on the release profile, plus
   profile source/transport review.
2. Read-only Production preflight using the exact `-ReleaseSha` with no `-Deploy`.
   STOP if the live Setup SHA, backup chain, controller, role permissions,
   migration function settings or source lineage do not match.
3. Separate explicit Production authorization, then the same exact tooling
   `-Deploy`. Greg's request to get the accepted fix into Production is recorded;
   the server must still prove live preflight before any mutation.
4. Controller MAINTENANCE; freeze proof; validated rollback snapshot; migration
   079 only; SQL/function/security and business-data equality; exact Setup source
   promotion; return to ONLINE; health and focused regression. Keep reporter
   attribution, historical assignments, dates, rows, roles and receipts intact.
5. Retain stdout report and snapshot path/SHA; protected Manager/Crew browser
   smoke against real service after ONLINE. Do not fabricate this receipt.
6. Append the Production deployment change log and #122/PR478 acceptance
   evidence after the real operator receipt. Never claim deployed from a merge.

## STOP and preservation

A failed preflight makes no Production edits. If deployment fails or connection
drops after maintenance begins, the existing orchestrator's retained
`state.json`, report and snapshot are authoritative. Do **not** rerun, restore,
reset, or operate maintenance ON/OFF manually. Obtain and inspect the journal
under the governing recovery runbook. The accepted PR478 preview CLEAN EXIT
already freed port 8898; preflight rechecks ownership.

The additional discovered problem — actual work performed on November 8
being associated with an older scheduled assignment for day-level totals —
is an unresolved **separate reporting aggregation** issue. The migration
must not invent, move or duplicate the 2026 field labor reports.
