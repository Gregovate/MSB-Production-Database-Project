# People / Identity Bootstrap — Disposable Acceptance — 2026-10-15

| Document Control | Value |
|---|---|
| Issue | #395 |
| Candidate | `dcc8f25f07a74e19ce3de3aae2d9d137b5411815` |
| Result | **PASS** |
| Production mutation | **NONE** |
| Production database access | `pg_dump + SELECT` only |
| Disposable Directus image | `directus/directus:11.17.1` |
| Server report | `/tmp/MSB_People_Identity_Bootstrap_Disposable_20261015T200047.txt` |

## Governing Authority

```text
Gregovate/MSB-Server-Management
docs/server/PostgreSQL_Disposable_Acceptance_Standard.md
```

The acceptance runner used a current Production PostgreSQL clone and a separate disposable Directus 11.17.1 container. The live People service, live Directus container, Production identities, and Don Martens' preserved browser fixture were not mutated.

## Candidate Under Test

```text
dcc8f25f07a74e19ce3de3aae2d9d137b5411815
```

The candidate implements the #395 silent human identity bootstrap:

```text
Cloudflare-authenticated my. human
    -> exact active existing Person preflight
    -> existing Directus identity:
         preserve role
         reconcile safe missing Person UUID link if needed
    -> missing Directus identity:
         create through supported Directus Users API
         provider = google
         external_identifier = exact normalized MSB email
         status = active
         role = MSB Browser
    -> accepted #385 exact-email reconciliation
    -> existing Person becomes durably linked
```

New identity creation assigns the non-null **MSB Browser** role at creation. The live legacy Directus User Onboarding Flow still requires `provider=google AND role IS NULL`, so this candidate does not enter that Flow's later missing-Person auto-create branch.

## Acceptance Coverage

The governed wrapper reached its final PASS / exit status 0 after exercising the exact candidate against the disposable current-Production environment.

The acceptance contract includes:

- exact candidate Python/contract regression;
- current live User Onboarding create-event / role-null gate verification;
- current Production clone restore;
- People migrations through candidate migration 006 on the clone;
- People application least-privilege boundary;
- active existing Person + no Directus user -> real Directus Users API creation;
- new identity remains **MSB Browser**;
- exact safe Person linkage through the #385 reconciliation contract;
- repeat bootstrap idempotence;
- existing Manager/Administrator role preservation;
- existing Production Crew role preservation;
- safe existing Directus + NULL Person-link reconciliation;
- missing Person fails before Directus user creation;
- inactive Person fails before Directus user creation;
- shared tablet/device identity remains non-human and does not become a Person;
- a Directus user created with a non-null Browser role does not cause the legacy User Onboarding Flow to auto-create a Person;
- disposable Directus fatal/load-error scan; and
- cleanup of disposable PostgreSQL, Directus, and detached candidate resources.

## Production Invariants

Final operator evidence:

```text
Person before: 4157a1c63a88bc900d566f6eb094f1c4
Person after:  4157a1c63a88bc900d566f6eb094f1c4
PASS: Production ref.person fingerprint unchanged

Directus before: 3170a3a5b5860bed1c293f2ee6b50131
Directus after:  3170a3a5b5860bed1c293f2ee6b50131
PASS: Production directus_users fingerprint unchanged

Exit status: 0
```

## Browser Review Tooling Correction — 2026-10-15

The first post-disposable browser-preview tooling drafted for #395 was **not executed** and was rejected because it used the historical People preview port `8795` and bypassed the established reusable disposable-browser workflow.

Current authority was re-read from:

```text
Gregovate/MSB-Server-Management
docs/server/Pre_Production_Browser_Review_Runbook.md
docs/server/Application_and_Test_Port_Register.md

Gregovate/MSB-Production-Database-Project
Setup/Acceptance/README.md
Setup/Acceptance/run_setup_disposable_browser_preview.ps1
```

The correction preserves the disposable-accepted People runtime at:

```text
dcc8f25f07a74e19ce3de3aae2d9d137b5411815
```

No `People/Application` or `People/Database` runtime file changed after that accepted SHA.

The existing reusable browser-preview launcher is being extended with a `PeopleIdentityBootstrap` profile rather than adding another independent workstation wrapper. The profile uses the same established foreground SSH/reconnect lifecycle and the registered stable review URL:

```text
http://127.0.0.1:8898/
```

The exact Backbone Apps candidate remains independently pinned:

```text
Gregovate/MSB-Internal-Web-Backbone PR #25
Apps SHA   1d7fa310dd5274078910e3a098ddfd633ae58836
Apps blob  9d340e5e944a7cd1db223b539066eb14ddb1c292
```

The profile uses a clone-only synthetic human identity, a disposable current-Production PostgreSQL clone, and disposable Directus 11.17.1. It must not consume Don Martens' real Production fixture during pre-Production browser review.

## Disposition

```text
DISPOSABLE ACCEPTANCE: PASS
PRODUCTION DEPLOYMENT: NOT AUTHORIZED BY THIS EVIDENCE
DON MARTENS FIXTURE: PRESERVED / UNCONSUMED
NEXT: exact-candidate browser/application integration review
```

The next gate is to validate the user-facing `my.sheboyganlights.org/apps/` integration against the exact accepted source candidate before any Production mutation.
