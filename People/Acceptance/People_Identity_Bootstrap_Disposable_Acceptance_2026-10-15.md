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

## First reusable 8898 browser attempt — pre-clone STOP — 2026-10-15

Greg ran the approved reusable `PeopleIdentityBootstrap` browser preview on his existing Windows desktop checkout at acceptance-tooling SHA `5865beaed0830825aed2c05cf8a053683b6191e7`, with accepted People runtime `dcc8f25f...`, expected version `V0.2.3`, registered port `8898`, and Backbone Apps commit/blob as pinned above.

```text
Preview clone-only identity  bootstrap-preview-20261015163303@sheboyganlights.org
Remote report                /tmp/MSB_People_Identity_Bootstrap_Browser_Preview_20261015T213306.txt
Production shared checkout   bb8dfa498c5b4bbecfc3693f68c4066c1e08242e
Runtime version gate         PASS (V0.2.3)
Exact People regression      PASS (39 passed)
Backbone Apps source step    FAIL: curl: (22) HTTP 404
Runner exit                  22, not resumable
Browser review               NOT STARTED
Disposable clone             NOT CREATED (failure preceded pg_dump)
```

Full cleanup/Production after-check from the operator terminal:

```text
ref.person before/after      4157a1c63a88bc900d566f6eb094f1c4 — UNCHANGED
directus_users before/after  3170a3a5b5860bed1c293f2ee6b50131 — UNCHANGED
Production checkout          bb8dfa498c5b4bbecfc3693f68c4066c1e08242e — UNCHANGED
Production People service    HEALTHY
Preview port 8898            NOT LISTENING after cleanup
```

**Verified source fact:** `Gregovate/MSB-Internal-Web-Backbone` has commit `1d7fa310dd5274078910e3a098ddfd633ae58836`; Backbone PR #25 remains open/draft with that head, and `my/apps/index.html` exists at the exact pinned revision through authenticated GitHub access. The server attempted to obtain this source from an anonymous `raw.githubusercontent.com` URL, which returned 404. This does **not** demonstrate that the Git source or requested blob is invalid. Authentication/availability of that anonymous URL has not been established as a supported means of transferring a draft Backbone candidate.

**Engineering correction required:** preserve the existing reusable launcher and registered 8898 profile; acquire the exact Backbone source through the workstation's authenticated Git transport, verify the committed HTML blob, package it with the existing controlled preview SCP bundle, verify the unchanged blob again before disposable clone creation on the server, and retain fail-closed behavior. Do not download by guessed alternate URL, bypass blob verification, mutate Backbone/People Production, or consume Don's fixture.

### Controlled reusable tooling repair staged (not yet executed)

Read-only authenticated GitHub inspection returned the following exact source evidence:

```text
Backbone repository   Gregovate/MSB-Internal-Web-Backbone
Open draft PR         #25
Backbone commit       1d7fa310dd5274078910e3a098ddfd633ae58836
Committed file        my/apps/index.html
Git blob SHA          9d340e5e944a7cd1db223b539066eb14ddb1c292 (matches existing pin)
```

Source repair was confined to the Production Database repository's **existing reusable browser tooling**:

- `Setup/Acceptance/run_setup_disposable_browser_preview.ps1`: for the People profile only, clone Backbone through workstation-authenticated Git into a temporary non-bundled directory, check out the exact commit without Windows CRLF rewriting, compare the committed HTML blob with the supplied expected blob, compare the actual file bytes and bundled copy with that same blob, and include `apps-index.html` in the existing SCP preview bundle. Abort before remote contact for missing repo/commit/blob or any mismatch. Delete the temporary clone in the normal `finally` path.
- `Setup/Acceptance/people_identity_bootstrap_disposable_browser_preview_server.sh`: do **not** download from anonymous `raw.githubusercontent.com`; require and hash-verify `apps-index.html` from the uploaded preview bundle, and reject a mismatched blob or absent Apps version/endpoint markers before `pg_dump`.
- `Setup/Application/test_setup_reusable_people_identity_preview_profile_contract.py`: regression assertions cover authenticated temporary-clone acquisition, exact commit/blob and raw-byte equality, bundle upload/readability, second server-side verification, and prohibition of the anonymous fetch.
- `Setup/Acceptance/README.md`: owns the reusable tool's external-asset contract and this failure/recovery handoff.

Relevant tooling commits:

```text
68fbc553ffcb014ac50ed6d259adbdd5240e3eee  authenticated workstation Git + pinned bundle
ddbad35f55d027e3abf64b80cedaf813ffabfece  server bundled-asset verification
2b233de6849af8a50b4f70dd2f63231a632a2d78  new acquisition regression assertions
ea708c1e4c3565ed98d0e081ed6f22db5b7142fb  evidence-precise test comments
```

The accepted People runtime `dcc8f25f...` and Backbone source commit `1d7fa310...` are unchanged.

### Repaired tooling — local regression evidence received

Greg's Windows desktop PowerShell output for the repaired tooling confirms:

```text
python -m pytest -q -p no:cacheprovider Setup/Application
    770 passed, 5 skipped in 5.13s
    [100%]
```

The previously pasted terminal also reached `PASS: Bash server syntax` and `PASS: #395 local tooling validation completed` after executing the guarded regression/syntax sequence. The separate focused profile test's new numeric count was not included in the latest excerpt; do not fabricate it. The full Setup result includes the updated preview-profile test file.

These are **local engineering checks**, not reusable 8898 browser acceptance. The corrected source-acquisition path has not yet been exercised in a new integrated preview. The exact accepted People runtime `dcc8f25f...`, pinned Backbone Apps commit/blob, and preserved Don fixture remain unchanged.

Next controlled action: refresh the existing feature branch, confirm a clean matching tooling HEAD and port ownership, then run the same established reusable 8898 profile with exact accepted runtime/App pins under the Server Management browser-review runbook. Inspect readiness, operator browser result, cleanup and Production after-check before changing any Production deployment state.


### Operator handoff: copy only the final result block

