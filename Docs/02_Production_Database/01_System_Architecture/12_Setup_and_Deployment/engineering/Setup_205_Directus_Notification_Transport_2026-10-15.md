# Setup #205 — Dedicated Directus Event-Flow Mail Handoff

| Document Control | Value |
|---|---|
| Status | IMPLEMENTATION CANDIDATE — NOT ACTIVATED; Directus flow setup and browser acceptance pending |
| Owner | Setup #205 under commanding #122 |
| Last reviewed | 2026-10-15 |
| Related | [Daily Accountability Engineering Contract](Setup_205_Schedule_Performance_and_Daily_Accountability_Contract_2026-10-15.md) |

## Decision

Reuse **the existing Directus mail service**, not the Work Order event flows and not a new SMTP client. Create a **separate Setup-specific Directus Event Hook Flow** that fires on authenticated Items API `items.create` for only `setup_notification_outbox`. In Directus, an Event Hook is invoked by the Items API, not arbitrary PostgreSQL INSERT. An incoming **Webhook Flow is NOT used**, because a webhook-triggered flow is publicly invokable by design and unsuitable as an unrestricted email trigger.

The new Flow MUST be installed in inactive state until it passes disposable security, recipient, idempotence, rendering and delivery acceptance. Do not modify the current `WOI Request Triage Email` or `Work Order Email Assignees` flows.

```text
04:00 America/Chicago controlled Setup runner (NOT installed)
  OR Manager authenticated Email to Myself / Request Report
      -> current PostgreSQL 2026 board + eligible current Person/Directus identities
      -> distinct daily Manager/Captain message plans
      -> dedicated Setup server-side Directus token
      -> POST local http://127.0.0.1:8055/items/setup_notification_outbox
      -> unique message_key enforced in PostgreSQL
      -> Directus Event Hook: items.create (this collection only)
      -> Directus existing Send Email operation
      -> success/failure status update + Directus flow audit
```

## Components committed on PR #394

- `Setup/Database/074_add_setup_notification_outbox.sql` — new sensitive outbox, database-unique `message_key`, recipient domain, audit/status and restricted Directus metadata. CANDIDATE migration; **not applied**.
- `Setup/Application/setup_notification_service.py` — derive missed past occurrences from original assignment/report, current/future continuation, imminent blocked/NOT READY and Captain TBD; resolve dynamic verified active People↔Google Directus identity and existing Setup capabilities; produce Manager and per-Captain consolidated text; POST only local authenticated Directus Items API.
- `Setup/Application/setup_notification_api.py` — authenticated Manager-only preview, `Email to Myself` to the current verified Manager only, and `Request Report` on original overdue reportless assignment to only its verified Captain. Browser input cannot choose recipients or body.
- `Setup/Application/setup_205_daily_notifications.py` — `--dry-run` default read-only counts and explicit `--queue` only; not installed to cron/timer.
- `Setup/Application/test_205_setup_notification_service.py` — isolated dry-run/eligibility/duplicate/transport tests, no real sends.

Runtime env (outside Git): `SETUP_DIRECTUS_URL` (loopback local only), `SETUP_DIRECTUS_NOTIFICATION_TOKEN` (separate least-privilege Directus identity), `SETUP_NOTIFICATION_TEST_SEND_ENABLED` and `SETUP_NOTIFICATION_DAILY_ENABLED` (both OFF unless exactly `1`). Do not reuse the WO Intake credential or give the notification service token generic Flow/mail/admin permissions.

## Exact Directus Flow installation contract — gated, not yet performed

First inspect actual existing Work Order mail flow configuration, existing Directus version, collection mapping, existing mail operation options and current Directus policies on the **same current-Production disposable clone**. Using that verified configuration, install a new INACTIVE flow under the owning Directus configuration mechanism:

1. Name: **Setup Daily Accountability Email**. Trigger: **Event Hook**, Action (non-blocking), scope **items.create**, collection **setup_notification_outbox** ONLY. Never a public Webhook or manual/public trigger.
2. Condition/check: restrict `kind` to `MANAGER_DAILY`, `CAPTAIN_DAILY`, `CAPTAIN_REQUEST`, `MANAGER_SELF_TEST`; recipient under `@sheboyganlights.org`, appropriate identity and existing unique message-key row. The Setup producer independently checks live authorization and identity before creating the item.
3. Email operation: use the existing Directus **Send Email** transport and sender settings, with `recipient_email`, `subject`, and `body_text` mapped from the **new item**, not client-supplied user input or Work Order fields. Confirm the installed Directus version's exact payload keys in a disposable Flow log and ensure plain-text newlines/escaping render safely.
4. Record status using a Flow operation based on actual email operation outcome: `DIRECTUS_ACCEPTED` only after the mail operation returns success, `FLOW_FAILED` with redacted error on failure, `DELIVERY_UNKNOWN` where outcome is ambiguous. **This means accepted by the transport, not inbox delivered**. The precise `$trigger` item-key and failure branch must be verified in a disposable Flow before provisioning, not guessed from documentation alone.
5. Grant CREATE on the new collection only to a dedicated service identity with a static token confined to protected Setup runtime configuration. It must NOT have read/update to unrelated collections, general Manager/Production Crew identity, administrative Flow edit, or Work Order Intake privileges. Flow's configured accountability and required read/update fields must be explicitly reviewed.
6. Ensure collection and audit rows are not readable by Public, Production Crew, general Managers, or untrusted browser credentials. Flow mail cannot be triggered by a direct database INSERT or nonauthorized API token. Attempt denied unauthenticated POST; denied generic Manager and Crew POST; approved dedicated token create; and duplicate key second POST (must not trigger a second send).
7. In disposable, test one exact Manager `Email to Myself` and verify received message in actual approved review mailbox, subject, human tasks, schedule/crew/captain, responsive formatting and authenticated link. Test send failure, timeout after create, retry with unchanged key, expired/removed Manager, Captain no org account and daily repeat. Only then accept flow and gate its activation.
8. **Separately** register a controlled 04:00 **America/Chicago** server-side timer/scheduler under Server Management authority. Do not use a workstation timer, general Production PostgreSQL trigger, or Directus Work Order Flow to synthesize Setup events. The runner stays read-only `--dry-run` during acceptance. No installed scheduling is implied by code alone.

A response from `POST /items/setup_notification_outbox` means a request was queued, **not** proof it was sent or received. Idempotence is enforced by a unique `message_key` per recipient/kind/day (and original assignment for a targeted request); if an HTTP timeout leaves the outcome unknown, query the ledger by original key before retrying. Never invent a new key to force another send. The current source reserves one daily Manager/Captain notice per recipient; outstanding prior days are included in each new day's digest. Test sends are distinct from daily send keys.

## Gates blocking activation

The actual on-host Directus Flow payload shape and mail settings, server capability/permissions, flow success/failure audit, outbox collection metadata, migration 074 acceptance and service token are **not independently verified**. No Directus flow has been installed, no emails sent, and no server-side timer created by this document. The existing one-clone #122 acceptance, full regressions, Greg review of received formatted email, version/asset pins and Production runbook remain mandatory.

If the currently installed Directus version cannot guarantee independent row-level sender restriction or audited failed mail outcomes without an extension, record a **RUNBOOK GAP FOUND** or explicit integration gap; do not weaken recipient safety or bypass the Flow service.
