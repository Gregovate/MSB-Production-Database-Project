# Sequencing-only preview catalog releases — 2026-10-31

Owner: #81 publication / #299 PC consumption, draft PR300. Existing branch
agent/issue-299-lor2db-2pc-sync-phase1; main reconnaissance
cfde519487e933bfa8e49f80c509f81921fd6f91, candidate parent
2868453373ac3e3b732c5ab2a35ccaa91b207ba5. No production deployment yet.

## Accepted operator workflow

Greg exports approved edits directly to the versioned master. The same UUID is
the same preview even when Name and export filename acquire a new date. Move
the old export outside the controlled folder when renaming; two files sharing
one UUID are ambiguous and remain blocked. Review then Publish once for the
batch. Programmers update via existing1.1.1 updater. No new client installer,
parser execution or ingest is required for these sequencing-only changes.

## Database comparison vs distributed content

Comparison V2 is explicit inside review identities; catalog wire POLICY remains
MSB_PREVIEW_CATALOG_V1 because its acceptance/actor/digest/baseline contract has
not changed. Old clients1.1.x can consume approved schema2 documents. Full raw
file SHA256 and manifest cover ALL bytes, including ignored sequencing content.
PC semantic comparison still detects and distributes all group/motion/name edits;
this change does not add consumer exclusions or discard sequencing content.

V7.0.11 parser examines PropClass and Scene, not PropGroup/MotionRowDefaults/
PropViews. V2 excludes only known sequencing subtrees at their expected parent
positions: root PropGroup with member/motion-row children, root PropViews with
PropView/ViewMember, and direct PropClass MotionRowDefaults/MotionRowDefault.
Unexpected descendants remain protected, including hidden Scene/PropClass.
Root Name may change, but parser-derived StageID must remain unchanged. UUID,
Comment identity, wiring/device/master links, physical props, scene membership
and their order, and unknown XML remain protected. Existing approved exceptions
for direct channel Name with nonblank Comment and MasterDimmable remain.

UUID matching replaces filename-keyed catalog matching. New filenames replace
the prior UUID entry; added/removed UUID sets still require contract review.
Changes include UUID, prior filename/name and current filename/name for audit.

## Existing immutable evidence

Existing baseline records contain only V1 hashes; never rebase them from altered
master files. Supplemental, hashed comparison anchors bind policy, baseline raw
SHA and preview UUID. Review can create one only from byte-identical registered
master content, or an independently supplied published export with a pinned
reviewed raw hash/projection. Unknown legacy baselines retain V1 checks until
their original bytes are supplied or an exact unchanged review establishes V2.
No baseline, prior review, publication or pointer is rewritten or reset.
New comparison policy participates in review IDs, invalidating pre-update reviews.
Current publication and parent-chain integrity remain unchanged.

## Actual file evidence / tests

Published August20 Revision137 and October30 Revision142: same preview UUID,
719 identical physical PropClass definitions apart from MtCrumpet MotionRowDefaults,
18 identical Scene definitions. Changes include Cave Door row, Cave region,
Dancing Forest group removal, Northern Lights group membership/tag, PropViews,
root label/Revision/background preference. No timing-grid elements exist in this
export. Actual files have equal V2 contract projections and different raw SHA.
Private source files stay outside git. Actual legacy-baseline -> dated filename
rename -> Review -> Publish -> Current pipeline passes. 43 unittest executions
include prior protections plus stage reassignment, hidden Scene, unsupported
legacy rebase, and exact-byte anchor adoption.

## Deployment / acceptance

Only Windows preview_catalog.py changes in production; authenticated runner task
restart required to clear Python import cache. LinuxAPI, frontend, PC updater,
DPAPI, task configuration, parser, ingest and catalog records are unchanged.
Update-Catalog-Sequencing-Policy.ps1 stages immutable git bytes, checks old/new
hashes, backs up module, uses existing idle-guarded Stop/Start and Status, and
restores module on failure. No native PowerShell execution was available in this
container: operator-side script/runtime validation remains required. Do not call
this deployed or accepted before actual task and browser Review proof.

After install, Review the changed master; inspect filenames and changes, approve
Publish, then validate one programmer PC retrieves and installs the accepted
preview. Close/reopen LOR and repeat ADD0/REPLACE0. No bypass, ingest, policy reset,
new baseline from changed files or silent catalog publication.
