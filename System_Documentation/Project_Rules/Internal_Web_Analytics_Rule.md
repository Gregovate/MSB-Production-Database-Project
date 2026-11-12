# Internal Web Analytics Rule

| Document Control | Value |
|---|---|
| Document Type | Project Rule |
| Repository | MSB Production Database Project |
| Status | CURRENT |
| Owner | Production project owner / administrator |
| Last Reviewed | 2026-08-29 |

## Purpose

This rule defines the analytics requirement for MSB web applications and operator portals deployed under `my.sheboyganlights.org` so usage measurement is built into new work instead of being retrofitted after deployment.

The goal is to understand which applications, documents, procedures, and portal choices are actually used so future engineering and documentation work can be prioritized from evidence rather than assumption.

## Approved GA4 Property

The approved Google Analytics 4 Measurement ID for the authenticated MSB intranet is:

```text
G-X08ZTSY0VV
```

All applications and portals deployed under `my.sheboyganlights.org` use this same MSB Internal Intranet GA4 property unless a later controlled project rule explicitly changes that architecture.

Do not create a separate GA4 property merely because an application is owned by another repository or subsystem.

## Required Integration

Analytics is part of the normal implementation and production-acceptance scope for a new `my.sheboyganlights.org` application or portal.

At minimum, the owning project must provide page-view measurement for the application itself. This is required because users may enter an application directly through a bookmark, QR code, scan action, inbound link, or browser history without first visiting the main intranet portal.

Where useful to understand adoption, usefulness, or operator workflow, the application should also emit bounded anonymous interaction events such as:

- major task or application choices;
- documentation/procedure selections;
- navigation to another MSB subsystem;
- workflow milestones whose aggregate usage helps determine whether a feature is being used.

Do not add events merely because a control can be measured. Events should answer a useful operational or product question.

## Privacy Boundary

GA4 is for aggregate usage analytics. It is not the MSB audit log and must not become one.

Do not send any of the following to Google Analytics:

- names;
- email addresses;
- Cloudflare Access authenticated identity;
- QR payloads;
- Display IDs, Container IDs, Controller IDs, Location IDs/codes, or other Production Database record identifiers;
- raw Google Drive document/folder IDs or URLs;
- work-order numbers or other record-specific operational values;
- passwords, tokens, credentials, secrets, or other sensitive values;
- any other personally identifying or record-identifying value that is not required for aggregate usage measurement.

When individual authenticated-user activity must be recorded for audit, accountability, or workflow history, that belongs in MSB-controlled application/database logging under the responsible subsystem. It must not be implemented by placing authenticated identity into GA4 custom dimensions or event parameters.

Google Signals and advertising-personalization features must remain disabled for this internal analytics use unless a later controlled rule explicitly changes that decision.

## Ownership Boundary

Each owning project is responsible for integrating analytics into the application it owns.

The shared Measurement ID does not transfer application ownership to the Internal Web Backbone and does not make the Backbone responsible for editing separately deployed applications.

Examples:

```text
MSB-Internal-Web-Backbone
    -> owns analytics integration for Backbone-owned my.* portal pages

MSB-Production-Database-Project
    -> owns analytics integration for its separately deployed my.* applications
       such as Procedure, FieldWiring, LOR2DB, or successors when those applications
       are maintained and deployed from this repository

other owning repository
    -> owns analytics integration for its own my.* application
```

Cross-repository applications must use the same approved analytics contract while preserving their normal source/deployment ownership boundaries.

## Shared Loader / Cache Rule

When an application uses a shared JavaScript analytics loader or other shared browser asset, deployment must make the intended analytics version verifiable.

A changed shared asset must not rely indefinitely on an unchanged browser-cached URL with no way to prove which version the client is executing.

Use an appropriate explicit version, cache-busting parameter, asset version, or equivalent controlled mechanism when needed so production acceptance can prove the deployed client is running the intended analytics behavior.

Do not alter unrelated application assets merely to force a cache refresh.

## Production Acceptance Gate

A new or materially changed `my.sheboyganlights.org` application is not fully accepted until the applicable analytics gate has been checked.

Minimum gate:

```text
[ ] GA4 integration is present in the owning application
[ ] Measurement ID is G-X08ZTSY0VV
[ ] direct application page view is verified in the MSB Internal Intranet GA4 property
[ ] useful anonymous workflow events were considered and implemented where they materially help measure use
[ ] no PII, authenticated identity, QR payload, or Production Database record identifier is sent to GA4
[ ] Google Signals / advertising personalization remain disabled
[ ] the deployed analytics asset/version can be identified or cache behavior has been explicitly verified
```

For an application that already existed before this rule, analytics may be added as bounded follow-on work. Once integrated and accepted, future changes must preserve it unless a controlled decision explicitly removes or replaces the analytics contract.

## Documentation Requirement

When analytics behavior, event names, destination classifications, privacy boundaries, or production acceptance are changed, update the responsible application/subsystem documentation during the work in accordance with the Documentation Maintenance Rule.

Do not leave a newly established analytics contract only in chat, GA4 configuration, browser code, an issue, or a pull-request description.

## Related Standards and Rules

- [Documentation Maintenance Rule](../Standards/Documentation_Maintenance_Rule.md)
- [Repository Change Workflow](Repository_Change_Workflow.md)
- [Production Operational Documentation Rule](Operational_Documentation_Rule.md)
