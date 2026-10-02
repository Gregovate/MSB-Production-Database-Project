# Setup and Deployment — Internal Web Backbone Handoff

| Document Control | Value |
|---|---|
| Document Type | Internal Web Backbone Integration Handoff |
| Source System | Production Database — Setup and Deployment |
| Consuming System | `Gregovate/MSB-Internal-Web-Backbone` |
| Status | CURRENT HANDOFF — source Setup state reconciled through V0.3.33 live 2026 scheduling / field execution / movement / Manager Material Status |
| Owner | MSB Production Database / Setup documentation owner |
| Last Reviewed | 2026-09-30 |

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
2025 historical data rendering        = PASS
2026 annual Session / Scheduling      = LIVE / Production accepted
post-deployment invariants            = PASS
```

The **runtime and 2026 Scheduling Board are accepted**. The real 2026 Setup Session is now the current annual planning/execution context. 2025 Historical Verification remains available only for intentional historical/review work. Backbone navigation must lead with current 2026 Setup work rather than presenting 2025 review/training as the primary Setup action.

Current accepted operator workflows also include **Perform Work / Report Work**, **Report Correction -> Work Order Intake**, and the **Rolling Pick List / Pick Delay** release. The current Production application identity is **V0.3.22-pick-list-delay**. Persisted physical PICKED/movement execution remains separate.

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

Operator screenshot assets:

```text
Docs/02_Production_Database/01_System_Architecture/12_Setup_and_Deployment/images/
```

The screenshots are source-owned documentation assets and are referenced with relative Markdown paths. Backbone should render them with the canonical documents rather than copying them into a second image library.

These source documents are now on Production Database `main`.

PR **#223** rewrote the Setup operator instructions in plain language using live Manager feedback. The canonical Setup README remains the documentation target for Backbone; do not create a second editable copy.

Backbone issue **#10** records the Production-page integration. Greg provided live browser evidence on 2026-09-22 showing **Production Portal v1.3 — Updated 2026-09-07** with the **Review 2025 Setup**, **Setup Documentation**, and **Procedures** actions visible. He also opened **Setup Documentation** from that portal and reached the current Setup README showing **Last Reviewed 2026-09-22**.

That confirms the live portal is using the canonical Setup documentation path on Production Database `main`.

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

Primary current tasks:

- **Schedule 2026 Setup Work** — Managers use the live 2026 Setup Session and **Plan / Schedule** for current annual planning.
- **Perform / Report Setup Work** — Captains and Production Crew use **Perform Work** for scheduled field assignments and **Report Work** for actual date, crew, elapsed time, progress, and completion.
- **Rolling Pick List** — warehouse/picker view of current schedule-derived physical demand; Manager early-pick demand and transient **Pick Delay / Resume Pick** are accepted.
- **Report Correction** — preserves a field Procedure/material/data problem as Submitted Work Order Intake for Manager triage without silently changing durable Setup data.
- **Kit / T-Post Inventory** — review expected Kit contents and physical inventory while keeping expected, on-hand, and storage facts separate.

Secondary historical/review task:

- **Review and Correct the 2025 Setup History** — use the Production-backed 2025 Historical Verification session only when historical/review evidence is intentionally needed.

Canonical historical-review procedure:

```text
operatorSOP/Review_2025_Setup_History.md
```

Useful supporting action link:

- **Open Setup Application** — `https://my.sheboyganlights.org/setup/`

Additional Setup task choices should be added only after the corresponding workflow is production-operational and documented in the source subsystem.

## Suggested Plain-Language Copy

Primary card/action title:

```text
2026 Setup — Plan, Perform & Pick
```

Description:

> Schedule current 2026 work, open Captain field assignments, report actual work, and pull the physical material the live schedule now needs.

Useful supporting actions:

```text
Open Rolling Pick List
Open Kit Inventory
Open T-Post Inventory
Setup Operator Procedures
Perform and Report Setup Work
```

Secondary historical action when useful:

```text
Review 2025 Setup History
```

Do not label the application as a prototype. The annual Scheduling Board, Perform Work / Report Work, Report Correction intake, and Rolling Pick List / Pick Delay workflows are live Production software. Persisted physical movement/scanning remains under its owning workstream.

## Search / Discovery Metadata

Useful search terms:

```text
Setup
2026 Setup
Plan / Schedule
Scheduling Board
Perform Work
Report Work
Report Correction
Rolling Pick List
Pick Delay
Work Day
2025 Setup
Historical Verification
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

The Rolling Pick List and transient Pick Delay are current Production workflows and may be exposed in operator navigation.

Do **not** describe the Pick List as proof that material physically moved or was picked. Persisted physical PICKED/movement execution and Container/Display movement/scanning writes remain separate work.

## Backbone Implementation

Backbone PR **#11** merged the initial Setup application action on 2026-09-07. Backbone issue **#10** records the later source work that also adds the canonical Setup documentation destination.

Implemented source:

```text
my/committees/production/index.html
```

Live browser evidence from 2026-09-22 showed the then-current Backbone Setup destinations as **Review 2025 Setup**, **Setup Documentation**, and **Open Procedures**. That evidence is historical portal state, not current Setup workflow authority.

Current source-system direction is:

- **2026 Setup — Plan, Perform & Pick** -> `https://my.sheboyganlights.org/setup/`;
- **Rolling Pick List** -> `https://my.sheboyganlights.org/setup/pick-list/`;
- **Kit Inventory** -> `https://my.sheboyganlights.org/setup/kit-inventory/`;
- **T-Post Inventory** -> `https://my.sheboyganlights.org/setup/t-post-inventory/`;
- **Setup Documentation** -> the canonical Setup README on Production Database `main`;
- **Open Procedures — Setup / Takedown / Inspection** -> `https://my.sheboyganlights.org/procedures/`;
- retain **Review 2025 Setup History** only as a secondary historical/review destination where useful.

Because the documentation destination points to the canonical README on `main`, future source-document improvements do not require a duplicate Backbone copy of the procedure. If the live Backbone portal still shows the old 2025-first label, that is a Backbone presentation follow-up; it does not change current Setup authority.

## Acceptance Criteria

Backbone integration is VERIFIED only when all applicable checks pass:

1. the Production index/task navigation includes an appropriate Setup action;
2. the action points to `https://my.sheboyganlights.org/setup/`;
3. the primary action reflects live 2026 scheduling/execution and current Pick List capability, while 2025 historical review remains clearly secondary;
4. the obsolete static Setup/Takedown page is not linked or promoted;
5. engineering/acceptance/database source paths are absent from normal operator navigation;
6. no duplicate editable copy of the source operator procedure is created in Backbone;
7. maintained `index.html` pages preserve their required visible version indicators; and
8. deployed intranet verification confirms the intended Production page reaches the protected Setup application.

## Backbone State

```text
SOURCE FOLLOW-UP REQUIRED — existing Production landing copy predates the live 2026 Scheduling Board / Perform Work / Report Correction / V0.3.22 Pick List workflow
```

The canonical source documentation is current through the accepted 2026 operator workflow. Backbone presentation must be refreshed from this handoff and then live-verified through its controlled one-file publish process.

## Related Documents

- [Setup operator portal](../README.md)
- [Setup operator procedures](../operatorSOP/README.md)
- [Setup engineering portal](README.md)
- [Setup Session Production Engineering Handoff](Setup_Session_Production_Engineering_Handoff_2026-09-07.md)
