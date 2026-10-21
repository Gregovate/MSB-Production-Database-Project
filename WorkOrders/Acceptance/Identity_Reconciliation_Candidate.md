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

## Confirmed defect and correction

Operator confirmed Steve could enter after the shared reconciler repaired Person
26. Three further safe unlinked Persons were repaired manually. These repairs do
not fix the application. Native entry now commits a narrowly authorized shared
identity reconciliation before checking linked-Person reads. Existing stable
actor/mail/status readers remain read-only. No new table or business permission,
role changes, Directus user creation, mail operation or bulk repair.

## Verification and remaining acceptance

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
