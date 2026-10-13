# Directus / Person Identity Reconciliation Contract — 2026-10-13

| Document Control | Value |
|---|---|
| Document Type | Engineering Identity / Authorization Contract |
| System | People and Identity |
| Status | IMPLEMENTATION CANDIDATE — Issue #385 |
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

Steve is therefore not currently a stale-link reconciliation case.

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

The 2026-10-13 operational failure requires fresh Person/link verification, but it is consistent with the recurring stale-link class.

The disposable Issue #385 acceptance runner prints a current Production read-only identity snapshot before mutating only the disposable clone.

## Directus Onboarding Flow Boundary

The existing Directus onboarding flow remains a separate current-state concern.

Issue #385 self-reconciliation prevents safe exact-email matches from remaining broken merely because the create-event flow missed the link.

Long-term Directus onboarding must also fail closed rather than auto-create a Person when no exact existing Person is present.

That flow change is not achieved merely by the PostgreSQL reconciliation helper and must be separately accepted before claiming the no-match branch is eliminated.

## Acceptance

Before Production deployment:

1. run static People/Identity contract regression;
2. clone current Production with pg_dump;
3. apply migration 005 only to the disposable clone;
4. prove all protected actor paths self-reconcile an exact safe NULL link;
5. prove the reconciliation UPDATE is attributed to the target Person;
6. prove already-correct state is idempotent;
7. prove provider mismatch fails;
8. prove external identifier mismatch fails;
9. prove inactive Person fails;
10. prove missing exact-email Person fails;
11. prove conflicting Person UUID fails;
12. prove UUID ownership conflict fails;
13. prove Directus role is unchanged;
14. prove internal reconciliation helpers are not executable by application roles; and
15. prove Production ref.person fingerprint remains unchanged before/after disposable acceptance.

Production mutation remains a separate explicit gate.
