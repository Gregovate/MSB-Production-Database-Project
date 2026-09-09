# People Manager

This area owns the application/database implementation for the global People and Identity manager tracked by issue #130.

## Current State

The People Manager engineering and browser-acceptance work is complete on branch `agent/people-manager-milestone1-20260908` and is ready for the separate Production deployment gate.

Current gate status:

```text
current-Production disposable acceptance       PASS
pre-Production browser operator review          ACCEPTED FOR PRODUCTION DEPLOYMENT GATE
Production deployment                           NEXT — SEPARATE EXPLICIT GATE
Production analytics verification               REQUIRED AFTER DEPLOYMENT
Production index / intranet integration          REQUIRED AFTER LIVE ENTRY POINT EXISTS
```

Accepted database/backend candidate:

```text
deaa9157282e59e8acd6a7da2a82fc9296e44f20
```

Final accepted browser presentation candidate:

```text
4724185fe8cd8831a59c61ea40df61073abbb0c6
```

The final browser-review cleanup also proved the Production `ref.person` fingerprint and live shared checkout were unchanged, FieldWiring remained healthy, and the temporary preview port was removed.

## Implemented Scope

### Durable person / contact identity

- Manager/Administrator-authorized person search and detail;
- create/edit contact information;
- active/inactive lifecycle with reactivation of the same durable `person_id`;
- collision-safe reserved `@sheboyganlights.org` identity candidates;
- strong duplicate review before create/identity-changing edits;
- protected Directus/PostgreSQL identity fields;
- dynamic visibility of current foreign-key relationships; and
- no browser hard-delete or merge action.

### Global capability catalog

`ref.person_capability_type` is the controlled capability catalog and `ref.person_capability` relates people to reusable skills, experience, and MSB-specific knowledge.

Current controlled categories are:

```text
TRADE
TECHNICAL
DISPLAY_BUILD_KNOWLEDGE
EQUIPMENT
OTHER
```

No skill level such as beginner/intermediate/expert is invented.

### Formal qualifications

`ref.person_qualification_type` is the controlled qualification catalog and `ref.person_qualification` stores dated person qualification records including:

```text
completed_on
valid_from
expires_on
qualification_role
certificate_number
evidence_reference
active_flag
notes
```

Capabilities and qualifications remain separate. Expiration dates are entered from authoritative evidence rather than inferred from conversational shorthand.

### Setup / Takedown participation and eligibility

`ref.person_setup_role` supports:

```text
SETUP_VOLUNTEER
TAKEDOWN_VOLUNTEER
CAPTAIN_CANDIDATE
ADVISOR_CANDIDATE
```

These relationships describe participation/eligibility and do not create Captain assignments.

### Existing Setup leadership visibility

People Manager reads the existing `ref.setup_task_captain` relationship so a person's current reusable-task `CAPTAIN`, `ALTERNATE`, and `ADVISOR` assignments are visible. People Manager does not create or infer those assignments.

## Browser / UI Contract

The accepted presentation follows the current MSB application family:

- official Making Spirits Bright blue logo/header;
- shared `msb-theme` light/dark preference;
- compact sticky People list at left;
- separated Contact, Capabilities, Qualifications, Setup/Takedown, and Leadership cards;
- protected system state and database relationships collapsed as technical details; and
- blue left-edge panel accents for separation, especially in dark mode.

## Google Analytics Contract

People Manager includes the required MSB internal GA4 integration using:

```text
G-X08ZTSY0VV
```

The application sends a direct page view and only bounded anonymous workflow events. It must never send person names, email addresses, phone numbers, `person_id`, authenticated identity, search text, Directus/PostgreSQL identity values, or other Production record identifiers to GA4.

Google Signals and advertising-personalization features remain disabled.

Production closeout is not complete until the deployed People page view is verified in the MSB Internal Intranet GA4 property and the deployed analytics asset/version is confirmed under `System_Documentation/Project_Rules/Internal_Web_Analytics_Rule.md`.

## Operator Documentation

Plain-English operator procedures are under:

```text
Docs/02_Production_Database/02_Operational_SOPs/People/
```

Use those procedures for normal person/contact, capability, qualification, and Setup/Takedown role maintenance. Engineering documentation remains separate.

## Folder Guide

| Folder | Purpose |
|---|---|
| `Application/` | Flask browser/API and static People Manager UI |
| `Database/` | Least-privilege PostgreSQL functions, metadata tables, and grants |
| `Acceptance/` | Disposable current-Production-clone acceptance, browser review, and retained evidence |

## Engineering Authority

Start with:

`Docs/02_Production_Database/01_System_Architecture/03_People_and_Identity/engineering/README.md`

Current implementation detail:

`People_Manager_Metadata_Implementation_2026-09-09.md`

Current Directus onboarding behavior:

`Directus_User_Onboarding_Identity_Contract_2026-09-09.md`

Acceptance evidence:

```text
People/Acceptance/People_Manager_Metadata_Disposable_Acceptance_Evidence_2026-09-09.md
People/Acceptance/People_Manager_Browser_Review_Acceptance_2026-09-09.md
```

Server/runtime mechanics remain owned by `Gregovate/MSB-Server-Management`.

## Separate / Future Work

The accepted current People Manager deliberately leaves these as separate follow-on work:

- Google Workspace account provisioning remains owned by Google Admin / Workspace;
- Directus role/policy administration remains outside ordinary People editing;
- authoritative capability/qualification seed evidence must be resolved to canonical `person_id` values before any seed/import;
- `ref.setup_task_capability` remains a later Setup-consumer relationship; and
- governed person merge/reconciliation remains future work before relationship-heavy duplicate cleanup.

These follow-ons do not block deployment of the accepted People Manager scope.

## Production Boundary

Nothing in this directory by itself authorizes a Production mutation. Production deployment is a separate explicit gate governed by:

```text
Gregovate/MSB-Server-Management
docs/server/Production_Database_Change_Deployment_Runbook.md
```

After Production deployment and verification, the People source handoff to `MSB-Internal-Web-Backbone` controls addition of the live People application to the Production intranet page.
