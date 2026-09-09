# People and Identity — Engineering

This is the engineering starting point for Production Database work involving person identity, onboarding, contact data, authentication linkage, actor attribution, duplicate-safe person management, reusable capabilities, formal qualifications, Setup/Takedown eligibility, and the People Manager.

## Current Authority

- [`../README.md`](../README.md) — subsystem overview
- [`Directus_User_Onboarding_Identity_Contract_2026-09-09.md`](Directus_User_Onboarding_Identity_Contract_2026-09-09.md) — current Production Directus onboarding behavior and People identity lifecycle
- [`People_Manager_Metadata_Implementation_2026-09-09.md`](People_Manager_Metadata_Implementation_2026-09-09.md) — capability/qualification/Setup-role implementation
- [`Internal_Web_Backbone_Handoff.md`](Internal_Web_Backbone_Handoff.md) — source-owned Production intranet integration handoff
- [`../../../../../People/README.md`](../../../../../People/README.md) — current People Manager implementation/runtime summary
- [`../../../../../People/Acceptance/README.md`](../../../../../People/Acceptance/README.md) — People acceptance portal
- [`../../../02_Operational_SOPs/People/README.md`](../../../02_Operational_SOPs/People/README.md) — plain-English operator procedures
- GitHub issue #130 — People / Capability / Qualification catalog and duplicate-safe person management

Server/runtime mechanics are governed by `Gregovate/MSB-Server-Management`, including the Production Database change, protected Flask service, Synology reverse-proxy, and interactive SSH safety runbooks.

## Current Production State

People Manager is live at:

```text
https://my.sheboyganlights.org/people/
```

Accepted Production runtime:

```text
application SHA      54e1192309b96c9838676be51a0bfcdb3ac92e06
version              V0.2.0
service              msb-people.service
runtime account      fieldwiring
working directory    /opt/fieldwiring/People/Application
listener             192.168.5.9:8796
environment          /etc/msb-people/people.env
PostgreSQL role      people_app
PGPASSFILE           /var/lib/fieldwiring/.pgpass
public route         https://my.sheboyganlights.org/people/
```

The backend listener is exposed only from Synology `192.168.5.4` through the source-limited UFW rule for `8796/tcp`.

## Identity and Onboarding

`ref.person` remains the durable person identity. A person may exist without a Google Workspace account, Directus identity, PostgreSQL login, or active system access.

The Production Directus **User Onboarding** flow matches an existing `ref.person` by `email`, provided `directus_user_id` is null or already equals the triggering Directus user ID. If no matching person is found, it creates a new person from the Directus user's first name, last name, email, and Directus ID.

A manually added volunteer can therefore reserve the intended Sheboygan Lights email on the existing person before later first Google/Directus login when preserving the same `person_id` matters.

## Accepted People Manager Behavior

The accepted contact/identity behavior includes:

- standalone Flask People Manager application;
- separate `people_app` least-privilege login/command contract;
- Cloudflare-authenticated browser identity plus current Directus Manager/Administrator authorization;
- database-governed search and person detail;
- manual volunteer/contact create with standard `first initial + last name @sheboyganlights.org` reservation;
- collision review favoring additional first-name characters rather than silent numbering;
- duplicate review using normalized name, MSB email, personal email, and phone evidence;
- contact edit and active/inactive lifecycle;
- optimistic concurrency through exact `updated_at` round-trip serialization;
- Directus-linked MSB email protected from ordinary edit;
- protected system state visible but not ordinary writable input;
- dynamic current foreign-key relationship counts;
- no normal person DELETE or merge route; and
- required GA4 integration with a privacy-safe aggregate event boundary.

The metadata model adds:

```text
ref.person_capability_type
ref.person_capability
ref.person_qualification_type
ref.person_qualification
ref.person_setup_role
```

and exposes:

- controlled reusable capability catalog and person capability relationships;
- formal dated qualifications with validity/expiration, certificate/evidence, active state, and notes;
- `SETUP_VOLUNTEER`, `TAKEDOWN_VOLUNTEER`, `CAPTAIN_CANDIDATE`, and `ADVISOR_CANDIDATE` relationships; and
- read-only person-centric visibility of existing `ref.setup_task_captain` Captain/Alternate/Advisor assignments.

