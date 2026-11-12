# Controller V0.4.0 Production Deployment Acceptance — 2026-09-03

| Item | Value |
|---|---|
| Status | PRODUCTION DEPLOYMENT ACCEPTED |
| Issue | #110 |
| Draft PR | #111 |
| Production host | `msb-prod-db` / `192.168.5.9` |
| Old checkout | `e9ab029a17067b38b34f9306069f54899925f73f` |
| Deployed checkout | `63be47f40be78f608416935ed0583287da9d90e6` |
| FieldWiring | `V0.4.0 / postgres / healthy` |
| Procedures | `V0.1.0 / postgres / healthy` |
| Controller fingerprint | `578217bcb18e1291ceced673a3de3b27` unchanged |

## Purpose

Record the governed production deployment acceptance for Controller Inventory V0.4.0 after disposable/current-production-clone proof, operator browser acceptance, explicit production deployment approval, and bounded production deployment.

This is the durable production checkpoint for the Controller planning, browser-native maintenance, assignment-management, and contextual-help slice.

## Accepted application candidate

The exact operator-reviewed and deployed application commit is:

```text
63be47f40be78f608416935ed0583287da9d90e6
```

The production deployment wrapper/harness was later repinned to that already-accepted application SHA. Harness/document commits after this SHA are not part of the deployed application checkout unless separately deployed later.

## Production deployment result

The bounded production runner completed successfully:

```text
CONTROLLER SETUP + MANAGEMENT PRODUCTION DEPLOYMENT: PASS
CONTROLLER SETUP + MANAGEMENT PRODUCTION WRAPPER: PASS
Exit status: 0
```

Production checkout transition:

```text
old: e9ab029a17067b38b34f9306069f54899925f73f
new: 63be47f40be78f608416935ed0583287da9d90e6
```

Health after deployment:

```json
FieldWiring: {"data_mode":"postgres","status":"ok","version":"V0.4.0"}
Procedures:  {"data_mode":"postgres","status":"ok","version":"V0.1.0"}
```

## Database migrations installed

This deployment installed the accepted Controller management command boundary:

```text
Controllers/Database/023_create_controller_management_commands.sql
Controllers/Database/024_harden_controller_assignment_capability.sql
```

These migrations provide the browser-native Add/Edit/Assignment command functions through narrow PostgreSQL `SECURITY DEFINER` commands while preserving the rule that `fieldwiring_app` does not receive broad direct DML on `ref.controller*`.

The already-deployed browser authorization and Print Label commands remain in place:

```text
ref.controller_browser_capabilities(text)
ref.request_controller_label(text, bigint)
```

## Governed-data invariant

The Controller governed-data fingerprint was identical before and after deployment:

```text
Before: 578217bcb18e1291ceced673a3de3b27
After:  578217bcb18e1291ceced673a3de3b27
```

Result:

```text
PASS: production Controller fingerprint unchanged
```

This proves the deployment installed the command/application layer without silently rewriting the existing Controller inventory, assignments, or firmware-history state.

## Rollback evidence

Validated rollback PostgreSQL archive retained on `msb-prod-db`:

```text
/home/msbadmin/backups/postgres/msb-pre-controller-setup-management-20260903T044324.dump
```

SHA256:

```text
702bcb71c776a1495fecef3e73ec39a35d75049e21b0c02f54a7ed2b65311a23
```

Deployment report retained at:

```text
/tmp/MSB_Controller_Setup_Management_Production_Deploy_20260903T044324.txt
```

The immediate application rollback checkout is the prior live production commit:

```text
e9ab029a17067b38b34f9306069f54899925f73f
```

## Operator-visible scope accepted for V0.4.0

The exact candidate was accepted in the disposable current-production-clone browser preview before deployment.

Accepted for this version:

- Controller planning screens;
- Add Controller;
- Edit Controller;
- Controller-to-Display assignment-management presentation and workflow;
- current programmed Network / UID / IP maintenance;
- firmware/status/location/serial/hardware maintenance;
- `Physically Attached to Display` wording distinct from logical assignment state;
- contextual `?` help for non-obvious fields;
- unsaved-change protection;
- duplicate Add Controller action correction;
- Print Label visual treatment distinct from the primary Save action;
- human-facing label-request attribution using the mapped operator identity.

The grouped maintenance form is the accepted editing paradigm for this version.

## Authentication / authorization boundary

Production Controller browser authentication/authorization remains:

```text
Cloudflare Access
    -> authenticates protected browser identity
    -> Controller backend obtains trusted authenticated email
    -> Directus user / role / policy data supplies authorization
    -> server checks capability on every write
    -> narrow PostgreSQL command executes
    -> PostgreSQL constraints / audit remain final authority
```

There is no required Directus login redirect or cross-origin Directus browser-session bridge.

Capability intent remains:

```text
Production Crew           browse + Print Label
Manager                   browse + Print Label + Controller management
Administrator             browse + Print Label + Controller management
MSB Browser / Read Only   browse only
```

Lower-role browser acceptance remains a separate follow-up verification item.

## Not completed by this deployment

V0.4.0 production deployment does **not** close the following separate workstreams:

1. offline/printable Controller reports for firmware verification, Stage/Display lists, and exception/verification work;
2. physical Controller label printing in the external LabelPrintService, including Controller template/profile/routing support;
3. cleanup of the accidental pending CTRL 1001 print request before Controller physical print routing becomes active;
4. final Production Crew / Read Only browser capability acceptance;
5. final plain-English operator procedures based on the accepted production screens;
6. final PR #111 reconciliation/merge preparation.

PR #111 remains draft. This production deployment does not authorize or perform a merge to `main`.

## Governing runtime procedure

Production deployment followed the reusable server authority in:

`Gregovate/MSB-Server-Management/docs/server/Production_Database_Change_Deployment_Runbook.md`

Future Controller production mutations must continue to use that runbook rather than rediscovering SSH, rollback, PostgreSQL archive, checkout, service, or invariant mechanics in feature work.
