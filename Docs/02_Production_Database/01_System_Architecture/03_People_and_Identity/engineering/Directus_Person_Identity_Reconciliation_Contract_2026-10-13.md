# Directus / Person Identity Reconciliation Contract — 2026-10-13

| Document Control | Value |
|---|---|
| Document Type | Engineering Identity / Authorization Contract |
| System | People and Identity |
| Status | PRODUCTION ACCEPTED — V0.2.2 |
| Owner | Production Database / People and Identity |
| Related | #385; historical #130 |

## Problem

MSB protected applications authenticate and authorize through Google-backed Directus users, but human/audit attribution depends on the separate durable link:

```text
public.directus_users.id
    -> ref.person.directus_user_id
```

Production incidents proved that an active correctly authorized Directus user can exist while the matching Person link remains NULL.

Confirmed examples include Adam Biebel and Mark Hayon. The same failure class later appeared for `pneils@sheboyganlights.org`.

This is not an application-role failure. It is an identity-reconciliation failure after authentication and authorization have already succeeded.

## Current Root Cause

The existing Directus User Onboarding flow is create-event-only.

An already-established Directus user does not receive another reconciliation opportunity merely by logging in again.

Protected application actor functions also historically required a pre-existing UUID link and failed immediately when it was absent.

Therefore a one-time onboarding miss could remain latent until a field write failed.

## Durable Rule

The system must have one shared exact-email reconciliation contract.

Automatic reconciliation is allowed only when all of these facts agree:

```text
authenticated email
    == active Directus user email
    == Directus external_identifier
    == active existing ref.person.email

Directus provider = google
Person.directus_user_id = NULL or same UUID
Directus UUID not owned by another Person
```

If the Person link is NULL and every check passes, the shared resolver may link that exact Directus UUID to that exact existing Person atomically.

If any check fails, the system fails closed.

## What Automatic Reconciliation Must Never Do

It must not:

- guess by first/last name;
- use personal email as a Google identity match;
- create a Person;
- reactivate an inactive Person;
- change a Directus role;
- change Directus policies;
- choose Production Crew / Manager / Administrator authority;
- overwrite a different existing Person UUID link; or
- steal a Directus UUID already owned by another Person.

## Audit Attribution

The reconciliation UPDATE itself must be attributed to the same authenticated human being reconciled.

Because the normal audit resolver historically requires the UUID link that is being created, Issue #385 introduces a narrowly scoped transaction-local bootstrap:

```text
app.directus_user_uuid
app.identity_reconcile_email
```

The exact-email fallback in `ref.resolve_actor()` is valid only while the special reconciliation email setting is present.

Ordinary application writes cannot use email matching as an audit shortcut.

After reconciliation succeeds, all future attribution uses the normal durable UUID link.

## Shared Protected Actor Boundary

The following protected actor paths must use the shared reconciliation helper after their existing authorization checks:

```text
ref.setup_management_actor
ref.setup_movement_actor
ref.setup_execution_actor
ref.setup_inventory_actor
ref.people_management_actor
ref.controller_management_actor
ref.request_controller_label
```

Authorization remains owned by the existing subsystem capability/role logic.

Identity reconciliation does not grant authorization.

## Reconciliation Report

Issue #385 adds an administrator-only read-only report that classifies current Sheboygan Lights identities.

Expected dispositions include:

```text
LINKED_OK
SAFE_EXACT_EMAIL_UNLINKED
PERSON_WITHOUT_DIRECTUS
DIRECTUS_WITHOUT_PERSON
DIRECTUS_INACTIVE
PERSON_INACTIVE
PROVIDER_CONFLICT
EXTERNAL_IDENTIFIER_CONFLICT
PERSON_LINK_CONFLICT
DIRECTUS_UUID_CONFLICT
MULTIPLE_ACTIVE_DIRECTUS
SHARED_TABLET_ACCOUNT
NONHUMAN_SERVICE_ACCOUNT
```

This report is the required preflight for one-time cleanup and future troubleshooting.

## Steve Reiter Finding — 2026-10-13

Read-only operator evidence:

```text
Person 26
Steve Reiter
sreiter@sheboyganlights.org
active = true
Person directus_user_id = NULL
exact-email Directus user = NONE
```

At that October 13 snapshot, Steve was not a stale-link reconciliation case.

He requires Directus provisioning before a UUID link can exist.

## Paul Neils / pneils Finding

