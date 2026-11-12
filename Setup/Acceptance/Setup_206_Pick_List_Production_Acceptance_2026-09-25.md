# Setup #206 Pick List Production Acceptance — 2026-09-25

## Scope

Production acceptance for the rolling physical Pick List and Manager early-pick override owned by Setup issue #206.

This release adds:

- schedule-driven physical Container / Display demand;
- non-material precursor early-demand propagation with direct-material downstream expansion suppressed;
- rack-walk ordering;
- Home Location, governed Destination, Pick By, Needed For, and established Container/Display QR identity;
- Manager early-pick override with governed Stage destination;
- suppression of already-demanded Containers from Manager search;
- picked/moved overlay from existing Setup movement state;
- compact print layout;
- migration 060 for annual/session-scoped Manager Pick List override authority.

## Accepted Candidate Lineage

Operator-accepted browser candidate:

```text
59148515ab361a297cd7107184662648cd10a60d
```

Release/version commit:

```text
a084b0130eae4547f26f3aaddf181b644eccd0b9
V0.3.19-pick-list
```

A stale contract assertion for the dirty-guard cache pin was corrected without changing accepted runtime/application/migration bytes. Final Production deployment target:

```text
24dd851b6ceed879ca96170db648476a8307a775
```

Migration identity:

```text
Setup/Database/060_add_setup_pick_list_manager_override.sql
Git blob: 72137b49d78da26647e539769973641b24ee1c57
```

## Browser / Operator Acceptance

Disposable current-Production clone review accepted:

- Container search by name;
- exact already-demanded Container disappears from manual-pick availability;
- same-named sibling Containers with different IDs remain independently selectable;
- governed Stage destination selector;
- Sunday excluded from Pick By, with Monday demand rolling to Saturday;
- rack-walk ordering;
- compact printed pull sheet;
- screen QR physically scanned successfully from the laptop display with a phone.

The final compact print-specific QR was visually reviewed but was not re-scanned in the final browser pass.

The disposable browser review ended with:

```text
SETUP REUSABLE DISPOSABLE BROWSER PREVIEW: CLEAN EXIT
```

## First Production Gate — Fail Closed Before Mutation

The first Production attempt stopped during detached exact-target regression because one stale contract test still expected:

```text
setup_catalog_dirty_guard.js?v=2026-09-25.1
```

while the accepted V0.3.19 runtime correctly used:

```text
setup_catalog_dirty_guard.js?v=2026-09-26.1
```

Evidence:

```text
500 passed / 1 failed
rollback backup: not created before stop
migration 060: not applied
live Setup checkout: not advanced
2026 Setup Session count before: 1
2026 Setup Session count after: 1
exit status: 1
```

The stale assertion was corrected in:

```text
24dd851b6ceed879ca96170db648476a8307a775
```

No operator-reviewed runtime file or migration byte changed.

## Successful Production Deployment

Final governed deployment:

```text
Live Setup SHA:
24dd851b6ceed879ca96170db648476a8307a775

Health:
{"data_mode":"postgres","status":"ok","version":"V0.3.19-pick-list"}
```

Live regression:

```text
LIVE SETUP REGRESSION: PASS
```

Final Production invariants:

```text
Final Setup fingerprint:        96b399ee872c1fe980d6f69a1ad34157
Final 2026 Setup Session count: 1
Final Pick List override rows:  0
```

After-check:

```text
Frozen Setup fingerprint: 96b399ee872c1fe980d6f69a1ad34157
Final Setup fingerprint:  96b399ee872c1fe980d6f69a1ad34157
PASS: governed Setup data fingerprint unchanged

2026 Setup Session count before: 1
2026 Setup Session count after:  1
PASS: 2026 Setup Session count unchanged
```

Final deployment result:

```text
SETUP_206_PICK_LIST_PRODUCTION_DEPLOYMENT_PASS
SETUP #206 PICK LIST PRODUCTION DEPLOYMENT WRAPPER: PASS
Exit status: 0
```

## Rollback Evidence

Validated rollback archive:

```text
/home/msbadmin/backups/setup-206/msb-pre-setup-206-pick-list-20260926T030610.dump
```

SHA256:

```text
ecb8da74c9192da5c5cf18ff45f8882b4d2cb0cada45516e8b0193073668c145
```

Deployment report:

```text
/home/msbadmin/setup-deployment-reports/Setup_206_Pick_List_Production_Deploy_20260926T030610.txt
```

Rollback is governed by `Gregovate/MSB-Server-Management` `Production_Database_Change_Deployment_Runbook.md`. Do not restore the PostgreSQL archive casually or without reconciling legitimate post-deployment Production writes.

## Current Operational State

The rolling Pick List is now Production operational under:

```text
V0.3.19-pick-list
24dd851b6ceed879ca96170db648476a8307a775
```

Migration 060 is installed. No Manager override rows were left behind by deployment or acceptance.

Tablet validation is intentionally deferred until the Production route is exercised on the field tablet. That validation does not block this Production acceptance because the exact browser workflow was already accepted on the disposable clone and the Production runtime/health/regression gates passed.

Issue #206 remains the owning workstream for any remaining material-readiness scope, including the previously identified full-season / Master Setup Material List requirement.
