# Setup 2025 Live Review Work Ledger — 2026-09-08

| Document Control | Value |
|---|---|
| Document Type | Engineering Live-Review Work Ledger |
| System | Production Database — Setup Session |
| Status | CURRENT WORK LEDGER — candidate changes on draft PR #125; Production unchanged |
| Owner | MSB Production Database engineering |
| Last Reviewed | 2026-09-08 |
| Related Work | Issue #122; draft PR #125 |

## Purpose

Preserve the exact current Setup live-review workstream, interpretation rules, candidate-versus-Production boundary, completed candidate work, unresolved items, and resume point discovered while reviewing the real 2025 Historical Verification session.

This ledger exists because the 2025 review generated several related workstreams at once — navigation, reconciliation of annual items into the Reusable Task Catalog, Captain/knowledge-owner maintenance, reconstruction correction, material/logistics context, and review of Rick Hoffmann's historical notes. Those findings must not be reconstructed from conversation history.

This document supplements the accepted Production handoff. It does **not** replace the V0.3.4 Production baseline in `Setup_Session_Production_Engineering_Handoff_2026-09-07.md`.

## 1. Safety and Acceptance Baseline

Production remains on the previously accepted Setup V0.3.4 runtime. The current training/reconstruction candidate on draft PR #125 is **not deployed to Production**.

Current candidate before the next cleanup pass:

```text
branch = agent/setup-session-production-foundation
candidate SHA = e44c903fc423733c2caf9a752b20f705a59e8423
```

The candidate contains migrations and UI/API work for:

```text
019 = reconstruction-safe task delete
020 = Captain / Alternate / Advisor management
021 = ASSIGNED reconciliation state
```

The disposable-clone acceptance path has already established the intended safety boundary:

```text
Production database reads = pg_dump + SELECT only
all acceptance writes      = disposable PostgreSQL clone only
Production fingerprint     = unchanged after disposable acceptance
```

The disposable candidate validation passed migrations 019–021, the targeted reconstruction/Captain/ASSIGNED checks, and least-privilege assertions while leaving Production unchanged.

The remaining code-quality gate at the stop point is:

```text
Setup/Application full suite = 83 passed / 15 stale pre-existing failures
```

**Do not deploy the current candidate until those 15 stale tests are corrected and the complete Setup/Application suite is green.** After any test/code correction, rerun disposable acceptance against the new exact candidate SHA before any Production promotion.

## 2. Reconciliation Vocabulary and Left-Side Queue Behavior

The 2025 review has two different identities that must not be conflated:

```text
annual Setup item
    = the 2025 session occurrence / reconstruction item

Reusable Task
    = durable Setup task knowledge that may carry forward
```

### ASSIGNED means reconciliation, not execution

`ASSIGNED` is a **reconciliation state**. It does not mean work was performed, completed, scheduled, or verified as an operational fact.

It means:

> This 2025 annual reconstruction item has been reviewed enough to accept that it belongs to its current reusable task identity.

The intended filter order is:

```text
All
Unverified
Needs Correction
Verified
Assigned
```

Default queue behavior:

- `ASSIGNED` items leave the normal actionable Verification Queue;
- they remain preserved in the 2025 historical session;
- they remain deliberately viewable using the **Assigned** filter;
- marking Assigned must not delete or rewrite the reusable task;
- marking Assigned must not create execution/completion history.

Candidate source now implements this behavior through `setup_assigned_review.js`, including **Mark Assigned**, default hiding of Assigned rows, and the Assigned filter.

### Important remaining reconciliation gap

The current candidate only accepts an annual item as belonging to its **current** reusable task.

It does **not** yet implement the controlled workflow for:

```text
annual item currently points to reusable task A
    -> reviewer determines it actually belongs to reusable task B
    -> reassign / merge the annual item into reusable task B
```

Migration 021 deliberately leaves that workflow separate. Do not simulate reassignment by deleting useful history or manually editing identity relationships outside a governed command.

## 3. Rick Hoffmann Historical-Note Review Rules

