# People Manager Acceptance

Milestone 1 must be proven against a disposable database restored from the current Production database before any Production mutation.

Required acceptance cases:

1. candidate migration applies only to the disposable clone;
2. Production `ref.person` fingerprint remains unchanged;
3. `people_app` has EXECUTE on the approved People functions but no direct `ref.person` INSERT/UPDATE/DELETE and no Directus table SELECT;
4. Manager/Administrator access succeeds and unauthorized Directus users fail closed;
5. a new casual volunteer reserves the standard `first-initial + last-name` MSB email when available;
6. a standard email collision cannot reuse the existing address and requires explicit alternate review;
7. duplicate name/contact evidence blocks create until duplicate review is acknowledged;
8. exact MSB-email collision remains a hard conflict;
9. update cannot change `directus_user_id`, `pg_login_name`, Manager/team flags, or Work Order eligibility because no command argument exists for those fields;
10. a Directus-linked person's MSB email cannot be changed by ordinary contact edit;
11. inactive person records remain present and can be reactivated;
12. optimistic concurrency rejects a stale update;
13. current foreign-key dependencies are visible for a selected person;
14. no person DELETE function/route exists; and
15. actor/audit stamping resolves the authenticated Directus manager through the existing `app.directus_user_uuid` trigger path.

A server-side clone runner is still to be written before the Production gate. Do not substitute testing directly against Production.
