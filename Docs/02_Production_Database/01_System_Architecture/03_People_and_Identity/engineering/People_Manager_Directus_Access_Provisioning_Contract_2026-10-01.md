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

### 2. Sheboygan Lights email should represent a real Google Workspace account

People Manager currently generates/reserves an `@sheboyganlights.org` value when a Person is added, but the operator clarified that this behavior is undesirable.

The target contract is:

```text
no real Google Workspace account
    -> ref.person.email = NULL
    -> use personal_email for contact

real Sheboygan Lights Google Workspace account exists
    -> ref.person.email = actual Google account
    -> use it as the primary organization/contact email
```

There is currently no automatic People Manager -> Google Workspace provisioning link.

Creating a Person must not imply that a Google account exists or should exist.

### 3. Communication/contact is independent from system access

The People system is the uniform contact list for operational communication such as notifications and schedules.

A volunteer does not need a Google Workspace or Directus account to remain a valid communication recipient.

The intended primary-email rule is:

```text
actual Sheboygan Lights Google account exists
    -> ref.person.email is primary

otherwise
    -> personal_email is primary
```

This rule is intentionally independent of Directus/database authorization.

Historical generated/reserved MSB emails must be audited before automated notification consumers rely on non-null `ref.person.email` as proof of deliverability.

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

### 5. Google Workspace enables baseline Browser access; elevated roles remain explicit

Database applications use Google authentication through Directus.

Any real Sheboygan Lights Google Workspace user may receive the baseline `MSB Browser` Directus role, which is intended to provide read-only application access.

A Google Workspace account does **not** imply Production Crew, Manager, or Administrator authorization.

There are Sheboygan Lights Google users who are not Production Crew. Those users may remain `MSB Browser` and must not be elevated merely because their Google account exists.

### 6. Directus role controls database-application authorization

Directus identity/role is the database-application authorization layer.

The intended role ladder is:

```text
Google Workspace user
    -> MSB Browser (read-only baseline)

explicit Production Crew access
    -> Production Crew

explicit management authority
    -> Manager / Administrator
```

Creating a new Person must **not automatically provision Directus**, because many People records are contact-only volunteers without Google Workspace accounts.

When a real Google account exists, baseline Browser access may be established through the Google/Directus bootstrap path. People Manager is still responsible for showing the resulting identity/role state and for governed elevation such as Production Crew.

## Clarification — Google Users, Browser Role, and Contact Email Semantics — 2026-10-01

The operator clarified two important rules that supersede the earlier assumption that every Person should receive a reserved/fictitious Sheboygan Lights email at creation time.

### Any real Google Workspace user may receive the read-only Browser role

The `MSB Browser` Directus role exists as the baseline read-only database-application role.

The intended access model is:

```text
real Sheboygan Lights Google Workspace account
    -> eligible to authenticate with Google
    -> default Directus role may be MSB Browser (read-only)

Production Crew role
    -> explicit elevation above Browser
    -> not inferred merely from having a Google account

Manager / Administrator
    -> separately governed elevated roles
```

Therefore a Google Workspace user who is not part of Production Crew may still legitimately have read-only database access through `MSB Browser`.

### New Person creation must not invent a Sheboygan Lights/Google email

People Manager should return to the simpler contact rule:

```text
new Person with no real Google Workspace account
    -> store personal_email / phone
    -> ref.person.email remains NULL
    -> no Directus identity
    -> no database access

person later receives a real Sheboygan Lights Google Workspace account
    -> set ref.person.email to that actual Google account
    -> this becomes the preferred organization email
    -> Google authentication / Directus provisioning may then use the exact address
```

Do not automatically generate a fictitious `@sheboyganlights.org` value merely to reserve a future identity.

The current automatic **Build email** behavior on new Person creation is therefore a corrective target.

### Primary email selection

Once existing data is reconciled so `ref.person.email` represents an actual Sheboygan Lights Google account rather than a reservation, communication consumers should use:

```text
if real ref.person.email exists
    -> use Sheboygan Lights email as primary

else
    -> use personal_email
```

This restores the simple operator meaning the user preferred: organization account when one actually exists; otherwise personal email.

Until the existing population is audited, consumers must not assume every current non-null `ref.person.email` is deliverable because historical People Manager behavior may have generated reserved addresses that were never created in Google Workspace.

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

## Role-Governance Correction — 2026-10-01

The People Manager must **not** expose a free-form Directus role selector to ordinary Managers.

The operator clarified that a Manager must not be able to:

- choose an arbitrary Directus role while provisioning a user;
- elevate a Browser user to Production Crew by personal judgment;
- switch a Production Crew user to Manager or Administrator;
- downgrade an existing Manager or Administrator; or
- otherwise use People Manager as a generic Directus role editor.

The access model is therefore:

```text
real Sheboygan Lights Google Workspace account
    -> baseline Directus role may be MSB Browser
    -> role is selected by system rule, not by Manager choice

Production Crew
    -> elevated database role
    -> must come from a separate authoritative eligibility/approval source
    -> exact authority still to be finalized after current identity cleanup

Manager / Administrator
    -> privileged administrative roles
    -> never assignable or switchable by ordinary People Manager workflow
```

For Managers, Directus role/state is **read-only visibility**.

A Manager-facing provisioning action, if retained, may only request/trigger the single role allowed by a deterministic rule. The backend must compute the resulting role and reject any caller-supplied role value.

Privileged role assignment remains outside ordinary People Manager contact maintenance.

### Current sequencing decision

Do not finalize the Production Crew provisioning authority until the existing `ref.person.email` population has been reconciled against the real Google Workspace population.

First:

```text
remove generated/bogus Sheboygan Lights emails
    -> establish which People actually have Google Workspace accounts
    -> reconcile existing Directus identity/link state
    -> then define the authoritative Production Crew elevation rule
```

This cleanup is intentionally separate from changing Directus authorization.

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

For an active Person with a real Sheboygan Lights Google Workspace identity and no Directus identity, the Manager-facing workflow must not expose a role selector.

The intended shape is:

```text
Google Workspace identity
    actual-user@sheboyganlights.org

Directus identity
    Not provisioned

Computed baseline access
    MSB Browser — read only

[ Provision Browser access ]
```

The backend, not the Manager, determines the baseline role.

Production Crew elevation is a separate governed decision whose authoritative source is still to be finalized after current email/identity cleanup.

Manager and Administrator role assignment are not People Manager operations.

Setup/Takedown participation, Production help, active Person state, capabilities, qualifications, or notification eligibility must not automatically select an elevated Directus role.

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
