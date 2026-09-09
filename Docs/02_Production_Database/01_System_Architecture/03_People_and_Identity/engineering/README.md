# People and Identity — Engineering

This is the engineering starting point for Production Database work involving person identity, onboarding, contact data, authentication linkage, actor attribution, duplicate-safe person management, reusable capabilities, formal qualifications, Setup/Takedown eligibility, and the People Manager.

## Current Authority

- [`../README.md`](../README.md) — subsystem overview
- [`Directus_User_Onboarding_Identity_Contract_2026-09-09.md`](Directus_User_Onboarding_Identity_Contract_2026-09-09.md) — current Production Directus onboarding behavior and People identity lifecycle
- [`People_Manager_Metadata_Implementation_2026-09-09.md`](People_Manager_Metadata_Implementation_2026-09-09.md) — current capability/qualification/Setup-role implementation
- [`Internal_Web_Backbone_Handoff.md`](Internal_Web_Backbone_Handoff.md) — source-owned Production intranet integration handoff
- [`../../../../../People/README.md`](../../../../../People/README.md) — People Manager implementation
- [`../../../../../People/Acceptance/README.md`](../../../../../People/Acceptance/README.md) — People acceptance entry/evidence portal
- [`../../../02_Operational_SOPs/People/README.md`](../../../02_Operational_SOPs/People/README.md) — plain-English operator procedures
- GitHub issue #130 — People / Capability / Qualification catalog and duplicate-safe person management

Server/runtime mechanics are governed by `Gregovate/MSB-Server-Management`, especially:

- `docs/server/PostgreSQL_Disposable_Acceptance_Standard.md`;
- `docs/server/Pre_Production_Browser_Review_Runbook.md`; and
- `docs/server/Production_Database_Change_Deployment_Runbook.md` for the separate Production gate.

## Current State

`ref.person` remains the durable person identity. A person may exist without a Google Workspace account, Directus identity, PostgreSQL login, or active system access.

The Production Directus **User Onboarding** flow was inspected directly in the Directus administrative UI. It matches an existing `ref.person` by `email`, provided `directus_user_id` is null or already equals the triggering Directus user ID. If no matching person is found, it creates a new person from the Directus user's first name, last name, email, and Directus ID.

A manually added volunteer therefore reserves the intended Sheboygan Lights email on the existing person before later first Google/Directus login when preserving the same `person_id` matters.

## Accepted People Manager Implementation

Branch `agent/people-manager-milestone1-20260908` contains the accepted People Manager source under `People/`.

The accepted contact/identity behavior includes:

- standalone Flask People Manager application;
- separate `people_app` least-privilege login/command contract;
- Cloudflare-authenticated browser identity plus current Directus Manager/Administrator authorization;
- database-governed search and person detail;
- manual volunteer/contact create with standard `first initial + last name @sheboyganlights.org` reservation;
- collision review favoring additional first-name characters rather than silent numbering;
- duplicate review using normalized name, MSB email, personal email, and phone evidence;
- contact edit and active/inactive lifecycle;
- optimistic concurrency through exact `updated_at` round-trip serialization;
- Directus-linked MSB email protected from ordinary edit;
- protected system state visible but not ordinary writable input;
- dynamic current foreign-key relationship counts;
- no normal person DELETE or merge route; and
- required GA4 integration with a privacy-safe aggregate event boundary.

The accepted metadata behavior adds:

```text
ref.person_capability_type
ref.person_capability
ref.person_qualification_type
ref.person_qualification
ref.person_setup_role
```

and the browser exposes:

- controlled reusable capability catalog and person capability relationships;
- formal dated qualifications with validity/expiration, certificate/evidence, active state, and notes;
- `SETUP_VOLUNTEER`, `TAKEDOWN_VOLUNTEER`, `CAPTAIN_CANDIDATE`, and `ADVISOR_CANDIDATE` relationships; and
- read-only person-centric visibility of existing `ref.setup_task_captain` Captain/Alternate/Advisor assignments.

