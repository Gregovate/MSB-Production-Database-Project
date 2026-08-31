# Procedure Internal Analytics Contract — 2026-08-31

| Item | Value |
|---|---|
| Status | CURRENT |
| Owning application | Field Procedures |
| Production route | `https://my.sheboyganlights.org/procedures/` |
| GA4 property | MSB Internal Intranet |
| Measurement ID | `G-X08ZTSY0VV` |
| Analytics asset version | `2026-08-31.1` |
| Governing rule | `System_Documentation/Project_Rules/Internal_Web_Analytics_Rule.md` |

## Requirement

Field Procedures is a separately deployed `my.sheboyganlights.org` application and therefore owns its own direct page-view measurement under the shared MSB Internal Intranet GA4 property.

Analytics implementation lives in:

```text
Procedures/Application/static/analytics.js
```

The browser loads the asset with an explicit version:

```text
static/analytics.js?v=2026-08-31.1
```

## Privacy Boundary

Procedure browser URLs may contain operational selection values including:

- `display_id`;
- `stage_id`;
- `preview_uuid`;
- `scene_uuid`;
- Procedure task;
- current asset name.

Those values must not be transmitted to GA4 as page-location query strings or record-identifying event parameters.

The Procedures-owned analytics loader reports only the normalized application pathname. It does not use `window.location.search` or the raw browser URL for page-view measurement.

Example:

```text
Browser URL:
https://my.sheboyganlights.org/procedures/?display_id=807&task=Setup

GA4 page path:
/procedures/
```

Do not send authenticated identity, email address, QR payload, Display/Controller/Container/Location identifiers, Preview/Scene UUIDs, raw Drive IDs/URLs, Procedure asset paths, or Procedure filenames to GA4.

Google Signals and advertising-personalization signals remain disabled.

## Measurement

The initial integration sends one sanitized `page_view` per direct Procedure page load.

The loader exposes a bounded helper for future anonymous aggregate workflow events:

```text
window.msbProcedureAnalyticsEvent(eventName, parameters)
```

The helper strips known identity, Production Database identifier, file-name, path, and URL fields before submitting an event. Future event callers must still use only non-record-specific aggregate values.

Useful Procedure workflow events were considered. The initial acceptance keeps the scope to direct page-view measurement rather than sending Procedure document or Display-specific selections. Additional aggregate events may be added later when they answer a useful adoption question without crossing the privacy boundary.

## Automated Acceptance

Contract tests are maintained in:

```text
Procedures/Application/test_internal_analytics_contract.py
```

They verify:

- the Procedure page loads the versioned analytics asset;
- the asset is served by the Procedure application;
- the approved Measurement ID is used;
- Google Signals and advertising personalization are disabled;
- query strings and raw URLs are not sent in page measurement; and
- the bounded event helper strips known identity, record identifier, filename, path, and URL parameters.

Production acceptance must additionally verify a direct `/procedures/` page view in the MSB Internal Intranet GA4 property after deployment.

## Related Project Rule

`System_Documentation/Project_Rules/Internal_Web_Analytics_Rule.md` is the project-wide authority. It requires analytics for applications deployed under `my.sheboyganlights.org`, including separately owned applications such as Procedures, FieldWiring, Controller Inventory, and LOR2DB when applicable.
