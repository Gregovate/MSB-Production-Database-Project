## October 18 — Current location/contents conflicts need an actionable Manager review

The operator confirms normal Setup never intentionally **returns a Container from the park while it is still loaded with its Setup Displays**. An email value such as `18 Returned Home` with `0 location/status exceptions` does NOT prove those returns have coherent Display associations. The existing “with contents-review history” number is historical and does not mean exactly that many outstanding active issues; the Manager must see the **actual Container numbers and Display Names**.

**Available now for investigation (read-only):** Open the Setup **Material Status** screen (`/setup/material-status/`) and select **Container Movement**, which contains the movement and Display-effect history. For confirmed cases **C052** and **C053**, the operator separately observed their 32 Tree Wrap Displays installed at Festive Trees despite the recorded returned-Container associations. This report is for evidence, not an update/resolve facility. Do not repeat scans to invent missing October 9 unload facts or hand-edit returned status. The #88 Manager Contents Review/Resolve facility remains unimplemented; it must be built and browser-tested before any email **“Review / Correct”** deep link is called operational.

**Required future result:** the daily mail links to the exact affected Container's protected Manager case, with all current named Displays, recorded Home/park status, chronology, physical field evidence and open/resolved classification. The Manager decides whether to verify in field, annotate uncertainty, or authorize a guarded #88 event correction preserving later independent Display observations. Only genuine authoritative evidence closes a case; merely opening it does not. Email reports discrepancies and decisions, but does not automatically change Container/Display or Setup-task completion.

## October 18 — daily Manager email until 2026 show opening

The approved October 17 initial 04:00 report was a one-day pilot; it **did not schedule October 18 or any later day**. The operator now requests an immediate, specifically approved missing October 18 Manager report and then an automatic **04:00 America/Chicago** briefing every morning until the show opens, **November 27, 2026**, or an earlier Manager-selected cutoff.

**Default:** the last scheduled email is **November 27 at 04:00 AM** (the morning of show opening); none on November 28 or later. The Administrator can request an earlier YYYY-MM-DD cutoff before then. Future cutoff changes must go through the governed server procedure; do not assume this first candidate installs an editable Setup settings screen or that changing a browser field already controls a timer. The server timer must use finite year-2026 calendar entries and its runner must independently decline sends outside its date/time gate. No unbounded daily recurrence, no late/catch-up replay, and no Captain messages.

**Today's exception:** an Administrator can execute the separately guarded `--send-today` **once on October 18 only**. It recalculates current task, readiness, Container and assignment figures at execution rather than reusing yesterday's 296/90/206 snapshot, sends to the same authorized seven Managers, and creates today's distinct immutable per-recipient receipts in the existing secure mail ledger. The original October 17 delivery and all test receipts remain untouched. After a failed/uncertain attempt, inspect the ledger before trying anything else; do not rerun or reset it to force duplicates. SMTP acceptance is not Inbox delivery proof.

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

## White logo acceptance — one remaining header refinement

The operator's actual formatted Gmail screenshot confirms the report structure and Container/Manager sections are useful. The only requested presentation correction is the **white MSB logo at the top of the dark blue header**. This artwork already belongs to Setup dark mode at `https://webassets.sheboyganlights.org/images/branding/msb-white-logo-600-plain.svg`; no new logo design is needed.

For Gmail delivery, confirm the image **actually displays**. A working SVG on the Setup website does not prove it renders in email; if the preview/test does not display it, the controlled email-ready **PNG derivative of the same approved SVG** must be published through the existing MSB webassets workflow. Don't mistake a source-included image tag for a received, visible logo. Keep all other text/figures and layout unchanged. No broad-send approval follows from this visual correction.

## Final white-logo Gmail review — October 17

The operator confirms the email-ready white PNG already exists in the same established MSB webassets branding folder as the dark-theme SVG: `msb-white-logo-600-plain.png`. The revised Gmail mail retains the accepted HTML layout and shows this white PNG at the top of the navy banner. Only this logo link changes.

The operator requests **one final Gmail test to their own mailbox only**, not another `--preview`, not a group distribution. This test uses a distinct `FINAL LOGO TEST —` subject and new durable attempt purpose `MANAGER_LOGO_REVIEW_TEST`; preserve the earlier plain and formatted test records. Confirm actual Inbox arrival and that the white logo appears. Check no other portion of the report or sender was changed. No Manager-wide or Captain activation follows automatically.

## October 17 final layout and 04:00 request

The operator confirmed the final white PNG displays in Gmail and requests the **same logo larger, to the left of** “Setup Morning Brief”. The larger white logo must remain clear on the navy background, with no change to the rest of the report. Source acceptance tests must check the table layout and identical hosted asset.

The operator also requested the first automated **04:00 Manager-only email**. The prior one-recipient delivery tests did **not** activate any service. Before 04:00 activation, reconcile the exact audience against People and current Setup Manager privileges. As of the latest read-only People query five records are eligible (Rick, Greg, Rich, Eric, Tom), one active People Manager (Don) is **HELD because identity is not linked**, and one person (Randy) is Setup-authorized but not marked Manager in People. Do not silently exclude/include either without operator decision. The currently guarded sender stops on any held People Manager. The accepted Server Management timer installation/health check is mandatory and must produce a specific active future trigger, not a planning claim. Never send a catch-up email if setup isn't complete by 04:00, and do not enable Captain notifications.

## First Manager email: operator-confirmed recipient interpretation

For October 17, Randy's Setup Manager capability is intentional and Don's missing People-to-Directus link is an onboarding follow-up, not an email disqualification. An active People contact is eligible if marked as a People Manager OR currently authorized in Setup as a Manager, with a unique valid MSB email. Seven named recipients must match the operator-reviewed list before dispatch. Keep the mismatches as review notes without editing identities. Captain sending stays OFF.

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
