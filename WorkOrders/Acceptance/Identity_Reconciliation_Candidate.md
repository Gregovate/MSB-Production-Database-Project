# Work Orders identity reconciliation candidate — #447

| Control | Value |
| --- | --- |
| Status | SOURCE CANDIDATE — NOT DEPLOYED; held for combined release |
| Owner | #447 / #419, commanding #122; People contract #385 |
| Version | V1.1.3-identity-reconciliation |
| Branch | fix/work-orders-identity-reconciliation |
| Main at start | 2d65781d73c761f0320eefd35fc06a5bf7b7dfa9 |
| Migration | 004_work_management_identity_reconciliation.sql |
| Design | [Work Order System Design](../../Docs/02_Production_Database/01_System_Architecture/06_Work_Orders/Work_Order_System_Design.md#october-21--447-authorized-entry-reconciles-existing-human-identity) |

## October 22 — disposable privilege failure correction

Current main reviewed at `1f2a43a85c798aa32acacec94cb298e6b424c0c1`;
its concurrent changes are Setup mail recovery only and do not overlap these files.
PR449 head at review: `66dbeb5996efcbf551b3890d49372a485a8a1447`.

The failed clone was removed and Production fingerprint remained unchanged.
The four-operand identity privilege assertion remains authoritative; do not weaken
it or grant the application direct execution of the shared helper.

Source establishes a clone ACL reconstruction defect: the existing restore uses
`--no-acl`, which omits People005's `REVOKE ALL ... FROM PUBLIC` on
`ref.reconcile_directus_person_identity(text)`. A restored function consequently
has PostgreSQL's default PUBLIC EXECUTE. Migration004 restricts its own wrapper,
but does not reconstruct this restored helper ACL. That makes the helper-execute
operand true on the clone even though the production contract makes it private.
The original failed report did not identify its operand; this source finding is
not a claim that the diagnostic rerun has passed or that Production grants drifted.

Correction uses the existing guarded clone-grant fixture to reinstate the exact
People005 PUBLIC revocation before any app validation. This is clone-only ACL
reconstruction, not a new Production permission system or migration change.
Keep all four privilege checks and their diagnostic DETAIL. Revalidate using the
existing SQL-only profile before another browser setup. Executable current-clone
PASS and subsequent Manager/Crew browser acceptance remain required.

## Confirmed defect and correction

Operator confirmed Steve could enter after the shared reconciler repaired Person
26. Three further safe unlinked Persons were repaired manually. These repairs do
not fix the application. Native entry now commits a narrowly authorized shared
identity reconciliation before checking linked-Person reads. Existing stable
actor/mail/status readers remain read-only. No new table or business permission,
role changes, Directus user creation, mail operation or bulk repair.

## Verification and remaining acceptance

October 21 continuation rechecked current main (unchanged at the baseline above)
and implementation `c8a4af578bc8a1d941ff60fd6c2658075fcdc2d6`: application/read-model
suite again **184 passed**. [People owning checkpoint](../../Docs/02_Production_Database/01_System_Architecture/03_People_and_Identity/engineering/Directus_User_Onboarding_Identity_Contract_2026-09-09.md#october-21--launch-control-reconciliation)
reconciles #395/#403 and consumed real-user fixtures. Draft #403 at
`4d5b61cbfb114c35aebf8b582dba797134d21127` passed 58 local People tests;
its scoped credential experiment remains paused and must not block acceptance
of this existing-user correction.

Publication authorization received October 21: Greg explicitly approved pushing
this existing correction to a feature branch, opening a draft PR under #447/#419
and running engineering tests. This supersedes the earlier source-upload approval
block only. Refreshed origin/main remains `2d65781d73c761f0320eefd35fc06a5bf7b7dfa9`;
no concurrent main changes require integration. No merge, migration execution,
Production mutation or deployment is authorized. Exact published SHA and CI
results are checkpointed in the draft PR, #447 and #122.

This environment has no PostgreSQL/Docker for executable clone acceptance.
Current-clone and browser gates below remain pending; source publication does
not establish acceptance.

Local application/read-model tests: **184 passed**. Setup/GIS: **841 passed**;
FieldWiring: **209 passed**, run in separate processes as in CI. The combined
Work Orders/profile run before the last added runner assertion had 200 passed
and one existing listener cleanup test failed because this environment denies
netlink access. That test
and safety guard are preserved; Linux CI must pass it. Bash syntax passed.
These results are source tests, not PostgreSQL or protected-browser acceptance.

The existing #419 runner applies migration 004 in both native validation and
browser modes. Rollback-only SQL fixture covers unlinked Crew/Manager, original
roles/audit, idempotence, revocation and invalid identity cases with the dedicated
web role. Browser mode deliberately clears only the reviewer's link in the owned
clone, starts the actual app, and checks from a separate database connection that
HTTP entry persisted the audited repair. Refresh must leave the complete Person
row unchanged. Crew uses its personal queue and must get 403 for Manager scope.
No new runner, port, credential mechanism or dump workflow.

Current-Production-clone SQL, actual HTTP repair, Manager/Crew operator review
and CLEAN EXIT are still required. Use the existing
`run_work_management_disposable_browser_preview.ps1` with exact candidate SHA,
8898, explicit existing reviewer and `-V1Browser` role selection, on this branch.
This mode includes identity SQL assertions and browser review in the SAME clone;
do not demand a separate dump merely to repeat these identity assertions.
Respect other active 8898 sessions. Do not run Production migrations from chat.

## Coordinated release hold — operator direction October 21

Greg already has repairs staged and requires avoiding repeated maintenance windows.
Do not release #447 alone by default. Engineering must inventory compatible
accepted changes under #122, reconcile main/source conflicts, validate the combined
candidate and produce the ordered migration/application/rollback manifest BEFORE
requesting one Production approval. One #37 maintenance/freeze/validated snapshot,
approved changes, validation and return ONLINE for the compatible DB batch.
All engineering and disposable/browser review occur while Production stays ONLINE.

Known adjacent vehicles at reconnaissance (not automatic inclusion/acceptance):
- #444: approved wording-only forward release, no DB maintenance required;
  source is already represented in this branch's main baseline.
- #445 / draft #446: shared trailer unload cleanup; rollback-only probe, not an
  accepted Production migration. Must not include until its own acceptance passes.
- #395 / draft #403: missing-Directus onboarding bootstrap remains undeployed;
  separate credentials/runtime/security acceptance, not solved by #447.
- Other #205 launch corrections must be reconciled from their current owning
  records; this list is not a complete inventory or permission to ship them.

Do not rerun migrations 001–003 in Production for this repair. The existing
Server Management #81 upgrade mechanism needs its approved migration manifest
extended to 004 for the eventual combined release. No deployment tooling or
Production host changes were made here. Keep #447 open until actual deployment
and protected first-entry proof, not merely source merge.

## October 22 — confirmed identity PASS; stale mail fixture HOLD

Operator report `WO419_Disposable_Browser_Preview_20261022T144821.txt` at
4325f095 proves Crew/Manager unlinked repair, audit, idempotence, revocation and
negative identity cases PASS. Later V1 validation rejected pre-existing SENT mail
copied from Production. Clone/worktree/listener cleanup and Production fingerprint
and shared-checkout preservation PASS. This is not full acceptance.

Correction contract: compare complete SENT-row snapshots before/after the rollback
fixture, rejecting additions, deletion or modification without erasing historical
mail. Preserve installed Phase2 function definitions: reconstruct only clone ACLs
instead of replaying001. Existing Phase1 fixture deliberately disables capture in
its rollback transaction; Phase2 fixture enables it independently. Emit a bounded
BEGIN/END WO447 RESULT block with candidate, phase results, cleanup/preservation
status and report. No new runner, sender, role model or Production mutation.

## October 22 — Crew preflight authorization correction

Reviewed current main `395b8e9651f4da0d06bfccaff9be189e00a0541a`.
Concurrent shared email authority and Setup documentation changes do not alter
these acceptance files; preserve them at integration. No email behavior changes.

Candidate `8797f32df557ec25f2cf911410467a3da1766901` passed disposable
identity/V1/Phase2 SQL and Manager automated preview with clean teardown. Crew
report `WO419_Disposable_Browser_Preview_20261022T155217.txt` proves personal
identity scope PASS (5 rows), then correct 403 at `all_tickets_query`. The validator
incorrectly required Manager reads from Crew before the identity suite.

Acceptance must require Manager All Work Orders and Create catalog reads, and
require 403 for both from Crew. Unexpected success or another error fails. Keep
existing Crew aging/Create denials and native HTTP identity/refresh checks.
No role, identity, application or SQL authority changes. New candidate needs
disposable Crew acceptance; previous receipts remain attached to their exact SHA.
Production and caller checkout were unchanged; cleanup passed. Browser visual
observations remain unconfirmed. No merge or deployment authorized.

## Combined release preparation

See [the #122 manifest, final gates and rollback plan](Combined_122_Release_Preparation.md).
Component browser acceptance is complete; combined release tooling and #445 repair
remain explicit gates. No Production authorization or final integrated SHA claimed.

## Approved release — final transaction rehearsal

Greg approved #447 release October22. Server99 preflight passed at live180841d5
and shared17c522c4. Approval persists; no repeated permission request for same scope.
Before merge/execution, existing validate_v1 now runs Server99 d81f0da9's exact
transaction envelope on its owned clone, proves uncommitted rollback, committed
installation and clone-only removal of the newly installed entry. It restores
absence before existing004 installation and identity/V1/Phase2 regression. No
Production inverse/restore is supplied. This does not rehearse controller entry
on Production;85 offline tooling tests cover orchestration/containment.
Application/Database payload remains byte-identical to accepted d72789bf. No
repeat visual review requested. Retain exact rehearsal SHA/report and CLEAN EXIT.

## Final rehearsal Manager scope correction

Report20261022T213558 proves Manager reads/aging PASS then NameError at
manager_rehearsal_catalogs. The prior Crew-check extraction made catalogs local
to check_privileged_reads without returning them to validate. Corrected return
and caller assignment; regression exercises validate through the write-rehearsal
boundary. No runtime, migration or release-envelope changes. Approval retained.
