# Procedure Display Scan Production Acceptance — 2026-08-23

| Item | Accepted value |
|---|---|
| Status | ACCEPTED PRODUCTION — physical Display QR path verified |
| Production Database source merge | `a909cbef147c8b6575394513649862211f837f6e` |
| Live Directus Scan artifact | `/opt/directus/extensions/directus-extension-scan/dist/index.js` |
| Accepted live SHA-256 | `fb2a98088e363430fb0a303e4c895bae8202f4f253ac22a1481a406eb5b7443a` |
| Rollback artifact | `/home/msbadmin/backups/directus-scan/pre-procedures-20260824T004146Z/index.js` |
| Directus image | `directus/directus:11.17.1` |

## Purpose

This document records the production acceptance of the bounded Procedure Display Scan integration and the physical-QR origin compatibility correction discovered during phone testing.

It is acceptance evidence for the current Scan application behavior. Server deployment/restart/recovery authority remains in `Gregovate/MSB-Server-Management`.

## Accepted Display Scan Behavior

The existing physical Display QR resolves the permanent Display identity through the existing Scan hub. The hub now exposes the independent field-document actions with explicit protected public origins:

```text
Field Wiring
https://my.sheboyganlights.org/fieldwiring/wiring.html?display_id=<display_id>

Procedures
https://my.sheboyganlights.org/procedures/?display_id=<display_id>
```

Procedure task choice remains inside the existing Procedure application:

```text
Setup
Takedown
Inspection
```

Scan passes only permanent `display_id`. No physical Display QR redesign, second field-context resolver, Procedure schema, alternate Google hierarchy, or Procedure health/API dependency was added.

## Physical QR Defect Found During Acceptance

A newly printed Display label was scanned from a phone. The label opened the Scan hub on the current QR-encoded Directus origin:

```text
https://db.sheboyganlights.org/scan/DISP/<display_id>
```

Before the compatibility correction, the Field Wiring button was root-relative and therefore resolved incorrectly to:

```text
https://db.sheboyganlights.org/fieldwiring/wiring.html?display_id=141
```

Directus returned `ROUTE_NOT_FOUND` because FieldWiring is served under the protected `my.sheboyganlights.org` origin.

The newly added Procedures action would have had the same origin defect because it was also initially root-relative.

The accepted correction is to use explicit `my.sheboyganlights.org` origins for FieldWiring and Procedures while leaving Directus-facing Scan actions on `db.sheboyganlights.org`.

Existing printed Display QR labels therefore remain usable and do not require mass reprinting as part of this correction.

Future printed-QR-origin reconciliation is tracked separately in `Gregovate/MSB_LabelPrintService` issue #2.

## Deployment Acceptance

The documented Server Management deployment safety gate was followed:

1. the previously accepted live artifact hash was verified;
2. a new pre-Procedure rollback was captured;
3. the corrected merged candidate was staged outside the live directory;
4. the staged JavaScript passed syntax validation;
5. the staged artifact was copied to the live Scan runtime;
6. live and staged hashes matched;
7. the live mounted artifact passed syntax validation;
8. `msb-directus` was restarted successfully; and
9. the Display Scan endpoint returned successfully after restart.

Final runtime evidence supplied after restart:

```text
msb-directus
image: directus/directus:11.17.1
status: Up

SHA-256:
fb2a98088e363430fb0a303e4c895bae8202f4f253ac22a1481a406eb5b7443a
```

Rollback preserved at:

```text
/home/msbadmin/backups/directus-scan/pre-procedures-20260824T004146Z/index.js
```

## Phone / Physical Label Acceptance

Actual phone testing with a newly printed physical Display QR label passed after the public-origin correction.

Accepted result:

```text
Physical Display QR decode / Scan hub path: PASS
Physical Display QR downstream field-app origin compatibility: PASS
```

The physical QR test is important because the earlier FieldWiring acceptance had explicitly deferred physical QR decode when no QR label was available.

## Explicitly Deferred

The following case was not tested during this acceptance and must not be reported as passed:

```text
Physical Container QR decode: NOT TESTED
```

No Container QR label was printed for this acceptance.

The existing Display-hub Container action working correctly does not prove physical Container-label QR behavior.

Other previously deferred Scan regression cases remain deferred unless separately exercised and recorded.

## Cross-Repository Follow-up

`MSB_LabelPrintService` currently generates full Scan URLs for printed Display and Container QR labels. The intended future QR-origin/payload contract must be reconciled through the LabelPrintService engineering recovery rather than changed casually during this Scan acceptance.

See:

- Production Database issue #52 — physical QR downstream-origin defect and correction;
- `Gregovate/MSB_LabelPrintService` issue #2 — future printed QR origin reconciliation; and
- `Gregovate/MSB-Server-Management/docs/directus/Display_Scan_Extension_Deployment_and_Recovery.md` — deployment/recovery authority.

## Resume Point

Procedure Display Scan Integration is production-accepted for the physical Display QR path.

Do not reopen the Procedure/FieldWiring resolver architecture or QR identity merely to continue later Scan work. Future Scan changes must begin from the accepted live artifact hash above and the current Server Management deployment/recovery documentation.

Physical Container QR acceptance remains a separate untested regression case until a real Container label is scanned.
