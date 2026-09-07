# Setup and Deployment — Internal Web Backbone Handoff

| Document Control | Value |
|---|---|
| Document Type | Internal Web Backbone Integration Handoff |
| Source System | Production Database — Setup and Deployment |
| Consuming System | `Gregovate/MSB-Internal-Web-Backbone` |
| Status | READY FOR IMPLEMENTATION — `/setup/` operational; UI/workflow in live evaluation |
| Owner | MSB Production Database / Setup documentation owner |
| Last Reviewed | 2026-09-07 |

## Purpose

Define what the Internal Web Backbone should expose for Setup and Deployment without copying engineering history into the operator experience or creating a competing documentation authority.

The source Setup subsystem remains authoritative. The Backbone should publish navigation/search/application entry points that lead users to the current controlled source or protected application.

## Current Source-System State

The Production Setup application is live and protected at:

```text
https://my.sheboyganlights.org/setup/
```

Accepted source-side checks include:

```text
Synology /setup/ route                = operational
public Setup health                   = PASS
Cloudflare-authenticated browser use  = PASS
2025 Production data rendering        = PASS
post-deployment invariants            = PASS
```

The **runtime is accepted**, but the Setup UI/workflow remains in live evaluation while Managers use the real 2025 Historical Verification session. Backbone navigation should therefore present the application as available for current 2025 review/training without implying that all Setup features are final.

## Canonical Operator Portal

Canonical source portal:

```text
Docs/02_Production_Database/01_System_Architecture/12_Setup_and_Deployment/README.md
```

Canonical operator procedure index:

```text
Docs/02_Production_Database/01_System_Architecture/12_Setup_and_Deployment/operatorSOP/README.md
```

Detailed Manager guide:

```text
Docs/02_Production_Database/02_Operational_SOPs/Setup/Setup_Session_Manager_Review_Guide.md
```

## Preferred Application Entry Point

Normal protected Setup action link:

```text
https://my.sheboyganlights.org/setup/
```

This is a `my.` action application and requires the established Google/Cloudflare Access perimeter.

Do not send ordinary users to repository application source, database migration files, server runbooks, old preview listeners, or obsolete hand-built Setup navigation pages.

## Obsolete Backbone Page

The former static Production Setup/Takedown page:

```text
my/committees/production/setup-takedown-testing/index.html
```

is obsolete.

Do not:

- update or revive its direct Google Doc list;
- link to it from current Production navigation;
- treat it as the current Setup portal; or
- make new Setup workflows depend on it.

The live Setup application and the current Procedure application replace the need for that hand-built page:

```text
https://my.sheboyganlights.org/setup/
https://my.sheboyganlights.org/procedures/
```

The obsolete static artifact may be removed later through the Backbone repository's controlled deployment/removal process. Its existence must not block current Production navigation work.

## Operator Tasks That Should Be Discoverable

Primary current task:

- **Review and Correct the 2025 Setup History** — Managers/reviewers use the real Production-backed 2025 Historical Verification session to verify annual history, add/correct reusable tasks and resources, improve reusable Setup knowledge, ask questions, and suggest workflow/UI improvements before the 2026 Setup Session is created.

Canonical source procedure:

```text
operatorSOP/Review_2025_Setup_History.md
```

Useful supporting action link:

- **Open Setup Application** — `https://my.sheboyganlights.org/setup/`

Future Setup task choices should be added only after the corresponding workflow is production-operational and documented in the source subsystem.

## Suggested Plain-Language Copy

Primary card/action title:

```text
Review 2025 Setup
```

Description:

> Review what happened during 2025 Setup, correct what you know, add missing reusable tasks or resources, and help improve the Setup workflow before the 2026 plan is created.

Secondary label/status when useful:

```text
Live review / training
```

Do not label the application as a prototype or as fully finalized. The accurate operator meaning is that it is live Production software currently being evaluated through real 2025 review work.

## Search / Discovery Metadata

Useful search terms:

```text
Setup
2025 Setup
Historical Verification
Setup training
review Setup history
add Setup task
Setup resources
verify Setup task
reusable Setup task
2026 Setup baseline
Setup plan
```

## Important Operator Meaning

Backbone presentation should preserve this distinction in plain language:

```text
2025 annual changes
    = corrections to 2025 history

Reusable Task changes
    = permanent Setup knowledge that may carry forward
```

The selected Setup Session controls the allowed operational year. The 2025 review area accepts 2025 operational dates only.

## Authorization / Link Boundary

The `/setup/` link may be visible as an internal action destination, but possession of the link does not grant application capability.

The protected application performs its own authenticated identity and authorization checks. Backbone must not recreate Setup Manager/Administrator authorization logic.

## Exclude from Normal Operator Navigation

Do not expose these as normal task choices or search destinations:

```text
engineering/
Setup/Acceptance/
Setup/Database/
Setup/Application/ source files
old disposable preview URLs/ports
historical dated engineering handoffs
PostgreSQL rollback archive paths
server systemd/nginx/UFW instructions
```

Engineering material may remain available through a clearly separated contributor/engineering path when appropriate, but it must not compete with operator navigation.

## Current Feature Boundary

Do not advertise the following as current operator workflows:

- Pick List generation; or
- Container/Display movement/scanning write commands.

Those remain outside the current accepted Production-ready boundary.

## Acceptance Criteria

Backbone integration is VERIFIED only when all applicable checks pass:

1. the Production index/task navigation includes an appropriate Setup action;
2. the action points to `https://my.sheboyganlights.org/setup/`;
3. the 2025 historical review purpose is understandable in plain language;
4. search/navigation can find Setup using ordinary task terms;
5. the obsolete static Setup/Takedown page is not linked or promoted;
6. engineering/acceptance/database source paths are absent from normal operator search/navigation;
7. no duplicate editable copy of the source operator procedure is created in Backbone;
8. maintained `index.html` pages preserve their required visible version indicators; and
9. deployed intranet verification confirms the intended Production page reaches the protected Setup application.

## Backbone State

```text
READY FOR IMPLEMENTATION
```

Source route/runtime acceptance is complete. Backbone issue `#10` may proceed using this handoff and the Backbone repository's own project rules/deployment procedure.

After source changes are made, use `IMPLEMENTED`. After deployed intranet verification, use `VERIFIED` and record the acceptance evidence.

## Related Documents

- [Setup operator portal](../README.md)
- [Setup operator procedures](../operatorSOP/README.md)
- [Setup engineering portal](README.md)
- [Setup Session Production Engineering Handoff](Setup_Session_Production_Engineering_Handoff_2026-09-07.md)
