# Project Rules

This folder contains documentation and governance rules that are specific to the MSB Production Database Project.

When Greg says **read the project instructions**, read this README and every linked rule relevant to the requested work before proposing changes.

When Greg says **put/add this in the issue**, **make sure this is in an issue**, or similar language during an engineering discussion, do **not** assume that means creating a new GitHub issue. Follow the [Issue Management and Closeout Rule](Issue_Management_and_Closeout_Rule.md): find the existing owning issue first and preserve the finding there unless Greg explicitly asks for a new/separate issue or the work is genuinely independently schedulable/acceptable/closable.

## Mandatory Production Gate

**Production mutation commands are forbidden until the governing runbook has been retrieved from the responsible repository and read in the current workstream.**

For any Production deployment, server/service/configuration change, database migration, recovery action, or other Production mutation, the [Runbook-First Production Rule](Runbook_First_Production_Rule.md) is always relevant and mandatory.

Reusable rules that should apply across multiple repositories belong under [`../Standards/`](../Standards/README.md). Project-specific rules belong here so other MSB repositories do not inherit Production Database assumptions merely because they use the same documentation framework.

## Current Project Rules

- [Runbook-First Production Rule](Runbook_First_Production_Rule.md) — requires retrieving and reading the governing repository-owned runbook before any Production mutation command, stating the authority/procedure/current step, stopping after failures, and declaring `RUNBOOK GAP FOUND` rather than improvising when documentation is incomplete.
- [Repository Change Workflow](Repository_Change_Workflow.md) — requires refreshing current remote `main`, reviewing the latest affected files, and resolving stale-branch/concurrent-work issues before changing code, schema, configuration, or controlled documentation.
- [Issue Management and Closeout Rule](Issue_Management_and_Closeout_Rule.md) — defines the conversation-finding -> owning-issue default, when a separate GitHub issue is actually warranted, how multiple PRs may implement one issue, requires durable discoveries to be promoted into controlled documentation rather than left only in issues/chat, and makes issue review/closure part of project and sub-project closeout.
- [Internal Web Analytics Rule](Internal_Web_Analytics_Rule.md) — requires GA4 usage analytics for `my.sheboyganlights.org` applications, defines the shared Measurement ID and privacy boundary, preserves per-project ownership, and makes analytics verification part of production acceptance.
- [Production Operational Documentation Rule](Operational_Documentation_Rule.md) — defines Production-specific SOP ownership, `my.sheboyganlights.org` discovery, Display Folder procedure boundaries, and the rule that the existing central SOP tree is not the mandatory home for every operator procedure.
- [Stage Setup Documentation Standard](Stage_Setup_Documentation_Standard.md) — governs how Stage/Scene setup instructions relate to the established Google Shared Drive structure, controlled templates, Production Database identity, QR resolution, and the `my.sheboyganlights.org` presentation layer.

## Rule Ownership

Use this folder for rules that are durable across Production Database subsystems but are not appropriate as reusable cross-repository standards.

Subsystem implementation details still belong in the responsible engineering documentation rather than here.
