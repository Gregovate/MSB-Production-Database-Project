# Setup 2025 Live Review Work Ledger — 2026-09-08

| Document Control | Value |
|---|---|
| Document Type | Engineering Live-Review Work Ledger |
| System | Production Database — Setup Session |
| Status | CURRENT WORK LEDGER — engineering/disposable gate green; browser approval pending; Production unchanged |
| Owner | MSB Production Database engineering |
| Last Reviewed | 2026-09-08 |
| Related Work | Issue #122; draft PR #125 |

## Purpose

Preserve the exact current Setup live-review workstream, review rules, accepted candidate evidence, candidate-versus-Production boundary, unresolved work, and resume point while reviewing the real 2025 Historical Verification session.

This ledger exists because the 2025 review generated several related workstreams at once: navigation, annual-item reconciliation into the Reusable Task Catalog, Captain/knowledge-owner maintenance, reconstruction correction, material/logistics context, and review of Rick Hoffmann's historical notes. These findings must not be reconstructed from conversation history.

This document supplements, and does not replace, the accepted V0.3.4 Production baseline in `Setup_Session_Production_Engineering_Handoff_2026-09-07.md`.

## 1. Current Accepted Candidate and Safety State

Production remains on the previously accepted Setup V0.3.4 runtime. The current training/reconstruction candidate has **not** been deployed to Production.

Accepted application/database candidate:

```text
branch = agent/setup-session-production-foundation
candidate SHA = a10edf8618dfb944bde5558c3a9e88e2a1502173
```

Candidate migrations:

```text
019 = reconstruction-safe task delete
020 = Captain / Alternate / Advisor management
021 = ASSIGNED reconciliation state
```

Candidate migration hashes:

```text
019  8cc1d14f8289f9ddf3a2a7b5b14e1f69e7fb53f4d6f2151de691a7aed5ffc1e6
020  7e3cdb4612f52801890b18c6d8f5f7b2009727fde07ef636ac034ed94f9cdd2c
021  51d587fb06575ce0ddf6c846d7f209f8411013fee166abea5a7ba3ed61fe6389
validation  14c5d81c373d8af110eb299472d4aa903ac15e8ea4d994ce576b83a451c81a27
```

### Full Setup/Application regression

On the exact accepted candidate:

```text
107 passed in 2.32s
```

The former `83 passed / 15 stale failures` blocker is closed.

### Disposable current-Production-clone acceptance

Accepted report:

```text
/home/msbadmin/setup-acceptance-reports/Setup_Training_Disposable_20260908T233301.txt
```

Safety boundary:

```text
Production database reads = pg_dump + SELECT only
all acceptance writes      = disposable PostgreSQL clone only
```

Initial migration application:

```text
Migration 019 reconstruction-safe delete: PASS
Migration 020 Captain management: PASS
Migration 021 ASSIGNED reconciliation state: PASS
```

The same migrations were then deliberately applied a second time to the already-migrated disposable clone:

```text
Migration 019 idempotence replay: PASS
Migration 020 idempotence replay: PASS
Migration 021 idempotence replay: PASS
```

Governed Setup fingerprint across replay:

```text
before replay = a2a84fc3f162f2f30914c909710976cf
after replay  = a2a84fc3f162f2f30914c909710976cf
PASS: migrations 019-021 replay cleanly with governed Setup data unchanged
```

Feature-specific validation:

```text
DISPOSABLE_SETUP_TRAINING_VALIDATION_PASS
validation_status       = PASS
delete_execute          = true
captain_execute         = true
no_broad_task_delete    = true
no_broad_captain_insert = true
no_broad_annual_update  = true
DISPOSABLE_SETUP_TRAINING_ACCEPTANCE_PASS
```

Production Setup fingerprint for the full run:

```text
before = a2a84fc3f162f2f30914c909710976cf
after  = a2a84fc3f162f2f30914c909710976cf
PASS: Production Setup fingerprint unchanged
Exit status: 0
```

