# Setup #205 — Migration 069 Deployment Record

| Document control | Value |
|---|---|
| Status | DRAFT — review hold; not an execution instruction |
| Owner | MSB Production Database project owner |
| Prepared | 2026-10-04 |
| Owning issue | [#205](https://github.com/Gregovate/MSB-Production-Database-Project/issues/205) |
| Implementation | [PR #293, merged](https://github.com/Gregovate/MSB-Production-Database-Project/pull/293) |
| Runtime authority | Gregovate/MSB-Server-Management |
| Scope | Setup migration 069 and V0.3.38 deployment only |

## Purpose and hold

This record supplies the release-specific gates beneath the Server Management procedure. It does not replace that procedure or create another maintenance implementation.

Greg authorized Production deployment after merge, then explicitly held execution until the workflow was deliberately documented and reviewed. That hold remains in force. No new maintenance entry, snapshot, migration, application checkout move, or service restart has occurred.

The previously supplied inline preflight block is withdrawn pending this review. It did not include the full database and recovery gates. Do not resume from that block.

## Governing authority

Retrieve and read these current repository documents before execution:

- [Production Database Change Deployment Runbook](https://github.com/Gregovate/MSB-Server-Management/blob/main/docs/server/Production_Database_Change_Deployment_Runbook.md), observed blob `19bd65f11b11f92d7ae8c0f06bda54ceb9a554dd`.
- [Production Database Maintenance Mode](https://github.com/Gregovate/MSB-Server-Management/blob/main/docs/server/Production_Database_Maintenance_Mode.md), observed blob `919da2182d6d211d789c213ab37b3bdb085f8208`. Its launch closeout supersedes the historical prototype blockers.
- [Setup Production Runtime](https://github.com/Gregovate/MSB-Server-Management/blob/main/docs/server/Setup_Production_Runtime.md). Its historical SHA sections must be reconciled with the verified live baseline below.
- [Runbook-First Production Rule](../../System_Documentation/Project_Rules/Runbook_First_Production_Rule.md).
- [Release Identity and Versioning Rule](../../System_Documentation/Project_Rules/Release_Identity_and_Versioning_Rule.md).

Classification: **DATABASE-CHANGING**. Use the installed Issue #37 controller for entry, freeze proof, snapshot and return to service. Do not replace it with a Setup-only service stop or manually reproduce its HBA logic.

Latest accepted precedent: [migration 068 / PR #292 server acceptance](https://github.com/Gregovate/MSB-Production-Database-Project/issues/205#issuecomment-5975602651). That deployment completed detached regression, maintenance, writer freeze, validated snapshot, migration, dedicated Setup checkout promotion, return to ONLINE and live regression.

## Release identity

| Item | Pinned value |
|---|---|
| Accepted candidate | `3063a92877d89e5ec00b3b8187da20d208498254` |
| Accepted tree | `1ed39fd16c97da09fb28d500af1b186d5a10ce0d` |
| PR #293 merge | `e2f58d016f015f1ac695940e9ab67c61c04a8a8a` |
| Proposed deployed Setup SHA | `e2f58d016f015f1ac695940e9ab67c61c04a8a8a` |
| Proposed visible version | `V0.3.38-setup-day-milestones` |
| Migration | `Setup/Database/069_fix_setup_day_sequence_and_audit.sql` |
| Migration blob | `a49b25cf7325da86fc9810e8a75465de07f8cadf` |
| Disposable validation | `Setup/Acceptance/setup_205_day_sequence_history_disposable_validation.sql` |
| Validation blob | `2d91feae12800815f952b8c748df6918a4fb8ee4` |

Deploy the merged application target, as migration 068 did, only after proving its full tree equals the accepted candidate tree. A later documentation/tooling commit is not a new application target. If tree equality fails, stop and reconcile; do not redefine acceptance.

## Verified evidence and live baseline

Operator-supplied server output establishes:

- `/opt/msb-setup`: `f01444e4131083615e2b13f144b75022860fdff6`, clean.
- `/opt/fieldwiring`: `6dd05c4aa5ef8f50fe172145c3ae281cc245a101`, clean.
- Setup health: postgres / ok / `V0.3.37-record-location-scanner`.
- Real controller: ONLINE, last_error null, database_fenced false, read continuity OFF.
- Governed services active and Directus running; NAS mounted and current backup replication PASS.

The controller's retained freeze/snapshot gates belong to migration 068. They are not a current freeze proof or a rollback point for 069.

Reviewed reports under `/home/msbadmin/setup-acceptance-reports/`:

- `Setup_Disposable_Acceptance_20261004T113717.txt`.
- `Setup_Disposable_Browser_Preview_20261004T113913.txt`.

Both pin the exact candidate, migration 069 and supplied validation; 676 tests passed; validation passed; exit status 0. Preview version and authorization passed, and operator-ended cleanup is recorded. Both prove Production fingerprint `26aa751c63d844c1e618a3c3641b07c4` and live Setup SHA unchanged. Chrome/operator browser acceptance is recorded separately in the issue recovery comments.

These are evidence checkpoints, not permanent current-data fingerprints. Legitimate online scheduling may have continued since capture.

## Intended changes and preservation contract

Migration 069 renumbers retained Work Days in **every PLANNING or ACTIVE session**, ordered by work_date then stable day ID, to contiguous 1..N. Inventory all affected sessions, not just 2026.

Expected changes:

- setup_day_number and normal update-audit metadata on renumbered rows;
- new passive scheduling event table, indexes and audit triggers;
- governed historical-day addition and noted empty-day removal;
- replaced resequencing, past-insert guard and assignment-move command functions;
- Setup application version, annual milestones, accepted presentation and scrolling.

Preserve:

- complete Work Day ID set, dates, session identity and all other planning fields;
- assignment IDs and payloads, crews, task progress and execution history;
- historical-verification and other non-open session Work Day rows unchanged;
- reusable Catalog, dependencies, material mappings, physical movement/location state;
- session count and status, role memberships, existing unrelated privileges and source checkouts.

Do not insert the missing 2026-10-02 day or delete a real day as part of installation. Historical correction is an operator feature, not a deployment test.

A whole-Setup fingerprint is expected to change. Compare exact expected numbered rows and independently preserved data, rather than requiring the old whole fingerprint to stay equal. Identify permitted audit-column changes from the actual audit function before constructing preservation checks; do not ignore every metadata column by assumption.

## Stage gates and operator workflow

Greg runs one bounded stage in the existing trusted `msbadmin@msb-prod-db` terminal. The agent supplies the reviewed command and waits for its result. Full output stays on the server; the operator returns a short stage PASS/STOP summary, report path and essential identity values. Detailed output is requested only for a failure or ambiguity.

Each mutation is introduced with Authority / Procedure / This step. No later mutation is issued until the preceding gate has been inspected.

| Stage | Action | Required evidence before proceeding | Stop behavior |
|---|---|---|---|
| A: ONLINE preflight | Recheck exact live SHAs, clean worktrees, service health/controller state; explicitly fetch current main; prove target ancestry, merged/accepted tree equality and migration blob; detached Setup regression using Production Python | Exact source pins, healthy ONLINE baseline, regression PASS, 068 function/trigger baseline, affected-session inventory | No maintenance entry; retain report |
| B: Freeze | Installed controller ON, then inspect current real status | MAINTENANCE, freeze_proof ok, DB fenced, zero normal writer sessions, continuity active | Preserve controller fail-closed state; no migration |
| C: Snapshot | Controller snapshot to unique retained 069 dump while frozen; capture preservation baseline | Nonempty dump, recorded SHA-256, validated archive; frozen data mapping and invariants retained | No migration; investigate under maintenance |
| D: Migration | Recheck freeze and exact file blob; apply only 069 through host-file stdin into container psql | psql exit 0, confirmed committed catalog state, no ambiguous interruption | Stop; determine commit state before retry |
| E: Database validation | Non-writing checks of numbering, preserved data, definitions, privileges and audit objects | All expected row/privilege/object assertions PASS | Remain fenced; no application promotion/OFF |
| F: Setup promotion | Move only dedicated Setup worktree to pinned merged target; retain previous Setup SHA | Exact target SHA, clean status, matching server/client declarations, unchanged shared checkout | Remain fenced; preserve report |
| G: Return to service | Controller OFF restores previously active writers and checks health | ONLINE, no fence, no last_error, health checks/web restoration PASS, Setup V0.3.38 | Follow controller ERROR/fail-closed recovery; do not bypass |
| H: Live acceptance | Bounded Setup health/read-only negative identity checks, live regression, protected browser smoke | Exact version/SHA; board numbering, milestones, scrolling/navigation and protected routes PASS | Report failure; do not automatically restore database after writers reopen |
| I: Closeout | Commit actual outcomes and evidence into repository docs | Acceptance record, reverse-chronological deployment log, Server Management runtime record and issue disposition | Keep issue open until closeout complete |

No OS upgrade, reboot, maintenance reinstall, unrelated service deployment or shared checkout promotion is included.

## Command source and execution preparation

The release runner must be pinned and reviewed before Stage A is issued. Commands are adaptations of the governing runbooks, not recalled chat commands.

Known controller interface, to be used only by the reviewed stages:

```text
sudo python3 /opt/msb-maintenance/msb_maintenance_controller.py --config /etc/msb-maintenance/config.json status
... on
... snapshot <unique-retained-069-archive>
... off
```

Migration command pattern:

```text
sudo docker exec -i msb-postgres psql -X -v ON_ERROR_STOP=1 -U msbadmin -d msb < <verified-host-migration-file>
```

The migration already owns BEGIN/COMMIT. Do not feed a host path to container psql -f or use cat pipelines. Do not run the supplied disposable validation on Production: it creates/deletes/moves test rows and sequence advancement is not undone by ROLLBACK.

Dedicated Setup promotion follows the successful 068 boundary: `sudo git -C /opt/msb-setup checkout --detach <pinned-merged-target>`. It does not advance `/opt/fieldwiring`.

During maintenance Setup is stopped and its port may serve the maintenance responder. Do not expect normal Setup health until return to service. Validate source/database before OFF; then require the controller's bounded service health and the exact release version.

Required execution artifacts still to complete:

1. Versioned staged runner with stage journal, error trap, safe temp cleanup and concise terminal summaries.
2. Non-writing Production SQL checks plus frozen preservation capture/comparison, including all open sessions and audit attribution.
3. Failure-path tests showing no automatic migration retry, snapshot before freeze, OFF after failure, or partial-success message.
4. A documented recovery disposition for committed 069 failures; if restore is selected, retrieve the responsible server recovery authority and review its exact commands before they are used.

## Failure and recovery decisions

| Observed state | Required response |
|---|---|
| Before maintenance | Stop; do not change Production; clean only owned temporary test artifacts |
| Maintenance entry failed | Controller may be ERROR/fenced; inspect actual state; do not call OFF blindly |
| Snapshot/preflight failed before migration | No database repair is needed; diagnose gate; return through controller only after safe baseline/health are confirmed |
| Migration psql failed or transport interrupted | Determine transaction/commit state from catalog and journal; never infer rollback merely from lost stdout; do not rerun automatically |
| Migration rolled back, baseline verified unchanged | Use controller-governed return once baseline and health are proven; retain failure report |
| Migration committed, validation/promotion failed | Keep writer fence; retain snapshot and before/after evidence; select reviewed forward correction or database recovery with administrator |
| App moved but database checks incomplete | App-only reversal is not a complete rollback; keep maintenance and record both identities |
| OFF failed | Controller's fail-closed ERROR path governs; do not manually open HBA/start writers to force green health |
| Failure after ONLINE | Normal writes may exist; no automatic whole-database restore; reconcile them before any separately reviewed recovery |

**RUNBOOK GAP FOUND:** the generic deployment runbook's newly-installed-function rollback example does not fully specify reversal of 069's replacements of existing functions plus persisted Day renumbering. This record defines a safe containment decision (remain fenced and inspect) but does not claim an executable restore procedure has been validated. Complete the appropriate recovery authority or accepted release-specific forward-recovery plan before execution clearance. Do not improvise DROP commands or restore the database merely to undo a UI issue.

A thread loss is not an instruction to retry. Read this record, staged journal, current controller status, exact live checkout and migration catalog state before choosing the next action. A snapshot path alone is not proof of a completed snapshot; require validation and hash evidence.

## Report and closeout identities

Use uniquely named reports under `/home/msbadmin/setup-deployment-reports/` and archive under `/home/msbadmin/backups/setup-205/`, with PR293/migration069 and UTC timestamp in names. Display times in America/Chicago when summarizing to the operator.

Record actual values after execution: prior Setup SHA/version, shared SHA unchanged, deployed SHA/version, merged-main SHA, migration blob, snapshot path/hash/validation, stage outcomes, invariant deltas, controller ONLINE proof, browser disposition and any recovery performed.

Update [Production Deployment Change Log](../../System_Documentation/Production_Deployment_Change_Log.md) only after actual deployment; do not label this proposal as a completed Production release.

## Review disposition

Current status: documentation review draft; execution artifacts and committed-migration recovery resolution pending. Production unchanged. Do not resume execution until Greg's documentation-review hold is lifted and outstanding mechanical gates are satisfied.

## Revision history

| Date | Revision | Change |
|---|---|---|
| 2026-10-04 | Draft 1 | Captures merged release, verified evidence, maintenance stages, preservation contract, review hold and recovery gap |