Capabilities, qualifications, Setup eligibility, and actual Captain assignments remain distinct facts. People Manager does not infer Captain assignments.

## Authorization Boundary

Cloudflare Access authenticates the user. Current Directus role/policy state authorizes the People application.

People Manager maintenance is limited to current **Manager / Administrator** or equivalent accepted `admin_access` authority. Human writes also require the authenticated Directus user to map to a durable `ref.person` actor.

## Acceptance State — 2026-09-09

### Disposable acceptance

```text
accepted database/backend candidate
deaa9157282e59e8acd6a7da2a82fc9296e44f20
```

Production `ref.person` fingerprint remained:

```text
47f494107952a84f30a406374b8d01d7
```

Durable evidence:

`People/Acceptance/People_Manager_Metadata_Disposable_Acceptance_Evidence_2026-09-09.md`

### Browser review

```text
final browser presentation candidate
4724185fe8cd8831a59c61ea40df61073abbb0c6

ACCEPTED FOR PRODUCTION DEPLOYMENT GATE
```

Durable evidence:

`People/Acceptance/People_Manager_Browser_Review_Acceptance_2026-09-09.md`

### Production acceptance

Production deployment passed with:

```text
274 detached Production-runtime tests passed
migrations 001-003 applied
people_app least privilege PASS
no metadata seed rows
ref.person fingerprint unchanged
msb-people.service active/enabled V0.2.0
missing identity -> HTTP 401
Manager identity -> authorized
UFW 8796/tcp from Synology only
/people/ route PASS
FieldWiring / Procedures / Setup regressions PASS
Cloudflare-authenticated browser PASS
GA4 Production page view PASS
```

Durable evidence:

`People/Acceptance/People_Manager_Production_Acceptance_2026-09-09.md`

## Google Analytics Contract

People Manager uses:

```text
Measurement ID      G-X08ZTSY0VV
analytics version   2026-09-09.1
```

The operator verified `MSB People Manager` in the live MSB Internal Intranet GA4 property. The analytics implementation prohibits names, emails, phones, `person_id`, authenticated identity, search terms, PostgreSQL login values, and other Production record identifiers; Google Signals and advertising personalization remain disabled.

## Synology Runtime Finding

DSM administrative SSH is established as:

```text
ssh msbad@192.168.5.4 -p 22222
```

Modern Windows OpenSSH `scp` required legacy protocol (`-O`) because the DSM administrative SSH service rejected the SFTP subsystem. More importantly, a nested workstation SSH deployment stalled at interactive `sudo -v`.

The accepted `/people/` nginx change was therefore completed from the normal interactive PowerShell SSH session using a bounded subshell gate. Future Synology nginx changes requiring interactive sudo should use that established interactive workflow rather than a nested sudo-requiring SSH runner.

## Person Lifecycle

```text
volunteer/contact
    -> ref.person created or existing person found
    -> personal contact data maintained
    -> reserved @sheboyganlights.org identity stored when appropriate
    -> Google Workspace account may be created later
    -> first Directus login can link the same person_id by exact MSB email
```

If a person stops participating, retain the durable identity and set `active_flag=false`; reactivate that same person if they return.

## Current Closeout Sequence

```text
disposable acceptance                PASS
browser operator acceptance          PASS
Production deployment                PASS
live browser + GA4                    PASS
Production intranet/index            NEXT — Backbone #16
return handoff                        AFTER Backbone verification
```

## Separate Future Work

- authoritative capability/qualification seed evidence and canonical `person_id` resolution;
- `ref.setup_task_capability` as a Setup-consumer relationship;
- governed person merge/reconciliation;
- Google Workspace provisioning automation/integration beyond the reserved identity contract; and
- any future role/policy administration UI.

These do not block the current Production People Manager.

## Resume Development

Before changing People behavior:

1. read the onboarding contract, metadata implementation, accepted disposable/browser/Production evidence, and current operator procedure;
2. inspect current Production schema/runtime rather than relying on historical acceptance alone;
3. preserve Google Workspace provisioning authority and Directus authorization authority;
4. preserve least privilege and duplicate-safe identity behavior;
5. preserve the GA4 privacy boundary; and
6. use Server Management runbooks for runtime/Production work rather than feature-local reconstruction.
