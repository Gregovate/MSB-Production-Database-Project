# PC installation and distribution procedure

Filename: PC_INSTALLATION_AND_DISTRIBUTION.md · Revision 2 · 2026-10-27
Owner: #299 / PR #300; protected website hosting owned by Server Management.
Status: COMPARISON-ONLY PILOT; not approved for general programmer distribution.

## Installation and runtime boundaries

Installation does not require G:. Supply the complete committed release ZIP by
an administrator-approved download or file transfer; extract it on the PC. Do
not use ChatGPT attachment links as the permanent programmer distribution channel.
The installer copies the application into the current user's LocalAppData and
registers the browser launch handler for that user. No elevation is required.
Each Windows account on each programmer PC needs its own installation. Installing
under another administrator's account does not install for the programmer.

Synchronization still requires that user's access to the exact accepted master
folder on G:, in addition to browser sign-in with Production Crew capability.
A local app installation does not grant either permission. The accepted source
is always the latest eligible COMPLETED LOR2DB state; never a bundled master copy.
The existing G: shared deployment is a separate surface and is not changed here.

## Current pilot release identity

Runtime source: 30fabb49e6b4ec8c17e679e97743bb25a9cd3450.
Package: LOR2PC_ShowPC_Comparison_1.0.2-30fabb49.zip.
SHA-256: 14e46bf00dc1fc46e67d4848fc6f61afd37c4d508405cd0a82da2ae3cf8f68c3.
Prepared by Prepare-LOR2PC-Candidate.py from that clean committed checkout;
DEPLOYMENT.json records the source and runtime hashes. apply_enabled=false and
the installed handler uses -AuditOnly. This package cannot perform live apply.

## Administrator preparation and first installation

1. Verify the release is the approved pilot above, including its archive digest.
   General rollout requires the acceptance gates below, not only server deployment.
2. On the programmer's PC, sign into the Windows account the programmer will use.
   Ensure LOR is installed and the expected local library is
   C:\lor\CommonData\LORPreviews.xml. The current launcher uses that fixed path;
   C:\LOR is the required MSB data folder. The installer blocks before any copy or
   registry change if the required library is missing; no alternate path is offered.
3. Close LOR. Verify the user can access the shared drive and the protected
   https://my.sheboyganlights.org/lor2db/ page with their own account.
4. Transfer the complete approved ZIP without depending on G:. Extract all files
   into C:\MSB299-ShowPC-Comparison. Do not execute from the ZIP viewer or mix
   files from different packages.
5. Double-click `Install MSB PC Preview Updater.vbs` in that folder. This invokes
   the included installer and requires no programmer terminal work. If Windows
   blocks script execution, retain the exact message; the MSB administrator must
   resolve it through approved workstation policy, not disable browser security.
6. If the administrator needs the PowerShell alternative, run under the same
   normal Windows user (not Run as a different user):

   powershell.exe -NoProfile -ExecutionPolicy Bypass -File "C:\MSB299-ShowPC-Comparison\Install-LOR2PC-Launcher.ps1"

7. Require the installation confirmation: "MSB PC Preview Updater launcher
   installed. No previews were changed." On error, stop and retain the message.
8. Open the protected LOR2DB page. Click Update this PC's MSB Previews, then Open
   PC Preview Updater. Allow the requested external-app prompt. Complete the
   normal sign-in and, if requested, allow local access only for this requested
   updater interaction. Never disable browser security to make it work.
9. Return to the updater. Require accepted-source/master validation and the
   expected comparison. On the new Show PC, expect ADD 34 / REPLACE 0, with
   unrelated/default/imported/store previews preserved. Retain the result and
   diagnostic/audit paths. Confirm the actual local library bytes did not change.
10. Stop here for the comparison-only pilot. Do not present it as a usable live
    updater or distribute broadly. Installation success is not sync acceptance.

## Ordinary programmer use after release acceptance

1. Close Light-O-Rama.
2. Open LOR2DB and click Update this PC's MSB Previews.
3. Click Open PC Preview Updater; allow the requested launch/sign-in prompts.
4. Review the proposed changes. Approve only the intended MSB update.
5. Reopen LOR and verify the previews are usable. If blocked, send the exact
   message to the MSB administrator; do not manually replace the preview library.

Steps 4-5 involving apply require a future separately approved apply-enabled
release. They are not available in this comparison-only package.

