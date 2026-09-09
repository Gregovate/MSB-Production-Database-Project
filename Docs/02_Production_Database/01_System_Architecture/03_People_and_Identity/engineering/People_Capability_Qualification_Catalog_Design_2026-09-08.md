# People Capability / Qualification Catalog Design — 2026-09-08

| Document Control | Value |
|---|---|
| Document Type | Engineering Design / Reconnaissance |
| System | People and Identity |
| Status | DESIGN CANDIDATE — NOT APPLIED TO PRODUCTION |
| Owner | Production Database / People and Identity |
| Issue | #130 |
| Related | Setup #122, PR #125 |
| Last Reviewed | 2026-09-08 |

## Purpose

The 2025 Setup reconstruction exposed a broader missing Production Database capability: MSB has durable operational knowledge about volunteers and members — skills, specialized display/build knowledge, formal training, and Setup/Takedown participation — but that knowledge is not represented in the current PostgreSQL People model.

This is a **global People and Identity concern**, not a Setup-owned data model. Setup is the first active consumer that demonstrated the need.

The design goal is to preserve one durable person identity while allowing multiple operational systems to consume reusable capability and qualification information without adding a new boolean to `ref.person` for every subsystem.

## Current Authority

`ref.person` remains the durable master person/contact identity.

Current observed fields include:

```text
person_id
first_name
last_name
preferred_name
email
cell_phone
active_flag
is_manager
created_at / created_by
updated_at / updated_by
is_team
personal_email
directus_user_id
pg_login_name
created_by_person_id
updated_by_person_id
available_for_work_orders
```

A person may legitimately exist in `ref.person` without a Sheboygan Lights email, Directus user, PostgreSQL login, or Manager status. This is useful for Setup/Takedown-only volunteers and other contacts whose identity/contact information must still be durable.

`person_id` is a surrogate key. It distinguishes rows; it does **not** prove two rows are different people.

A duplicate person was found manually during the Setup review and could be deleted only because no meaningful relationships depended on the duplicate yet. Once capabilities, qualifications, Captain assignments, Work Orders, or other relationships exist, duplicate resolution must be governed.

## Why Existing Flags Are Not Enough

`active_flag` answers whether the person record is active.

`available_for_work_orders` is an existing subsystem-oriented eligibility flag, but continuing that pattern for every new workflow would eventually create many unrelated booleans such as Setup volunteer, Takedown volunteer, Captain candidate, welder, electrician, lift trained, etc.

Those facts are not the same category:

- active person identity;
- participation/eligibility for a workflow;
- durable skill or practical knowledge;
- formal dated qualification/certification;
- actual assignment to a specific reusable task.

The schema should model those separately.

## Naming / Grouping Direction

The `ref` schema already groups related tables by domain prefix (`controller_*`, `display_*`, `setup_*`). The People subsystem should follow the same pattern so related objects remain discoverable together.

### Existing

```text
ref.person
ref.person_xref
```

### Proposed global People tables

```text
ref.person_capability_type
ref.person_capability
ref.person_qualification_type
ref.person_qualification
```

### Proposed Setup integration

```text
ref.person_setup_role
ref.setup_task_capability
```

### Existing Setup relationship

```text
ref.setup_task_captain
```

Do not rename global People facts with a `setup_` prefix merely because Setup first exposed the need.

## Capability Model

A capability is reusable skill, experience, or MSB-specific practical knowledge.

Examples discovered during live review include:

```text
Welding
Electrical
Networking
Panel Building / Rope Lighting
Racing Arches Assembly
Mega Tree Assembly
Controller Wiring
```

`ref.person_capability_type` is the controlled catalog. `ref.person_capability` relates a person to one catalog capability.

Recommended initial catalog fields:

```text
person_capability_type_id
capability_name
capability_category
notes
active_flag
sort_order
created_at / created_by_person_id
updated_at / updated_by_person_id
```

Potential categories should remain intentionally small and may include:

```text
TRADE
TECHNICAL
DISPLAY_BUILD_KNOWLEDGE
EQUIPMENT
OTHER
```

`ref.person_capability` should minimally contain:

```text
person_id
person_capability_type_id
active_flag
notes
created_at / created_by_person_id
updated_at / updated_by_person_id
```

Initial implementation should **not** invent skill levels such as beginner/intermediate/expert without real operational evidence that those distinctions are needed.

## Qualification Model

A qualification is formal training, certification, authorization, or credential whose validity may depend on dates or evidence.

This must remain separate from capabilities.

Example discovered during live review:

```text
Lift Equipment — Train the Trainer
training date: 2026-08-18
stated validity: 3 years
```

`ref.person_qualification_type` is the controlled qualification catalog.

`ref.person_qualification` should support at least:

```text
person_id
person_qualification_type_id
completed_on
valid_from
expires_on
qualification_role
certificate_number          nullable
evidence_reference          nullable
active_flag
notes
created_at / created_by_person_id
updated_at / updated_by_person_id
```

Do not calculate or seed an exact expiration date from conversational shorthand. Use the authoritative training documentation/certificate when the durable record is created.

## Setup Participation / Leadership Eligibility

Setup-specific participation should not be encoded as general capabilities.

Proposed `ref.person_setup_role` values include:

```text
SETUP_VOLUNTEER
TAKEDOWN_VOLUNTEER
CAPTAIN_CANDIDATE
ADVISOR_CANDIDATE
```

A person may have several active rows.

