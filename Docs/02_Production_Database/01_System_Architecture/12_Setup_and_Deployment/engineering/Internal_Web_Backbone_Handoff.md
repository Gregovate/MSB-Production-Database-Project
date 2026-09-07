# Setup and Deployment — Internal Web Backbone Handoff

| Document Control | Value |
|---|---|
| Document Type | Internal Web Backbone Integration Handoff |
| Source System | Production Database — Setup and Deployment |
| Consuming System | `Gregovate/MSB-Internal-Web-Backbone` |
| Status | PENDING — permanent `/setup/` route deployment in progress |
| Owner | MSB Production Database / Setup documentation owner |
| Last Reviewed | 2026-09-07 |

## Purpose

Define what the Internal Web Backbone should expose for Setup and Deployment without copying engineering history into the operator experience or creating a competing documentation authority.

The source Setup subsystem remains authoritative. The Backbone should publish navigation/search/application entry points that lead users to the current controlled source or protected application.

## Canonical Operator Portal

Canonical source portal:

```text
Docs/02_Production_Database/01_System_Architecture/12_Setup_and_Deployment/README.md
```

Canonical operator procedure index:

```text
Docs/02_Production_Database/01_System_Architecture/12_Setup_and_Deployment/operatorSOP/README.md
```

## Preferred Application Entry Point

When live acceptance is complete, the normal protected Setup action link is:

```text
https://my.sheboyganlights.org/setup/
```

This is a `my.` action application and requires the established Google/Cloudflare Access perimeter.

Do not send ordinary users to repository application source, database migration files, or a temporary preview listener when the protected production route is available.

## Operator Tasks That Should Be Discoverable

Initial task choice:

- **Review and Correct the 2025 Setup History** — authorized reviewers use the real 2025 Production-backed Historical Verification session to correct annual history and improve reusable Setup knowledge before the 2026 Setup Session is created.

Canonical source procedure:

```text
operatorSOP/Review_2025_Setup_History.md
```

Future Setup task choices should be added only after the corresponding workflow is production-operational and documented in the source subsystem.

## Search / Discovery Metadata

Useful search terms:

```text
Setup
2025 Setup
Historical Verification
Setup training
review Setup history
reusable Setup task
2026 Setup baseline
Setup plan
```

Operator-facing description:

> Review and correct the 2025 Setup record, improve reusable Setup knowledge, and prepare the baseline used to build the 2026 Setup plan.

## Important Operator Meaning

Backbone presentation should preserve this distinction in plain language:

```text
2025 annual changes
    = corrections to 2025 history

Reusable Task changes
    = permanent Setup knowledge that may carry forward
```

The selected Setup Session controls the allowed operational year. The 2025 review area accepts 2025 operational dates only.

Do not expose database/schema implementation details to ordinary operators merely to explain this rule.

## Authorization / Link Boundary

The `/setup/` link may be visible as an internal action destination, but possession of the link does not grant application capability.

The protected application performs its own authenticated identity and authorization checks. Backbone must not attempt to recreate Setup Manager/Administrator authorization logic.

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

Engineering material may be available through a clearly separated contributor/engineering path when appropriate, but it must not compete with operator navigation.

## Legacy / Compatibility Link Rule

Existing dated Setup/Deployment engineering documents in the parent folder are supporting historical/current engineering evidence. They should not become new intranet operator dependencies merely because they remain in the repository for compatibility.

The Backbone should prefer the canonical operator portal and operatorSOP index above.

## Images

No Setup operator-documentation images are required for the initial 2025 review procedure. If screenshots are later added, they should live under the Setup subsystem's controlled `images/` location and be referenced from the source operator procedure rather than copied independently into Backbone content.

## Acceptance Criteria

Backbone integration is VERIFIED only when all applicable checks pass:

1. `https://my.sheboyganlights.org/setup/` is production-operational and protected by the normal Access perimeter;
2. the intranet presents Setup as an internal action/workflow rather than an engineering document tree;
3. the 2025 historical review procedure is discoverable by plain-language task/search terms;
4. the preferred application link points to `/setup/` rather than GitHub or a preview port;
5. engineering/acceptance/database source paths are absent from normal operator search/navigation;
6. no duplicate editable copy of the operator procedure is created in the Backbone repository; and
7. a deployed intranet check confirms navigation reaches the intended Setup application/procedure.

## Backbone State

```text
PENDING
```

Reason: source handoff exists, but permanent `/setup/` service/public-route acceptance and Backbone implementation have not yet completed.

When Backbone source is updated, change this state to `IMPLEMENTED`. After deployed intranet verification, change it to `VERIFIED` and record the acceptance reference.

## Related Documents

- [Setup operator portal](../README.md)
- [Setup operator procedures](../operatorSOP/README.md)
- [Setup engineering portal](README.md)
- [Setup Session Production Engineering Handoff](Setup_Session_Production_Engineering_Handoff_2026-09-07.md)
