# Repository Change Workflow

## Purpose

This project rule defines the minimum repository-synchronization steps that must occur before making changes in the MSB Production Database repository.

The project is worked on across multiple active branches, sub-projects, and conversation threads. A branch that was current when one task started may be stale by the time another task resumes.

## Step Zero — Refresh Before Editing

Before changing code, schema, configuration, or controlled documentation:

1. refresh the repository view from the current remote;
2. identify the current `main` head;
3. verify whether the intended working branch is current with `main`;
4. inspect the latest versions of the files that will be changed; and
5. if the existing working branch is materially behind current `main`, rebase/merge deliberately or start a fresh branch from current `main` before editing.

Do not assume that repository state remembered from an earlier conversation is still current.

For connector/API-based work where a local `git pull` is not available, creating the work branch directly from current remote `main` and reading the current remote files satisfies the refresh requirement.

## Mandatory Feature-Worktree VS Code Identity

**Before the first edit or test on a newly prepared feature branch/worktree, provide a dedicated VS Code window for that exact Git worktree.** This is part of feature-branch setup, not a cosmetic afterthought. Parallel #171 GIS, #88 Container and #419 Work Orders windows must be unambiguously distinguishable while remaining open at the same time.

Use the existing shared cross-subsystem utility [`Utilities/Open-MSBFeatureWorkspace.ps1`](../../Utilities/Open-MSBFeatureWorkspace.ps1). It opens a VS Code `.code-workspace` with:
- an explicit **verified Git root**, **feature branch**, and issue number/workstream in the folder name and title bar;
- a stable issue-specific accent (automatic color mapping or a deliberate caller selection; e.g. #171 teal, #88 yellow, #419 blue);
- the high-contrast **Default Dark Modern** palette with a dark terminal/editor, readable white text, **14-pixel terminal and editor fonts**, and **zoom 0**; no all-white editor with faint console text or oversized workspace-wide font;
- a separate workspace file under the user's Windows `%LOCALAPPDATA%\MSB-VSCode-Workspaces\`, **outside every Git checkout**, named uniquely for the issue, workstream, and worktree path;
- no change to tracked repository `.vscode/settings.json`, the tracked repository `*.code-workspace`, Git worktrees/branches, other VS Code windows, or Production services.

Example from the laptop **after creating or confirming the desired feature worktree and refreshing the primary checkout**:

```powershell
& 'C:\lor\ImportExport\VSCode\Utilities\Open-MSBFeatureWorkspace.ps1' `
    -WorktreePath 'C:\lor\ImportExport\MSB-WorkOrders-419' `
    -IssueNumber 419 -Label 'WORK ORDERS'
```

The utility validates the exact worktree root and a non-`main` checked-out branch. **Never pass a leftover `$Worktree` variable from another feature** or open `code --new-window` against an inferred folder. The script may warn if the checkout is dirty, but must not clean, reset, stash, stage, switch branches, or modify existing local changes. Git cleanliness for acceptance/deployment remains an independent strict gate.

**Tracked editor-setting trap (observed #419 October 19):** `.gitignore` contains `.vscode/`, but `.vscode/settings.json` was already tracked in that feature checkout, so changing it made the worktree dirty and blocked the approved disposable browser launcher. **An ignore rule cannot make an already tracked file untracked.** Keep personalized window/title/color/font settings in the external feature workspace, not in the repository. If an existing tracked configuration was edited, first inspect `git status --short` / `git diff` and back it up; restore that exact tracked file only with explicit approval, never broad `git reset --hard`, blanket clean, or forced worktree removal.

**Required handoff check:** in the new colored window, verify its Explorer root, `git branch --show-current`, `git rev-parse --show-toplevel`, `git status --short`, and intended exact candidate SHA. The workspace should remain available until its owning feature/PR and local worktree are safely closed out. Local workspace appearance setup is **not** a substitute for the governed disposable browser tunnel, database/port isolation, branch clean gate, Production release approval or Server Management runbooks.

## Greg's Workstation and Checkout Context

Confirmed by Greg on 2026-10-05. Greg actively switches between machines; use the latest pasted PowerShell prompt as the working-location indicator. Do not assume the machine or checkout stayed the same between messages.

| Machine | Primary repository checkout / prompt path |
|---|---|
| Desktop | `C:\Users\Greg\Github\MSB-Production-Database-Project` |
| Laptop | `C:\lor\ImportExport\VSCode` |
| Park workstation | Pending: Greg will provide the path when park WiFi is operational. Do not invent a location. |

A prompt ending in `MSB-Production-Database-Project-81-vcheck` identifies a separate worktree observed on the desktop; it is not the primary checkout above. The suffix alone does not establish its current purpose, branch, or whether it can be removed. Check those before cleanup.

### Required Command Handoff and Cleanup

- Give commands for the machine and checkout shown in the latest prompt. Include an explicit `Set-Location` when returning from a preview worktree to the primary checkout.
- Refresh remote `main` before preparing changes and refresh the operator's primary `main` checkout before running merged release tooling. Use fast-forward-only pulls; do not assume `pull.ff=only` is configured on every PC.
- Inspect branch/worktree state before recommending `git switch main`. When main is already checked out in another worktree, use that existing checkout rather than forcing a second checkout or resetting branches.
- Provide the complete sequence: prepare isolated change, test, obtain Production approval, merge, deploy under the governing runbook, close out documentation, clean up this task's disposable work, and return the operator to updated primary `main`.
- Include concrete cleanup commands in the handoff. Check ownership, branch, clean status, and merged history before removing a worktree or local branch. Preserve unrelated worktrees and uncommitted work. Do not use forced removal/reset to bypass a failure.
- Commands must stop on failure. If a switch or pull fails, subsequent deployment must not run; do not provide a multiline sequence that silently continues after a native Git failure.
- Never confuse reusable preview CLEAN EXIT (server disposable cleanup) with local Git worktree cleanup; both have their own disposition.

Greg coordinates several concurrent workstreams during launch. Correct checkout selection, complete command sequences, and cleanup are the assistant's responsibility rather than work Greg should have to reconstruct from chat.

## Concurrent Project Work

When another sub-project has changed the same area since the current branch was created:

- review the newer work before applying older planned changes;
- preserve accepted newer architecture and operator behavior;
- do not overwrite newer documentation merely because an older branch already contains a draft rewrite;
- reconcile conflicts against the current repository authority, not conversation memory; and
- record any newly discovered cross-system conflict in the responsible engineering documentation.

## Documentation Work

Documentation changes are subject to the same synchronization rule as code.

Before rewriting an operator procedure or engineering document:

1. read the current repository version;
2. read the current engineering authority and related subsystem README when the subject crosses system boundaries;
3. preserve newer accepted decisions from parallel work;
4. update the operator document only after the underlying current behavior is understood; and
5. perform the normal README/documentation closeout after the change.

## Why This Rule Exists

The repository is the durable project record. Parallel development is expected.

Refreshing first prevents:

- overwriting newer work;
- documenting obsolete behavior;
- rebuilding decisions already settled in another thread;
- creating conflicting operator and engineering instructions; and
- wasting time reconciling changes after they have already been written against a stale base.

## Simple Rule

> **Before changing the repository, refresh current `main` and read the latest affected files. Do not edit from remembered repository state.**

## Related Standards

- [Documentation Standards](../Standards/Documentation_Standards.md)
- [README Portal Standard](../Standards/README_Portal_Standard.md)
- [Document Control Standard](../Standards/Document_Control_Standard.md)

## Engineering authority and automated compliance boundary

The governing hierarchy is: (1) Project rules and documentation standards,
(2) owning subsystem engineering design, (3) issues for unfinished work,
(4) pull requests for implementation/regression/controlled integration, and
(5) chat for working discussion only. A PR must conform to the existing design;
a PR comment or issue comment does not replace an owning controlled document.
Read existing design, update owning decisions, implement within the existing PR,
protect with regression, validate against the design, obtain operator browser
acceptance where applicable, then merge under established rules.

The GitHub **Engineering Compliance** job performs limited deterministic checks
of PR evidence and documentation changes, plus applicable application regression.
It is not an automated engineering architect or a substitute for authorizing
exceptions, verifying design quality, reading external Server Management
runbooks, assessing acceptance, or granting Production mutation permission.
Evidence in a PR description must be truthful and link to the actual owning
design. A mandatory green check is necessary but not sufficient for merge.

A PR touching controlled acceptance runners, deployment procedures, workflows
or project standards must explain **Infrastructure reuse / exception** and
identify the established mechanism reused. If a new mechanism is proposed, the
responsible controlled engineering/runbook document must authorize and specify
it before implementation; entering text in a PR field is not approval.

For applicable engineering PRs include these named evidence fields in the PR
description: **Design authority**, **Implementation scope**, **Regression
evidence**, **Acceptance status**, and **Runbook / existing mechanism**.
Protected tooling changes also include **Infrastructure reuse / exception**.
The checker cannot prove chronology; reviewers must verify the recorded
design-first sequence from source and PR history.

Protected GitHub settings remain administrator-controlled. The new job must
run and pass on a PR before being selected as required in the existing active
**Protect Main** ruleset. Existing protections must not be weakened. Do not
claim enforcement active merely because the workflow exists on a branch.
