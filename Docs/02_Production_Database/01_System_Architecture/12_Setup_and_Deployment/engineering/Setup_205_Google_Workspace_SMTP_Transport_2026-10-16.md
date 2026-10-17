# #205 Setup — Existing Google Workspace SMTP Transport (October 16, 2026)

| Control | Value |
|---|---|
| Authority | #205 under #122, V0.3.84 production preserved |
| Status | **PRODUCTION HOST → GOOGLE WORKSPACE INBOX TEST PASS; APPLICATION NOTIFICATION WORKFLOW NOT YET ACCEPTED** |
| Candidate | [PR #412](https://github.com/Gregovate/MSB-Production-Database-Project/pull/412) |
| Role | Delivery transport only; no Directus Flow, no additional web server/container |

## Operator-confirmed relay facts

Greg inspected the existing Google Workspace Admin Console **SMTP relay service** entry *Local Network Machine Device Emails* on October 16. This entry is **Enabled**. Its Allowed Senders is **Only addresses in my domains**. It accepts traffic from the specified public IP **69.21.78.70**. **Require SMTP Authentication** is unchecked. **Require TLS encryption** is checked.

Greg then executed read-only commands on the MSB server at internal `192.168.5.9`:
- `curl -4 -sS https://api.ipify.org` produced **69.21.78.70**.
- `openssl s_client -starttls smtp -connect smtp-relay.gmail.com:587 -servername smtp-relay.gmail.com -brief < /dev/null` produced **CONNECTION ESTABLISHED**, **TLSv1.3**, **TLS_AES_256_GCM_SHA384**, peer certificate CN `smtp-relay.gmail.com`, **Verification: OK**, and `250 SMTPUTF8`.

**Operator-confirmed end-to-end SMTP test — October 16 at approximately 19:39 America/Chicago:**
- Using a one-time standalone Python `smtplib` script run on the MSB Production server, Greg sent **one test message** through `smtp-relay.gmail.com:587` using mandatory STARTTLS and system certificate verification, with the existing `MSB Production DB <no-reply@sheboyganlights.org>` sender.
- The sole recipient was Greg's verified organizational mailbox, `gliebig@sheboyganlights.org`. Subject: **MSB Production DB - SMTP Test**.
- Terminal printed **SMTP ACCEPTED - Now check your mailbox.** Greg then confirmed the actual message appeared in the Gmail Inbox with the expected From, subject and test body.
- This proves the approved host and Workspace relay can deliver a real email to the tested mailbox. It does **not** test PR #412's `setup_google_smtp.py` directly, the PostgreSQL notification outbox, application routes, eligible-recipient resolution, work-report suppression, failure audit, real Captain recipient, or unattended 04:00 dispatch. No change to Workspace settings, Production application code, Postgres schema or scheduled services was made.

**Earlier network preflight:** Public source IP and TLS reachability are also confirmed independently. Existing Google Admin rule remains unchanged.

**Existing unattended sender identity (operator-confirmed):** Work Order triage already uses **MSB Production DB** `<no-reply@sheboyganlights.org>`. Reuse this for **automated** #205 reports/reminders and never present it as a reply address. For an **authorized manually composed/sent** notice, schedule publication, or team event invitation, the intended From is the **logged-in sender's own verified, provisioned `@sheboyganlights.org` mailbox and display name**, derived server-side through the existing trusted application identity and sender permission. A known Cloudflare/Directus user or reserved `ref.person.email` does not alone prove the mailbox exists. The Google IP-authorized relay must never become an arbitrary From impersonation path; actual human-From SMTP acceptance and received RSVP reply remain an explicit acceptance test. If a person lacks a provisioned MSB mailbox, do not silently claim From in their name; an explicitly approved system From plus safe Reply-To may be designed after review.

## Implementation contract

- `Setup/Application/setup_google_smtp.py`: narrowly scoped Python `smtplib` transport, fixed `smtp-relay.gmail.com:587`, mandatory STARTTLS with Python default certificate validation, **single syntactically validated recipient at any domain**, with **From constrained to a valid `@sheboyganlights.org` address**, `EmailMessage` plain text, no SMTP AUTH/password, no plaintext fallback, no direct retries on an uncertain outcome. Google Workspace's *Only addresses in my domains* restriction applies to **senders**, not recipients. Per-message eligibility, consent and privacy policy are enforced by the Setup notification/People workflow **before invoking SMTP**.
- Configure `SETUP_NOTIFICATION_FROM_EMAIL=no-reply@sheboyganlights.org` in protected Setup runtime configuration **only during an authorized deployment**, not in Git. For **automatic** messages, use `MSB Production DB <no-reply@sheboyganlights.org>`. The sender accepts an optional validated MSB-domain **From** and safe per-message display name for **manually initiated** communication; upstream code must bind it to the actual authenticated, authorized and provisioned Workspace sender and reject browser-supplied spoofing. No invented sender, mailbox, alias, credential or Reply-To. `SETUP_NOTIFICATION_SMTP_SEND_ENABLED` defaults off and must remain off until separately governed acceptance.
- Transport return `SMTP_ACCEPTED_NOT_DELIVERED` means relay accepted the SMTP submission. Do not claim inbox delivery. Provider exceptions/timeouts mean unconfirmed; reconcile against the durable notification ledger before retry.
- The existing deferred Directus Outbox client and migration 074 from the held branch **are superseded candidate code**, not an approved runtime path. Refactor queue/ledger to PostgreSQL-owned status/audit, no Directus Flow trigger or token. Since migrations 075 and 076 are deployed, check the current installed migration ledger and use the next authorized migration identity (expect 077 after verification), not retroactively apply an old candidate 074 out of order.
- The sender must only be called by fresh, authorized MSB notification logic, including the #205 Manager self-email, Report Work reminders, consolidated **published** schedule notices for all affected volunteers, and 04:00 Manager digest. Before invoking SMTP, resolve current recipient contact, per-category preference/opt-out, authorization appropriate to the content, published versus speculative schedule and, when applicable, exact reporting occurrence. A valid partial or 100% report suppresses missing-report mail. Keep atomic per-recipient/per-day/per-original-assignment deduplication. Ordinary optional volunteer communications (e.g., annual team run-walk cookout) may reuse this sender later through a deliberate preview/approval workflow, not by inventing scheduled Setup work.
- Manager daily email must include full whole-Setup Total / Complete / Remaining, blockers, verified task-based pace vs required pace, deadline projection/confidence plus actionable missing-report/continuation ledger. Never claim estimates or recipient delivery that are not supported by actual source data.
- A **real single-recipient Workspace email from the MSB server** was already accepted and received on Oct 16 (see evidence above). The PR #412 application's SMTP sender is separately covered by mock-network tests including *external recipients*, sender restriction, malformed addresses, STARTTLS and timeout behavior; neither implies Setup outbox/Flask/authorization acceptance.
- When ready, conduct one operator-approved, **single-recipient test** using the real Workspace relay and review received subject/body/links. Then run full Setup/FieldWiring regression, current-Production single disposable clone, protected browser review with CLEAN EXIT, exact new version, and #122/#37 governed Production migration/activation. Activate unattended 04:00 America/Chicago mail only after separate operator approval.

## Editable message templates and RSVP sender acceptance

Authoritative [#205 accountability contract](Setup_205_Schedule_Performance_and_Daily_Accountability_Contract_2026-10-15.md) now requires **database-stored, Administrator-editable subject/body templates**, safe allowlisted placeholders, preview/test-send, version/audit and clear default-vs-one-off composition for manual volunteer events. No sentence in `setup_notification_service.py` or `setup_google_smtp.py` should be a long-lived hard-coded user-facing email body. The SMTP sender deliberately transports an already-rendered, authorized, audited message; the authenticated Flask/notification layer must supply its verified human sender, template revision and recipient decisions. System reports may continue using no-reply; human-sent run-walk cookout mail should have a replyable provisioned Workspace From and actual reply-to-organizer inbox proof.

**Current status:** The SMTP transport and mock tests accept the optional safe human display identity; **no template editor, PostgreSQL template table, authenticated-person sender binding, event composer, live human-sender relay test or received RSVP reply has been implemented/accepted/deployed**. Do not present them as working features.

## Explicit exclusions

No Synology mail-server integration, no replacement email provider, no new always-on daemon or Docker container, no generic message bus, no Work Order UI rewrite, no Directus event-flow trigger. Existing Directus Work Order flows are untouched. Setup remains V0.3.84 in Production until approved.
