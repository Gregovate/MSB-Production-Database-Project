# Controller Inventory Stage Search Context — 2026-08-31

| Item | Value |
|---|---|
| Status | CURRENT |
| Issue | #110 |
| Application | FieldWiring Controller Inventory browser |

## Operator problem

Controller Inventory free-text search supports Controller, Display, Stage/Sub-stage, model, serial, location, and programmed-configuration values.

A partial Stage search such as:

```text
raci
```

can correctly return the controllers assigned through Displays to:

```text
25-Racing Arches-RA
```

but a result count alone does not tell the operator that the Stage name was what matched. That makes a correct result set look ambiguous.

## Accepted behavior

Free-text search remains free text. It does **not** silently change the explicit Stage/Sub-stage dropdown.

When the entered search text matches one or more Stage/Sub-stage choices, the Controller browser shows an explicit search-context confirmation beneath the filters.

Example:

```text
Stage search match: 25-Racing Arches-RA
```

If more than one Stage/Sub-stage name matches, the browser identifies all matched Stage contexts.

When the operator selects the Stage/Sub-stage dropdown directly, the dropdown itself remains the explicit Stage context and the free-text Stage-match banner is hidden.

## Data boundary

Stage remains derived through current Display assignments:

```text
ref.controller
  -> ref.controller_display
    -> ref.display
      -> ref.stage
```

No `stage_id` is added to `ref.controller` for this UI behavior.

The Stage-match confirmation is presentation only. It does not alter controller identity, assignment relationships, or filter state.

## Regression coverage

Automated coverage is in:

```text
FieldWiring/Application/test_controller_stage_search_context.py
```

The test requires the visible search-context element and verifies that the helper does not assign a value to the Stage/Sub-stage dropdown.
