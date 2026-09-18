# Setup Expected Duration Hours / Minutes — Production Acceptance — 2026-09-17

## Scope

This record closes the implementation and Production acceptance evidence for Setup Issue #204 / PR #207.

Managers now enter reusable expected duration with:

```text
Crew min | Crew max | Expected hrs | Expected mins (0–59)
```

The durable database representation remains `ref.setup_task.expected_duration_minutes`. No second hours/minutes database representation was added.

## Accepted Candidate

```text
branch            = agent/setup-204-duration-hours-minutes
browser candidate = 052d31dd4e68e13f2997f723778b88eddf9c53cf
PR                = #207
merge commit      = 691fce3987a8b1e0918e7c292b8a64b65a783528
issue             = #204
prior live SHA    = 5040fa282410b729d93e58a8299e48e4ee214809
```

Production intentionally deploys the exact browser-accepted candidate rather than the later merge commit.

## Behavior Accepted

- stored 90 minutes displays as 1 hr / 30 mins;
- stored 60 minutes displays as 1 hr / 0 mins;
- stored 45 minutes displays as 0 hrs / 45 mins;
- saving 2 hrs / 15 mins recombines to 135 total minutes;
- both fields blank preserve NULL/missing;
- minute remainder greater than 59 is rejected;
- dirty-edit/save protections remain active;
- Planning Summary preserves `MISSING` for missing reusable duration and presents saved duration in human-readable form;
- annual `actual_duration_minutes` and #132 field-work reporting semantics are unchanged.

## Regression and Disposable Browser Review

Focused local regression: `21 passed`.

Full Setup regression: `345 passed`.

Exact-candidate disposable current-Production browser review:

```text
candidate = 052d31dd4e68e13f2997f723778b88eddf9c53cf
SETUP_REUSABLE_DISPOSABLE_BROWSER_PREVIEW_CLEAN_EXIT
exit status = 0
Production fingerprint before/after = 7dd32f21ca9a455329de54e8799f01b5 unchanged
live Setup SHA before/after = 5040fa282410b729d93e58a8299e48e4ee214809 unchanged
report = /home/msbadmin/setup-acceptance-reports/Setup_Disposable_Browser_Preview_20260918T000405.txt
Flask log = /tmp/Setup_Disposable_Browser_Preview_Flask_20260918T000405.log
```

Operator review accepted the final one-line labels and Hours/Minutes workflow.

## Production Source-Only Deployment

Authority:

```text
Gregovate/MSB-Server-Management
docs/server/Setup_Source_Only_Application_Deployment_Runbook.md
```

Preflight:

```text
OLD_HEAD = 5040fa282410b729d93e58a8299e48e4ee214809
TARGET_SHA = 052d31dd4e68e13f2997f723778b88eddf9c53cf
forward ancestry = PASS
exact-target Setup/Application regression = 345 passed in 0.79s
Production fingerprint before = 7dd32f21ca9a455329de54e8799f01b5
```

Controlled mutation advanced only the detached `/opt/msb-setup` checkout to the accepted SHA and restarted only `msb-setup.service`.

Post-restart:

```text
service = active
health = {"data_mode":"postgres","status":"ok","version":"V0.3.13-assignment-layer"}
health = PASS on attempt 1
focused live #204 regression = 21 passed
Production fingerprint after = 7dd32f21ca9a455329de54e8799f01b5
PRODUCTION_FINGERPRINT=PASS
```

No PostgreSQL migration, environment change, service-unit change, proxy/firewall change, or host reboot was part of #204.

## Rollback

Source-only rollback point:

```text
5040fa282410b729d93e58a8299e48e4ee214809
```

Rollback follows the Server Management Setup Source-Only Application Deployment Runbook: return `/opt/msb-setup` to that exact SHA and restart only `msb-setup.service`. No PostgreSQL restore belongs to this rollback boundary.

## Closeout

#204 is a bounded reusable-Catalog usability correction. The durable field remains total minutes, the operator surface is Hours / Minutes, and actual elapsed field-work duration remains separate under #132.

The remaining Setup launch sequence continues through #145 final reusable-Catalog acceptance and then #122 annual scheduling / Pick List launch work.
