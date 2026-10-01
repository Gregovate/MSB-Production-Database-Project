# Production Deployment Change Log

| Document Control | Value |
|---|---|
| Document Type | Controlled Production deployment history |
| Repository | MSB Production Database Project |
| Status | CURRENT |
| Owner | Production project owner / administrator |
| Established | 2026-10-01 |
| Ordering | Reverse chronological — newest deployment first |

## Purpose

Maintain one human-readable, date-ordered record of Production changes across the MSB Production Database Project.

This log is the quick operational history. It does not replace the exact acceptance record, owning issue, pull request, migration, rollback archive, or Git history. Each entry links those identities together so an operator can answer what changed, when it changed, and what actually reached Production without reconstructing the answer from multiple issues and acceptance files.

## Entry Rule

Add a new entry for every Production deployment that changes application behavior, database schema/functions, Production data by governed migration/correction, runtime behavior owned by this repository, or another operator-visible Production capability.

Newest entries go at the top.

Each deployment entry must record, when applicable:

- deployment date;
- subsystem/application;
- visible Production version;
- concise operator-visible or operational changes;
- exact deployed application SHA;
- merged-main SHA when different;
- migration path/number and identity;
- owning issue(s);
- implementation/deployment PR(s);
- acceptance/deployment result;
- rollback archive/report identity;
- important post-deployment field validation.

Documentation-only repository changes that do not alter Production do not require a deployment entry.

## 2026-10-01 — Setup V0.3.31-pick-review-fixes

**Subsystem:** Setup and Deployment  
**Owning work:** #206 under #122  
**Production result:** PASS

### Changes deployed

- Removed the blocking sticky Training banner from the Rolling Pick List.
- Training state is now shown inside the scanner controls without covering Pick counts or the Pick List.
- Corrected Training exit behavior.
- Removed Manager Override creation/edit/cancel controls from the Rolling Pick List; that screen remains the material-handler execution surface.
- Preserved Manager override demand state display on the Pick List.
- Removed the redundant second disposable-browser-review banner; the single Browser Review warning remains sufficient during disposable review.
- Deployed migration 066 so Manager override cancellation remains independent of preserved physical movement evidence.
- Advanced Pick Mode cache/assets for the accepted browser behavior.

### Identity

```text
visible Production version = V0.3.31-pick-review-fixes
accepted/deployed application SHA = 79574e3a7d16e82ef3e045eb2c7c96cff624e4e1
application PR #273 merge = 0976aedf28f05eac62040b27a22177a360cde415
deployment tooling PR #274 merge / main = f22f43dffcbb60050218a13f0788378d575749c5
migration = Setup/Database/066_allow_manager_pick_override_cancel_after_movement.sql
migration blob = a27574d99af70d5de0e247ef6ffb73974708f127
```

### Production acceptance

```text
marker = SETUP_206_V031_PRODUCTION_DEPLOYMENT_PASS
governed Setup fingerprint before/after = 9951600040f7b01c75b8c104b4ddeb8c unchanged
2026 Setup Session count before/after = 1 unchanged
exit status = 0
```

Rollback/evidence:

```text
rollback archive = /home/msbadmin/backups/setup-206/msb-pre-setup-206-v031-20261001T213325.dump
rollback SHA256 = 5ea93a8be1592400f00b393dd948e904a838ec7caf45591c4ff5edd6a145aa73
deployment report = /home/msbadmin/setup-deployment-reports/Setup_206_V031_Production_Deploy_20261001T213325.txt
```

Post-deployment field validation:

- real rugged-tablet / Zebra scanner path worked in Production Training Mode;
- Training Mode continued to prevent operational PICKED recording while exercising the real scanner validation path.

Remaining related work is not part of this deployment entry: #205 wide-screen Scheduling Board layout correction and #206 Manager Material Status remain separate active work.

---

## Historical Boundary

This centralized log begins with the 2026-10-01 V0.3.31 deployment.

Earlier Production history remains authoritative in the existing dated acceptance records, engineering handoffs, issues, pull requests, and Git history. Historical entries may be backfilled when useful, but no pre-2026-10-01 deployment fact should be invented merely to make this log look complete.

From 2026-10-01 forward, the project rule requires this log to be updated as part of Production deployment closeout.
