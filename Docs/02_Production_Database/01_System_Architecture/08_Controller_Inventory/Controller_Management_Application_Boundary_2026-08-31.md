# Controller Management Application Boundary — 2026-08-31

| Item | Value |
|---|---|
| Status | ACTIVE ARCHITECTURE DECISION — CURRENT RESUME AUTHORITY |
| Issue | #110 |
| Primary Controller UX | Purpose-built Controller application |
| Authentication authority | Cloudflare Access on `my.sheboyganlights.org` |
| Authenticated identity | `Cf-Access-Authenticated-User-Email` |
| Authorization authority | Existing Directus user / role / policy data |
| Secondary Directus use | Simple table/reference maintenance only |
| Controller delete policy | No normal Controller delete |

## Decision

Controller Management uses the same protected-site authentication boundary already established for MSB browser applications:

```text
Cloudflare Access
  = authentication / known user identity

Directus
  = existing user / role / policy authorization data

Purpose-built MSB applications
  = operational user experience and workflow

PostgreSQL
  = data integrity, audit, constraints, narrow write commands, and final authority
```

A Controller user does **not** log into Directus again, and the Controller application does **not** depend on cross-origin Directus cookies or a Directus browser session. Once Cloudflare Access has authenticated the user at `my.sheboyganlights.org`, the protected backend receives the authenticated email and resolves current authorization from the existing Directus user/role/policy model.

The detailed authentication/authorization contract is controlled in [Controller Management Authentication / Authorization Contract — 2026-08-31](Controller_Management_Authentication_Authorization_Contract_2026-08-31.md).

Directus may still be used for relatively simple maintenance tasks where the operator is editing one table at a time. That is a secondary convenience, not the Controller operational workflow.

## Current Accepted Implementation State

The production Controller/FieldWiring read experience is operational.

Accepted production checkpoint before browser write work:

```text
checkout                    84d6f06e16c43ebb0f6aa21273b999af7f6d455b
FieldWiring health/version  V0.3.1 / postgres / ok
Procedures health/version   V0.1.0 / postgres / ok
combined live regression    183 passed in 2.39s
```

The read experience includes permanent Controller browse/detail, Stage/Sub-stage-aware search, programmed Network/UID/IP presentation, current Display assignments, firmware history, label state, and Controller/FieldWiring cross-links.

### Browser write implementation checkpoint — not yet production deployed

Candidate `99728122e982eb2e77268cf1bb5aee682aaa4c62` establishes the first narrow write slice:

- Cloudflare-authenticated email is consumed by the backend;
- `ref.controller_browser_capabilities(text)` resolves current Directus-backed capabilities without granting `fieldwiring_app` direct access to Directus system tables;
- `ref.request_controller_label(text,bigint)` is a narrow `SECURITY DEFINER` command;
- `fieldwiring_app` retains no direct `UPDATE` on `ref.controller`;
- the command resolves the active Directus UUID and sets transaction-local `app.directus_user_uuid` so the existing `ref.set_actor_on_update()` -> `ref.resolve_actor()` audit path records the mapped MSB person;
- the browser sends no email, role, policy, or capability value supplied by JavaScript;
- `Print Label` is POST-only and server-authorized.

Application regression for this candidate passed on 2026-08-31:

```text
focused Controller auth/write contracts   9 passed in 0.86s
FieldWiring full regression               144 passed in 4.48s
Procedures full regression                 54 passed in 1.23s
combined application regression           198 passed
```

These results are an application gate only. Database migrations `021_create_controller_browser_authorization_contract.sql` and `022_create_controller_label_request_command.sql` have **not** yet been applied to production. Current-production disposable PostgreSQL acceptance is the next gate.

## Directus Controller relationship experiment — closed

Live testing proved that Directus is not a suitable operational editor for the Controller multi-table workflow. The attempted reverse relationship workspaces became brittle around the legitimate composite Controller/Display key and caused the Directus Controller detail page to fail.

Accepted cleanup remains:

- Directus `display_assignments` reverse workspace removed;
- Directus `firmware_history` reverse workspace removed;
- temporary Directus assignment DELETE capability removed;
- `ref.controller_display` retained its valid composite primary key `(controller_id, display_id)`;
- permanent relationship/history data were preserved;
- cleanup validation returned `DIRECTUS CONTROLLER SIMPLIFICATION: PASS`;
- Directus restarted healthy and Controller item detail no longer crashes.

Do **not** resume attempts to make Directus the Controller operational editor.

## Authentication / authorization boundary

Accepted request flow:

```text
Browser
    -> Cloudflare Access authenticates the user
    -> protected my.sheboyganlights.org/fieldwiring/ proxy path
    -> backend receives Cf-Access-Authenticated-User-Email
    -> backend / PostgreSQL resolves active Directus user + role/policy capability
    -> capability-specific controls are presented
    -> every state-changing request rechecks identity and authorization server-side
    -> narrow PostgreSQL command performs the approved write
    -> existing PostgreSQL audit/constraints remain final authority
```

The client-visible button is never the security boundary. A hidden or visible button does not grant permission.

