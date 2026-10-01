# People Manager Directus Access Provisioning Contract — 2026-10-01

| Document Control | Value |
|---|---|
| Document Type | Engineering Contract / Production Finding / Operator Workflow |
| System | People and Identity / People Manager / Directus |
| Status | CURRENT — Adam Biebel no-first-login pilot proven; People Manager provisioning workflow required |
| Owner | Production Database / People and Identity |
| Evidence Date | 2026-10-01 |
| Related | Issue #130; PR #135; Setup Issue #122 |

## Purpose

Define the corrected operator and engineering contract for provisioning Directus identity and role access from the MSB People system.

The existing operational process required a Google Workspace user to visit Directus before a Directus UUID existed. The operator then had to return to Directus and edit the user's role. That process is not acceptable as the long-term MSB onboarding workflow because Directus identity and role assignment are required by other MSB applications before first Directus use.

This document records the Production evidence gathered on 2026-10-01 and the required People Manager workflow.

## Current People Manager Surface

People Manager is live at:

```text
https://my.sheboyganlights.org/people/
```

The current Person detail screen already owns durable Person/contact management and shows a read-only protected system-state section containing:

```text
Directus linked
PostgreSQL login linked
Legacy Manager flag
Legacy Team flag
Available for Work Orders
```

The current UI therefore tells the operator only whether a Directus link exists. It does not show the current Directus role, Directus status, or provide a governed provisioning action.

That is insufficient because these are materially different states:

```text
Directus linked = Yes, role = MSB Browser
Directus linked = Yes, role = Production Crew
Directus linked = Yes, role = Manager
Directus linked = Yes, role = Administrator
```

## Clarified People / Contact / Google / Database-Access Model — 2026-10-01

The People system must not equate a Person record, an MSB-style email identity, Production participation, a Google Workspace account, or database-application access.

These are separate facts.

### 1. Person / contact identity — applies to everyone

`ref.person` is the uniform MSB contact identity for:

- organization members;
- Production Crew members;
- Setup/Takedown helpers;
- seasonal/casual volunteers;
- people who want to help but do not want organization membership;
- people who should receive notifications/schedules but must not access database applications.

Creating a Person must **not** grant application access.

### 2. Reserved Sheboygan Lights identity is not a Google account

People Manager currently generates/reserves an `@sheboyganlights.org` value when a Person is added.

That value is a **reserved MSB/system identity string**, not a fictitious or real Google Workspace account.

There is currently no automatic People Manager -> Google Workspace provisioning link.

Therefore:

```text
ref.person.email exists
    != Google Workspace account exists
    != mailbox is deliverable
    != Directus user exists
    != database application access is granted
```

The reserved identity remains useful for deterministic future identity matching even when the person never becomes a Google/Directus user.

### 3. Communication/contact is independent from system access

The People system is the uniform contact list for operational communication such as notifications and schedules.

A volunteer does not need a Google Workspace or Directus account to remain a valid communication recipient.

`personal_email` remains an ordinary deliverable contact channel when known.

The system must not send mail to a reserved `ref.person.email` merely because the value exists. A future notification/scheduling consumer must use a contact address known to be deliverable rather than infer mailbox existence from the reserved MSB identity.

The exact preferred-email/deliverability field or rule must be established before a scheduler automatically chooses between personal and MSB email.

### 4. Participation is independent from database access

Production participation, Setup/Takedown participation, Captain/Advisor eligibility, and database authorization are separate facts.

Examples:

```text
Setup helper
    -> may be active Person
    -> may receive schedules/notifications
    -> may have no Google Workspace account
    -> may have no Directus identity
    -> must have no database application access

Production participant / helper
    -> may still be contact-only
    -> must not receive Directus access merely because they help Production

Google Workspace user
    -> may exist for a non-Production purpose
    -> must not automatically receive Production Crew database role
```

Do not infer Directus `Production Crew` authorization from Setup/Takedown helper status or ordinary Person activity.

### 5. Google Workspace is authentication eligibility, not automatic authorization

