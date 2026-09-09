# People and Identity — Engineering

This is the engineering starting point for Production Database work involving person identity, onboarding, contact data, authentication linkage, actor attribution, duplicate-safe person management, and the emerging People Manager.

## Current Authority

- [`../README.md`](../README.md) — subsystem overview
- [`Directus_User_Onboarding_Identity_Contract_2026-09-09.md`](Directus_User_Onboarding_Identity_Contract_2026-09-09.md) — current Production Directus onboarding behavior and People Manager identity lifecycle
- [`../../../../../People/README.md`](../../../../../People/README.md) — People Manager implementation candidate
- [`../../../../../People/Acceptance/README.md`](../../../../../People/Acceptance/README.md) — People disposable/browser acceptance entry point
- GitHub issue #130 — global People / Capability / Qualification catalog and duplicate-safe person management

Server/runtime mechanics are governed by `Gregovate/MSB-Server-Management`, especially:

- `docs/server/PostgreSQL_Disposable_Acceptance_Standard.md`;
- `docs/server/Pre_Production_Browser_Review_Runbook.md`; and
- `docs/server/Production_Database_Change_Deployment_Runbook.md` for the later separate Production gate.

## Current State

`ref.person` is the durable person identity. A person may exist without a Google Workspace account, Directus identity, PostgreSQL login, or active system access.

The Production Directus **User Onboarding** flow has now been inspected directly in the Directus administrative UI. It matches an existing `ref.person` by `email`, provided `directus_user_id` is null or already equals the triggering Directus user ID. If no matching person is found, the flow creates a new person row from the Directus user's first name, last name, email, and Directus user ID.

This establishes a critical People Manager rule: a manually added casual volunteer must already have their reserved Sheboygan Lights email stored on the existing `ref.person` row before a later first Google/Directus login if the same `person_id` is to be preserved automatically.

### Milestone 1 implementation candidate

Branch `agent/people-manager-milestone1-20260908` contains the first People Manager vertical slice under `People/`.

Candidate scope:

- standalone Flask People Manager application;
- separate `people_app` least-privilege database login contract;
- Cloudflare-authenticated browser identity plus current Directus Manager/Administrator authorization;
- database-governed search and detail for `ref.person`;
- manual casual-volunteer create with standard `first initial + last name @ sheboyganlights.org` reservation;
- collision review that favors additional first-name characters rather than silent numbering;
- duplicate candidate review using normalized name, MSB email, personal email, and phone evidence;
- safe contact edits and active/inactive lifecycle;
- optimistic concurrency through `updated_at`;
- directus-linked MSB email protected from ordinary contact edit;
- `directus_user_id`, `pg_login_name`, `is_manager`, `is_team`, and `available_for_work_orders` visible as protected state, not writable inputs;
- dynamic current foreign-key relationship counts for deletion/merge awareness;
- no person DELETE route/function; and
- required GA4 integration with no person/authenticated identity or record identifiers sent to Google Analytics.

The branch includes a follow-on hardening migration for person search so a non-numeric search term cannot normalize to an empty phone token and match every row.

### Acceptance state — 2026-09-09

Exact People candidate accepted by the current-Production disposable-clone gate:

```text
7cd4c02420f564c1fe563d0c12052480c6ce6f6b
```

Disposable acceptance result:

```text
PEOPLE MANAGER DISPOSABLE ACCEPTANCE: PASS
PEOPLE MANAGER DISPOSABLE WRAPPER: PASS
```

Production `ref.person` fingerprint before and after that gate was identical:

```text
0498fba0d2398405632e4be72207bcd8
```

The disposable container/work directory was cleaned and no Production migration, checkout movement, or service restart occurred. Durable evidence is in `People/Acceptance/People_Manager_Disposable_Acceptance_Evidence_2026-09-09.md`.

The branch now also contains the People-specific browser-review harness that consumes the existing Server Management `Pre_Production_Browser_Review_Runbook.md`. It pins the exact accepted SHA above, creates a fresh current-Production disposable clone, launches the exact accepted Flask candidate on a localhost-only temporary listener through an SSH tunnel, and re-proves Production invariants during teardown.

**Browser operator review is the current next gate and has not yet been dispositioned.** Production deployment is not authorized.

Static/unit contract validation also passes, including Python compilation, JavaScript syntax checks, and People Manager contract tests.

The capability/qualification catalog, Google Workspace provisioning integration, Setup roles, and governed person merge remain later work.

## Person Lifecycle

The intended identity lifecycle is:

```text
casual volunteer
    -> ref.person created manually
    -> personal_email used for ordinary contact/scheduling
    -> reserved @sheboyganlights.org email generated and stored on ref.person.email
    -> Google Workspace account may be created later
    -> once Google confirms the account exists, the MSB address becomes the business/deliverable address
    -> first Directus login links directus_user_id to the same person_id by exact MSB email match
```

If a person does not return in later seasons, keep the durable person record and set `active_flag = false`; do not delete the identity merely because the volunteer stopped participating. If they return later, the same identity should be reactivated rather than recreated.

## Resume Development

Before changing onboarding or People Manager behavior:

1. read the Directus onboarding identity contract;
2. inspect the current `People/` Milestone 1 candidate and issue #130;
3. inspect the current `ref.person` schema, indexes, constraints, and relationships;
4. preserve Google Workspace as the authority for whether an MSB account actually exists;
5. do not treat the presence of `ref.person.email` alone as proof that the address is deliverable;
6. preserve the current first-login Directus linking behavior unless a separately accepted change replaces it;
7. preserve exact candidate `7cd4c02420f564c1fe563d0c12052480c6ce6f6b` through the browser-review gate unless application/database behavior changes and acceptance is rerun;
8. use the Server Management browser-review/disposable standards rather than inventing feature-local runtime procedures; and
9. do not mutate Production without the separate explicit Production gate and governing deployment runbook.
