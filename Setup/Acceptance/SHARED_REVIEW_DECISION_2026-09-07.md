# Setup Shared Review Decision — 2026-09-07

Decision: use the real 2025 `HISTORICAL_VERIFICATION` Setup Session as a shared Production-backed review/training area behind authenticated Setup access.

Current runtime status:

```text
Production application = https://my.sheboyganlights.org/setup/
runtime deployment     = ACCEPTED
UI/workflow             = LIVE EVALUATION
```

Safety controls:

- all operator-entered operational dates are constrained to the selected Setup Session year;
- the database independently enforces the same year boundary;
- `America/Chicago` is used for historical operational timestamp year checks;
- audit/recording timestamps remain current and are not rewritten into the historical year;
- Managers/reviewers may improve 2025 annual data and reusable Setup knowledge;
- only Administrators may create annual Setup Sessions or promote annual order into the future reusable baseline;
- no 2026 Setup Session was created by the V0.3.4 promotion;
- Pick List generation is not yet a live Production workflow;
- movement/scanning write commands are not part of the current live-review workflow;
- no fake Production work days or movement records should be created merely for testing; and
- Production availability does not close the UI/workflow evaluation. PRs #123, #124, and #125 remain open while real-use findings are collected and resolved.