**Engineering regression and disposable database acceptance are GREEN for `a10edf8618dfb944bde5558c3a9e88e2a1502173`. This does not itself authorize Production mutation.**

## 2. Current Browser-Review Gate

The older `run_setup_session_browser_preview.ps1` is a V0.3-era harness pinned to an older candidate and older disposable migration stack. It must not be used as the exact-candidate acceptance surface for this package.

A current thin launcher now exists:

```text
Setup/Acceptance/run_setup_training_browser_preview.ps1
```

It reuses the already-hardened current-Production-clone preview machinery, pins the accepted candidate `a10edf8618dfb944bde5558c3a9e88e2a1502173`, and applies only migrations 019–021 to the disposable clone before starting the exact candidate application.

The launcher itself is an acceptance artifact added after the accepted code/database candidate; it does not change the candidate's application/database behavior.

Required operator browser review before Production approval:

- Reusable Task Catalog return navigation;
- Verification Queue versus Catalog navigation context;
- Material / Logistics Context;
- safe reconstruction delete behavior;
- Captain / Alternate / Advisor management;
- filter order: All / Unverified / Needs Correction / Verified / Assigned;
- `Mark Assigned` removes the item from the normal actionable queue;
- Assigned filter still exposes preserved history; and
- ASSIGNED does not imply execution or completion.

Operator disposition must be one of:

```text
ACCEPTED
CHANGES REQUIRED
INCOMPLETE / NEED MORE REVIEW
```

Only `ACCEPTED` proceeds to the separate Production deployment gate.

## 3. Reconciliation Vocabulary and Queue Behavior

The 2025 review has two different identities:

```text
annual Setup item
    = the 2025 session occurrence / reconstruction item

Reusable Task
    = durable Setup task knowledge that may carry forward
```

The Reusable Task Catalog is the durable knowledge layer. The left-side 2025 list is a reconstruction/review queue for annual occurrences, not a second independent task catalog.

### ASSIGNED means reconciliation, not execution

`ASSIGNED` means:

> This 2025 annual reconstruction item has been reviewed enough to accept that it belongs to its current reusable task identity.

It does **not** mean performed, completed, scheduled, or operationally verified.

Default behavior:

- ASSIGNED items leave the normal actionable Verification Queue;
- they remain preserved in the 2025 historical session;
- they remain deliberately viewable using the Assigned filter;
- marking Assigned must not delete or rewrite the reusable task; and
- marking Assigned must not create execution/completion history.

### Remaining reconciliation gap

The current candidate accepts an annual item as belonging to its **current** reusable task. It does not yet implement the separate controlled workflow for reassigning/merging an annual item to a **different** reusable task.

Do not simulate that missing workflow with manual identity edits or destructive history cleanup.

## 4. Large 2025 Import Gate

Do **not** bulk-load the next spreadsheet/reconstruction task set until the reconstruction correction/reconciliation workflow is accepted in Production.

The review has already shown that provisional task boundaries can be wrong, duplicated, over-split, under-split, or attached to the wrong reusable identity. Cheap mistakes must remain cheap to correct before the next large import.

Recurring practical Stage-level task families identified during review include:

```text
Locates
Lay Cords
Plug In / Power
Network Connection
Testing
```

These are reviewed patterns, not automatic templates for every Stage.

## 5. Rick Hoffmann Historical-Note Review Rules

Rick Hoffmann's historical Setup notes are **mixed evidence, not one authoritative task source**. A single note may contain reusable knowledge, annual facts, equipment information, Procedure/Wiring instructions, current-asset references, actual-history evidence, and open questions.

Rules established during live review:

