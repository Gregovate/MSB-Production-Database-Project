# People Manager Acceptance

Milestone 1 must be proven against a disposable database restored from the current Production database before any Production mutation.

## Governing Runtime Authority

Disposable PostgreSQL orchestration is not owned by the People feature. The governing server/runtime authority is:

```text
Gregovate/MSB-Server-Management
docs/server/PostgreSQL_Disposable_Acceptance_Standard.md
```

Production deployment, if later explicitly approved, is separately governed by:

```text
Gregovate/MSB-Server-Management
docs/server/Production_Database_Change_Deployment_Runbook.md
```

The files in this `People/Acceptance/` folder provide only the People-specific candidate migrations and assertions needed to consume that established runtime pattern. Do not invent alternate SSH, Docker, PostgreSQL clone, readiness, cleanup, or Production deployment behavior here.

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

Passing this disposable runner is necessary but does **not** authorize Production deployment. Production still requires the separate explicit Production gate and the governing Server Management deployment runbook.
