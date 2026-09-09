# People and Identity

This subsystem documents the people, authentication, authorization, onboarding, and actor-attribution layer required for Production Database access and operational workflows.

## Current State

Operational database access depends on a person identity that can be related to authentication and application roles. Directus is currently used for user/role administration and selected onboarding automation.

`ref.person` is the current durable human/service identity record used by Production Database relationships and audit attribution. A person may also exist as a casual or seasonal volunteer without a Google Workspace account, Directus identity, or PostgreSQL login.

The current Production Directus **User Onboarding** flow has now been inspected directly from the Directus administrative UI. The observed flow matches an existing `ref.person` by MSB email when `directus_user_id` is null or already matches the triggering Directus user. If no person matches, the flow creates a new active person from the Directus user's name, email, and Directus ID. The detailed observed contract is preserved under [Engineering](engineering/README.md).

People/Identity is not required for LOR authoring or parsing, but it is required before volunteers can perform authenticated Production Database work such as container testing, work-order activity, label requests, and other audited operations.

## Design Intent

Maintain one durable person identity that can participate in database relationships while allowing authentication and application-specific identities to change independently.

For casual/seasonal volunteers, preserve the same `person_id` over time. If a person does not return in later seasons, mark the person inactive rather than deleting the identity; reactivate the same record if the person returns.

The People Manager must support later conversion of a casual volunteer into a system user without creating a second person. For a manually created volunteer, the intended `@sheboyganlights.org` identity is reserved on the existing person before first Google/Directus login so the current onboarding flow can link the same `person_id` by email.

A richer reusable role/skill taxonomy may be considered as part of the active People Manager work tracked in issue #130; it is not part of the current implemented identity model.

## Current Responsibilities

- `ref.person` and related person metadata
- durable casual/seasonal volunteer identity
- Google-authenticated user access
- Directus user linkage
- Directus roles/policies and low-level initial access
- onboarding automation
- actor attribution used by PostgreSQL audit behavior
- metadata needed by operational subsystems

## Engineering

Start with [People and Identity — Engineering](engineering/README.md).

The current Production onboarding behavior and the accepted casual-volunteer-to-team identity lifecycle are documented in [Directus User Onboarding Identity Contract — 2026-09-09](engineering/Directus_User_Onboarding_Identity_Contract_2026-09-09.md).

## Directus Ownership

The Directus User Onboarding flow belongs with this subsystem because it implements the People/Identity business process. Shared Directus platform notes may be documented elsewhere, but onboarding behavior should be documented here.

The active Production flow involving `ref.person` was inspected operation-by-operation on 2026-09-09 and is now documented in the engineering identity contract. No Production flow or database configuration was changed during that reconnaissance.

## Known Open Work

- verify the human-readable Directus role corresponding to the observed default-role UUID before documenting its role name
- verify current role/policy assignment behavior beyond the observed onboarding branch
- design the People Manager manual-create path that generates/reserves a collision-safe Sheboygan Lights email
- provide an authoritative mechanism for determining whether the reserved MSB email has actually been provisioned in Google Workspace before applications treat it as deliverable
- implement duplicate-safe person create/edit behavior and later governed merge behavior under issue #130
- document current failure/recovery behavior for incomplete onboarding

## Related Systems

- [Database Foundation](../01_Database_Foundation/README.md)
- [Containers and Storage](../04_Containers_and_Storage/README.md)
- [Testing System](../05_Testing_System/README.md)
- [Work Orders](../06_Work_Orders/README.md)

## Resume Development

Read the current [engineering handoff](engineering/README.md) and onboarding identity contract, then inspect current PostgreSQL person structures and current Directus role/policy configuration before editing this subsystem. Do not rely on older Directus MVP or legacy database-structure documents as current authority.