Historical Production Crew evidence established:

```text
pneils@sheboyganlights.org
Directus UUID = 74cc6c86-6bf8-4f0d-87e8-97a72567c1e0
provider = google
external_identifier = pneils@sheboyganlights.org
status = active
role = Production Crew
```

The 2026-10-13 current Production read-only snapshot confirmed Paul as an active existing Person with an active Google-backed Production Crew Directus user at the same email and a NULL Person UUID link. This is an exact safe reconciliation case under the accepted contract.

## Missing Directus Identity Is Outside #385

V0.2.2 reconciliation can repair a missing Person↔Directus UUID link only after an active Directus user exists.

It does not create a Directus user.

Issue #395 confirmed the earlier lifecycle gap with Don Martens:

```text
active Person exists
real Sheboygan Lights Google account exists
Cloudflare authentication succeeds
Directus user does not exist
-> Setup authorization returns no capability row
```

This condition must be solved by the separate first-login/bootstrap path. The #395 bootstrap must initialize the Directus identity at **MSB Browser** only and then allow the exact existing Person link to be established safely.

Legacy Person flags such as `is_manager` or `is_team` must not automatically elevate Directus authorization. Directus role/policy remains authoritative, and administrators may continue changing the role of an existing Directus user directly in the Directus backend.

Non-human tablet/device/service identities may legitimately have no Person row and must remain excluded from human reconciliation.

## Directus Onboarding Flow Boundary

The existing Directus onboarding flow remains a separate current-state concern.

Issue #385 self-reconciliation prevents safe exact-email matches from remaining broken merely because the create-event flow missed the link.

Long-term Directus onboarding must also fail closed rather than auto-create a Person when no exact existing Person is present.

That flow change is not achieved merely by the PostgreSQL reconciliation helper and must be separately accepted before claiming the no-match branch is eliminated.

## Production Acceptance — 2026-10-13

The complete acceptance sequence passed.

```text
visible version       V0.2.2
accepted runtime      2c9a2937079f817dafd5119584aaffc77b51357d
merged/deployed main  bb8dfa498c5b4bbecfc3693f68c4066c1e08242e
migration 005 blob    88442b8f4150513fd6af581e2ea90004c6f27658
```

Current-Production disposable acceptance proved:

1. static People/Identity contract regression — 26 passed;
2. current Production clone restore and migration 005 — PASS;
3. all protected actor paths self-reconcile an exact safe NULL link — PASS;
4. reconciliation audit attribution to the target Person — PASS;
5. already-correct state is idempotent — PASS;
6. provider mismatch — fail closed;
7. external identifier mismatch — fail closed;
8. inactive Person — fail closed;
9. missing exact-email Person — fail closed;
10. conflicting Person UUID — fail closed;
11. UUID ownership conflict — fail closed;
12. Directus role unchanged — PASS;
13. internal reconciliation helpers unavailable to application roles — PASS;
14. non-human tablet/device/service identities rejected — PASS; and
15. Production `ref.person` fingerprint unchanged — `9dca556251712a3824cda436b0300fc8`.

Governed Production deployment then passed under the Server Management Issue #37 maintenance controller. The final checkout is `bb8dfa498c5b4bbecfc3693f68c4066c1e08242e`, the validated rollback snapshot is `/home/msbadmin/backups/postgres/msb-pre-people-identity-reconcile-20261013T183854.dump`, and the retained deployment report is `/tmp/MSB_People_Identity_Reconcile_Production_Deploy_20261013T183854.txt`.

Durable acceptance evidence:

`People/Acceptance/People_Identity_Reconciliation_Production_Acceptance_2026-10-13.md`


## October 21 — Work Orders consumer gap (#447)

The October 13 Steve snapshot is historical: his Google Directus user now exists.
On October 21 his active Person 26 still had a NULL link. Administrator role
assignment to Production Crew enabled Setup reads but Work Orders rejected entry.
Operator called the existing reconciler, confirmed `link_reconciled=true` and
successful Work Orders entry, then repaired three additional safe unlinked people.

Work Orders omitted the shared reconciliation boundary. Its proposed narrow
wrapper consumes this helper after current Directus authorization and commits
before read-only access. See the [Work Order design](../../06_Work_Orders/Work_Order_System_Design.md#october-21--447-authorized-entry-reconciles-existing-human-identity).
Candidate is not deployed; #395 account provisioning remains a separate gate.
