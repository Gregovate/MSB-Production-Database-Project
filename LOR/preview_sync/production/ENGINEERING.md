# LOR2PC candidate engineering

Filename: ENGINEERING.md · Revision 2 · 2026-10-27 · #299 / draft PR #300
Status: DEVELOPMENT CANDIDATE 1.0.2 — NOT DEPLOYED OR PRODUCTION ACCEPTED

## Repository reconciliation

Work continues on `agent/issue-299-lor2db-2pc-sync-phase1`.
Checkpoint `7a02b59eef80ae2dc02e2047257c7b3c395623c7` was read first.
Remote main `43077980051ab40005ce66ecfd38ef38c6fdad35` was merged deliberately
in `e2195abf`; the old branch was 2094 main commits behind.
Draft PR #472 / branch `release/299-lor-preview-sync-v1.0.0` was reviewed.
Its WIP updater was recovered as the starting point, not accepted as release
quality. In particular its timestamp fallback and UNC archive discovery were
removed. #300 remains the requested working PR; #472 has not been closed.
Historical ZIPs remain unchanged. Current text source lives here.

## Defect and authority

Run 32 / ingest 74 COMPLETED/PASSED and Rotary-Trees Revision 57 are recorded
operational evidence in the checkpoint, not independently verified live here.
The deployed CSV requirement still fixes content to older extraction-era hashes.
A later accepted run cannot advance that separate authority, causing the block.

#81 owns `LOR2DB/Application/current_source.py` and GET `/current-source`.
It reads the latest COMPLETED run (completion timestamp, run ID tie breaker)
and its frozen source inventory in one SQL snapshot. Missing hash, validation,
publication, inventory or exact version-folder evidence BLOCKS; it never falls
back to an older completed run with more convenient evidence. REPORTING,
CANCELLED and COMPLETED_WITH_EXCEPTIONS are not accepted sources.
The source digest and SQLite digest are already frozen by migration 0031.
No schema is changed. Migration 0043 grants the existing backend role EXECUTE
on the shared read-only capability resolver. This is DATABASE-CHANGING permission
work requiring the approved maintenance/snapshot boundary. Do not substitute
broad Directus-table grants. Current-source queries the already-granted frozen
source table rather than requiring an additional view grant.

#299 consumes the contract, matches PreviewID/name/revision inventory and the
whole-folder parser digest, and merges only controlled identities. Revision is
metadata, never winner selection. Unmanaged XML fragments are preserved.
Source identity, source bytes, local file and candidate are rechecked after review.
Missing digest has no file-mtime fallback. Current digest implementation rejects
non-ASCII source filenames until Unicode casefold ordering is cross-tested.

## Browser authentication and PC handoff

Crew access is checked through the existing active Directus role/policy resolver
`ref.setup_browser_capabilities(email)`: Production Crew, Manager or Administrator.
Volunteer/unknown/inactive users fail closed. Operator allowlisting is unchanged
for parser, ingest, reconciliation and approval routes. The existing protected
proxy remains responsible for the authenticated Cloudflare email header; do not
expose this backend directly or accept client-supplied identity headers.

The separate browser surface is `/lor2db/pc/`, linked from the landing page.
The landing page's administrator-only status requests may still be denied to crew;
crew can use `/lor2db/pc/` directly without granting administrator API access.
Inspect the live Cloudflare application/path policies before opening this surface.
No live access settings were read or changed in this workstream.

A per-user registered `msb-lor2pc:update` protocol launches a fixed local updater.
Protocol URI arguments are never interpolated into a command. The updater opens
the default browser to the protected PC page with a random loopback port and
64-character nonce in the URL fragment. The page fetches the source contract
using its own existing browser login and relays ASCII JSON to the PC listener.
No login cookie, JWT, database credential or administrator token is transferred.
The listener binds only 127.0.0.1, validates exact Host/Origin/path, restricts
method/body size, times out and closes after one document. Review completion opens
a fresh browser handoff to check that accepted evidence is still current.

Windows browser Local Network Access/private-network permission, custom-protocol
confirmation, proxy route behavior and authentication redirects REQUIRE real PC
acceptance. Do not disable browser protections to make the handoff work.
The updater blocks if authentication or handoff fails. Native TCP/HTTP transport now passes an actual loopback socket test (Linux
PowerShell); real Windows browser integration remains unaccepted. Keep release blocked.

## Source-only preparation and installation boundary

`Prepare-LOR2PC-Candidate.py OUTPUT_DIRECTORY` runs only on a clean committed
checkout, prepares named runtime files and writes exact SHA/version/hash metadata.
It does not deploy, register a protocol or touch any preview library.
`Install MSB PC Preview Updater.vbs` invokes `Install-LOR2PC-Launcher.ps1`, which
checks identity, installs under the user's LocalAppData and registers HKCU only.
Installation requires explicit operator authorization and Windows validation.
No shared-folder files are reorganized by this candidate. Existing shared layout
remains authoritative; rollout/rollback integration is still required before release.

