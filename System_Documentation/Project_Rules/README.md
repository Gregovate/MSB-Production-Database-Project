# Project Rules

This folder contains documentation and governance rules that are specific to the MSB Production Database Project.

Reusable rules that should apply across multiple repositories belong under [`../Standards/`](../Standards/README.md). Project-specific rules belong here so other MSB repositories do not inherit Production Database assumptions merely because they use the same documentation framework.

## Current Project Rules

- [Repository Change Workflow](Repository_Change_Workflow.md) — requires refreshing current remote `main`, reviewing the latest affected files, and resolving stale-branch/concurrent-work issues before changing code, schema, configuration, or controlled documentation.
- [Production Operational Documentation Rule](Operational_Documentation_Rule.md) — defines Production-specific SOP ownership, `my.sheboyganlights.org` discovery, Display Folder procedure boundaries, and the rule that the existing central SOP tree is not the mandatory home for every operator procedure.
- [Stage Setup Documentation Standard](Stage_Setup_Documentation_Standard.md) — governs how Stage/Scene setup instructions relate to the established Google Shared Drive structure, controlled templates, Production Database identity, QR resolution, and the `my.sheboyganlights.org` presentation layer.

## Rule Ownership

Use this folder for rules that are durable across Production Database subsystems but are not appropriate as reusable cross-repository standards.

Subsystem implementation details still belong in the responsible engineering documentation rather than here.
