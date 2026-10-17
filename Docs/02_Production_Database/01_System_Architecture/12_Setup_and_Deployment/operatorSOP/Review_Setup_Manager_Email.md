# Review the Daily Setup Manager Email

| Document control | Value |
| --- | --- |
| Document type | **Operator Procedure — Manager / Administrator** |
| Owner | MSB Production Database / Setup Administrator |
| Status | **CANDIDATE PROCEDURE — Manager email NOT YET ACTIVE** |
| Audience | Setup Managers and Administrators |
| First proposed delivery | October 17, 2026, 4:00 AM Central time |
| Application | [Open Setup](https://my.sheboyganlights.org/setup/) |

## What this email is for

The Manager email helps us identify what Setup has finished, what remains, what is blocked, and whether we are on pace for the **November 19** deadline. It identifies scheduling/reporting discrepancies so Managers can correct them **before volunteers receive unnecessary reminders**. It is not a demand that Captains report work that never happened.

**Important status:** The current V0.3.84 Setup Action Center is available, but automatic Manager email and the Administrator email settings are **not yet installed**. This procedure describes the intended reviewed workflow; do not expect a 4:00 AM message until installation is separately approved and confirmed.

## What the morning email looks like

The subject is **MSB Setup — Manager Actions — [report date]**. Read it from the top: first **Total / Completed / Remaining**, then actual versus required task-based pace and the November 19 deadline. The next section gives separate counts of **past assignments to verify**, **started work needing a continuation**, and **upcoming readiness issues**. Individual task names and dates are below those decisions, not ahead of the main status.

The email deliberately uses the words **review** and **verify**, not “Captain failed to report.” A missing report is not proof that any work happened. The final line explains that unresolved exceptions remain visible and **Captain reminders are OFF** during the Manager pilot. The one-day pilot is not a promise that a recurring daily email is already installed.

## Preview who will receive the emails — Administrator

**This preview page is part of the new candidate; it is not installed in today's Production Setup.**

1. Open [Setup](https://my.sheboyganlights.org/setup/) with your normal MSB account and choose **Manager Action Center**.
2. As an authorized **Setup Administrator**, open **Email Notifications — Review recipients**. (The candidate address is `https://my.sheboyganlights.org/setup/notifications/`; it will work only after the approved release.)
3. Review the **Manager daily email** section. The starting list comes from **People (`ref.person`)**: active persons marked **Manager**. The screen shows their actual names/emails, whether they are **Eligible** for this initial Manager-only email (current Setup Manager permission and linked identity), and any **Held** record needing review. Review authorized Setup Managers without the People Manager flag as a separate discrepancy; those are not added silently.
4. Confirm **From: MSB Production DB <no-reply@sheboyganlights.org>**, **Captain reminders: OFF** and **Automatic send: NOT ACTIVATED**. A preview does not turn anything on.
5. Select **Refresh preview** to reread People and the 2026 Setup data. Compare the date, Total / Completed / Remaining, and the exception list against the **Manager Action Center**.
6. Check missing/extra Managers and any **Held** rows in **People Manager** and existing Setup access controls. The People Manager flag is a recipient-directory designation, not a permission grant; do not change Directus roles or the email sender just to clear the review. **Do not approve a broadcast until the actual eligible list matches the intended audience.**
7. Only **after** the roster and report are correct, approve the separate single-recipient actual email test to **your own** verified MSB mailbox. Verify that it arrived **from the Production DB sender**, not your Gmail personal account.
8. Review the email in Gmail, request corrections if needed, and separately decide whether to authorize Manager-wide sending. **Captains remain excluded.**

If the preview is unavailable, shows a **STOP** condition, or does not show real names/addresses, do not send the test or enable the timer. Do not assume a ChatGPT mockup or previous screenshot is a live roster.

## What to look for in the revised Gmail message

The first real Production SMTP test reached the operator's Inbox, but the **plain-text appearance and omitted Container progress were not accepted**. The next candidate must render a clear HTML email in Gmail, with a complete plain-text fallback. Start with three large **Total / Completed / Remaining** numbers, actual-versus-required task pace and November 19, then a separate **Containers — field movement** section above the task follow-up lists.

Container counts must be labeled carefully: **park location recorded** (not just Picked), **picked/on the way**, **empty at park based on recorded Display associations** (physical contents not confirmed), **partially unloaded at park**, **returned Home** (recorded empty return), and **not yet observed/uncertain**. Empty and partially unloaded are *subsets* of park-location Containers, so do not add all these columns together. The report should say where its Container information came from and when it was refreshed.

Below the Container section, see actionable work-report exceptions and unfinished continuations in readable, compact rows rather than repeated long lines. The protected **Email recipients & preview** Administration page will show the proposed HTML email and the exact live recipient list. That page must pass browser acceptance before wide mail is approved. The first received text test does not authorize the next send or the 4:00 AM timer; Captains remain OFF.

## The new formatted test email — separately from the no-send preview

The read-only server preview displays actual 2026 task/Container counts and reports `sent: 0`. **It does not appear in Gmail.** If it prints `HTML alternative: prepared, NOT SENT`, that is source/data validation only.

After accepting the no-send data, a separate operator-confirmed `FORMATTED TEST — MSB Setup — Manager Actions — 2026-10-17` may be sent **only to gliebig@sheboyganlights.org**, from `MSB Production DB <no-reply@sheboyganlights.org>`, using the current tested HTML and a complete plain-text alternative. It is identified as **Manager formatted-review test**, not a resend of the original received plain-text email, and its own duplicate-prevention record must be preserved. Do not repeat the formatted test if delivery status is uncertain.

Open that Gmail message to inspect colors, font sizes, mobile width, the **296/90/206** style of progress header, actual recorded Container counts, and compact task lists. Check **actual current** numbers rather than assuming earlier October 17 values remain unchanged. Approval of formatted presentation is a decision the Manager makes **after** seeing the Inbox message. The recipient Management interface and any Manager-wide activation remain separately unapproved; Captains remain OFF.

## Before the first email is enabled — Administrator review

1. Open the **Setup** application with your normal Sheboygan Lights Google Workspace account. Select the **2026** season.
2. Open the **Manager Action Center**. Check that the whole-Setup **Total, Completed and Remaining** match what you expect. Review the **Past occurrences awaiting reports** and **Incomplete tasks needing continuation** groups.
3. Review the exact **email preview** supplied for the candidate. Check task names, dates, crew/shift and the plain-language instructions; inspect all Manager recipient addresses drawn from the current authorized People records. **The preview must not send any message.**
4. Ensure the report states **Captain reminders are OFF**, and does not treat every unfinished or NOT READY task as a missing work report.
5. Review the separately approved **one-recipient test**, sent only to your own authorized Manager mailbox. Open it in Gmail and confirm the sender, subject, legibility and links. A “queued” or “SMTP accepted” result does **not** prove it arrived in your Inbox.
6. Tell the directing engineer whether the preview/test is **Approved**, **Changes required**, or **Stop**. Do not approve installation merely because the SMTP connection works.

The first pilot is **Managers only**, not a broadcast to Captains or all volunteers. The release process must show the actual date/time, recipient count and delivery outcome before enabling a timer.

## When you receive the Manager report

1. Start with **Total / Completed / Remaining**, actual completions per day, required completions per day, and task-based projected finish. If the email says **insufficient data**, the forecast is unknown; do not read it as on track.
2. Open [**Setup**](https://my.sheboyganlights.org/setup/) and the **Manager Action Center**. The email reflects a morning snapshot; the live screen may have changed since it was generated.
3. Expand **Past occurrences awaiting reports**. Review each original scheduled **Task name, Setup Day/date, Crew, Captain and AM/PM shift**. A missing report is **not proof that work took place**.
4. **If no work happened**, locate the original assignment in **Perform Work**, choose **Reschedule · No work performed** where offered, select the correct current/future Work Day and crew, and confirm. A Manager may use the existing **Reschedule unworked AM/PM tasks** option for multiple genuinely unworked shift assignments. **Do not create a fake 1% report or enter fake hours/minutes.**
5. **If real work happened but the report is missing**, contact the Captain and help obtain a truthful work report for the **original occurrence**. Report the actual work date, actual number of people, elapsed Hours/Minutes, cumulative task percent and what remains.
6. **If work was already reported**, even partially, **do not send a missing-report reminder**. For unfinished tasks open **Incomplete tasks needing continuation** and use **Plan continuation** to schedule remaining work without rewriting worked history.
7. Review **NOT READY / blocked / upcoming readiness** independently. Resolve material/prerequisite/Work Order issues or correct the plan; these classifications are **not reasons by themselves** to email Captains.
8. If you're uncertain whether work happened, confirm it with the crew or another Manager. Keep it flagged for review; **do not guess** or clear the history just to remove a warning.

## What happens when a Manager does not act?

The unresolved exception stays in the Manager Action Center and may appear in later **Manager-only** summaries. Email does **not** complete or reschedule a task. During this first pilot, **Captain reminder emails remain OFF**. Later Captain reminders will require a Manager's review of the actual original occurrence and a fresh check that an actionable report is still missing.

## Administrator email controls — not yet available

The accepted planned controls are: **automatic mail master on/off**, **Manager daily report on/off**, and **Captain reminder on/off**. Template editing, manual sending, individual preferences and delivery/audit history belong to the later #205 mail application release. Until those controls are installed, do **not** assume toggles exist in the Production browser and do not attempt to change an email server setting to pause Setup reminders. Contact the Setup Administrator or the directing deployment engineer to stop an installed pilot.

## If something is wrong

- **No email arrives:** check Gmail Inbox/Spam, then ask the Administrator to verify that the pilot was actually installed/enabled, that your current Manager access is valid, and the per-recipient SMTP result. Do not tell the operator to repeatedly re-run an uncertain send.
- **Wrong recipient or someone no longer a Manager:** stop further sends and notify the Administrator. The current People identity and Setup Manager access must be reviewed.
- **Wrong task, schedule or completion figures:** compare with the live 2026 Setup screen; request an engineering review before trusting the email for scheduling decisions. Do not edit real work data merely to force the numbers to match.
- **No work was performed:** **Reschedule · No work performed**, with Manager confirmation; do not fabricate reporting data.
- **A report exists but email calls it missing:** verify **Progress history**, the original task/day/crew and, when needed, use **Correct report**. Do not create a duplicate.
- **Email says Captain reminders are already active:** treat this as a release discrepancy. The first Manager-only pilot expressly excludes Captain email.

## Expected result

Managers can see whole-Setup progress, distinguish real reporting obligations from scheduling corrections, assign truthful follow-up and reduce unnecessary volunteer email. No Actual Work or Schedule history changes merely because an email was opened.

## Related operator instructions

- [Perform and Report Setup Work](Perform_and_Report_Setup_Work.md) — currently installed reporting, corrected historical work, no-work rescheduling and continuation.
- [Setup Manager Review Guide](../../../02_Operational_SOPs/Setup/Setup_Session_Manager_Review_Guide.md) — Manager planning and materials.
- [Engineering authority](../engineering/Setup_205_Manager_Email_Engineering_2026-10-16.md) — implementation/acceptance, not needed for ordinary operator actions.
