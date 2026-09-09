# People Manager Acceptance

People Manager has completed current-Production disposable acceptance, governed browser review, Production deployment, protected-route deployment, live browser verification, and GA4 verification.

Current status:

```text
current-Production disposable acceptance       PASS
pre-Production browser operator review          ACCEPTED
Production database/backend deployment          PASS
Production protected /people/ route             PASS
Cloudflare-authenticated live browser            PASS
Production GA4 page view                         PASS
Production intranet/index integration            NEXT — BACKBONE #16
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
