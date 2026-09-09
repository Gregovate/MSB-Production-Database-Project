# People Manager

This area owns the application/database implementation for the global People and Identity manager tracked by issue #130.

## Current State

The People Manager is a branch-only implementation candidate. It is **not installed in Production**.

The original contact/identity slice passed a current-Production disposable-clone gate, but browser review correctly returned **CHANGES REQUIRED** because issue #130 also requires capabilities, qualifications, Setup/Takedown eligibility, and leadership visibility. Those missing metadata areas are now implemented on the branch and require a fresh disposable acceptance and browser review.

Current gate status:

```text
original contact/identity disposable acceptance    PASS
browser review of original scope                   CHANGES REQUIRED
metadata implementation                            BUILT — UNACCEPTED
fresh current-Production disposable acceptance     REQUIRED NEXT
fresh browser operator review                      REQUIRED AFTER PASS
Production deployment                              NOT AUTHORIZED
```

## Implemented People Manager Scope

### Durable person / contact identity

- manager-authorized person search and detail;
- create/edit contact information;
- active/inactive lifecycle;
- collision-safe reserved `@sheboyganlights.org` identity candidates;
- strong duplicate review before create/identity-changing edits;
- protected Directus/PostgreSQL identity fields;
- dynamic visibility of current foreign-key relationships; and
- no browser hard-delete action.

### Global capability catalog

`ref.person_capability_type` is the controlled capability catalog and `ref.person_capability` relates people to reusable skills/experience/knowledge.

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

Capability and qualification are deliberately separate. The application does not infer qualification expiration from conversational shorthand.

### Setup / Takedown participation and eligibility

`ref.person_setup_role` supports the current controlled relationship values:

```text
SETUP_VOLUNTEER
TAKEDOWN_VOLUNTEER
CAPTAIN_CANDIDATE
ADVISOR_CANDIDATE
```

These roles describe participation/eligibility. They do not assign a Captain.

### Existing Setup leadership visibility

People Manager reads the existing `ref.setup_task_captain` relationship so a person's current reusable-task `CAPTAIN`, `ALTERNATE`, and `ADVISOR` assignments are visible. People Manager does not create or infer those assignments in this implementation slice.

## Still Separate / Future Work

- Google Workspace account provisioning remains owned by Google Admin / Workspace;
- Directus role/policy administration remains outside ordinary People contact editing;
- `ref.setup_task_capability` remains a Setup-consumer relationship for later Setup integration;
- authoritative capability/qualification seed evidence must be resolved to canonical `person_id` values before any seed/import; and
- governed person merge/reconciliation remains future work before duplicate cleanup becomes relationship-heavy.

## Folder Guide

| Folder | Purpose |
|---|---|
| `Application/` | Flask browser/API and static People Manager UI |
| `Database/` | Least-privilege PostgreSQL functions, metadata tables, and grants |
| `Acceptance/` | Disposable current-Production-clone acceptance and governed browser-review artifacts |

## Engineering Authority

Read the People/Identity engineering handoff first:

`Docs/02_Production_Database/01_System_Architecture/03_People_and_Identity/engineering/README.md`

Current implementation detail is recorded in:

`Docs/02_Production_Database/01_System_Architecture/03_People_and_Identity/engineering/People_Manager_Metadata_Implementation_2026-09-09.md`

The current Production Directus onboarding behavior is documented in:

`Directus_User_Onboarding_Identity_Contract_2026-09-09.md`

Acceptance commands/checklists are under:

`People/Acceptance/README.md`

Server/runtime mechanics are owned by `Gregovate/MSB-Server-Management`; People feature code consumes the existing disposable/browser/deployment runbooks rather than reconstructing those procedures.

## Production Boundary

Nothing in this directory authorizes a Production mutation. Because application/database behavior changed after the earlier disposable PASS, the new metadata candidate must pass a fresh current-Production disposable-clone gate and fresh browser review before a Production deployment gate can even be requested.
