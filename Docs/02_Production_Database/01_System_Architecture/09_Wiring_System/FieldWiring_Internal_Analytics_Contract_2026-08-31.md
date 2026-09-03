# FieldWiring Internal Analytics Contract — 2026-08-31

| Item | Value |
|---|---|
| Status | CURRENT |
| Owning application | FieldWiring / Controller Inventory |
| GA4 property | MSB Internal Intranet |
| Measurement ID | `G-X08ZTSY0VV` |
| Analytics asset version | `2026-08-31.1` |
| Governing rule | `System_Documentation/Project_Rules/Internal_Web_Analytics_Rule.md` |

## Scope

FieldWiring is deployed beneath `my.sheboyganlights.org` and therefore participates in the shared MSB Internal Intranet GA4 property.

Analytics is integrated on the three operator-facing FieldWiring pages:

```text
/fieldwiring/
/fieldwiring/controllers
/fieldwiring/wiring
```

The implementation lives in:

```text
FieldWiring/Application/static/analytics.js
```

Each page loads the asset with an explicit cache/version parameter:

```text
static/analytics.js?v=2026-08-31.1
```

## Privacy Boundary

FieldWiring URLs can contain Production Database identifiers such as:

- `display_id`;
- `stage_id`;
- Preview UUID;
- Scene UUID;
- other selection-specific values.

Those values must never be sent to Google Analytics.

The FieldWiring-owned analytics loader therefore does **not** use `window.location.search` or the raw current URL for GA4 page measurement. It reports only the normalized application pathname.

Examples:

```text
Browser URL:
https://my.sheboyganlights.org/fieldwiring/wiring?display_id=309&stage_id=45

GA4 page path:
/fieldwiring/wiring
```

No authenticated identity, email address, QR payload, Controller ID, Display ID, Container ID, Location ID/code, Preview UUID, Scene UUID, or raw query string may be sent to GA4.

Google Signals and advertising-personalization signals remain disabled.

## Current Measurement

The loader sends one sanitized `page_view` for each direct page load.

The loader also exposes a bounded helper for future anonymous workflow events:

```text
window.msbFieldWiringAnalyticsEvent(eventName, parameters)
```

The helper removes known record-identifying and identity parameters before calling GA4. Application code must still use only aggregate/non-record-specific event parameters.

No additional Controller-selection or wiring-selection event is required by the initial integration. Such events may be added later only when they answer a useful operational adoption question without transmitting record identifiers.

## Acceptance

Automated contract coverage is in:

```text
FieldWiring/Application/test_internal_analytics_contract.py
```

The automated gate verifies:

- all three FieldWiring pages load the versioned analytics asset;
- the approved Measurement ID is used;
- Google Signals and advertising personalization are disabled;
- page measurement is pathname-only and does not use query strings/raw URLs;
- the bounded event helper strips known identity and Production Database identifier parameters.

Production acceptance must additionally verify a direct page view in the MSB Internal Intranet GA4 property after deployment.