Issue #122 already records the architectural rule that Rick Hoffmann's historical Setup notes are **mixed evidence, not one authoritative task source**. A single note can contain reusable task knowledge, annual facts, actual-history evidence, equipment information, Procedure/Wiring instructions, current-asset references, and open questions.

The review must classify and consolidate the evidence rather than copy the note wholesale into a reusable task.

### Evidence classes already established

Rick's historical material may contain:

- reusable practical Setup work and estimates;
- reusable sequencing/staging guidance;
- reusable Captain/crew/equipment knowledge;
- annual/session resource sourcing or availability facts;
- recurring non-Stage Setup support tasks;
- actual-history evidence and lessons learned;
- Procedure/Wiring technical instructions that belong in their responsible how-to subsystem; and
- references to current Displays, Containers, or locations whose current truth belongs in the Production Database.

Current Display-to-Container and location truth must be resolved from the database at use time rather than copied from an old note into permanent Setup text.

### Additional live-review interpretation rules

The following rules were established during the 2025 review and are now made durable here:

1. **Rick writing “I have no idea” is a knowledge-gap marker.** It is not evidence that Rick, the named crew member, or anyone else is the Captain/knowledge owner for that task.
2. **Crew names are historical evidence only unless separately reviewed as reusable leadership knowledge.** A person appearing in a 2025 crew list does not automatically create a `CAPTAIN`, `ALTERNATE`, or `ADVISOR` assignment.
3. **Captain assignments are deliberate reusable knowledge.** They must identify a real `ref.person` and represent who can lead, back up, or advise on the reusable task.
4. **Later hours entries from Rick are outside the current reconstruction pass.** Do not silently fold those later estimates into the current 2025 review unless that scope is deliberately reopened.
5. **Procedure-recommended crew counts and elapsed times are reusable/candidate estimates, not confirmed 2025 actuals.** Historical actual crew/time fields require actual 2025 evidence.
6. **Unknown information stays unknown.** Do not invent an actual date, crew count, duration, Captain, resource quantity, or task relationship merely to make a record look complete. Leave it UNVERIFIED or mark NEEDS CORRECTION as appropriate.
7. **Preserve provenance.** When a reusable estimate/rule is derived from a historical report, Procedure, leader review, or prior-season actual, retain enough source context to explain why it exists without copying the entire source note into the task.

These rules are part of the review method, not one-off exceptions for a single Rick note.

## 4. Candidate Workstream Ledger

| Workstream | Candidate status | Production status / remaining gate |
|---|---|---|
| Reusable Task Catalog return navigation | **IMPLEMENTED + CONTRACT TESTED** | Not yet accepted as the Production baseline. Opening a task from the Catalog remembers its origin and provides `← Back to Reusable Task Catalog`, returning to/highlighting the same Catalog row. |
| Verification Queue vs Catalog navigation context | **IMPLEMENTED + CONTRACT TESTED** | Opening from the Verification Queue deliberately clears Catalog-return context. |
| Material / Logistics Context in Catalog | **IMPLEMENTED + CONTRACT TESTED** | Candidate resolves Displays, current Containers, supplemental support/KIT Containers, uncontained Displays, location context, and why an asset is included. Controller context is still an explicit gap and must come from authoritative FieldWiring/controller relationships. |
| Reconstruction-safe delete | **IMPLEMENTED + DISPOSABLE-CLONE VALIDATED** | Migration 019/API/UI/test path exists. Hard delete is limited to reconstruction mistakes with no meaningful operational/planning history and fails closed on unknown future FK dependencies. Not yet Production promoted. |
| Captain / Alternate / Advisor | **IMPLEMENTED + DISPOSABLE-CLONE VALIDATED** | Migration 020/API/UI/tests exist. Uses `ref.person`; no free-text Captain identity; crew names do not infer leadership. Candidate includes the explicit primary-key conflict-target fix. Not yet Production promoted. |
| ASSIGNED reconciliation state | **IMPLEMENTED + DISPOSABLE-CLONE VALIDATED** | Migration 021 accepts ASSIGNED as a reconciliation state. Not yet Production promoted. |
| ASSIGNED left-side queue behavior | **IMPLEMENTED + CONTRACT TESTED** | `Mark Assigned`, default queue removal, and Assigned filter are in candidate source. Browser acceptance remains part of post-promotion validation after full test suite is green. |
| Reassign/merge annual item to a different Reusable Task | **NOT IMPLEMENTED** | Separate governed workflow still required. |
| Resource editor clarity | **CAPTURED LIVE-EVALUATION DEFECT** | Current UX can make adding an existing catalog resource look like editing the selected assignment. Must clearly distinguish current requirements, add existing resource, update assignment, and create new catalog resource. Verify current branch status before closeout. |
| Task/Stage search | **CAPTURED LIVE-EVALUATION FINDING** | Verify current branch and Production behavior before declaring resolved. |
| Dark-mode contrast | **CAPTURED LIVE-EVALUATION FINDING** | Signed-in/access badge, Catalog surfaces, and Needs Correction warning were reported. Verify current branch and Production behavior before closeout. |
| Google editable-source legacy `archive` capitalization | **CAPTURED LIVE-EVALUATION FINDING** | Resolver must tolerate historical lower-case `archive` on Linux/rclone. Verify current branch and Production behavior before closeout. |
| True Scene vs LOR display-group classification | **CAPTURED SEMANTIC DEFECT** | Setup must reuse the established Folder Alignment classification contract rather than treating every `ref.lor_scene` row as a Setup Scene. Verify candidate/acceptance status before closeout. |

