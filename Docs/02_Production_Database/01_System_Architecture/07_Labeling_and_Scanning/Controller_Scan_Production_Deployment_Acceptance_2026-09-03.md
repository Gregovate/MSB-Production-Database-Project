# Controller Scan Production Deployment Acceptance — 2026-09-03

| Document control | Value |
|---|---|
| Status | PRODUCTION DEPLOYED — manual and physical Controller scan paths accepted; tablet HID focus repair pending |
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

## Physical Controller-label acceptance

A production label for Controller `1031` was printed and tested on 2026-09-03.

| Input path | Result |
|---|---|
| Phone camera decoded `https://db.sheboyganlights.org/scan/CTRL/1031` | PASS |
| Full QR URL opened Controller 1031 | PASS |
| Zebra DS3678-ER decoded the same label as `CTRL:1031` | PASS |
| Zebra ADF Enter submitted the compact identifier | PASS |
| Controller Inventory opened Controller 1031 | PASS |

The exact phone operating system and practical scan distance were not recorded in this pass. Do not convert this result into separate Android and iPhone acceptance claims until those devices are identified or independently tested.

## Tablet HID focus defect

The tablet Scan page did not place the cursor in **Scan code or paste URL** when the page opened. The operator had to tap the field before using the Zebra. After the field was selected, the Zebra compact identifier and Enter submission worked correctly.

This is a Scan landing-page input-focus defect. It is not a Controller label, QR payload, route, Controller Inventory, or Zebra ADF defect.

The focused repair under #113 must:

- actively focus the entry field when Scan opens or becomes active;
- retain the first HID character even if the mobile browser ignores initial autofocus;
- restore focus after a cancelled or failed camera attempt;
- avoid hijacking deliberate input in another editable control; and
- be physically retested on the production tablet without first tapping the field.

## Resume point

After the input-focus repair is deployed:

1. open Scan from the normal protected launcher without tapping the entry field;
2. scan the physical Controller label with the Zebra and verify the first character, complete `CTRL:<controller_id>` value, and Enter submission are all retained;
3. verify the exact Controller Inventory result opens;
4. return to Scan and repeat the test to cover browser page restoration;
5. confirm the focus behavior does not force an unwanted on-screen keyboard or interfere with camera/manual input; and
6. record the tested phone/tablet operating systems and practical scan distance.

`LOC` route/resolution and Setup movement semantics remain separate work under #88.

## Related documents

- [Labeling and Scanning](README.md)
- [Deployed Display Scan Runtime Boundary](Deployed_Display_Scan_Runtime_Boundary.md)
- [Asset Identity and Scan Payload Standard](Asset_Identity_and_Scan_Payload_Standard.md)
- [Setup-Season Scan Integration Handoff](Setup_Season_Scan_Integration_Handoff_2026-09-02.md)
- [Controller Inventory](../08_Controller_Inventory/README.md)
- [MSB Server Management — Display Scan Extension Deployment and Recovery](https://github.com/Gregovate/MSB-Server-Management/blob/main/docs/directus/Display_Scan_Extension_Deployment_and_Recovery.md)
