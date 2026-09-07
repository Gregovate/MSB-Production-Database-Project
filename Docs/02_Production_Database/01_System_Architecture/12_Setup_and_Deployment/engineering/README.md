# Setup and Deployment Engineering

| Document Control | Value |
|---|---|
| Document Type | Engineering Handoff Portal |
| System | Production Database — Setup and Deployment |
| Audience | Greg, maintainers, database administrators, future engineering sessions |
| Status | CURRENT HANDOFF — Production runtime accepted; UI/workflow in live evaluation |
| Owner | MSB Production Database engineering |
| Last Reviewed | 2026-09-07 |

This is the engineering starting point for Setup Session architecture, database behavior, application contracts, deployment state, and resume information.

The operator-facing instructions are separate under [`../operatorSOP/`](../operatorSOP/README.md).

## Current State

Production deployment is operational and accepted at the runtime level.

```text
public application             = https://my.sheboyganlights.org/setup/
application version            = V0.3.4-shared-season-guard-review
2025 Setup Session             = HISTORICAL_VERIFICATION
2025 annual tasks              = 57
2025 UNVERIFIED tasks          = 57
2026 Setup Sessions            = 0
Setup work days                = 0
Setup movement events          = 0
active reusable Setup tasks    = 57
```

Accepted runtime state includes:

```text
/opt/msb-setup                 = permanent detached worktree
msb-setup.service              = active / enabled
msb-setup-google-links.service = active / enabled
listener                       = 192.168.5.9:8794
UFW                            = 8794/tcp from Synology 192.168.5.4 only
Synology /setup/ route         = active
Cloudflare-authenticated view  = PASS; real 2025 data rendered
post-reboot invariants         = PASS
```

The Setup/UI subsystem is **not final**. The three Setup PRs remain open drafts while managers use the 2025 session for real reconstruction/training and expose usability, workflow, data-model, and documentation problems.

The current operator/plain-English and engineering documentation has been released separately to Production Database `main` so the Internal Web Backbone can link stable documentation without prematurely merging the Setup application/UI stack.

A follow-up acceptance defect is now implemented in source and pending Production deployment: Setup had no GA4 integration and no visible UI revision marker. The candidate adds the shared MSB Internal Intranet GA4 contract plus a visible `Setup Session V0.3.4 — UI revision 2026-09-07.1` marker.

## Start Here

- [Setup Session Production Engineering Handoff — 2026-09-07](Setup_Session_Production_Engineering_Handoff_2026-09-07.md) — current database/application/runtime state, accepted deployment evidence, open PR structure, and live-evaluation resume point.
- [Setup Internal Analytics and Visible Version Contract — 2026-09-07](Setup_Internal_Analytics_and_Version_Contract_2026-09-07.md) — GA4 Measurement ID/privacy boundary, versioned analytics asset, visible UI revision, contract tests, and remaining Production acceptance gate.
- [Internal Web Backbone Handoff](Internal_Web_Backbone_Handoff.md) — source-subsystem contract for intranet navigation/search/application entry points.
- [Setup Session Shared Review and Season-Year Guard](../Setup_Session_Shared_Review_and_Season_Year_Guard_2026-09-07.md) — annual-vs-reusable data boundary and session-year enforcement.

## Authoritative Implementation Sources

Application source:

```text
Setup/Application/
```

Database migration source:

```text
Setup/Database/
```

Production acceptance/install material:

```text
Setup/Acceptance/
```

The Production Database repository owns Setup application/business/database behavior. `Gregovate/MSB-Server-Management` owns deployed service, listener, firewall, reverse-proxy, restart/recovery, and host permission facts.

## Current PR Structure

The active Setup work remains intentionally open across three draft PRs:

```text
#123  reconnaissance / planning documentation lineage
#124  browser UI / verification lineage
#125  Production foundation / database / runtime lineage
```

Do not merge/close this stack merely because the application is reachable. Final normalization and merge should wait until enough real 2025 review use has occurred to identify and resolve material UI/workflow findings.

The documentation-only release to `main` is intentionally separate from that closeout decision.

## Critical Runtime Permission Boundary

`msbadmin` is the SSH administrator but does not have the `msb-docs-read` traversal permissions used by the `fieldwiring` runtime account on `/mnt/msb-display-folders` and `/mnt/msb-setup-google-links`.

Runtime-path validation must run as `fieldwiring`. Server-side detail and recovery procedure belong in `Gregovate/MSB-Server-Management`.

## Known Boundaries / Open Work

Current live-review scope includes:

- 2025 annual review/verification;
- reusable task creation/copy and maintenance;
- task scope/order/prerequisite/resource maintenance;
- supported planning/review controls;
- Procedure/document context; and
- authenticated multi-user browser access.

Still outside the accepted Production-ready workflow:

- Pick List generation; and
- Container/Display movement/scanning write commands.

Current acceptance follow-up:

- deploy and verify Setup GA4 page-view instrumentation using `G-X08ZTSY0VV`;
- verify the visible Setup UI revision marker in the live browser; and
- preserve the analytics privacy boundary that excludes identity, query strings, and Production record identifiers.

Live evaluation should also capture questions and suggestions that are not traditional software defects. The 2025 review is the usability and operating-model test bed before 2026 is created.

## Resume Development

Before changing this subsystem:

1. read the Production Database Project Rules;
2. review PRs #123, #124, and #125 together rather than treating one as the whole subsystem;
3. read the Production Engineering Handoff linked above;
4. read the Setup analytics/version contract before changing browser instrumentation or visible revision behavior;
5. review current live-use findings from managers/reviewers;
6. preserve the accepted 2025/2026 annual-vs-reusable boundary;
7. use `Gregovate/MSB-Server-Management` for current runtime/service/proxy facts; and
8. keep operator docs, engineering docs, and Internal Web Backbone navigation synchronized when behavior changes.

Current resume point:

```text
Production runtime                    = ACCEPTED
Cloudflare-authenticated 2025 view    = ACCEPTED
post-deployment invariants            = ACCEPTED
UI/workflow                           = LIVE EVALUATION
2026 Setup Session                    = NOT CREATED
PR #123 / #124 / #125                 = OPEN DRAFTS
operator/engineering docs on main     = RELEASED
Backbone Production page              = PUBLISHED; documentation-link correction in progress
Setup GA4 + visible UI revision       = IMPLEMENTED IN SOURCE; DEPLOYMENT PENDING
```

## Related Systems

- [Setup and Deployment operator portal](../README.md)
- [Operator procedures](../operatorSOP/README.md)
- [Detailed Manager Review Guide](../../../02_Operational_SOPs/Setup/Setup_Session_Manager_Review_Guide.md)
- [Labeling and Scanning](../../07_Labeling_and_Scanning/README.md)
- [Wiring System](../../09_Wiring_System/README.md)