## 5. Scene Classification Rule That Must Survive Closeout

`ref.lor_scene` is raw/promoted LOR organization evidence; membership in that table alone does not prove a true Setup Scene.

The established Folder Alignment contract distinguishes structured scope from panel/display-group organization. For the Stage 02 acceptance example:

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

Setup must consume the shared deterministic classification rule instead of inventing a second Scene definition or rewriting raw LOR scene data to satisfy the UI.

## 6. 2025 Reconstruction Data Rules

The 2025 dataset contains several evidence qualities and must be reviewed accordingly.

### Provisional reconstruction

Many seeded tasks were intentionally provisional. Their existence, task boundary, reusable scope, actual date(s), crew, duration, resources, and notes may still require review.

A provisional row is not proof that the task was performed exactly as seeded.

### Controlled-workbook / Procedure candidates

Some tasks were reconstructed from controlled workbook gaps and current Procedures. Those are useful evidence for the reusable task definition but do not automatically prove the 2025 actual values.

Representative examples already visible in the reconstruction include:

- Mega Tree light preparation: Procedure evidence suggests a reusable crew/time estimate; actual 2025 values still require evidence;
- Mega Tree trailer positioning/structural readiness: reusable equipment/crew guidance exists, while exact historical elapsed time remains reviewable;
- hanging 48 Mega Tree light strings: Procedure recommends a crew and lift configuration, while Captain and actual elapsed time still require verification;
- Fred's Stars: confirmed as a real Setup task with normal lift need, while duration remains to verify; and
- tree-wrap work: many tasks can run independently/in parallel, making Captain availability and volunteer count important planning constraints.

### Browser-review corrections

Tasks added or reorganized during the live 2026 Manager review are real Production reusable knowledge changes when deliberately saved, but their 2025 historical details can still remain unverified.

Do not turn the reconstruction cleanup exercise into fabricated historical precision.

## 7. System Ownership Boundaries During Review

Keep the following ownership rules intact while consolidating historical knowledge:

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

Do not copy current asset IDs/locations into Procedures or historical notes merely to make the Setup screen self-contained. Resolve authoritative relationships when needed.

Detailed KIT **contents** remain outside the current 2026 MVP, but the existing KIT **Container** can be a real physical Setup dependency and may need a supplemental reviewed reusable relationship when Display links cannot derive it.

## 8. Non-Negotiable Production Boundaries

Until explicitly changed by accepted work:

- no 2026 Setup Session has been created;
- no fake Production work days, movement events, or throwaway Setup records should be created for acceptance testing;
- candidate migrations 019–021 are not Production baseline merely because disposable validation passed;
- Production must not be used as the write target for candidate acceptance;
- Pick List generation is still outside the current live Production workflow;
- Container/Display movement/scanning writes are still outside the current accepted review workflow; and
- no broad table DML should be granted to `fieldwiring_app` to make browser operations easier.

## 9. Exact Resume Order

Resume from this sequence rather than reconstructing the prior chat:

1. **Fix the 15 stale/pre-existing Setup/Application tests.** Preserve the intended current contracts; do not weaken tests merely to obtain green output.
2. Run the complete Setup/Application suite and require a clean pass.
3. Pin the resulting exact candidate SHA and rerun the disposable-clone acceptance wrapper.
4. Require migrations 019–021, safe delete, Captain management, ASSIGNED behavior, least privilege, and unchanged Production fingerprint to pass again.
5. Re-audit the unresolved live-evaluation findings in this ledger — especially resource-editor clarity, Scene classification, search, dark-mode contrast, and legacy `archive` resolution — and record whether each is fixed, still open, or separately deferred.
6. Only after the full test/acceptance gate is clean, prepare the controlled Production promotion for migrations 019–021 and the associated application assets.
7. Perform authenticated browser acceptance for:
   - Catalog return navigation;
   - material/logistics context;
   - safe reconstruction correction behavior;
   - Captain/Alternate/Advisor management;
   - exact status filter order;
   - `Mark Assigned` leaving the default queue;
   - Assigned filter/history visibility; and
   - no accidental execution/completion semantics from ASSIGNED.
8. Update operator documentation only after the candidate behavior is actually deployed and accepted. Do not document candidate-only controls as already live Production behavior.
9. Continue the Rick-note / 2025 reconstruction review using the interpretation rules in this ledger.
10. Design the separate governed reassign/merge workflow when a 2025 annual item belongs to a different reusable task.
11. Keep issue #122 and PR #125 open until real remaining work and acceptance gates are resolved; then normalize the stacked Setup PR lineage without losing history.

## 10. Stop Point — 2026-09-08

```text
Production runtime V0.3.4                     = ACCEPTED / UNCHANGED
candidate branch                              = agent/setup-session-production-foundation
candidate SHA before stale-test cleanup       = e44c903fc423733c2caf9a752b20f705a59e8423
Catalog return navigation candidate           = IMPLEMENTED
material/logistics Catalog context candidate  = IMPLEMENTED
safe reconstruction delete candidate          = IMPLEMENTED / DISPOSABLE VALIDATED
Captain management candidate                  = IMPLEMENTED / DISPOSABLE VALIDATED
ASSIGNED database state candidate              = IMPLEMENTED / DISPOSABLE VALIDATED
ASSIGNED queue/browser candidate               = IMPLEMENTED / CONTRACT TESTED
reassign to different reusable task           = NOT IMPLEMENTED
full Setup/Application suite                   = 83 PASS / 15 STALE FAILURES
Production deployment of this candidate        = BLOCKED UNTIL FULL SUITE GREEN
Rick-note review method                        = NOW DURABLY RECORDED HERE
```

The next engineering session should start with the stale-test cleanup and this ledger. It should not repeat broad Setup reconnaissance or infer missing review rules from chat memory.

## Related Durable Sources

- [Setup engineering portal](README.md)
- [Production Engineering Handoff — 2026-09-07](Setup_Session_Production_Engineering_Handoff_2026-09-07.md)
- [2025 review operator procedure](../operatorSOP/Review_2025_Setup_History.md)
- [Manager Review Guide](../../../02_Operational_SOPs/Setup/Setup_Session_Manager_Review_Guide.md)
- GitHub issue #122 — annual Setup Session engineering and live-evaluation findings
- GitHub issue #122 comment `5560096460` — historical Rick Hoffmann notes are mixed evidence, not one task source
- Draft PR #125 — current Production foundation / live-review candidate implementation
