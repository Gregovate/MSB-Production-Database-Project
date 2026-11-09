# Setup local calendar correction — #122 DBG-2026-021

Status: implementation candidate; NOT deployed or browser accepted.
Owner: #205 scheduling, #132 reporting, commanding #122.
Base main: `897a9ab1175402adcfc3ac12223830f3b9bbd663`.
Branch: `fix/122-local-work-dates`. Version: `V0.3.106-local-calendar`.

Design authority: [Scheduling Board Contract](../../Docs/02_Production_Database/01_System_Architecture/12_Setup_and_Deployment/engineering/Setup_Scheduling_Board_Contract_2026-09-17.md#local-calendar-authority--dbg-2026-021-2026-11-08).

## Finding and correction

November8 work was blocked after UTC midnight: normal Add Work Days rejected
November8 as past while Historical Day limited entry to November7. Existing UI
helper already uses Chicago; SQL guards used connection current_date. The source
mismatch is proven; live session/function settings have not been collected.

Migration079 pins only four existing function TimeZone settings to Chicago.
Bodies, owners, ACLs, security/search_path and business rows remain unchanged.
API report/correction date checks, material query boundaries, UI defaults and
timestamp displays explicitly use Chicago. Literal business dates and UTC
instant transport retain their meanings. Cache versions and client/server
identity are refreshed. Existing annual data is not repaired or rewritten.

The first open PR inventory contained no current active PR for this correction.
PR291 is an obsolete pre-migration069 deletion candidate and does not safely own
this work; PR418 owns Container/report work. Keep ownership in #122/#205 rather
than creating another issue or reviving an obsolete release.

## Local validation

Run `python -m pytest -q -p no:cacheprovider Setup/Application Setup/Acceptance/test_setup_gis_preview.py`.
New tests execute both report API routes with frozen instants and real browser
functions under UTC, Chicago and Tokyo workstation settings. Cover winter/summer
UTC rollover, Chicago midnight, both DST transitions and local year rollover.
The database configuration contract test is static, not PostgreSQL acceptance.

Local result: **974 passed**, including 22 new calendar checks. All changed
JavaScript files pass Node syntax checks. Of 18 existing standalone Node
harnesses, 17 pass; `test_205_historical_day_behavior.cjs` fails because it omits
`nextAssignmentInactive` from its VM context. The identical failure was
reproduced using all three unchanged files from origin/main; it is an existing
harness defect, not evidence of a new behavioral regression. The standard CI
Node list does not include that stale harness. Do not describe all Node tests
as passing. PostgreSQL/current-clone and browser acceptance remain pending.

## Existing disposable mechanism (next gate)

Use `Setup/Acceptance/run_setup_disposable_browser_preview.ps1` with the exact
candidate SHA/ref and matching version; allocation remains **8898**. Use its
existing parameters:

- MigrationPaths: `Setup/Database/079_fix_setup_local_calendar_boundaries.sql`
- ValidationPaths: `Setup/Database/validation/079_setup_local_calendar_validation.sql`
- PreviewProfile: Setup

Do not run a second dump/clone between database checks and browser review.
Read current Server Management port/runtime/browser authority before launching.
Do not run either SQL file manually against Production.

Validation SQL checks four exact function configurations, then attaches the
actual insertion trigger to a rollback-only temporary table. It accepts today
and tomorrow, rejects yesterday under UTC/Chicago/Kiritimati/Honolulu caller
settings, and proves the caller timezone is restored after function return.
It does not substitute for actual historical/report command acceptance.

Browser acceptance on the same current-Production clone must prove:

1. Add the current local day, including Sunday; one default Crew A is created.
2. Assign a captain and test task; Report Work saves the correct actual local
   date, crew, duration, progress and notes; reload confirms persistence.
3. Historical entry accepts yesterday and rejects today/tomorrow. Duplicate day
   attempts do not create another work day/default crew.
4. Existing assignment can report a different actual date without moving or
   rewriting the original scheduled assignment. Manager correction uses the
   same local date boundary. Future actual reports are rejected.
5. Authorization, audit, original report history and partial-work continuation
   remain correct. Compare pre/post migration business fingerprints.
6. Review date/timestamp presentation in Schedule, Perform Work, materials,
   pick list and location surfaces. Local dates must agree even if browser
   timezone is UTC. Finish with recorded operator disposition and CLEAN EXIT.

Production classification is DATABASE-CHANGING. After exact candidate review,
use existing Server Management maintenance/freeze/validated snapshot/migration/
return-to-service procedure. Source-only installers cannot deploy this fix.
No Production permission, merge, deployment or actual report save is claimed.
