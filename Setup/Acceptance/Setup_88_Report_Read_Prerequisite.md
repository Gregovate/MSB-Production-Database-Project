# #88 Container Movement — read prerequisite

| Document control | Value |
|---|---|
| Status | PREPARED / engineering privilege proof PASS; Production approval and current-clone acceptance pending |
| Reviewed | 2026-10-08 America/Chicago |
| Owning issues | #88, #122 |
| Proposed permission migration | `Setup/Database/071_grant_setup_container_type_report_read.sql` |
| Exact migration blob | `1fd5de8f3de7665336e0eabead498e94ed915883` |
| Application | Existing approved V0.3.50 / `6c44a082dd520b75881c50ad2ce78feb029ff87d`; unchanged |
| Current live proof | V0.3.42 / `cb0538022ed066ff90675e832daa1cd95488114a`; healthy |
| Production permission change / report installation | NOT APPLIED |

## Failure and concrete correction

The October 8 source-only installer correctly stopped before mutation when the
exact application-role query joined `ref.container_type`. Administrative fixture
acceptance had missed the real runtime read boundary. The retained attempt is
`/home/msbadmin/setup-deployment-reports/Setup88Report-20261008T151700Z/report.txt`.

The proposed migration's only persistent change is:

```sql
GRANT SELECT (container_type_id, container_type_name)
    ON TABLE ref.container_type TO fieldwiring_app;
```

This keeps live reference names authoritative and preserves the reviewed type
labels and Standalone/single-Display Pallet warnings. It creates no tables,
columns, functions or views, changes no field records, and grants no write
privileges. Additional type columns remain unreadable. Migration 070 belongs to
the separate guided-contents draft; this prerequisite does not depend on it.

## Engineering acceptance

`test_setup_88_report_read_privilege.mjs` creates an isolated PostgreSQL/WASM
database and a runtime role with the existing report reads but no Container-type
grant. It reproduces the exact denial, applies the actual proposed SQL, executes
all six statements extracted from the actual report source as `fieldwiring_app`
inside a read-only repeatable-read transaction, and checks Session scope,
Container-only observations, active Displays and attached/detached/unassigned
positions. It proves type records unchanged and rejects reads of an additional
private column plus INSERT, UPDATE, DELETE and TRUNCATE. PASS on October 8.

Engineering invocation uses an already installed `@electric-sql/pglite` module
via `PGLITE_MODULE` and Python via `PYTHON` (default python3). This does not require
Node on Greg's workstation. This synthetic proof is not current-Production-clone
acceptance and does not authorize Production mutation.

Full Setup: **775 passed**. Focused report/application plus installer boundary:
**212 passed**; isolated Current Location: **22 passed**. Application and source
installer bytes remain identical to current main; no UI review changes are
introduced.

## Production gate

The prior report approval covered a source-only release with no PostgreSQL
mutation. This permission change is a separately reviewable prerequisite; no
permission SQL or retry command is included in the source-only installer.

Authority retrieved/read for this correction:

- [Production Database Change Deployment Runbook](https://github.com/Gregovate/MSB-Server-Management/blob/main/docs/server/Production_Database_Change_Deployment_Runbook.md), blob `d307771d15baf27b0086b8c421c0c84146b74887`.
- [Production Database Maintenance Mode](https://github.com/Gregovate/MSB-Server-Management/blob/main/docs/server/Production_Database_Maintenance_Mode.md), blob `919da2182d6d211d789c213ab37b3bdb085f8208`.
- [Runbook-First Production Rule](../../System_Documentation/Project_Rules/Runbook_First_Production_Rule.md).

Required next sequence: accept this exact permission scope; establish exact
merged migration identity and current-clone acceptance; prepare/review its bounded
runner using the established maintenance-controller pattern; verify live/source
and ONLINE state; enter maintenance and require freeze proof; retain and validate
rollback snapshot; capture existing ACL/data evidence; apply only migration 071;
validate exact report reads under the application role and preservation; return
through the same controller and require ONLINE/health proof. No application or
shared checkout advancement is part of the permission-only step.

After successful prerequisite evidence, the separately pinned source-only
installer can install the previously accepted report source. It retains its exact
merged/forward source guards, full/focused tests, real application-role query
probe, fingerprint comparison and old-source rollback. Never weaken those gates.

Failure/transport interruption: inspect retained journal, controller state and
actual ACLs before another mutation. Do not infer grant commit from a disconnect,
restore the database automatically, or retry the old installer blindly. Capture
prior column ACLs before any reviewed permission rollback; do not revoke access
that existed before this prerequisite.
