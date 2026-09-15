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

The launcher and server runner require exact clean candidate identity, rerun the full `Setup/Application` regression in a detached worktree, clone current Production through `pg_dump`, apply only supplied candidate migrations/validations to the disposable database, clean all disposable artifacts, and prove Production fingerprint/live Setup SHA are unchanged before success.

Feature-specific behavior belongs in supplied migration/validation files, not in a new disposable runner.

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

`-ValidationPaths` is optional for browser review. Use it only when a validation/preparation SQL is intentionally safe to leave in the disposable browser state.

The browser launcher refuses governed Production listener ports, owns the foreground SSH tunnel, uses the documented runtime, checks the expected health version/Manager capability, and cleans the preview process/listener/database artifacts before returning Production-after proof.

## Legacy feature-specific wrappers

Older feature-specific wrappers remain historical evidence and may contain pinned SHAs/migration sets. Do not copy or patch them for new work when the reusable launchers can express the candidate.

If reusable tooling cannot safely express a future requirement, improve the reusable tooling first and contract-test the improvement rather than substituting ad-hoc interactive SSH.

## Production gate

A green disposable acceptance and accepted browser review do **not** authorize Production mutation by themselves.

After explicit operator approval, consume `Gregovate/MSB-Server-Management` `Production_Database_Change_Deployment_Runbook.md`: verify exact live checkout/services, run detached exact-candidate regression, create/validate rollback archive before mutation, apply only reviewed migrations, validate least privilege/invariants, deploy exact target, verify health/live regression/security boundaries, and retain recovery/report evidence.

## Current Production Acceptance Records

- `Setup_Assignment_Layer_V0313_Production_Acceptance_2026-09-12.md`
- `Setup_Resource_Upsert_Repair_Production_Acceptance_2026-09-13.md`
- `Setup_Kit_Inventory_TPost_Production_Acceptance_2026-09-15.md` — #184 durable Extra Material / Kit Inventory / T-Post subsystem plus completed #167 one-time reconstruction.
