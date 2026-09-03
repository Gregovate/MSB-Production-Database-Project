# Controller Scan Production Deployment Acceptance — 2026-09-03

| Document control | Value |
|---|---|
| Status | PRODUCTION DEPLOYED — manual input accepted; physical-label/device acceptance pending |
| Issue | #113 |
| Merged PR | #116 |
| Production host | `msb-prod-db` / `192.168.5.9` |
| Previous shared checkout | `63be47f40be78f608416935ed0583287da9d90e6` |
| Deployed shared checkout | `72f5b7164f31753a33e5c2a9d83d9a7a6909a417` |
| Previous Scan SHA-256 | `fb2a98088e363430fb0a303e4c895bae8202f4f253ac22a1481a406eb5b7443a` |
| Deployed Scan SHA-256 | `3457efa15f461b774ef20462f57807d36cb848cac67bdcffcc2a8284c2dc2f96` |
| Immediate Scan rollback | `/home/msbadmin/backups/directus-scan/pre-ctrl-20260903T112856Z/index.js` |
| Deployment report | `/tmp/MSB_Scan_CTRL_Production_Deploy_20260903T112856Z.txt` |

## Purpose

Record the controlled production deployment and current acceptance boundary for the `CTRL` Scan route and its handoff to the existing Controller Inventory application.

## Accepted production behavior

The deployed route is:

```text
/scan/CTRL/<controller_id>
    -> https://my.sheboyganlights.org/fieldwiring/controllers?controller_id=<controller_id>
```

Controller Inventory uses `controller_id` to:

- populate the existing Search field;
- filter the Controller list to the exact permanent Controller;
- open that Controller's existing detail panel; and
- preserve the existing Controller information, Display-assignment context, and actions.

Scan does not duplicate Controller data, query a second Controller identity, or own Controller maintenance and label-request actions.

## Pre-production evidence

The deployment gate established:

- the live checkout was clean at `63be47f40be78f608416935ed0583287da9d90e6`;
- the accepted target existed and the live checkout was its ancestor;
- the live Scan hash matched the previously accepted baseline;
- the exact detached candidate passed 256 FieldWiring and Procedures tests;
- `src/index.js` and `dist/index.js` were identical;
- the staged Scan candidate passed JavaScript syntax validation;
- the disposable production-clone browser opened CTRL 1014 with Search set to `1014`, exactly one result shown, and the detail panel open; and
- the production Controller fingerprint was unchanged before and after the disposable preview.

## Production deployment result

The bounded production deployment completed with exit status `0`:

```text
CTRL SCAN DEPLOYMENT: PASS
old checkout: 63be47f40be78f608416935ed0583287da9d90e6
new checkout: 72f5b7164f31753a33e5c2a9d83d9a7a6909a417
new Scan hash: 3457efa15f461b774ef20462f57807d36cb848cac67bdcffcc2a8284c2dc2f96
```

The deployment runner verified the shared services, live regression suite, existing Scan landing/Display/Container routes, the exact CTRL redirect, invalid CTRL rejection, final checkout, and deployed artifact hash.

The immediately preceding Scan artifact is retained at:

```text
/home/msbadmin/backups/directus-scan/pre-ctrl-20260903T112856Z/index.js
```

## Operator input acceptance

The following inputs were pasted into the production Scan window and both opened CTRL 1014 correctly:

```text
https://db.sheboyganlights.org/scan/CTRL/1014
CTRL:1014
```

Accepted:

| Input path | Result |
|---|---|
| Manual full Scan URL | PASS |
| Manual compact canonical value | PASS |
| Exact Controller Inventory Search/detail result | PASS |

## Explicitly pending physical acceptance

No physical Controller label could be printed during this acceptance because Controller polling/printing was not yet available in the separate LabelPrintService workstream.

Do not report the following as passed yet:

- physical Controller label output;
- Zebra scan of the printed Controller label through the production Scan application;
- Android or iPhone camera decode of the printed Controller label;
- automatic Enter/submission from the final Zebra Controller ADF rule; or
- useful physical scan distance for the final label design.

The Zebra ADF had independently produced the expected compact value in Google Docs earlier on 2026-09-03. That is valid input-format evidence, but it is not a substitute for the pending printed-label end-to-end test.

## Resume point

After LabelPrintService produces the first Controller label:

1. confirm its QR contains `https://db.sheboyganlights.org/scan/CTRL/<controller_id>`;
2. scan the physical label with Zebra and verify the Scan application receives `CTRL:<controller_id>` and submits it;
3. scan the same physical label with the relevant phone/tablet cameras;
4. verify every path opens the exact Controller Inventory result; and
5. record practical scan distance and complete the physical-label gate before volume printing.

`LOC` route/resolution and Setup movement semantics remain separate work under #88.

## Related documents

- [Labeling and Scanning](README.md)
- [Deployed Display Scan Runtime Boundary](Deployed_Display_Scan_Runtime_Boundary.md)
- [Asset Identity and Scan Payload Standard](Asset_Identity_and_Scan_Payload_Standard.md)
- [Setup-Season Scan Integration Handoff](Setup_Season_Scan_Integration_Handoff_2026-09-02.md)
- [Controller Inventory](../08_Controller_Inventory/README.md)
- [MSB Server Management — Display Scan Extension Deployment and Recovery](https://github.com/Gregovate/MSB-Server-Management/blob/main/docs/directus/Display_Scan_Extension_Deployment_and_Recovery.md)