Do not grant broad write privileges to `fieldwiring_app` merely to enable browser editing.

## Capability boundary

Current accepted Controller capabilities are:

```text
Authenticated production user  -> browse according to existing protected-app access
Production Crew                 -> browse + Print Label
Manager                         -> browse + Print Label + Controller management
Administrator                   -> browse + Print Label + Controller management
MSB Browser / Read Only         -> browse only
```

Controller management includes Add Controller, Edit Controller, current model/status/location/firmware/verification/programmed configuration, and Controller-to-Display assignment/reassignment/unassignment. No normal Controller DELETE workflow is authorized.

## PostgreSQL write boundary

The browser application must retain least privilege:

```text
fieldwiring_app
    -> SELECT approved read model
    -> EXECUTE narrow Controller functions/procedures
    -> no broad table INSERT/UPDATE/DELETE
```

The first implemented command is:

```text
ref.request_controller_label(authenticated_email, controller_id)
```

Its only Controller state change is:

```text
ref.controller.print_label = true
```

The label polling/print service remains a separate subsystem and consumes the established request state. Controller Management does not create a second print queue.

The same narrow-command model is the required direction for later Controller create/update/assignment operations.

## Audit actor boundary

The existing Controller tables use:

```text
ref.set_actor_on_insert()
ref.set_actor_on_update()
    -> ref.resolve_actor()
```

`ref.resolve_actor()` first honors transaction/session setting:

```text
app.directus_user_uuid
```

and maps that UUID through `ref.person.directus_user_id`. Browser write commands therefore resolve the authenticated Directus user server-side and set `app.directus_user_uuid` transaction-locally before the governed table write. This preserves the existing audit standard and records the real MSB person rather than `fieldwiring_app`.

Do not bypass the actor triggers, manually stamp audit IDs, or map an arbitrary browser-supplied identity.

## Custom-application threshold

A purpose-built application owns the UX when an operator must coordinate multiple related facts/actions, including relationship management, workflow state, conditional validation, task-specific navigation, printing, history, or application commands.

Controller Management is beyond the Directus UX threshold. Work Orders are expected eventually to cross the same threshold while continuing to reuse the common authentication/authorization model.

## Controller Management responsibility

The Controller application owns the normal operational experience for:

- browse/search;
- Add Controller;
- Edit Controller;
- model/status/location/firmware maintenance;
- current programmed Network/UID/IP maintenance;
- Controller-to-Display assignment/reassignment/unassignment;
- reviewed `wiring_source_display_id` maintenance;
- label request state;
- firmware/history context;
- FieldWiring cross-links;
- shelf-stock/unassigned Controller workflows;
- capability-protected commands and validation.

## Directus secondary CRUD responsibility

Directus may remain available for simple reference or one-record maintenance where it behaves well, for example `ref.controller_model`, `ref.controller_status`, or `ref.controller_firmware_version`. This is a convenience, not the required Controller workflow.

Do not require Directus to provide Controller-to-Display assignment or other complex Controller workflows.

## Database-model rule

Do not distort PostgreSQL solely to satisfy an administrative UI limitation.

`ref.controller_display` legitimately uses:

```text
PRIMARY KEY (controller_id, display_id)
```

The composite relationship key remains accepted. Do not replace it with a surrogate key merely for Directus compatibility.

## Security / deployment boundary

The Cloudflare authenticated-user header is trusted only behind the documented protected `my.sheboyganlights.org` proxy path. The internal FieldWiring listener must remain restricted according to the Server Management runtime contract so an untrusted client cannot bypass Cloudflare and inject the identity header.

Database-changing Controller work must follow the Server Management [PostgreSQL Disposable Acceptance Standard](https://github.com/Gregovate/MSB-Server-Management/blob/main/docs/server/PostgreSQL_Disposable_Acceptance_Standard.md): product regression, current-production disposable clone, candidate migration/behavior assertions, production invariants, cleanup, then a separate explicit production deployment gate.

## Immediate Resume Point

Do not resume from the Directus relationship experiment or the old Stage-browser backlog.

Current sequence is:

1. **Complete disposable PostgreSQL acceptance for migrations 021/022 and the Print Label command.**
2. Separate explicit production deployment/validation of 021/022 and the V0.3.3 browser slice.
3. Admin browser acceptance: authenticated identity, capability display, Print Label request, and audit identity.
4. Production Crew and Read Only capability-boundary acceptance.
5. Implement Edit Controller using the same narrow command/audit model.
6. Implement Add Controller.
7. Implement Controller-to-Display assignment/reassignment/unassignment with M:N and `wiring_source_display_id` preserved.
8. Minor UI cleanup, full regression/acceptance, operator procedures, and final PR #111 preparation.

The working read-side Controller Inventory and FieldWiring screens are the implementation foundation. Extend them; do not replace them merely to add management capability.

## Acceptance direction

Controller Management is complete when authorized operators can perform the accepted operational workflow in the purpose-built Controller application without raw SQL and without relying on Directus for multi-table coordination, while Cloudflare Access remains authentication authority, Directus role/policy data remains authorization authority, and PostgreSQL narrow commands/audit remain the final write boundary.
