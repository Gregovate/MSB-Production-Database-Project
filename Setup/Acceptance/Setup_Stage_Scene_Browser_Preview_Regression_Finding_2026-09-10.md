# Setup Stage / Scene Browser Preview Regression Findings — 2026-09-10

## Scope

Two browser-preview attempts stopped during the exact-candidate regression phase before any temporary browser was launched. Both failures were candidate/test wiring mistakes. Production remained unchanged in both runs.

## Failure 1 — stale visible-version assertions

Failed candidate:

`1aea891bc231bddb41ba13f227534700ab8b7316`

The full Setup regression reported two stale assertions:

1. `test_setup_internal_analytics_contract.py` still expected `Updated 2026-09-09` while the candidate UI had advanced to `Updated 2026-09-10`.
2. `test_setup_production_contract.py` still expected health version `V0.3.4-shared-season-guard-review` while the candidate application reported `V0.3.5-stage-scene-material-review`.

148 other tests passed.

Correction: update the tests to the current visible date/version contract.

## Failure 2 — Stage-order asset naming mismatch

Failed candidate:

`8bf71b898ce946e9f0855f0940e9ebbd2aec4154`

The full Setup regression reported three failures because `test_setup_production_contract.py` required a nonexistent asset name `setup_stage_view.js`.

The actual candidate implementation consistently used:

```text
setup_stage_order.js
setup_stage_order.css
```

`production.html` already loaded those names and `production_backend.py` already served those names. The regression test alone used the wrong `setup_stage_view.js` name.

147 other tests passed.

Correction: align `test_setup_production_contract.py` with the actual `setup_stage_order.js` / `setup_stage_order.css` assets.

## Password-prompt / preflight finding

Each server-side browser-preview attempt requires repeated interactive authentication. Candidate static-wiring failures should therefore be caught before SCP/SSH/sudo.

The browser-preview PowerShell wrapper now performs a local no-password gate before contacting the server. It verifies:

- local HEAD equals the requested candidate SHA;
- local worktree is clean;
- exact candidate contains the Stage-order JS/CSS and required material files;
- `production.html` loads the Stage-order assets;
- `production_backend.py` serves the Stage-order assets; and
- no stale `setup_stage_view` reference remains in `Setup/Application`.

This does not replace the server-side exact-candidate regression. It prevents obvious candidate wiring mistakes from consuming operator password prompts.

## Safety result

Both failed preview attempts cleaned up successfully. Production remained unchanged:

- Production Setup fingerprint before/after: `2f8f105d247118a80f8b7337ae799e89`
- live Setup SHA before/after: `f39174c21bb7382c50b6d70d68a2bab1cb7bb098`

No Production database/application/runtime mutation occurred.
