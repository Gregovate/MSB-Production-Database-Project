# Directus Onboarding Identity Error Propagation Finding — 2026-09-10

| Document Control | Value |
|---|---|
| Document Type | Engineering Production Finding |
| System | People and Identity / Directus onboarding |
| Status | CURRENT FINDING — operator provisioning error confirmed; no Production change authorized |
| Owner | Production Database / People and Identity |
| Finding Date | 2026-09-10 |

## Purpose

Record the corrected provenance of the Production identity `mark@sheboyganlights.org` and the hardening implication for the current Directus User Onboarding Flow.

## Corrected Provenance

The Production audit identified:

```text
Directus email       mark@sheboyganlights.org
Directus UUID        f810e959-8d33-4f34-9b85-0f23cdd179e9
provider             google
role                 0ce54f42-8438-4eb6-8081-4303612c9da1
ref.person           person_id 58
Person created       2026-08-05 10:33:24 -0500
created_by           directus_app
created_by_person_id NULL
updated_by           directus_app
updated_by_person_id NULL
```

Operator clarification established that this identity belongs to **Mark Rozmarynowski** and was created under the wrong MSB address during onboarding. It is **not Mark Hayon**, whose actual Google/MSB account is `mhayon@sheboyganlights.org`.

Therefore:

- `mark@sheboyganlights.org` is not evidence that Directus spontaneously invented an account;
- it is not evidence for the historical Mark Hayon scan problem;
- it is an operator onboarding error that the current Directus onboarding path propagated into `ref.person`.

## Hardening Consequence

The current Production User Onboarding Flow performs an exact-email lookup in `ref.person`. If no matching Person exists, its reject branch creates a new Person from the Directus user identity.

That behavior means an upstream provisioning mistake can become durable Person data:

```text
wrong Directus / Google identity
    -> no exact ref.person.email match
    -> Flow takes Add Person branch
    -> wrong identity becomes a new durable ref.person row
```

The Flow therefore has two distinct failure classes that must be addressed in the corrected lifecycle:

1. **Missed linkage** — an existing correct Person and established Directus user can remain unlinked because reconciliation occurs only during the one-shot `directus_users.items.create` Flow.
2. **Bad identity propagation** — an incorrect newly-created Directus identity can cause a new Person to be created automatically instead of being stopped for review.

## Required Design Direction

Under the current People Manager model, `ref.person` is the durable person authority and can reserve the intended MSB identity before Google/Directus provisioning. The corrected onboarding path should therefore treat an exact Person match as required evidence for automatic linkage.

Recommended fail-closed behavior for normal human onboarding:

```text
exact email Person exists + directus_user_id NULL + UUID unused
    -> link existing Person

same exact Person already linked to same UUID
    -> no-op / success

no exact Person match
    -> STOP / Administrator review
    -> do not silently create a new Person

Person already linked to another UUID
    -> STOP / conflict

UUID already linked to another Person
    -> STOP / conflict
```

Any future capability to create a Person from Directus must be an explicit separately-governed workflow, not an automatic fallback from failed identity reconciliation.

## Audit Finding

The Person row created for the incorrect `mark@sheboyganlights.org` identity has both `created_by_person_id` and `updated_by_person_id` NULL. This is consistent with the confirmed `ref.set_actor_on_insert()` behavior, which attempts actor stamping but does not hard-fail if no Person actor can be resolved.

That audit behavior is a separate hardening concern from the operator provisioning error itself.

## Current Boundary

This finding does not authorize deleting or renaming the `mark@sheboyganlights.org` Directus user or Person row. Any cleanup must first identify dependent references and use the normal Production change gate.

It also does not establish the cause of Mark Hayon's historical scan problem. That issue must be evaluated against `mhayon@sheboyganlights.org`, not `mark@sheboyganlights.org`.

## Related Documents

- [Directus User Onboarding Identity Contract](Directus_User_Onboarding_Identity_Contract_2026-09-09.md)
- [Directus Access and Identity Bootstrap Contract](Directus_Access_and_Identity_Bootstrap_Contract_2026-09-10.md)
- [People Manager Directus-Person Link Acceptance Gap](People_Manager_Directus_Person_Link_Acceptance_Gap_2026-09-10.md)
- [Directus Production Permission Matrix](Directus_Production_Permission_Matrix_2026-09-10.md)
