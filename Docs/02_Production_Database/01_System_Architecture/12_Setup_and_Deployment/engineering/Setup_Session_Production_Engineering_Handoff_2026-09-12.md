# Setup Session Production Engineering Handoff — 2026-09-12

| Document Control | Value |
|---|---|
| Document Type | Engineering Handoff |
| System | Production Database — Setup Session |
| Status | CURRENT HANDOFF — real 2026 Setup Session and Scheduling Board live |
| Owner | MSB Production Database engineering |
| Last Reviewed | 2026-09-25 |

## Purpose

Preserve the current accepted Setup Session Production state after the real 2026 annual launch, including the reusable/annual boundary, live Scheduling Board baseline, accepted material foundation, and the remaining downstream workstreams that now consume real 2026 annual identities.

This handoff and the Setup engineering `README.md` are the current resume authorities. The 2026-09-07 and 2026-09-11 handoffs are retained as historical acceptance records and are explicitly superseded for current runtime/launch status.

## Current Production Runtime

```text
protected application = https://my.sheboyganlights.org/setup/
live /opt/msb-setup SHA = 24dd851b6ceed879ca96170db648476a8307a775
version = V0.3.19-pick-list
service = msb-setup.service
listener = 192.168.5.9:8794
2025 Setup Session = HISTORICAL_VERIFICATION / historical evidence
2026 Setup Session = LIVE / PLANNING
Scheduling Board = live / Production accepted
Rolling Pick List = live / Production accepted
migration 060 = installed
current Setup fingerprint = 96b399ee872c1fe980d6f69a1ad34157
real 2026 scheduling = started
```

Server/runtime authority remains `Gregovate/MSB-Server-Management`.

## Accepted Assignment Layer

- LOR remains authority for current Stage/real-Scene Display membership.
- One material-bearing task in a scope continues to work implicitly.
- Multiple material-bearing tasks in the same scope use explicit Display Ownership.
- Each current resolved Display has one effective reusable Setup-task owner.
- Display assignment does not rewrite LOR membership or the Display's current Container.
- Physical Kit Boxes are explicitly assigned many-to-many to reusable tasks through `relationship_type='KIT'`.
- Existing SUPPORT / REQUIRED_CONTAINER relationships remain separate.
- The real 2026 Setup Session now exists and is the current annual planning/execution context.

## Accepted Durable Inventory — #184

#184 is the permanent Production subsystem. Migrations 032-037 established the normalized Extra Material catalog/schema, governed Manager commands, expected Container/Kit contents, Remainders, append-only physical inventory events/balance, and duplicate-row hardening.

The accepted browser/runtime surfaces are:

```text
Reusable task detail -> Extra Materials Required by This Task
/setup/kit-inventory/
/setup/t-post-inventory/
```

Permanent separation:

```text
reusable task requirement
expected source allocation
expected Kit / Container content
physical stock history/balance
current Display -> Container relationship
```

The same physical Kit may support multiple tasks. T-Posts may be in shared/bulk stock or intentionally stored with a Kit/Display. Storage location is a physical fact, not task-requirement ownership.

#184 Production foundation deployment applied migrations 032-037 and left the governed Setup fingerprint unchanged. Rollback archive retained:

```text
/home/msbadmin/backups/setup-184/msb-pre-setup-184-kit-inventory-20260915T001407.dump
```

## Accepted One-Time Reconstruction — #167

The accepted reconstruction target was:

```text
1e0e2d2c3ffbcafc2ffef2bb4a98c81d600e8b1b
```

One-time Production migrations:

```text
038, 043, 044, 045, 046, 047, 048
```

They loaded procedure-derived task Extra Material requirements, expected Kit contents, durable Remainders, shared/Kit T-Post stock definitions, and task T-Post requirements while preserving unresolved/conflicting values as `UNVERIFIED` / `NEEDS_REVIEW`.

They did not create a 2026 Setup Session, physical inventory events, or a competing task-to-Kit relationship. Migration 045 is read-only with respect to Kit assignments; current operator-entered Production assignments remain authoritative.

Final Production proof:

```text
SETUP_167_PRODUCTION_RECONSTRUCTION_PASS
298 passed live Setup/Application regression
FINAL LIVE SHA = 1e0e2d2c3ffbcafc2ffef2bb4a98c81d600e8b1b
2026 Setup Sessions = 0
Physical inventory history unchanged = 0 rows
Protected core fingerprint before/after = adc431f96b5622e125bf44d96e3d7807
```

Retained rollback evidence:

