# Direct required Containers — C106

| Document control | Value |
|---|---|
| Status | OPERATOR ACCEPTED / PRODUCTION AUTHORIZED — installation pending |
| Reviewed | 2026-10-14 |
| Owner | #122 / DBG-2026-013; Pick List integration #206 |
| Baseline main | b183a79124d1de9ccf1844f4fc4613a911bcc938 |
| Branch | fix/122-direct-container-requirements |
| Version | V0.3.64-required-containers |
| Migration | Setup/Database/073_add_setup_required_container_command.sql |

Greg cannot readily add C106 Who Ville Panel Stands (8) to the Who People task:
the material form demands an unrelated catalog item after he selects its source
Container. Material Status search CONT:106 also returns no row. Source review proves
that annual material demand is required for that Manager projection; it is not a
complete warehouse catalog. No claim of live database inspection is made.

New **Required Containers → Add / Remove Container** searches by number/name and
saves a checked Container immediately. No extra material, contents or quantity
entry is required. The existing REQUIRED_CONTAINER authority feeds the existing
scheduled Pick List and unscheduled annual Manager Material Status projections.
Other KIT/SUPPORT links are shown checked/locked here; their owning editors remain.

Migration 073 adds only a Manager-authenticated/audited command over the existing
relationship table. It is a database-changing release, not source-only deployment.
No Production code, data, permissions or service have been changed.

## Engineering evidence

- Full application regression: **763 passed**.
- Actual PostgreSQL/WASM migration test: PASS for non-Kit C106, site-wide task,
  repeated save, sharing, removal, rollback, non-Manager denial, inactive/missing
  identity rejection, and preserving an existing KIT assignment and Container Type.
- Focused application projection/API tests cover manual/scheduled demand, moved and
  Workshop gates, shared physical deduplication, command attribution and commit.
- Isolated SQL is supplemental; it does not replace current-Production clone tests.
- Actual UI executed in isolated DOM: PASS for C106/106/name search, save with only assigned=true, persistence/readback, KIT lock, failure restoration, removal and non-Manager hiding.
- Exact candidate SHA is recorded in the implementation PR.
- Developer-only supplemental tests live under `engineering/`: install jsdom and @electric-sql/pglite in a temporary external directory, then set JSDOM_MODULE/PGLITE_MODULE to their absolute module entry paths when running the .mjs tests. These are not workstation/browser-preview dependencies.

## Single disposable acceptance and browser review

Use existing `run_setup_disposable_browser_preview.ps1`, explicit port 8898,
PreviewEmail gliebig@sheboyganlights.org, the exact PR candidate SHA and branch,
ExpectedVersion V0.3.64-required-containers, migration above, validation
`Setup/Acceptance/setup_required_container_validation.sql`, and
`-AllowConcurrentProductionWrites`. One regression → one clone → validation →
browser lifecycle. Do not launch separate acceptance and browser clones. Observe
port ownership and stop on failure; open only after BROWSER REVIEW READY.
Server authority: MSB-Server-Management Pre_Production_Browser_Review_Runbook.md,
PostgreSQL_Disposable_Acceptance_Standard.md and Application_and_Test_Port_Register.md.

1. In the disposable 2026 Catalog, select the actual Who People setup task.
2. Required Containers → search C106, 106, Who Ville; select C106 once. No Item,
   quantity or contents definition is required. Close, refresh and verify persistence.
3. If task is unscheduled, refresh Material Status and search CONT:106. Verify
   its task reason and Add to Pick List; exercise existing Manager dates/override.
4. Schedule the task in this clone and verify ordinary Pick List shows C106 once
   with the correct task/dates. Verify scanner validation accepts its live demand.
5. Remove only the direct requirement and verify another task's shared link and
   any independent Manager override remain. Remove clone-only override separately.
6. Verify existing Kit Box and detailed material editing still work; non-Manager
   cannot assign, Workshop/moved Containers retain existing safety rules.
7. Confirm clone audit attribution and no expected-content/inventory/movement
   mutations from requirement save. Finish CLEAN EXIT; retain report and verdict.

Production approval follows accepted exact-candidate browser review. Use the current
Server Management database-change runbook/maintenance window for migration 073;
no deployment command is authorized by this candidate document.

## Local cleanup after acceptance/integration

Return to the actual primary checkout (Desktop C:\Users\Greg\Github\MSB-Production-Database-Project;
Laptop C:\lor\ImportExport\VSCode). Inspect worktree list and clean status first.
Fetch origin main and fast-forward primary main. Remove only this task's clean
preview worktree after its branch head is proven ancestral to origin/main, then
`git branch -d fix/122-direct-container-requirements`. Stop on any failure; no force.
Server CLEAN EXIT and local worktree cleanup are separate steps.

## October 14 operator acceptance and approved deployment

Greg assigned C106 to Setup Who People in the V0.3.64 disposable browser and
confirmed it remained after refresh. He confirmed reusable preview CLEAN EXIT,
then explicitly approved deployment including migration 073. Feature PR #389
merged as `625693fea1f1ca024f14885701e9f4fa55ccda5b`. The accepted/deployment
application pin remains `efb7f26fd0d4e1275daa509e2ade62bc291b1d8f`.

Use `run_setup_required_container_deploy.ps1` from updated primary main.
It packages committed bytes through the existing Windows transport, invokes
`setup_required_container_deploy.py` as a bounded profile of
`setup_maintenance_deploy.py`, and uses the installed Server Management controller.
It does not rebuild the already-accepted disposable clone. The exact source
receives host regression while ONLINE; only the short installation enters
MAINTENANCE → current freeze proof → controller-validated rollback snapshot →
migration 073 → exact function/least-privilege and all ref/ops-row preservation →
Setup source promotion → controller OFF/ONLINE proof → exact health/regression.
The shared checkout stays at its observed/ancestry-verified identity, including
newer accepted People work. C106 is not assigned or marked picked by deployment.

Expected Setup baseline is operator-recorded `2bc88ae627420c2138268e39a26b4942a3248580`
/ V0.3.62. Any baseline drift, active preview, failed snapshot or validation stops.
The existing deployment lock, retained journal and failure containment are reused.
No error cleanup calls OFF, retries SQL, reverses data or restores the database.
After STOP or interrupted SSH, inspect the exact retained journal/controller
before any retry; do not toggle the dashboard concurrently.

Reports: `/home/msbadmin/setup-deployment-reports/PR389-073-<UTC>/`.
Snapshot: the existing `/home/msbadmin/backups/setup-205/` archive directory,
with unique `pr389-073` name and retained validated SHA256. Deployment PASS still
requires protected Production browser confirmation and actual report transcription.

Office PC primary checkout confirmed:
`C:\Users\Greg\Github\MSB-Production-Database-Project`.
C106 preview worktree is `C:\Users\Greg\Github\MSB-389-Containers`.
Preserve the separately listed Scheduling, Locate, GIS Office and #88 worktrees.
After PASS, return to updated primary main, prove the C106 branch is merged and
its worktree clean, remove only that worktree and delete only its merged branch.

### Deployment tooling verification

- 25 targeted maintenance/profile/Windows-transport tests PASS; Python compile and
  diff checks PASS. Existing controller safety ordering remains unchanged.
- Broader historical Acceptance suite was also checked: baseline merge 625693fe
  already has eight legacy #88 installer tests failing against newer report/helper
  sources. Historical transport fixtures now read their exact pinned Git blobs,
  fixing two of those failures. Six older report-query-count tests remain unrelated
  to this release; the current runner does not invoke those retired installers.
- The accepted application source and 763 passing application tests are unchanged.
