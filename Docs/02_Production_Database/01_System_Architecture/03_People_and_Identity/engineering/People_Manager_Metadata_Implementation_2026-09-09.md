# People Manager Metadata Implementation — 2026-09-09

| Document Control | Value |
|---|---|
| Document Type | Engineering Implementation / Browser Finding Follow-up |
| System | People and Identity |
| Status | IMPLEMENTATION CANDIDATE — NOT APPLIED TO PRODUCTION |
| Owner | Production Database / People and Identity |
| Issue | #130 |
| Browser finding | Contact/identity slice was usable but incomplete against issue #130 |
| Last Reviewed | 2026-09-09 |

## Why this implementation pass exists

The governed browser review proved that the contact/identity People Manager could create people, build the reserved Sheboygan Lights email, and save contact/lifecycle changes after the optimistic-lock serialization correction.

The same operator review then exposed a scope defect: the screen did not include the global People metadata already defined by issue #130 and the People capability/qualification architecture.

The review disposition is therefore:

```text
CHANGES REQUIRED — RETURN TO ENGINEERING
```

The missing areas were capabilities, qualifications, Setup/Takedown participation/eligibility, and visibility of existing reusable-task Captain/Alternate/Advisor assignments.

## Database implementation

Migration:

```text
People/Database/003_create_people_metadata_contract.sql
```

adds the global People-owned tables:

```text
ref.person_capability_type
ref.person_capability
ref.person_qualification_type
ref.person_qualification
ref.person_setup_role
```

`ref.person` remains the durable person/contact authority.

### Capability contract

Capabilities represent reusable skills, practical experience, or MSB-specific knowledge.

The controlled catalog supports these deliberately broad categories:

```text
TRADE
TECHNICAL
DISPLAY_BUILD_KNOWLEDGE
EQUIPMENT
OTHER
```

No arbitrary proficiency levels are introduced.

### Qualification contract

Qualifications remain separate from capabilities and support formal dated/evidenced records:

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

No expiration date is inferred from conversational evidence. Durable dates must come from authoritative training/certificate evidence.

### Setup / Takedown relationship

`ref.person_setup_role` currently supports:

```text
SETUP_VOLUNTEER
TAKEDOWN_VOLUNTEER
CAPTAIN_CANDIDATE
ADVISOR_CANDIDATE
```

These are participation/eligibility facts only.

### Actual Setup leadership remains separate

Existing `ref.setup_task_captain` remains the actual reusable-task leadership authority with current roles:

```text
CAPTAIN
ALTERNATE
ADVISOR
```

People Manager reads these assignments for person-centric visibility. Migration 003 creates no Captain write command and performs no Captain inference.

## Least-privilege / audit boundary

The metadata tables use the existing actor stamping functions/triggers.

All browser writes pass through narrow SECURITY DEFINER functions that first resolve the existing People Manager actor and set transaction-local `app.directus_user_uuid` so current audit behavior remains authoritative.

`people_app` receives no direct DML on:

```text
ref.person
ref.person_capability_type
ref.person_capability
ref.person_qualification_type
ref.person_qualification
ref.person_setup_role
ref.setup_task
ref.setup_task_captain
```

The browser receives only the function EXECUTE surface required for the People Manager workflow.

## Browser implementation

The person screen now contains:

1. **Contact Information** — existing person/contact workflow.
2. **Protected identity / current system state** — Directus/PostgreSQL/legacy current-state visibility.
3. **Capabilities** — assign, deactivate/reactivate, person-specific notes, and controlled catalog type creation.
4. **Qualifications** — add/edit/deactivate/reactivate dated formal qualification records including certificate/evidence fields and controlled catalog type creation.
5. **Setup / Takedown participation & eligibility** — the four current controlled relationship values with optional notes.
6. **Reusable-task leadership** — read-only current Captain/Alternate/Advisor relationships.
7. **Current relationships** — dynamic foreign-key dependency visibility.

A new unsaved person must be saved first so metadata relationships attach to a durable `person_id`.

## Intentionally not included

This implementation does not:

- create Google Workspace accounts;
- change Directus roles/policies;
- make protected identity fields ordinary editable inputs;
- infer capability or qualification records from shorthand names;
- seed the known historical capability/qualification evidence;
- implement `ref.setup_task_capability` yet;
- create Captain assignments from capabilities, roles, or historical crews;
- hard-delete people; or
- implement governed person merge.

## Acceptance reset

The earlier disposable PASS applied only to the original contact/identity application/database candidate. Migration 003 and the V0.2.0 browser/API materially change the candidate.

Therefore the required order is reset to:

```text
static/application contract validation
    -> current-Production disposable clone acceptance of 001 + 002 + 003
    -> governed browser review of the exact accepted candidate
    -> operator disposition
    -> separate explicit Production deployment gate, if accepted
```

Production mutation remains unauthorized.
