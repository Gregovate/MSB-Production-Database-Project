# Setup Internal Analytics and Visible Update Contract — 2026-09-07

| Document Control | Value |
|---|---|
| Document Type | Engineering Contract |
| System | Production Database — Setup Session |
| Status | IMPLEMENTED IN SOURCE — Production deployment/GA4 verification pending |
| Production route | `https://my.sheboyganlights.org/setup/` |
| GA4 property | MSB Internal Intranet |
| Measurement ID | `G-X08ZTSY0VV` |
| Analytics asset version | `2026-09-07.1` |
| Visible page marker | `Updated 2026-09-07` |
| Governing rule | `System_Documentation/Project_Rules/Internal_Web_Analytics_Rule.md` |

## Purpose

Define the analytics and visible-update requirements for the Setup application so direct application use can be measured and an operator can identify how recently the deployed page was revised without inspecting server files.

This contract was added after live Setup deployment exposed two acceptance gaps:

1. the Setup application had no GA4 integration even though the Production Database project rule requires analytics for applications under `my.sheboyganlights.org`; and
2. `production.html` had cache-busting asset revisions but no visible updated/version marker.

## GA4 Contract

Setup uses the shared authenticated-intranet GA4 property:

```text
G-X08ZTSY0VV
```

Current source asset:

```text
Setup/Application/setup_analytics.js
```

Current asset version:

```text
2026-09-07.1
```

The Production page loads it explicitly as:

```text
setup_analytics.js?v=2026-09-07.1
```

The current minimum behavior is a direct application `page_view`. No task-specific workflow events are required for this correction.

Future bounded anonymous events may be added only when they answer a useful operational/product question. Do not instrument controls merely because they can be measured.

## Privacy Boundary

Analytics receives only safe aggregate browser context.

Page views use `window.location.pathname` only. Do not send query strings or raw URLs because Setup URLs and application state may contain operational identifiers.

The Setup analytics helper strips record/identity values including:

- Setup Session, annual-task, reusable-task, resource, and work-day IDs;
- Display, Container, Location, Stage, Scene, Preview identifiers;
- authenticated user/email/identity values;
- QR payloads/URLs;
- task names;
- filesystem paths;
- raw URLs; and
- document IDs.

Google Signals and advertising personalization remain disabled.

GA4 is not the Setup audit log. User accountability and record-change history remain in MSB-controlled application/database logging.

## Visible Updated-Date Contract

The Setup Production page must display a small visible update marker near the bottom of the page.

Current source marker:

```text
Updated 2026-09-07
```

A semantic/application version is not required merely to satisfy this human-facing freshness marker. The backend health endpoint remains the technical application-release authority and currently reports:

```text
V0.3.4-shared-season-guard-review
```

The visible update date answers the simpler operator question: "Am I looking at the recently updated page?"

When the maintained Setup page changes materially, update the visible date. Internal asset cache/version parameters remain separate technical controls and should be bumped when the corresponding asset changes.

## Production Asset Boundary

`production_backend.py` explicitly allowlists `setup_analytics.js`. The Production backend must continue to block prototype/source files while serving the analytics asset.

Contract tests live at:

```text
Setup/Application/test_setup_internal_analytics_contract.py
```

They verify:

- the Production page loads the versioned analytics asset;
- the visible `Updated YYYY-MM-DD` marker is present;
- the Production backend serves the analytics asset;
- the approved Measurement ID is used;
- Google Signals/ad personalization are disabled;
- page views omit query strings/raw URLs; and
- the event helper strips record/identity values.

## Production Acceptance Gate

This contract is not fully accepted until the deployed Setup application proves:

```text
[ ] /setup/ visibly shows Updated 2026-09-07
[ ] /setup/setup_analytics.js?v=2026-09-07.1 is served
[ ] browser network/source confirms Measurement ID G-X08ZTSY0VV
[ ] direct /setup/ page view appears in the MSB Internal Intranet GA4 property
[ ] no query string, authenticated identity, or Production record ID is sent
[ ] Setup health and representative authenticated 2025 behavior remain healthy
```

After those checks pass, update this document to `CURRENT / ACCEPTED` and record the deployment evidence in the Setup production engineering handoff.

## Related Documents

- [Setup Engineering](README.md)
- [Setup Session Production Engineering Handoff](Setup_Session_Production_Engineering_Handoff_2026-09-07.md)
- [Internal Web Analytics Rule](../../../../../System_Documentation/Project_Rules/Internal_Web_Analytics_Rule.md)
