# #205 Setup — Existing Google Workspace SMTP Transport (October 16, 2026)

| Control | Value |
|---|---|
| Authority | #205 under #122, V0.3.84 production preserved |
| Status | **PRODUCTION RELAY PREFLIGHT VERIFIED; SMTP SEND AND NOTIFICATION WORKFLOW NOT YET ACCEPTED** |
| Candidate | [PR #412](https://github.com/Gregovate/MSB-Production-Database-Project/pull/412) |
| Role | Delivery transport only; no Directus Flow, no additional web server/container |

## Operator-confirmed relay facts

Greg inspected the existing Google Workspace Admin Console **SMTP relay service** entry *Local Network Machine Device Emails* on October 16. This entry is **Enabled**. Its Allowed Senders is **Only addresses in my domains**. It accepts traffic from the specified public IP **69.21.78.70**. **Require SMTP Authentication** is unchecked. **Require TLS encryption** is checked.

Greg then executed read-only commands on the MSB server at internal `192.168.5.9`:
- `curl -4 -sS https://api.ipify.org` produced **69.21.78.70**.
- `openssl s_client -starttls smtp -connect smtp-relay.gmail.com:587 -servername smtp-relay.gmail.com -brief < /dev/null` produced **CONNECTION ESTABLISHED**, **TLSv1.3**, **TLS_AES_256_GCM_SHA384**, peer certificate CN `smtp-relay.gmail.com`, **Verification: OK**, and `250 SMTPUTF8`.

**Interpretation:** public source IP matches Workspace relay restriction; STARTTLS/certificate/port accessibility have been demonstrated. This is *not* proof that a real message has been accepted by SMTP DATA, entered an inbox or been read. Existing Google Admin rule is unchanged.

## Implementation contract

- `Setup/Application/setup_google_smtp.py`: narrowly scoped Python `smtplib` transport, fixed `smtp-relay.gmail.com:587`, mandatory STARTTLS with Python default certificate validation, single `@sheboyganlights.org` recipient and sender, `EmailMessage` plain text, no SMTP AUTH/password, no plaintext fallback, no direct retries on an uncertain outcome.
- Sender must be configured explicitly as `SETUP_NOTIFICATION_FROM_EMAIL` outside Git and approved as an MSB organizational sender. Do **not** invent a sender identity, mailbox or credential. `SETUP_NOTIFICATION_SMTP_SEND_ENABLED` defaults off and must remain off until separate governed acceptance.
- Transport return `SMTP_ACCEPTED_NOT_DELIVERED` means relay accepted the SMTP submission. Do not claim inbox delivery. Provider exceptions/timeouts mean unconfirmed; reconcile against the durable notification ledger before retry.
- The existing deferred Directus Outbox client and migration 074 from the held branch **are superseded candidate code**, not an approved runtime path. Refactor queue/ledger to PostgreSQL-owned status/audit, no Directus Flow trigger or token. Since migrations 075 and 076 are deployed, check the current installed migration ledger and use the next authorized migration identity (expect 077 after verification), not retroactively apply an old candidate 074 out of order.
- The sender must only be called by fresh, authorized Setup notification logic (Manager Email to Myself, Manager Request Report and Chicago 04:00 digest); obtain current recipient eligibility and the exact reporting occurrence. A valid partial or 100% report suppresses missing-report mail. Keep atomic per-recipient/per-day/per-original-assignment deduplication.
- Manager daily email must include full whole-Setup Total / Complete / Remaining, blockers, verified task-based pace vs required pace, deadline projection/confidence plus actionable missing-report/continuation ledger. Never claim estimates or recipient delivery that are not supported by actual source data.
- When ready, conduct one operator-approved, **single-recipient test** using the real Workspace relay and review received subject/body/links. Then run full Setup/FieldWiring regression, current-Production single disposable clone, protected browser review with CLEAN EXIT, exact new version, and #122/#37 governed Production migration/activation. Activate unattended 04:00 America/Chicago mail only after separate operator approval.

## Explicit exclusions

No Synology mail-server integration, no replacement email provider, no new always-on daemon or Docker container, no generic message bus, no Work Order UI rewrite, no Directus event-flow trigger. Existing Directus Work Order flows are untouched. Setup remains V0.3.84 in Production until approved.
