## October 17 HTML no-send preview PASS; one-receiver follow-up prepared, not sent

Operator ran the corrected live `--preview` after new HTML and #88/#171 Container integration. **Exit 0, `PREVIEW_ONLY`, `sent=0`**, and HTML was **prepared only** (14216 characters). No new message could appear in Gmail from that command; the operator explicitly reported not seeing a new email.

**Verified October 17 Production Container snapshot:** 236 reference Containers; 80 park setup stops recorded; 13 picked/loaded/on the way; 11 association-derived empty-at-park (subset of 80); 1 association-derived partial-at-park (subset of 80); 18 recorded returns Home; 125 no movement recorded; 0 current location/status review; 10 with historical contents-review events. PostgreSQL snapshot `2026-10-17 07:16:33.023685+00:00`. Task figures remained 296 total / 90 completed / 206 remaining; pace 6.71 vs required 6.24 tasks/day, forecast November 17 (task count). Four report-check occurrences, twelve continuations, four upcoming readiness exceptions, zero Captain TBD. These are live snapshot facts, not physically counted Container inventory.

To get the **revised HTML in Gmail**, a distinct operator-only `--html-test-to gliebig@sheboyganlights.org` entry point has been built after governing engineering/SOP updates. It is time-bounded to October 17 Chicago, and uses `MANAGER_HTML_REVIEW_TEST` with a fresh protected `html-test-<day>-<recipient-hash>.json` receipt in the **same existing Production ledger**. This is not an old test retry: the original `test-` receipt is unchanged. The entry point builds proper HTML + text multipart via the existing SMTP relay; restricts the address to Greg (validated as currently authorized Manager), guards with original explicit SMTP flags, never sends to Captains or everyone, and blocks a second identical formatted-review attempt. Wrong recipient/date/ledger, duplicate sends and no-SMTP preview are tested.

**Source candidate `dfb8795656dc5747924b3a6c6f7188cdc5806d67`: Setup and FieldWiring full CI PASS (workflow 39013414613); #205 release tooling PASS (39013414376).** These are source checks; the new formatted actual Inbox message **has not yet been sent or reviewed**, and Server Management's dedicated mail pilot runbook remains draft. The older plain-text Inbox receipt at 01:45 remains accepted and protected. No Captain mail, Manager broadcast or timer activated.

## October 17 Gmail presentation and Container visibility — revised candidate

The operator reviewed the **actual Gmail screenshot** of the successful 01:45 Production test and did **not** accept its plain-text presentation as the final manager briefing. It was a transport/live-KPI **PASS**, not formatting/fan-out acceptance. The user specifically requested Container progress in the park, empty, and returned.

**Source corrections after engineering+operator contract updates:**
- `Setup/Acceptance/manager_mail_pilot/manager_digest_html.html`: controlled inline-style responsive 640px email, navy MSB header, three large progress KPI cells, task pace/deadline, **Containers · Field movement** KPI matrix, compact Manager decision cells, concise conditional instructions and aligned detailed tables. Email sender now uses proper **multipart/alternative HTML + full plain-text**; HTML is not a screenshot or remote image. Dynamic Manager names/assignment text is HTML-escaped; task details retained and no invented task deep links.
- `manager_digest_template.txt` remains complete accessible plain-text fallback and now includes Container movement counts and evidence limitations. Neither component claims Captains are being mailed.
- `manager_mail_pilot.py` reads the **existing #88 recorded movement snapshot** via `setup_production_report.movement_picture` and `setup_locate_assets.locate_assets` (the #171 map read projection) for the same 2026 Session, instead of independently reinterpreting history or adding a migration. Distinguishes park stop observed, picked/in transit, empty at park and partial (both **subsets** inferred from Display relationships), recorded returned Home, no recorded movement, unknown/status review, and historical contents-review evidence. **Physical empty unverified**, `PICKED` ≠ park arrival, return is recorded Home rather than GPS Workshop. Partitioned distinct Container identity counts; STOP if projection or Session missing.
- The protected Administrator-only recipient-review endpoint returns the exact formatted HTML as well as the plain text and actual Container counts. Its read-only UI renders the HTML in a sandboxed iframe, next to current eligible/HELD People roster and 2026 figures. Browser approval still outstanding.
- Network-free tests now assert Container categorization/overlap, escaping against injected task names, TLS SMTP `multipart/alternative`, preview-only/no-send, and Admin view counts. Full Setup/FieldWiring and release-tooling CI reached **PASS** on commit `d42969bb1ce6b46e9cebaa0c9055fcd4af81ff59` at source stage; this is **not actual Production Container-count verification**.
- **REMAINING REQUIRED:** New exact-commit **no-send Production preview** with real Container counts and HTML browser/email review. There is **no accepted follow-up SMTP test or broadcast** for the new formatted report, no timer installation and no Captain notification. The prior one-recipient test's receipt must be preserved; do not delete it or retry under the same purpose/date key. A follow-up formatted copy test would need an explicitly reviewed distinct test purpose and operator authorization.