## Verification recorded here

- 10 Python contract/authorization tests: PASS, disposable mocked database.
- 34 existing backend safety tests: PASS.
- 15 engine checks: PASS on Linux PowerShell 7.4.6, functions-only, synthetic XML.
  Includes parser digest compatibility, stale CSV isolation, missing/wrong digest,
  identity mismatch, post-run edit, clean add, preservation, stale local/candidate,
  exact backup, repeat no-op, revision-only, replacement and conflict rejection.
- Node browser-logic checks: PASS; mocked fetch/DOM, no browser or actual listener.
- Installer/registry, actual Windows browser handoff, copied real inputs,
  UI responsiveness, LOR reopen and live PC acceptance: NOT RUN.

## First Show PC step — disposable engine only

Use this exact committed checkout; do not overwrite G: with these source files.

1. On the Show PC, open `LOR\preview_sync\production` in that checkout.
2. Double-click `Validate MSB PC Updater - Disposable.vbs`.
3. Require all 15 PASS lines, no red exception. Retain the printed temporary
   evidence path and copy the output for the engineering acceptance record.
4. Close the validation window. It never executes updater startup, opens the
   browser, registers a launcher, contacts Production or reads/writes the real
   `C:\lor\CommonData\LORPreviews.xml`.

Only after Windows/hand-off/deployment preparation and explicit approval:
verify accepted source (currently expected 34), first clean Show PC ADD 34 /
REPLACE 0, preserve default/store previews, approve apply, retain backup/audit,
reopen LOR and verify usability, close it and require ADD 0 / REPLACE 0.
Do not mark #300 ready or #299 closed before that evidence exists.


## Continuation — candidate 1.0.2

Show PC operator-reported Windows disposable result at candidate 717cfc4e: all
15 checks PASS. Evidence:
`C:\Users\Light-O-Rama\AppData\Local\Temp\msb299-ee4c33b1c12c4263aace4dca81fe890b`.
The test launcher targets Windows PowerShell 5.1; no explicit version printout
was provided. This is engine acceptance, not browser or live-library acceptance.

Candidate 1.0.2 separates the UI event pump from the transport so actual socket
requests can be tested without launching the whole application. The test rejects
wrong origins/nonces/methods, duplicate headers and chunked bodies, tests OPTIONS,
accepts the valid request and proves the listener closes. Test uses the actual
TCP function, with browser opening/UI pumping substituted; no real browser/login.

Installer protocol now always uses `-AuditOnly`. Prepared metadata independently
sets `apply_enabled=false`; either guard forces comparison-only execution.
Live install remains blocked until a separate explicitly approved candidate.
The backend release identity is V0.6.5. See
[deployment and rollback preparation](deployment/DEPLOYMENT_AND_ROLLBACK.md).
Read-only prerequisite runner:
`deployment/Inspect LOR2PC Production - Read Only.vbs` invokes its neighboring
PowerShell/SSH wrapper without uploading a remote file. It does not change live
source, permissions, services, preview content or access policy. It requires the
usual SSH/sudo credentials interactively, never stores or prints them.

The new PC HTML entry was previously present locally but excluded by the global
`*.html` ignore rule. Candidate 1.0.2 explicitly tracks this entry and adds a
narrow ignore exception. No deployment had occurred from the incomplete prior
candidate. Browser test checks now require the entry and both referenced assets.


## Shared landing-page visibility

Greg clarified from the live landing screenshot that parser execution is the
restricted feature; displayed status, source details and reports are shareable.
GET /dashboard now accepts any identity authenticated by the existing protected
Access proxy. The response marks parser/operator capabilities from the existing
operator allowlist; unauthenticated requests return 401. Viewer rendering hides
the parser launch and start-mutation button. Backend parser/ingest/approval/start
routes continue to enforce the existing operator allowlist independently.
The version information/link and completed-report link remain visible.
LOR2PC still requires the established active Production Crew role/policy.
Public/anonymous access has not been introduced. Live Cloudflare policy inspection
and changes remain separate from source implementation. Backend V0.6.6; landing
JS V0.6.3/cache key updated. No underlying preview-engine change from 1.0.2.


## Read-only preflight transport correction

Greg reported SSH authentication then immediate connection close with no preflight
header. HOLD: no live checks were proven. Local harmless-shell reproduction shows
that loss of the nested bash -c quotes can execute only the shebang as a comment,
returning 0 with no output. The wrapper now uses the quote-free pipeline
`printf %s BASE64 | base64 -d | bash`. Three local transport regressions PASS:
original silent-zero reproduction, entire-script execution, failure propagation.
Actual Windows SSH and live preflight remain pending. The original 1.0.2 ZIP's
wrapper is superseded; its unchanged Inspect-LOR2PC-Production.sh can be invoked
with the corrected transport without redownloading or modifying Production.


