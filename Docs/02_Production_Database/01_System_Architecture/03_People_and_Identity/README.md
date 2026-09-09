# People and Identity

This subsystem documents the people, authentication, authorization, onboarding, actor-attribution, reusable capability, qualification, and People Manager layer used by Production Database workflows.

## Current State

`ref.person` is the durable human/service identity record used by Production Database relationships and audit attribution. A person may exist as a casual or seasonal volunteer without a Google Workspace account, Directus identity, or PostgreSQL login.

The People Manager engineering scope has now passed current-Production disposable-clone acceptance and governed browser operator review. The accepted implementation is ready for the separate Production deployment gate; it is not yet installed in Production.

The People Manager provides controlled maintenance for:

- person/contact information;
- active/inactive lifecycle;
- duplicate-safe create/edit;
- reserved Sheboygan Lights email identity;
- reusable capabilities;
- formal dated qualifications and evidence;
- Setup/Takedown participation and Captain/Advisor eligibility; and
- read-only reusable-task Captain/Alternate/Advisor visibility.

Plain-English operator procedures are under [Operational SOPs — People](../../02_Operational_SOPs/People/README.md).

## Identity and Onboarding Contract

The current Production Directus **User Onboarding** flow matches an existing `ref.person` by MSB email when `directus_user_id` is null or already matches the triggering Directus user. If no person matches, the flow creates a new active person from the Directus user's name, email, and Directus ID.

This establishes a critical People Manager rule: a manually added volunteer can reserve the intended `@sheboyganlights.org` identity on the existing person before first Google/Directus login so the current onboarding flow can later link the same durable `person_id` by email.

A reserved MSB email does not prove that Google Workspace has provisioned a mailbox. Google Workspace remains the provisioning/deliverability authority.

## Design Intent

Maintain one durable person identity while allowing authentication, authorization, and application-specific relationships to change independently.

If a person stops participating, normally mark the person inactive rather than deleting the identity. If the same person returns later, reactivate the same `person_id` rather than creating a replacement person.

The People metadata model deliberately separates:

```text
Person identity/contact
    -> who the person is and how to contact them

Capability
    -> reusable skill, experience, or practical MSB knowledge

Qualification
    -> formal training/certification/authorization with dates/evidence

Setup role
    -> Setup/Takedown participation or leadership eligibility

Setup task leadership
    -> actual Captain / Alternate / Advisor responsibility for a reusable task
```

Capabilities, qualifications, and eligibility never automatically create Captain assignments.

## Current Responsibilities

- `ref.person` and `ref.person_xref` durable identity
- casual/seasonal volunteer lifecycle
- reserved MSB identity for later onboarding linkage
- Google-authenticated user access boundary
- Directus user linkage and role/policy authorization context
- actor attribution used by PostgreSQL audit behavior
- capability and qualification catalogs/relationships
- Setup/Takedown participation and eligibility relationships
- People Manager browser/API and least-privilege command boundary
- People-specific operator procedures and engineering documentation

## Google Analytics

The People application includes the required MSB internal GA4 integration using measurement ID `G-X08ZTSY0VV`.

Only aggregate page/workflow usage may be sent. Person names, emails, phone numbers, `person_id`, authenticated identity, search text, and other Production Database record identifiers are prohibited. Google Signals and advertising personalization remain disabled.

Production acceptance must verify the deployed People page view and analytics asset/version before final closeout.

## Engineering

Start with [People and Identity — Engineering](engineering/README.md).

Key current records include:

- [Directus User Onboarding Identity Contract — 2026-09-09](engineering/Directus_User_Onboarding_Identity_Contract_2026-09-09.md)
- [People Manager Metadata Implementation — 2026-09-09](engineering/People_Manager_Metadata_Implementation_2026-09-09.md)
- `People/Acceptance/People_Manager_Metadata_Disposable_Acceptance_Evidence_2026-09-09.md`
- `People/Acceptance/People_Manager_Browser_Review_Acceptance_2026-09-09.md`

## Directus / Google Ownership Boundaries

Directus remains the authorization authority for application role/policy behavior. Google Workspace remains the authority for account/mailbox provisioning.

People Manager does not replace either system. It maintains the durable Production Database person identity and People metadata that those and other operational systems reference.

## Accepted Current Scope vs Future Work

The accepted People Manager scope does **not** include:

- Google Workspace account creation;
- ordinary Directus role/policy administration;
- automatic capability/qualification seeding from shorthand names;
- `ref.setup_task_capability` Setup-task-to-capability integration; or
- governed person merge/reconciliation.

Those remain separate future work and do not block deployment of the accepted People Manager.

## Related Systems

- [Database Foundation](../01_Database_Foundation/README.md)
- [Containers and Storage](../04_Containers_and_Storage/README.md)
- [Testing System](../05_Testing_System/README.md)
- [Work Orders](../06_Work_Orders/README.md)
- [Setup and Deployment](../12_Setup_and_Deployment/README.md)

## Resume Development

Read the current [engineering handoff](engineering/README.md), onboarding identity contract, accepted browser/disposable evidence, and the plain-English People operator procedure before changing this subsystem. Preserve Google Workspace provisioning authority, Directus authorization authority, duplicate-safe identity behavior, least privilege, and the existing People analytics privacy boundary.