## Operator-verified October 17 Production data and one-recipient email

**Evidence status:** Operator-supplied SSH and Gmail Inbox observations, October 17 2026. No Manager-wide release or timer activation approved.

- The original candidate `0d49c575...` read-only test first failed due to missing libpq credentials and then the intentionally denied `public.directus_users` SELECT. Root causes corrected without changing server database credentials, privileges, schema or Production Setup service: explicit established `fieldwiring_app` libpq connection/PGPASSFILE, and lookup beginning with `ref.person` plus the existing `SECURITY DEFINER ref.setup_browser_capabilities(p.email)`. Rejected earlier worktree is not an authorized sender.
- Operator's direct **read-only Production People query** passed: seven active People records either designated Manager or holding current Setup Manager authorization; five initially eligible, two requiring review (Don has a People Manager flag and Setup Manager capability but lacks a linked Person identity; Randy has Setup Manager capability but is not designated Manager in People). These discrepancies must be shown in the protected Administrator UI, not silently ignored or automatically resolved.
- Exact reviewed candidate source `a3c750caf4c060ee725c93460e075afd33907748`: **Production database preview passed** as `fieldwiring_app`; `PREVIEW_ONLY`, `sent=0`, exit code 0. Current 2026 Setup: **296 total / 90 completed / 206 remaining**; **140 blocked/NOT READY**; 7-day actual task-based pace **6.71/day** versus needed **6.24/day** by November 19; projected **November 17** with explicit task-size limitation. **Four** historical assignments without matched reports, **twelve** started tasks needing continuation, **four** upcoming scheduled readiness exceptions, **zero** future Captain TBD. The operator reviewed the actual detailed task lines.
- **Actual Production sender/Gmail Inbox test — PASS:** Operator shared Gmail Inbox receipt at approximately **01:45 America/Chicago October 17**. Subject `TEST — MSB Setup — Manager Actions — 2026-10-17`; From displayed **MSB Production DB**, To only the operator `gliebig@sheboyganlights.org`, personalized `Good morning Greg,` and correct live figures/exception detail. This is confirmed inbox arrival, not merely SMTP `250`. No evidence of any Captain or second Manager being sent.
- **Still STOP before fan-out and automated scheduling:** The operator **has not approved** the wording/group recipients or timer. The existing protected Setup Administration **Email recipients & preview** browser candidate has not passed disposable browser acceptance nor been installed. Runbook approval, dynamic People roster with eligible versus held identities, UI review and separately explicit broad-send consent remain mandatory. Captain mail stays **OFF**. Do not install or activate the October 17 04:00 timer if these gates cannot all be finished before its intended trigger; no catch-up emails.

# #205 — Governed Manager Mail Candidate, October 16, 2026

| Field | Value |
| --- | --- |
| Status | **SOURCE CANDIDATE; NOT DEPLOYED, NO 04:00 TIMER** |
| Commanding authority | #122; Setup implementing issue #205 |
| Engineering | [Manager Email Engineering Authority](../../Docs/02_Production_Database/01_System_Architecture/12_Setup_and_Deployment/engineering/Setup_205_Manager_Email_Engineering_2026-10-16.md) and engineering README |
| Operator | [Review the Daily Setup Manager Email](../../Docs/02_Production_Database/01_System_Architecture/12_Setup_and_Deployment/operatorSOP/Review_Setup_Manager_Email.md) and operatorSOP README |
| Observed Production baseline | Setup V0.3.84, deployed `7740498e6602f`, `msb-setup.service` active |
| Target | One time **2026-10-17 04:00 America/Chicago**, current Setup Managers only |
| Captain sending | Excluded by source, no trigger |
| First email | `manager_digest_template.txt` — text reviewed first, before install |
| Transport | Existing Google Workspace IP-authorized SMTP with mandatory STARTTLS, authorized MSB no-reply From |

