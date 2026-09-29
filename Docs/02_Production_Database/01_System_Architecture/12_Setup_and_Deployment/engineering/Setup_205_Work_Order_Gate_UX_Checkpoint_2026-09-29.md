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

**Hard invariant confirmed 2026-09-29:** `SEASON_ONLY` tasks remain in their originating season permanently. They are never promoted, converted, copied, or written back into the Master reusable task Catalog, and they never seed a future Setup Session. If a recurring need is discovered from annual experience, a separate reusable task must be created through the governed reusable Catalog workflow while the original season-only row remains unchanged as that season's history.

Creation semantics are also explicit:
- Scheduling Board -> **Add Task** asks the Manager to choose reusable or season-only.
- Reusable Task Catalog -> **Add Task** is assumed reusable by definition.
- Scheduling Board -> **Reusable Setup Task — every year** hands off to the same reusable Catalog creation workflow.
- Scheduling Board -> **Season Task Only — this season** remains annual/session-only.

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


## Browser review attempt 1 — stopped on client/server identity mismatch

The first exact-candidate disposable browser preview reached the READY gate on port `8899`, but the first page load correctly failed closed before any operator mutation:

```text
Setup client/server version mismatch.
Client V0.3.20-material-authority;
server V0.3.21-scheduling-gates.
```

Root cause:
- `production_backend.py` had already advanced the server identity to `V0.3.21-scheduling-gates`;
- `setup_catalog_dirty_guard.js` still declared `CLIENT_BUILD = 'V0.3.20-material-authority'`;
- the dirty-guard asset pin also needed a cache-busting refresh.

Correction:
- client build advanced to `V0.3.21-scheduling-gates`;
- visible badge derives from the authoritative client build rather than duplicating a hard-coded minor version;
- dirty-guard asset pin advanced to `2026-09-29.2`;
- regression coverage now compares the server and client build identities directly so a future version bump cannot pass regression with different client/server identities.

Source-fix checkpoint before this documentation commit:
`500dab15be46165673302de56e91fc338599c58f`

Because application code changed after disposable/browser acceptance began, all exact-candidate gates must restart from the final branch head:
1. full Setup/Application regression;
2. reusable disposable current-Production acceptance;
3. fresh disposable browser preview.

The failed preview made no accepted browser mutations and is not reusable for later acceptance.


## Browser review attempt 1 follow-up — shared command version check added

The initial mismatch page continued rendering behind the browser alert. Review showed that the exact client/server version check was wired directly into the older reusable/annual save paths, while newer Setup surfaces use the shared command request path.

Correction:
- `setup_catalog_dirty_guard.js` exposes the exact client/server version check as `window.msbSetupEnsureServerBuild`;
- shared `api()` checks every request created with the governed Setup command header before sending it;
- a command request does not proceed when the version check is unavailable or does not match;
- Scheduling Board and the other Setup command surfaces therefore use the same version-consistency rule;
- `setup_production.js` and `setup_catalog_dirty_guard.js` asset pins were refreshed;
- regression coverage now protects this shared command boundary.

Static JavaScript parse checks after the correction:
- `setup_production.js`: PASS
- `setup_catalog_dirty_guard.js`: PASS

Source checkpoint before this documentation commit:
`ada13aab763833e29281da260ed85b331263732d`

Because this changed application code after the earlier `580 passed` run, exact-candidate regression and disposable/browser acceptance must restart from the final branch head.


## Reusable acceptance lesson promoted — future Setup threads inherit this gate

The first #205 browser-review mismatch proved a gap in the reusable acceptance process, not only in this feature candidate.

The common Setup acceptance tooling is now changed so future Setup work cannot reach server-side disposable/browser testing with different client/server build identities.

Reusable launcher preflight now reads the exact candidate files with `git show`:

```text
Setup/Application/production_backend.py
    PRODUCTION_VERSION

Setup/Application/setup_catalog_dirty_guard.js
    CLIENT_BUILD
```

Before any SCP/SSH/server contact:
- disposable acceptance requires the two build strings to match exactly;
- browser preview requires the two build strings to match exactly;
- browser preview also requires the operator-supplied `-ExpectedVersion` to equal that same exact candidate build.

