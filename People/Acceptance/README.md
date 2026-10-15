# People Manager Acceptance

People Manager has completed current-Production disposable acceptance, governed browser review, Production deployment, protected-route deployment, live browser verification, and GA4 verification.

Current status:

```text
People Manager original Production acceptance   PASS
Identity reconciliation V0.2.2 disposable        PASS
Identity reconciliation V0.2.2 Production        PASS
Identity bootstrap V0.2.3 disposable              PASS — #395
Identity bootstrap browser/application review     PASS — #395 / Backbone #24
Production protected /people/ route              PASS
Cloudflare-authenticated live browser             PASS
Production GA4 page view                          PASS
Production intranet/index integration             NEXT — BACKBONE #16
```

Current Production People/Identity release:

```text
version              V0.2.2
deployed main SHA    bb8dfa498c5b4bbecfc3693f68c4066c1e08242e
migration            People/Database/005_reconcile_directus_person_identity.sql
```

## Governing Runtime Authority

Disposable PostgreSQL orchestration:

```text
Gregovate/MSB-Server-Management
docs/server/PostgreSQL_Disposable_Acceptance_Standard.md
```

Browser review:

```text
Gregovate/MSB-Server-Management
docs/server/Pre_Production_Browser_Review_Runbook.md
```

Production deployment:

```text
Gregovate/MSB-Server-Management
docs/server/Production_Database_Change_Deployment_Runbook.md
docs/server/Protected_Flask_Application_Service_Deployment.md
docs/server/Synology_Protected_Application_Reverse_Proxy.md
```

## Disposable Acceptance — PASS

Accepted database/backend candidate:

```text
deaa9157282e59e8acd6a7da2a82fc9296e44f20
```

Server report:

```text
/tmp/MSB_People_Manager_Disposable_20260909-183640.txt
```

Production `ref.person` fingerprint before/after:

```text
47f494107952a84f30a406374b8d01d7
```

Accepted clone behavior includes:

- least-privilege People metadata boundary;
- person create + reserved MSB email;
- same-person deactivate/reactivate;
- capability catalog + person capability;
- formal qualification dates/evidence;
- Setup/Takedown participation and eligibility roles;
- existing reusable-task leadership visible but not directly writable by `people_app`;
- metadata actor/audit stamping; and
- no normal People delete function.

Durable evidence:

`People_Manager_Metadata_Disposable_Acceptance_Evidence_2026-09-09.md`

## Browser Review — ACCEPTED

Final accepted browser presentation candidate:

```text
4724185fe8cd8831a59c61ea40df61073abbb0c6
```

Disposition:

```text
ACCEPTED FOR PRODUCTION DEPLOYMENT GATE
```

Browser review covered the person/contact workflow plus capability, qualification, Setup/Takedown role, leadership visibility, duplicate/collision protections, protected identity behavior, and the final MSB-consistent UI treatment.

The final preview cleanup proved Production `ref.person` and the shared checkout were unchanged, FieldWiring remained healthy, and the preview port was removed.

Durable evidence:

`People_Manager_Browser_Review_Acceptance_2026-09-09.md`

## Production Acceptance — PASS

Production application target:

```text
54e1192309b96c9838676be51a0bfcdb3ac92e06
```

Production service/runtime:

```text
service             msb-people.service
version             V0.2.0
runtime account     fieldwiring
listener            192.168.5.9:8796
PostgreSQL role     people_app
public route        https://my.sheboyganlights.org/people/
```

Production deployment proved:

- `274` detached Production-runtime tests passed;
- validated rollback archive created before mutation;
- migrations 001-003 applied;
- `people_app` remained least privilege;
- no People metadata seed rows were created;
- Production `ref.person` fingerprint remained exactly `47f494107952a84f30a406374b8d01d7`;
- FieldWiring, Procedures, Setup, and People were healthy;
- missing Cloudflare identity returned HTTP 401;
- accepted Manager identity resolved authorized;
- UFW exposes `8796/tcp` only from Synology `192.168.5.4`;
- `/people/` rendered through the protected Synology route;
- reverse proxy did not inject identity;
- existing protected routes remained healthy; and
- the operator verified the real Cloudflare-authenticated People browser application.

Production rollback artifacts:

```text
/home/msbadmin/backups/postgres/msb-pre-people-manager-20260909T221415.dump
/root/msb-nginx-backups/user.conf.pre-people-20260909T173958
```

Durable evidence:

`People_Manager_Production_Acceptance_2026-09-09.md`

## Identity Reconciliation V0.2.2 — PASS

Issue #385 / PR #386 installed the durable exact-email self-reconciliation boundary for recurring Directus↔Person link failures.

Accepted runtime candidate:

```text
2c9a2937079f817dafd5119584aaffc77b51357d
```

Merged/deployed main:

```text
bb8dfa498c5b4bbecfc3693f68c4066c1e08242e
```

Migration:

```text
People/Database/005_reconcile_directus_person_identity.sql
blob 88442b8f4150513fd6af581e2ea90004c6f27658
```