The operator should **not need to copy the whole pytest progress or multi-page SSH transcript** to report results. Every future #395 PowerShell test or browser-review command handoff must end with a bounded, clearly labeled result block that includes:

- exact local tooling HEAD and accepted People runtime SHA;
- focused profile regression result and full Setup regression count when those tests were actually run;
- PowerShell/Bash syntax outcomes when checked;
- browser-review status (`NOT RUN`, `READY/IN PROGRESS`, `STOPPED`, or `CLEAN EXIT`—do not confuse CLEAN EXIT with operator acceptance);
- the first blocking error and the server report path when known, otherwise a clear statement that the path is in the preceding terminal output; and
- Production invariants only when verified by the runner.

In PowerShell, capture each command's exit status and retain failure semantics; do **not** pipe an interactive SSH command through `Tee-Object` or other pipelines to harvest its output, because the governed interactive terminal/sudo contract forbids that transport. Prefer a `try/catch/finally` summary printed after the existing launcher returns, and do not claim passing values not actually observed. The operator should only need to paste the lines between `BEGIN #395 RESULT` and `END #395 RESULT`, plus a specific failure detail if the remote report identifies one.

### Operator browser evidence and scope clarification — October 15 (pending final runner result)

Greg supplied a screenshot of `127.0.0.1:8898/` displaying the expected MSB Apps launcher. The captured portion showed ordinary Apps navigation without a visible identity-bootstrap error, Directus login, or Google account chooser. The visible frame did **not** include the bottom version footer and did **not** prove that the disposable identity was created, linked, or idempotent. A second screenshot showed the real Production Setup `https://my.sheboyganlights.org/setup/?view=perform` reached through an Apps link. That is an **external Production destination**, not an integrated disposable Setup browser instance; no Production write is evidenced by the screenshots, but no Production after-check for this live browser session has yet been supplied.

This established a review-instruction clarity gap. The operator checklist now explicitly says to **stay on the localhost Apps page**, verify the Apps v0.2 footer, refresh localhost once and confirm no warning, then press Enter in the existing foreground PowerShell session. Only the server runner's real disposable Directus/Person state verification and final cleanup/Production after-check can complete browser acceptance. The durable procedural correction is maintained in [reusable Setup browser acceptance](../../Setup/Acceptance/README.md#people-395-operator-browser-checklist--only-the-local-apps-page).

Historical interim state: visual review was initially pending final server evidence. **Superseded by the completed runner PASS / exit 0 and Production-after checks documented below.** Don's preserved Production fixture was not consumed by the localhost preview.

## Reusable 8898 Browser Integration — Final Runner PASS — 2026-10-15

### Authoritative operator/server evidence

After the corrected authenticated-Git Backbone Apps acquisition, Greg exercised the same reusable `PeopleIdentityBootstrap` profile on the registered local URL `http://127.0.0.1:8898/` and provided the browser observations and final foreground runner output.

The browser visibly presented the pinned `MSB Apps v0.2 — Updated 2026-10-15` footer. No Directus/Google account chooser or bootstrap-error banner was visible in the reviewed Apps screen. The visual page intentionally remains almost identical to earlier Apps; the #395 behavior is the silent backend identity initialization. The Apps buttons target real `my.sheboyganlights.org` Production applications, **not** a disposable copy of Setup. The user was instructed to remain on localhost for the acceptance; the real Setup screenshot was outside the disposable identity test.

The server runner finished the explicit `verify_browser_result` step and produced:

```text
PeopleIdentityBootstrap REUSABLE DISPOSABLE BROWSER PREVIEW: CLEAN EXIT
Exit status: 0
Preview report:
  /tmp/MSB_People_Identity_Bootstrap_Browser_Preview_20261015T215102.txt
Preview Flask log:
  /tmp/MSB_People_Identity_Bootstrap_Browser_Preview_Flask_20261015T215102.log
```

In the current accepted tooling, the remote runner emits its browser `PASS` only after verifying the clone-only Directus identity is active, Google-backed, exact-email, **MSB Browser** role, safely linked to a Person, and remains idempotent on repeat bootstrap. Normal runner completion is impossible after a failed assertion there. The `CLEAN EXIT` result therefore establishes the governed **disposable integration test** PASS, not Production deployment or Don's final real first-login verification.

The final cleanup/Production preservation evidence returned by Greg:

```text
Production ref.person:
  before 4157a1c63a88bc900d566f6eb094f1c4
  after  4157a1c63a88bc900d566f6eb094f1c4
  PASS: unchanged

Production directus_users:
  before 3170a3a5b5860bed1c293f2ee6b50131
  after  3170a3a5b5860bed1c293f2ee6b50131
  PASS: unchanged

Production shared checkout:
  before bb8dfa498c5b4bbecfc3693f68c4066c1e08242e
  after  bb8dfa498c5b4bbecfc3693f68c4066c1e08242e
  PASS: unchanged

Production People service:  PASS — remains healthy
Preview TCP 8898:           PASS — no longer listening
Remote exit status:         0
```

### Separate workstation reporting error — not a preview failure

After the successful runner exit, Greg's interactive PowerShell console received a standalone `finally { ... }` fragment from a previously supplied multi-part `try/catch/finally` result-summary example. The shell rejected the word `finally` as an unknown command because the matching `try` statement was no longer in the same parsed PowerShell statement. This was an **operator-command composition defect in the assistant's reporting instructions**, unrelated to the validated launcher, Linux server process, clone, or teardown. The final PowerShell `if ($result -ne 'CLEAN EXIT')` condition cannot override or invalidate the already completed remote exit 0.

Do not rerun the disposable browser preview or repeat the regression solely to repair the optional console footer. Future workstation command handoffs must either provide one fully contiguous valid PowerShell `try/catch/finally` command (not fragments/pasted piecemeal) or have the existing script print the bounded results itself; never ask Greg to assemble a `finally` block manually. Keep interactive SSH foreground and **never** pipe it through `Tee-Object`, as prohibited by the Server Management runbook.