## Repair, upgrades, removal and evidence

- Missing handler: reinstall the complete approved package under the actual
  programmer's Windows account. Website rendering alone does not prove installation.
- Upgrades: the administrator prepares and verifies a new committed package;
  install it under the same Windows user. The handler then targets that commit's
  local directory. Existing version directories are retained. No automatic update
  check, downgrade authorization or rollback registration backup exists yet.
- Do not manually edit DEPLOYMENT.json to enable apply or alter source evidence.
- On failure, retain the full error and logs under
  %LOCALAPPDATA%\MSB\LOR2PC\<source commit>\logs, and any printed backup/audit paths.
  Do not delete evidence while repairing an installation.
- Removal is administrator-assisted: verify the registered command belongs to
  this application before removing its HKCU\Software\Classes\msb-lor2pc handler.
  Preserve logs/backups first. Do not remove or replace LORPreviews.xml, other
  applications' registration, shared master files, or unrelated local previews.

## Permanent distribution work still required

The recommended entry is an authenticated Install / Repair PC Updater download
button on the LOR2DB PC page, beside Open PC Preview Updater. Publish an immutable
approved package with its exact source identity and hash; keep older release
assets for audit. Installation must remain possible without G:. Browser launch
still requires a locally installed native handler; a web page cannot silently
install that handler. The download button/package hosting, upgrade/repair UX,
and guided removal are NOT implemented by the current candidate.

Before general distribution: real crew policy/authentication and native browser
handoff; Show PC comparison; separately approved live apply; preserved unmanaged
previews and original-byte backup/audit; LOR reopen/usability; close LOR and repeat
ADD 0 / REPLACE 0. Publish simple programmer instructions only with that accepted
release. Keep server maintenance, hashes and engineering commands out of normal
programmer instructions.

## Candidate 1.0.3 distribution implementation

The PC page now includes Install / Repair PC Updater and numbered local setup
steps. It downloads pc/downloads/MSB-PC-Preview-Updater-1.0.3.zip through the
existing protected static site; no public GitHub or shared-drive installer link.
The archive is immutable for this version and records its runtime source commit
and hashes. The package includes the programmer readme. The installer checks
C:\LOR\CommonData\LORPreviews.xml before any installation mutation.

This is repository implementation, not a claim of deployed download availability.
Server Management must publish only the exact committed static page/script/archive,
preserve rollback bytes and validate the download. Existing authentication must
cover the download path; do not add a public bypass. Comparison-only safeguards
remain enabled. Guided uninstall and signed-executable packaging remain unimplemented.

## Candidate 1.0.4 package correction

The programmer download now contains exactly Setup MSB PC Preview Updater.vbs
and READ ME Instructions.txt. Setup embeds the technical runtime; no technical
files or Support directory are exposed at the extracted package root. Extract
both files and double-click Setup MSB PC Preview Updater.vbs. It installs under
the same Windows user without elevation. Prior manual installer filenames are
engineering/history only. The current candidate remains comparison-only and
requires actual Windows setup/handoff review before distribution.

## Candidate 1.0.5 desktop launch

The installer creates MSB PC Preview Updater.lnk on the current user's actual
Desktop (including redirected folders) and registers the website handler. Both
use the same fixed command generator and -AuditOnly. The existing tree/star icon
applies to the shortcut and protocol; PowerShell taskbar grouping is separate.
The corrected first-colon header parser successfully received the real Windows
probe document. This does not establish full updater/source/master acceptance.
After installation, launch from the Desktop, finish the normal protected browser
handoff and retain the comparison result. Do not apply; the candidate cannot
replace previews. The ZIP still exposes only setup plus instructions.

## Candidate 1.0.6 controlled apply pilot (not distributed)

Preparation defaults to review-only; --enable-apply builds the distinct
MSB-PC-Preview-Updater-1.0.6-pilot.zip. It contains only Setup MSB PC Preview
Updater.vbs and READ ME Instructions.txt. The pilot CAN apply after named content
review and explicit operator acknowledgements. Installation does not apply.
Use first on Greg's laptop to inspect the two replacement descriptions and
Cancel; do not approve laptop replacement as part of the Show PC test. Show PC
live apply still requires separate explicit approval and backup/reopen/repeat
acceptance. Do not publish this as a general programmer release yet.
