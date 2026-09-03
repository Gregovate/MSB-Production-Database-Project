# Controller Print Label Live Browser Acceptance Finding — 2026-09-01

| Item | Value |
|---|---|
| Status | DATABASE REQUEST PATH ACCEPTED — HUMAN-FACING ATTRIBUTION / PHYSICAL PRINT FOLLOW-UP |
| Issue | #110 |
| Production checkout | `e9ab029a17067b38b34f9306069f54899925f73f` |
| Controller used | `CTRL 1001` |
| Browser identity | `Greg Liebig · Administrator` |

## What the live browser proved

The protected production Controller browser resolved the Cloudflare-authenticated operator to the expected Controller authorization context and displayed:

```text
Greg Liebig · Administrator
```

On Controller `CTRL 1001`, the Administrator-authorized **Print Label** action was visible.

The operator clicked **Print Label**. The browser immediately changed to:

```text
Print Requested
Waiting for the label service to consume the request.
```

This proves the live protected browser POST reached the controlled PostgreSQL command path and set the production Controller label request state.

## Audit acceptance — person mapping confirmed

The initial browser success notice displayed:

```text
Label requested by msbadmin.
```

Subsequent Directus inspection of the same `ref.controller` row showed:

```text
Updated By Person ID -> Greg Liebig
```

This confirms the important audit contract succeeded: the Controller write resolved the authenticated operator through the Directus user/person mapping and stamped the real `ref.person` identity.

The remaining `msbadmin` text is therefore a **human-facing attribution/presentation defect**, not an audit-person failure. The browser currently renders the PostgreSQL text actor (`updated_by`) instead of the mapped person identity for the success notice.

Required UI correction:

- do not describe `updated_by = msbadmin` as the human requester;
- use the authenticated/mapped Controller operator display identity for human-facing request attribution;
- preserve the existing database audit fields and person FK behavior.

Do not change the shared `ref.resolve_actor()` mechanism to fix this text. Existing `ref.display` Directus edits already demonstrate that the shared person-aware audit system works correctly.

## Physical Controller printing is not yet an accepted path

Directus inspection of `CTRL 1001` also showed:

```text
Label Template ID -> unassigned
```

The current Labeling/Scanning architecture keeps logical profile/template assignment distinct from raw runtime `.lbx` paths. A Controller request without an effective Controller label profile/template is not a valid physical-print acceptance case.

Current `MSB_LabelPrintService` V4 draft work explicitly implements Display and Container routing/preflight. It does not yet establish an accepted Controller polling/snapshot/template/render path.

Therefore this accidental `CTRL 1001` request is classified as:

```text
browser authentication/authorization proof = PASS
database request command proof             = PASS
real mapped-person audit FK proof           = PASS
physical Controller print proof             = NOT TESTED / NOT YET IMPLEMENTED
```

The pending request must not later be mistaken for a printer failure. Before Controller physical printing is accepted, the Controller label profile/template and LabelPrintService Controller route must be implemented and tested through the established labeling subsystem.

## Acceptance status

Accepted:

- protected Cloudflare identity reaches Controller authorization;
- Administrator capability is visible in the live browser;
- Print Label action is exposed to the authorized account;
- live Print Label request reaches PostgreSQL;
- `Updated By Person ID` resolves to Greg Liebig through the existing audit/person mapping.

Open follow-up:

- change human-facing success attribution so it does not show `msbadmin` as the requester;
- clear/retire the accidental pending `CTRL 1001` request before a future Controller-capable print service could consume it;
- establish Controller logical label profile/template assignment;
- implement/accept Controller polling/snapshot/render support in LabelPrintService before physical printing is considered operational.
