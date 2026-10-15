# People and Identity — Engineering

This is the engineering starting point for Production Database work involving person identity, onboarding, contact data, authentication linkage, actor attribution, duplicate-safe person management, reusable capabilities, formal qualifications, Setup/Takedown eligibility, and the People Manager.

## Current Authority

- [`../README.md`](../README.md) — subsystem overview
- [`Directus_User_Onboarding_Identity_Contract_2026-09-09.md`](Directus_User_Onboarding_Identity_Contract_2026-09-09.md) — current Production Directus onboarding behavior and People identity lifecycle
- [`Directus_Person_Identity_Reconciliation_Contract_2026-10-13.md`](Directus_Person_Identity_Reconciliation_Contract_2026-10-13.md) — Issue #385 durable exact-email self-reconciliation contract for recurring Directus↔Person link failures
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
application SHA      bb8dfa498c5b4bbecfc3693f68c4066c1e08242e
version              V0.2.2
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

## Application / Authentication Host Boundary

The current end-user application surface is **`my.sheboyganlights.org`**. MSB moved normal operational UI/UX away from Directus because Directus Data Studio did not provide an acceptable task-oriented user experience for field and production workflows.

Current intent:

```text
my.sheboyganlights.org
    -> normal human application/navigation surface
    -> Cloudflare Access authentication at the intranet boundary
    -> standalone/task-focused MSB applications

db.sheboyganlights.org
    -> Directus runtime/authentication backend
    -> Directus role/policy authorization authority
    -> administrator/backend Directus access when needed
    -> NOT the normal user application experience
```

Normal users should not have to visit or understand the Directus login/Data Studio UI merely to initialize access to MSB applications. Issue #395 exists specifically to remove that remaining first-login dependency while retaining Directus as the authentication/authorization backend.

## Identity and Onboarding

`ref.person` remains the durable person identity. A person may exist without a Google Workspace account, Directus identity, PostgreSQL login, or active system access.

The historical Directus **User Onboarding** flow remains create-event-only and is separately documented. V0.2.2 no longer relies on that one-time event to repair every safe established identity.

Protected actor boundaries now use the shared exact-email reconciliation contract from Issue #385. Reconciliation is allowed only for an active Google-backed Directus user whose email and external identifier exactly match an active existing Person's real Sheboygan Lights email, with no UUID ownership conflict. It may create only the missing `ref.person.directus_user_id` relationship; it does not create a Person or change Directus authorization.

Shared tablet/device/service identities are explicitly non-human and are rejected from Person reconciliation.

## Current First-Login Gap and Human Access Administration — 2026-10-15

Live Production reconnaissance for Issue #395 proved that the Directus **User Onboarding** flow is an active event Flow on `directus_users.items.create`. It assigns role UUID `0ce54f42-8438-4eb6-8081-4303612c9da1`, currently **MSB Browser**, with policy **Read Only - MSB Core**, before attempting the Person lookup/link.

The flow therefore cannot run merely because a user successfully authenticates through Cloudflare Access to `my.sheboyganlights.org`. If the human has never caused a Directus Google identity to be created, protected applications that authorize through Directus see no active Directus user.

The confirmed Production example is Don Martens:

```text
ref.person.person_id       18
name                       Don Martens
email                      dmartens@sheboyganlights.org
active_flag                true
legacy is_manager          true
directus_user_id           NULL
matching Directus user     NONE
Setup capability row       NONE
```

Don successfully authenticated to the protected MSB intranet through Cloudflare Access but Setup returned **Setup read access is not authorized for this account** because no Directus identity existed yet.

This establishes the current engineering requirement:

```text
normal human first use
    -> Cloudflare authenticates the human
    -> MSB initializes the corresponding Directus Google identity without
       exposing the Directus admin/login UI
    -> new Directus identity starts as MSB Browser / least privilege
    -> exact existing Person is linked when safe
    -> protected application authorization continues from Directus role/policy
```

The current administrator workflow for role elevation remains valid and intentionally separate:

```text
new Directus human identity
    -> MSB Browser by default

administrator may later change the existing Directus user role
    -> Production Crew / Manager / Administrator as appropriate
```