### Acceptance and remaining gate

```text
#395 accepted People runtime                dcc8f25f07a74e19ce3de3aae2d9d137b5411815
Repaired tooling Setup/Application regression 770 passed, 5 skipped
Apps + People disposable browser review      PASS — runner exit 0
Production ref.person fingerprint            UNCHANGED
Production directus_users fingerprint        UNCHANGED
Production People service                    HEALTHY
Preview 8898 after cleanup                   STOPPED / NO LISTENER
Don first-login Production fixture           UNCONSUMED
Production deployment                        NOT AUTHORIZED
```

**Next:** preserve this passed evidence; do **not** recreate the disposable clone. Conduct separate Production deployment planning under the current Server Management change/maintenance runbook and Backbone publishing authority only when explicitly authorized. Don's preserved real first-login test is a subsequent Production acceptance gate, not part of this disposable browser review. The operator has completed the prescribed visual check, but the final Production release authorization is **not implied** by the browser test or CLEAN EXIT.

## #395 Release Authorization and Mandatory Deployment Preflight — 2026-10-15

Greg expressly requested: **"if it's ready then merge and migrate to production"** after the accepted disposable and integrated Apps+People browser review. This authorizes advancing approved source through PR review/merge and preparing the governed release; it does not waive any mandatory Production maintenance, verified rollback, secret-handling, live-checkout, exact-SHA, or installation gate.

### Cross-repository release scope

- **Production Database PR #401** supplies the accepted People `V0.2.3` runtime (accepted source `dcc8f25f...`), migration `People/Database/006_create_silent_identity_bootstrap_contract.sql`, acceptance tooling, and engineering evidence.
- **Internal Web Backbone PR #25** supplies exact accepted `my/apps/index.html` source `1d7fa310dd5274078910e3a098ddfd633ae58836` (blob `9d340e5e944a7cd1db223b539066eb14ddb1c292`). It requires controlled static publication **after** the backend is healthy, with source/live comparison and post-publication visible version verification.
- **Server Management** owns `docs/server/Production_Database_Change_Deployment_Runbook.md`, `docs/server/Production_Database_Maintenance_Mode.md`, and the established `People_Production_Runtime.md` / `Protected_Flask_Application_Service_Deployment.md`. Its #37 controller must fence writers for migration 006; snapshot validity, checkout identity, least-privilege contract and ONLINE return require proof.

### RUNBOOK GAP FOUND — do not execute migration 006 yet

The accepted #385 Production runner `People/Acceptance/people_identity_reconciliation_production_deploy_server.sh` is hard-pinned to migration **005**, accepted `V0.2.2`, and #385's exact rollback definitions. Replaying or text-substituting it to deploy #395 would violate the reviewed release identity and rollback contract. As of this checkpoint there is **no separately accepted, contract-tested #395 Production migration-006 + V0.2.3 release runner and rollback plan** identified by the owning People release artifacts.

Additionally, `People/Application/README.md` explicitly requires a **protected server-side `PEOPLE_DIRECTUS_IDENTITY_TOKEN` credential** with Directus administrator accountability to create Google-backed user identities through the supported Users API, alongside `PEOPLE_DIRECTUS_URL`. The accepted disposable runner generated a disposable-only credential; that evidence is **not** proof that the Production `/etc/msb-people/people.env` has a properly governed secret. Production installation must check or provision the credential through an accepted protected runtime procedure without exposing or recording its value.

**Before Production mutation:** prepare/review an exact merged-main SHA release profile or runner under the current Server Management runbooks; validate rollback/migration 006 and role grants; verify the protected Directus credential and service startup/negative identity guard; identify the exact Backbone allowlisted Apps publishing procedure and current published source; record a single directing deployment window. Only the approved runner may enter #37 maintenance, create a validated frozen rollback archive, apply migration 006 and promote the source, return ONLINE and verify service/browser. Preserve Don's untouched real first-login fixture until the separate live acceptance is ready.

**Status here:** approved source merge can proceed when merge gates are satisfied. Production database migration and Apps publication are **not yet reported executed**. Do not infer deployed state from GitHub merge or from the successful localhost browser review.

## Merged Release Source and Production Stop Point — 2026-10-15

Greg authorized #395 merge and Production migration, subject to existing MSB governance. The two accepted source pull requests were merged using GitHub's expected-head guard:

```text
Production Database PR #401 -> main    cab3c1caa7c4c018ee132ffd5918999baf4f837d
Backbone Apps PR #25 -> main           91674b254d204235366f7d9a17f8395ae98149af
Accepted People runtime               dcc8f25f07a74e19ce3de3aae2d9d137b5411815
Accepted Apps HTML source              1d7fa310dd5274078910e3a098ddfd633ae58836
Accepted Apps HTML Git blob            9d340e5e944a7cd1db223b539066eb14ddb1c292
Production migration target            People/Database/006_create_silent_identity_bootstrap_contract.sql
Visible People release version         V0.2.3
```

**MERGED DOES NOT MEAN DEPLOYED.** Last actual governed remote evidence was the disposable browser review ending in exit 0: the shared Production checkout remained `bb8dfa498c5b4bbecfc3693f68c4066c1e08242e`, People remained healthy as the previous V0.2.2 baseline, and Production identities were unchanged. No subsequent Production maintenance/deployment/Apps publication receipt has been supplied in this workstream.

**RUNBOOK GAP FOUND — deployment intentionally stopped before Production mutation.** The #385 People release runner is specifically pinned to migration 005, V0.2.2 and rollback definitions for that older migration; it is **not** an accepted #395 migration-006 install path. The Server Management production database and #37 maintenance runbooks provide the governing pattern, but #395 still requires a feature-owned **reviewed, testable release runner** with an exact main SHA and migration 006 blob, controller-maintenance/freeze proof, validated rollback snapshot, least-privilege checks, known-function cleanup or fail-closed committed-migration containment, People V0.2.3 health and other live regressions. In particular, do not automatically replay the #385 installer or execute migration 006 as an isolated ad-hoc `psql` operation.

