# Scheduled search reveals collapsed work days

| Document control | Value |
|---|---|
| Status | OPERATOR ACCEPTED / DEPLOYMENT AUTHORIZED — installation pending |
| Reviewed | 2026-10-14 |
| Owner | #205 / #122 DBG-2026-014 |
| Baseline main | be8988cd4cf65f5ce8eb1816568714a3a643bdf5 |
| Branch | fix/205-search-expand-day |
| Release | V0.3.65-scheduled-search-focus |
| Migrations | None; consumes existing accepted baseline |

Greg's October14 screenshot and Randy Miller's October12 email (subject
Finding scheduled tasks) show the same defect. Search returns Layout Tree Benches
D7/Oct5 CrewE AM and Setup Tree Benches D10/Oct9 CrewF AM, but choosing a result
cannot reveal the assignment while its reported day is collapsed.

`board205RevealScheduledAssignment` enabled the day filter and rerendered, then
scrolled a card inside hidden day content. It now expands only that card's day,
updates the collapse button's arrow/aria-expanded, focuses the card without an
extra scroll jump, then applies the existing scroll/highlight. Other days stay
collapsed; search dismissal and schedule/report data are unchanged. The existing
workload branch has the same original reveal function; this isolated correction
must be reconciled there rather than overwriting concurrent KPI work.

## Engineering checks

Actual candidate reveal function executed in isolated DOM against completed,
unfinished and empty day filters: target expanded before scroll, target-only
expansion, keyboard focus, arrow/aria state, highlight/removal and null selection
PASS. Supplemental test: `engineering/test_scheduled_search_reveal.mjs`, using
an externally installed jsdom via JSDOM_MODULE; this is not an operator dependency.
Full Setup/Application and shared preview regression, JS syntax and diff checks
are recorded with exact SHA in the PR. No server/Production work performed.

## Governed browser acceptance

Use the existing reusable disposable browser launcher, exact candidate SHA from
the PR, branch above, ExpectedVersion above, port8898 and concurrent Production
writes allowed. MigrationPaths/ValidationPaths empty: source-only candidate on the
existing schema. Reuse one clone/browser lifecycle; verify port ownership and do
not interrupt a concurrently owned review. Open only after BROWSER REVIEW READY.

- Collapse a reported day containing a scheduled task, including Randy's bench
  examples where present. Search ben/candy and select its exact occurrence.
- Correct day opens; correct task card receives focus/highlight and scrolls into
  view. Other reported days stay collapsed. Repeat for another day/crew occurrence.
- Exclude completed days via Day view, search a completed-day occurrence and
  verify its filter is enabled and the day/card is revealed.
- Check already-open day, ordinary manual collapse/expand, keyboard result-button
  activation and search popup dismissal after selection/outside click/Escape.
- No schedule/report/movement writes should occur. Finish CLEAN EXIT and record
  actual disposition. Source changes after acceptance require affected review.

No Production deployment is authorized for this candidate. Greg requires the
system maintenance mechanism for deployments; read current Server Management
runbooks and reconcile the actual live baseline before any later deployment.
PR389 migration073 deployment/receipt is separate; do not replay its installer to
deploy this change or assume it ran merely because it is merged.

## Workstation and cleanup

Latest confirmed PC is Office. Primary main:
`C:\Users\Greg\Github\MSB-Production-Database-Project`.
Preserve existing Scheduling/Locate/GIS/#88/C106 worktrees and their branches.
Use a separate clean worktree for this branch after current worktree inventory.
After acceptance and integration, return to refreshed primary main; prove branch
ancestry and clean ownership before removing only this review worktree and deleting
its merged local branch. Server CLEAN EXIT is separate from local Git cleanup.

## October 14 acceptance and maintenance deployment

Greg confirmed the search correction works, confirmed reusable preview CLEAN EXIT,
and explicitly approved merge/deployment at13:51 CDT. Feature PR391 merged
`4819959be8bdad3d002623775b83ebe876a417e5`; exact accepted/deployed application
target remains `86341d49dc8ccf290575f9d2b418c235094a1377` / V0.3.65.
Day View wording is a separate #205 finding, not part of this accepted source.

Use the existing wrapper with the new allowlisted profile:

```powershell
.\Setup\Acceptance\run_setup_required_container_deploy.ps1 -Release ScheduledSearch
```

Run from refreshed clean primary main. The same committed-byte Windows transport,
cooperative deployment lock, stage journal and installed maintenance controller
are reused. No new launcher, extra disposable clone or dump is introduced.
Host exact-source regression runs ONLINE; then controller ON/freeze, complete
ref/ops-row preservation baseline, exact detached Setup promotion, unchanged
shared checkout, preservation equality, controller OFF/ONLINE, exact V0.3.65
health and live regression. No SQL migration, business edit or PostgreSQL rollback
archive is required for this source-only profile. Maintenance mode is used at
Greg's explicit request despite the source-only runbook not normally requiring it.

Preflight requires actual live Setup `efb7f26fd0d4e1275daa509e2ade62bc291b1d8f`
/ V0.3.64 and exact already-installed migration073 command/security, plus clean
source/healthy services and backup chain. The earlier deployment receipt has not
been supplied to this thread; this is an enforced prerequisite, not a claim it
is already installed. A different baseline or absent073 stops BEFORE maintenance.
This profile never silently applies/replays073. Inspect the prior PR389 report
if it stops; do not reset live source or rerun a migration to satisfy the gate.

Reports: `/home/msbadmin/setup-deployment-reports/PR391-Source-<UTC>/`.
Failures do not retry, restore the database or automatically call OFF. Preserve
controller/journal evidence and inspect before another action. No concurrent
maintenance dashboard or other directing chat during this window.
31 focused maintenance/profile/Windows-transport tests PASS; compile/diff and
canonical transport checks are separate from the accepted application764 checks.

After server PASS, refresh protected Production, verify Client V0.3.65 and Updated
2026-10-14, and repeat collapsed-day bench search. Transcribe actual report, live
source/version, preservation and ONLINE proof into release closeout/change log.
No Production success is claimed until the operator provides that evidence.

Office review path for this change: `C:\Users\Greg\Github\MSB-391-Search`.
After successful deployment, return to primary main, fetch/fast-forward, prove
fix/205-search-expand-day is ancestral to origin/main, verify review ownership and
clean state, remove only that worktree and delete only its merged local branch.
Preserve all Scheduling/Locate/GIS/#88/C106 worktrees.
