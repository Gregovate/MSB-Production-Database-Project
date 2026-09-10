# People and Identity — Engineering

This is the engineering starting point for Production Database work involving person identity, onboarding, contact data, authentication linkage, actor attribution, duplicate-safe person management, reusable capabilities, formal qualifications, Setup/Takedown eligibility, and the People Manager.

## Current Authority

- [`../README.md`](../README.md) — subsystem overview
- [`Directus_User_Onboarding_Identity_Contract_2026-09-09.md`](Directus_User_Onboarding_Identity_Contract_2026-09-09.md) — current Production Directus onboarding behavior and People identity lifecycle
- [`People_Manager_Directus_Person_Link_Acceptance_Gap_2026-09-10.md`](People_Manager_Directus_Person_Link_Acceptance_Gap_2026-09-10.md) — **required before changing Directus/Person identity linkage**; records the missed People Manager acceptance requirement, affected Production identity state, and Randy Miller repeat-login proof
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
PGPASSFILE            /var/lib/fieldwiring/.pgpass
public route         https://my.sheboyganlights.org/people/
```

The backend listener is exposed only from Synology `192.168.5.4` through the source-limited UFW rule for `8796/tcp`.

### Current identity-link limitation — 2026-09-10

The 2026-09-09 People Manager Production acceptance did **not** prove the Directus onboarding identity-link lifecycle end to end even though the onboarding contract required that proof before Production acceptance.

A 2026-09-10 read-only Production audit found active Setup Managers whose exact-email `ref.person` rows exist but whose `directus_user_id` remains NULL. Randy Miller then explicitly authenticated again through Google at `db.sheboyganlights.org`; the mapping remained NULL.

The documented Directus User Onboarding Flow is gated to Google users whose Directus `role IS NULL`. It is therefore a first-onboarding path, not a general reconciliation mechanism for already-established Directus users.

Do not treat repeat login, additional Setup table permissions, or Manager policy changes as a repair for this identity-link condition. Read [`People_Manager_Directus_Person_Link_Acceptance_Gap_2026-09-10.md`](People_Manager_Directus_Person_Link_Acceptance_Gap_2026-09-10.md) before changing this boundary.

## Identity and Onboarding

`ref.person` remains the durable person identity. A person may exist without a Google Workspace account, Directus identity, PostgreSQL login, or active system access.

The Production Directus **User Onboarding** flow matches an existing `ref.person` by `email`, provided `directus_user_id` is null or already equals the triggering Directus user ID. If no matching person is found, it creates a new person from the Directus user's first name, last name, email, and Directus ID.

The Person-link branch is reached only through the currently observed Google-user onboarding condition that also requires the Directus user's role to still be null. Therefore the flow must not be described as a general login-time reconciliation mechanism for all existing Directus accounts.

A manually added volunteer can reserve the intended Sheboygan Lights email on the existing person before later first Google/Directus login when preserving the same `person_id` matters.

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

## Acceptance State — 2026-09-09, corrected 2026-09-10

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

The disposable harness proved People Manager database/API behavior using an already-mapped Manager actor. It did **not** execute or simulate the Directus User Onboarding Flow and therefore did not satisfy the written requirement to prove existing-person -> first-Directus-login -> same-person identity linkage.

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

These proven deployment/application results remain valid. However, the historical `PEOPLE MANAGER PRODUCTION ACCEPTANCE: PASS` must **not** be interpreted as proof that the Directus onboarding identity-link acceptance requirement was exercised. The 2026-09-10 acceptance correction linked above is the current authority for that gap.

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
    -> first Directus onboarding can link the same person_id by exact MSB email when the current Flow's onboarding gate is satisfied
```

If a person stops participating, retain the durable identity and set `active_flag=false`; reactivate that same person if they return.

## Current Closeout Sequence

```text
People Manager application/runtime       DEPLOYED / PROVEN
browser operator acceptance              PASS for reviewed UI
Production deployment                    PASS for deployed artifacts
Directus-Person identity-link coverage   ACCEPTANCE GAP — correction required
Production intranet/index                separate Backbone work
```

Do not treat the People/Identity subsystem as fully closed while authorized human accounts required by governed MSB applications remain unmapped.

## Separate Future Work

- authoritative capability/qualification seed evidence and canonical `person_id` resolution;
- `ref.setup_task_capability` as a Setup-consumer relationship;
- governed person merge/reconciliation;
- Google Workspace provisioning automation/integration beyond the reserved identity contract; and
- any future role/policy administration UI.

The Directus/Person linkage correction is **current corrective work**, not an optional future enhancement.

## Resume Development

Before changing People behavior:

1. read the onboarding contract, the 2026-09-10 Directus-Person acceptance-gap correction, metadata implementation, accepted disposable/browser/Production evidence, and current operator procedure;
2. inspect current Production schema/runtime and run a read-only Directus↔Person identity audit rather than relying on historical acceptance alone;
3. preserve Google Workspace provisioning authority and Directus authorization authority;
4. preserve exact-email identity matching, least privilege, and duplicate-safe identity behavior;
5. do not repair missing identity linkage by granting broad application table DML or by guessing identity from names;
6. preserve the GA4 privacy boundary; and
7. use Server Management runbooks for runtime/Production work rather than feature-local reconstruction.
