# Setup Session Production Engineering Handoff — 2026-09-07

| Document Control | Value |
|---|---|
| Document Type | Engineering Handoff |
| System | Production Database — Setup Session |
| Status | CURRENT HANDOFF — Production runtime accepted; UI/workflow in live evaluation |
| Owner | MSB Production Database engineering |
| Last Reviewed | 2026-09-07 |

## Purpose

Preserve the accepted Setup Session V0.3.4 Production state, operating model, security boundaries, runtime dependencies, rollback evidence, open PR structure, and current live-evaluation resume point so later work can start from repository evidence instead of chat history.

## Current Operating Model

The real 2025 Production-backed Setup Session is the shared historical reconstruction and training area.

Authorized reviewers use it to:

- reconstruct and correct 2025 annual Setup facts;
- learn the Setup application using real data;
- add or correct reusable Setup tasks, resources, prerequisites, scope, order, and other permanent Setup knowledge where appropriate;
- verify records where evidence exists;
- leave uncertain records UNVERIFIED or mark them NEEDS CORRECTION; and
- identify UI/workflow/data-model/documentation problems before the 2026 Setup Session is created.

The selected Setup Session owns the allowable operational year:

```text
2025 session -> 2025 operational dates/timestamps only
2026 session -> 2026 operational dates/timestamps only
```

Audit/recording timestamps remain current truthful timestamps.

## Production Database Promotion

Production V0.3.4 promotion is accepted.

Durable migration sequence applied:

```text
008
009
010
011
013
014
015
016
017
```

Migration `012` was intentionally excluded because it contains disposable browser-review reset/seed behavior and must never be applied to Production.

Validated pre-promotion rollback archive:

```text
/home/msbadmin/backups/setup-v034/msb_pre_setup_v034_20260907T202706Z.dump
SHA256 e09bd97010b464fe307a9fbe0192c9ca4189fd562215f4eaa93e02a2d08f89a5
```

The archive is PostgreSQL custom format and `pg_restore -l` validation passed.

## Accepted Production Data State

Final post-cutover / post-reboot read-only invariant check:

```text
setup_session_id          = 1
season_year               = 2025
session_status            = HISTORICAL_VERIFICATION
annual_tasks              = 57
unverified_tasks          = 57
sessions_2026             = 0
work_days                 = 0
movement_events           = 0
active_reusable_tasks     = 57
```

This proves deployment, Directus reload, and host reboot did not alter Setup operational data.

## Accepted Application / Runtime State

Protected Production entry point:

```text
https://my.sheboyganlights.org/setup/
```

Application version:

```text
V0.3.4-shared-season-guard-review
```

Permanent source/runtime:

```text
/opt/msb-setup
source SHA = c0639c5b04de667176a8d8eef14fce0409f03ec6
msb-setup.service = active / enabled
listener = 192.168.5.9:8794
msb-setup-google-links.service = active / enabled
```

Accepted network/proxy state:

```text
UFW 8794/tcp ALLOW IN 192.168.5.4
Synology /setup -> /setup/ redirect = PASS
/setup/ root = HTTP 200
/setup/api/health = expected V0.3.4 payload
Cloudflare-authenticated browser access = PASS
real 2025 Production data rendered = PASS
Procedures regression = PASS
```

The first Setup Synology route cutover was safely rolled back after the first immediate post-reload request returned Synology 404. The Server Management reverse-proxy runbook was corrected with a bounded post-reload readiness gate. The accepted retry became healthy on attempt 2.

## Host Reboot / Directus Reload

Ubuntu required a reboot for:

```text
linux-image-7.0.0-31-generic
```

One controlled host reboot both activated the kernel and reloaded Directus after the Setup schema promotion.

Accepted post-reboot state:

```text
kernel                         = 7.0.0-31-generic
reboot-required marker         = cleared
msb-postgres                   = running / healthy / unless-stopped
msb-directus                   = running / unless-stopped
Directus image                 = directus/directus:11.17.1
Directus extensions            = directus-extension-scan, directus-extension-stamp-actor-fields
Directus startup               = online; no blocking startup errors
fieldwiring.service            = active / enabled
msb-procedures.service         = active / enabled
msb-display-folders.service    = active / enabled
msb-setup-google-links.service = active / enabled
msb-setup.service              = active / enabled
FieldWiring health             = V0.4.0 PASS
Procedures health              = V0.1.0 PASS
Setup health                   = V0.3.4 PASS
public Setup / Procedures      = PASS
```

