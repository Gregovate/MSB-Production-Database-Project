# People Manager

This area owns the application/database implementation for the global People and Identity manager tracked by issue #130.

## Current State

People Manager is **live in Production** at:

```text
https://my.sheboyganlights.org/people/
```

Current accepted state:

```text
current-Production disposable acceptance       PASS
pre-Production browser operator review          ACCEPTED
Production deployment                           PASS
Production protected /people/ route             PASS
Cloudflare-authenticated live browser            PASS
Production analytics verification               PASS
Production index / intranet integration          NEXT — BACKBONE #16
```

Accepted database/backend candidate:

```text
deaa9157282e59e8acd6a7da2a82fc9296e44f20
```

Final accepted browser presentation candidate:

```text
4724185fe8cd8831a59c61ea40df61073abbb0c6
```

Production application target:

```text
54e1192309b96c9838676be51a0bfcdb3ac92e06
```

Production acceptance evidence:

```text
People/Acceptance/People_Manager_Production_Acceptance_2026-09-09.md
```

## Production Runtime

```text
service             msb-people.service
version             V0.2.0
runtime account     fieldwiring
working directory   /opt/fieldwiring/People/Application
listener            192.168.5.9:8796
PostgreSQL role     people_app
public route        https://my.sheboyganlights.org/people/
```

The People backend is exposed only to the Synology reverse proxy through the source-limited UFW rule for `192.168.5.4 -> 8796/tcp`.

Server/runtime mechanics remain owned by `Gregovate/MSB-Server-Management`.

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

## Authentication / Authorization

Cloudflare Access authenticates the browser user. PostgreSQL then resolves the current Directus authorization context.

People Manager maintenance is limited to current **Manager / Administrator** or equivalent accepted `admin_access` authority. Cloudflare authentication alone does not grant People management access.

Human writes also require the authenticated Directus user to map to a durable `ref.person` actor.

## Browser / UI Contract

The accepted presentation follows the current MSB application family:

- official Making Spirits Bright blue logo/header;
- shared `msb-theme` light/dark preference;
- compact sticky People list at left;
- separated Contact, Capabilities, Qualifications, Setup/Takedown, and Leadership cards;
- protected system state and database relationships collapsed as technical details; and
- blue left-edge panel accents for separation, especially in dark mode.

## Google Analytics Contract

People Manager uses the required MSB internal GA4 integration:

```text
Measurement ID      G-X08ZTSY0VV
analytics version   2026-09-09.1
```

The live Production page view was verified in the MSB Internal Intranet GA4 property on 2026-09-09.

The application must never send person names, email addresses, phone numbers, `person_id`, authenticated identity, search text, Directus/PostgreSQL identity values, or other Production record identifiers to GA4. Google Signals and advertising-personalization features remain disabled.

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
| `Acceptance/` | Disposable acceptance, browser review, Production deployment, and retained evidence |

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
People/Acceptance/People_Manager_Production_Acceptance_2026-09-09.md
```

## Separate / Future Work

The accepted current People Manager deliberately leaves these as separate follow-on work:

- Google Workspace account provisioning remains owned by Google Admin / Workspace;
- Directus role/policy administration remains outside ordinary People editing;
- authoritative capability/qualification seed evidence must be resolved to canonical `person_id` values before any seed/import;
- `ref.setup_task_capability` remains a later Setup-consumer relationship; and
- governed person merge/reconciliation remains future work before relationship-heavy duplicate cleanup.

These follow-ons do not block the current Production People Manager.

## Current Closeout Boundary

The People application itself is accepted and live. The remaining current closeout step is to expose the verified live People route from the Production intranet/index through:

```text
Gregovate/MSB-Internal-Web-Backbone#16
```

The source handoff is:

`Docs/02_Production_Database/01_System_Architecture/03_People_and_Identity/engineering/Internal_Web_Backbone_Handoff.md`