1. **Rick writing “I have no idea” is a knowledge-gap marker.** It is not Captain evidence.
2. **Historical crew names do not automatically create Captain, Alternate, or Advisor assignments.**
3. Captain assignments are deliberate reusable knowledge tied to a real `ref.person`.
4. Later Rick hours entries are outside the current reconstruction pass unless scope is deliberately reopened.
5. Procedure-recommended crew counts and elapsed times are reusable/candidate estimates, not confirmed 2025 actuals without separate evidence.
6. Unknown information stays unknown; do not invent actual date, crew count, duration, Captain, quantity, or relationship merely to complete a record.
7. Preserve provenance when reusable knowledge is derived from a historical report, Procedure, leader review, or prior-season actual.

## 6. Candidate Workstream Status

| Workstream | Status |
|---|---|
| Reusable Task Catalog return navigation | **IMPLEMENTED + CONTRACT TESTED; browser approval pending** |
| Verification Queue vs Catalog navigation context | **IMPLEMENTED + CONTRACT TESTED; browser approval pending** |
| Material / Logistics Context | **IMPLEMENTED + CONTRACT TESTED; browser approval pending** |
| Reconstruction-safe delete / migration 019 | **IMPLEMENTED + DISPOSABLE VALIDATED + REPLAY-SAFE; browser approval pending** |
| Captain / Alternate / Advisor / migration 020 | **IMPLEMENTED + DISPOSABLE VALIDATED + REPLAY-SAFE; browser approval pending** |
| ASSIGNED reconciliation / migration 021 | **IMPLEMENTED + DISPOSABLE VALIDATED + REPLAY-SAFE; browser approval pending** |
| ASSIGNED queue/filter behavior | **IMPLEMENTED + CONTRACT TESTED; browser approval pending** |
| Reassign/merge annual item to different Reusable Task | **NOT IMPLEMENTED** |
| Large 2025 spreadsheet/reconstruction import | **BLOCKED UNTIL CORRECTION/RECONCILIATION PACKAGE IS PRODUCTION-ACCEPTED** |
| Controller context in Material / Logistics | **OPEN GAP — must come from authoritative FieldWiring/Controller relationships** |
| Resource editor clarity | **CAPTURED LIVE-EVALUATION DEFECT — verify before closeout** |
| Task/Stage search | **CAPTURED LIVE-EVALUATION FINDING — verify before closeout** |
| Dark-mode contrast | **CAPTURED LIVE-EVALUATION FINDING — verify before closeout** |
| Legacy lower-case `archive` resolution | **CAPTURED LIVE-EVALUATION FINDING — verify before closeout** |
| True Scene vs LOR display-group classification | **CAPTURED SEMANTIC DEFECT — shared Folder Alignment classification remains authoritative** |

## 7. Scene Classification Rule

`ref.lor_scene` is raw/promoted LOR organization evidence; membership in that table alone does not prove a true Setup Scene.

Stage 02 acceptance example:

```text
true Setup Scenes
- 02-Mega Tree
- 02-Fred's Stars

not Setup Scenes / display-group organization
- Abominable
- CharlieInTheBox
- Frosty
- Headlights
- Narwhal
- Signage
- US Flag
- Volunteer Path Lights
```

Setup must consume the shared Folder Alignment classification rule instead of inventing a second Scene definition.

## 8. Material / Logistics Knowledge Goal

The Reusable Task Catalog should expose authoritative operational context needed to replace tribal knowledge:

```text
required Displays / durable assets
    -> current Containers / trailers
    -> current or home locations
    -> supplemental KIT/support Containers where needed
    -> authoritative Controller context from FieldWiring / Controller Inventory
```

The Catalog should explain **why** each dependency is present. Do not hard-code current IDs or locations into Procedure prose merely to make the Setup screen self-contained.

## 9. System Ownership Boundaries

```text
Setup Session
    = annual work/reconciliation + reusable Setup task knowledge

Production Database asset relationships
    = current Display / Container / location truth

Procedures
    = detailed how-to instructions

FieldWiring / Controller Inventory
    = authoritative current controller/wiring relationships

Work Orders
    = defects, repair, correction, and maintenance work that is not normal Setup execution
```

