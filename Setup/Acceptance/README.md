# Setup Acceptance Tooling

## Authority

Setup acceptance consumes the runtime/safety rules owned by `Gregovate/MSB-Server-Management`:

- `docs/server/PostgreSQL_Disposable_Acceptance_Standard.md`
- `docs/server/Pre_Production_Browser_Review_Runbook.md`
- `docs/server/Production_Database_Change_Deployment_Runbook.md`

The Production Database repository owns Setup feature migrations, validation SQL, application behavior, and the reusable Setup launchers that consume those server/runtime contracts.

## Required lifecycle

For database-affecting Setup work, use the same sequence every time:

```text
exact candidate + clean local checkout
    -> full Setup/Application regression
    -> disposable current-Production clone acceptance
    -> exact-candidate browser review against a fresh disposable clone
    -> operator acceptance
    -> separate Production deployment runbook
```

Production mutation is not part of either reusable acceptance launcher. Production is limited to `pg_dump` and read-only evidence/fingerprint queries until the candidate has been explicitly accepted.

If the candidate changes after either gate, start again from the new exact SHA. Do not carry forward a prior disposable clone or browser preview.

## Reusable disposable acceptance

Use:

```powershell
.\Setup\Acceptance\run_setup_disposable_acceptance.ps1 `
  -CandidateSha <exact-sha> `
  -TargetRef <exact-branch> `
  -MigrationPaths @(<candidate-relative Setup/Database SQL files>) `
  -ValidationPaths @(<candidate-relative Setup/Acceptance SQL files>)
```

The launcher and server runner:

- require the local checkout to be clean and exactly match the requested candidate SHA/ref;
- rerun the full `Setup/Application` regression on a detached exact-candidate worktree;
- capture current Production with `pg_dump` only;
- restore a disposable `postgis/postgis:16-3.5` clone;
- require final PostgreSQL PID 1 plus `pg_isready` before restore/use;
- mirror the current Production `fieldwiring_app` Setup read/execute privilege surface using read-only Production queries;
- apply only the migration files explicitly supplied by the feature;
- run only the validation SQL explicitly supplied by the feature;
- clean the disposable container/worktree/dump/pycache on success, failure, interruption, or HUP; and
- prove the Production Setup fingerprint and live `/opt/msb-setup` SHA are unchanged before returning success.

Feature-specific behavior belongs in the supplied migration/validation files, not in a new acceptance runner.

## Reusable disposable browser review

After disposable acceptance passes, use:

```powershell
.\Setup\Acceptance\run_setup_disposable_browser_preview.ps1 `
  -PreviewPort <unused-nonproduction-port> `
  -CandidateSha <same-exact-sha> `
  -TargetRef <same-exact-branch> `
  -ExpectedVersion <candidate-health-version> `
  -MigrationPaths @(<same candidate migrations>)
```

`-ValidationPaths` is optional for browser review. Use it only when a validation/preparation SQL is intentionally safe to leave in the disposable browser state. Do not preload a feature validation that would hide the operator behavior being reviewed.

The browser launcher preserves the same disposable-clone/Production-after safety gates and additionally:

- refuses governed Production listener ports;
- owns the foreground SSH tunnel directly;
- starts the exact candidate with the documented `fieldwiring` Python runtime;
- pins `/api/health` to the expected candidate version when supplied;
- verifies the preview operator has Setup Manager capability;
- cleans the preview process as the `fieldwiring` runtime owner;
- verifies the preview-owned TCP listener is gone after cleanup; and
- remains bounded by an eight-hour foreground timeout so an abandoned session cannot become a permanent preview.

When the terminal prints `SETUP REUSABLE DISPOSABLE BROWSER REVIEW READY`, perform the feature-specific operator checklist. Press ENTER only after the review is complete so the same bounded process performs cleanup and Production-after proof.

## Legacy feature-specific wrappers

Older Setup acceptance files remain historical evidence for the feature that created them. They contain hard-coded candidate SHAs, migration sets, or feature checks and must not be copied or patched for new work when the reusable launchers above can express the candidate.

If the reusable launchers cannot safely express a future requirement, treat that as an acceptance-tooling gap: improve the reusable tooling first, contract-test the improvement, then rerun the exact candidate. Do not substitute an ad-hoc interactive SSH procedure.

## Production gate

A green disposable acceptance and accepted browser review do **not** authorize Production mutation by themselves.

Only after explicit operator acceptance switch to the Server Management `Production_Database_Change_Deployment_Runbook.md`, including its live-checkout verification, validated rollback point, reviewed migration/deployment, post-deployment health/security/invariant checks, and rollback path.

## Current Production Acceptance Records

- `Setup_Assignment_Layer_V0313_Production_Acceptance_2026-09-12.md`
- `Setup_Resource_Upsert_Repair_Production_Acceptance_2026-09-13.md`
- `Setup_Kit_Inventory_TPost_Production_Acceptance_2026-09-15.md` — #184 durable Extra Material / Kit Inventory / T-Post subsystem plus completed #167 one-time reconstruction.
- `Setup_Planning_Summary_Production_Acceptance_2026-09-15.md` — #122 Planning Summary / hand-markup scheduler and Pick-List readiness review surface.
