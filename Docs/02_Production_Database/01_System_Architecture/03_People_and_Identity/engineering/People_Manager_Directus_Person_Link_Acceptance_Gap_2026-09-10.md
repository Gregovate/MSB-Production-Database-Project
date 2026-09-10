# People Manager Directus-Person Link Acceptance Gap — 2026-09-10

| Document Control | Value |
|---|---|
| Document Type | Engineering Acceptance Correction / Production Finding |
| System | People and Identity / People Manager |
| Status | CURRENT FINDING — Production identity reconciliation gap confirmed; no Production mutation authorized |
| Owner | Production Database / People and Identity |
| Finding Date | 2026-09-10 |
| Related | Issue #130; PR #135; Setup Issue #122 |

## Purpose

Record a confirmed acceptance gap discovered after the 2026-09-09 People Manager Production acceptance so future work does not treat the earlier PASS as proof that all Directus-to-`ref.person` identity-link requirements were validated.

This document corrects the engineering handoff. It does not alter the historical Production acceptance record and does not authorize a Production Directus Flow, `ref.person`, role, policy, or Setup change.

## Required Identity Acceptance That Was Written Before Production

The current [`Directus_User_Onboarding_Identity_Contract_2026-09-09.md`](Directus_User_Onboarding_Identity_Contract_2026-09-09.md) explicitly required, before any Production People Manager implementation was accepted, proof that:

```text
an existing casual volunteer with the staged MSB email
    -> later first Directus login
    -> links to the same existing ref.person.person_id
```

That requirement exists because Setup, Controller management, People Manager actor attribution, and other governed browser writes depend on the authenticated Directus user UUID mapping to `ref.person.directus_user_id`.

## What the People Manager Disposable Acceptance Actually Proved

`People/Acceptance/people_manager_disposable_server.sh` restored a current-Production clone, applied the People migrations, and selected an already-mapped Manager with:

```sql
SELECT u.email,p.person_id
FROM public.directus_users u
JOIN ref.person p ON p.directus_user_id=u.id
JOIN LATERAL ref.people_browser_capabilities(u.email) c ON true
WHERE u.status='active'
  AND c.can_manage_people
ORDER BY u.email
LIMIT 1;
```

That actor was then used to test People Manager create/edit/reactivate behavior, capability/qualification/Setup-role metadata, actor stamping, and least privilege.

The disposable acceptance did **not**:

- create or simulate a first-time Google Directus user;
- execute the Production Directus User Onboarding Flow;
- prove that a staged existing `ref.person` row received the triggering Directus UUID;
- audit all existing authorized Directus users for missing `ref.person.directus_user_id`; or
- test an already-established Directus user whose role was non-null but whose matching `ref.person` link was null.

Therefore the written first-login identity-link acceptance requirement was not satisfied by that acceptance harness.

## What the 2026-09-09 Production Acceptance Actually Proved

The historical Production acceptance record correctly proves the People application deployment, `people_app` least-privilege boundary, protected route, Manager authorization, browser behavior, GA4 behavior, and that Production `ref.person` remained unchanged during deployment.

For identity linkage, it proves only:

```text
missing Cloudflare identity -> HTTP 401
accepted mapped Manager identity -> authorized
```

It does not prove population-wide Directus/Person mapping completeness or first-login onboarding linkage.

The statement `PEOPLE MANAGER PRODUCTION ACCEPTANCE: PASS` must therefore not be interpreted as proof that every requirement in the Directus onboarding identity contract was exercised.

## Confirmed Production Evidence — 2026-09-10

A read-only Setup authorization/person-link audit found these exact-email cases:

```text
esandvig@sheboyganlights.org
    Directus role/policy = Manager
    can_manage_setup = true
    ref.person person_id = 29
    ref.person.email = exact match
    ref.person.directus_user_id = NULL

rmiller@sheboyganlights.org
    Directus role/policy = Manager
    can_manage_setup = true
    ref.person person_id = 19
    ref.person.email = exact match
    ref.person.directus_user_id = NULL

tshircel@sheboyganlights.org
    Directus role/policy = Manager
    can_manage_setup = true
    ref.person person_id = 31
    ref.person.email = exact match
    ref.person.directus_user_id = NULL
```

Other Manager/Administrator accounts in the same audit were correctly linked, proving this is not a universal Setup authorization failure.