A required protected service secret is separately unresolved: the new backend requires `PEOPLE_DIRECTUS_IDENTITY_TOKEN` with Directus administrator-level provider-field creation accountability in `/etc/msb-people/people.env`. Its current **Production existence/validity has not been verified** and no service credential value may be pasted into chat or Git. An approved least-privilege/dedicated identity and installation/rollback procedure must be reconciled before deployment.

Backbone source is merged but the approved, allowlisted source-to-live **Apps page publishing** procedure, current live file, and publication verification remain to be reconciled from `MSB-Internal-Web-Backbone` authority. Publish `my/apps/index.html` only after People V0.2.3 backend, migration 006 and credential checks are accepted/ONLINE. Never manually copy arbitrary same-named index files or perform whole-root sync.

**Next governed engineering step:** reconcile exact Production live checkout, controller status, service environment credential presence (no secrets displayed), migration 006 absence/presence, and Backbone static publication tooling using read-only checks; prepare/review and contract-test the #395 installation tooling on a separate branch from merged main. No additional disposable Apps browser test is required solely because the release runner is new. Only after those gates can the already authorized operator execute an approved bounded Production migration window. Don's real first-login fixture remains unconsumed until final live acceptance.

## Production authorization — read-only readiness gate staged (October 15, 2026)

Greg explicitly approved Production for Issue #395 after [PR #401](https://github.com/Gregovate/MSB-Production-Database-Project/pull/401) and Backbone [PR #25](https://github.com/Gregovate/MSB-Internal-Web-Backbone/pull/25) merged and after the disposable Apps+People browser review returned PASS. **This is operator Production authorization, not proof of installation.**

The exact merged source pins currently authorized for release reconnaissance are:

```text
Production Database main  6122d7923c2a07eb6b278225cf71cafc4704d349
People runtime            dcc8f25f07a74e19ce3de3aae2d9d137b5411815
People version            V0.2.3
People migration          People/Database/006_create_silent_identity_bootstrap_contract.sql
Backbone Apps main        91674b254d204235366f7d9a17f8395ae98149af
Backbone Apps blob        9d340e5e944a7cd1db223b539066eb14ddb1c292
```

Before any maintenance or migration, the **new read-only preflight**, staged separately from merged Production source, must be run and its compact receipt inspected:

```text
People/Acceptance/run_people_395_production_readonly_preflight.ps1
People/Acceptance/people_395_production_readonly_preflight.sh
People/Acceptance/test_people_395_production_readonly_preflight_contract.py
```

This runner follows the Server Management Production Database Change Deployment Runbook and Issue #37 maintenance state query contract; it **does not switch maintenance, apply SQL, restart services, advance a checkout, create Directus users, or publish Apps**. It verifies server/controller ONLINE state, V0.2.2 live People service, clean previously accepted Production HEAD, current `origin/main` equality with the approved SHA, #385 function and baseline Browser role, migration 006 still absent, the real Don fixture still unconsumed, Production identity fingerprints, and protected `/etc/msb-people/people.env` identity-bootstrap token presence and non-mutating Directus `/users/me` authentication. The token must never be printed, passed as a command argument, written to Git or surfaced in the terminal report. Token authentication does **not** yet prove permission to set provider fields and does not remove the dedicated-credential review requirement.

The unique uploaded preflight bundle is removed; the `/tmp/MSB_People395_Production_Readonly_Preflight_*.txt` report is preserved. The runner prints a bounded `BEGIN #395 RESULT` / `END #395 RESULT` footer for Greg to paste without pages of logs. The workstation wrapper enforces source checkout and runs its focused contract tests before server contact; server script syntax is checked via `bash -n`.

**STOP CONDITIONS:** any mismatch in live checkout/version, controller ONLINE/unfenced state, #385/migration objects, Don preservation, exact remote main, or missing/invalid protected Directus token stops the work before database mutation. This is not a substitute for the still-required reviewed migration 006 production deployment runner and validated rollback/commit containment or the Backbone controlled Apps publishing procedure. No Production migration or static publication receipt exists yet. Continue from the preflight result and the governing runbooks, not from ad hoc SQL or #385's migration-005 installer.

## First governed Production preflight — credential STOP (2026-10-15)

Greg ran the versioned read-only `People/Acceptance/run_people_395_production_readonly_preflight.ps1` wrapper. The retained host report is `/tmp/MSB_People395_Production_Readonly_Preflight_20261015T232453.txt`.

```text
Exact merged-main release target  6122d7923c2a07eb6b278225cf71cafc4704d349
Live shared checkout             bb8dfa498c5b4bbecfc3693f68c4066c1e08242e
Issue #37 controller             ONLINE / UNFENCED
Production ref.person MD5        4157a1c63a88bc900d566f6eb094f1c4
Production directus_users MD5    3170a3a5b5860bed1c293f2ee6b50131
Stop step                        Check protected Directus credential without printing secret
Credential                       STOP: NOT READY
Exit                             30
Production writes                NONE
```

The full earlier preflight sequence reached the credential step, which means its preceding controller, checkout, baseline-version, object-presence and Don-fixture guards did not stop. The token check deliberately used a single generic failure message covering missing environment key, wrong file protection/URL, invalid/expired credential, Directus connectivity or an inactive token owner. **This result alone does not establish which condition failed. Do not assume the token is merely missing or insert an arbitrary administrator token.** No maintenance transition, migration 006, People deployment, Apps publication or Don bootstrap was performed.

The next controlled action is non-secret **read-only credential failure classification** under the existing Server Management People runtime authority. Any diagnostic must display only a bounded reason category and HTTP status if applicable—never the bearer token, environment file content, service-account password or raw response. Reconcile the actual failure before governed provisioning. Maintain the current Production ONLINE state. The older #385 installer still cannot be reused for migration 006.

### Credential failure classification correction — still read-only

