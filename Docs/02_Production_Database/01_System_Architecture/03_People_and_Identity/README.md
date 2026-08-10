# People and Identity

This subsystem documents the people, authentication, authorization, onboarding, and actor-attribution layer required for Production Database access and operational workflows.

## Current State

Operational database access depends on a person identity that can be related to authentication and application roles. Directus is currently used for user/role administration and selected onboarding automation.

`ref.person` is the current durable human/service identity record used by Production Database relationships and audit attribution. The current model uses direct person fields/flags for practical operational distinctions rather than the older unimplemented `ref.user`, `ref.role`, `ref.user_role`, `ref.skill`, `ref.skill_level`, and `ref.user_skill` design from the legacy database-structure document.

People/Identity is not required for LOR authoring or parsing, but it is required before volunteers can perform authenticated Production Database work such as container testing, work-order activity, label requests, and other audited operations.

## Design Intent

Maintain one durable person identity that can participate in database relationships while allowing authentication and application-specific identities to change independently.

A richer reusable role/skill taxonomy may be considered later if a real operational need justifies it, but it is not part of the current implemented identity model.

## Current Responsibilities

- `ref.person` and related person metadata
- Google-authenticated user access
- Directus user linkage
- Directus roles/policies and low-level initial access
- onboarding automation
- actor attribution used by PostgreSQL audit behavior
- metadata needed by operational subsystems

## Directus Ownership

The Directus User Onboarding flow belongs with this subsystem because it implements the People/Identity business process. Shared Directus platform notes may be documented elsewhere, but onboarding behavior should be documented here.

The documentation audit also identified at least one active Directus Flow involving `ref.person` whose behavior has not yet been captured. That flow must be inspected from the current production Directus configuration before it is documented; do not reconstruct it from memory or the legacy architecture notes.

## Known Open Work

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

## Resume Development

Inspect the current PostgreSQL person structures and current Directus user/role/onboarding configuration before editing this subsystem. Do not rely on the older Directus MVP or legacy database-structure documents as current authority.