Detailed KIT contents remain outside the current 2026 MVP, but an existing KIT Container can be a real physical Setup dependency.

## 10. Non-Negotiable Production Boundaries

Until explicitly changed by accepted work:

- no 2026 Setup Session has been created;
- no fake Production work days, movement events, or throwaway Setup records should be created for acceptance testing;
- candidate migrations 019–021 are not Production baseline merely because disposable validation passed;
- Production must not be used as the write target for candidate acceptance;
- do not bulk-load the next large 2025 spreadsheet task set before this correction/reconciliation package is Production-accepted;
- Pick List generation remains outside the current live Production workflow;
- Container/Display movement/scanning writes remain outside the current accepted review workflow; and
- no broad table DML should be granted to `fieldwiring_app`.

## 11. Exact Resume Order

Resume from this sequence:

1. Pull the latest branch acceptance artifacts.
2. Run the full `Setup/Application` suite to prove the new browser-preview contract itself is green.
3. Run `Setup/Acceptance/run_setup_training_browser_preview.ps1` on a non-Production preview port.
4. Review the exact accepted candidate in the browser using the checklist in Section 2.
5. Record operator disposition.
6. If changes are required, change candidate code, rerun the full test suite and disposable current-Production-clone acceptance, and repeat browser review.
7. If accepted, follow the mandatory Runbook-First Production gate:
   - database mutation authority: `Gregovate/MSB-Server-Management/docs/server/Production_Database_Change_Deployment_Runbook.md`;
   - Setup runtime authority: `Gregovate/MSB-Server-Management/docs/server/Setup_Production_Runtime.md`.
8. Apply only approved migrations 019–021 under the controlled Production deployment sequence.
9. Advance the `/opt/msb-setup` application checkout to the exact approved target through the accepted Setup deployment pattern.
10. Restart/verify only the required Setup runtime.
11. Run live regression, health, security-boundary, and Production invariant checks.
12. Retain rollback archive and deployment report.
13. Continue 2025 reconstruction/Rick-note review only after the package is accepted in Production.
14. Keep the large spreadsheet import blocked until the correction/reconciliation workflow is live and accepted.
15. Design the separate governed reassign/merge workflow for annual items that belong to a different reusable task.

## 12. Stop Point — 2026-09-08

```text
Production runtime V0.3.4                     = ACCEPTED / UNCHANGED
accepted app/database candidate               = a10edf8618dfb944bde5558c3a9e88e2a1502173
full Setup/Application suite at candidate     = 107 PASS
migrations 019-021 initial disposable apply   = PASS
migrations 019-021 replay/idempotence         = PASS
disposable governed fingerprint replay        = UNCHANGED
Production fingerprint across acceptance       = UNCHANGED
feature-specific/least-privilege assertions    = PASS
current browser-preview launcher               = ADDED AFTER CANDIDATE; CONTRACT CHECK PENDING LOCAL RUN
operator browser disposition                   = PENDING
Production deployment of 019-021               = NOT STARTED
reassign to different reusable task            = NOT IMPLEMENTED
large 2025 spreadsheet import                  = BLOCKED
Rick-note review method                        = DURABLY RECORDED
```

The next engineering action is the current-candidate browser-preview contract test followed by operator browser review. Do not repeat broad Setup reconnaissance or infer review rules from chat memory.

## Related Durable Sources

- [Setup engineering portal](README.md)
- [Production Engineering Handoff — 2026-09-07](Setup_Session_Production_Engineering_Handoff_2026-09-07.md)
- [2025 review operator procedure](../operatorSOP/Review_2025_Setup_History.md)
- [Manager Review Guide](../../../02_Operational_SOPs/Setup/Setup_Session_Manager_Review_Guide.md)
- GitHub issue #122
- Draft PR #125
- `/home/msbadmin/setup-acceptance-reports/Setup_Training_Disposable_20260908T233301.txt`
