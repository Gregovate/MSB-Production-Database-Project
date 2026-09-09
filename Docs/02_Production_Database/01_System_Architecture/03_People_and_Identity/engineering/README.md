# People and Identity — Engineering

This is the engineering starting point for Production Database work involving person identity, onboarding, contact data, authentication linkage, actor attribution, duplicate-safe person management, reusable capabilities, formal qualifications, and the global People Manager.

## Current Authority

- [`../README.md`](../README.md) — subsystem overview
- [`Directus_User_Onboarding_Identity_Contract_2026-09-09.md`](Directus_User_Onboarding_Identity_Contract_2026-09-09.md) — current Production Directus onboarding behavior and People Manager identity lifecycle
- [`People_Manager_Metadata_Implementation_2026-09-09.md`](People_Manager_Metadata_Implementation_2026-09-09.md) — current capability/qualification/Setup-role implementation follow-up
- [`../../../../../People/README.md`](../../../../../People/README.md) — People Manager implementation candidate
- [`../../../../../People/Acceptance/README.md`](../../../../../People/Acceptance/README.md) — People disposable/browser acceptance entry point
- GitHub issue #130 — global People / Capability / Qualification catalog and duplicate-safe person management

Server/runtime mechanics are governed by `Gregovate/MSB-Server-Management`, especially:

- `docs/server/PostgreSQL_Disposable_Acceptance_Standard.md`;
- `docs/server/Pre_Production_Browser_Review_Runbook.md`; and
- `docs/server/Production_Database_Change_Deployment_Runbook.md` for the later separate Production gate.

## Current State

`ref.person` remains the durable person identity. A person may exist without a Google Workspace account, Directus identity, PostgreSQL login, or active system access.

The Production Directus **User Onboarding** flow has been inspected directly in the Directus administrative UI. It matches an existing `ref.person` by `email`, provided `directus_user_id` is null or already equals the triggering Directus user ID. If no matching person is found, the flow creates a new person row from the Directus user's first name, last name, email, and Directus user ID.

This establishes a critical People Manager rule: a manually added casual volunteer must already have their reserved Sheboygan Lights email stored on the existing `ref.person` row before a later first Google/Directus login if the same `person_id` is to be preserved automatically.

## Current People Manager Implementation Candidate

Branch `agent/people-manager-milestone1-20260908` contains the People Manager under `People/`.

The contact/identity slice includes:

- standalone Flask People Manager application;
- separate `people_app` least-privilege database login contract;
- Cloudflare-authenticated browser identity plus current Directus Manager/Administrator authorization;
- database-governed search and detail for `ref.person`;
- manual volunteer/contact create with standard `first initial + last name @ sheboyganlights.org` reservation;
- collision review that favors additional first-name characters rather than silent numbering;
- duplicate candidate review using normalized name, MSB email, personal email, and phone evidence;
- safe contact edits and active/inactive lifecycle;
- optimistic concurrency through `updated_at`, including exact timestamp serialization in the browser API;
- Directus-linked MSB email protected from ordinary contact edit;
- `directus_user_id`, `pg_login_name`, `is_manager`, `is_team`, and `available_for_work_orders` visible as protected state, not ordinary writable inputs;
- dynamic current foreign-key relationship counts for deletion/merge awareness;
- no person DELETE route/function; and
- required GA4 integration with no person/authenticated identity or record identifiers sent to Google Analytics.

The metadata follow-up now adds:

```text
ref.person_capability_type
ref.person_capability
ref.person_qualification_type
ref.person_qualification
ref.person_setup_role
```

and the browser now exposes:

- controlled reusable capability catalog and person capability relationships;
- formal dated qualifications with validity/expiration, certificate/evidence, active state, and notes;
- `SETUP_VOLUNTEER`, `TAKEDOWN_VOLUNTEER`, `CAPTAIN_CANDIDATE`, and `ADVISOR_CANDIDATE` relationships; and
- read-only person-centric visibility of existing `ref.setup_task_captain` Captain/Alternate/Advisor assignments.

Capabilities, qualifications, Setup eligibility, and actual Captain assignments remain distinct facts. The People Manager does not infer Captain assignments.

## Acceptance State — 2026-09-09

The original contact/identity application/database candidate passed the current-Production disposable-clone gate with Production `ref.person` fingerprint unchanged:

```text
0498fba0d2398405632e4be72207bcd8
```

During the governed browser review:

1. an optimistic-lock browser serialization defect was found and corrected; and
2. after contact/person creation was working, the operator identified that the screen omitted the capabilities, qualifications, Setup/Takedown roles, and leadership visibility already required by issue #130.

The browser disposition is therefore:

```text
CHANGES REQUIRED — RETURN TO ENGINEERING
```

The metadata implementation materially changes application/database behavior. **The previous disposable PASS does not accept the new candidate.** A fresh current-Production disposable-clone acceptance of migrations 001 + 002 + 003 is required before another browser review.

Current sequence:

```text
metadata implementation/static contract validation
    -> fresh current-Production disposable acceptance
    -> fresh governed browser review
    -> operator disposition
    -> separate explicit Production deployment gate if accepted
```

Production deployment is not authorized.

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

If a person does not return in later seasons, keep the durable person record and set `active_flag = false`; do not delete the identity merely because the volunteer stopped participating. If they return later, reactivate the same identity rather than recreating it.

## Remaining Work

- run fresh disposable acceptance for the new metadata candidate;
- complete the fresh browser review after that PASS;
- recover/verify authoritative capability and qualification evidence before any seed/import;
- resolve shorthand evidence to canonical `person_id` before any seed;
- add `ref.setup_task_capability` only as a Setup-consumer relationship when that integration is ready;
- retain Google Workspace as provisioning authority;
- retain Directus as authorization authority; and
- design/prove governed person merge before relationship-heavy duplicate cleanup.

## Resume Development

Before changing onboarding or People Manager behavior:

1. read the Directus onboarding identity contract, the metadata implementation record, and issue #130;
2. inspect the current `People/` application/database candidate;
3. inspect the current `ref.person` schema, indexes, constraints, and relationships;
4. preserve Google Workspace as the authority for whether an MSB account actually exists;
5. do not treat the presence of `ref.person.email` alone as proof that the address is deliverable;
6. preserve the current first-login Directus linking behavior unless a separately accepted change replaces it;
7. do not reuse an earlier acceptance after application/database behavior changes;
8. use the Server Management browser-review/disposable standards rather than inventing feature-local runtime procedures; and
9. do not mutate Production without the separate explicit Production gate and governing deployment runbook.
