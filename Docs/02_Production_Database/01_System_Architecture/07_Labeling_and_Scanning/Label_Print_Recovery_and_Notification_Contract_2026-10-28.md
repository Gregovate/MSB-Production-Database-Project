# Label Print Recovery and Notification Contract

| Document Control | Value |
|---|---|
| Status | CANDIDATE — source and disposable acceptance required |
| Date | 2026-10-28 |
| Database owner | MSB Production Database engineering |
| Print runtime owner | MSB LabelPrintService |
| Delivery/runtime owner | MSB Server Management #96/#97 |
| Production coordination | #122 |

## Required outcome

Label printing must not require Greg to inspect logs, delete batches, reset
requests, or restart services during ordinary recoverable failures. The system
must preserve no-double-print safety while reporting failures durably.

## Versioned producer contract

PRINT-SERVER receives EXECUTE only on narrow functions to:

1. bind frozen batch items to request-time requester evidence;
2. update the single PRINT-SERVER heartbeat;
3. open/update a stable incident key; and
4. resolve an incident after the runtime has evidence of recovery.

It cannot read recipient configuration, select arbitrary recipients, create raw
email content, claim delivery work, or access relay credentials.

## Requester provenance

`print_label` remains the established work flag. A database trigger records one
active `ops.label_print_request` when that flag changes from false to true. The
request-time Person is frozen before later asset edits or batch aggregation can
overwrite attribution. Batch items bind to that request before printing.

Existing pending requests at migration time are retained as
`LEGACY_ROW_AUDIT` but are not eligible for requester-specific email because
their actor is not proven request-time evidence. Administrators still receive
administrator-only evidence when recovery is exhausted.

## Recovery truth

Email never proves a label printed. Runtime recovery must distinguish:

- pre-submission failure: safe bounded retry with no batch replay;
- wrong/missing stock: retain work and automatically continue after correct
  media passes full preflight;
- retained physical job: resume the same Brother job, never submit another;
- proven active-to-ready physical completion: finalize once;
- ambiguous completion: hold for reconciliation and alert; never guess.

An unresolved failed batch freezes only its own workload. An active physical
batch and an unsafe Windows queue remain global printer locks.

## Notification transitions

An incident uses a stable key plus generation. Repeated 15-second polls update
the same incident and cannot create duplicate events. A queued incident notice
is cancelled if the condition clears before delivery. RESOLVED email is
created only for recipients whose ACTIVE event reached `SMTP_ACCEPTED`.

Requester notifications are the normal operating interface:

- wrong or missing stock: identify only that person's retained requests and
  state the exact required tape size/type; tell the requester to replace the
  tape and not submit the labels again;
- successful completion: identify only that person's completed requests and
  state that the labels are ready at the print station.

Administrator mail is not emitted for a condition the automatic recovery path
is still handling. It is reserved for exhausted/ambiguous recovery, an
unreconciled failed batch, or stale service heartbeat. Those messages include
printer, host, workload, batch, pending impact, required/observed stock,
Brother/SNMP evidence, spooler state, operator action, and recovery state.

## Delivery boundary

The database owns event/outbox/recipient/content state. Server Management owns
the worker, watchdog, relay, credentials, delivery claims, receipts and
operational monitoring. `SMTP_ACCEPTED` means relay acceptance, not Inbox proof.
Uncertain attempts are retained and never blindly replayed.

## Production gates

This contract and candidate migration authorize no Production mutation, admin
recipient activation, service deployment, timer activation, or real email.
Required acceptance includes current-Production disposable clone, request actor
capture, batch binding, duplicate incident polls, stale heartbeat/recovery,
wrong stock, failed/uncertain SMTP, cross-consumer regression, rollback, and one
explicitly approved real-recipient send.