```text
/home/msbadmin/backups/setup-167/msb-pre-setup-167-reconstruction-20260915T005504.dump
/home/msbadmin/backups/setup-167/msb-pre-setup-167-target-tables-20260915T005504.dump
/home/msbadmin/setup-deployment-reports/Setup_167_Kit_Inventory_Reconstruction_Production_Migrate_20260915T005504.txt
```

The prior failed Production attempt was a harness-only wrong-route check (`/tpost-inventory/` instead of `/t-post-inventory/`). Fail-closed rollback restored the checkout and targeted tables exactly before the corrected run. That typo is now covered by a harness contract test.

## Accepted Expected Duration UI — #204

Reusable task expected duration is still durably stored as `expected_duration_minutes`. Managers now review/edit it as **Expected hrs** plus **Expected mins (0–59)**. Stored values are split on load and recombined on save through the existing governed reusable-task path. Blank remains NULL/missing. Annual actual-duration reporting remains separate under #132.

Production acceptance:

```text
candidate = 052d31dd4e68e13f2997f723778b88eddf9c53cf
prior live / rollback SHA = 5040fa282410b729d93e58a8299e48e4ee214809
preflight exact-target regression = 345 passed
focused live #204 regression = 21 passed
health = V0.3.13-assignment-layer PASS
governed fingerprint before/after = 7dd32f21ca9a455329de54e8799f01b5 unchanged
database migration = none
```

## Current Operator Meaning

Managers can now maintain reusable-task Extra Material requirements and expected Kit/T-Post stock definitions. Kit Inventory separates expected contents, physical on-hand, task assignment context, current Displays, and Remainders. T-Post Inventory separates shared/bulk storage from T-Posts carried with Kits/Displays and records physical counts through the append-only ledger.

Procedure-derived reconstructed values remain reviewable. Do not convert an expected/planning quantity into physical on-hand without an actual count.

## Preservation Baseline

Preserve V0.3.7 dirty-edit/client-build protections, V0.3.8 compact task detail, V0.3.9 prerequisite behavior, V0.3.10 Resource Catalog behavior plus migration 031 repair, V0.3.11 active-task identity, V0.3.13 assignment behavior, the Stage/Scene resolver, current Display/Container authority, the #184 durable inventory contract, and the accepted #167 reconstructed data.

## Current Post-Launch Resume Sequence

#145 is complete and closed. The real 2026 Setup Session and Scheduling Board are live under #122. Remaining work must refresh from current `main` and consume real 2026 annual/schedule identities:

```text
#175 Captain Work List / Procedure context
#132 Report Work
#172 Report Problem / Suggest Change
#206 Pick List / material readiness
#222 performance protection in parallel
#219 / GIS / writable movement later where required
```

Do not recreate the annual Session, treat 2025 as the current planning authority, or restore disposable pre-launch scheduler assumptions.

## Runtime / Rollback Boundary

The accepted rollback archives above are governed database recovery points. Do not restore them merely to undo a UI/documentation problem or without reconciling legitimate post-deployment Production work.

The current live Setup checkout is `24dd851b6ceed879ca96170db648476a8307a775` (`V0.3.19-pick-list`). Migration 060 is installed for the #206 Manager Pick List override, so #206 rollback is migration-bearing and must use the retained `/home/msbadmin/backups/setup-206/msb-pre-setup-206-pick-list-20260926T030610.dump` archive or the bounded migration-060 rollback procedure under Server Management authority. The immediately preceding application SHA is `55e097e7bb3b807793893defc939c9a23fc4ec5d` (`V0.3.18-scheduling-board`), but source-only rollback does not remove migration 060. Older rollback archives in this handoff remain valid historical evidence for the deployments that created them.

## Engineering Resume

Before changing Setup:

1. refresh remote `main`;
2. read Project Rules;
3. read the Setup engineering README and this handoff;
4. read the Supporting Information Contract;
5. preserve the accepted V0.3.7 through V0.3.13 foundations plus #184/#167 inventory behavior/data and the accepted live Scheduling Board baseline;
6. use the live 2026 Session for annual planning/execution and retain 2025 only as historical/verification evidence;
7. resume downstream #175/#132/#172/#206 work from real 2026 identities rather than rebuilding a disposable pre-launch world; and
8. use Server Management for disposable acceptance, browser review, and Production deployment authority.

## Related Current Evidence

- `Setup/Acceptance/Setup_Kit_Inventory_TPost_Production_Acceptance_2026-09-15.md`
- `Setup/Acceptance/Setup_Resource_Upsert_Repair_Production_Acceptance_2026-09-13.md`
- `Setup/Acceptance/Setup_Assignment_Layer_V0313_Production_Acceptance_2026-09-12.md`
- `Setup_Task_Supporting_Information_Contract_2026-09-11.md`
