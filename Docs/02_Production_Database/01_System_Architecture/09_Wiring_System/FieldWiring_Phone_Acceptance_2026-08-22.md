# FieldWiring Phone Acceptance — 2026-08-22

| Document control | Value |
|---|---|
| Status | PASSED — phone layout accepted after currentness-banner correction |
| Sub-project | FieldWiring |
| Public URL | `https://my.sheboyganlights.org/fieldwiring/` |
| Application branch | `agent/fieldwiring-server-deployment-reconnaissance` |
| Accepted correction commit | `fc85bdfad31be272163cfa8d3ed7c2ac85b012bf` |

## Acceptance result

FieldWiring was tested successfully on a phone in the live public environment.

Observed successful behavior:

- public FieldWiring route loads;
- Stage / Scene context is readable;
- Background / Static and Musical context controls remain usable;
- image controls remain touch-usable;
- Field Hookup rows remain readable in portrait without critical clipping;
- controller group presentation remains usable on the narrow layout;
- dark mode presentation is readable; and
- the wiring currentness banner was identified as unnecessary screen clutter and removed from interactive PC / phone / tablet presentation.

## Currentness correction

The `CURRENT FIELD COPY` block containing generated time, expiration time, snapshot, and supersession warning is now print-only.

This preserves the stale-copy protection required for printed / saved PDF field copies while keeping the connected interactive screen focused on the live current FieldWiring result.

The accepted HTML contract is:

```html
<section id="currentness" class="currentness print-only">
```

The print stylesheet explicitly displays `.print-only` content under `@media print`.

## Remaining device acceptance

Desktop and phone browser presentation have now been accepted in the live public environment.

Tablet presentation and print / Save PDF output still require explicit final acceptance before scan-hub integration is considered complete.
