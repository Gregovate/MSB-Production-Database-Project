# Shared Production-Backed Setup Review

Status: **PRODUCTION RUNTIME ACCEPTED — UI/WORKFLOW LIVE EVALUATION**

The V0.3.4 Setup application uses the real 2025 `HISTORICAL_VERIFICATION` Setup Session as a shared review/training environment.

Production deployment is complete at the runtime level:

```text
public application              = https://my.sheboyganlights.org/setup/
Setup health                    = V0.3.4-shared-season-guard-review
Cloudflare-authenticated view   = PASS
2025 Production data rendering  = PASS
post-cutover invariants         = PASS
```

The Setup/UI subsystem is intentionally still open for live evaluation through real Manager/reviewer use.

## Safety Boundaries

- operational dates must match the selected Setup Session year;
- audit/recording timestamps remain real current timestamps;
- the browser and database both enforce the year boundary;
- reusable task edits are permanent Setup knowledge;
- 2025 annual edits remain 2025 history;
- annual Setup Session creation is Administrator-only;
- future-baseline promotion is Administrator-only;
- no 2026 Setup Session was created by the V0.3.4 promotion;
- Pick List generation is not yet a live Production workflow;
- movement/scanning write commands are not part of the current live-review workflow; and
- no fake Production work days or movement records should be created merely for acceptance testing.

## Production Baseline at Deployment Acceptance

```text
setup_session_id          = 1
season_year               = 2025
session_status            = HISTORICAL_VERIFICATION
annual_tasks              = 57
unverified_tasks          = 57
sessions_2026             = 0
work_days                 = 0
movement_events           = 0
active_reusable_tasks     = 57
```

## Live Evaluation

Managers/reviewers should use the 2025 session to perform real supported review work, including verification/correction, reusable task/resource/prerequisite maintenance, and questions/suggestions about the UI and workflow.

Production availability does not equal final UI acceptance. PRs #123, #124, and #125 remain open drafts until enough real use has occurred to identify and resolve material findings.

## Historical Promotion Material

`setup_v03_production_preflight.sql` and `setup_v034_production_install_plan.md` remain the historical promotion/acceptance records. Migration `012` was intentionally excluded from Production because it contains disposable seed/reset behavior.
