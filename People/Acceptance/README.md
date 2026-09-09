# People Manager Acceptance

Milestone 1 must be proven against a disposable database restored from the current Production database before any Production mutation.

## Disposable Acceptance Runner

From the repository checkout on Greg's Windows workstation, run:

```powershell
.\People\Acceptance\run_people_manager_disposable_acceptance.ps1
```

The wrapper uploads only the two People candidate migrations plus the bounded server-side runner, then starts one foreground SSH session. The server-side runner:

- fingerprints Production `ref.person` before testing;
- reads Production only through `SELECT` and `pg_dump`;
- restores the current Production database into a separate disposable PostgreSQL container;
- creates clone-only `people_app` as `NOLOGIN` for privilege testing;
- applies the People candidate migrations only to the disposable database;
- executes the acceptance cases below against the clone;
- removes the disposable container/work directory; and
- fingerprints Production `ref.person` again and fails if it changed.

The retained server report is named:

```text
/tmp/MSB_People_Manager_Disposable_YYYYMMDD-HHMMSS.txt
```

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

Passing this disposable runner is necessary but does **not** authorize Production deployment. Production still requires the separate explicit Production gate and governing repository runbook.
