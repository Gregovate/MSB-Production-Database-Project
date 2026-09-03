# Controller Setup Probe Acceptance Evidence — 2026-09-02

| Item | Value |
|---|---|
| Status | **PASS — APPROVED FOR SEPARATE PRODUCTION DEPLOYMENT GATE** |
| Issue | #110 |
| Draft PR | #111 |
| Application candidate | `2fd2067958cc0a903260fe6f089f88ae63a857f1` |
| Production application baseline | `e9ab029a17067b38b34f9306069f54899925f73f` |
| Acceptance wrapper | `Controllers/Acceptance/run_controller_setup_probe_disposable_acceptance.ps1` |
| Candidate DB migrations | `023_create_controller_management_commands.sql`, `024_harden_controller_assignment_capability.sql` |
| Production mutation during acceptance | NONE |

## Final Result

The 2026 Controller setup probe and browser-maintenance candidate completed the full accepted gate successfully.

Final banners:

```text
CONTROLLER MANAGEMENT DISPOSABLE ACCEPTANCE: PASS
CONTROLLER MANAGEMENT DISPOSABLE CHILD: PASS
CONTROLLER SETUP PROBE + MANAGEMENT ACCEPTANCE: PASS
CONTROLLER SETUP PROBE + MANAGEMENT WRAPPER: PASS
```

Production deployment remains a **separate explicit gate** governed by the MSB Server Management Production Database deployment runbook.

## Detached Application Regression

Exact application candidate:

```text
2fd2067958cc0a903260fe6f089f88ae63a857f1
```

Result:

```text
231 passed in 2.25s
DETACHED CONTROLLER PROBE/MAINTENANCE REGRESSION: PASS
```

The combined FieldWiring + Procedures suite therefore passed against the exact application candidate in the production runtime before any database-clone write testing.

## Current Production Read-Only Planner Probe

The live production planner probe was read-only and passed.

Observed current-production evidence:

```text
planner numeric UID rows       = 1786
planner programmed Controllers = 168
planner Stages                 = 38
planner Regular rows           = 1159
planner multi-UID models       = 5
```

Result:

```text
PLANNER PRODUCTION READ PROBE: PASS
```

This establishes that the current governed data supports the first setup-season planner for:

- Stage/Sub-stage selection;
- Networks currently used by a Stage;
- Network-scoped LOR Unit-ID usage;
- physical Controller current-programming overlay;
- `Regular` network context;
- model-aware multi-UID / contiguous-UID planning.

The planner does **not** claim physical Network reachability for every Stage. When probing a Network not currently evidenced at the selected Stage, the operator confirms physical reach using the existing park/network map. `Regular` remains the known park-wide slow/background network exception.

## Current Production Direct-Stage SPARE Probe

The current LOR/V7 materialization returned:

```text
direct_stage_spare_rows=116
```

This confirms useful directly attributable Stage/SPARE evidence exists for the initial planner.

`ref.spare_channel` is not used as current authority. Shared/master Preview SPARE rows remain deliberately unguessed when Stage or physical-Controller attribution cannot be proven.

## Current-Production Disposable Clone

Production state captured before the clone test:

```text
Controller fingerprint = 578217bcb18e1291ceced673a3de3b27
controllers             = 177
assignments             = 194
production dump         = 14M, structurally validated
```

A disposable `postgis/postgis:16-3.5` PostgreSQL instance was populated from the current production dump. The candidate migrations were then applied **only to the disposable clone**:

```text
023_create_controller_management_commands.sql
024_harden_controller_assignment_capability.sql
```

Migration privilege result:

```text
can_read_controller_management_options = true
can_create_controller                  = true
can_update_controller                  = true
can_assign_controller                  = true
can_unassign_controller                = true
can_reassign_controller                = true
forbidden direct controller UPDATE     = false
forbidden direct controller INSERT     = false
forbidden direct assignment INSERT     = false
forbidden direct assignment DELETE     = false
```

This confirms the intended least-privilege boundary: `fieldwiring_app` executes narrow governed commands but does not receive broad Controller-table DML.

## Authorization and Audit Proof

The disposable acceptance resolved the real Manager/Admin actor:

```text
gliebig@sheboyganlights.org -> person_id 17 -> Greg Liebig
```

Results:

```text
PASS: direct fieldwiring_app Controller INSERT denied
PASS: unauthorized Controller create denied
PASS: created clone-only CTRL 1178; audit person=17; actor=Greg Liebig
```

The clone-only Controller used PostgreSQL-generated permanent identity. Production Controller identity remained unchanged.

## Programmed Configuration and UID Rules

Results:

```text
PASS: intentional duplicate Network/UID programming accepted
PASS: fixed-capacity model rejected invalid UID count
```

This preserves the accepted Controller rules:

- `controller_id` is permanent physical identity;
- Network/UID is mutable programming, not identity;
- repeated Network/UID values are valid when intentional;
- fixed-capacity multi-UID models enforce their governed UID count;
- UID planning is Network-scoped.

## Controller-to-Display Lifecycle

The disposable clone exercised the current-snapshot M:N relationship workflow.

Results:

```text
PASS: one Controller assigned to two Displays and AVAILABLE -> DEPLOYED transition applied
PASS: replacement preserved other assignment and moved only selected relationship
PASS: final unassign preserved Controller asset and returned DEPLOYED -> AVAILABLE
PASS: REPAIR Controller assignment denied until status is explicitly changed
```

The tested workflow therefore preserved:

- one Controller -> many Displays;
- one Display -> many Controllers as a supported model;
- atomic selected-relationship replacement;
- Controller asset preservation on unassign;
- operational status lifecycle;
- assignment guard for REPAIR;
- assignment-capability hardening from migration 024.

## Production Safety Proof

After all disposable write tests completed:

```text
Before: 578217bcb18e1291ceced673a3de3b27
After:  578217bcb18e1291ceced673a3de3b27
PASS: production Controller fingerprint unchanged
```

No candidate migration was installed in production during this acceptance run. No production Controller, assignment, or firmware-history row was changed.

## Accepted Deployment Target

The accepted **application** target remains exactly:

```text
2fd2067958cc0a903260fe6f089f88ae63a857f1
```

Acceptance-harness commits made after that SHA do not change the accepted application target and must not silently repin deployment.

The production deployment package must install only candidate migrations 023/024 and fast-forward the shared application checkout to this exact target after all production preflight, backup, least-privilege, regression, health, and rollback requirements pass.

## Next Gate

Before any production mutation:

1. prepare the Controller setup/maintenance production deployment runner from the active `MSB-Server-Management` Production Database Change Deployment Runbook;
2. pin the exact accepted application SHA above;
3. verify the actual live production checkout rather than assuming a remembered SHA;
4. run detached regression in the production runtime;
5. create and validate the rollback PostgreSQL archive using direct stdin redirection;
6. preflight and apply migrations 023/024 only;
7. verify Controller fingerprints remain unchanged by function installation;
8. fast-forward the shared checkout;
9. restart and verify FieldWiring + Procedures;
10. run live combined regression and negative security checks;
11. retain deployment report and rollback archive;
12. then perform deliberate browser/operator acceptance for Plan Capacity and Controller Maintenance.

Production deployment requires explicit approval and is not authorized merely by this PASS record.
