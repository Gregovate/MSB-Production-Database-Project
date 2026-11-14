# QC area coverage and compact punch list correction

| Document control | Value |
|---|---|
| Owner | Setup engineering, #122 / #205 |
| Status | Engineering investigation; not implemented or deployed |
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
- Show signed-off areas as discoverable locations with explicit readiness and the existing Work Order handoff. Do not silently reopen signed evidence or weaken the agreed post-signoff boundary.
- Separate finding location from final-check task eligibility. Resolve current location identities from authoritative Stage/Scene relationships; never infer identity by title.
- Existing findings retain IDs, reporters, claimants, completing actors, event timestamps, source intake links and signoff evidence.
- A manager location correction must be audited and transactionally preserve that history. Destination validity and signed-off constraints must be checked. No automatic reassignment based on free text.
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
On the same reusable disposable clone: report a new finding for a valid scene with no final QC task; it appears under the exact location in repair queue and punch list. Existing findings and signoffs compare unchanged. Signed areas remain searchable with explicit handoff. Manager correction records old/new location and actor without erasing events. Invalid cross-stage scene selection is rejected. Duplicate-scope tasks do not duplicate findings. Repaired items do not appear as unclaimed work. Full-history report remains complete. Print review includes long notes and multiple findings in one scene; browser review covers both themes, large text and mobile.
Production is unchanged until an exact tested candidate is reviewed and authorized using the existing preview and deployment tooling.
