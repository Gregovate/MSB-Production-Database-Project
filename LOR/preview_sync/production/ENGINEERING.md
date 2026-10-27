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
