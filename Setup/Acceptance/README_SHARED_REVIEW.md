# Shared Production-Backed Setup Review

The controlled V0.3.4 review uses the real 2025 `HISTORICAL_VERIFICATION` Setup Session as a shared review/training environment.

Key safety boundaries:

- operational dates must match the selected Setup Session year;
- audit/recording timestamps remain real current timestamps;
- the browser and database both enforce the year boundary;
- reusable task edits are permanent Setup knowledge;
- 2025 annual edits remain 2025 history;
- annual Setup Session creation is Administrator-only;
- future-baseline promotion is Administrator-only;
- no 2026 Setup Session is created by this promotion;
- no movement/scanning write commands are introduced;
- the candidate application remains isolated until accepted.

Run `setup_v03_production_preflight.sql` before any Production promotion and require `READY_FOR_CONTROLLED_V034_PROMOTION`.

See `setup_v034_production_install_plan.md` for the exact durable migration sequence and the explicit exclusion of disposable seed 012.
