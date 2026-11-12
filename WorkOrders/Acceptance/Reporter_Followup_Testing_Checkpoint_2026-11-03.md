# Reporter follow-up and shared Intake triage — testing checkpoint

Candidate: V1.1.4-wo-reporter-followup, branch
`fix/419-work-order-clarification`, based on main
`0506d4bbd6a21931e0fcc45a84bf63bc31e96975`. Owners #419 / #122 DBG-2026-020.

## Consolidated scope status — November 3 evaluation

The owning Work_Order_System_Design.md section **consolidated correction: shared
triage and reporter communication** now controls the complete requested scope.
This branch includes existing-photo display, cross-history duplicate review/linking,
source-Intake correlation in new assignment emails and readable named activity.
New photo uploads on clarification replies and live recipient verification remain
outstanding; they are not implicitly deferred acceptance.
Do not announce ready for complete operator testing from local test counts alone.

## Implemented candidate

- Active-WO questions by Manager/active assignee; original-reporter reply,
  retained activity, existing mail capture to reporter/question author.
- Migration005 supplies narrowly authorized native command and reporter activity
  read access. Existing assignment, due date and repair state remain unchanged.
- Email deep links read current Intake status before exposing actions; handled
  banner includes recorded handler/time/reason and native WO/current assignees.
- Visible Intake refresh every 15 seconds/on focus and pre-confirmation recheck;
  stale forms disable while keeping entered values. Database locks remain final.
- Safe conflict wording for already-handled records, no raw SMTP status dump,
  actionable email failures retained. Assignment/shared-intake templates explain
  real page actions and shared Manager responsibility.

## Evidence and remaining gates

- WorkOrders/Application, disposable profile/source contracts and unified read
  model tests: 216 passed; one process-cleanup test excluded after it failed on
  this environment's denied netlink inspection. The safeguard was not modified.
- Established Setup suite: 939 passed; FieldWiring: 232 passed on the earlier
  text-follow-up candidate. Subsequent edits are confined to Work Orders.
- Node syntax and git whitespace checks passed.
- Native migration005 and rollback-only follow-up SQL fixture: NOT EXECUTED here
  (no PostgreSQL/owned server clone). Actual Manager/Reporter browser review,
  installed private template reconciliation, CI and production deployment remain
  pending. No real Work Order, Intake, mail, timer or server changed.
- Existing public-form photo references now appear in authorized ticket details.
  WO reads include both its own photo_url and source intake photo_url_raw, so an
  already-promoted WO does not require a production backfill to show its original
  links. HTTPS links open at the existing host; file permissions are unchanged.
  This is reference display, not a new upload implementation. Live form mapping,
  actual photo access and adding new clarification photos still require validation.
- Duplicate review/linking is in local development and has not passed native SQL
  acceptance. Do not use local source tests as evidence of transactional behavior.

## Established acceptance path

Use existing `run_work_management_disposable_browser_preview.ps1` / native
validate_v1 and browser profiles, exact published candidate SHA and approved
reviewer, under existing Server Management runbooks. Existing server runner now
applies migration005 after004 and includes
`wo419_followup_disposable_validation.sql` in native validation. It uses only
rolled-back fixtures and the existing owned clone; no sender is invoked.
Do not run acceptance against production or exercise real WO-429/424 as fixtures.

Browser cases: old email for promoted Intake; closed feedback with reason; two
Managers viewing one pending request; preserved draft after other Manager acts;
failed status read; WO question by assignee; reporter-only answer; notification
intent/recipient; no mutation of assignment/completion; missing contact.

## Publication / release blocker

Git push was rejected by automatic approval review for lack of explicit
publication authorization. No subsequent push or alternate upload was attempted.
User approval is needed to publish this branch to
Gregovate/MSB-Production-Database-Project and open a draft PR. After publication,
check exact-head CI and current-main relationship before test handoff. This is
not a production approval request. Server migration005 deployment must follow
current Server Management runbook and its maintenance/snapshot gates; existing
installer support for005 has not been prepared or claimed.

