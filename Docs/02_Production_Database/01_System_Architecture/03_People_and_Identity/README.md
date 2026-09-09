# People and Identity

This subsystem documents the people, authentication, authorization, onboarding, actor-attribution, contact, capability, and qualification layer required for Production Database access and operational workflows.

## Current State

Operational database access depends on a person identity that can be related to authentication and application roles. Directus is currently used for user/role administration and selected onboarding automation.

`ref.person` is the current durable human/service identity record used by Production Database relationships and audit attribution. It is also the correct durable identity/contact authority for volunteers who may not have a Sheboygan Lights email, Directus account, or PostgreSQL login.

The current table contains practical operational fields such as `active_flag` and `available_for_work_orders`, but the 2025 Setup reconstruction has now established a real need for richer reusable People data that should not be represented as an expanding set of subsystem-specific booleans.

That live operational evidence includes reusable capabilities such as Welding, Electrical, Networking, and Panel Building / Rope Lighting, together with formal dated qualifications such as Lift Equipment — Train the Trainer. Duplicate person rows have also been encountered, proving that surrogate `person_id` values alone are not sufficient duplicate prevention.

The global People/Skills/Qualifications design is tracked in issue #130 and under [Engineering](engineering/README.md). No global capability/qualification tables or People Manager have been installed in Production yet.

People/Identity is not required for LOR authoring or parsing, but it is required before volunteers can perform authenticated Production Database work such as container testing, work-order activity, label requests, and other audited operations. It is also increasingly useful to non-authenticated volunteer/contact workflows such as Setup/Takedown planning.

## Design Intent

Maintain one durable person identity that can participate in database relationships while allowing authentication and application-specific identities to change independently.

The richer reusable role/skill taxonomy is no longer merely hypothetical. Live Setup review has justified a global capability/qualification model, while Setup-specific participation and Captain eligibility remain consumer relationships rather than ownership of global People data.

Current design direction:

```text
EXISTING GLOBAL AUTHORITY
ref.person
ref.person_xref

PROPOSED GLOBAL PEOPLE TABLES
ref.person_capability_type
ref.person_capability
ref.person_qualification_type
ref.person_qualification

PROPOSED SETUP CONSUMER RELATIONSHIPS
ref.person_setup_role
ref.setup_task_capability

EXISTING SETUP TASK LEADERSHIP
ref.setup_task_captain
```

Capabilities represent reusable skill/experience/knowledge. Qualifications represent formal dated training/certification/authorization. Setup role/eligibility and actual Captain assignment are separate facts.

## Current Responsibilities

- `ref.person` and related person metadata
- contact identity for members/volunteers, including people without application logins
- Google-authenticated user access
- Directus user linkage
- Directus roles/policies and low-level initial access
- onboarding automation
- actor attribution used by PostgreSQL audit behavior
- metadata needed by operational subsystems
- engineering ownership of the emerging global capability/qualification catalog
- duplicate-safe person creation/merge design

## Engineering

Start with [People and Identity — Engineering](engineering/README.md).

Current design authority:

- [People Capability / Qualification Catalog Design — 2026-09-08](engineering/People_Capability_Qualification_Catalog_Design_2026-09-08.md)
- GitHub issue #130 — implementation/reconnaissance tracker

The People Manager is intended to be a global People/Identity application area for contact information, capabilities, qualifications, active/inactive state, duplicate detection, and governed merge behavior. Setup and other systems consume this authority.

## Setup Integration Boundary

The 2025 Setup reconstruction exposed this need but does not own the global People model.

Setup-specific facts may include:

```text
SETUP_VOLUNTEER
TAKEDOWN_VOLUNTEER
CAPTAIN_CANDIDATE
ADVISOR_CANDIDATE
```

Actual reusable-task leadership remains in `ref.setup_task_captain`.

The current Setup Captain candidate has a narrow migration, `Setup/Database/022_require_active_setup_captain_people.sql`, that restricts new Captain selection/assignment to active `ref.person` rows. Future Captain Candidate filtering depends on the global People work; it must not infer Captain assignment from 2025 crew names, capabilities, or qualifications.

## Duplicate Person Boundary

`person_id` is a surrogate key, not proof of unique human identity.

Person creation should search existing people first using normalized name/contact evidence. Names must not become globally unique because different people may share a name. Personal email/phone also require caution because family contact information may be shared.

Once People relationships become richer, person deletion should be replaced by a governed merge/reconciliation workflow that repoints known relationships, preserves audit/history, and fails closed on unknown/future foreign-key references rather than using broad `CASCADE` behavior.

## Directus Ownership

The Directus User Onboarding flow belongs with this subsystem because it implements the People/Identity business process. Shared Directus platform notes may be documented elsewhere, but onboarding behavior should be documented here.

The documentation audit also identified at least one active Directus Flow involving `ref.person` whose behavior has not yet been captured. That flow must be inspected from the current production Directus configuration before it is documented; do not reconstruct it from memory or the legacy architecture notes.

## Known Open Work

- issue #130 — global People capability/qualification catalog and duplicate-safe People Manager
- inventory all current foreign keys and uniqueness constraints involving `ref.person`
- recover legacy spreadsheet / To-Do talent data if available
- resolve known capability/qualification shorthand names to canonical `person_id` values before any seed/import
- design and prove duplicate detection / governed merge behavior
- document the current User Onboarding flow from the production Directus configuration
- inspect and document the active Directus Flow involving `ref.person`
- verify current role/policy assignment behavior
- document required metadata and identity-linking fields
- document current failure/recovery behavior for incomplete onboarding

## Related Systems

- [Database Foundation](../01_Database_Foundation/README.md)
- [Containers and Storage](../04_Containers_and_Storage/README.md)
- [Testing System](../05_Testing_System/README.md)
- [Work Orders](../06_Work_Orders/README.md)
- [Setup and Deployment](../12_Setup_and_Deployment/README.md)

## Resume Development

Inspect the current PostgreSQL person structures and current Directus user/role/onboarding configuration before editing this subsystem. Read the current engineering design and issue #130 before adding schema. Do not rely on older Directus MVP or legacy database-structure documents as current authority.