Database applications use Google authentication through Directus.

Only people who actually have the appropriate Google Workspace identity and are intentionally granted database application access should receive a Directus user/role.

A Google Workspace account is **necessary for Google-authenticated Directus access but is not by itself sufficient to grant database access**.

There are Sheboygan Lights Google users who are not Production Crew and must not be assigned the Production Crew Directus role merely because their account exists.

### 6. Directus role is explicit database-application authorization

Directus identity/role is the database-application authorization layer.

The operator must explicitly choose the intended database role when provisioning access.

For the People Manager workflow:

```text
Person/contact record
    -> no database access by default

operator confirms the person has the real Google Workspace account
    + operator intentionally selects database access role
    -> provision Directus identity
    -> link exact Person
    -> assign selected Directus role
```

Creating a new Person must **not automatically provision Directus**.

The access action is a separate governed action on the existing Person page.

## Current Directus Role Evidence

Confirmed Production roles relevant to onboarding include:

```text
MSB Browser
role_id = 0ce54f42-8438-4eb6-8081-4303612c9da1

Production Crew
role_id = edd36182-2029-4bfa-b6ca-1fa9a9b771a9
policy  = Volunteer
policy_id = b6c0dfb6-c4fe-49c6-b038-f3426e8e1399

Manager
role_id = ea935743-c437-45e5-a90a-7224350429f3

Administrator
role_id = 655ce69d-0e9e-4fda-a839-b0039ffc43eb
```

Production evidence also confirms existing Google-backed Directus users use:

```text
provider = google
external_identifier = Sheboygan Lights email
```

## Production Crew Membership Is Input, Not the Entire Identity Decision

Many intended users are already members of the Google Production Crew group and should receive the Directus Production Crew role.

However, Google group membership must not blindly override the durable Person lifecycle.

The 2026-10-01 preflight demonstrated this distinction:

```text
Larry Boeldt
    Google Production Crew membership present
    ref.person exists
    ref.person.active_flag = false
    -> HOLD for operator review

Paul Hahn
    Google Production Crew membership present
    no exact ref.person record
    -> HOLD for operator review
```

The intended rule is therefore:

```text
Google Production Crew membership
    + existing active exact-email ref.person
    + no conflicting Directus identity
    -> eligible for Production Crew provisioning

inactive Person
    -> STOP / review

no Person
    -> STOP / review

identity conflict
    -> STOP / review
```

Do not create a Person merely because a Google/Directus identity exists.

## Adam Biebel No-First-Login Pilot — Proven 2026-10-01

Adam Biebel, Person 1, was used as the controlled pilot.

Initial Person state:

```text
person_id       1
name            Adam Biebel
email           abiebel@sheboyganlights.org
active_flag     true
directus_user_id = NULL
```

An Administrator manually created the Directus user before Adam authenticated to Directus with:

```text
first_name           Adam
last_name            Biebel
email                abiebel@sheboyganlights.org
provider             google
external_identifier  abiebel@sheboyganlights.org
status               active
role at create        NULL
```

Directus created:

```text
Directus UUID  2e2100a3-cb20-4c54-b3dd-bf9bd4673131
role           MSB Browser
```

This proves:

```text
a Directus UUID can exist before the user ever authenticates to Directus
```

First Directus login is therefore **not** technically required to establish the Directus identity.

### Existing Flow Did Not Complete Person Linkage

Immediately after Administrator-side Directus creation:

```text
Directus user exists
role = MSB Browser
ref.person person_id 1 still has directus_user_id = NULL
```

Therefore the existing Directus User Onboarding Flow must not be relied on to complete existing-Person reconciliation for Administrator pre-provisioning.

The Flow and Person reconciliation are separate lifecycle responsibilities.

### Governed Person Link Repair Passed

A bounded Production transaction then linked Adam's exact Directus UUID to existing Person 1.

The transaction:

