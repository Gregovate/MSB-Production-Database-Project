# Setup Reconstruction Migration and Acceptance History — 2026-09-07 to 2026-09-09

| Document Control | Value |
|---|---|
| Document Type | Engineering Migration / Acceptance History |
| System | Production Database — Setup Session |
| Status | HISTORICAL ENGINEERING RECORD — preserves accepted reconstruction/deployment findings; not a current Production runbook |
| Owner | MSB Production Database engineering |
| Related Work | Issue #122; PR #125; PR #137; Setup Catalog Reconstruction Import |

## Purpose

Preserve the material migration, disposable-clone, browser-acceptance, and reconstruction-cleanup findings encountered while moving the Setup subsystem from the small 2025 Historical Verification foundation to the accepted reusable Catalog reconstruction.

This record exists because several important failures were discovered only when the real governed Setup commands and Production-like disposable environment were exercised. Those findings must not be reconstructed from chat history or rediscovered by a later migration.

For the current deployed state and resume point, use [`README.md`](README.md). For the final one-time Catalog import result, use [`Setup_Catalog_Reconstruction_Import_2026-09-09.md`](Setup_Catalog_Reconstruction_Import_2026-09-09.md).

## Production Safety Boundary Used During Reconstruction

The reconstruction work deliberately separated Production evidence from test writes.

- Production could be inspected and fingerprinted.
- Feature writes and migration probes were performed against disposable PostgreSQL clones before Production consideration.
- A disposable failure stopped that acceptance attempt and required a corrected exact candidate to be rerun.
- Production fingerprint / live-checkout checks were used to prove that failed disposable acceptance had not mutated Production.
- Final Production mutation remained subject to the Production Database deployment runbook and rollback requirements.

This boundary was important because the disposable gates found real SQL defects before the corresponding feature writes could reach Production.

## Repeated PL/pgSQL Ambiguity Defect Class

A major recurring defect was caused by the interaction between `RETURNS TABLE` output names and unqualified SQL identifiers inside PL/pgSQL.

In PL/pgSQL, `RETURNS TABLE` output columns are also function variables. A bare column name can therefore become ambiguous when a table/CTE column uses the same name.

The accepted correction pattern is:

1. qualify table and CTE column references with relation aliases;
2. prefer `ON CONFLICT ON CONSTRAINT <governed_constraint_name>` instead of a bare column-list conflict target when function variables can collide with column names; and
3. exercise the actual governed command in a disposable database, not only migration syntax or static contract tests.

### Migration 013 — reusable task creation

[`013_fix_setup_task_creation_command.sql`](../../../../../Setup/Database/013_fix_setup_task_creation_command.sql) exists because Manager browser acceptance exposed:

```text
column reference "setup_task_id" is ambiguous
```

`ref.create_setup_task(...)` returns a column named `setup_task_id`. The original:

```sql
ON CONFLICT (setup_session_id, setup_task_id)
```

could collide with that PL/pgSQL output variable.

The correction targets the existing governed unique constraint explicitly:

```sql
ON CONFLICT ON CONSTRAINT uq_setup_session_task DO NOTHING
```

No schema shape or authorization expansion was required.

### Migration 015 — harden the remaining conflict targets

[`015_harden_setup_command_conflict_targets.sql`](../../../../../Setup/Database/015_harden_setup_command_conflict_targets.sql) generalized the same finding instead of waiting for each command to fail independently.

It replaced bare conflict targets with named constraints in:

```text
ref.set_setup_task_resource(...)
ref.set_setup_task_dependency(...)
ops.set_setup_work_day_task(...)
```

using:

```text
pk_setup_task_resource
pk_setup_task_dependency
pk_setup_work_day_task
```

Migration 013 remained the separate correction for reusable-task creation.

This was an important migration-design correction: a command can parse, install, and still fail only when a specific write path executes.

### Migration 018 — dependency cycle CTE still had an unqualified name

[`018_fix_setup_dependency_cycle_reference.sql`](../../../../../Setup/Database/018_fix_setup_dependency_cycle_reference.sql) fixed the remaining ambiguity in `ref.set_setup_task_dependency(...)` after migration 015.

