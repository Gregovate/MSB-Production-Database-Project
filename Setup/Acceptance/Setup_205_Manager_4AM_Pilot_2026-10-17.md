# #205 — Manager-only 04:00 pilot, October 17, 2026

| Item | Status |
| --- | --- |
| Operator requested | Oct 16, ~20:34 America/Chicago |
| Desired first occurrence | **2026-10-17 04:00 America/Chicago (CDT)** |
| Sender | MSB Production DB <no-reply@sheboyganlights.org> |
| Recipient audience | Current authorized active Setup Managers, dynamically obtained from authoritative `ref.person` + Google-backed Directus role/capability on send |
| Captain or general volunteer recipients | **NONE** |
| Actual 04:00 Production scheduler | **NOT INSTALLED; DELIVERY NOT CONFIRMED** |
| DB/Production migration | Not approved/installed for #205 |
| Branch | Draft [PR #412](https://github.com/Gregovate/MSB-Production-Database-Project/pull/412), under #205/#122 |

## Time-critical operational intent

The pilot is for **Managers only**, so Managers have time to correct historical no-work, reporting and rescheduling before the Captain reminder channel is activated. The first email must educate Managers on the difference among original no-report, reported-but-unfinished, continuation, readiness and speculative Pick List scheduling. A 04:00 Manager summary can continue to identify unresolved items daily; **no automatic Captain email is sent** until the particular original occurrence is reviewed and approved by a Manager, and the SMTP dispatcher rechecks it.

Do not equate the October 16 operator screenshot with October 17 04:00 data. At 04:00, retrieve a fresh 2026 Session/Scheduling Board read from current Production and calculate the email fields from the same authoritative projections as the two Setup screens. No fabricated counts or recipients. When projection evidence is insufficient, report `not verifiable` instead of a false deadline forecast.

## Editable manager-only initial template (for operator review, not yet wired to PostgreSQL)

**Template key:** `MANAGER_DAILY` (subject/body to be maintained through Administrator-controlled DB template UI in the accepted implementation).

**Subject:** `MSB Setup — Manager Action Report — {{report_date}}`

**Body:**

Hello {{recipient_name}},

This is your current **2026 Setup Manager Action Report**. It is intended to help us resolve reporting and planning issues before anyone receives an unnecessary Captain reminder.

**Overall Setup progress**

Total tasks: **{{total_tasks}}**  
Completed: **{{completed_tasks}}**  
Remaining: **{{remaining_tasks}}**  
Blocked or NOT READY: **{{blocked_tasks}}**  
Actual completions, last 7 calendar days: **{{actual_tasks_per_day}} per day**  
Needed to meet our November 19 deadline: **{{required_tasks_per_day}} per day**  
Task-based projected finish: **{{projected_finish_or_unavailable}}** ({{projection_confidence}})

**Manager actions requiring review**

- Past scheduled assignments with no matched work report: **{{missing_report_occurrences}}**
- Started tasks with no current/future continuation assignment: **{{continuation_needed}}**
- Upcoming scheduled readiness/Work Order exceptions: **{{upcoming_readiness_exceptions}}**
- Scheduled work with no identified Captain: **{{captain_tbd_count}}**

**What we need you to do**

1. Open the protected **Setup Action Center**: https://my.sheboyganlights.org/setup/
2. For each past assignment without a report, determine whether the work actually happened. A missing report does not prove that a volunteer failed to report.
3. **If no work occurred as planned:** use the existing Manager **Reschedule · No work performed** process when eligible. Preserve the original schedule audit; do not invent hours, crew size, Minutes, or completion percentage.
4. **If real work occurred but the report is missing:** confirm the original task/date/shift/Captain. Mark the occurrence for a later reviewed Report Work reminder and help the Captain enter actual work when necessary.
5. **If a partial or full work report exists:** that occurrence has been reported. Do not send a missing-report reminder. A partially completed task may still need a future continuation date.
6. Review NOT READY, blocked and overcommitted work separately. These are scheduling/readiness issues, not automatic reasons to email Captains.
7. If you are uncertain, hold the case for Manager follow-up instead of guessing.

**Why we're beginning with Managers**

We are establishing a consistent reporting process. Once Captain reminders are enabled separately, they will only concern **verified, Manager-reviewed original work that was performed but is still unreported**. Reminders will explain how to report actual work, who to contact when **no work occurred**, and who can help with reporting. No one should enter fictitious results merely to clear an alert.

**What happens if an item is not resolved?**

It remains visible as a Manager Action Center exception and, while Manager email is enabled, continues to appear on future Manager summaries. A missing report alone will **not** automatically cause a Captain email during this Manager-only phase. Unresolved partial work still requires realistic rescheduling. No email or lack of response changes a task's recorded actual progress.

Thank you for helping us keep 2026 Setup records accurate.

MSB Production DB — automated Manager status message. This inbox does not accept responses. Use the protected Setup application and your normal Manager communications for decisions.

---

## Non-negotiable activation gates

1. Validate exact authenticated, active current Manager list and fresh 2026 board data at send time; no personal addresses/active-status inference from a reserved Person email alone; no external volunteer recipient.
2. Actual plain-text/HTML template is editor-controlled and revised/audited, not permanently hardcoded in the transport.
3. For each Manager and Chicago calendar day, record a unique send key / accepted-or-failed result; reruns must not duplicate accepted recipients. SMTP accepted is not inbox delivered.
4. **Unreviewed Captain output = zero**, including when a Manager later reviews the email. Draft #412 has fail-closed Captain planning but not DB approval.
5. Preview actual Manager body and recipient count and run a controlled one-recipient/one-message test. Any send to all Managers requires operator-approved content and acceptance.
6. Install a single 04:00 `America/Chicago` systemd timer / runner using the **Server Management-owned runbook** only after runbook/read-only preflight, source and DB acceptance, controlled deployment and #122 approval.
7. If those cannot be completed before Oct 17 at 04:00, mark the scheduled email **NOT ACTIVATED**. Do not silently claim it was sent or install an ungoverned cron/temporary production script. An operator-reviewed manual Manager email may be used as an explicitly separate fallback, without claiming live database metrics.