A separate Administrator-authorized Directus identity, `greg@engrinnovations.com`, had no exact `ref.person.email` match and is therefore a different reconciliation case. It must not be auto-linked by name or guesswork.

## Randy Miller Repeat-Login Test

On 2026-09-10 Randy Miller explicitly visited `db.sheboyganlights.org`, authenticated through Google, and the same read-only audit was rerun.

Result:

```text
rmiller@sheboyganlights.org
    Directus user remains active Manager
    can_manage_setup remains true
    ref.person person_id 19 remains exact email match
    ref.person.directus_user_id remains NULL
```

This proves that merely logging into Directus again does not reconcile an already-established Manager account whose person link is missing.

## Root Cause in the Observed Directus Onboarding Flow

The documented Production Flow contains this gate before the Person-link operations:

```text
provider = google
AND
role IS NULL
```

Only users satisfying that condition proceed through the branch that sets the default role, reads `Person` by exact MSB email, and then either updates the existing person's `directus_user_id` or creates a new Person.

For an already-established Manager whose Directus role is non-null, a later login does not satisfy that onboarding branch. The flow is therefore a first-onboarding path, not a general Directus/Person reconciliation mechanism.

The prior operation-by-operation review accurately described the individual Flow operations but incorrectly treated that as sufficient validation of the complete identity lifecycle. The `role IS NULL` gate should have been identified as a coverage limitation before People Manager Production acceptance.

## Impact

An affected user may:

```text
authenticate successfully
    -> be an active Directus Manager
    -> pass ref.setup_browser_capabilities(...)
    -> see Manager-level Setup UI
    -> fail every governed human write that requires ref.person actor identity
```

Typical failure:

```text
Authenticated Setup operator is not mapped to an MSB person
```

This is not repaired by granting additional Setup table DML or by changing the Manager policy.

## Required Correction Direction

People and Identity owns the durable correction.

The repair must preserve:

- exact-email identity matching as the deterministic bridge;
- one durable `ref.person.person_id` per real person;
- current Directus role/policy authorization authority;
- fail-closed handling for conflicting Directus UUIDs;
- no automatic name-based identity guessing;
- protected `directus_user_id` from ordinary contact editing; and
- governed actor/audit attribution for human writes.

The durable mechanism must handle both:

```text
first-time Google/Directus onboarding
AND
already-established Directus users whose exact-email ref.person exists but directus_user_id is NULL
```

It must not require a person to remember to visit the Directus application solely to make unrelated protected MSB applications work.

## Immediate Production Repair Boundary

The three exact-email/null-link Manager cases are suitable for a focused reconciliation preflight because the Directus UUID, active Directus account, exact `ref.person.email`, existing person identity, and null link are all known.

Before any Production update, still verify:

1. each target `ref.person.directus_user_id` is still NULL;
2. the Directus UUID is not linked to another `ref.person` row;
3. the exact-email person is the intended durable identity;
4. no conflicting duplicate person exists;
5. current actor/audit triggers and People identity write contract are understood; and
6. rollback and post-update read-only validation are prepared.

The `greg@engrinnovations.com` no-person-match case must be handled separately.

## Acceptance Correction

People Manager remains deployed and its proven application/runtime behaviors remain valid. However, the People subsystem must no longer state or imply that the 2026-09-09 acceptance proved the Directus onboarding identity-link lifecycle end to end.

A future corrected acceptance must explicitly prove at least:

```text
A. existing person + staged MSB email + new Google Directus user
   -> same person_id gains correct directus_user_id

B. existing non-null-role Directus user + exact-email person + NULL link
   -> governed reconciliation safely links the existing person

C. conflicting UUID or ambiguous/no exact-email identity
   -> reconciliation fails closed

D. population-wide audit
   -> every authorized human account required to perform governed writes is either mapped or intentionally documented as an exception
```

## Related Documents

- [Directus User Onboarding Identity Contract](Directus_User_Onboarding_Identity_Contract_2026-09-09.md)
- [People and Identity engineering portal](README.md)
- [People Manager Production Acceptance](../../../../../People/Acceptance/People_Manager_Production_Acceptance_2026-09-09.md)
- [Setup and Deployment engineering portal](../../12_Setup_and_Deployment/engineering/README.md)