The conflict target had already been hardened, but the recursive cycle-prevention query still referenced `setup_task_id` without a relation alias. Because the function also returns `setup_task_id`, PostgreSQL could interpret that identifier as either the recursive CTE column or the PL/pgSQL output variable.

The correction explicitly uses the CTE alias:

```sql
FROM prerequisite_chain c
WHERE c.setup_task_id = p_setup_task_id
```

The function signature, authorization, and cycle-prevention behavior remained unchanged. Live browser acceptance later passed when a real Mega Tree prerequisite was added, proving the corrected command path rather than only the migration installation.

### Migration 020 — Captain assignment failed in disposable feature validation

[`020_add_setup_captain_management_commands.sql`](../../../../../Setup/Database/020_add_setup_captain_management_commands.sql) exposed the same defect class during the 2026-09-08 training/reconstruction disposable gate.

The candidate migrations reached 019/020/021 on a current Production clone, but feature validation failed inside `ref.set_setup_task_captain(...)` before the Captain assignment completed. The original column-list conflict target:

```sql
ON CONFLICT (setup_task_id, person_id)
```

was ambiguous because the function also returns `setup_task_id` and `person_id`.

The correction pins the existing primary key:

```sql
ON CONFLICT ON CONSTRAINT pk_setup_task_captain
```

The failed run left the Production Setup fingerprint unchanged:

```text
a2a84fc3f162f2f30914c909710976cf
```

No Production mutation occurred. The corrected candidate then required a fresh disposable acceptance run.

## Production Migration Path Had To Exclude Disposable-Only SQL

During the earlier Production-foundation promotion, the durable migration path was explicitly separated from browser-preview/reset SQL.

The reviewed durable sequence at that stage was:

```text
008 -> 009 -> 010 -> 011 -> 013 -> 014 -> 015 -> 016
```

Migration 012 was **not** a Production migration because it contained disposable browser-review execution resets. Migration 016 was the Production-safe Command Center / Park Infrastructure reconstruction seed.

Later correction/training work added the subsequently accepted migrations through 022 before Catalog migrations 023/024 were deployed.

The durable lesson is that migration numbering alone is not evidence that every SQL file belongs in the Production path. The Production sequence must be stated and reviewed explicitly.

## Disposable / Browser Acceptance Harness Findings

The Catalog reconstruction itself also exposed failures in the acceptance harness. These were important because a broken gate can either block a correct candidate or, worse, give misleading evidence about what was actually validated.

### Function privilege mirror called a PROCEDURE as a function

A Catalog browser-preview run failed before candidate migrations because the Production privilege-mirror query scanned `pg_proc` and called `has_function_privilege()` on `ref.apply_display_metadata_from_sheet()`, which is a PostgreSQL `PROCEDURE`.

PostgreSQL correctly rejected that call as:

```text
is not a function
```

The correction restricted function-privilege mirroring to actual functions/window functions:

```text
p.prokind IN ('f','w')
```

The failure did not change the Production fingerprint or shared checkout.

### Active Catalog count was correct but the effort API leaked retired rows

Disposable Catalog validation correctly produced:

```text
185 active reusable tasks
187 total reusable rows
```

But `/api/setup/task-efforts` returned 187 because the reader selected all `ref.setup_task` rows, including the two intentionally retired provisional identities 40 and 58.

This was an application/API correctness defect, **not** a failed Catalog import.

The correction added the active-row boundary:

```sql
WHERE active_flag
```

Because the application surface changed, the application/database candidate required re-acceptance rather than treating the Catalog count discrepancy as harmless.

### Preview cleanup used the wrong process owner

The same browser-preview cycle exposed a cleanup defect. Flask ran as the `fieldwiring` runtime identity, while the preview trap attempted plain `kill` as `msbadmin`.

Result:

- the preview listener could remain on port 8795;
- cleanup could replace the original failure with exit 99; and
- a stale listener could contaminate the next acceptance attempt.

The harness was corrected to use privileged termination where required and to recognize the Catalog-preview process/container/worktree patterns during stale cleanup.

This is why runtime-account ownership is part of acceptance design, not merely a server-administration detail.

## One-Time Catalog Reconstruction Result

After the correction and acceptance cycle, migrations 023/024 produced the accepted Production baseline:

