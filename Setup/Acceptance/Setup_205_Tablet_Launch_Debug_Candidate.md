# Setup #205 tablet launch-debug candidate

| Document control | Value |
|---|---|
| Status | CANDIDATE — disposable/browser/operator acceptance pending |
| Reviewed | 2026-10-05 |
| Owner | #205, commanding #122 |
| Branch | `fix/205-tablet-launch-debug` |
| Release | `V0.3.39-tablet-launch-debug` |
| Base main | `bb45a9cea4205d7382745ab550a6f73d1cc771db` |
| Database migrations | None |

## Corrections

- **DBG-2026-001:** COMPLETE SETUP wording; passive wrapping text countdowns without card borders/backgrounds, beneath Perform Work heading. Shared Scheduling countdown presentation uses the same passive renderer. Milestone date derivation is preserved.
- **DBG-2026-002:** At <=1100 CSS pixels, open on Scheduling Board and expose sticky Scheduling Board / Find Tasks navigation. Only the chosen panel is shown; ordinary page scrolling exposes all controls. The large shared header scrolls away in Scheduling. Desktop retains both independent scrolling panes. Existing Schedule… / Move… dialogs remain the touch scheduling path; existing authorization and historical-work protections remain unchanged. Historical Catalog review stays finder-only.
- **DBG-2026-003:** Always-visible In Progress checkbox, outside More filters. It isolates annual execution_status IN_PROGRESS, including already-scheduled continuations. Explicit Stage/Scene/search/time/crew/effort and blocking/readiness filters still apply. Unchecking restores existing status filtering. Finder capture/restore preserves the checkbox.

No current active PR is a safe carrier: #291 contains separate empty-day database work and is behind main; #271 contains historical readiness migration/layout work already accepted elsewhere. This bounded source-only slice needs one draft PR covering all three DBG entries, rather than three PRs.

## Local verification

- Full Setup/Application regression: 677 passed.
- Changed JavaScript syntax and git diff whitespace checks: PASS.
- Direct execution of candidate JavaScript with synthetic task/control state: PASS for unfinished 90%-case population, scheduled continuations, blockers ON/OFF, task-name search, restoring normal filter population, panel selection, and 2026 milestone dates (Nov 19/21/27).
- Browser/viewport acceptance: NOT RUN. Workspace Chromium absent; automated browser download returned invalid/truncated archive. These results do not establish tablet layout/touch acceptance.
- Current-Production disposable acceptance: NOT RUN here. This workspace is separate from Greg's Windows checkout and has no established private server access.
- Production: untouched; no merge/deployment/server or database mutation performed.

## Disposable review

Use existing `run_setup_disposable_acceptance.ps1`, followed only on PASS/CLEAN EXIT by `run_setup_disposable_browser_preview.ps1`. Pin the exact candidate SHA from this draft PR; TargetRef is the branch above. MigrationPaths/ValidationPaths remain empty. ExpectedVersion is the release above. AllowConcurrentProductionWrites is supported for launch operation and read-only before/after evidence; no maintenance window is required for preview.

Runtime authorities read in this workstream: Server Management `docs/server/Pre_Production_Browser_Review_Runbook.md` and `docs/server/PostgreSQL_Disposable_Acceptance_Standard.md`.

Operator checklist:

1. Confirm Client V0.3.39, matching server version, footer Updated 2026-10-05, and disposable-clone banner.
2. Perform Work: COMPLETE SETUP/launch countdowns are passive, compact, readable, wrapping at portrait width, and leave work controls accessible.
3. Schedule at 900x600, 1024x768, portrait 768x1024 and the actual tablet: board is initially visible; switch Find Tasks <-> Scheduling Board by touch; page scroll reaches lower days/crews; AM/PM horizontal scrolling works without page-wide horizontal overflow; expanded Add Work Days and dialogs remain usable.
4. In collapsed filters, select In Progress; locate an actual unfinished task (90% example), inspect existing historical assignment, and schedule a later continuation through Schedule… in the clone. Confirm historical assignment is retained; find/move/remove only an unworked future assignment through existing Move… controls. Refresh and verify clone state.
5. Include a task with an already scheduled continuation in the In Progress result. Toggle blockers/search; uncheck In Progress and verify normal finder behavior.
6. Desktop 1280px/wide: both panels and independent scrolling remain usable. Historical review remains finder-only. Print retains board/cover-sheet behavior.
7. Finish preview with ENTER and retain CLEAN EXIT plus Production-after checks. Record exact SHA, preview port/operator, observations, and any outstanding actual-tablet acceptance.

The current launcher forwards only localhost on the PC. PC viewport review can proceed first; it does not provide actual-tablet reachability. Do not infer an actual-tablet PASS from PC review, and do not expose this authenticated preview publicly to bypass that limitation.