The initial approved preflight intentionally reported one generic `Credential: STOP: NOT READY` outcome for all credential problems. That preserved the secret but could not distinguish whether the environment file or token was absent, permissions were unsafe, authentication failed, the Directus listener was unavailable, or the token owner was inactive.

The reusable **read-only** `people_395_production_readonly_preflight.sh` credential gate now reports exactly one bounded failure code in its existing `Credential:` footer field: `ENV_FILE_MISSING`, `ENV_FILE_PERMISSIONS`, `ENV_FILE_UNREADABLE`, `TOKEN_NOT_CONFIGURED`, `DIRECTUS_URL_MISMATCH`, `DIRECTUS_AUTH_HTTP_401`, `DIRECTUS_AUTH_HTTP_403`, other `DIRECTUS_HTTP_<status>`, `DIRECTUS_UNREACHABLE`, `DIRECTUS_RESPONSE_INVALID`, or `DIRECTUS_USER_INACTIVE`. It never prints credential contents, Directus user ID/email, response JSON, or the environment file. The check remains a read-only authenticated GET to `/users/me` and cannot create/update a Directus identity.

**Next gate:** refresh the current #395 release-readiness feature branch, run its focused read-only-tool contract test and existing foreground preflight, then paste **only the final result block**. Do not replay the migration, add arbitrary static tokens or switch #37 maintenance merely because the credential failed. A PASS of the Directus GET does not prove administrator-level provider-field mutation rights; that will require the separately reviewed release credential contract. No Production mutation has been performed by this correction.

## Second governed Production preflight — missing token confirmed (2026-10-15)

Greg ran the corrected non-secret diagnostic and supplied the exact footer:

```text
Release target         6122d7923c2a07eb6b278225cf71cafc4704d349
Production HEAD        bb8dfa498c5b4bbecfc3693f68c4066c1e08242e
Controller             ONLINE / UNFENCED
Credential             STOP: TOKEN_NOT_CONFIGURED
Person fingerprint     4157a1c63a88bc900d566f6eb094f1c4
Directus fingerprint   3170a3a5b5860bed1c293f2ee6b50131
Exit status            30
Production writes      NONE
Retained report        /tmp/MSB_People395_Production_Readonly_Preflight_20261015T233214.txt
```

This distinguishes the exact problem from the earlier generic `STOP: NOT READY`: **the `PEOPLE_DIRECTUS_IDENTITY_TOKEN` setting has no configured value in the protected People environment-file parsing path**. It does not establish that Directus itself is unhealthy or that a token was rejected; authentication was not attempted because no token was configured. All upstream runbook guards reached the credential gate without stopping. Migration 006, People service promotion, Backbone Apps publication, #37 maintenance transition, and Don's real first-login acceptance were **not** performed.

### Existing Server Management credential authority — Issue #49

Read `Gregovate/MSB-Server-Management` Issue #49 ("Establish governed Directus service-credential provisioning and recovery procedure") and the current `docs/server/Setup_Production_Runtime.md` as provenance, **not as a substitute for a controlled runbook**. Prior read-only evidence established:

- The existing `Work Order Intake (Service)` Directus identity is application-specific and its static token powers `SETUP_DIRECTUS_INTAKE_TOKEN`; accepted #172 deployment reused that unchanged existing identity.
- The other token-bearing Production identity observed during #49's reconnaissance was a **human Administrator**. The accepted #172 path deliberately did not reuse it.
- The reusable Directus service-credential **creation, permission design, secure installation, rotation and recovery procedure remains open as Server Management #49** even though Setup #172 deployment succeeded.

For #395 the required Directus Users API operation creates a Google-backed identity, sets `provider` and `external_identifier`, and assigns `MSB Browser`; it is not the Work Order Intake collection-create permission. **Do not reuse or rotate the Work Order service token; do not copy a human Administrator token.** The accepted disposable bootstrap demonstrated an administrator-authorized Directus Users API operation but **did not prove that a narrower Directus service policy can set provider/external_identifier**.

**RUNBOOK GAP FOUND — credential provisioning and authorization.** Before any Production identity/token mutation, Server Management #49 must define and disposable-test a dedicated #395 non-human service principal's effective permissions, including exact field authority, required denied operations, audit attribution, protected runtime-token installation/rotation, rollback and cleanup. A dedicated administrator-level token would be broad and requires explicit architecture/security review if a least-privilege role cannot support the required fields. The root-owned People environment remains outside Git; do not expose tokens in command arguments, reports, chat or repository files.

**Next actionable gate:** implement and accept the #49 procedure (including a scoped-permission disposable proof where feasible), verify the protected People runtime with a non-secret GET to `/users/me`, then follow the separate #395 migration 006 release runner/rollback and controlled Backbone Apps publisher. The user’s Production approval stands, but approval does not waive that credential safety boundary. Keep Production ONLINE while this is unresolved.

## #49 / #395 Scoped Service Credential Proof — Candidate, Not Yet Executed

The exact `TOKEN_NOT_CONFIGURED` Production STOP above remains authoritative. Do **not** rerun that diagnostic until a governed People service credential has actually been installed.

The active release-readiness branch now extends the **existing** accepted #395 disposable PostgreSQL + Directus 11.17.1 harness with an opt-in `-ServiceScopeProbe` switch. It does **not** create another disposable orchestration system and does not change `People/Application`, `People/Database`, the accepted runtime `dcc8f25f...`, or Production service configuration.

```text
People/Acceptance/run_people_identity_bootstrap_disposable_acceptance.ps1
    -ServiceScopeProbe
People/Acceptance/people_identity_bootstrap_disposable_server.sh
People/Acceptance/people_395_service_scope_disposable_probe.sh
People/Acceptance/test_people_395_service_scope_disposable_contract.py
```

**Purpose:** prove (or disprove) in the disposable current-Production clone whether a **non-admin/API-only** Directus service role, with only field-limited `directus_users.create` permission and validation for `google`, `active`, and the baseline `MSB Browser` role, can perform the exact #395 Users API POST. All test roles, users, policies, permissions, tokens and simulated humans are uniquely named **disposable-only** fixtures. The accepted harness verifies Production before/after identity fingerprints and always tears down its disposable containers. This profile is strictly opt-in; the original accepted harness/default branch behavior is preserved.

