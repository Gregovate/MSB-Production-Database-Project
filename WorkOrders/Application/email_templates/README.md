# Work Order email templates

Status: **PRODUCTION — Work Management V1.1.2-manager-utilities**

These reviewed JSON templates are used by the current Work Management Phase 2 notification system. Editing the repository does not directly change Production; template changes follow the normal reviewed configuration/deployment process.

Each file contains `subject`, `html` (formatted message), and `text` (plain-text alternative). Keep both bodies equivalent.

| File | Purpose |
| --- | --- |
| new_request.json | New Intake notice to Manager recipients |
| task_feedback.json | Setup Task Feedback notice with original task context |
| assignment.json | Assignment notice, including Due by |
| outcome.json | Original reporter's done/canceled/disposition notice |
| reporter_reply.json | Reporter answer to the accountable correction owner or question author |
| more_info.json | Original reporter's clarification question and protected response link |

Available placeholders: `$ticket`, `$title`, `$reporter`, `$assignees`, `$due_by`,
`$task_name`, `$question`, `$outcome`, `$reason`, `$ticket_url`.

Recipients and credentials are not editable in templates. Directus remains the authorization authority.

`outcome` must state the real business result: cancellation is not completion.

The sender records immutable rendered content and event/recipient delivery state before attempts. Existing uncertain claims are not blindly retried. **SMTP_ACCEPTED** means the relay accepted the message; it does not by itself prove Inbox delivery.

## Manager Utility

Managers can open **Utilities → Email template previews** to view fictional no-send examples of the current templates. The utility does not send mail and cannot edit templates.

## Editing Templates

1. Edit the appropriate JSON source file through the normal repository workflow.
2. Keep HTML and plain-text bodies equivalent.
3. Preserve only the documented placeholders.
4. Run the template tests before review.
5. Review the rendered fictional preview.
6. Deploy the reviewed configuration through the governed Work Management release process.

Do not change recipients, credentials, authorization, or transport behavior by embedding logic in a template.
