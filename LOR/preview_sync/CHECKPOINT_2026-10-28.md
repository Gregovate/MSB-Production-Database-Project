# Checkpoint — restricted official preview catalog / PC updater

Date: 2026-10-28. Continue #299 branch agent/issue-299-lor2db-2pc-sync-phase1,
draft PR300; #81 owns catalog publication. Do not switch/recreate prior work.

## Identified application checkpoints

- 1.1.0 source:4ceaf640cee63c18aa3cf019093b002e1d7635cb.
- 1.1.0 installer checkpoint:7ba3e4055c74711710753a9123becb64f1bc905e.
- Programmer ZIP SHA256:09ec784278757ccf4028f968841fbaf565798c43ca85e5522802ff0da5990709.
- Source-only API V0.6.7 / Windows runner V1.8.0 / PC1.1.0 candidate.
- This checkpoint adds the exact-candidate copied-input browser review and
 missing-published-pointer fail-closed check. Review artifact records its exact
 source SHA in SOURCE.json; no uncommitted runtime is distributed.

## Accepted evidence and remaining gap

Actual laptop1.0.8 apply:2 controlled replacements,0 additions,8 unmanaged
preserved; installed SHA equals reviewed candidate; backup path logged. Native
focus and prepared->cancel/apply log append proven. Post-LOR repeat originally
showed presentation-only changes; root Brightness and LastSelectedSceneId are
now excluded from PC controlled comparison and preserved through replacements.
Controlled export7->0 changed only root Brightness, no Revision change.

Later local Rotary-Trees export58 turns eight HW-Flood MasterDimmable flagsFalse.
This is real PC-distribution content but not a Display/wiring identity change.
ChannelName is mutable metadata, Comment is Display identity. Captured snapshot
metadata is not synonymous with a requirement for DB ingest. #81 now provides a
restricted preview-only catalog path using a narrow proof of protected-contract
preservation. Unknown/identity/wiring/scene changes require contract review.

Greg explicitly keeps exporting directly into the master folder. Only designated
publishers may approve the catalog afterward; Crew may consume only. First
register unchanged accepted master bytes before the new export. Greg confirms
the new preview has NOT been copied to master and is waiting for deployment.
Do not promote source/ingest or rewrite the master during preparation.

## Production facts

Live backend remains prior deployed V0.6.6 in /opt/lor-preflight. Production static
PC page remains stale1.0.2; new installer/page/catalog actions are not deployed.
Permanent runner is PRINT-SERVER192.168.5.56, Print Service task/profile, existing
C:\MSB_LORRunner runtime. Server Management owns source/config/restart/rollback.
New feature requires coordinated Linux API, existing Windows runner, static page
and client updates. No migration/grant/DB write or database maintenance window.
Automatic app updates remain separate unimplemented work; website download is a
versioned self-service installer, not a silent update engine.

## Resume point

1. Complete exact-candidate disposable browser review using the new engineering
   catalog review ZIP. Wrapper reads existing G: master into a temporary copy ZIP,
   clone launcher validates that against latest completed source. No Production
   source/service/runner/DB/PC mutations. Use localhost8898; don't pick new ports.
2. Review unchanged baseline, upload local new export into disposable master,
   review/publish new catalog, inspect short programmer page wording. Do not
   install/launch updater from the clone. Press Enter for ownership-safe cleanup.
3. Record operator disposition before explicit Production deployment approval per
   Server Management's Pre_Production_Browser_Review_Runbook.md. Unit/mock/HTTP
   fixture tests are not operator browser acceptance.
4. Prepare/review bounded two-host source-only rollout and rollback from exact SHA.
   Keep publisher allowlists distinct from Crew; private local Windows evidence
   ACLs; no task re-pairing or source/reset of unrelated services.
5. Upgrade participating clients before first schema2 Publish (old clients block).
   Register unchanged real master; Greg exports; Greg reviews/publishes.
6. Real publisher/negative Crew auth, ShowPC ADD34/REPLACE0/unmanaged13 expected,
   explicit apply, LOR reopen/usability and repeat0/0 with backup/audit remain.

#299/PR300 remain open/draft. No general Production release acceptance claimed.


## First catalog review HOLD / r2 correction

Actual attempt /tmp/msb-lor2pc-review.1fEgXNGG failed startup because catalog
source_digest used the VERSION CHECKER signature rather than the PARSER source
manifest digest frozen by ingest. This is an engineering defect, not evidence
that Greg changed the master. Earlier parity fixture used the wrong reference.
Do not deploy catalog code from4ceaf640/0ccf9623 without this correction. The
PC installer1.1.0 remains unchanged: its source digest was already correct.

Current correction matches actual parser source_manifest_sha256, with actual
parser-function AST parity, multifile/Unicode/BOM/order and known C# fixture
checks. Real API->runner fixture now generates expected evidence independently.
First browser review is FAIL/HOLD, not accepted. Use the new immutable
LOR2PC-Catalog-Review-1.1.0-r2.zip; exact corrected source is in SOURCE.json.
Readiness failure now prints retained browser.log and records source-validation
JSON with expected/observed/count/per-file hashes. Existing Windows PowerShell
plus child process -ExecutionPolicy Bypass keeps errors visible without policy
changes. Corrected operator browser/production/native acceptance remain pending.
