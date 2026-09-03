# Controller Management Authentication / Authorization Contract — 2026-08-31

| Item | Value |
|---|---|
| Status | CURRENT ACCEPTED AUTH/AUTHZ CONTRACT |
| Issue | #110 |
| Public Controller application | `https://my.sheboyganlights.org/fieldwiring/` |
| Authentication authority | Cloudflare Access on `my.sheboyganlights.org` |
| Authenticated identity | `Cf-Access-Authenticated-User-Email` |
| Authorization authority | Existing Directus user / role / policy data |
| Controller operational UX | Purpose-built FieldWiring / Controller Inventory browser |

## Purpose

Define the exact authentication and authorization boundary for browser-native Controller Management so implementation does not re-probe or re-invent the login/session design.

## Accepted Authentication Rule

A user who reaches the protected `my.sheboyganlights.org` application has already authenticated through Cloudflare Access. The Controller browser does **not** redirect the user to Directus and does **not** create a second login/session flow.

MSB already has an established production pattern in `LOR2DB/Application/backend.py` for consuming the Cloudflare Access identity:

```text
Cf-Access-Authenticated-User-Email
```

Controller Management must reuse that same identity pattern behind the protected proxy boundary.

Conceptually:

```text
Browser
    -> Cloudflare Access authenticates user
    -> my.sheboyganlights.org/fieldwiring/
    -> Cf-Access-Authenticated-User-Email
    -> Controller backend resolves MSB authorization
```

No cross-origin Directus cookie/session sharing between `my.sheboyganlights.org` and `db.sheboyganlights.org` is required for Controller Management.

## Directus Role

Directus remains the existing MSB user / role / policy authority. It does not perform a second authentication step for the Controller browser.

The Controller backend uses the Cloudflare-authenticated email to determine the corresponding active Directus user and effective role/policy authorization.

Current relevant authorization groups include:

```text
Production Crew -> Volunteer policy
Manager         -> Manager policy
Administrator   -> Administrator policy and/or Manager access
MSB Browser     -> Read Only - MSB Core
```

Exact authorization must be evaluated server-side from governed current data rather than from client-supplied role names.

## Controller Capability Matrix

### Read-only browsing

Authenticated MSB users who already have access to the protected production application may continue to use the existing read-only Controller Inventory / FieldWiring experience according to current application access policy.

### Print Label

Controller label requests are an operational production action, not Controller administration.

The following may request a Controller label:

```text
Production Crew
Manager
Administrator
```

The browser action uses the existing Controller label contract by requesting:

```text
ref.controller.print_label = true
```

The Controller application does not create a second print queue or print-service architecture. The separate label polling service consumes the established label-request state.

### Controller maintenance

The following may perform Controller maintenance:

```text
Manager
Administrator
```

Manager/Admin capabilities include:

- Add Controller;
- Edit Controller;
- maintain model/status/location/firmware/verification fields;
- maintain current programmed Network / UID / management IP configuration;
- assign Controller to Display;
- reassign/move Controller-to-Display relationships;
- unassign Controller-to-Display relationships without deleting the Controller;
- maintain reviewed `wiring_source_display_id` when required;
- request Controller labels.

Ordinary Production Crew users do not receive these Controller-data maintenance capabilities merely because they may request labels.

## UI Rule

The Controller detail view should expose controls according to resolved server-side capability, conceptually:

```text
[ Print Label ]                              Production Crew + Manager + Administrator

[ Edit Controller ] [ Manage Assignments ]  Manager + Administrator
[ Add Controller ]                          Manager + Administrator
```

The presence or absence of a button is only presentation. It is not the security boundary.

## Server-Side Enforcement Rule

Every state-changing request must independently:

1. obtain the Cloudflare Access authenticated email from the trusted request header;
2. resolve the current active MSB/Directus user and effective authorization;
3. verify the specific capability required for the requested action;
4. reject unauthorized requests server-side;
5. execute only the narrow approved database operation;
6. preserve the real operator identity in PostgreSQL audit fields.

Never trust an email, role, policy, or capability supplied by browser JavaScript or form data.

## PostgreSQL Write Boundary

The existing `fieldwiring_app` role remains a read-only table-access role. Browser editing must not be implemented by granting broad INSERT/UPDATE/DELETE privileges on `ref.controller*` to `fieldwiring_app`.

Preferred implementation direction is narrow database commands / `SECURITY DEFINER` functions or procedures with explicit `EXECUTE` grants. Those commands should perform authorization/audit-sensitive writes while the calling application role retains no broad table DML.

Conceptually:

```text
fieldwiring_app
    -> SELECT existing read model
    -> EXECUTE narrow Controller command
        -> PostgreSQL validates inputs
        -> PostgreSQL records operator/audit identity
        -> controlled production write
```

Candidate command boundaries include:

- resolve Controller capabilities for authenticated email;
- request Controller label;
- create Controller;
- update Controller;
- assign Controller-to-Display;
- update Controller-to-Display relationship detail;
- unassign Controller-to-Display.

No normal Controller DELETE command is authorized.

## Audit Actor Handoff — recovered 2026-08-31

The existing production Controller tables already use the standard MSB audit triggers:

```text
ref.controller
    -> ref.set_actor_on_insert()
    -> ref.set_actor_on_update()

ref.controller_display
    -> ref.set_actor_on_insert()
    -> ref.set_actor_on_update()

ref.controller_firmware_history
    -> ref.set_actor_on_insert()
    -> ref.set_actor_on_update()
```

The unchanged standard `ref.resolve_actor()` function first reads the transaction/session setting:

```text
app.directus_user_uuid
```

When that UUID maps to `ref.person.directus_user_id`, the standard trigger path stamps the real MSB person. Only when no Directus UUID/person mapping is available does `resolve_actor()` fall back to the PostgreSQL login.

Therefore browser Controller write commands must not allow the service-account fallback for human operations. The accepted handoff is:

```text
Cloudflare authenticated email
    -> active Directus user
    -> current Directus role/policy authorization
    -> require matching ref.person.directus_user_id
    -> SET LOCAL app.directus_user_uuid = <resolved Directus UUID>
    -> narrow Controller write
    -> existing audit trigger
    -> ref.resolve_actor()
    -> real person_id / preferred actor name
```

A human Controller write fails closed if the authenticated Directus user is not mapped to `ref.person`.

The first implementation of this pattern is `ref.request_controller_label(text,bigint)` in `Controllers/Database/022_create_controller_label_request_command.sql`. It is deliberately idempotent while `print_label` is already true and grants `fieldwiring_app` `EXECUTE` only, not direct table `UPDATE`.

## Cloudflare Trust Boundary

The Cloudflare identity header is trusted only because the application is deployed behind the protected `my.sheboyganlights.org` proxy/access boundary. Direct access to the internal FieldWiring listener must remain restricted to the documented Synology/protected runtime path so an untrusted client cannot inject the identity header.

This follows the already-established MSB LOR2DB pattern and must be preserved in deployment and firewall/proxy configuration.

## Rule Established

> Cloudflare Access authenticates the Controller browser user at `my.sheboyganlights.org`. The Controller backend consumes `Cf-Access-Authenticated-User-Email` as the known authenticated identity, resolves current authorization from the existing Directus user/role/policy authority, permits Controller label requests to Production Crew/Manager/Administrator, permits Controller maintenance only to Manager/Administrator, rechecks authorization server-side on every write, passes the resolved Directus UUID through `app.directus_user_uuid` so the existing audit triggers resolve the real `ref.person`, and keeps `fieldwiring_app` free of broad production-table write privileges.