The durable common authority is:
`Setup/Acceptance/README.md` -> **Mandatory exact client/server build identity gate**.

The reusable tooling contract test now protects this behavior:
`Setup/Application/test_setup_reusable_acceptance_tooling_contract.py`.

This intentionally applies to future Setup threads using the reusable acceptance launchers; it is not limited to #205.

The prior candidate `cb76d28648528d57c2ea2d69a68d1a7e84618024` passed:
- full regression: `581 passed in 1.15s`;
- reusable disposable current-Production acceptance;
- Production fingerprint unchanged: `2e4e1176f52fd083e3803c4e70ff0134`;
- live Setup SHA unchanged: `3cedba88283e4766932ae7905034856a2b9baa00`;
- retained acceptance report: `/home/msbadmin/setup-acceptance-reports/Setup_Disposable_Acceptance_20260929T131346.txt`.

Because the reusable launcher/docs/contracts were then improved, those gates do not transfer to the new exact branch head. Regression and disposable/browser acceptance restart from the new SHA.


## Browser review attempt 2 — placement save permission failure and UX correction

Exact preview candidate:
`f8a168baf6a6bd3a2894c8f58c7877251bd8f3c1`

The corrected client/server identity reached READY and rendered with `Client V0.3.21` and server `V0.3.21-scheduling-gates`.

Operator reviewed the existing 2026 season-only Magic Igloo WO 372 gate and selected the intended annual window:

```text
after:  Layout / Erect Frame / Strap Down
before: Install Skins and Bungees
```

Save failed in the disposable browser with the exact database error:

```text
permission denied for table setup_session_task
```

### Root cause

The new placement repository path performed a direct:

```sql
SELECT setup_session_id, task_origin
FROM ops.setup_session_task
WHERE setup_session_task_id = ...
FOR UPDATE
```

The disposable application role intentionally has broad Setup SELECT plus narrow SECURITY DEFINER command EXECUTE, but does not have broad table UPDATE/DML. PostgreSQL row locking through `FOR UPDATE` crosses that least-privilege boundary, so the command correctly failed.

The row lock was unnecessary because the actual annual dependency and planned-order mutations already go through governed SECURITY DEFINER commands.

### Correction

- remove the direct `FOR UPDATE` from the season-placement read;
- retain the season-only identity check with ordinary SELECT;
- continue all dependency/planned-order writes through:
  - `ops.set_setup_session_task_dependency(...)`;
  - `ops.set_setup_session_task_planned_order(...)`.

The browser Save path is also tightened so task-definition changes and requested placement are one database transaction instead of two separate HTTP mutations:
- season-only create + initial dependency placement are atomic;
- season-only edit + dependency reconciliation + planned-order update are atomic;
- a dependency/cycle/permission failure rolls the whole Save back instead of leaving a partially updated task.

### Placement UX correction from operator review

The original labels were too implementation-oriented:

```text
Place after / requires
Before / blocks
```

Accepted replacement wording:

```text
This task happens after (optional)
This task must happen before (optional)
```

The controls move immediately below the Work Order/gate section and above Crew min / Crew max.

Both sides are optional. Use one side when one constraint is sufficient. Use both only when the annual exception truly belongs between two Setup steps. WO 372 is intentionally two-sided because the frame must exist before welding and skins must wait until the weld repair is complete.

An inline error area is added inside the season-task dialog and this save path no longer depends on an immovable native browser alert to expose command errors.

### Magic Igloo second annual exception

The accepted #205 baseline still requires the separate 2026 season-only WO 156 gate:

```text
Install Skins and Bungees
    -> WO 156 manufacturer skin repair
    -> Install Lighting, Cameras, Mats, Signs, and Finish Setup
```

WO 156 remains annual-only and must not be recreated as reusable Catalog work.

Source checkpoint before this documentation commit:
`cdf686cf6aece7b0f3df5b21c3b60ddd5bc26b38`

Because application/API/repository behavior changed, the prior `582 passed`, disposable PASS, and browser READY evidence do not transfer to the new exact candidate. Restart exact-candidate regression, reusable disposable acceptance, and browser review after clean teardown of the current preview.

No Production mutation occurred.
