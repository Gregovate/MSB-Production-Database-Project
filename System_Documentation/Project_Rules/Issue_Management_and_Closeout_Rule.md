# Issue Management and Closeout Rule

| Document Control | Value |
|---|---|
| Document Type | Project Rule |
| Repository | MSB Production Database Project |
| Status | CURRENT |
| Owner | Production project owner / administrator |
| Last Reviewed | 2026-08-24 |

## Purpose

This rule defines how GitHub issues are used and closed in the MSB Production Database Project so the issue list remains a useful record of real remaining work rather than an accumulating history of every discussion point.

Issues are durable work items. They are not a substitute for controlled repository documentation.

## When to Create an Issue

Create a separate issue when the work can reasonably be scheduled, implemented, accepted, deferred, or closed independently from the current work item.

Examples include:

- a separate application retirement;
- a database compatibility migration;
- a distinct subsystem documentation conversion;
- a production defect requiring its own validation and acceptance; or
- future engineering work that should remain visible after the current project closes.

Do not create a new issue merely because a useful thought, discovery, or small follow-up occurred during a conversation. When the item belongs to an existing active issue, add it to that issue's scope, checklist, or comments as appropriate.

## Issues Do Not Replace Documentation

A GitHub issue records work to be done and its completion state. It does not become the authoritative location for architecture, operating rules, procedures, current production facts, naming rules, or other durable project knowledge.

When work or discussion establishes information that belongs in controlled documentation, follow the Documentation Maintenance Rule and update the responsible repository document during the work.

A comment on an issue may preserve context for the work item, but it is not a substitute for updating the controlled document that owns the rule or system fact.

## Keep Related Work Together

Prefer one active issue for one coherent piece of work.

Use an umbrella issue when a larger project contains several independently completable work items. Create child/separate issues only when those items truly need independent scheduling, acceptance, or closeout.

Do not split one normal engineering task into many small issues solely to record every finding.

## Closeout Is Part of the Work

An issue is not finished merely because the code, documentation, or deployment change was made.

Before leaving a completed work item:

1. review the issue's acceptance criteria and current comments;
2. confirm the responsible controlled documentation has been updated for durable discoveries or decisions;
3. identify the pull request, merge commit, deployment acceptance, or other evidence that completed the work;
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
    -> update responsible controlled documentation

work item completed
    -> record acceptance/evidence
    -> close or deliberately retain the GitHub issue
```

Neither step replaces the other.

## Related Standards and Rules

- [Documentation Maintenance Rule](../Standards/Documentation_Maintenance_Rule.md)
- [Repository Change Workflow](Repository_Change_Workflow.md)
- [Documentation Subsystem Conversion Tracker](Documentation_Subsystem_Conversion_Tracker.md)
