# #205 — Manager Email Engineering Authority

| Document control | Value |
| --- | --- |
| Owner | Setup #205, subordinate to commanding #122 |
| Status | Engineering contract for review; **not** Production deployment approval |
| Initial audience | Active, authorized **Setup Managers only** |
| Target schedule | October 17, 2026, **04:00 America/Chicago** for first controlled pilot |
| Current installed application | V0.3.84 / `7740498e6602f` (operator read-only preflight) |
| Initial Captain sending | **OFF**; zero Captain emails |
| Runtime authority | `Gregovate/MSB-Server-Management` for systemd, protected environment and installation |

## Authority and sequence

Read this engineering authority together with the [Setup engineering README](README.md) and the existing [#205 KPI/reporting contract](Setup_205_Schedule_Performance_and_Daily_Accountability_Contract_2026-10-15.md). The implementation must use their shared classifications, not an independently invented definition of completion, “late,” or work reported. The [Manager Email Operator Procedure](../operatorSOP/Review_Setup_Manager_Email.md) must be reviewed next, followed by tested implementation, current-Production disposable/live-data review, and **only then a Pull Request and deployment approval**. The [Setup operatorSOP README](../operatorSOP/README.md) provides discoverability.

The earlier draft [application PR #412](https://github.com/Gregovate/MSB-Production-Database-Project/pull/412) includes rejected Directus mail-flow code and incomplete PostgreSQL mail facilities. **Do not install or merge that candidate as the October 17 pilot.** The early Server Management draft PR #79 and ZIP are not accepted installation authority. Preserve the operator's already verified Google relay and live V0.3.84 application.

## Existing architecture — consume it, do not rebuild it

- **PostgreSQL**: source of truth for the 2026 Setup Session, work-day/assignment history, progress, readiness, and people.
- **Existing people/authorization:** `ref.person` linked to active Google-backed `public.directus_users`, current `ref.setup_browser_capabilities(email).can_manage_setup` = true. Do not use legacy `is_manager` flags or guess recipient email from Captain assignment. Resolve **fresh at dispatch**, require exact active linked Google/MSB identity, unique normalized `@sheboyganlights.org` contact.
- **Cloudflare Access** identifies the signed-in human for interactive actions; existing Setup authorization controls who can preview/change settings. A headless 04:00 sender does not impersonate a Cloudflare user; it uses the server's narrowly scoped read-only DB connection and approved system sender.
- **Google Workspace SMTP relay**: the existing IP-authorized `smtp-relay.gmail.com:587` with required STARTTLS, verified public source IP `69.21.78.70`, organizational **From** `MSB Production DB <no-reply@sheboyganlights.org>`. Operator-confirmed one-message SMTP acceptance **and Gmail Inbox receipt** Oct 16. Google admin change, SMTP user/password, Synology SMTP or Directus Flow are not required.
- **Python**: use the current `/opt/fieldwiring/.venv/bin/python` under `fieldwiring`, current protected `/etc/msb-setup/setup.env`, and existing V0.3.84 `SetupSchedulingBoardRepository(dsn).board(2026)`. No new HTTP endpoint, Docker, daemon or second notification provider.

## 4:00 AM first Manager-only report

Freshly compute from the authoritative board at dispatch time, matching the existing Setup KPI definition:
- **Total / Completed / Remaining**, whole Setup, not Captain-filtered.
- Distinct unfinished **hard-blocked or NOT READY**, separately enumerate readiness if useful.
- Last seven calendar days actual effective task completions with verified **actual work dates**; label the task-based pace, required calendar-day pace to **Nov 19**, forecast/date only when evidence permits. Never substitute save/audit timestamps for work dates.
- **Past scheduled occurrences without valid saved reports** (original task, date, shift, Crew, named Captain/TBD), excluding cancelled/rescheduled no-work cases per current governed history. Do **not** imply the Captain is at fault merely from absence of report.
- **Reported partially worked tasks needing continuation**, upcoming scheduled readiness/blocker exceptions, and Captain TBD.
- Clear Manager actions: determine whether work occurred; if no work use the existing audited **Reschedule · No work performed** without fictitious 1%/time; if actual work happened get an accurate report; if already reported partial, schedule continuation; if unknown, investigate/hold. Explain unresolved items continue appearing in Manager action summaries.

Email wording is an **editable external text template** with validated variables (subject and body; first-day pilot may use a controlled, versioned reviewed text file, **not permanent user-facing strings in Python**). No hard-coded persons, contact addresses, screenshot stats, or invented links. Use the protected Setup entry `https://my.sheboyganlights.org/setup/`; an exact-assignment email deep link may be added only after browser acceptance. Show actual current Manager/recipient preview before any live test or fan-out.

## Strict safety gates

1. **Manager-only:** the first runner contains no Captain dispatch path. Regardless of draft PR #412 code, do not import `DirectusSetupOutboxClient`, enable old 074 schema/Flow or send to Production Crew.
2. **Preview first, default no-send:** read-only recipient/count/body preview. Validate current Session and real roster against the protected Setup Action Center. No email on source install or template edit.
3. **One-recipient test:** actual email only to the authenticated operator's verified current Manager account, after seeing the rendered report and exact From/To. Verify Gmail Inbox received; SMTP `250` alone is “accepted,” not “delivered.”
4. **Explicit fan-out approval**: only after Manager roster and content test are accepted. The test does not authorize emailing every Manager.
5. **Single-day timer:** Oct 17 04:00 America/Chicago, not recurring/catch-up; if date or approval missed, fail closed rather than send later unexpectedly. No Captain email, even if 4AM Manager run succeeds.
6. **No double sends:** unique date+recipient+message-purpose attempt record *before* SMTP. When a provider accepts a message, never claim Inbox delivery. If network outcome is unknown, do **not** retry automatically; preserve audit. Initial isolated pilot may use a dedicated protected on-disk attempt record because no Production schema change is authorized; full #205 system must later use native PostgreSQL outbox, preferences, audit and per-recipient idempotency.
7. **Production preserved:** no DB write/migration, current Setup checkout update, Setup service restart, Cloudflare/Directus change, or unauthorized systemd install. Server Management must have an accepted **one-shot timer** service/runbook before any Production unit is created. The source-only Setup runbook explicitly excludes unit/environment changes. This is a **runbook gap**, not permission to improvise.
8. Never expose `setup.env`, passwords or a full private Manager roster in GitHub logs/issues or user-facing public links. Runtime environment is consumed by `fieldwiring` only.

## Acceptance evidence before PR / Production

Document exact candidate SHA/blob hashes, CLI and Python regression, secure template-placeholder handling, Manager eligibility and duplicate tests, cancelled/no-work/partial classification, zero Captain recipients, 4AM timezone validation including no catch-up, protected roster/real-data preview, one Manager received-email review, and status of the Server Management one-shot timer runbook. Operator acceptance comes after exact current-data/email preview. PR merges/docs closeout and Production release approval remain separate gates under #122.

## Broader #205 follow-on, not implied shipped

Manager-facing Admin master and per-audience switches, editable PostgreSQL template editor/history, permanent PostgreSQL notification outbox, Manager-approved Captain follow-up and separate volunteer schedule/event communications all remain unfinished. A bounded first-night Manager pilot does **not** silently activate any of these. Preserve their ownership in the existing #205 contract without expanding the first send into an uncontrolled multi-purpose mail system.
