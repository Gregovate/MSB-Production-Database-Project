# People Manager Acceptance

Milestone 1 must be proven against a disposable database restored from the current Production database before any Production mutation.

## Governing Runtime Authority

Disposable PostgreSQL orchestration is not owned by the People feature. The governing server/runtime authority is:

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

The files in this `People/Acceptance/` folder provide only the People-specific candidate migrations, assertions, and browser-review entry/cleanup pieces needed to consume those established runtime patterns. Do not invent alternate SSH, Docker, PostgreSQL clone, readiness, preview-process, cleanup, or Production deployment behavior here.

## Disposable Acceptance Runner

From the repository checkout on Greg's Windows workstation, run:

```powershell
.\People\Acceptance\run_people_manager_disposable_acceptance.ps1
```

The wrapper follows the Server Management disposable-acceptance contract: one bundled SCP transfer, one foreground SSH session, Linux line-ending normalization, Production access limited to `SELECT` and `pg_dump`, and all candidate mutation confined to the disposable clone.

The server-side runner:

- fingerprints Production `ref.person` before testing;
- reads Production only through `SELECT` and `pg_dump`;
- restores the current Production database into a separate disposable PostgreSQL container;
- consumes the documented final-PostGIS-server readiness gate before restore begins;
- creates clone-only `people_app` as `NOLOGIN` for privilege testing;
- applies the People candidate migrations only to the disposable database;
- executes the People-specific acceptance cases below against the clone;
- removes the disposable container/work directory; and
- fingerprints Production `ref.person` again and fails if it changed.

The retained server report is named:

```text
/tmp/MSB_People_Manager_Disposable_YYYYMMDD-HHMMSS.txt
```

## 2026-09-09 Runtime Discovery Promoted to Server Management

The first People disposable restore exposed a runtime gap: `postgis/postgis:16-3.5` can report `pg_isready` while its Docker entrypoint is still running a temporary PostgreSQL server used to install PostGIS. The image then intentionally shuts that temporary server down before starting the final PostgreSQL server as PID 1.

The diagnostic proved that behavior and also proved the failure was not OOM, disk exhaustion, or a Production database change. Production `ref.person` remained fingerprint-identical and no People migration had run.

That startup/readiness rule is a reusable server/runtime fact, so its authoritative contract now belongs in the Server Management `PostgreSQL_Disposable_Acceptance_Standard.md`. This People document records only why the feature runner depends on that standard; it is not a second authority for the Docker/PostgreSQL startup sequence.

## Pre-Production Browser Review

The disposable database acceptance passed on 2026-09-09 for exact candidate:

```text
7cd4c02420f564c1fe563d0c12052480c6ce6f6b
```

People Manager changes what an operator sees and edits, so the next gate is the Server Management `Pre_Production_Browser_Review_Runbook.md`.

From the same branch and a clean Windows worktree:

```powershell
git pull
.\People\Acceptance\run_people_manager_browser_preview.ps1
```

Default review parameters are:

```text
server        = msbadmin@192.168.5.9
preview port  = 8794
preview user  = gliebig@sheboyganlights.org
```

The default identity is the established Administrator-context preview identity used by the prior Controller browser-review pattern. The People runner does not assume that is sufficient: it re-resolves current Directus/ref.person authorization in the fresh disposable clone and fails closed before Flask launch if the identity no longer has People Manager capability or is not mapped to a governed person.

The browser-review wrapper and server runner follow the existing runbook pattern:

- require the People feature branch and a clean local worktree;
- pin the exact disposable-accepted candidate SHA above;
- refuse to proceed if `People/Application` or `People/Database` changed after that accepted SHA;
- use one bundled SCP transfer plus one foreground SSH session;
- use an SSH localhost tunnel rather than publishing the preview port;
- verify the Production FieldWiring service/health and live checkout before preview;
- create a detached worktree for the exact accepted People candidate without moving the Production checkout;
- run the People candidate regression with the documented Production Python runtime;
- create a new current-Production disposable PostgreSQL clone using the Server Management final-PostGIS readiness contract;
- create clone-only `people_app` LOGIN credentials and apply only migrations `001` and `002` to that clone;
- re-assert current People authorization and the no-broad-table-DML boundary;
- launch the exact accepted People Flask application bound to `127.0.0.1` with a preview-only identity injector and a DSN that points only to the disposable clone;
- keep the foreground PowerShell/SSH session open while Greg reviews the real browser workflow;
- tear down the Flask process, disposable database, dump, worktree, and temporary bundle after ENTER; and
- re-prove Production `ref.person`, the Production checkout, FieldWiring health, and the temporary preview port are unchanged/clean.

The browser opens at:

```text
http://127.0.0.1:8794/
```

Minimum People-specific operator review:

1. search by name, email, and phone; exercise **Include inactive**;
2. open existing people and inspect Contact Information, protected identity/current system state, and current relationships;
3. open a Directus-linked person and confirm the MSB email/build controls are protected from ordinary editing;
4. add a clone-only person, use **Build email**, and save;
5. edit that clone-only person's contact data, deactivate the same `person_id`, then reactivate it;
6. trigger the potential-duplicate warning and review the acknowledgement behavior before any intentional separate-person save;
7. trigger an MSB-email collision and review the additional-first-name-character alternate and exception acknowledgement;
8. confirm there is no person delete action; and
9. refresh/reopen records and confirm the disposable-clone state is presented consistently.

If the foreground preview is interrupted and stale resources remain, use the dedicated runbook-pattern cleanup wrapper:

```powershell
.\People\Acceptance\run_people_manager_browser_preview_cleanup.ps1
```

The retained browser-review evidence paths are:

```text
/tmp/MSB_People_Manager_Browser_Preview_YYYYMMDDTHHMMSS.txt
/tmp/MSB_People_Manager_Browser_Preview_Flask_YYYYMMDDTHHMMSS.log
```

The operator disposition must be one of:

```text
ACCEPTED FOR PRODUCTION DEPLOYMENT GATE
CHANGES REQUIRED — RETURN TO ENGINEERING
REVIEW INCOMPLETE — NO PRODUCTION APPROVAL
```

A browser-review PASS still does not authorize Production mutation.

## Required Acceptance Cases

1. candidate migrations apply only to the disposable clone;
2. Production `ref.person` fingerprint remains unchanged;
3. `people_app` has EXECUTE on the approved People functions but no direct `ref.person` SELECT/INSERT/UPDATE/DELETE and no Directus table SELECT;
4. Manager/Administrator access succeeds and unauthorized Directus users fail closed;
5. a new casual volunteer reserves the standard `first-initial + last-name` MSB email when available;
6. a standard email collision cannot reuse the existing address and requires explicit alternate review;
7. duplicate name/contact evidence blocks create until duplicate review is acknowledged;
8. exact MSB-email collision remains a hard conflict;
9. update cannot change `directus_user_id`, `pg_login_name`, Manager/team flags, or Work Order eligibility because no command argument exists for those fields;
10. a Directus-linked person's MSB email cannot be changed by ordinary contact edit;
11. inactive person records remain present and can be reactivated;
12. optimistic concurrency rejects a stale update;
13. non-numeric text search cannot become a phone `LIKE '%%'` match-all;
14. current foreign-key dependencies are visible for a selected person;
15. no person DELETE function/route exists; and
16. actor/audit stamping resolves the authenticated Directus manager through the existing `app.directus_user_uuid` trigger path.

Passing the disposable runner and browser review is necessary but does **not** authorize Production deployment. Production still requires the separate explicit Production gate and the governing Server Management deployment runbook.
