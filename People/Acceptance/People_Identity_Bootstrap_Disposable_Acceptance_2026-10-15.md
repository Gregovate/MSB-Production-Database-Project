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

The existing reusable browser-preview launcher has been extended with a `PeopleIdentityBootstrap` profile rather than adding another independent workstation wrapper. The profile uses the same established foreground SSH/reconnect lifecycle and the registered stable review URL:

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

## Reusable 8898 Profile — Engineering Regression Checkpoint — 2026-10-15

The **two** governing acceptance/runtime procedures have separate responsibilities:

1. `Gregovate/MSB-Server-Management/docs/server/PostgreSQL_Disposable_Acceptance_Standard.md` governs the current-Production clone, isolation and disposable acceptance.
2. `Gregovate/MSB-Server-Management/docs/server/Pre_Production_Browser_Review_Runbook.md` governs the exact-candidate browser/application review, temporary listener, reconnect, and teardown.

The companion `docs/server/Application_and_Test_Port_Register.md` assigns sequential reusable Production Database browser review to **8898**. The Production Database repository's `Setup/Acceptance/README.md` and `Setup/Acceptance/run_setup_disposable_browser_preview.ps1` own the application-side reusable launcher contract. None of these are Production deployment authorization.

### Accepted runtime versus acceptance-tooling HEAD

```text
Accepted People/Application + People/Database runtime   dcc8f25f07a74e19ce3de3aae2d9d137b5411815
Reusable 8898 profile initially staged               b04262c5a3bb11d910c536d5f937964eee37c8e6
Read-only preview entry preflight correction           2859e6434442a43f63733b66d862aa37017b4481
Workstation regression contract correction             01606de3c00f668b3e065ccfc38efaf64aa11b36
Greg's verified local checkout and tests               01606de3c00f668b3e065ccfc38efaf64aa11b36
```

The first #395 feature-specific browser-preview wrapper was removed; it was never authorized or run. Changes above the accepted runtime remain acceptance tooling/documentation only. Do not reinterpret newer tooling SHA as a new accepted People runtime.

### Preflight issue and correction

The new server runner attempted `sudo -u fieldwiring ... python -m py_compile` on the uploaded entry file. The uploaded bundle is made traversable/readable (`755` directory; `644` entry) but not writable by `fieldwiring`; `py_compile` can try to create `__pycache__` beside the entry and fail before the review starts. Tooling commit `2859e643...` replaces this with Python `compile(source.read_bytes(), str(source), "exec")` in memory under the same service account. Commit `01606de3...` adds the static regression to protect the read-only bundle contract. No Production runtime mutation was made.

### Greg's Windows desktop PowerShell evidence

Greg ran these checks in his existing `C:\Users\Greg\Github\MSB-Production-Database-Project` checkout at `01606de3...`:

```text
python -m pytest -q -p no:cacheprovider Setup/Application/test_setup_reusable_people_identity_preview_profile_contract.py
    11 passed in 0.15s

python -m pytest -q -p no:cacheprovider Setup/Application
    769 passed, 5 skipped in 9.46s

bash -n Setup/Acceptance/people_identity_bootstrap_disposable_browser_preview_server.sh
    NOT RUN: PowerShell CommandNotFoundException, bash command not on PATH
```

The original `bash` command-not-found result was a Windows command-resolution failure, **not a failed syntax test**. Greg subsequently used the documented repository checkout to resolve Git for Windows Bash relative to the installed `git.exe` and completed both syntax checks on tooling/documentation HEAD `514b0ca42a392cafc54ace6103f61cd2d876d9bf`:

```text
PowerShell Parser.ParseFile(
  Setup/Acceptance/run_setup_disposable_browser_preview.ps1
)
  PASS: PowerShell launcher syntax (0 parse errors)

Git for Windows bash.exe -n
  Setup/Acceptance/people_identity_bootstrap_disposable_browser_preview_server.sh
  PASS: Bash preview server syntax (exit 0)
```

These are syntax-only checks: neither launcher nor server script was executed; no server/Production contact was made by these checks. Existing pytest evidence remains **11 passed** for the profile contract and **769 passed, 5 skipped** for full `Setup/Application` at `01606de3...`; newer commits through this checkpoint only update documentation.

### Exact stop point and next gate

```text
#395 disposable runtime acceptance   PASS (dcc8f25...; separate controlled report above)
Reusable-profile pytest               PASS (11/11)
Complete Setup/Application pytest     PASS (769 passed, 5 skipped)
Bash server syntax                    PASS (Git for Windows Bash, -n)
PowerShell launcher parser            PASS (ParseFile, 0 errors)
Real reusable 8898 browser review    NOT STARTED
Don real Production fixture          UNCONSUMED
Production deployment                NOT AUTHORIZED
```

**Next controlled action:** use the existing `Setup/Acceptance/run_setup_disposable_browser_preview.ps1` with `-PreviewProfile PeopleIdentityBootstrap`, explicit port `8898`, accepted People runtime `dcc8f25f07a74e19ce3de3aae2d9d137b5411815`, accepted `V0.2.3`, feature branch `issue-395-silent-human-identity-bootstrap`, and pinned Backbone Apps source/blob above. The launcher itself enforces a clean matching branch, candidate ancestry/version, selected-port ownership, disposable clone, and foreground reconnect workflow. Open `http://127.0.0.1:8898/` **only after** the runner prints BROWSER REVIEW READY.

Follow both governing Server Management acceptance/browser runbooks and the companion port register. Do not run the rejected People-specific wrapper, create a competing runbook, or use Don's real Production fixture for pre-Production review.

## Disposition

```text
DISPOSABLE ACCEPTANCE: PASS
PRODUCTION DEPLOYMENT: NOT AUTHORIZED BY THIS EVIDENCE
DON MARTENS FIXTURE: PRESERVED / UNCONSUMED
NEXT: exact-candidate browser/application integration review
```

The next gate is to validate the user-facing `my.sheboyganlights.org/apps/` integration against the exact accepted source candidate before any Production mutation.
