# #122 Catalog Scene placement refresh candidate

Date: 2026-10-21. Candidate: V0.3.87-catalog-scene-refresh-r3.
Base main: 180841d5c0c4b3f91ac8a2774af690256900e116.
Status: local regression PASS; disposable/operator acceptance PENDING.

## Correction

Copy, Add Task Here and Move reload saved organization scope before rendering
or destination ordering. The true-Scene decorator forwards refresh options.
No migration or new mutation endpoint is introduced.

## Local evidence

- Full Setup Application pytest: 840 passed.
- Node production-function regression: Copy/Add/Move to Scene and Stage,
  immediate/fresh-load placement, cache behavior and create counts PASS.
- Explicit Stage-to-Scene, Scene-to-Stage and Scene-to-Scene transitions PASS.
  The Scene-to-Scene case starts with stale Sliding Penguins scope and targets
  SnowballBears; all moves retain task identity without creating a copy.

## Operator case and acceptance

Greg reports deleting the Stage-level duplicate. Preserve the remaining
Snowballs task currently shown under 21-Sliding Penguins (previous screenshot
Task 395); intended destination is Scene 21-SnowballBears. Do not delete the
remaining task or create another copy. Saved Production placement and surviving
references have not been queried by this workstream.

Use the established Server Management reusable disposable browser process on
one current Production clone. Verify move to 21-SnowballBears immediately and
after full reload, preservation of task identity/materials/prerequisites, and
Copy/Add Task Here with disposable test tasks. Check Stage and Site-wide
behavior remains intact. Finish CLEAN EXIT. Production approval, deployment,
protected browser acceptance and repository closeout remain pending.

The duplicate-late Report Work finding remains separate under #205 and is not
changed by this candidate.


## First operator preview — FAIL

Greg reports all Scene groups disappeared; screenshot shows their tasks grouped
under Stage-level. Initial candidate a5ed4df00f1a4f5bf5b191862e9d74cf872bd01d
is rejected. Do not deploy it. Preview CLEAN EXIT receipt remains pending.

The true-Scene normalizer ran before the asynchronous Stage bootstrap, classified
all Scenes as invalid, then destructively cached that empty result. The revised
normalizer defers classification until Stage metadata is available. Regression
now uses the real classification/normalization functions instead of a stub and
covers organization-before-Stages startup, all Stage/Scene move directions,
Stage-to-Stage Copy/Move and ordinary caching. Drag edge-scroll remains an
explicit operator browser acceptance requirement, not an automated PASS claim.


## Second operator preview — movement PASS, edge-scroll FAIL

First preview CLEAN EXIT confirmed. Greg reports Scenes restored and moving the
Snowballs task PASS at 3442dfe908f5b15a7f7ab19fb2de9602f6793da0. Catalog drag
edge-scroll FAIL with search `polar` and after clearing search. Overall
acceptance CHANGES REQUIRED; second preview CLEAN EXIT not yet confirmed.

Revision 3 adds Catalog-only animation-frame edge-scroll for the actual nearest
scrollable ancestor or document scroll owner, accounting for the sticky header.
Continues with a stationary pointer; stops on drop, drag end, leaving Catalog or
window blur. It does not change drop targets, move commands, scheduler scrolling,
search visibility or prerequisite behavior. Node scroll-loop tests cover page and
panel up/down, stationary pointer, center, cleanup and unrelated drags. Actual
browser search-filtered and unfiltered scroll acceptance remains pending.


## Operator approval and source integration

Revision3 filtered/unfiltered drag scrolling PASS and CLEAN EXIT reported.
Greg explicitly approved merge and maintenance-controlled deployment. PR440
merged as 91f638b72bccda01b2b9c6b7b4678c5263bd41a6. Accepted application stays
pinned to e3c39f2781b5a97648dce1f00965110becd2edd6; deployment tooling and later
documentation do not advance the application target. Source promotion uses
run_setup_catalog_scope_deploy.ps1 from merged clean main. Current expected
baseline is the recorded V0.3.84 deployment target
7740498e6602f36c8cdfd384791bbafaab71ee9e; any actual drift stops preflight.
Existing maintenance controller owns ON/freeze/promotion/OFF and preserved data.
No migrations or database rollback dump. 31 deployment orchestration tests PASS.
Production receipt/protected browser acceptance and local cleanup remain pending.