Do **not** use legacy Person flags such as `ref.person.is_manager` or `is_team` as a substitute authorization source and do not automatically promote a new Directus user from those flags. Directus remains the runtime role/policy authority.

People Manager may later become a friendlier administration surface that writes governed Directus role changes, but that is not required for the #395 first-login fix. Administrators can continue changing roles in Directus for identities that already exist.

Non-human identities are a separate valid class. A shared tablet or service account may have a Directus identity while intentionally having **no** `ref.person` row. In particular, `tablet-*@sheboyganlights.org` must remain a non-human device identity, MSB Browser only, with no Person linkage and no human actor attribution.

Issue #395 owns replacement of the visible Directus first-login dependency. It must preserve the accepted #385 reconciliation contract and must not silently create a Person merely because an account authenticates.

## Preserved #395 Production Acceptance Fixture

Don Martens is currently the clean real-world first-login fixture for #395.

```text
browser/device               office / print-server PC, Google Chrome
human                        Don Martens
email                        dmartens@sheboyganlights.org
Cloudflare / my. login       completed successfully
db.sheboyganlights.org       never visited by Don
Directus Google first-login  never completed
matching Directus user       NONE
ref.person.person_id         18
Person directus_user_id      NULL
current browser state        original Setup authorization error remains open
test operator                 Greg / MSB administrator
browser-use permission        Don explicitly authorized Greg to use this Chrome session for #395 testing
```

This is an authorized operator test fixture; Don does not need to be physically present for each test step. Greg, acting as the MSB administrator, may use Don's existing Chrome session for the controlled #395 browser acceptance work Don authorized.

Preserve the missing-Directus-user state until the #395 candidate has passed disposable/pre-Production acceptance. Authorization to use the browser does not mean the fixture should be consumed early by visiting Directus or manually creating/linking Don's identity before the candidate is ready.

The intended final acceptance is for Greg to resume from Don's normal `my.sheboyganlights.org` workflow in that authorized Chrome session and prove that the accepted bootstrap creates/initializes the Directus identity without exposing Directus Data Studio/login, assigns only **MSB Browser** initially, safely links Person 18, and leaves later role elevation as a separate administrator action.

## Directus Google SSO Runtime — 2026-10-15

Live read-only runtime inspection confirmed Directus 11.17.1 is configured with a single Google OpenID provider and public registration enabled:

```text
AUTH_PROVIDERS=google
AUTH_GOOGLE_DRIVER=openid
AUTH_GOOGLE_SCOPE=openid email profile
AUTH_GOOGLE_ALLOW_PUBLIC_REGISTRATION=true
AUTH_GOOGLE_ISSUER_URL=https://accounts.google.com
PUBLIC_URL=https://db.sheboyganlights.org
```

This means a supported Google SSO login can create the missing Directus identity. The provider-specific login route can be used without presenting the Directus Data Studio login page first. #395 must still prove shared-tablet account consistency before adopting that as the normal invisible bootstrap path.

The current Production default-role behavior remains owned by the User Onboarding Flow: a newly created Google-backed Directus user with NULL role is assigned **MSB Browser** / **Read Only - MSB Core**. Role elevation remains an explicit administrator action.

## #395 Disposable Acceptance — 2026-10-15

The first complete V0.2.3 silent human identity bootstrap candidate passed governed current-Production disposable acceptance.

```text
candidate             dcc8f25f07a74e19ce3de3aae2d9d137b5411815
result                PASS
production mutation   NONE
server report         /tmp/MSB_People_Identity_Bootstrap_Disposable_20261015T200047.txt
```

Production identity fingerprints were unchanged:

```text
ref.person       4157a1c63a88bc900d566f6eb094f1c4
directus_users   3170a3a5b5860bed1c293f2ee6b50131
```

The disposable gate exercised the real Directus 11.17.1 Users API against a disposable current-Production clone, proved new human identities stay at **MSB Browser**, proved existing roles remain unchanged, proved missing/inactive Person failure, proved non-human tablet/service exclusion, proved exact #385 Person linkage, and proved the legacy User Onboarding missing-Person branch is bypassed when the candidate supplies the non-null Browser role at user creation.

Durable evidence:

