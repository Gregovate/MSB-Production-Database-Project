# Setup #172 Report Correction Production Acceptance — 2026-09-27

| Document Control | Value |
|---|---|
| Document Type | Production Acceptance Record |
| System | Production Database — Setup Session / Work Order Intake |
| Issues | #172, #122 |
| Pull Request | #236 |
| Status | ACCEPTED / PRODUCTION |
| Owner | MSB Production Database / Setup |
| Accepted Date | 2026-09-27 |

## Accepted Production Target

```text
application SHA = fc0b76d57826eebf04b81c99cbb904109162cd87
version         = V0.3.19-pick-list
migration       = Setup/Database/062_add_setup_context_work_order_intake.sql
migration blob  = c8a98d653de4797c30050397f07d8b0cbd5141c5
PR              = #236
PR merge commit = 827fa746fafd2a2e62bd191d3f28765360a64c14
```

Production intentionally runs the exact browser-accepted application SHA rather than the later PR merge or closeout/tooling commits.

## Capability Accepted

The live Setup application now supports the field-correction path from a real scheduled assignment:

```text
Production Crew / Manager
  -> Perform Work
  -> Report Correction
       What did you find?
       Suggested correction / evidence (optional)
  -> PostgreSQL prepares authoritative Setup context
       annual task / reusable task when applicable
       exact scheduled assignment
       Setup Day / work date / shift / Crew / Captain
       Stage / Scene
       current Procedure identity when available
       authenticated reporter / timestamp
  -> protected Setup backend
  -> Directus Items API
  -> Work Order Intake
  -> existing items.create Flow
  -> Manager triage email
  -> Manager disposition
```

Report Correction does **not** create an active Work Order directly and does not grant Production Crew Manager-level durable-data authority.

## Work Order Intake / Notification Boundary

Migration 062 installs:

`ops.prepare_setup_work_order_intake(text,bigint,bigint,text,text,jsonb)`

The function authenticates/authorizes the reporter and prepares authoritative Setup context. It does not insert the Intake row.

The protected Setup backend creates the Intake through the existing Directus Items API so the active `WOI Request Triage Email` Flow continues to fire from the existing `items.create` event on `work_order_intake`.

`fieldwiring_app` has narrow EXECUTE on the preparation command and does not have direct `stage.work_order_intake` INSERT authority.

## Runtime Directus Authentication

The Production Setup service uses runtime-only configuration:

`SETUP_DIRECTUS_INTAKE_TOKEN`

The credential is stored outside Git in the protected Setup environment file. No token value is present in this repository or acceptance record.

Production reconnaissance confirmed an existing Directus service identity dedicated to Work Order Intake. The Setup runtime reuses that existing authenticated Work Order Intake service identity for this call rather than using a human Administrator credential.

The local Setup-to-Directus request uses the existing local Directus listener and does not require Cloudflare service-token headers.

The generic Directus service-credential provisioning/recovery procedure remains separate Server Management work; #172 did not rotate, revoke, or replace existing credentials.

## Engineering Acceptance

Exact candidate:

`fc0b76d57826eebf04b81c99cbb904109162cd87`

Full Setup/Application regression:

`544 passed`

Reusable current-Production-clone disposable acceptance:

`SETUP REUSABLE DISPOSABLE ACCEPTANCE: CLEAN EXIT`

Exact-candidate browser review:

`PASS`

Disposable browser teardown:

`SETUP REUSABLE DISPOSABLE BROWSER PREVIEW: CLEAN EXIT`

Browser acceptance confirmed both Report Correction actions use the Work Order yellow CTA, the form preserves the intended low-friction field workflow, and Report Work remains normal.

## Production Deployment

Deployment authority:

`Gregovate/MSB-Server-Management — docs/server/Production_Database_Change_Deployment_Runbook.md`

Versioned deployment wrapper:

`Setup/Acceptance/run_setup_172_production_deploy.ps1`

Successful deployment-tooling commit:

`d8524bedc943822b9186fca93007de4285aae545`

The first Production deployment attempt reached the candidate and migration, then stopped at a deployment-harness negative-path assertion. Fail-closed recovery restored the prior application SHA and removed migration 062 successfully. The defect was in deployment tooling, not in the accepted application candidate.

The corrected wrapper then completed successfully:

```text
SETUP_172_REPORT_CORRECTION_PRODUCTION_DEPLOYMENT_PASS
Exit status: 0
```

Final Production evidence:

```text
Final Setup SHA:
fc0b76d57826eebf04b81c99cbb904109162cd87

Frozen Setup fingerprint:
a779cc9f77adde416a0b8a78f40e9b70

Final Setup fingerprint:
a779cc9f77adde416a0b8a78f40e9b70
```

The governed Setup fingerprint was unchanged across deployment.

Rollback archive:

`/home/msbadmin/backups/setup-172/msb-pre-setup-172-20260928T005954.dump`

Rollback SHA256:

`fe0d349a587ec0363cb69bb295618c49ab8df771ff9bcb8bf9c0e71c66b8b89a`

Deployment report:

`/home/msbadmin/setup-deployment-reports/Setup_172_Report_Correction_Production_Deploy_20260928T005954.txt`

## Real Protected-Route Production Validation

A legitimate Production Report Correction was submitted from a real scheduled Setup assignment.

Created Intake:

`Work Order Intake #60`

Observed Intake state included:

- source form `SETUP_CORRECTION`;
- authenticated submitter;
- field finding;
- automatically captured Setup provenance/context;
- Setup field-correction task type;
- resolved Stage;
- target year 2026; and
- `Submitted` triage state.

The existing Directus `WOI Request Triage Email` Flow fired successfully for Intake #60 and delivered the normal Manager triage notification.

This proves the full live path:

`Report Correction -> Work Order Intake -> Directus items.create Flow -> Manager triage email`

## Closeout

- #172 Report Correction / field-observation intake: Production accepted.
- Existing Work Order Intake / Manager triage lifecycle remains authoritative.
- No automatic active Work Order creation was introduced.
- #122 remains the commanding Setup integration issue.
- Server Management owns the independent follow-up to formalize the reusable Directus service-credential provisioning/recovery procedure.