## Activity presentation correction — WO-425 evidence

Native and preview activity reads resolve actor names from ref.person after the
existing ticket authorization. UI maps stored audit codes to plain-language
labels (progress → Work note added), shows Central time with timezone and omits
seconds. Missing person names say Name unavailable; IDs/codes remain stored for
audit. No historical notes, attribution IDs or completion state are rewritten.
Local Node regression verifies labels, fallback and November CST conversion.
Live browser and database validation remain pending with the full candidate.

## November 3 continuation

- Duplicate confirmation fetches and displays the original WO title; saved records
  show a link to that original. Server rejects self-links, chains, reverse links,
  unauthorized actors and conflicting replays. New rollback-only SQL cases cover
  manager/crew permissions, self/cycle rejection, replay and unchanged original.
- New assignment mail captures the source Intake number. Request/assignment
  subjects include a bounded description; older queued payloads remain renderable.
  Actual recipient routing is preserved pending evidence of the reported mismatch.
- Existing acceptance launcher targets this branch and pins its exact SHA; server
  allowlist includes this candidate without changing port or clone ownership guards.
- Native SQL fixtures have not been executed. The cloud workspace cannot reach
  the private server. Publish the reviewed candidate before the established local
  PowerShell runner can fetch it for SQL/browser acceptance. Do not substitute
  production tests or resend queued messages.

## First native validation HOLD and runner correction

Candidate e492a1a1 on 2026-11-03: disposable read acceptance PASS; native
validation stopped at `WO447 rehearsal baseline entry must be absent` before
identity/V1/Phase2 tests. Report: WO419_Disposable_Browser_Preview_20261103T123939.txt.
Cleanup PASS; Production fingerprint and shared checkout UNCHANGED.

PR475 now requires the installed004 identity entry and reconstructs only its
clone ACL after the no-ACL restore. It does not replay the historical install/
rollback rehearsal or overwrite the deployed identity function. Original #447
branch retains its original rehearsal. Both validation and browser paths use
this installed-baseline handling; identity functional regressions still run.
29 targeted checks pass (one existing listener inspection exclusion). Native
rerun remains required; this source correction is not native acceptance.

## Second native validation HOLD — test fixture availability

Candidate 1c9d24ec: identity PASS; V1 Manager correction/cancel, Directus rights
and suspended-user checks PASS, then HOLD because no unpromoted public Intake
remained. Report: WO419_Disposable_Browser_Preview_20261103T124400.txt. Cleanup
PASS, production fingerprint and shared checkout UNCHANGED.

V1 promotion and Phase2 clarification now each INSERT their own uniquely
identified public-shaped intake inside the existing guarded rollback transaction.
No restored intake is selected, reopened or assigned a different reporter.
Native rerun is still required.

## First Manager browser findings

Operator confirms WO-429 clarification saved and waiting-for-reporter state
appeared. WO-425 activity resolves names and readable dates correctly. Browser
found repeated description and raw stamped progress duplicated in original notes.
Presentation correction shows full description once, selected-ticket ID only,
and hides a stamped note only when timestamp/person/text match loaded progress
activity exactly. Unmatched history and all stored notes remain unchanged.
89 focused local checks pass; corrected browser review pending. Intake-75 can
be tested by opening the preview root with ?ticket=INTAKE-75.

## Handled intake browser review and disposition emphasis

Operator confirms INTAKE-75 shows Rick Hoffmann's promotion, WO-429 and Greg
Liebig assignment without promotion actions. Requested stronger disposition
emphasis. Native browser tunnel then reported CLEAN EXIT. Candidate now places
a bordered, high-contrast handled banner before original evidence, with a large
heading and prominent WO link. Duplicate link/search clutter is removed on
handled intake and the misleading unsaved-entry message is omitted on refresh.
89 focused checks pass; visual confirmation of this update remains pending.
