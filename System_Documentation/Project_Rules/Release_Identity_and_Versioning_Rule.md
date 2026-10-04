# Release Identity and Versioning Rule

| Document Control | Value |
|---|---|
| Document Type | Project Rule |
| Repository | MSB Production Database Project |
| Status | CURRENT |
| Owner | Production project owner / administrator |
| Last Reviewed | 2026-10-04 |

## Purpose

This rule makes Production release identity explicit and mechanically traceable.

MSB frequently has several accepted branches, migrations, issues, and deployment candidates active at the same time. A visible application version must therefore identify a materially distinct Production release rather than being reused across unrelated accepted behavior.

The exact Git commit SHA remains the authoritative implementation identity. The visible version is the human-facing release identity that lets an operator quickly tell which generation of the application is running.

## Mandatory Rule

> **A materially distinct Production release candidate must have a distinct visible application version before final exact-candidate acceptance and Production deployment.**

Do not reuse the same visible version for two materially different Production release candidates.

A release is materially distinct when it changes operator-visible behavior, business rules/workflow semantics, database schema or required migration, persisted operational state/commands, security/authentication, consumed API behavior, launch-critical scanner/device interaction, or another accepted capability that an operator or maintainer must distinguish in Production.

Example:

    V0.3.21-scheduling-gates
        = #205 Scheduling Board / Work-vs-Gate / Captain dispatch release

    V0.3.22-pick-list-delay
        = #206 bounded material frontier / Pick Delay release

Those releases must not share one visible version merely because one was developed directly on top of the other.

## What Does Not Require a New Application Version

A new visible version is not required merely for documentation-only commits after the accepted application candidate, deployment/rollback tooling that does not change the application, repository-only merge/reconciliation commits, issue/PR comments, acceptance-record documentation, branch housekeeping, or presentation-only UI changes such as spacing, styling, layout, wording, or labels that do not change workflow meaning, persisted behavior, API behavior, or the meaning of an operator action.

A UI change **does** require a new release version when it changes workflow semantics, available actions, safety behavior, persisted state, or another operational capability rather than presentation alone.

Those commits may have different repository SHAs while still referring to the same deployed application SHA/version. Documentation must state that distinction explicitly.

## Visible UI Update Date

Every UI change, including presentation-only changes, must update the visible `Updated YYYY-MM-DD` date in the same candidate. For Setup this is the footer in `Setup/Application/production.html`. Update date-sensitive contracts and verify the footer in the served Production page during browser acceptance. Use the date of the UI change, not the current browser date; a refresh must not change it. A stale footer is a release-check failure even when the version badge is correct.

Presentation-only corrections may retain the application version under the rule above, but their accepted and deployed source SHAs must still be recorded. Never patch the live file outside merged repository history.

## Release Identity Tuple

Every accepted Production release must be tracked with:

    visible application version
    + exact accepted application SHA
    + migration number/path and blob SHA where applicable
    + owning issue(s)
    + implementation/integration PR
    + acceptance record
    + merged-main SHA
    + exact deployed Production SHA
    + reverse-chronological Production deployment change-log entry

Do not use the visible version alone as proof of deployed source. Do not use the Git SHA alone as the normal operator-facing release label. Both are required.

## Server and Client Identity

When an application has separate server and client build declarations, they must describe the same release identity.

For Setup this currently includes:

    Setup/Application/production_backend.py -> PRODUCTION_VERSION
    Setup/Application/setup_catalog_dirty_guard.js -> CLIENT_BUILD

The exact full build identity must stay synchronized. The user-visible badge may show a shortened form such as Client V0.3.22 while the full build identity remains V0.3.22-pick-list-delay.

A client/server version mismatch is a stop condition, not a warning to dismiss.

## When the Version Must Be Bumped

The version bump belongs inside the candidate before final acceptance:

    implementation behavior frozen
      -> choose next distinct release version
      -> update server/client identities together
      -> refresh required asset/cache pins
      -> update version-sensitive contract tests
      -> full regression
      -> disposable/current-Production acceptance
      -> browser/operator acceptance
      -> repository integration
      -> governed Production deployment

Do not complete broad acceptance on one visible version and then silently deploy materially different behavior under that same version.

## If a Missing Version Bump Is Found Late

If a materially distinct candidate has already passed acceptance while still carrying the prior release version:

1. record the defect on the owning issue/PR;
2. create a narrow release-identity correction candidate;
3. bump server/client identities together;
4. update only necessary asset/version pins and version-sensitive contracts;
5. because the exact candidate SHA changed, rerun the acceptance gates required by that subsystem;
6. keep the repeat bounded to release identity unless testing exposes a real behavioral defect.

For Setup, the normal bounded repeat is full Setup/Application regression, reusable disposable current-Production acceptance, short browser smoke proving server/client identity and the already-accepted surface, clean exit, then governed Production deployment.

Do not use a late version correction as an excuse to reopen accepted scope.

## Acceptance and Deployment Records

Before Production deployment, the owning issue/PR must state the proposed visible version, exact candidate SHA, migration(s), acceptance status, and intended Production deployment boundary.

After deployment, the acceptance/closeout record must state the visible Production version, exact deployed SHA, migration(s) actually installed, PR/merge SHA, and Production verification evidence.

If the deployed application SHA differs from a later documentation/tooling closeout SHA, record both. Never imply the documentation/tooling SHA is the deployed application merely because it is newer.

## Mandatory Production Deployment Change Log

The repository-wide reverse-chronological deployment history is:

`System_Documentation/Production_Deployment_Change_Log.md`

Every Production deployment covered by this repository must add or update the newest entry in that log as part of deployment closeout.

The entry must record the deployment date, subsystem/application, visible version when applicable, concise operator-visible or operational changes, exact deployed SHA, merged-main SHA when different, migration identity when applicable, owning issue(s), PR(s), acceptance result, and rollback/report evidence when generated.

The change log is a navigation and operational-history record. It does not replace the detailed acceptance record, issue, PR, migration, rollback evidence, or Git history.

A Production deployment is not documentation-closeout complete until the change-log entry exists in the repository. Do not leave the only record of what changed in chat, an issue comment, a deployment transcript, or an acceptance file.

Keep the log reverse chronological: newest Production deployment first. Do not silently rewrite historical entries to match current architecture; append/correct with traceable evidence.

## Issue and PR Discipline

For application work that can reach Production, the owning engineering issue and implementation/integration PR must carry the release identity requirement before closeout.

At minimum, acceptance/closeout must answer:

    What visible version will this release use?
    What exact SHA was accepted?
    What migration(s) belong to it?
    What PR/merge contains it?
    What exact SHA/version is actually live?

If those answers are missing or ambiguous, release closeout is incomplete.

The owning work must also prove that the Production deployment change log has been updated for the deployed release.

## Relationship to Repository Closeout

Version identity does not replace repository closeout. A release is not fully closed until Production identity is proven and accepted repository history is integrated and proven.

Follow the [Repository Change Workflow](Repository_Change_Workflow.md) and [Issue Management and Closeout Rule](Issue_Management_and_Closeout_Rule.md) for the repository half of that proof.

## Simple Rule

> **New Production behavior gets a new visible release version. Exact SHA proves precisely what it is. Record both, and add the Production deployment to the reverse-chronological change log.**

## Related Rules

- [Repository Change Workflow](Repository_Change_Workflow.md)
- [Issue Management and Closeout Rule](Issue_Management_and_Closeout_Rule.md)
- [Runbook-First Production Rule](Runbook_First_Production_Rule.md)
