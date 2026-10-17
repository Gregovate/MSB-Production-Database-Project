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