The probe validates the effective Directus permissions and requires all of the following before declaring PASS:

- active scoped service authentication to disposable Directus 11.17.1;
- creation of the exact Google-backed Browser identity through the actual Users API;
- failure of Manager-role elevation, arbitrary Directus user updates, and unrelated Work Order Intake creation;
- no broad Directus user listing outside the service identity;
- no `ref.person` auto-creation for the synthetic test email;
- no `admin_access` or Data Studio app access in the service policy; and
- unchanged Production identity fingerprints after disposal.

The disposable Directus container may be restarted **by its exact generated test-container name only** to refresh policy cache after clone-only fixture seeding; this is not a restart of Production Directus. Test-generated bearer credentials are never printed or stored in Git.

**HISTORICAL STATUS (before first run): tooling implemented; executable result was then STOP/exit 1 because required `directus_access.id` was omitted. The corrected fixture is now staged; no second executable result has yet been supplied.** A failure is useful evidence that the non-admin design may require correction, and is **not** permission to substitute a human Administrator token or immediately grant a dedicated service account full administrative authority. Do not create a Production token, modify `/etc/msb-people/people.env`, apply migration 006, or publish Apps before a reviewed scope proof and Server Management #49 provisioning/rollback procedure.

**Next:** run the scoped profile from the clean current release-readiness branch, using the accepted wrapper's foreground SSH/clone isolation, and copy only its final `BEGIN #395 RESULT` block. After PASS, design the separately reviewed #49 Production credential creation/install/recovery sequence and migration 006 deploy runner. Don's real first-login fixture remains unconsumed.

## First #49 / #395 Scoped Directus Service Permission Proof — STOP, 2026-10-15

Greg executed the opt-in disposable profile on exact acceptance-tooling SHA `94c505d7dbbd28e8d3f48d7cb02d7cce50232648` against `directus/directus:11.17.1`. The operator supplied the complete **compact result block**:

```text
Proof target:       #49 / #395 scoped Directus service credential
Accepted People:    dcc8f25f07a74e19ce3de3aae2d9d137b5411815
Tooling SHA:        94c505d7dbbd28e8d3f48d7cb02d7cce50232648
Disposable scope:   STOP (first failed line still to be retrieved)
Person after:       PASS
Directus after:     PASS
Production writes:  NONE
Real Don fixture:   NOT CONSUMED
Exit status:        1
Report:             /tmp/MSB_People_Identity_Bootstrap_Disposable_20261015T235232.txt
```

**Disposition: NOT ACCEPTED.** Exit 1 is a generic script/command failure, **not evidence of any specific Directus role/policy authorization rejection**. The failed command could have occurred before the scoped Users API test. In particular, do not infer from this receipt that the non-admin Directus user-creation permission is impossible, and do not respond by creating an administrator-authorized Production credential.

Greg supplied the bounded read-only report excerpt from the retained `/tmp/MSB_People_Identity_Bootstrap_Disposable_20261015T235232.txt` report. The stage sequence definitively reached:

```text
PASS: disposable PostgreSQL restored from current Production
PASS: People migrations 001-006 applied to clone
PASS: disposable Directus 11.17.1 healthy
PASS: disposable Directus admin API authentication
--- Disposable Directus API-only service credential scope probe ---
ERROR: null value in column "id" of relation "directus_access" violates not-null constraint
--- Cleanup ---
PASS: Production ref.person fingerprint unchanged
PASS: Production directus_users fingerprint unchanged
```

**Root cause: disposable fixture SQL omitted the required `public.directus_access.id`, which has no usable automatic default in the accepted Directus 11.17.1 clone.** The scoped service role/policy linkage failed before the Users API permission test. This is neither evidence that non-admin Directus Users API creation works nor evidence that it is impossible.

Controlled acceptance-tooling correction: change only `People/Acceptance/people_395_service_scope_disposable_probe.sh` to use `INSERT INTO public.directus_access (id,role,policy) VALUES (gen_random_uuid(), ...)`, with a mandatory regression assertion in `test_people_395_service_scope_disposable_contract.py`. The existing People backend/migration remain pinned to `dcc8f25f...` unchanged. The acceptance harness now also prints a **bounded `Scope stage`** in the final `BEGIN #395 RESULT` footer (for example, `LINK_ROLE_POLICY`, `CREATE_PERMISSION`, or `VERIFY_SERVICE_API_PERMISSIONS`) so another stopped probe has a useful location without extracting pages of logs. Do not alter Production schema, Directus users/roles/policies/tokens or the existing Work Order Intake credential. After local regression and exact clean branch checks, one governed opt-in disposable rerun may resume the unfinished permission proof. The original failed report is preserved, not overwritten.

The reusable scoped-probe reporting standard should include a safe first-failure **category/location** in its final result block after diagnosis, avoiding another request for multiple pages of terminal output. That is acceptance-tooling improvement, not a runtime change.

## Second #49 / #395 service-scope disposable attempt — API-permission stage STOP (2026-10-15)

Greg supplied the completed bounded acceptance result from tooling SHA `d57b2177f01aebf55718c2cada2190b73f818e9f`:

```text
Proof target:      #49 / #395 scoped Directus service credential
Accepted People:   dcc8f25f07a74e19ce3de3aae2d9d137b5411815
Tooling SHA:       d57b2177f01aebf55718c2cada2190b73f818e9f
Directus image:    directus/directus:11.17.1
Disposable scope:  STOP
Scope stage:       VERIFY_SERVICE_API_PERMISSIONS
Person after:      PASS
Directus after:    PASS
Production writes: NONE
Real Don fixture:  NOT CONSUMED
Exit status:       74
Server report:     /tmp/MSB_People_Identity_Bootstrap_Disposable_20261016T000349.txt
```