```text
People/Acceptance/People_Identity_Bootstrap_Disposable_Acceptance_2026-10-15.md
```

This is not Production deployment approval. The next gate is exact-candidate browser/application integration review through the `my.` Apps workflow and Backbone #24. Don Martens remains the preserved final Production acceptance fixture.

## #395 Browser-Review Tooling Correction — 2026-10-15

After the V0.2.3 runtime passed disposable acceptance, the first draft of browser-review tooling was rejected before execution because it used historical People preview port `8795` instead of the established reusable Production Database disposable-browser workflow.

The current controlled path is:

```text
Setup/Acceptance/run_setup_disposable_browser_preview.ps1
    -> PreviewProfile PeopleIdentityBootstrap
    -> explicit PreviewPort 8898
    -> exact accepted People runtime dcc8f25f...
    -> exact Backbone Apps candidate SHA/blob
    -> disposable PostgreSQL + disposable Directus 11.17.1
    -> clone-only synthetic human
    -> operator browser review
```

Server Management PR #76 made the current #395 allocation durable: `8898` is the reusable review port; `8795` is historical People preview evidence only.

No Production identity or application service is changed by this review, and Don Martens remains the untouched final Production first-login fixture.

### #395 Reusable preview engineering/test checkpoint

The reusable `PeopleIdentityBootstrap` profile is now implemented on the existing Setup acceptance launcher. `dcc8f25f...` remains the **only disposable-accepted People runtime**; later changes are tooling/documentation. On Greg's Windows desktop at tooling SHA `01606de3...`, the profile contract tests returned **11 passed** and the complete `Setup/Application` suite returned **769 passed, 5 skipped**.

The first attempt at local `bash -n` **did not execute** because `bash` was not on the PowerShell PATH. The preview server script's separate `py_compile` write-permission problem was corrected by in-memory syntax compilation under the `fieldwiring` account in tooling commit `2859e643...`. Bash syntax validation, PowerShell parser validation, and integrated operator browser review at registered port 8898 remain **pending**. Do not run the discarded People-specific wrapper or consume Don's browser fixture.

**Durable detailed evidence, authoritative source pins, governing Server Management disposable/browser runbooks, and next commands/gates:** [#395 People Identity Bootstrap acceptance and reusable-preview checkpoint](../../../../../People/Acceptance/People_Identity_Bootstrap_Disposable_Acceptance_2026-10-15.md). This engineering README is the navigation/handoff, not a competing runbook.

## Accepted People Manager Behavior

The accepted contact/identity behavior includes:

- standalone Flask People Manager application;
- separate `people_app` least-privilege login/command contract;
- Cloudflare-authenticated browser identity plus current Directus Manager/Administrator authorization;
- database-governed search and person detail;
- manual volunteer/contact create without fabricating a Sheboygan Lights identity;
- `ref.person.email` stores only a real Sheboygan Lights Workspace account when one exists;
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

People Manager maintenance is limited to current **Manager / Administrator** or equivalent accepted `admin_access` authority. Human writes also require a durable Person actor. V0.2.2 can repair a missing exact safe Person↔Directus UUID link after authorization succeeds; reconciliation never grants Production Crew, Manager, Administrator, or any other role.

## Acceptance State

### Identity reconciliation — 2026-10-13

```text
People version          V0.2.2
accepted runtime        2c9a2937079f817dafd5119584aaffc77b51357d
merged/deployed main    bb8dfa498c5b4bbecfc3693f68c4066c1e08242e
migration 005 blob      88442b8f4150513fd6af581e2ea90004c6f27658
Production deployment   PASS
```

Disposable current-Production acceptance proved exact safe self-reconciliation, audit attribution, idempotence, role preservation, fail-closed conflict handling, and non-human device/service exclusion. Governed Production deployment completed under the Server Management Issue #37 maintenance controller.

Durable evidence:

`People/Acceptance/People_Identity_Reconciliation_Production_Acceptance_2026-10-13.md`

### Original People Manager — 2026-09-09

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
    -> ref.person.email stays NULL until a real Sheboygan Lights account exists
    -> Google Workspace account may be created later
    -> Directus authorization remains authoritative
    -> exact safe Person↔Directus UUID link self-reconciles on protected use when needed
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