## Verified preflight and next browser-review candidate

Greg's corrected read-only production preflight PASS is captured in
[evidence/production-preflight-2026-10-27.json](evidence/production-preflight-2026-10-27.json).
This proves Run 32 already has the accepted source digest and that only the
narrow read-only role-resolver EXECUTE privilege is missing. No new ingest or
reconciliation is required by the authority fix.

Server Management draft [PR #102](https://github.com/Gregovate/MSB-Server-Management/pull/102)
owns the frozen deployment/selective rollback candidate and runtime runbook
reconciliation. Eight disposable filesystem/state tests passed there; it has not
run against Production. Application work remains on #299 branch / PR #300.

The next candidate review uses `deployment/review_clone.sh` and
`preview_entry.py`. It creates a uniquely named current-production disposable
Postgres clone, restores without original owners/ACL, recreates reviewed role
permissions, proves migration 0043 changes only the required role capability,
and runs the actual candidate backend/static entry on the sequential reusable
localhost review port 8898. An explicit existing reviewer email is used only in
the isolated wrapper. Production DSNs/names and remote/browser writes are rejected.
The real Windows parser is never configured or called. The parser card therefore
truthfully shows unavailable in this preview; this is not a parser workflow test.

The shell harness and Windows launcher have syntax checks only. The WSGI test
passed for real static/health routes, write rejection, remote request rejection,
path escape rejection and Production DSN rejection. Current-clone restore and
operator browser acceptance have NOT run. The launcher opens no browser until
readiness; the operator opens the printed URL manually. It requires both local
and server 8898 availability and stops on an occupied listener. Cleanup targets
only its unique container, worktree and recorded process command. Logs/private
snapshot evidence are retained, rather than claiming remote cleanup from local
SSH cancellation. Actual browser login and native PC handoff remain separate
protected-site acceptance gates after this screen/source review.

VS Code is optional for inspecting the exact checkout or running the normal
terminal; no VS Code extension, Python installation on the Show PC, or manual XML
editing is required by the Windows one-click review launcher.

## Disposable restore HOLD and readiness correction

Greg's exact d571d0c4 review failed during pg_restore while creating
ops.controller_label_batch_item, before browser readiness. Retained evidence path:
`/tmp/msb-lor2pc-review.6plsgMPs`. The original trap attempted removal of the
unique clone/worktree; its failure output is not proof of final resource cleanup.
No clone/browser PASS or production deployment occurred.

The launcher omitted the final-PID-1 readiness contract explicitly documented in
Server Management PostgreSQL_Disposable_Acceptance_Standard.md. pg_isready alone
can pass during PostGIS's temporary initialization server. This is a known matching
failure mechanism, not a proven diagnosis for this specific container because its
logs were not retained before removal. Correction now requires container running,
PID 1 = postgres and pg_isready, bounded to 120 checks. Cleanup saves State-only
Docker inspection and container logs before removal, without capturing Config.Env.
Three local tests exercise the actual extracted gate and cleanup ordering; they
are not an actual PostGIS restore or Windows/current-clone acceptance.

## Operator browser review and launcher feedback

Greg tested r3 (source 351d5315748f621d5e1994e7faa8a9ea12e3e4d8): landing
and PC entry rendered, the blue landing button navigated to the PC entry, and
the harness reported CLEAN EXIT. The PC protocol button opened no updater; the
Windows launcher was not installed as part of this browser-only review. This is
not native launch, actual Cloudflare login, live comparison or production acceptance.

The entry now reports the expected browser permission prompt and directs a user
whose updater does not open to the MSB administrator. Browsers cannot reliably
detect protocol registration; the message does not assert successful launch.
The handler remains a fixed native URI and transfers no credentials.

Distribution remains blocked on protected-site policy review, governed deployment
of the #81 accepted-source endpoint/role permission, and Show PC comparison-only
acceptance. After comparison, a separately approved live apply must preserve
unmanaged previews, produce backup/audit evidence, survive LOR reopen/use/close,
and produce ADD 0 / REPLACE 0 on the next run. The comparison-only installer and
metadata guards are still enabled; this candidate cannot approve live application.

## Production server installation — operator evidence

Greg's deployment output reports SERVER DEPLOYMENT PASS for application
30fabb49e6b4ec8c17e679e97743bb25a9cd3450 through the comparison-only wrapper
232e26704bd20bb7368bbc5f66b46315f4091888 (Server PR #102). Normal writer sessions
were zero while frozen; source/grant installation completed; controller returned
ONLINE with database_fenced=false, READ_CONTINUITY=OFF and all configured services
active, including Work Management. Health/negative identity checks passed.

Report: /home/msbadmin/lor2pc-deployment-reports/539d2d0f75c4405fa3e567ea05387025
Snapshot: /home/msbadmin/backups/lor2pc299/msb-pre-lor2pc-30fabb49-20261027T221430Z.dump
Snapshot bytes: 149203658
Snapshot SHA-256: 2edcff06c7a50cbe114ea66ac4eba7c23338002decccd256b39a3d7035323718

This is server installation acceptance only. Real protected-site/crew access,
Windows protocol installation and browser handoff, master validation, Show PC
comparison, and live apply/reopen/repeat acceptance remain outstanding. The
prepared Show PC runtime comes from clean exact 30fabb49; its deployment metadata
sets apply_enabled=false and its registered handler uses -AuditOnly. Installing
this per-user launcher does not authorize preview replacement.

## Candidate 1.0.3 — installation/distribution and required data folder

Greg confirmed all programmers have shared G: access and that C:\LOR is the
mandatory LOR data folder on every programmer PC, including the new Show PC.
The ShowPC staging directory shown in his screenshot belongs to the older
Windows 10 PC; it is not discovery evidence for a new PC. No alternate library
selection is part of the programmer workflow.

The installer now blocks before file-copy/registration work if the required
C:\LOR\CommonData\LORPreviews.xml is missing. The failure directs the user to
initialize LOR with the required folder and close it. Functions-only checks
exercise both missing and present prerequisites; they do not prove live Windows
registration. Candidate 1.0.3 retains both comparison-only safeguards.

The PC entry adds Install / Repair PC Updater, local extraction/double-click
instructions and a comparison-only notice. Installation is per Windows user and
independent of G:; master validation still uses the accepted shared folder.
The fixed versioned ZIP is built by Build-LOR2PC-Download.py from a clean exact
committed source, never overwritten, and served through the existing protected
static site. No new backend route, role grant, listener or public bypass.
Tests compare every packaged runtime file to its recorded source commit and
hash; the read-only review entry permits only the exact named archive.

This change is not deployed. Server Management owns the bounded static update
and rollback. Exact-candidate browser review, authenticated download, Windows
install/native handoff and Show PC master comparison remain operator gates.
The prior server installation acceptance does not cover these new assets.

## Candidate 1.0.4 — two-file programmer package

Greg rejected the 1.0.3 download's exposed technical files during review. The
replacement outer ZIP contains exactly Setup MSB PC Preview Updater.vbs and
READ ME Instructions.txt. Setup embeds the complete immutable runtime archive,
extracts only into a uniquely created temporary folder, verifies the embedded
archive SHA-256 before expansion, runs the normal per-user installer, and removes
only its temporary folder afterward. Installed application/log files remain in
LocalAppData. No Support folder or technical files are exposed at package root.

Tests unpack the outer ZIP, require exactly those two names, decode the embedded
payload, verify its recorded digest and compare every hash-recorded runtime file
with its source commit. Native VBScript execution remains Windows acceptance;
Linux package/static checks do not establish a successful Windows installation.
The required C:\LOR check and both comparison-only guards are preserved. The
1.0.3 assets are historical; the new immutable filename is 1.0.4, not an overwrite.

## Browser handoff HOLD and bounded diagnosis

Actual Windows candidate 1.0.3/e578acd5 installed and launched from the browser.
Greg allowed the local-app prompt; Chrome still reported permission denied for
loopback access and net::ERR_FAILED. A screenshot shows Apps on device=Allow,
Local network=Ask without an operator change. These observations do not prove
a persisted permission denial or an HTTP CORS-header defect. Do not instruct
reinstallation, global security bypasses or repeated permission changes.
The taskbar remains the PowerShell icon (minor unresolved presentation defect).

The old timeout log had no request evidence and incorrectly implied sign-in was
the cause. New fixed-code listener events distinguish no connection, preflight
reply, rejected origin/host/method-or-nonce/body/response and document receipt.
No nonce, raw headers, body, email, cookies or tokens enter the trace. Browser
diagnostics separately identify source-fetch versus loopback-fetch failure and
query reported granular permission states only as evidence, never authority.
The browser diagnostic UI has not been deployed to Production.

Build-LOR2PC-HandoffProbe.py produces a standalone read-only engineering probe
from clean committed source. It extracts the actual transport functions, opens
the existing protected page and retains only its isolated listener trace. No
launcher installation/registration, library access, master validation, migration
or preview synchronization. Receipt proves transport only. This lets Greg test
the listener without reinstalling a working launcher. Root cause remains HOLD.

## First actual Windows probe evidence

Greg reports Edge also failed. Probe log for port 62627 at 23:04:10 UTC records
LISTENING -> CONNECTED -> REQUEST_REJECTED(reason=request-read), then timeout
with connections=1/preflights=0/rejections=1 and STOPPED at 23:06:10 UTC. This
proves one connection reached the listener, not that a valid HTTP request arrived
or that the browser permission gate succeeded. The rejection's exception was
not captured, so the immediate next probe adds exception type and source line,
plus reader-init/request-line/header-read/header-separator/header-duplicate
stages. It still records no request text, nonce, headers or credentials.

Header parsing now explicitly uses first-colon IndexOf/Substring instead of the
ambiguous Split overload. This is a compatibility correction, not a proven root
cause of Greg's rejection. Actual Windows retest remains necessary. The separate
temporary browser-review terminal can be cleaned up by pressing Enter and
requiring its CLEAN EXIT; closing only a browser tab does not clean its clone.

## Actual handoff receipt and desktop entry — candidate 1.0.5

Greg's second Windows probe records LISTENING -> CONNECTED -> DOCUMENT_RECEIVED
-> STOPPED on port60493 at 23:11:36 UTC, with no rejection. This is actual
transport receipt with the revised first-colon parser; full source/master
validation and sync have NOT passed. The prior failure's exact exception is
unknown, so this is not a retrospective claim of its proven cause.
Temporary browser review reported CLEAN EXIT; retained evidence:
/tmp/msb-lor2pc-review.twOp9ObV.

Greg authorized an installer-created desktop shortcut as an alternate launch
entry. Candidate 1.0.5 installs MSB PC Preview Updater.lnk on the actual current
user Desktop, including redirected folders. It targets the same fixed installed
script with -AuditOnly; the website and desktop entries still require the same
protected source evidence. The desktop and protocol DefaultIcon use the existing
tree/star asset. This does not claim the PowerShell taskbar icon is corrected.
The outer download remains exactly setup plus instructions; no exposed runtime.
Native self-contained Windows setup, shortcut, full updater comparison, protected
download hosting and live apply/reopen/repeat remain acceptance gates.

## Two-PC audit acceptance and 1.0.6 controlled apply candidate

Actual 1.0.5 audit results against accepted Run32: new Show PC ADD34/REPLACE0,
13 unmanaged; Greg laptop ADD0/REPLACE2, 8 unmanaged. Browser and desktop launch
worked after per-user installation. No live library changes were applied. Laptop
CSV identifies Rotary-Trees (same ID b820267c-7fa7-42ad-acf1-3850a057a3a4, local
rev54/master57) and Icicle Tunnel (same ID 6e8a166f-9fa8-4ce7-9df0-be9146f087f7,
local128/master130). There are 28 exact NOOP and 4 Revision-only NOOP previews.
Greg describes adding 8 dumb RGB lights on trees and 16x3 RGB Pixie strings of
length150 on the tunnel. This operator explanation is not an independently
verified content diff and is never inserted as fabricated machine evidence.

Candidate 1.0.6 derives replacement descriptions from the captured local/master
XML: added/removed items and settings, changed attributes/text and reordered
items. Identity-bearing children match by ID plus occurrence; other children by
tag/occurrence. Pairing is explanatory only; semantic hashes still determine
action. Root Revision is excluded. Unknown substantive differences that produce
no explanation BLOCK. Control characters in values are escaped. Full details
are retained in the CSV and shown in the scrollable named-preview review. Audit
mode now shows that same review with its apply button disabled.

Release preparation defaults to apply_enabled=false. Explicit --enable-apply
prepares CONTROLLED_APPLY_PILOT metadata and a distinct immutable -pilot.zip;
normal preparation yields -review.zip. Installer requires a boolean apply flag
and uses one fixed launch-command generator for desktop/protocol; audit mode
adds -AuditOnly, explicitly enabled pilot mode allows the reviewed apply flow.
The updater still requires operator acknowledgement, LOR closed, current source
identity/evidence/digest, unchanged local/candidate, atomic backup and audit.
Metadata hash/commit/apply permission are frozen and revalidated after review
and immediately before installation. Installation alone never applies previews.

No live apply or new Production website deployment is authorized by preparation.
The next operator gate is visual/content review then Cancel on the laptop. A
separate explicit Show PC live-apply approval, LOR reopen/usability, close and
repeat ADD0/REPLACE0, retained exact backup/audit paths remain mandatory. Current
Production browser page remains 1.0.2 without the install download. Server
Management owns bounded static publication after the candidate is accepted.

## Candidate 1.0.7 — filename list, diff and optional Revision alignment

Greg rejected the 1.0.6 combined text view after review (no apply approval).
Replacement UI: all controlled preview filenames/actions/Revision metadata in a
selectable grid, separate read-only red/green unified diff, and database-review
notes. The resizable layout uses current screen working area and automatic
layout instead of fixed stacked text. Actual Windows rendering is still an
operator acceptance gate; Linux cannot establish WinForms acceptance.

Priorities confirmed against parser field map and reconciliation ownership docs:
Preview UUID/name; Comment-based display identity and prop association; raw prop
UUID; scenes and positional scene membership. Parser also consumes ChannelGrid,
channel Name, DeviceType, DimmingCurveName, string type/master relationships.
Review labels prefer Comment for props, while Name remains visible as channel
metadata. Review categories are an aid, not a second LOR2DB impact engine. The
PC updater never writes the database; accepted #81 evidence remains authority.
Other substantive settings/geometry remain actionable even without DB identity
changes. Unknown/unexplained differences remain blocked.

Match master Revision is initially unchecked. It is permitted only when stable
PreviewID and the full substantive hash already match. It changes the local
PreviewClass root Revision, verifies the same identity/hash afterward, and is
counted as ALIGN_REVISION_IN_CANDIDATE, not REPLACE. Serialization may normalize
formatting inside that controlled fragment; unmanaged fragments remain byte
identical. Master numeric Revision must be usable. Revision never ranks content.
Review-only rows show just two metadata diff lines. Matching the master can lower
a local Revision; that is metadata normalization, not authority.

Changing that option clears the acknowledgement, rebuilds only the candidate
from the captured accepted master and unchanged local bytes, refreshes the CSV
and freezes a new candidate hash. Failed rebuild disables apply. Both audit and
pilot retain original release/local/master/candidate revalidation and exact-byte
backup gates. No-change/Revision-only state cannot silently trigger a write;
operator must opt in, acknowledge and approve a nonempty plan. No real PC apply
or new Production website deployment has occurred.

Installation procedure correction: download -> Extract All into the default
Downloads folder -> double-click Setup MSB PC Preview Updater.vbs on every PC.
No version-specific C:\MSB299 installation folders are required. C:\LOR remains
the mandatory LOR data folder; application storage is per-user LocalAppData.


## Candidate 1.0.8 — durable review evidence and foreground results

Actual laptop 1.0.7 screenshots and supplied CSV confirm 34 controlled rows:
28 current, four Revision-only, two content replacements (Rotary-Trees and
Icicle Tunnel). Handoff trace confirms document receipt and listener closure.
No live apply acceptance. Greg reported the browser covering the results and
only browser-handoff.log in the runtime logs folder. The exact cause of the
missing post-dialog summary has not been established; do not claim it was a
successful cancellation or a sign-in failure.

Write the initial REVIEW_PREPARED event and a complete CSV beside its unique
sync summary before ShowDialog. Failure to retain evidence blocks review/apply.
Rebuilds retain the updated plan before enabling approval. Final status appends
to the same run log; unique millisecond/GUID names prevent subsequent launches
from overwriting earlier runs. The normal CommonData CSV remains compatible.
Open report folder opens runtime logs, including full multiline per-preview
CSV details. No credentials or handoff tokens are added to these reports.

Results request foreground on Shown with temporary topmost (350ms), then release
it. There is no polling or continuing focus stealing. Native Windows behavior
remains an operator test; Linux engine checks do not establish focus acceptance.
Installer/version/download references advance to 1.0.8. Production and live
preview libraries remain untouched; next operator gate is review then Cancel.

Startup and review window captions display application version and release date;
review heading repeats both. Logs record release date separately from run time.
This identifies the installed PC runtime independently of the website version.


## Candidate 1.0.9 — preserve local presentation preferences

Greg's controlled exported-file experiment confirms root PreviewClass.Brightness
7 -> 0 is the ONLY structural difference after adjusting background-image
brightness; Revision58, props, scenes and MasterDimmable flags remain identical.
The official LOR background-image brightness help also documents changes from
the Playback Window. LastSelectedSceneId is local scene selection, distinct
from scene definition/membership. These local preferences must not block PC
preview distribution or force a publication/ingest.

PC substantive hashing and explanatory diff now exclude only unqualified root
Brightness and LastSelectedSceneId (plus existing root Revision metadata).
Accepted-source captured-byte folder digest, identity, inventory and evidence
checks are unchanged; changing those values in MASTER still invalidates the
accepted master digest. No #81/source digest algorithm change is involved.
CSV Presentation_Details records local/master differences independently of
controlled diff, including attribute absence. NOOP retains the exact local
fragment. Substantive replacement merges only these two local root preferences
into accepted content, verifies identity and accepted PC semantic hash, and
preserves unmanaged fragments. Revision alignment operates on local content and
therefore also retains preferences. Missing local preference attributes remain
absent. ADD uses the accepted preview because no local preference exists.

Descendant brightness, MasterDimmable, dimming curves, channel names, wiring,
identity, scenes and membership remain controlled PC-distribution content.
This does not mean every such change requires DB ingest: database-contract
impact and preview publication remain separate #81 work. Greg's later eight
HW-Flood MasterDimmable=False edits are deliberate playback changes and still
compare against accepted True flags. Do not apply that reversal without explicit
review. No preview-only publication implementation or automatic app update check
is claimed in 1.0.9.

Evidence: actual laptop 1.0.8 APPLIED (2 replace/0 add/unmanaged8, installed hash
matches reviewed candidate) followed by nonzero repeat due preferences. Native
1.0.9 retest remains pending. Tests cover exact-byte NOOP, separate preference
report, real dimming replacement plus preference preservation, unchanged
unmanaged bytes, zero repeat, descendant brightness/scene edits, attribute
absence, Revision alignment, mismatched IDs, and unchanged source digest gates.
No Production source promotion, DB ingest, website deployment or PC apply was
performed while implementing this fix.


## Candidate 1.1.0 — restricted official catalog publication

Bounded #81 change implemented beside the existing Windows parser runner in
preview_catalog.py; API V0.6.7 forwards fixed authenticated operations, Windows
runner V1.8.0 owns approved-folder capture and protected local catalog evidence.
No new DB tables/grants or ingest. Greg's direct-to-master export remains intact.
First review of unchanged accepted bytes registers baseline before a new export.
Later review/publish permits only root Revision/presentation and direct prop
Name(with nonblank Comment)/MasterDimmable exceptions. Other fields stop for
contract review. Unknown changes are never silently approved. Publication is a
separate schema2 ACCEPTED evidence record, not a fabricated COMPLETED run.

Dedicated publisher allowlists on API and runner, exact Origin/JSON checks,
server-derived database baseline/folder, global runner operation lock, repeated
captured-byte validation, actor/parent/source-bound review, immutable evidence
and atomic pointer protect approval. Production Crew access only consumes.
Feature is opt-in, disabled by default. Once enabled current-source requires
runner/catalog availability; no stale fallback. New DB completion supersedes
catalogs tied to an earlier baseline. PC1.1.0 validates schema2 policy/baseline and
shows accepted catalog identity separately from the inherited database Run.

See LOR2DB/Application/PREVIEW_CATALOG_PUBLICATION.md for exact configuration,
initial registration and pending deployment/Windows/negative-auth gates. Review
can register baseline without publication. Upgrade participating PC clients
before first schema2 Publish (older clients fail closed). Source-only two-host
rollout remains a Server Management task; no Production actions performed.
Automatic app update checks remain separate, documented and unimplemented.


Programmer UX update in1.1.0: selected-preview details default to a short summary
of additions/removals, Display name changes, network/channel changes, dimming
settings, programming names and scenes. Show full details toggles the existing
technical diff; CSV retains full detail plus Change_Summary. Presentation and
Revision-only states remain non-actionable summaries. The protected PC page
removes the redundant sign-in instruction, uses Install / Update PC Updater,
and documents per-user self-install (no administrator visit/elevation). The
button downloads the immutable published ZIP; it does not silently execute an
installer or automatically discover a newer release. Production1.0.2 page remains
stale until the approved static publication is performed.


## Exact catalog browser review — 2026-10-28

Server Management Production_Database_Change_Deployment_Runbook.md classifies
this catalog release as SOURCE-ONLY/non-migration (no database-wide maintenance
window). Its Pre_Production_Browser_Review_Runbook.md still requires exact
operator-visible browser review before production approval. There is no bypass
of that review merely because unit tests pass.

New catalog_preview_entry.py composes the real API and authenticated runner
HTTP dispatch with copied master exports and a disposable database. Only the
clone harness maps the baseline folder to a private local copied path and
recomputes the disposable document identity; captured-byte digest must equal
the actual clone's latest completed source. Baseline registration and subsequent
XML upload/publication write only private disposable evidence/master copies.
No live Windows runner is configured. Normal parser/ingest/reconciliation writes
are blocked at the loopback middleware, including requests from the reviewer.
The copied-export simulation is explicitly labelled and cannot address arbitrary
paths: its target comes only from the existing controlled PreviewID inventory.

Review-LOR2PC-Catalog.ps1 reads only master .lorprev files, uploads one bounded
copy archive, then opens one foreground SSH session. Reuses8898 with prior port
ownership checks and existing clone/post-init/readiness/cleanup gates. No browser
opens before BROWSER REVIEW READY. The original GET-only harness remains GET-only.
The review ZIP is built only from a clean committed checkpoint by
production/deployment/Build-Catalog-Review.py, with SOURCE.json file hashes.

Additional fail-closed repair: a missing current pointer after any catalog
publication is now an error, never a fallback to the older database source.
Test proves both read and new review are blocked in that condition. Native full
workflow, live Cloudflare/runner, ACL and Production acceptance remain pending.


## Catalog source-digest correction / review r2

Actual first catalog browser attempt HOLD: copied master digest did not match
latest clone accepted source; retained evidence /tmp/msb-lor2pc-review.1fEgXNGG.
Traceback established the readiness failure, not a changed-master diagnosis.
Code investigation found catalog source_digest wrongly copied the software-
version checker's manifest_source_signature (identity/key sorting). The ingest
SourceManifestSHA256 actually uses parse_props_v7_scene_parser.py's
source_manifest_sha256: filenames sorted casefold; list of filename/sha256 dicts
in that key order; ensure_ascii=False; compact JSON UTF8. Existing PC C# digest
was already correct. Earlier "parser parity" test compared against the wrong
version-checker helper and therefore did not prove parser/ingest parity.

Corrected catalog hashing without weakening source validation. Tests now load
actual parser SHA functions via AST (no parser top-level I/O), include multiple
files/Unicode filenames/BOM/order and the independent previously proven C#/
parser fixture digest f0b1d09d14ed4e5438f010e8fb69c096339dd97f4a44acbbee3cb6859d61fe18.
HTTP fixture source evidence is independently generated instead of calling the
catalog helper on both sides. First browser attempt remains FAIL/HOLD; corrected
r2 operator review is pending. No Production code/source/DB was changed.

Review now retains source-validation.json with expected/observed digests,
counts and copied per-file hashes. Readiness failure prints the bounded retained
browser log in the same foreground SSH output; expected startup connection
retries are quiet. Existing PowerShell window should be used with process-only
-ExecutionPolicy Bypass, not an unsigned direct invocation. r2 review archive is
new and immutable; do not overwrite the first artifact.


## Review r3 — native source selection and explicit copy confirmation

Greg's actual r2 browser registered unchanged Run32 master digest c21e0287...
successfully. The browser-only export simulation then reported Failed to fetch;
that message alone does not establish connection/tunnel/CORS/server root cause.
No catalog publication acceptance is claimed. Do not diagnose a master edit.

Browser APIs cannot force arbitrary C:\LOR\ImportExport as their first folder.
The engineering wrapper now uses native Windows OpenFileDialog with that initial
directory, stages selected bytes plus full source path/hash as two reserved ZIP
entries, and verifies captured bytes against the selected local file. It does
not write the local export or G:. Existing approved master copy remains separate
and must still match accepted parser digest. Native dialog actual Windows
acceptance remains pending; wrapper ZIP/evidence tests use an explicit fixture
path and fake SCP/SSH, not a real Windows GUI.

The disposable page shows the actual source, reference master destination and
exact isolated copy path, with an explicit acknowledgement. It submits a plain
HTML form (no JS fetch/file upload), uses the preselected hash-verified bytes,
and returns styled success/HTTP error pages. Copy is atomic under the existing
runner operation lock. Baseline registration and protected catalog review gates
remain. This removes the opaque fetch interaction, not a proven fix for the
unknown original transport failure. Keep the SSH review window open throughout.

Publisher review includes source/evidence destination folders. Approval checkbox
uses existing flex confirmation style. No change to real direct-to-master export
workflow: this picker/copy UI is engineering review only, not a required upload
for Production publishing. Production source/DB/master/PC remain unchanged.


## Publication closeout and source-release preparation

Actual r3 browser publication succeeded: local Rotary-Trees58, eight dimming
flags, reviewed digest e93a363ee254f5bf2c6579bd3b40a093f29a4246bcb5be917a2fa7374f1b698,
disposable catalog c8365550d72f727f710ec4323f462b1ba3cd0b3d6d59feaba75017c8bbed274b.
Retained /tmp/msb-lor2pc-review.sSBiAAiP; cleanup still pending user closeout.
No real source/DB/PC changes. Native picker/source/destination/copy/approval
workflow proven for that one preview. Multi-preview native acceptance not claimed.

Completion UX corrected: prominent green publication-complete region receives
focus, states disposable vs real scope, changed-preview count and no-ingest
outcome. Receipt retains actor/time/catalog/master digest/database baseline.
Old review detail is hidden and approval resets. A no-change review after an
existing publication cannot create another redundant catalog, and reports the
current parent rather than incorrectly saying initial registration is ready.
Three-preview disposable test proves one batch and whole-batch rejection if one
protected wiring change appears. This is automated proof, not a native batch PASS.

Deployment gap corrected in root run_lor_runner.ps1: the existing task now reads
private per-profile catalog-settings.json on every Start, independently of any
interactive environment. Missing/disabled config clears catalog authority;
enabled config validates schema/publishers/local evidence path and Windows write
ACLs/reparse points before setting process-only values. Token/PG credential/task
identity and existing parser/checker/ingest paths remain unchanged. Functions-only
Linux checks pass; actual Print Service profile ACL/start/restart remain gates.

Server Management owns new read-only preflight and source-only rollback plan.
Collect current live backend/source hashes, current accepted evidence and paired
runner version/activity before pinning production mutation. No old comparison
migration deploy runner reuse; no maintenance fence/DB migration is needed.
Do not make Greg repeat the same disposable single-preview publication test.
