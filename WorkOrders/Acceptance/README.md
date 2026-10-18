# Work Management #419 — disposable clone and browser review

**Status: SOURCE-ONLY; not started or browser accepted.** Work Management is the existing MSB Database Work Orders subsystem.

## Authorities

- [Work Orders design](../../Docs/02_Production_Database/01_System_Architecture/06_Work_Orders/Work_Order_System_Design.md) governs identities, Stage Related Information, and P0 acceptance.
- [Server Management PostgreSQL Disposable Acceptance Standard](https://github.com/Gregovate/MSB-Server-Management/blob/main/docs/server/PostgreSQL_Disposable_Acceptance_Standard.md) controls clone isolation.
- [Server Management Pre-Production Browser Review Runbook](https://github.com/Gregovate/MSB-Server-Management/blob/main/docs/server/Pre_Production_Browser_Review_Runbook.md) controls temporary listener, SSH, runtime, reviewer identity and cleanup.
- [Application and Test Port Register](https://github.com/Gregovate/MSB-Server-Management/blob/main/docs/server/Application_and_Test_Port_Register.md) owns port allocation. [Draft Server Management PR #80](https://github.com/Gregovate/MSB-Server-Management/pull/80) proposes explicit #419 **sequential reuse of existing 8898**. It is **not yet an approved allocation**. No Setup or #395 review may be stopped to free that listener without its own governed recovery.

## Feature-owned disposable profile files

| Existing #419 candidate file | Responsibility |
| --- | --- |
| run_work_management_disposable_browser_preview.ps1 | Windows SHA, branch, reviewer, port, local-listener and byte-digest checks, foreground SSH tunnel |
| work_management_disposable_browser_preview_server.sh | Server-side clone/port/identity/source/Flask readiness, clean-exit and fingerprint assertions |
| wo419_preview_clone_read_grants.sql | **Clone-only** PostgreSQL read grants; never apply to Production |
| validate_work_management_clone.py | Exact-SHA read checks for real current Work Orders and Setup Feedback |
| ../Application/preview_entry.py | Localhost Flask profile that injects only the runner-selected existing MSB reviewer |

The server runner follows the existing Standard: verify live services/listener, detached exact-SHA worktree, source regression, pg_dump from Production, isolated PostGIS Docker clone, read-only clone role, feature SQL validator, temporary localhost browser and controlled teardown. It never switches the live application checkout, creates Production records, emails volunteers, or alters Directus Flows. A distinct clone name is necessary but insufficient: validate private Docker network/container IP and no published clone DB port.

## Intended Windows operator invocation AFTER profile approval

From a clean local feature-branch MSB Database checkout, with the exact review commit checked out and the approved Person email:

PowerShell:

    $sha = (git rev-parse HEAD).Trim()
    .\WorkOrders\Acceptance\run_work_management_disposable_browser_preview.ps1 -CandidateSha $sha -PreviewPort 8898 -PreviewEmail 'approved.person@sheboyganlights.org' -ApprovedReviewProfile

Replace that sample reviewer with the **real explicitly approved existing person**. This is a **future command template, not authorization to run it while PR #80 is draft**. The wrapper refuses to start without the approved-profile switch, current branch/SHA match, clean checkout and free local listener. The remote runner must similarly prove the server listener unused and live services unchanged. Do not open the localhost URL until **WO419 BROWSER REVIEW READY** is printed.

At READY, review My Work, All, another assignee, Show completed, current Intake and WO examples, the **collapsed Related Information** section, Stage-level Kit/Container/Display/material resources and honest "Stage-related" vs "task-linked" labels. Browser interactions in this V0.1 are read-only.

Press ENTER in the SSH session when done, and require the exact **WO419 DISPOSABLE BROWSER REVIEW: CLEAN EXIT** report with unchanged Production fingerprints. If transport fails or a listener remains, stop and inspect recognized owner/state before retry; never kill unknown processes.

## Remaining acceptance gates

Run and correct Python source tests, revised WO419 PostgreSQL read model and clone audit before calling the first browser review READY. #419 P0 **atomic triage/Promote & Assign, alternate Setup corrections, original-reporter Request More Information/replies, final resolution emails and noncompeting Directus cutover are NOT implemented or accepted**. No temporary read-only preview can waive those future gates.

This README is the acceptance handoff. As authored, these scripts exist as source on draft PR #420, but the clone/browser has **not run on the server**, and Server Management port/profile PR #80 remains draft/unmerged.
