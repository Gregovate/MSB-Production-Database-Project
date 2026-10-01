# People Manager Nullable MSB Email — Browser Acceptance — 2026-10-01

| Item | Value |
|---|---|
| System | People Manager / People and Identity |
| Change | Stop automatic Sheboygan Lights email generation |
| Browser candidate | `9ef05fbb0ac20505ee12c246e9f5df742fdf082d` |
| Candidate branch | `agent/people-identity-link-acceptance-gap-20260910` |
| Prior disposable acceptance | PASS |
| Browser review | PASS |
| Production mutation during preview | NONE |

## Operator Browser Review

The operator reviewed the disposable current-Production browser preview and confirmed the corrective behavior.

### 1. Existing bogus/reserved Sheboygan Lights email can be removed when not Directus-linked

PASS.

An existing unlinked Person record was edited so the previously generated/bogus `@sheboyganlights.org` value was removed. The Person saved successfully with the Sheboygan Lights email blank.

The duplicate-review warning shown during this test was based on matching personal email/phone evidence and remained an independent duplicate-safety control. It did not force regeneration of an MSB email.

### 2. New Person does not receive an automatic Sheboygan Lights email

PASS.

A clone-only new Person was created with:

- first/last name;
- personal email;
- phone;
- active state; and
- **blank Sheboygan Lights email**.

After save/reopen, the Sheboygan Lights email remained blank.

The browser no longer exposes the former **Build email** control.

### 3. Directus-linked identity remains protected

PASS.

Adam Biebel was opened as the linked-identity validation case.

His existing Sheboygan Lights email remained protected from ordinary People contact editing, preserving the prior identity boundary.

## Accepted Browser Contract

The reviewed browser behavior now matches the intended People/Identity contract:

```text
contact-only Person
    -> personal_email may be used
    -> Sheboygan Lights email may remain NULL
    -> no automatic/fictitious @sheboyganlights.org generation

real Google Workspace account
    -> exact Sheboygan Lights address may be entered

Directus-linked Person
    -> linked Sheboygan Lights identity remains protected
```

## Acceptance Result

```text
PEOPLE MANAGER NULLABLE MSB EMAIL BROWSER ACCEPTANCE: PASS
```

This browser acceptance, together with the 2026-10-01 disposable acceptance, satisfies the pre-Production validation for the nullable-MSB-email correction.

Production deployment remains a separate explicit gate.
