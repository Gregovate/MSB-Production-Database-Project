# LOR Preflight Operator Interface

| Document control | Value |
|---|---|
| Status | Interface template and API contract; backend implementation pending |
| Initial release / current revision | 2026-08-04 / 2026-08-04 |

This directory contains the reusable browser interface for production LOR
reconciliation review. It replaces the hard-coded Run 4 mockup with a run-data
contract. The browser must be published under the protected route:

`https://my.sheboyganlights.org/lor2db/preflight/`

The files are intentionally not a standalone decision system. The browser must
never contain PostgreSQL credentials or write reconciliation tables directly.
A same-origin authenticated backend must implement the endpoints below and
invoke only the installed `ops` views, functions, and procedures.

## Required API

### `GET api/runs/{run_id}`

Returns the frozen run and all decision-required groups. `candidates` may
contain display, stage, scene, or scene-display groups using the same row shape.

```json
{
  "run_id": 4,
  "import_run_id": 45,
  "status": "AWAITING_DECISIONS",
  "candidates": [{
    "group_id": 7590,
    "entity_type": "DISPLAY",
    "entity_key": "DISPLAY:1017",
    "classification_label": "UUID changed, same name",
    "operator_message": "Display has a new LOR UUID.",
    "allowed_actions": ["UPDATE_LOR_LINK", "CORRECT_SOURCE_REQUIRED", "DEFER"],
    "proposed_action": "UPDATE_LOR_LINK",
    "effective_action_id": null,
    "effective_action_type": null,
    "effective_reason": null,
    "current_display_name": "FE-TuneRadio-2CH-01",
    "proposed_display_name": "FE-TuneRadio-2CH-01",
    "facts": [{"label": "Stage", "value": "01"}]
  }]
}
```

The backend reads `ops.v_lor_reconciliation_run_review`,
`ops.v_lor_reconciliation_group_review`, and the four installed entity review
views. It must return persisted effective decisions when the page is reopened.

### `POST api/runs/{run_id}/groups/{group_id}/decisions`

Body:

```json
{
  "action_type": "DEFER",
  "reason": "Investigate unexpected UUID change after Run 3.",
  "expected_action_id": null
}
```

The backend verifies the authenticated operator, run status, run/group
relationship, allowed action, and optimistic `expected_action_id`; then calls
`ops.f_record_lor_reconciliation_action`. It returns the complete refreshed run
document as `{ "run": { ... } }`.

### `POST api/runs/{run_id}/decisions/bulk`

Body: `group_ids`, `action_type`, and `reason`. The backend calls
`ops.f_record_lor_reconciliation_bulk_action`. Every group must independently
allow the selected action. Reassociation cannot use this endpoint.

### `POST api/runs/{run_id}/cancel`

Requires a nonblank reason and a second browser confirmation. The backend calls
`ops.p_cancel_lor_reconciliation`, publishes the cancellation report, and never
runs Finish.

### `POST api/runs/{run_id}/finish`

Requires `READY_TO_FINISH`, zero unresolved groups, an unchanged final-review
decision set, and a second browser confirmation. The backend calls
`ops.p_finish_lor_reconciliation` once and then invokes the existing report
publisher. This is the only production-write endpoint.

## Run 4 acceptance test

Run 4 must remain unchanged until the backend exists. Its five display rows are
the first production-flow acceptance data:

- `FE-TuneRadio-2CH-01`: choose `DEFER` during the interface test.
- `QV-Making-01`, `QV-Bright-01`, and `QV-Spirits-01`: operator selects the
  appropriate missing-from-LOR action; no action is preaccepted.
- `QV-ToolBox`: `ADD_NEW_DISPLAY` is the proposed action, still requiring
  operator acceptance.

Stage, scene, and scene-display sections must render automatically when their
review views return decision-required groups. Empty sections are omitted.