The scoped-policy fixture progressed past the previous `directus_access.id` insert failure, as the stage reached the actual API-permission verification. **The exact failed API assertion is not established by this compact report**; do not infer that non-admin Directus user creation is unsupported, or that any particular privilege should be added. The guarded runner reports the failure cleanly; Production identities are unchanged.

### Architecture/effort decision re-opened at operator request

Greg questioned the disproportionate engineering effort involved in eliminating the extra Google login at the Directus website and stated that, had this effort been known, he would have considered a different approach. **Pause further service-credential experiments and Production deployment work while the architecture trade-off is made explicit.** This is a design-direction checkpoint, not withdrawal of the earlier Production approval.

The existing authoritative [Directus User Onboarding Identity Contract](../../Docs/02_Production_Database/01_System_Architecture/03_People_and_Identity/engineering/Directus_User_Onboarding_Identity_Contract_2026-09-09.md) already records current Directus 11.17.1 Google OpenID support (`AUTH_GOOGLE_ALLOW_PUBLIC_REGISTRATION=true`) and a supported provider-specific route at `https://db.sheboyganlights.org/auth/login/google` with a configured/allowed return URL. The route can begin Google SSO **without first rendering the Directus Data Studio login screen**. A conditional Apps → Directus Google SSO → protected Apps return flow may avoid creating/maintaining a privileged People bootstrap service token, but this option **has not been accepted or tested**. It must prove the Cloudflare-vs-Directus Google identity match on shared tablets and prevent the live User Onboarding Flow's missing-Person branch from creating a Person, with baseline role/no-elevation and existing-user role preservation intact. A Google account chooser or extra sign-in step may still be visible. Never claim a seamless transparent flow without such proof.

The merged #395 People/Apps source remains *source-only*, not Production deployed. Do not discard the accepted source or change live login redirects without a reviewed decision. Before further testing, explain the simpler Directus SSO redirect option, its operator-visible difference and the two unresolved safety conditions; let Greg choose whether to re-scope #395 rather than continuing the credential effort automatically. Do not consume Don's final Production fixture.

### Operator correction — actual login UX problem and intended simple remedy

Greg clarified that MSB already has Google authentication at the protected `my.sheboyganlights.org` Cloudflare boundary **and** Google authentication is already possible in Directus. The immediate operator-facing defect is not that people cannot choose Google; it is that the Directus first-login screen unnecessarily offers **both username/password and Login with Google**, confusing volunteers despite explicit instructions to use Google exclusively. Greg expected a much smaller UX correction and objected to the expanding service-credential/migration/deployment burden. This clarification supersedes any implication that a generic second Google redirect is itself the requested innovation.

The most direct UX-only candidate to examine is a **one-time MSB Apps link/redirect straight to the existing Directus Google provider sign-in route**, thereby bypassing the mixed password/Google choice screen and returning the user to MSB Apps/previous destination. This may still invoke Google's normal account selection and is **not necessarily fully silent**; no Production behavior has been changed or this routing proven. It must not send volunteers into Directus Data Studio or alter the existing custom MSB operator applications.

A safe route still requires targeted checks: Directus provider redirect/allowed return origin, matching the Cloudflare identity on shared tablets, prevention of the existing User Onboarding flow's missing-Person auto-create path, and preservation of baseline Browser/existing higher roles. Those are open gates, not evidence the redirect is accepted. A one-time first-login experience may be a reasonable tradeoff if the only unwanted operator screen is Directus's login-choice page.

**Engineering pause:** Do **not** conduct another scoped service-token experiment, provision a privileged credential, install migration 006 or publish merged Apps v0.2 while this simpler login-route alternative is being evaluated. Preserve previously merged source and accepted test evidence for possible reuse, but do not imply its architecture is still the chosen implementation. Compare a narrow direct-provider route versus continuing silent API bootstrap, disclose complexity and residual second-account selection, and obtain explicit direction before new implementation. This checkpoint is a design clarification, not a Production approval revocation or a claim that Directus Data Studio could have met MSB's broader custom workflow requirements.

### Clarification: pre-existing Directus user vs. Person-link repair (#385, #230, #395)

Greg clarified the operational history of why a volunteer was required to visit the Directus login at least once. The **initial Google sign-in caused Directus to create an otherwise missing Directus user**. Subsequent protected application use also needed that user associated with an existing `ref.person`; newer work now appears to have solved that latter failure once the Directus user exists.

The exact repository owners are distinct:

- **Production Database #385, People V0.2.2, merged/deployed**: shared safe exact-email `ref.person.directus_user_id` self-reconciliation for an existing active Google-backed Directus user, implemented in `People/Database/005_reconcile_directus_person_identity.sql`; does not create Directus users and does not assign roles.
- **Production Database #230**: Manager Reference Data maintenance (Container, Display, Storage Location, etc.), **not** the ownership authority for this identity-reconciliation contract. Any apparent association with #230 in the operator's recollection should not silently change the owning issue or be dismissed without tracing a specific deployed action.
- **Production Database #395**: the remaining first-time Directus **user-creation/login-choice** problem. Cloudflare/Google authentication at `my.` already identifies the human, but does not create the needed Directus user.
- **Original Directus User Onboarding Flow**: triggered only on `directus_users.items.create` and still contains an unsafe missing-Person branch capable of creating a `ref.person` row. #385 means this Flow is no longer the durable link-repair mechanism, but #385 does **not** remove the Flow's unsafe missing-Person behavior.

**Design implication:** stop treating the task as if the Person link, authorization or a new universal identity management layer must be rebuilt. Re-evaluate the simplest one-time creation of the Directus Google user by bypassing the confusing mixed username/password-or-Google Directus login page and entering the existing Directus provider-specific Google sign-in directly. On successful first creation, the existing #385 reconciliation can safely link an existing Person on protected use when exact-email/provider/external-identifier and no-conflict conditions hold. Creation still needs a Browser baseline and the Flow's missing-Person auto-create branch needs correction/containment, with explicit checks for shared-tablet Cloudflare-versus-Directus identity mismatches.