```text
Setup runtime SHA                    = 5a8a317357ffa5d77c38bc4df63fe6c7b451dbaf
active reusable tasks                = 185
total reusable task rows             = 187
reusable dependencies                = 0
2026 Setup Sessions                  = 0
Production Setup fingerprint         = f0b98ac75e297a08eabc3df040708c08
```

The reviewed workbook, 2025 notes, and recovered 2022 schedule are now reconstruction/historical evidence. They are not a second task master. Current PostgreSQL reusable tasks are the working Catalog baseline.

## Reconstruction Correctness Findings After Deployment

Production acceptance of the bulk import did not mean every reconstructed task boundary was permanently correct. The import deliberately depended on later live review to catch omissions, duplicate boundaries, and ambiguous historical shorthand before 2026 planning copied the Catalog forward.

### Missing physical Frosty task

Historical `Bring Frosty to park` evidence was correctly excluded as transport/logistics, but no separate reusable physical `Set Up Frosty` task was created.

The required correction is to add the real physical setup work to the current Catalog and make it a predecessor of the applicable Stars setup work during the predecessor/readiness pass. Transport remains logistics.

This is a concrete example of why historical filtering cannot merely remove logistics phrases; it must also verify that the physical work implied by the history still has a reusable task definition.

### Reconstruction mistakes may have no annual historical row

A later cleanup finding corrected an important assumption in the Manager UI.

Some duplicate/bad reusable Catalog definitions introduced during reconstruction/merge have **no `ops.setup_session_task` annual row at all**. They are Catalog reconstruction mistakes, not historical annual records. Leaving them in the Catalog would propagate bad definitions into 2026.

The existing governed database command:

```text
ref.delete_setup_reconstruction_task(...)
```

already supports Catalog-only deletion and fails closed when protected planning/execution history exists.

The UI regression incorrectly hid Delete unless historical-session / annual-row context was present. PR #137 restores Manager **Delete Task** for a selected reusable Catalog task without requiring an annual historical record, while retaining the database guardrails.

This refines the earlier reconstruction-delete rule:

- if a mistaken reconstruction task has only its provisional annual inclusion, safe delete may remove that annual shell and reusable definition together;
- if a mistaken reusable Catalog definition has no annual row, safe delete must still be available;
- once protected planning, progress, work-day, movement, or execution history exists, destructive cleanup must fail closed and the normal retire/remove workflow applies instead.

## Current Resume Point

Do not create the 2026 Setup Session yet.

Resume from the current Production PostgreSQL Catalog, not from the reconstruction workbook:

1. disposable/browser-accept PR #137 against a Catalog-only mistaken/duplicate task and verify the governed fail-closed behavior;
2. remove confirmed reconstruction duplicates/bad reusable definitions before they can be propagated into 2026;
3. add/correct missing real reusable work such as `Set Up Frosty`;
4. perform the reviewed predecessor/readiness pass, distinguishing **hard predecessor**, **preferred order**, and **area-specific readiness condition**; and
5. only then proceed toward the short-horizon 2026 planning/session gate.

## Engineering Rule Carried Forward

For future Setup migrations, static SQL review and migration-install success are not sufficient acceptance for governed PL/pgSQL commands.

At minimum, candidate acceptance should include:

- exact-candidate pinning;
- disposable PostgreSQL built from current Production state where feasible;
- execution of the governed write paths the migration changes;
- negative-path / authorization checks;
- cleanup proof;
- Production fingerprint/live-checkout proof around failed disposable attempts; and
- explicit rerun from the corrected exact candidate after a failure.

When a `RETURNS TABLE` PL/pgSQL function uses names that also exist in tables/CTEs, qualify the SQL references and prefer named constraints for conflict targets.

## Related Evidence

- [`Setup_Catalog_Reconstruction_Import_2026-09-09.md`](Setup_Catalog_Reconstruction_Import_2026-09-09.md)
- [`Setup_Training_Browser_Acceptance_2026-09-08.md`](Setup_Training_Browser_Acceptance_2026-09-08.md)
- [`Setup_2025_Live_Review_Work_Ledger_2026-09-08.md`](Setup_2025_Live_Review_Work_Ledger_2026-09-08.md)
- Issue #122 — annual Setup Session engineering/reconstruction umbrella
- PR #125 — Setup Production foundation / accepted Catalog lineage
- PR #137 — restore Catalog-only reconstruction Delete Task UI
