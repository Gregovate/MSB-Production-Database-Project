# Issue Management and Closeout Rule

| Document Control | Value |
|---|---|
| Document Type | Project Rule |
| Repository | MSB Production Database Project |
| Status | CURRENT |
| Owner | Production project owner / administrator |
| Last Reviewed | 2026-09-12 |

## Purpose

This rule defines how GitHub issues are used and closed in the MSB Production Database Project so the issue list remains a useful record of real remaining work rather than an accumulating history of every discussion point.

Issues are durable work items. They are not a substitute for controlled repository documentation.

## Primary Operator Intent — Preserve Findings Without Fragmenting Work

A common reason Greg asks to "put that in the issue", "add that to the issue", or "make sure there is an issue for that" during an engineering conversation is to make sure an important finding does **not get lost in chat history**.

Unless Greg explicitly asks for a **new/separate issue**, the default interpretation is:

1. identify the existing active issue that already owns the workstream/problem;
2. record the finding, correction, decision, edge case, requirement, or follow-up on that issue as a comment or scope/checklist update;
3. update the responsible controlled documentation when the finding establishes durable project knowledge; and
4. create a new issue only when the new work passes the independent-work test below.

Do **not** interpret the importance of a finding as a reason to create another issue. An important finding may still belong entirely inside an existing issue.

If the owning issue is not obvious, search the current issue set before creating anything new. Prefer attaching the finding to the issue that owns the underlying problem over creating a convenience issue whose only purpose is to preserve the conversation.

## Independent-Work Test for a New Issue

Create a separate issue only when the work can reasonably be **scheduled, implemented, accepted, deferred, and closed independently** from the current owning issue.

A useful test is:

> Could this work be completed and closed on its own without falsely implying that the parent/owning problem is solved, and does it need its own acceptance/closeout evidence?

If the answer is **no**, keep the finding inside the existing owning issue.

Examples of genuinely independent work include:

- a separate application retirement;
- a database compatibility migration;
- a distinct subsystem documentation conversion;
- a production defect requiring its own validation and acceptance; or
- future engineering work that should remain visible after the current project closes.

Do not create a new issue merely because a useful thought, discovery, correction, requirement, edge case, or small follow-up occurred during a conversation. When the item belongs to an existing active issue, add it to that issue's scope, checklist, or comments as appropriate.

## Findings, Issues, Pull Requests, and Documentation Are Different Things

Use these project artifacts for different purposes:

```text
conversation finding / correction / decision
    -> existing owning issue comment or scope update

independently schedulable workstream/problem
    -> GitHub issue

implementation slice that can be reviewed/tested/merged
    -> pull request

accepted durable architecture / operating rule / system fact
    -> controlled repository documentation
```

One issue may legitimately be implemented through several pull requests. Do not create child issues merely to make each implementation slice smaller. Use separate PRs under the same issue when the work is independently reviewable/testable but still belongs to the same durable problem/workstream.

Likewise, several related findings may accumulate under one issue without requiring additional issues. The issue is the durable container for the workstream; comments preserve the discoveries that refine it.

## Issues Do Not Replace Documentation

A GitHub issue records work to be done and its completion state. It does not become the authoritative location for architecture, operating rules, procedures, current production facts, naming rules, or other durable project knowledge.

When work or discussion establishes information that belongs in controlled documentation, follow the Documentation Maintenance Rule and update the responsible repository document during the work.

A comment on an issue may preserve context for the work item, but it is not a substitute for updating the controlled document that owns the rule or system fact.

## Keep Related Work Together

Prefer one active issue for one coherent piece of work.

Use an umbrella issue when a larger project contains several independently completable work items. Create child/separate issues only when those items truly need independent scheduling, acceptance, or closeout.

Do not split one normal engineering task into many small issues solely to record every finding.

When a finding materially affects more than one existing issue, choose the **primary owning issue** for the full finding and cross-reference the other issue only when that issue's scope/acceptance is genuinely affected. Avoid duplicating the same long discussion into several issues.

## Closeout Is Part of the Work

An issue is not finished merely because the code, documentation, or deployment change was made.

Before leaving a completed work item:

1. review the issue's acceptance criteria and current comments;
2. confirm the responsible controlled documentation has been updated for durable discoveries or decisions;
3. identify the pull request(s), merge commit(s), deployment acceptance, or other evidence that completed the work;
4. record any deliberately deferred item and create a separate issue only when it is truly independent future work;
5. close duplicate, superseded, completed, or no-longer-planned issues using the appropriate GitHub close reason; and
6. leave an issue open only when real work remains, with a clear next step or unresolved acceptance item.

The goal is that the open-issue list represents actual remaining work.

## Sub-project Closeout Review

Before a project or sub-project is considered complete, review the GitHub issues associated with that work.

Each related issue must be in one of these states:

- **Closed — completed:** its acceptance criteria are satisfied and the durable repository documentation is current.
- **Closed — duplicate/not planned:** the issue is no longer an independent work item and the reason is recorded.
- **Open — real work remains:** the remaining scope and next step are explicit.

Do not leave completed issues open merely because issue cleanup was deferred to a later conversation.

## Relationship to Documentation Closeout

Issue closeout and documentation closeout are separate requirements that support each other:

```text
engineering discovery / decision
    -> preserve on the owning issue while work is active
    -> update responsible controlled documentation when it becomes durable project knowledge

work item completed
    -> record acceptance/evidence
    -> close or deliberately retain the GitHub issue
```

Neither step replaces the other.

## Related Standards and Rules

- [Documentation Maintenance Rule](../Standards/Documentation_Maintenance_Rule.md)
- [Repository Change Workflow](Repository_Change_Workflow.md)
- [Documentation Subsystem Conversion Tracker](Documentation_Subsystem_Conversion_Tracker.md)
