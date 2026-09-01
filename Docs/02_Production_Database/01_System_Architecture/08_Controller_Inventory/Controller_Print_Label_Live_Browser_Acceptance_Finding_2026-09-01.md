# Controller Print Label Live Browser Acceptance Finding — 2026-09-01

| Item | Value |
|---|---|
| Status | OPEN ACCEPTANCE FINDING — REQUEST PATH WORKS; AUDIT TEXT REQUIRES VERIFICATION |
| Issue | #110 |
| Production checkout | `e9ab029a17067b38b34f9306069f54899925f73f` |
| Controller used | `CTRL 1001` |
| Browser identity | `Greg Liebig · Administrator` |

## What the live browser proved

The protected production Controller browser resolved the Cloudflare-authenticated operator to the expected Controller authorization context and displayed:

```text
Greg Liebig · Administrator
```

On Controller `CTRL 1001`, the Administrator-only/authorized **Print Label** action was visible.

The operator clicked **Print Label**. The browser immediately changed to:

```text
Print Requested
Waiting for the label service to consume the request.
```

This proves the live protected browser POST reached the controlled PostgreSQL command path and left the Controller label request pending in production.

Physical printing is a separate downstream step owned by the label polling/print service. It is not yet confirmed merely by the pending browser state.

Remote confirmation of downstream consumption is possible without being physically at the printer: after refresh, successful service consumption should be reflected by the existing label-state fields, including the request flag clearing and the cached print count / last-printed timestamp changing according to the label-service contract.

## Audit acceptance finding

The live success notice displayed:

```text
Label requested by msbadmin.
```

That text comes from the `updated_by` value returned by `ref.request_controller_label(text,bigint)` and rendered by `controllers_detail_extras.js`.

This is **not sufficient to declare the audit-actor acceptance complete**. The intended contract is that a Cloudflare-authenticated Controller write resolves through the Directus user to the mapped `ref.person` identity.

The disposable acceptance did verify that `updated_by_person_id` matched the selected mapped person, but its text assertion only rejected `fieldwiring_app`; it did not require `updated_by` to equal the mapped person's preferred name. Therefore an `updated_by='msbadmin'` result could pass that prior harness while still exposing an operator-facing attribution mismatch.

Before closing browser-write actor acceptance, production must verify the stored fields for the live `CTRL 1001` request together:

```text
updated_by
updated_by_person_id
mapped ref.person identity
```

Do not paper over this by changing only the browser notice. If `updated_by_person_id` is correct and only text semantics differ, document/fix the intended display/audit contract deliberately. If the person ID is wrong, fix the write/audit path before implementing broader Controller edits.

## Acceptance status

Accepted:

- protected Cloudflare identity reaches Controller authorization;
- Administrator capability is visible in the live browser;
- Print Label action is exposed to the authorized account;
- live Print Label request reaches PostgreSQL and becomes pending.

Still pending:

- label polling/print service consumption of this specific request;
- exact production audit-person verification for the live request;
- resolution of the `Label requested by msbadmin` attribution before broader Controller write operations are considered fully accepted.
