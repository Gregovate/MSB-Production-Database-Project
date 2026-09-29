# Setup #205 — Work Order Gate / Annual Hold Engineering Checkpoint — 2026-09-29

| Document Control | Value |
|---|---|
| Document Type | Engineering checkpoint |
| System | Production Database — Setup and Deployment |
| Owning issue | #205 under #122 |
| Status | IMPLEMENTATION COMPLETE — REGRESSION / DISPOSABLE ACCEPTANCE NOT YET RUN |
| Branch | `agent/setup-205-work-order-gate-ux` |
| Accepted Production base | `3cedba88283e4766932ae7905034856a2b9baa00` |
| Accepted Production version before this candidate | `V0.3.20-material-authority` |
| Candidate application identity | `V0.3.21-scheduling-gates` |
| Implementation code checkpoint before this document | `08d1d7d5a3dead0dab8020b417087a8d445cacd7` |

## Why this work became blocking

Live 2026 Setup / #206 review exposed that the annual Magic Igloo dependency graph could not be maintained correctly from the Scheduling Board.

The real 2026 plan needs the season-only Work Order gates:

```text
Layout / Erect Frame / Strap Down
    -> WO 372 — Magic Igloo Weld Repairs
    -> Install Skins and Bungees
    -> WO 156 gate
    -> Install Lighting, Cameras, Mats, Signs, and Finish Setup
```

Those gates are 2026 annual facts. They must not become reusable Catalog tasks.

The same review also exposed a 2026-only road/site-work readiness hold. That hold must not be written into reusable `ref.setup_task.readiness_note`.

Until the annual graph and annual-only hold are trustworthy, #206 cannot safely decide whether downstream material-frontier behavior is wrong.

## Repository / concurrency boundary

This branch intentionally starts from the exact accepted/live Setup application SHA:

`3cedba88283e4766932ae7905034856a2b9baa00`

It does **not** start from stale repository `main`, and it does **not** include the additional unaccepted #206 Pick List commits.

This keeps the priority #205 correction isolated from the parallel #206 workstream.

## Implemented correction

### 1. Work Order discovery

The season-only task dialog no longer presents the complete open Work Order list when search is blank.

The operator can search by:
- WO number;
- `WO <number>`;
- problem-text terms.

Search terms are matched case-insensitively and all entered terms must be present in the Work Order ID/problem text.

Visible result buttons are rendered directly under the search field. Selecting a result makes it the current linked Work Order. The already-linked Work Order remains visible when editing an existing gate.

A clear action explicitly returns the annual task to no linked Work Order.

Representative required searches for WO 372:
- `372`;
- `Magic Igloo`;
- `broken welds`;
- `weld`.

### 2. Existing season-only gate placement

The edit dialog no longer hides annual placement controls for an existing season-only task.

The dialog now exposes:
- **Place after / requires**;
- **Before / blocks**.

For an existing gate, the application derives the closest visible prerequisite/downstream placement from the current annual dependency graph.

If additional annual prerequisite/downstream edges exist, they are preserved and explicitly listed as additional dependencies rather than silently removed.

The application uses the existing governed annual commands:
- `ops.set_setup_session_task_dependency(...)`;
- `ops.set_setup_session_task_planned_order(...)`.

The new placement API/repository path changes only the selected visible placement edge on each side and planned order in one database transaction. Existing same-session and circular-dependency protection remains in the database command layer.

No new dependency table or schema is introduced.

### 3. Annual-only readiness / hold

The Scheduling Board now exposes **Annual readiness…** for an unworked annual task.

The dialog is explicitly labeled:

`THIS SEASON ONLY`

It edits:
- annual READY / NOT_READY state;
- annual readiness/hold reason.

It does not call `ref.update_setup_task` and therefore does not change reusable Catalog readiness knowledge.

The implementation reuses the existing annual command surfaces:
- `ops.update_setup_annual_task_definition(...)` for the annual readiness note while preserving the other annual definition fields;
- `ops.set_setup_annual_task_readiness(...)` for annual READY / NOT_READY state.

Actual/progress evidence blocks this annual planning edit.

This is the intended path for the 2026 Magic Igloo road/site-work hold.

### 4. Existing quick readiness action

The existing quick Mark Ready / Mark Not Ready action now uses the annual-only hold path, preserving the annual reason text instead of writing reusable readiness knowledge.

It is hidden once progress/completion makes the annual planning fact historical.

## Schema / migration conclusion

No schema gap has been proven for this priority correction.

Existing annual identity, dependency, planned-order, readiness-note, readiness-state, and Work Order-link fields are sufficient for the currently accepted 2026 workflow.

There is therefore **no migration in this candidate**.

A structured annual `not_before` field remains unproven and is not introduced here.

## #206 boundary

This candidate does not modify:
- `downstream_material_frontier()`;
- Pick List deadline sorting;
- physical material authority;
- movement state.

The annual hold must not be interpreted as permission to hide downstream material need.

After #205 browser acceptance, #206 must re-test its frontier against the corrected real 2026 Magic Igloo graph before changing frontier semantics.

## Candidate files

Application:
- `Setup/Application/setup_scheduling_board.js`
- `Setup/Application/setup_scheduling_board.css`
- `Setup/Application/setup_scheduling_board_api.py`
- `Setup/Application/setup_scheduling_board_repository.py`
- `Setup/Application/production.html`
- `Setup/Application/production_backend.py`

Contracts:
- `Setup/Application/test_setup_scheduling_board_contract.py`
- `Setup/Application/test_setup_production_contract.py`

## Current validation

Completed:
- JavaScript parse check: PASS.
- Static contract coverage added for Work Order search, editable gate placement, governed annual dependency/planned-order calls, and annual-only readiness.

Not yet completed:
- full `Setup/Application` regression;
- reusable disposable current-Production-clone acceptance;
- exact-candidate browser review;
- Production deployment.

## Next gates

1. Run full `Setup/Application` regression on the exact current branch head.
2. If green, run reusable disposable current-Production acceptance with **no migration paths**.
3. Launch a fresh disposable browser preview on the same exact SHA.
4. Browser acceptance must prove:
   - problem-text search finds WO 372 without knowing the number;
   - blank Work Order search does not dump the full open-WO list;
   - existing WO 372 gate opens with placement controls visible;
   - WO 372 can be placed after Layout / Erect Frame / Strap Down and before Install Skins and Bungees;
   - WO 156 can be placed after Install Skins and Bungees and before Install Lighting...;
   - circular dependencies still fail closed;
   - additional unrelated annual dependency edges are preserved;
   - a reusable-origin annual Magic Igloo task can receive a 2026-only NOT_READY road/site-work reason without altering reusable Catalog readiness;
   - clearing/marking that annual hold Ready changes only annual planning state;
   - Setup health reports `V0.3.21-scheduling-gates`.
5. Only after that acceptance should #206 retest Magic Igloo downstream material demand.

## Production boundary

No Production mutation is authorized by this checkpoint.

Before any Production deployment, retrieve and read the current Server Management source-only Setup application deployment authority in the deployment workstream and follow the Runbook-First Production Rule.