This is an **architecture clarification and pause**, not a passed alternate implementation and not evidence that the Directus user can already be created automatically without the login. The previous merged #395 People V0.2.3/Apps code and its disposable evidence remain preserved but **not deployed**; do not continue the #49 service-token-provisioning experiment or request another Production action before Greg decides whether the smaller direct-Google sign-in path fits his actual operator experience.

### Operational account scope correction — Google account does not imply Directus entitlement

Greg explicitly clarified that **not every Sheboygan Lights Google Workspace account needs Directus**. Tablets, print servers, and other infrastructure/nonhuman principals should **never be given an interactive human Directus login**. The account `workorders@sheboyganlights.org` is used **strictly for email**, not an MSB human operator, and its Workspace/email existence must not trigger Directus human creation or grant application authorization.

Separate four authorities:

1. **Google Workspace mailbox/account** — may serve email-only, device, service, or human needs. Its existence does not authorize any MSB application.
2. **`ref.person`** — durable human record and safe exact-email association target; not equivalent to a Directus user, and not itself a role grant.
3. **Interactive Directus Google identity** — only when an identified human is deliberately entitled to a Directus-backed protected application; initial role at most MSB Browser. Existing higher-role assignments are preserved, not inferred.
4. **Nonhuman service/API identity** — only when a specific backend integration needs API access, through a separately governed least-privilege credential. It must not acquire interactive human login or be linked/reconciled to `ref.person`. Tablet/device identities, if currently represented in Directus for technical authorization, do not thereby become human sign-in accounts.

**Different literal mailbox names — verify, do not merge:** Greg specified `workorders@sheboyganlights.org` (plural) as email-only. Historical Server Management [Issue #49](https://github.com/Gregovate/MSB-Server-Management/issues/49) separately documents `workorder@sheboyganlights.org` (singular), role `Work Order Intake (Service)`, used by Setup #172 through `SETUP_DIRECTUS_INTAKE_TOKEN`. Current evidence does **not** prove whether the two addresses are distinct accounts, aliases, or a naming discrepancy; do not invent equivalence, change the known service token, or enroll the email-only address in Directus because its name is similar.

**#395 design guard:** eligibility to bootstrap must never be inferred from possession of an `@sheboyganlights.org` email alone. If any automatic login path is retained, it must explicitly reject nonhuman/email-only accounts even if an active Person row or Google account happens to exist. Existing SQL 006 exclusions cover literal `tablet-*`, `printservice@`, and `production-1@` identities, but do not name `workorders@`; these are **not evidence of a complete identity-category model**. Do not silently broaden credentials, whitelist all Workspace members, or provision unnecessary Directus users to eliminate one UI step. The simpler direct Google-provider login option must honor the same human-eligibility rule and must not automatically create a Person through the flawed legacy onboarding Flow.

This correction reinforces the pause on #49 service-token experiments and #395 Production deployment while the operator-facing one-time Google login path is reconsidered. The already deployed #385 reconciliation remains authoritative **only after an active human Directus identity exists** and only when its exact existing Person-link conditions pass. No Production mutation was performed by recording this decision.

### Explicit Person-versus-account lifecycle clarification

Greg reaffirmed that `ref.person` is the long-lived record of **people involved in Making Spirits Bright**, and it intentionally includes many people who **do not have an MSB email address because they do not want one**. That is normal, legitimate data; it is not an onboarding error, missing-account cleanup queue, or reason to provision Google Workspace/Directus access. A person may remain active and participate in MSB work with only existing contact information.

Application access, when actually needed, is a separate decision from Person membership. A Google Workspace mailbox may exist solely for communications; its presence does not authorize a Directus interactive login. An eligible human's Directus identity can be created through a supported, governed mechanism if needed for their application role. If an active, correct Google-backed Directus identity already exists, deployed People V0.2.2 / #385 handles only the safe matching `ref.person.directus_user_id` reconciliation. It does not create a missing Directus user, grant a role, or provide an MSB email address to a Person who does not want one.

The user cited Don, a retired operations manager and board member who is interested in the custom system, as an example of a human Person whose real access needs should be handled deliberately; **past leadership, board membership, expressed curiosity and legacy `is_manager` flags do not automatically grant Directus Manager authorization**. Any future onboarding design must keep actual access entitlements explicit and preserve the Person table's independence from accounts.

**Do not attempt to resolve #395 by auto-provisioning every `ref.person` row, every MSB email, every Google Workspace account, or any nonhuman/email-only identity.** The narrowed operator problem is the confusing first-time Google authentication path for humans who need Directus-backed applications, while safe Person association is already covered by #385. The more invasive service-token approach remains paused pending a clear architecture decision. No Production migration, deployment, identity change or test was performed by documenting this clarification.

## Disposition

```text
DISPOSABLE RUNTIME ACCEPTANCE: PASS
APPS + PEOPLE DISPOSABLE BROWSER REVIEW: PASS / CLEAN EXIT 0
PRODUCTION IDENTITY + SHARED CHECKOUT: UNCHANGED
DON MARTENS FIXTURE: PRESERVED / UNCONSUMED
PRODUCTION RELEASE AUTHORIZATION: GRANTED BY GREG — 2026-10-15
PRODUCTION INSTALLATION: BLOCKED — PEOPLE_DIRECTUS_IDENTITY_TOKEN not configured
CREDENTIAL PERMISSION/PROVISIONING: SERVER MANAGEMENT #49 NOT YET ACCEPTED
MIGRATION 006: NOT APPLIED
PEOPLE V0.2.3 / APPS v0.2: NOT PUBLISHED TO PRODUCTION
NEXT: disposable scoped Directus service credential proof; governed installation
```

That isolated Apps+People browser integration gate has passed, **and Greg has explicitly approved Production**. Installation remains stopped by the proven missing credential and the incomplete governed credential/deployment procedures. The approval remains valid; no Production mutation or final real-user acceptance has been performed. Follow the Server Management #49 credential authority, the #37 maintenance controller and the Backbone publishing runbook for their distinct remaining gates.
