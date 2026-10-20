# Work Order email templates

Status: Phase 2 candidate under #419. These files do not activate delivery.

Edit the four JSON files here using GitHub's file editor. Each file contains
`subject`, `html` (formatted message), and `text` (plain-text alternative).
Keep both bodies equivalent. JSON newlines are written as `\n`; quotation marks
inside HTML attributes are escaped as `\"`. Review changes through the normal PR
and configuration deployment process; editing GitHub does not change Production.

| File | Purpose |
| --- | --- |
| new_request.json | New Intake notice to the existing interim Manager mailing list |
| assignment.json | Assignment notice, including Due by |
| outcome.json | Original reporter's done/canceled/disposition notice |
| more_info.json | Original reporter's clarification question and response link |

Available placeholders: `$ticket`, `$title`, `$reporter`, `$assignees`, `$due_by`,
`$question`, `$outcome`, `$reason`, `$ticket_url`. A literal dollar sign is `$$`.
No Python, JavaScript, expressions or template includes are executed. Unknown,
blank or missing values fail validation. Ticket values are HTML-escaped.

Recipients and credentials are not editable in templates. The current Intake
test mailing list remains active People with `is_manager=true` and an email;
this flag confers no application rights. Directus owns those rights.

`outcome` must state the actual business result: cancellation is not completion.
The sender must supply a validated same-ticket URL; the site home alone is not
acceptable for final delivery acceptance. Verify original-reporter access to
that route before enabling reporter mail. Email replies are not ingested.

Run `python -m pytest WorkOrders/Application/test_email_templates.py` before
review. The renderer returns both alternatives, subject and the source digest.
The candidate worker stores these immutable values with the event/recipient
delivery record before any attempt. Existing claims are never retried
automatically. Do not mark SENT from rendering or a database enqueue.
SMTP_ACCEPTED records relay acceptance, not Inbox delivery.

For a formatted preview without a database, credentials, or email delivery:

```powershell
python WorkOrders/Application/preview_email_templates.py --output-dir "$env:TEMP\WO419-mail-preview"
Start-Process "$env:TEMP\WO419-mail-preview\index.html"
```

Edit a JSON template and run the command again to see the result. Examples are
fictional. The outcome sample deliberately demonstrates cancellation without
claiming completion. Preview does not install anything or activate the worker.

Production delivery remains OFF. Disposable SQL acceptance, reporter access,
operator preview approval, governed deployment and the exact two-Flow cutover
remain release gates. Preserve existing Setup daily report mail and non-mail
Directus Flows throughout.
