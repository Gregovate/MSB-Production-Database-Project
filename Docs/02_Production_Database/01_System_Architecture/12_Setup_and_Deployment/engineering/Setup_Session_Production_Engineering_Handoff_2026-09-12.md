# Setup Session Production Engineering Handoff — 2026-09-12

| Document Control | Value |
|---|---|
| Document Type | Engineering Handoff |
| System | Production Database — Setup Session |
| Status | CURRENT HANDOFF — #184 durable inventory and #167 one-time reconstruction accepted in Production |
| Owner | MSB Production Database engineering |
| Last Reviewed | 2026-09-15 |

## Purpose

Preserve the current accepted Setup Session Production state and the remaining launch sequence after completion of the durable Kit/Extra Material/T-Post subsystem and its one-time legacy reconstruction.

## Current Production Runtime

```text
protected application = https://my.sheboyganlights.org/setup/
live /opt/msb-setup SHA = 1e0e2d2c3ffbcafc2ffef2bb4a98c81d600e8b1b
version = V0.3.13-assignment-layer
service = msb-setup.service
listener = 192.168.5.9:8794
2025 Setup Session = HISTORICAL_VERIFICATION / SANDBOX
2026 Setup Sessions = 0
physical inventory events = 0
protected Setup core fingerprint = adc431f96b5622e125bf44d96e3d7807
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
- No 2026 Setup Session exists.

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

## Current Operator Meaning

Managers can now maintain reusable-task Extra Material requirements and expected Kit/T-Post stock definitions. Kit Inventory separates expected contents, physical on-hand, task assignment context, current Displays, and Remainders. T-Post Inventory separates shared/bulk storage from T-Posts carried with Kits/Displays and records physical counts through the append-only ledger.

Procedure-derived reconstructed values remain reviewable. Do not convert an expected/planning quantity into physical on-hand without an actual count.

## Preservation Baseline

Preserve V0.3.7 dirty-edit/client-build protections, V0.3.8 compact task detail, V0.3.9 prerequisite behavior, V0.3.10 Resource Catalog behavior plus migration 031 repair, V0.3.11 active-task identity, V0.3.13 assignment behavior, the Stage/Scene resolver, current Display/Container authority, the #184 durable inventory contract, and the accepted #167 reconstructed data.

## Remaining Pre-Launch Sequence

The controlling sequence is now:

```text
#145 FINAL reusable-Catalog acceptance + disposable 2026 seed proof
  -> #122 real 2026 Setup Session + scheduling / Pick List launch gate
```

#145 remains the final Catalog content/seed acceptance gate. #122 remains the real annual Setup Session / scheduling / Pick List launch gate.

## Runtime / Rollback Boundary

The accepted rollback archives above are governed database recovery points. Do not restore them merely to undo a UI/documentation problem or without reconciling legitimate post-deployment Production work.

The live Setup checkout is intentionally pinned to `1e0e2d2...`. Later #167 branch commits are Production harness corrections and controlled closeout documentation only; they are not a new runtime deployment target.

## Engineering Resume

Before changing Setup:

1. refresh remote `main`;
2. read Project Rules;
3. read the Setup engineering README and this handoff;
4. read the Supporting Information Contract;
5. preserve V0.3.7 through V0.3.13 plus #184/#167 inventory behavior/data;
6. keep 2025 as the proving ground and create no real 2026 Setup Session until the remaining gates pass;
7. continue `#145 FINAL -> #122`; and
8. use Server Management for disposable acceptance, browser review, and Production deployment authority.

## Related Current Evidence

- `Setup/Acceptance/Setup_Kit_Inventory_TPost_Production_Acceptance_2026-09-15.md`
- `Setup/Acceptance/Setup_Resource_Upsert_Repair_Production_Acceptance_2026-09-13.md`
- `Setup/Acceptance/Setup_Assignment_Layer_V0313_Production_Acceptance_2026-09-12.md`
- `Setup_Task_Supporting_Information_Contract_2026-09-11.md`
