# #205 Manager Morning Brief actionability — October 31 candidate

Owner #205; release #122; movement evidence #88. Existing PR413 reused.
Version V0.3.96-manager-brief. Main refreshed cfde519487e933bfa8e49f80c509f81921fd6f91.
Recorded installed sender: PR452 candidate 7f4e12219661a6b78452d8f2d3492646bd37f54e,
SHA256 fa91bcab5734fb581910a093d6d5329c86b8b15e19467d681f652490bf468e2d.
This is operator-reported October22 evidence, not a new live-host assertion.

## Engineering evidence

- Combined Setup application + acceptance: 1197 passed, 8 skipped.
- Separate application/GIS run: 924 passed, including four new evidence tests.
- 274 acceptance/tooling tests passed; 8 optional PostgreSQL/environment tests skipped.
- Existing Manager navigation Node tests pass; startup URL adapter tested with exact annual ID.
- New read-only SQL validation exercises Report Work columns and attribution joins as
  fieldwiring_app; requires existing Production-clone execution, not yet performed here.
- SMTP/retry/receipt/timer/recipient implementation unchanged. New content is read-only.
- Reuses PR418's immutable V0.3.50 test fixture only, not migration077 or its UI.
- Synthetic 23-task test is NOT proof that the real 23 notes were retrieved.

## Exact-candidate no-send review

Use the existing `run_setup_disposable_browser_preview.ps1`, sequential port8898,
PreviewEmail gliebig@sheboyganlights.org, ExpectedVersion V0.3.96-manager-brief,
TargetRef feat/205-manager-mail-governed-20261016, no MigrationPaths,
ValidationPaths Setup/Acceptance/setup_205_manager_brief_readonly_validation.sql,
AllowConcurrentProductionWrites. The exact candidate SHA and guarded worktree
command are recorded on PR413. Do not replace the existing runner or take another
clone between validation and browser review.

Wait for BROWSER REVIEW READY, then open http://127.0.0.1:8898/notifications/.
The preview uses the same sender and both templates, with no SMTP/receipt action.
Local preview record links stay on the disposable instance; production email
links use the existing my.sheboyganlights.org/setup/ URL.

1. Verify all 23 known continuation task identities against current data. Review
   exact notes, actual work date, report percentage, current percentage and actor.
   Any changed count needs evidence of intervening field work; do not hardcode23.
2. Compare original progress/movement/exception counts. Note interpretation must
   not change selection; completed Work Order gates still need no duplicate report.
3. Review Container C009/C034/C052/C053/C131/C216 where present. Confirm real names,
   last movement, load observation source/date, historical review reasons and
   unresolved-resolution wording. No park stop/membership count proves physical
   emptiness. No installed authoritative readiness/integral role was found in main;
   verify the read-only schema evidence before release. Do not invent these flags.
4. Review unscanned, Container-inferred, unloaded, independent and conflicting
   Display cases. None is called physically missing or final Setup verified.
   #431 is not a prerequisite. Manager historical corrections remain pending.
5. Follow a continuation planning link, past original report link, Container
   and Display links; confirm exact IDs. Cancel without saving. Preview link GET
   does not create a scan or correction. Do not test field writes on Production.
6. Review full text and HTML, actual message size and readability. Large inventory
   emails may be clipped by inbox clients; do not silently truncate record details.
7. Finish CLEAN EXIT and retain the printed report. Greg's exact preview approval
   is required before installation; engineering tests alone do not satisfy it.

## Installation gate — not a deploy command

Current Server authority retrieved/read: `docs/server/Setup_Manager_Mail_Recovery_2026-10-22.md`.
PR95 `install_digest_update.py` is restricted to October22 and preserves templates;
it CANNOT install this content/template release unchanged. RUNBOOK GAP FOUND:
its existing source-only installer must be extended under Server Management to
stage/preview/hash-check the exact content set and preserve delivery settings.
No recovery/send mode, receipt edit, timer edit or fresh email is permitted.
The Setup navigation/preview source must be installed and record links verified
before the private sender/templates are promoted. Updating Setup alone does not
update /opt/msb-setup-manager-pilot. Production installation remains HOLD.

No Production access was available from the engineering environment (private
192.168.5.9 network unreachable). No current-Production disposable, Greg preview,
installation, real23 acceptance or Inbox acceptance is claimed.
