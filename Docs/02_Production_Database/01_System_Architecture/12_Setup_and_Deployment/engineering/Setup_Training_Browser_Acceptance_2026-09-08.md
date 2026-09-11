# Setup Training / Reconstruction Browser Acceptance — 2026-09-08

| Document Control | Value |
|---|---|
| Document Type | Engineering Acceptance Record |
| System | Production Database — Setup Session |
| Status | ACCEPTED — browser/operator gate passed; Production deployment not yet authorized |
| Owner | MSB Production Database engineering |
| Related Work | Issue #122; draft PR #125 |

## Purpose

Record the final operator disposition for the current Setup training/reconstruction candidate after disposable database acceptance and live browser review against a disposable current-Production clone.

## Accepted candidate

```text
branch = agent/setup-session-production-foundation
application/database candidate = aaf7de1c1d457b3dfaafe061f084a044cdf2abb7
branch acceptance-harness head = 1fa865c308832ffe84f9378344a6de916401d52a
```

The browser launcher pins the application/database candidate while later branch commits only track preview-harness/contract metadata.

## Regression evidence

Final local Setup/Application suite:

```text
117 passed in 0.55s
```

## Disposable database acceptance

Migration package exercised against a disposable clone of current Production:

```text
019 = reconstruction-safe task delete
020 = Captain / Alternate / Advisor management
021 = ASSIGNED reconciliation state
022 = require active ref.person for new/updated Captain selection
```

Accepted disposable report:

```text
/home/msbadmin/setup-acceptance-reports/Setup_Training_Disposable_20260909T015839.txt
```

Result:

```text
DISPOSABLE_SETUP_TRAINING_ACCEPTANCE_PASS
Production Setup fingerprint before = a2a84fc3f162f2f30914c909710976cf
Production Setup fingerprint after  = a2a84fc3f162f2f30914c909710976cf
PASS: Production Setup fingerprint unchanged
Exit status: 0
```

Migration 022 acceptance includes both projection and command-layer protection: inactive people are excluded from the Captain candidate projection and the governed Captain command refuses new/updated assignments to inactive people.

## Browser review findings and final behavior

The browser review drove several refinements before acceptance:

- Catalog return navigation works and is placed beside reusable-task Save/Delete actions rather than at the top of a long task page.
- Back-to-Catalog styling was revised for usable light/dark theme contrast.
- Captain picker changed from an always-expanded directory list to a type-ahead selection workflow.
- The backing directory select is hidden from the rendered UI.
- Captain candidate data is restricted to active `ref.person` rows; existing historical Captain assignments remain readable even if a person later becomes inactive.
- Clear Selection behavior works.
- `Mark Assigned` wording was replaced with `Confirm Reusable Task Match` / `Matched to Reusable Task` language so the annual reconciliation action is not confused with Stage/Scene task assignment.
- Confirmation text explicitly identifies the reusable task/current scope and states that reconciliation does not move the task or change Stage/Scene scope.
- Material / Logistics keeps compact summary counts inline and moves long Container/Display detail into `View Material Details`, avoiding unusable pages for areas with many Displays/Containers.
- Reconstruction-safe Delete behavior worked in the disposable preview clone.

## Operator disposition

Greg's final operator disposition on 2026-09-08:

```text
ACCEPTED
```

The browser/operator gate is therefore passed for this candidate.

## Important boundary

This acceptance does **not** itself authorize a Production mutation.

The next gate is the separate Runbook-First Production deployment process using:

```text
Gregovate/MSB-Server-Management
docs/server/Production_Database_Change_Deployment_Runbook.md
```

and Setup runtime authority:

```text
Gregovate/MSB-Server-Management
docs/server/Setup_Production_Runtime.md
```

Before any Production write or checkout advance, obtain explicit Production deployment approval and then follow the controlled migration/runtime sequence. Apply only the approved migration set and advance `/opt/msb-setup` only to the exact approved target.

## Separate People / Skills discovery

The global People/Capability/Qualification design discovered during this browser review is intentionally separated from Setup implementation ownership and is tracked under issue #130 / draft PR #131 in `03_People_and_Identity`. It is not part of this Production deployment package other than the narrow migration 022 active-person Captain guard.