Capabilities, qualifications, Setup eligibility, and actual Captain assignments remain distinct facts. People Manager does not infer Captain assignments.

## Acceptance State — 2026-09-09

### Current-Production disposable acceptance

Accepted database/backend candidate:

```text
deaa9157282e59e8acd6a7da2a82fc9296e44f20
```

Server report:

```text
/tmp/MSB_People_Manager_Disposable_20260909-183640.txt
```

Production `ref.person` fingerprint was unchanged before/after:

```text
47f494107952a84f30a406374b8d01d7
```

The accepted clone proof includes least privilege, person create/reserved email, same-person deactivate/reactivate, capability, formal qualification evidence, Setup/Takedown roles, read-only leadership visibility, actor/audit stamping, and no normal person delete function.

Durable evidence:

`People/Acceptance/People_Manager_Metadata_Disposable_Acceptance_Evidence_2026-09-09.md`

### Browser operator acceptance

Final browser presentation candidate:

```text
4724185fe8cd8831a59c61ea40df61073abbb0c6
```

Disposition:

```text
ACCEPTED FOR PRODUCTION DEPLOYMENT GATE
```

The final operator-requested change was a CSS-only left-edge blue brace/accent for panel separation, especially in dark mode. The operator explicitly stated another browser test was not required for that cosmetic-only correction.

The preview session then exited cleanly with:

- Production `ref.person` fingerprint unchanged;
- Production shared checkout unchanged;
- Production FieldWiring service healthy; and
- preview port no longer listening.

Durable evidence:

`People/Acceptance/People_Manager_Browser_Review_Acceptance_2026-09-09.md`

## Google Analytics Contract

People Manager uses the approved internal GA4 property:

```text
G-X08ZTSY0VV
```

The application emits a direct page view and bounded anonymous workflow events. It must not send names, emails, phone numbers, `person_id`, Cloudflare/Directus authenticated identity, search terms, PostgreSQL login values, or other Production record identifiers.

Google Signals and advertising personalization remain disabled.

The Production gate must include post-deployment analytics verification required by `System_Documentation/Project_Rules/Internal_Web_Analytics_Rule.md`:

```text
[ ] deployed People page view visible in the MSB Internal Intranet GA4 property
[ ] intended analytics asset/version verified
[ ] no PII/authenticated identity/record identifier sent
[ ] Google Signals / ad personalization still disabled
```

## Person Lifecycle

```text
volunteer/contact
    -> ref.person created or existing person found
    -> personal contact data maintained
    -> reserved @sheboyganlights.org identity stored when appropriate
    -> Google Workspace account may be created later
    -> first Directus login can link the same person_id by exact MSB email
```

If a person stops participating, retain the durable identity and set `active_flag=false`; reactivate that same person if they return.

## Current Production-Gate Sequence

```text
accepted disposable clone
    -> accepted browser review
    -> documentation/operator SOP closeout
    -> explicit Production deployment approval
    -> Production preflight / rollback archive / migrations / application deployment
    -> live People workflow verification
    -> GA4 verification
    -> Production intranet/index integration through Internal Web Backbone handoff
    -> final closeout evidence
```

Production mutation remains a separate explicit gate.

## Separate Future Work

- authoritative capability/qualification seed evidence and canonical `person_id` resolution;
- `ref.setup_task_capability` as a Setup-consumer relationship;
- governed person merge/reconciliation;
- Google Workspace provisioning automation/integration beyond the reserved identity contract; and
- any future role/policy administration UI.

These do not block the accepted People Manager deployment.

## Resume Development

Before changing People behavior after deployment:

1. read the onboarding contract, metadata implementation, accepted disposable/browser evidence, and current operator procedure;
2. inspect current Production schema/runtime rather than relying on this historical acceptance alone;
3. preserve Google Workspace provisioning authority and Directus authorization authority;
4. preserve least privilege and duplicate-safe identity behavior;
5. preserve the GA4 privacy boundary; and
6. use the Server Management runbooks for runtime/Production work rather than feature-local reconstruction.