These roles answer whether someone participates in or is eligible for a Setup/Takedown function. They do **not** assign that person to a particular reusable task.

Actual reusable-task leadership remains in the existing:

```text
ref.setup_task_captain
```

with roles such as Captain, Alternate, and Advisor.

The intended distinction is:

```text
Person capability
    -> what this person knows/can do

Person qualification
    -> formal training/certification/authorization

Person Setup role
    -> whether/how this person participates in Setup/Takedown

Setup task capability
    -> what knowledge/skill is useful for a reusable task

Setup task captain
    -> who actually owns leadership/knowledge responsibility for this task
```

Capabilities, historical crew notes, or qualifications must never automatically create Captain assignments.

## Setup Task Capability Relationship

Proposed `ref.setup_task_capability` relates a reusable Setup task to the capabilities useful for that task.

This enables the application to answer:

> Who may be useful for this work?

without answering the separate question:

> Who is the Captain?

Stage/Scene familiarity should initially be **derived through reusable task scope and task capability relationships**, rather than adding separate person-to-Stage or person-to-Scene tables.

Example:

```text
Person -> Racing Arches Assembly capability
Capability -> Install Racing Arches reusable task
Reusable task -> Stage / Scene scope
```

The UI can therefore show where a person's knowledge is useful without maintaining redundant direct Stage assignments.

## Known Initial Evidence — Resolve Before Any Seed

The following shorthand names came from live operational discussion and are useful reconstruction evidence only. They must be resolved against existing `ref.person.person_id` values before any database seed/import. Do not create new people from initials alone.

### Welding

```text
Tom S
Seve R
Mark H
Greg L
```

### Electrical

```text
Tim P
Rich N
John H
Greg L
```

### Panel Building / Rope Lighting

```text
Paul N
Mike V
Rick H
Adam B
```

### Networking

```text
Greg L
Adam B
Rich N
```

### Lift Equipment — Train the Trainer

Training date stated as 2026-08-18; validity stated as three years:

```text
Tom S
Paul N
Greg L
Rich N
John H
Mark H
```

These are not yet durable database assignments. Exact person identity and qualification evidence must be confirmed first.

## People Manager Direction

A dedicated People Manager should be a global People/Identity application area rather than being buried inside the Setup task editor.

Initial responsibilities:

- search current people before create;
- create/edit contact information;
- active/inactive person state;
- capabilities;
- formal qualifications and expiration dates;
- Setup/Takedown participation/eligibility as a consumer relationship;
- visibility of Captain/Advisor assignments;
- duplicate detection during create/edit; and
- governed person merge/reconciliation.

Setup may link to or embed selected People Manager functions, but Setup should consume this global authority rather than own it.

## Duplicate Prevention

People creation must search first.

Potential duplicate detection should consider normalized combinations of:

- first/preferred/last name;
- MSB email;
- personal email; and
- phone number.

Do not make a person's name globally unique. Different people may legitimately share a name.

Be cautious about global uniqueness on personal email or phone because shared family contact information may occur.

`directus_user_id` and `pg_login_name` should remain unique when present according to the current identity contract.

## Governed Person Merge

A future merge command is required before the People catalog becomes heavily referenced.

Conceptual behavior:

```text
source duplicate person
    -> target canonical person
        -> inspect all current FK relationships
        -> repoint safe known relationships
        -> merge/deduplicate capabilities and qualifications
        -> preserve Captain/Advisor/Work Order/audit relationships
        -> fail closed on unknown/future references
        -> preserve audit evidence
        -> delete source only after all guards pass
```

Do not use broad `CASCADE` semantics.

A merge must be reconstruction-safe and idempotent/convergent where practical.

## Immediate Setup Captain Fix

The global People catalog is separate from the narrow Captain defect discovered during preview.

`Setup/Database/022_require_active_setup_captain_people.sql` currently addresses the immediate rule:

- Captain picker candidates must be active `ref.person` rows;
- the governed Captain write command must refuse new/updated assignment to an inactive person;
- an already-recorded Captain relationship may remain readable after the person later becomes inactive; and
- removal remains possible so durable history is not hidden.

Future `CAPTAIN_CANDIDATE` eligibility should tighten this further once `ref.person_setup_role` exists.

## Legacy Spreadsheet / To-Do Evidence

The prior spreadsheet-based To-Do system reportedly carried talent concepts such as Electrical and Welding. That knowledge was not preserved as a current PostgreSQL skill taxonomy during migration.

Before seeding the new capability catalog, locate and inspect the original spreadsheet/talent list if it remains available. Use it as evidence; do not rebuild the entire catalog from memory.

## Acceptance Gates

Before Production mutation:

1. inventory all current FKs and dependencies on `ref.person`;
2. inventory current uniqueness constraints/indexes on person identity fields;
3. recover and review legacy spreadsheet talent data if available;
4. confirm table/column names against repository naming standards and current schema;
5. build idempotent migrations on a current Production clone;
6. prove least-privilege read/write commands;
7. prove inactive-person and duplicate-person guards;
8. prove person merge against representative relationships without broad DML/CASCADE;
9. resolve shorthand names to canonical `person_id` values before any seed;
10. preserve capabilities separately from formal qualifications; and
11. integrate Setup, Work Orders, and later systems as consumers rather than competing authorities.

## Current Boundary

This document records architecture direction only.

No global People capability/qualification tables have been created in Production, no skill/qualification seed has been authorized, and no person merge command is currently available.
