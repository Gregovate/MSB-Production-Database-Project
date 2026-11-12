# Perform Work theme contrast — November 11, 2026

Owner: #205 under #122. Presentation-only follow-up to deployed PR482.

Production receipt: application37a02e2d9460d115e1d7255833b264a6bb5d8d80,
V0.3.111-explicit-no-work; merged-main605d86a5e7bf8a27bc4234aab16e54fccea5998a.
Migration080, freeze/snapshot/validation and return-to-service PASS in operator
receipt /home/msbadmin/setup-deployment-reports/PR482-080-20261111T190258Z.
Snapshot /home/msbadmin/backups/setup-205/msb-pre-pr482-080-PR482-080-20261111T190258Z.dump;
SHA256 5b3fbf21946dc07e3886c20f60855495f86ffce4aed6d820f4126b2bcb55f610.
This does not claim complete protected-browser closeout: operator identified a
dark-mode contrast failure after deployment. Do not rerun080 for this fix.

The current-day summary inherited dark-theme light text but used undefined
--surface with a white fallback. Correct it to --card paired with --text.
Shift banners now use paired warning/success foreground/background tokens.
No calculations, commands, data or permissions change. Presentation-only V111
is retained, next-pass asset111.8; exact source SHA is required for review.

Verification: 987 Setup application tests PASS. Actual generated daily/shift
markup evaluated against light, explicit dark and OS-dark palettes meets4.5:1
text contrast. Chromium installation/launch unavailable locally; cloud browser
blocked the local file URL. No visual browser PASS is claimed.

Use the existing reusable disposable preview8898, no migration/validation paths
for this source-only follow-up (080 is already installed in the fresh clone).
Check current-day summary, healthy/warning/overloaded shift banners, task cards,
Report Work and readiness dialogs in light and dark mode. Check after refresh
and with OS dark preference if available. CLEAN EXIT, then separate Production
approval. Current Production remains unchanged during this preview.

## First host preview stopped —191445Z

Operator returned1 failed/974 passed/13 skipped. Failing contrast wrapper invoked
Node unconditionally, unlike existing Node-based tests which skip only when
Node is unavailable. Corrected wrapper to existing runtime detection policy;
Node-present assertion failures still propagate. No application changes.
Exact exception text was not included in the pasted summary; missing Node is
consistent with other skipped tests, not independently proven from that summary.
Retained report /home/msbadmin/setup-acceptance-reports/Setup_Disposable_Browser_Preview_20261111T191445.txt.
Cleanup PASS: Production fingerprint23c6576ae8be2c0bac58a61edf723ba5 unchanged;
live SHA37a02e2 unchanged. No resumable preview. Re-run only corrected candidate.

Full operator console subsequently confirms FileNotFoundError [Errno2] 'node'.
Cause proven: missing optional Node runtime, not a contrast assertion failure.
Corrected wrapper follows established skip-only-if-missing policy. Engineering
run987 tests PASS and direct light/dark/system-dark contrast checks PASS.

## Node removed at operator direction

Greg explicitly prohibited Node for this correction. Removed the new CJS fixture
and subprocess wrapper entirely. Replaced them with pure-Python tests calculating
WCAG text contrast from shipped CSS palettes for light/dark/system-dark, plus
checks that shipped daily/shift markup uses those verified foreground/background
pairs. No new Node requirement, skip workaround, installer or service dependency.
These checks do not claim browser rendering; operator review remains required.

## Accepted theme release gate

Greg confirmed PASS on fdf1549e4215c305cb82b3e6e70e327ade574dd2,
then reusable preview CLEAN EXIT and explicit Production approval. Existing
PR482 application37a02e2 is the exact expected live rollback source.
Release profile reuses305 source installer, not the482 migration runner. Current
Server Management Setup_Source_Only_Application_Deployment_Runbook.md retrieved
and read for this step. No SQL/maintenance/archive; restart only Setup. Existing
source gates/rollback/fingerprint apply; briefly pause edits for preservation.
Tooling/doc/test-only follow-up preserves every accepted runtime file.
Actual Production report and protected live theme check remain pending.

## Production deployment and protected browser PASS

Greg returned source installer PASS in `/home/msbadmin/setup-deployment-reports/PR483-Source-20261111T192732Z`
and confirmed Production browser PASS with the corrected dark summary/shift
screenshot. Exact installed application is the profile-pinned
`fdf1549e4215c305cb82b3e6e70e327ade574dd2` / V0.3.111-explicit-no-work,
asset111.8. Integration/tooling main is3ee52204e64e9d14bc7a9e2306a736645855f0ae.
Runner PASS contract includes exact source, Setup-only restart/health, focused
Python tests and unchanged data/shared source. Actual fingerprint/shared SHA
remain in retained result/report; not independently probed or transcribed here.
No SQL,080 replay, PostgreSQL snapshot or maintenance transition. Rollback source
is37a02e2d9460d115e1d7255833b264a6bb5d8d80; no rollback reported.
Release run started at13:27:32 America/Chicago (19:27:32 UTC). Both-theme disposable
review, CLEAN EXIT and separate approval preceded it. No further runtime release
is needed for documentation. Local review-worktree cleanup awaits command receipt.
