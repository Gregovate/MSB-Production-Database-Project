# Setup #122 — 2026 Scheduling Board / Annual Session Production Acceptance — 2026-09-25

| Document Control | Value |
|---|---|
| Document Type | Production Acceptance Record |
| System | Production Database — Setup Session |
| Status | ACCEPTED / LIVE |
| Owner | MSB Production Database engineering |
| Commanding Issue | #122 |

## Accepted Production State

The 2026 Scheduling Board launch is complete and the real 2026 Setup Session has been created. The 2026 Session is now the active annual planning/execution context. The 2025 Session remains historical/verification evidence and is not the current schedule.

Accepted Scheduling Board application target:

```text
06a6536d92db5c7352beeed496563ed9bfdb7146
health version: V0.3.17-performance-trace
```

The launch deployment installed the accepted application plus:

```text
057_enable_2026_unworked_task_deletion.sql
058_preserve_catalog_review_on_annual_launch.sql
```

The repository launch/deployment contract is carried by `run_setup_122_2026_launch_unblock_production_deploy.ps1` and its server runner.

## Acceptance Evidence

The exact Scheduling Board UI candidate passed the complete Setup/Application regression:

```text
458 passed
```

It then passed disposable current-Production browser review before Production launch. Browser findings were corrected before acceptance, including keeping the Work Day calendar collapsed when idle, making **+ Add Work Days** visually obvious, and starting secondary Task Finder filters compact.

The real 2026 annual Session was launched only after the accepted Scheduling Board deployment was live.

## Accepted Scheduling Behavior

Preserve the accepted Scheduling Board layout and current scheduling behavior, including:

- Catalog/Plan ordering behavior;
- lavender material-task cue in Needs Scheduling and scheduled assignments;
- Day-view filters;
- completed/cancelled-day presentation;
- performance improvements;
- compact-by-default secondary Task Finder filters;
- a collapsed-by-default, visually primary **+ Add Work Days** action;
- tablet-friendly date multi-select by click/tap without Ctrl/Shift;
- existing Work Days disabled in the date picker;
- selected dates submitted together without overwriting existing Work Days; and
- annual history preserved rather than introducing broad Work Day deletion.

## Ownership Boundary

This acceptance does not redesign #206 Pick List/material demand. #206 / PR #216 owns early physical material-demand expansion and physical Pick List resolution. The rejected browser-side downstream-material lookahead is not part of the accepted Scheduling Board.

Reusable Catalog knowledge remains separate from 2026 annual/season-only planning. Annual execution may inform future reusable changes, but reusable knowledge changes remain explicit governed decisions.

## Closeout

The scheduler launch blocker is closed. Future Setup engineering should treat the live 2026 Session and the accepted Scheduling Board behavior above as the current baseline rather than reconstructing the pre-launch state from chat or historical issues.
