# Setup #206 live Pick demand correction

Reviewed: 2026-10-06. Owners #206/#122. Status: test candidate, Production unchanged. Build V0.3.40-live-pick-demand. No migrations.

Greg reports CONT:12 (Sledder panels/stands/net-light frame, RB07-B-01, Stage 11) shown as Scheduled to Pick, Pick By 2026-10-05, Needed For 2026-10-06, but online Workshop Pick rejects it. Container was added this morning. Screenshots establish a disagreement, not an independently inspected Production database root cause.

Code defect: focused Pick validation maps explicit task displays and a task's direct Scene, while the visible Pick projection uses the installed material-resolution/ownership extensions, including Stage-level LOR membership. Focused mapping misses now consult the authoritative full live physical Pick projection before rejection. Normal focused-demand hits avoid the full projection. Reconciliation retains the physical identity, active delay, and movement observation; movement API still rejects delayed/already outbound assets. No permission bypass or movement write is performed by demand resolution.

Client also refreshes cached demand once before an online rejection, addressing a tab left open while demand/container membership changes. Refresh failure stops with an error; offline cached validation remains unchanged. Scanner shell cache v18 and exact asset pin updated; footer Updated 2026-10-06 and client/server identity synchronized.

Verification: 683 Setup/Application tests; direct JavaScript stale-tab refresh execution; scanner/worker JavaScript syntax; whitespace checks. Five new regressions exercise missing explicit container mapping, delay/movement preservation, normal fast path, and identity mismatch. Full projection on a focused miss costs more than a normal scan; replacing the independent optimized mapping with a common bounded resolver remains a performance follow-up.

Operator acceptance: disposable current-Production browser preview, verify matching V0.3.40 identity, scan CONT:12; exactly one PICKED event, correct container, no manager dependency. Confirm delayed/already-picked assets remain rejected. Keep a tab open, change material demand in the clone, then scan and verify refreshed eligibility. End preview CLEAN EXIT. Production deployment requires Greg's testing approval.

Greg's fallback request remains an operator-level accountable override, not a manager-only planning override; it is not implemented by this candidate. His preferred correction is eliminating this erroneous rejection.

## Operator acceptance and deployment authorization

2026-10-06: Greg confirmed CONT:12 succeeds in the exact candidate, with screenshot showing PICKED FOR PARK TRANSPORT. He reported a slight delay, accepted correctness, reported reusable disposable browser preview CLEAN EXIT, and explicitly authorized Production deployment following project rules. Refreshing the old Production browser did not solve the defect. Raw server preview reports were not independently inspected here.

Approved target `0caed843bb37e7f1f1400972d8f6eb0b03f202d4`; installer old live pin `00de4635b0ee49658f2e6b5782d758e91054ca02`, supported by Greg's PR303 runner PASS at `/home/msbadmin/setup-deployment-reports/PR303-20261005T181340Z`. Server runtime documentation still lists the older V0.3.38 baseline; runner verifies the real exact live SHA before mutation and stops on drift.

Deployment command: `Setup/Acceptance/run_setup_306_source_only_deploy.ps1` from clean merged primary main. Authority: Server Management `docs/server/Setup_Source_Only_Application_Deployment_Runbook.md`. Five installer boundary/rollback tests pass. Advances only /opt/msb-setup, restarts only Setup, no database migration or maintenance. Exact-candidate regression, read-only data preservation, UI date, health/build, rollback, and candidate-worktree cleanup use the proven source-only procedure. Actual installation report, Production screen confirmation, deployment change log, and server runtime closeout remain pending execution evidence.
