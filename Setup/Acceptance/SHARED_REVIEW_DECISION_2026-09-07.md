# Setup Shared Review Decision — 2026-09-07

Decision: use the real 2025 `HISTORICAL_VERIFICATION` Setup Session as a shared Production-backed review/training area behind authenticated Setup access.

Safety controls:

- all operator-entered operational dates are constrained to the selected Setup Session year;
- the database independently enforces the same year boundary;
- `America/Chicago` is used for historical operational timestamp year checks;
- audit/recording timestamps remain current and are not rewritten into the historical year;
- Managers/reviewers may improve 2025 annual data and reusable Setup knowledge;
- only Administrators may create annual Setup Sessions or promote annual order into the future reusable baseline;
- no 2026 Setup Session is created by the V0.3.4 promotion;
- no movement/scanning write commands are included;
- shared candidate application remains isolated from the current live checkout until accepted.
