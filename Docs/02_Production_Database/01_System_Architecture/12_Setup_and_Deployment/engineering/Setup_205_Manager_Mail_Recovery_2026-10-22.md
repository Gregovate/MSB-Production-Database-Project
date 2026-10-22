# Setup Manager mail disconnect recovery — 2026-10-22

| Document control | Value |
| --- | --- |
| Owner | Setup #205 under #122; Server Management owns installation |
| Status | Engineering candidate; not deployed |
| Verified installed sender SHA256 | 8aaa6b56f5e53e461863a9843af68ca5cc8c163c06b25a6c2693d691e9faf5ad |
| Verified source | b46ee9a02f8385ddf6c3071ff0374f2618b48a15 |
| Runtime | /opt/msb-setup-manager-pilot/manager_mail_pilot.py, fieldwiring |
| Service | msb-setup-manager-season-2026.service |

## Incident evidence

The October 22 04:00 America/Chicago timer fired. The first recipient attempt
recorded UNKNOWN_NO_AUTORETRY / SMTPServerDisconnected, and the original sender
aborted before attempting remaining recipients. The journal shows empty Work
Orders worker runs surrounding, but not overlapping, that attempt. Later
operator-run relay checks completed TLS1.3 with verified certificate.
The installed sender hash exactly matches the October18 source. There is no
evidence that the Work Orders rollout replaced this sender or that the first
recipient's account changed. Original disconnect stage and acceptance remain
unknown because the old audit retained only exception class.

## Corrective behavior

Reuse the verified deployed sender and existing templates, People/Setup
recipient authority, approved private roster and single protected receipt ledger.
No report redesign, identity edit, schema migration or timer change.

Record connect, EHLO, STARTTLS, post-TLS EHLO and submission as distinct stages.
Validate EHLO response and verified TLS. Permit at most three attempts only for
connection-disconnect/timeout/connection failures before send_message starts,
with bounded one/two-second delay. Never retry submission. Certificate failures
never downgrade or retry. After successful send_message acknowledgement, socket
cleanup must not erase accepted status. Record stage, original exception class,
connection attempt count and numeric SMTP status when available; never log
credentials, SMTP conversation or message body.

Each distinct recipient has an exclusive durable receipt before SMTP. A failed
recipient does not prevent independently claimed later recipients from being
attempted; final batch status remains nonzero if any attempt failed. Existing
daily receipt collisions still stop a repeated normal daily invocation.

## Explicit October22 recovery

The operator requests repair of today's missing digest. A separate
--recover-unattempted action requires Chicago date October22,2026, the existing
season stop-date/send guards, exact live approved audience, original protected
ledger, and MSB_SETUP_MANAGER_RECOVERY_DATE=2026-10-22. It queries and renders the
current report at recovery time, not a fabricated 04:00 snapshot. It skips EVERY
existing receipt, including unknown, accepted, failed or unreadable records,
without deleting or changing it. Only recipients whose normal daily key does
not exist may get an atomically claimed first attempt. Repeated recovery skips
newly created keys too. No alternate ledger, prior-day backfill or automatic
retry of uncertain sends is permitted. The first uncertain recipient remains
unresolved; recovery success for others must not be called full delivery.

## Validation and deployment boundary

Offline acceptance covers transient pre-submission retry bounds, no retry after
submission, certificate/no-STARTTLS rejection, post-acceptance cleanup errors,
independent recipients, duplicate recovery, unknown receipt byte preservation,
date/approval rejection, and existing report/recipient tests.
The October18 sender regression plus new tests currently passes 47 tests.

Installation/recovery requires the Server Management procedure, exact deployed
hash guard, private backup, preserved templates/env/timer/ledger, no-send
preflight and runtime receipt. No Production installation or email occurred
during engineering. Library packages or chat commands are not deployment proof.