- required the exact Person ID and exact email;
- required the Person to remain active;
- required the Person link to remain NULL;
- required the Directus Google email/external identifier to match exactly;
- required the Directus UUID to be unused by any other Person;
- preserved the existing Person update audit trigger; and
- required the current PostgreSQL operator to resolve to an active MSB Person.

Validation:

```text
person_id                  1
person.directus_user_id    2e2100a3-cb20-4c54-b3dd-bf9bd4673131
Directus UUID              2e2100a3-cb20-4c54-b3dd-bf9bd4673131
email                      abiebel@sheboyganlights.org
provider                   google
external_identifier        abiebel@sheboyganlights.org
status                     active
updated_by                 Greg
updated_by_person_id       17
```

### Production Crew Role Assignment Passed

Adam's Directus role was then changed to Production Crew.

Final validation:

```text
person_id                  1
person.directus_user_id    2e2100a3-cb20-4c54-b3dd-bf9bd4673131
Directus UUID              2e2100a3-cb20-4c54-b3dd-bf9bd4673131
provider                   google
external_identifier        abiebel@sheboyganlights.org
status                     active
role_id                    edd36182-2029-4bfa-b6ca-1fa9a9b771a9
role                       Production Crew
```

This proves the complete no-first-login provisioning sequence:

```text
existing active Person
+ existing Google Workspace account
    -> Administrator creates Google-backed Directus user
    -> Directus UUID exists before first Directus login
    -> governed exact-email Person reconciliation links UUID
    -> intended Production Crew role is assigned
    -> final identity and authorization state validates
```

## Existing Flow Limitation

The current Production Directus User Onboarding Flow listens only to `directus_users.items.create`.

Its current gate is:

```text
provider = google
AND
role IS NULL
```

The Flow assigns the default MSB Browser role and then attempts Person reconciliation.

Production evidence now establishes two separate failure modes:

1. previously established Directus users can remain exact-email/unlinked and later login does not retry reconciliation;
2. Administrator pre-provisioning can create the Directus UUID and assign MSB Browser while the existing Person remains unlinked.

The existing Flow is therefore not sufficient as the long-term People/Identity reconciliation authority.

## No-Match Branch Must Fail Closed

The current Flow can create a new Person when no exact Person is found.

The Mark Rozmarynowski onboarding mistake demonstrated why this is unsafe for the current People Manager model: an incorrect MSB email was supplied upstream and the Flow propagated that mistake into a durable Person record.

Once People Manager owns durable Person creation and MSB email reservation, the desired rule is:

```text
exact existing Person found
    -> reconcile safely

no exact Person found
    -> STOP / Administrator review

do not create Person automatically
do not guess by name
```

## Required People Manager Operator Workflow

Directus provisioning belongs on the existing Person detail page in People Manager because that is already the operator's durable Person management surface.

The current read-only `Protected system state` section should evolve into a clearer `System Access & Identity` section.

At minimum it should display:

```text
Sheboygan Lights email
Person active/inactive state

Directus identity
    Provisioned / Not provisioned
    Directus UUID
    Directus status
    Directus role

PostgreSQL login
    Linked / Not linked
```

For an active Person with a valid reserved MSB identity and no Directus identity, the Manager/Administrator workflow should expose a **separate access action**, not an automatic side effect of Person creation:

```text
Google Workspace account confirmed by operator    [ ]
Requested database access                         [ None / MSB Browser / Production Crew / Manager ]

[ Provision Directus access ]
```

Default database access is `None`.

The action remains unavailable until the operator explicitly confirms that the real Google Workspace account exists for the exact reserved MSB identity.

The provisioning action must perform the entire governed sequence without requiring the operator to leave People Manager.

Setup/Takedown participation, Production help, active Person state, capabilities, qualifications, or notification eligibility must not automatically select a Directus role.

## Required Provisioning Command Behavior

A People Manager provisioning command must:

1. resolve the authenticated Manager/Administrator as the human actor;
2. require the target Person to exist;
3. require the target Person to be active;
4. require a normalized `@sheboyganlights.org` identity;
5. require no conflicting Person `directus_user_id`;
6. require no existing conflicting Directus user/email/external identifier;
7. create the Google-backed Directus identity through the supported Directus API or service boundary, not by direct table insert;
8. capture the returned Directus UUID;
9. link that UUID to the exact existing Person through a governed database command;
10. assign the intended Directus role;
11. validate the final Directus and Person state;
12. preserve person-level audit attribution;
13. return one clear success or fail-closed result to the operator.

No partial-success state should be silently treated as complete.

If Directus creation succeeds but Person linkage or role assignment fails, the UI must report the incomplete state explicitly for Administrator recovery.

## Role Assignment Rule

Google Production Crew membership may support the intended role decision, but the People system must not silently downgrade existing elevated users.

Examples:

```text
existing Administrator -> remain Administrator
existing Manager       -> remain Manager
existing Production Crew -> no-op
unprovisioned eligible active Person -> may provision Production Crew
```

A future Google-group synchronization may automate the proposed role, but it must preserve explicit elevated authority unless a separate governed deprovision/demotion action is approved.

## Separation of Identity and Authorization

These remain distinct facts:

```text
ref.person
    durable real-person identity

Google Workspace
    actual MSB account / authentication provider

Directus user / UUID
    application identity

Directus role / policy
    application authorization

PostgreSQL login
    separate database identity where applicable
```

Creating/reserving an MSB email is not the same as creating a Google account.

Creating a Directus UUID is not the same as assigning Production Crew.

Assigning Production Crew is not the same as Manager/Administrator authority.

The People Manager UI may coordinate these workflows, but it must continue to represent the distinctions explicitly.

## Immediate Batch State — 2026-10-01

The approved human Production Crew preflight population was:

```text
Adam Biebel        abiebel@sheboyganlights.org
Fred Engelhardt    fengelhardt@sheboyganlights.org
John Muehlbauer    jmuehlbauer@sheboyganlights.org
Larry Boeldt       lboeldt@sheboyganlights.org
Mark Becherer      mbecherer@sheboyganlights.org
Paul Hahn          phahn@sheboyganlights.org
Ron Navis          rnavis@sheboyganlights.org
Steve Reiter       sreiter@sheboyganlights.org
Todd Gutschow      tgutschow@sheboyganlights.org
```

Preflight result:

```text
Adam Biebel        PROVISIONED / Production Crew pilot PASS
Fred Engelhardt    eligible
John Muehlbauer    eligible
Larry Boeldt       HOLD — Person inactive
Mark Becherer      eligible
Paul Hahn          HOLD — no Person; operator uncertain
Ron Navis          eligible
Steve Reiter       eligible
Todd Gutschow      eligible
```

Larry and Paul must not be included in an automated provisioning batch until their Person state is resolved by an operator.

## Acceptance Requirements

Before People Manager Directus provisioning is accepted, prove at least:

1. an active exact-email Person can be provisioned to Directus without first user login;
2. the returned UUID is linked to the same existing Person;
3. the selected Directus role is assigned;
4. final state is visible on the Person page;
5. inactive Person fails closed;
6. missing Person fails closed;
7. existing conflicting Directus email/UUID fails closed;
8. existing elevated Manager/Administrator is not silently downgraded;
9. no-match Directus identity does not auto-create a Person;
10. person-level audit attribution records the initiating Manager/Administrator;
11. a partial Directus-create / Person-link / role-assignment failure is surfaced and recoverable;
12. repeat provisioning is idempotent;
13. ordinary Person/contact editing still cannot directly edit protected `directus_user_id`;
14. Production Crew provisioning can be performed without shell, DBeaver, or direct Directus record manipulation by the operator.

## Current Boundary

The 2026-10-01 Adam pilot proves the lifecycle mechanics but does not itself authorize broad Production automation.

The next implementation belongs in People Manager and must use the existing least-privilege/governed-command pattern rather than placing an Administrator token in browser JavaScript or granting broad PostgreSQL DML.

No additional Production user provisioning should be treated as complete unless identity link, role assignment, and final validation all pass.