## Code inventory (not an install package)

- `Setup/Acceptance/manager_mail_pilot/manager_mail_pilot.py` — 2026 Session projection, active ref.person Manager directory plus existing SECURITY DEFINER Setup capability (without direct Directus system-table SELECT), external controlled template, read-only preview; explicitly gated single-day Manager send; read-only PostgreSQL, per-recipient protected local receipt.
- `Setup/Acceptance/manager_mail_pilot/manager_digest_template.txt` and `manager_digest_subject.txt` — separate human-readable, source-editable first-day Manager body and subject templates. This is **not** the later PostgreSQL-backed Administrator template editor and should not be represented as such.
- `Setup/Application/test_205_manager_mail_pilot.py` — network-free tests covering totals/partial/cancelled work, preview, guard-off, local-date, one-recipient test, no-duplicate SMTP attempt, zero Captain functionality.

Candidate adds a protected read-only Administrator recipient/preview page to Setup, but **no changes to live Setup UI** until independently accepted/deployed. No changes to Report Work, the installed `/opt/msb-setup` detached worktree, the PostgreSQL schema/data, Directus Flows, or existing Work Order emails. No automatic periodic report: this is one calendar-day pilot only.

## Required acceptance order

1. Read engineering authority and indexes and accept the operator procedure. Review exact email subject/body with user; do not infer approval from an SMTP connection test.
2. Run exact source tests: `python -m pytest -q -p no:cacheprovider Setup/Application/test_205_manager_mail_pilot.py` and existing Setup/FieldWiring regressions. CI is not proof of runtime reception.
3. Verify the Production baseline and account/runtime facts again before staging: `7740498e6602f`, live `fieldwiring` runtime and protected `/etc/msb-setup/setup.env` must match expected values. Treat drift as STOP; do not reset Production.
4. Use a reviewed separate staging path and exact commit/binary manifest. Candidate must import the **installed** `SetupSchedulingBoardRepository` rather than the stale PR #412 mail service. Only read current Production data: show all current active People Managers with eligibility/HELD reasons, separately show any Setup-authorized-but-not-People-flagged discrepancy, and actual 2026 Task/overdue/continuation projections. Neither privilege escalation nor a direct SELECT on public.directus_users is allowed. **Never use screenshot figures as refreshed counts.**
5. Check the generated live-data report against the protected 2026 Setup Action Center. Any mismatch (task scope, completion dates,/report status, Captain or eligibility) is STOP.
6. Approve and conduct **one recipient** SMTP test exclusively to the current authorized operator's own MSB mailbox, and verify received body. No delivery to Captains.
7. Review full current Manager recipient roster and give **separate explicit** Production send authorization. The fallback “one-day” date/time must be fully governed by Server Management, including secure unit installation, environment, ledger and rollback. Missing Server Management runbook = **RUNBOOK GAP FOUND, STOP**.
8. If exact timer can be installed and inspected before 04:00 America/Chicago, perform one-time send with no catch-up. If not, record **NOT ACTIVATED**; do not run delayed mail or invent a successful morning email.
9. Record exact candidate SHA, test runs, operator preview approval, root-owned timer identity, per-recipient accepted/error/unknown receipt, actual inbox confirmation, system health, no-DB-mutation proof, and keep #205 work open for permanent settings/templates/native PostgreSQL ledger.

## Failure and privacy boundaries

- No SQL changes, fabricated 2026 Session, artificial Report Work, reassignment, Department/Captain status updates or Directus mail Flow installation.
- No automatic retry when SMTP outcome is uncertain. Accepted means SMTP provider accepted, not Inbox delivered or volunteer read.
- Never publish the full protected Manager roster or any token/DSN in GitHub reports.
- Captains and volunteers cannot be recipients of this candidate; a Captain who also holds current verified Manager authorization receives only a **Manager-role** digest.
- Test from the exact repo candidate and no independent ZIP substitute. A read-only preview/test MUST precede any timer.
- This candidate does **not** satisfy the complete #205 notification platform: Administrator on/off switches, DB template editor, PostgreSQL outbox and Manager-approved Captain notifications are still outstanding.
