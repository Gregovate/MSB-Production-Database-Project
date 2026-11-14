# QC area coverage and compact punch list correction

| Document control | Value |
|---|---|
| Owner | Setup engineering, #122 / #205 |
| Status | Candidate implementation in PR490; not deployed |
| Reviewed | 2026-11-13 America/Chicago |
| Baseline | main e55450eb32b03d0aa86e957ec1f9fb3707025014; deployed V0.3.122 |
| Authority | Setup_Scheduling_Board_Contract_2026-09-17.md |

## Observed failure
Greg cannot select Elf on the Shelf scenes or Who Forest to report problems.
He deliberately recorded Who Forest issue37 under Whoville because its location was unavailable.
Do not treat this as operator error or silently move/delete the finding.
The supplied QC page has 32 active areas and six signed-off areas. An earlier screenshot includes Who Forest QC461.
Therefore missing-task coverage and signed-off visibility are separate possible causes. The supplied findings report cannot establish which areas exist without findings.

Current browser discovery matches the final two-minute task name. Database081/082 requires an exact eligible annual task for findings and sign-off. Findings have a non-null task foreign key, and their displayed Stage/Scene is derived from that task. Expanding a dropdown alone is not a valid correction.

## Required behavior
- Reporting must expose the correct current Stage and Scene without requiring Greg to manufacture reusable or annual tasks.
- Controlling November13 clarification: signed-off areas stay green on the main QC list. Before show start, a valid new problem preserves prior signoff evidence and returns the area to yellow. Work Orders start at show start, never at individual signoff.
- Separate finding location from final-check task eligibility. Resolve current location identities from authoritative Stage/Scene relationships; never infer identity by title.
- Existing findings retain IDs, reporters, claimants, completing actors, event timestamps, source intake links and signoff evidence.
- A manager location correction must be audited and transactionally preserve that history. Destination validity and current readiness impact must be checked. No automatic reassignment based on free text.
- One visible Stage heading, Scenes nested below. Multiple final tasks at the same scope remain distinct records internally; determine the purpose of Santa Workshop588/590 rather than deleting either.
- Compact finding presentation: issue, complete problem text, clear status, assigned worker and latest repair note. Full history on demand. Distinguish assigned worker from actual repair recorder.
- Punch list PDF: one heading per Stage/Scene, compact rows, repair-needed items by default, optional awaiting-signoff items; full audit report remains separately available.
- Remove in-box example problems; put brief help outside the empty input.
- Never equate Unclaimed with physically unrepaired: status reflects recorded evidence. No inferred mass completion.
- Existing repaired findings stay available for the auditor's area check; actual unfinished setup work still blocks signoff.

## Required investigation before schema choice
Inventory current Stage/Scene identities against all 2026 annual tasks, qualifying QC tasks, exclusion flags, catalog versus annual scopes and signoffs. Include areas without findings and distinguish excluded tasks, absent tasks and signed-off tasks. Confirm current-season membership before exposing historical reference scenes. Verify Who Forest461 and Elf scene identities; no guessed IDs.
Trace every consumer of finding.task, including command gates, snapshot, report, signoff, concurrency locks and test fixtures before selecting the smallest compatible data change.
The previous source-only assumption does not cover decoupling reporting from task identity.

## Acceptance
On the same reusable disposable clone: report a new finding for a valid scene with no final QC task; it appears under the exact location in repair queue and punch list. Existing findings and signoffs compare unchanged. Signed areas remain visible and accept new pre-show problems; repeat repair and signoff restores green. Manager correction records old/new location and actor without erasing events. Invalid cross-stage scene selection is rejected. Duplicate-scope tasks do not duplicate findings. Repaired items do not appear as unclaimed work. Full-history report remains complete. Print review includes long notes and multiple findings in one scene; browser review covers both themes, large text and mobile.
Production is unchanged until an exact tested candidate is reviewed and authorized using the existing preview and deployment tooling.

## Existing tooling reuse
The existing run_485_qc_report_browser_review.ps1 wrapper selects the exact PR490 branch/version and applies only083 to the disposable current-Production clone through run_setup_disposable_browser_preview.ps1 on8898. No new launcher, service, Production write or replay of081/082. Missing-task coverage and location correction remain unfinished; this candidate addresses existing signed areas and punch-list readability first.

### Confirmed Show Animation coverage
Operator inventory confirms included stage-level final test tasks 471, 472, 479, 473, 474 on stages 91–95 (keys 90–94). Recognize `Plug in Network & Test` only for stages whose names begin `Show Animation`. Reuse these annual records without adding tasks, moving scene scope, or changing names. Apply identical eligibility to discovery, reporting, snapshots, prerequisite gates, and final sign-off. Ordinary network and wiring tasks remain excluded.

### November 14 — correction review; Production approval withdrawn
QC Check and QC Repairs share all-word area/issue/person/notes search, explicit expandable area headers, and the same Edit Issue form. Repairs group findings once per area and initially show Unclaimed; My Repairs and All Repairs remain available. Signed-off areas stay visible in QC Check. Reporter or manager may correct description and destination within the same season before a repair has been recorded; a claim alone does not count as a completed repair. Save preserves finding identity, original reporting, claimant, correction author/time and before/after wording/location. Stale edits are rejected. Moving an unresolved issue into a signed-off area archives its prior approval and turns it yellow; no automatic approval of the source area. Both screens and reports use corrected wording. No live data corrections or deployment have occurred. Prior report layout acceptance remains valid; screen acceptance and release authorization must be renewed.

### Explicit season exception — approved scope, not production authorization
A manager can accept a specific outstanding defect for the current season and create a native Planning Work Order for off-season repair in one transaction. Enter a reason, active Work Order type and due date in the next calendar year or later. Reuse the existing Work Management command, permissions, notification intents and Work Order authority; create no annual Setup dependency. If creation fails, acceptance rolls back. Retrying an accepted issue returns its existing WO. Preserve the defect as unrepaired with approval attribution and WO reference; exclude only explicitly accepted findings from the repair blocker and repair punch list. Full history and QC area retain the accepted exception. All other work/readiness/repair requirements and auditor observation remain mandatory. A normal Work Order never waives QC. No live emails or Work Orders have been created during engineering. The existing disposable environment remains the acceptance boundary.
