# Setup Reconstruction Migration and Acceptance History — 2026-09-07 to 2026-09-09

| Document Control | Value |
|---|---|
| Document Type | Engineering Migration / Acceptance History |
| System | Production Database — Setup Session |
| Status | HISTORICAL ENGINEERING RECORD — not a current Production runbook |
| Owner | MSB Production Database engineering |

## Purpose

Preserve the material migration, disposable-clone, browser-acceptance, and reconstruction-cleanup findings encountered while moving Setup from the small 2025 Historical Verification foundation to the reconstructed reusable Catalog.

Use the current [`README.md`](README.md) for present Production state and resume direction.

## Production Safety Boundary Used During Reconstruction

The reconstruction work deliberately separated Production evidence from test writes:

- Production could be inspected and fingerprinted;
- feature writes and migration probes ran against disposable PostgreSQL clones first;
- a disposable failure stopped that acceptance attempt;
- corrected candidates were rerun from a fresh exact candidate;
- Production fingerprint/live-checkout checks proved failed disposable attempts had not mutated Production; and
- Production mutation remained governed by the Production Database deployment runbook and rollback requirements.

## Repeated PL/pgSQL Ambiguity Defect Class

Several governed commands exposed the same PostgreSQL/PLpgSQL failure class: a `RETURNS TABLE` output name is also a function variable, so unqualified SQL identifiers with the same name can become ambiguous.

Accepted engineering rule:

1. qualify relation/CTE column references;
2. prefer `ON CONFLICT ON CONSTRAINT <name>` over bare conflict-column lists when output-variable names can collide; and
3. execute the real governed command in disposable acceptance rather than trusting migration-install success alone.

### Migration 013

Reusable task creation exposed:

```text
column reference "setup_task_id" is ambiguous
```

The fix replaced a bare conflict-column target with the named `uq_setup_session_task` constraint.

### Migration 015

The same conflict-target hardening was applied to remaining governed resource/dependency/work-day-task commands using their named constraints.

### Migration 018

Dependency cycle prevention still had an unqualified `setup_task_id` reference inside a recursive CTE. The correction explicitly qualified the CTE alias.

### Migration 020

Captain assignment reproduced the same ambiguity with `(setup_task_id, person_id)`. The correction pinned `pk_setup_task_captain`.

The failed disposable run left Production unchanged and required a fresh acceptance cycle.

## Production Migration Sequence Must Be Explicit

Migration numbering alone is not proof that every SQL file belongs in Production.

During the earlier Production-foundation promotion, migration 012 was intentionally excluded because it contained disposable browser-review/reset behavior. The durable Production path was stated explicitly and later extended by reviewed Setup migrations.

Permanent rule: review and state the exact Production migration set; never infer it from numeric filenames alone.

## Acceptance Harness Findings

### Function privilege mirror called a PROCEDURE as a function

A browser-preview privilege-mirror query scanned `pg_proc` too broadly and called `has_function_privilege()` on a PostgreSQL procedure. The correction limited the mirror to actual functions/window functions (`prokind IN ('f','w')`).

### Effort API leaked retired rows

Disposable Catalog validation correctly distinguished active reusable tasks from total reusable rows, while the effort API initially returned retired rows too. The application reader was corrected to require `active_flag`.

### Preview cleanup used the wrong process owner

The preview Flask process ran as `fieldwiring`, but cleanup initially attempted to kill it as `msbadmin`. A stale listener could remain on the preview port and contaminate the next acceptance attempt.

The harness was corrected to terminate preview-owned processes with the required privilege and to treat runtime process ownership as part of acceptance design.

## Accepted Catalog Reconstruction Baseline

The 2026-09-09 reconstruction deployment established current PostgreSQL reusable tasks as the working Catalog baseline. The reviewed workbook, 2025 notes, and recovered 2022 schedule remain historical/reconstruction evidence, not a second task master.

The accepted reconstruction intentionally reset dependencies for later deliberate rebuilding.

## Post-Deployment Correctness Findings

### Missing physical Frosty task

Historical `Bring Frosty to park` was correctly treated as transport/logistics evidence, but the separate physical reusable work `Set Up Frosty` was missing. This established the rule that filtering transport language is not enough; the physical work implied by history still must be represented when it is a real reusable task.

### Reconstruction mistakes can have no annual row

Some duplicate/bad reusable definitions created during reconstruction have no `ops.setup_session_task` row at all. They are Catalog reconstruction mistakes, not historical annual records.

The governed reconstruction-delete command supports Catalog-only deletion while failing closed when protected planning/execution history exists. The UI was corrected so Manager Delete Task does not require an annual row before the governed command can be attempted.

### 2026 propagation risk

Later Production review confirmed that annual Session creation seeds every active reusable task into the new Session. Therefore unresolved reconstruction duplicates must be removed/deactivated before 2026 creation. This is tracked by Issue #145.

## Engineering Rule Carried Forward

For future Setup migrations, static SQL review and successful installation are not sufficient acceptance for governed PL/pgSQL commands.

At minimum use:

- exact candidate pinning;
- disposable current-Production clone where feasible;
- execution of changed governed write paths;
- authorization/negative-path checks;
- cleanup proof;
- Production fingerprint/live-checkout proof around failed gates; and
- a fresh rerun after correction.

## Related Evidence

- [`Setup_Catalog_Reconstruction_Import_2026-09-09.md`](Setup_Catalog_Reconstruction_Import_2026-09-09.md)
- [`Setup_Training_Browser_Acceptance_2026-09-08.md`](Setup_Training_Browser_Acceptance_2026-09-08.md)
- [`Setup_2025_Live_Review_Work_Ledger_2026-09-08.md`](Setup_2025_Live_Review_Work_Ledger_2026-09-08.md)
- [`Setup_Stage_Scene_Production_Acceptance_2026-09-11.md`](../../../../../Setup/Acceptance/Setup_Stage_Scene_Production_Acceptance_2026-09-11.md)
- Issue #122
- Issue #145
