# People and Identity — Engineering

This is the engineering starting point for Production Database work involving person identity, onboarding, contact data, authentication linkage, actor attribution, duplicate-safe person management, and the emerging People Manager.

## Current Authority

- [`../README.md`](../README.md) — subsystem overview
- [`Directus_User_Onboarding_Identity_Contract_2026-09-09.md`](Directus_User_Onboarding_Identity_Contract_2026-09-09.md) — current Production Directus onboarding behavior and People Manager identity lifecycle
- GitHub issue #130 — global People / Capability / Qualification catalog and duplicate-safe person management

## Current State

`ref.person` is the durable person identity. A person may exist without a Google Workspace account, Directus identity, PostgreSQL login, or active system access.

The Production Directus **User Onboarding** flow has now been inspected directly in the Directus administrative UI. It matches an existing `ref.person` by `email`, provided `directus_user_id` is null or already equals the triggering Directus user ID. If no matching person is found, the flow creates a new person row from the Directus user's first name, last name, email, and Directus user ID.

This establishes a critical People Manager rule: a manually added casual volunteer must already have their reserved Sheboygan Lights email stored on the existing `ref.person` row before a later first Google/Directus login if the same `person_id` is to be preserved automatically.

The People Manager, capability/qualification catalog, Google provisioning integration, and governed person merge are not installed in Production yet.

## Person Lifecycle

The intended identity lifecycle is:

```text
casual volunteer
    -> ref.person created manually
    -> personal_email used for ordinary contact/scheduling
    -> reserved @sheboyganlights.org email generated and stored on ref.person.email
    -> Google Workspace account may be created later
    -> once Google confirms the account exists, the MSB address becomes the business/deliverable address
    -> first Directus login links directus_user_id to the same person_id by exact MSB email match
```

If a person does not return in later seasons, keep the durable person record and set `active_flag = false`; do not delete the identity merely because the volunteer stopped participating. If they return later, the same identity should be reactivated rather than recreated.

## Resume Development

Before changing onboarding or People Manager behavior:

1. read the Directus onboarding identity contract;
2. inspect the current `ref.person` schema, indexes, constraints, and relationships;
3. preserve Google Workspace as the authority for whether an MSB account actually exists;
4. do not treat the presence of `ref.person.email` alone as proof that the address is deliverable;
5. preserve the current first-login Directus linking behavior unless a separately accepted change replaces it; and
6. prove duplicate prevention and identity transitions against a current Production clone before any Production mutation.
