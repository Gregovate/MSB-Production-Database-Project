# People Manager Acceptance

People Manager application/database changes must be proven against a disposable database restored from the current Production database before any Production mutation.

## Governing Runtime Authority

Disposable PostgreSQL orchestration is owned by:

```text
Gregovate/MSB-Server-Management
docs/server/PostgreSQL_Disposable_Acceptance_Standard.md
```

User-facing browser review is governed by:

```text
Gregovate/MSB-Server-Management
docs/server/Pre_Production_Browser_Review_Runbook.md
```

Production deployment, if later explicitly approved, is separately governed by:

```text
Gregovate/MSB-Server-Management
docs/server/Production_Database_Change_Deployment_Runbook.md
```

Do not invent alternate SSH, Docker, PostgreSQL clone, readiness, preview-process, cleanup, or Production deployment procedures in the People feature.

## Current Acceptance State — 2026-09-09

The original contact/identity candidate passed disposable acceptance, but the governed browser review later returned:

```text
CHANGES REQUIRED — RETURN TO ENGINEERING
```

The operator finding was that the screen omitted capabilities, formal qualifications, Setup/Takedown participation/eligibility, and reusable-task leadership visibility already required by issue #130.

Those areas are now implemented through:

```text
People/Database/001_create_people_manager_contract.sql
People/Database/002_harden_people_search_phone_filter.sql
People/Database/003_create_people_metadata_contract.sql
People/Application/*
```

The new application/database candidate is **not accepted yet**. Because application/database behavior changed, the previous disposable PASS does not carry forward.

Required order now:

```text
fresh current-Production disposable acceptance of 001 + 002 + 003
    -> exact candidate browser review
    -> operator disposition
    -> separate Production deployment gate only if accepted
```

## Disposable Acceptance Runner

From Greg's Windows repository checkout:

```powershell
git pull
.\People\Acceptance\run_people_manager_disposable_acceptance.ps1
```

The wrapper follows the Server Management standard:

- one bundled SCP transfer;
- one foreground SSH session;
- Linux line-ending normalization;
- Production access limited to `SELECT` and `pg_dump`;
- current Production restored into a separate disposable PostGIS container;
- final PostGIS PostgreSQL readiness requires container PID 1 to be `postgres` plus `pg_isready`;
- migrations `001`, `002`, and `003` apply only to the clone;
- all test writes remain clone-only; and
- Production `ref.person` is fingerprinted before/after and must remain unchanged.

Retained report:

```text
/tmp/MSB_People_Manager_Disposable_YYYYMMDD-HHMMSS.txt
```

### Current disposable acceptance cases

The runner proves at least:

1. current Production clone dependencies are present;
2. `people_app` has narrow approved function execution but no broad direct People/Setup DML;
3. person create still reserves the standard first-initial + last-name MSB identity;
4. the same `person_id` can be deactivated/reactivated;
5. capability catalog + person capability relationship works;
6. formal qualification dates/evidence are preserved separately from capabilities;
7. all four current Setup/Takedown participation/eligibility roles work independently;
8. existing Setup leadership is visible through People Manager while `people_app` cannot directly write `ref.setup_task_captain`;
9. metadata writes use the existing authenticated actor/audit path; and
10. no normal People delete function exists.

A disposable PASS still does not authorize Production deployment.

## Browser Review — only after the fresh disposable PASS

The browser-review launcher must be pinned to the exact application/database SHA that passes the fresh disposable gate before another browser session is started.

Current Server Management rules remain mandatory:

- explicit preview port required;
- `8794` is Production Setup and must never be used/cleaned as preview state;
- selected port must be verified unused;
- browser does not auto-open;
- wait for `BROWSER REVIEW READY` before opening the localhost URL;
- `msbadmin` cannot traverse protected runtime paths under `/opt/fieldwiring`/`/opt/msb-setup`;
- runtime checks and Python execution occur as `fieldwiring` through foreground `sudo`; and
- cleanup preserves the original failure status and verifies only invariants actually captured before failure.

After the browser harness is pinned to the newly accepted SHA, the normal launch shape remains:

```powershell
.\People\Acceptance\run_people_manager_browser_preview.ps1 -PreviewPort 8795
```

`8795` is only an example candidate port; server preflight must prove it is unused.

### Required browser review after metadata acceptance

At minimum exercise:

1. search by name/email/phone and **Include inactive**;
2. activate an existing inactive person and save;
3. add a clone-only person and verify **Build email** + save;
4. edit/deactivate/reactivate that same clone-only `person_id`;
5. duplicate and MSB-email collision review;
6. **Capabilities** — create a controlled catalog item, assign it, deactivate/reactivate it, and inspect notes;
7. **Qualifications** — create a controlled qualification type and a clone-only dated qualification with completion/validity/expiration and certificate/evidence fields, then edit/deactivate/reactivate it;
8. **Setup / Takedown participation & eligibility** — exercise `SETUP_VOLUNTEER`, `TAKEDOWN_VOLUNTEER`, `CAPTAIN_CANDIDATE`, and `ADVISOR_CANDIDATE` independently;
9. **Reusable-task leadership** — confirm existing Captain/Alternate/Advisor assignments are visible but not editable from this People metadata screen;
10. protected Directus/MSB identity fields remain protected; and
11. no person delete action exists.

Operator disposition must be one of:

```text
ACCEPTED FOR PRODUCTION DEPLOYMENT GATE
CHANGES REQUIRED — RETURN TO ENGINEERING
REVIEW INCOMPLETE — NO PRODUCTION APPROVAL
```

## Cleanup

If a browser preview is interrupted after it has been started, use the same explicit preview port with:

```powershell
.\People\Acceptance\run_people_manager_browser_preview_cleanup.ps1 -PreviewPort 8795
```

Never pass a Production listener such as `8794` to preview cleanup.

## Production Boundary

Nothing in this folder authorizes a Production mutation. Production promotion requires a later separate explicit Production approval and the Server Management Production Database deployment runbook.
