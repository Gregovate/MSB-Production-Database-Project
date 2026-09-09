# People Manager Acceptance

People Manager has completed current-Production disposable acceptance and governed pre-Production browser review. The next gate is the separate explicit Production deployment process.

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
```

The files in this folder contain People-specific migrations/assertions, browser-review harness pieces, and retained evidence only. They do not replace Server Management runtime procedures.

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

The final cosmetic-only request added the blue left-edge panel brace/accent and stylesheet cache bump. The operator explicitly stated no additional browser test was required for that styling-only correction.

The final preview cleanup then proved:

```text
production ref.person fingerprint unchanged
production shared checkout unchanged
production FieldWiring service healthy
preview port removed
exit status 0
```

Durable evidence:

`People_Manager_Browser_Review_Acceptance_2026-09-09.md`

## Production Gate Requirements

A Production deployment is still a separate explicit mutation gate.

Before Production mutation, retrieve/read the current Server Management Production deployment runbook and follow its preflight, rollback, deployment, health, and post-acceptance sequence.

Production closeout must also verify the People application analytics contract under:

```text
System_Documentation/Project_Rules/Internal_Web_Analytics_Rule.md
```

Minimum People analytics acceptance after deployment:

```text
[ ] GA4 integration present
[ ] Measurement ID G-X08ZTSY0VV
[ ] direct People application page view verified in the MSB Internal Intranet GA4 property
[ ] useful anonymous workflow events considered/preserved
[ ] no PII, authenticated identity, search text, or Production record identifiers sent
[ ] Google Signals / advertising personalization disabled
[ ] deployed analytics asset/version identifiable
```

## Production Intranet / Index Handoff

The source-owned handoff for adding the live People application to the Production page is:

```text
Docs/02_Production_Database/01_System_Architecture/03_People_and_Identity/engineering/Internal_Web_Backbone_Handoff.md
```

Backbone integration must follow `Gregovate/MSB-Internal-Web-Backbone/System_Documentation/Project_Rules/Source_Subsystem_Handoff_Workflow.md` and must not guess the live People URL before Production deployment verifies it.

## Closeout Boundary

People engineering is accepted for Production deployment. Final subsystem closeout still requires:

1. Production deployment and live workflow verification;
2. GA4 verification;
3. Production intranet/index integration and live link verification; and
4. final Production/Backbone evidence updates.