Disposable current-Production acceptance proved exact safe self-reconciliation across protected actor paths, idempotence, role preservation, audit attribution, fail-closed mismatch/conflict behavior, and explicit rejection of tablet/device/service identities.

Production deployment completed successfully under the Server Management Issue #37 maintenance controller.

Rollback/evidence:

```text
/home/msbadmin/backups/postgres/msb-pre-people-identity-reconcile-20261013T183854.dump
/tmp/MSB_People_Identity_Reconcile_Production_Deploy_20261013T183854.txt
```

Durable acceptance:

`People_Identity_Reconciliation_Production_Acceptance_2026-10-13.md`

## Silent Human Identity Bootstrap V0.2.3 — DISPOSABLE PASS

Issue #395 candidate:

```text
dcc8f25f07a74e19ce3de3aae2d9d137b5411815
```

Governed current-Production disposable acceptance passed with a separate PostgreSQL clone and disposable Directus 11.17.1 runtime.

Production invariants remained unchanged:

```text
ref.person       4157a1c63a88bc900d566f6eb094f1c4 -> same
directus_users   3170a3a5b5860bed1c293f2ee6b50131 -> same
```

Retained report:

```text
/tmp/MSB_People_Identity_Bootstrap_Disposable_20261015T200047.txt
```

Durable evidence:

```text
People_Identity_Bootstrap_Disposable_Acceptance_2026-10-15.md
```

Greg's Production authorization is now recorded in the [#395 engineering acceptance](People_Identity_Bootstrap_Disposable_Acceptance_2026-10-15.md). The disposable Apps+People browser review passed. The next step is the guarded **read-only Production readiness probe**, followed by a separate reviewed migration-006/V0.2.3 deployment runner and controlled Backbone Apps publication. No migration is reported applied. Don Martens remains the preserved Production fixture and has not been consumed.

## #395 Production credential STOP and #49 scoped-permission proof

Greg authorized the #395 Production release after disposable acceptance and the Apps+People browser review passed. Production has **not** been migrated: the read-only credential gate returned `STOP: TOKEN_NOT_CONFIGURED` (exit 30) with both Production identity fingerprints unchanged and controller ONLINE. Exact evidence is in [People Identity Bootstrap disposable/browser acceptance](People_Identity_Bootstrap_Disposable_Acceptance_2026-10-15.md).

Existing Server Management [Issue #49](https://github.com/Gregovate/MSB-Server-Management/issues/49) owns the generic Directus service-credential provisioning/recovery contract; do not reuse the Work Order Intake service token or a human Administrator token. The accepted existing #395 disposable harness now has an **opt-in** `-ServiceScopeProbe` that tests a restricted, API-only Google/MSB Browser creation permission in the same disposable Directus 11.17.1 clone. The probe is source-staged, not yet operator-executed or accepted; it is not authorization for a Production credential.

```text
People/Acceptance/run_people_identity_bootstrap_disposable_acceptance.ps1 -ServiceScopeProbe
```

The wrapper requires the clean `issue-395-production-deployment-readiness` engineering branch and performs focused contract validation before server contact; the server tests only disposable service accounts/roles/policies and prints a compact `BEGIN #395 RESULT` footer with Production preservation results. After that proof, reconcile the separate Server Management credential installation/rollback procedure and the #37-governed migration 006 release runner. Do not rerun the earlier generic Production token preflight while its exact missing configuration remains unchanged.

## Google Analytics — PASS

```text
Measurement ID       G-X08ZTSY0VV
analytics version    2026-09-09.1
```

The operator verified `MSB People Manager` appeared in the MSB Internal Intranet GA4 property with a live page view.

The deployed analytics contract preserves:

```text
no person name/email/phone/person_id
no authenticated identity
no search text
Google Signals disabled
advertising personalization disabled
```

GA4 is aggregate application telemetry, not an audit trail.

## Synology Execution Finding

The first route transfer exposed a DSM compatibility detail: current Windows OpenSSH `scp` attempted SFTP, while the Synology administrative SSH service did not expose that subsystem. The wrapper was corrected to use legacy SCP (`scp -O`).

The next automated nested-SSH attempt then stalled at interactive `sudo -v`. It was terminated before the nginx configuration phase. The accepted route deployment was completed from the established normal PowerShell SSH session to `msbad@192.168.5.4 -p 22222`, using a bounded interactive-shell block.

Future Synology nginx changes that require interactive sudo should use the established interactive administrative SSH workflow rather than nesting the sudo-requiring deployment inside workstation SSH automation.

## Production Intranet / Index Handoff

The live People route is now known and accepted:

```text
https://my.sheboyganlights.org/people/
```

The source-owned handoff for adding it to the Production page is:

```text
Docs/02_Production_Database/01_System_Architecture/03_People_and_Identity/engineering/Internal_Web_Backbone_Handoff.md
```

Backbone issue:

```text
Gregovate/MSB-Internal-Web-Backbone#16
```

## Closeout Boundary

People application/runtime acceptance is complete. Remaining subsystem closeout is limited to:

1. Production intranet/index integration through Backbone #16;
2. live index link/version verification; and
3. return-handoff update marking the Backbone integration VERIFIED.
