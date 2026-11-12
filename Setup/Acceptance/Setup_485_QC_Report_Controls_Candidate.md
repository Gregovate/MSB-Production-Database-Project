# QC report and control visibility follow-up

Status: CANDIDATE — not deployed. Owner: Setup engineering under #122/#205.
Last reviewed: 2026-11-12. Design authority: current QC Scheduling Board Contract,
November12 controls/report section. V0.3.122-qc-report follows installed V0.3.121.

Production operator confirmed problem entry PASS; button distinction and retained
history/report access need correction. Use existing full-season authorized snapshot
and print/Save as PDF convention. No schema changes or installed081 replay.

## Disposable browser acceptance

Use `run_485_qc_report_browser_review.ps1` with exact SHA and the actual local
main checkout. It reuses existing Server Management8898 preview and current
Production clone. No migrations or Production writes; no Node dependency.

1. Confirm selected Perform Work and QC mode clearly highlighted in both themes.
2. Confirm amber repair claim/completion and purple auditor claim; labels readable.
3. Report, claim, repair and final-signoff a disposable finding; verify normal flow.
4. Open QC report/PDF from QC Check and QC Repairs Needed. Default includes all
   findings, including verified and completed-area history. Check full descriptions,
   reporter, claimant, repair/event notes, assigned auditors, actual final signer
   and Chicago timestamps. Outstanding-only excludes completed findings.
5. Confirm multiple findings in the same area share one Stage/Scene header,
   auditor list and final sign-off; each finding retains its own full history.
   Print/Save PDF; check long notes, multiple pages, repeated column headers,
   readable text and no clipped evidence. Report generation never changes status.
6. Expand completed area: final signer and read-only finding history remain visible.
7. Scheduled Work remains usable. Finish CLEAN EXIT. Release approval remains separate.

Local application regression: 1023 passed,3 skipped. Focused report/API14 passed.
Local Chromium could not start due environment socket restriction; hosted browser
regression is required, not claimed from local tests. No Production deployment.

## Assignment/search follow-up acceptance

Operator returned CLEAN EXIT for the prior preview; this is cleanup evidence, not acceptance of the new filters. No migrations are required or permitted by this source-only launcher.

- Sign in as Crew with assigned repairs: My Repairs defaults selected; another person with the same display name must not match. Unclaimed excludes assigned repairs; All Repairs shows all outstanding records. Repaired/awaiting-signoff findings remain under their owner until area sign-off.
- Search multiple words, Stage/Scene, QC task number, finding number (with or without #), reporter, repair owner and observation/repair notes. Combine with each ownership filter. Check no-result messages and counts.
- Type a repair note, switch filters and search, then return: draft remains. After claim, item leaves Unclaimed and appears in My Repairs. Filters/search persist across mode changes and saves.
- QC Check defaults All Areas; My QC Areas matches exact auditor identity. Search finds finding/history text even before opening an area. Completed history and full report remain accessible.
- Confirm large selected/filter buttons and focus in light/dark modes, Scheduled Work unchanged, no writes from search/filter/report. Finish CLEAN EXIT.