Two noncritical staging containers were not recovered by guesswork. One exited cleanly with `restart=no`; another no longer existed and had no repository-owned lifecycle contract. Server Management records this staging-container lifecycle documentation gap.

## Authorization Boundary

The protected Setup API uses:

```text
Cloudflare Access authenticated email
  -> Setup backend capability lookup
  -> Directus/ref.person authorization source
  -> narrow PostgreSQL command functions
```

A shared link alone does not grant write authority.

Managers/reviewers may work on the 2025 annual session and reusable Setup knowledge according to capability. Only Administrators may:

- create annual Setup Sessions; and
- promote an annual plan order to the reusable future baseline.

`fieldwiring_app` does not receive broad table DML merely to support browser actions.

## Annual vs Reusable Boundary

```text
annual 2025 change
    = 2025 historical fact/state

Reusable Task change
    = permanent Setup knowledge that may carry forward
```

Reviewers must not encode a one-off 2025 condition into reusable knowledge merely to make the historical record fit.

## Runtime / Filesystem Boundary

Server/runtime authority is `Gregovate/MSB-Server-Management`.

Critical runtime identity:

```text
service account          = fieldwiring
supplementary group      = msb-docs-read
Display Folders mount    = /mnt/msb-display-folders (read-only)
Google native link view  = /mnt/msb-setup-google-links
```

`msbadmin` is the SSH/system administrator but does not have the same runtime traversal rights. Filesystem/runtime validation under these paths must run as `fieldwiring`.

## Current Live-Evaluation Scope

Managers can use the 2025 session for real review/training work, including:

- annual verification/correction;
- reusable task creation/copy and maintenance;
- task scope/order maintenance;
- prerequisites;
- structured equipment/resources;
- supported planning/review controls; and
- Procedure/document context.

Still outside the current accepted Production-ready workflow:

- Pick List generation; and
- Container/Display movement/scanning write commands.

Do not create fake work days, fake movements, or throwaway Production records merely to test the UI.

## Open PR Structure

The Setup subsystem remains open across three draft Production Database PRs:

```text
#123  Document Setup Session subsystem reconnaissance
#124  Prototype 2025 Setup Session verification UI
#125  Build Setup Session production foundation
```

These PRs intentionally remain open while the 2025 session is used in practice. Production availability is not the same as final UI/workflow acceptance.

Before final merge:

1. gather enough real 2025 review use to expose material UI/workflow issues;
2. correct accepted defects and documentation errors;
3. keep operator/plain-English and engineering documentation synchronized;
4. complete the Internal Web Backbone integration and deployed navigation verification;
5. review issues/findings from managers;
6. normalize the three-PR stack without losing lineage; and
7. merge only when the subsystem is ready to be treated as the accepted baseline for 2026 planning.

## Internal Web Backbone State

Source handoff is now **READY FOR IMPLEMENTATION** because the protected `/setup/` route is operational and authenticated 2025 data rendering has passed.

Backbone implementation must still:

- present Setup as a task/action, not an engineering document tree;
- link to `https://my.sheboyganlights.org/setup/`;
- make the 2025 review procedure discoverable in plain language; and
- avoid exposing engineering/database/acceptance internals to ordinary operators.

Source handoff:

[Internal Web Backbone Handoff](Internal_Web_Backbone_Handoff.md)

Backbone issue:

```text
Gregovate/MSB-Internal-Web-Backbone #10
```

## Resume Point

```text
Database V0.3.4 promotion           = ACCEPTED
Production runtime                  = ACCEPTED
Cloudflare-authenticated 2025 view  = ACCEPTED
post-deployment invariants          = ACCEPTED
2025 historical session             = 57 / 57 UNVERIFIED at deployment baseline
2026 session                        = absent
UI/workflow                         = LIVE EVALUATION
PR #123 / #124 / #125               = OPEN DRAFTS
Backbone source handoff             = READY FOR IMPLEMENTATION
```

Next engineering work should come from real manager/reviewer findings and the Backbone integration, not from reconstructing deployment state.

## Related Documents

- [Setup engineering portal](README.md)
- [Setup operator procedures](../operatorSOP/README.md)
- [Manager Review Guide](../../../02_Operational_SOPs/Setup/Setup_Session_Manager_Review_Guide.md)
- [Shared Review and Season-Year Guard](../Setup_Session_Shared_Review_and_Season_Year_Guard_2026-09-07.md)
- [Internal Web Backbone Handoff](Internal_Web_Backbone_Handoff.md)
