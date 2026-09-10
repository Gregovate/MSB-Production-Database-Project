# Setup Stage / Scene Browser Preview Regression Finding — 2026-09-10

## Candidate

Failed candidate:

`1aea891bc231bddb41ba13f227534700ab8b7316`

## Result

The browser-preview gate stopped before preview launch because the full Setup application regression reported two stale assertions:

1. `test_setup_internal_analytics_contract.py` still expected `Updated 2026-09-09` while the candidate UI had advanced to `Updated 2026-09-10`.
2. `test_setup_production_contract.py` still expected health version `V0.3.4-shared-season-guard-review` while the candidate application reported `V0.3.5-stage-scene-material-review`.

148 other tests passed. The failure was therefore test-contract drift, not a material-resolution or database-acceptance failure.

## Safety result

The preview runner cleaned up successfully. Production remained unchanged:

- Production Setup fingerprint before/after: `2f8f105d247118a80f8b7337ae799e89`
- live Setup SHA before/after: `f39174c21bb7382c50b6d70d68a2bab1cb7bb098`

## Correction

The candidate regression expectations were updated to the visible 2026-09-10 revision and V0.3.5 health contract. The production contract now also explicitly asserts the new `setup_stage_view.js` asset is present, served, and free of browser-local prototype state.

Corrected candidate head:

`09fe4f884777a819b890594345bd4126ff90cc98`

The browser preview must be rerun from the beginning against that exact SHA because the accepted candidate changed after the failed regression.
