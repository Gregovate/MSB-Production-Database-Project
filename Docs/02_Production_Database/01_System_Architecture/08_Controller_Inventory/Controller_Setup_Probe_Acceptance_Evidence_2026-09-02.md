# Controller Setup Probe Acceptance Evidence — 2026-09-02

| Item | Value |
|---|---|
| Status | PARTIAL PASS — DISPOSABLE HARNESS RETRY REQUIRED |
| Issue | #110 |
| Draft PR | #111 |
| Application candidate | `2fd2067958cc0a903260fe6f089f88ae63a857f1` |
| Production application baseline | `e9ab029a17067b38b34f9306069f54899925f73f` |
| Acceptance wrapper | `Controllers/Acceptance/run_controller_setup_probe_disposable_acceptance.ps1` |
| Production mutation | NONE |

## Purpose

Record the first acceptance run that reached the real 2026 Controller planning/probing gates and preserve the exact reason the disposable write test did not complete.

This evidence is operationally important because the planner itself passed against current production data. The remaining failure was in disposable PostgreSQL container startup timing, not in Controller planning, Controller maintenance code, authorization, or production data.

## Detached Application Regression

Exact candidate:

```text
2fd2067958cc0a903260fe6f089f88ae63a857f1
```

Result:

```text
231 passed in 2.65s
DETACHED CONTROLLER PROBE/MAINTENANCE REGRESSION: PASS
```

This validated the candidate FieldWiring + Procedures application test suites before any planner data probe or disposable write testing.

## Current Production Read-Only Planner Probe

The acceptance wrapper queried the live production database read-only using the existing `fieldwiring_app` planner read boundary.

Observed current production evidence:

```text
planner numeric UID rows       = 1786
planner programmed Controllers = 168
planner Stages                 = 38
planner Regular rows           = 1159
planner multi-UID models       = 5
```

Result:

```text
PLANNER PRODUCTION READ PROBE: PASS
```

This establishes that the current production system contains enough governed data for the setup planner to provide:

- Network-scoped numeric UID usage;
- physical Controller current-programming overlay;
- Stage selection;
- `Regular` network context;
- model-aware multi-UID / contiguous UID planning.

## Current Production Direct-Stage SPARE Probe

The read-only direct-stage SPARE attribution query returned:

```text
direct_stage_spare_rows=116
```

This is strong evidence that the current LOR/V7 materialization contains useful directly attributable Stage/SPARE data for the first setup planner implementation.

Shared/master Preview SPARE rows remain deliberately unguessed when direct physical/Stage attribution cannot be proven.

## Production Safety Evidence

Before the disposable clone test:

```text
production Controller fingerprint = 578217bcb18e1291ceced673a3de3b27
controllers                         = 177
assignments                         = 194
```

After the failed disposable restore attempt:

```text
production Controller fingerprint = 578217bcb18e1291ceced673a3de3b27
```

Result:

```text
PASS: production Controller fingerprint unchanged
```

The setup probe parent remained SELECT-only against production. No candidate Controller maintenance migration was applied to production.

## Disposable PostgreSQL Failure

A current production dump was successfully captured and structurally validated:

```text
14M production dump
```

The disposable PostgreSQL container started and `pg_isready` returned success, after which the harness immediately created the disposable database and began `pg_restore`.

During restore PostgreSQL terminated the connection with:

```text
FATAL: terminating connection due to administrator command
server closed the connection unexpectedly
```

The visible restore statement at termination happened to be a COMMENT on `ops.v_lor_reconciliation_operator_stage_review`; that object is not considered the cause.

### Root cause

The newer Controller management disposable harness waited only for `pg_isready` after starting a brand-new `postgis/postgis:16-3.5` container.

The official PostgreSQL Docker entrypoint uses a temporary initialization server that can briefly satisfy `pg_isready`, then intentionally shuts that temporary server down before starting the final PostgreSQL process. Starting `pg_restore` during that interval can therefore terminate the restore with `administrator command`.

The older Controller label disposable harness already contained the correct sequence:

```text
wait for Docker log marker:
    PostgreSQL init process complete; ready for start up

then:
    wait for final pg_isready

then:
    createdb / pg_restore
```

The setup wrapper has been corrected to patch the child management harness to that proven sequence before transfer/execution.

It also now captures disposable PostgreSQL logs as failure evidence before container cleanup when a future clone test fails.

## Current Resume Point

Application candidate remains unchanged:

```text
2fd2067958cc0a903260fe6f089f88ae63a857f1
```

Do not repin the application merely because the disposable acceptance infrastructure changed. The candidate application already passed regression and the real production planner probe.

Rerun:

```powershell
git pull --ff-only origin agent/controller-inventory-ref-sandbox
powershell -ExecutionPolicy Bypass -File .\Controllers\Acceptance\run_controller_setup_probe_disposable_acceptance.ps1
```

The rerun should repeat the exact application regression and production read-only planner probe, then wait for final disposable PostgreSQL startup before restoring and executing Controller maintenance migrations 023/024 in the disposable clone only.

Production deployment remains a separate explicit gate after the full disposable acceptance passes.
