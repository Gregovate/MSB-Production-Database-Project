# People Manager Nullable MSB Email — Disposable Acceptance — 2026-10-01

| Item | Value |
|---|---|
| System | People Manager / People and Identity |
| Change | Stop automatic Sheboygan Lights email generation |
| Candidate SHA | `9ef05fbb0ac20505ee12c246e9f5df742fdf082d` |
| Candidate branch | `agent/people-identity-link-acceptance-gap-20260910` |
| Local contract tests | PASS — 19 |
| Disposable acceptance | PASS |
| Production mutation | NONE |
| Production `ref.person` before fingerprint | `39fb12d9598bc319dee8bb7347bebc5b` |
| Production `ref.person` after fingerprint | `39fb12d9598bc319dee8bb7347bebc5b` |
| Disposable report | `/tmp/MSB_People_Manager_Disposable_20261001-123729.txt` |

## Purpose

Record disposable acceptance of the corrective People Manager behavior that eliminates automatic/fictitious `@sheboyganlights.org` generation for new contact-only People.

The intended contract is:

```text
new Person without real Google Workspace account
    -> ref.person.email remains NULL
    -> personal_email is the ordinary contact email

real Sheboygan Lights Google Workspace account exists
    -> operator may explicitly enter that exact address
    -> ref.person.email stores the real account
```

## Candidate Scope

The candidate includes:

- `People/Database/004_stop_automatic_msb_email_generation.sql`;
- People browser removal of the automatic save-time email builder;
- removal of the **Build email** control from the Person form;
- People Manager V0.2.1 version bump; and
- updated contract/disposable tests.

The migration does not update existing `ref.person` rows.

## Local Contract Test

The candidate test suite completed:

```text
19 passed
```

The updated tests explicitly require that:

- create with blank Sheboygan Lights email does not synthesize an address;
- a supplied real-domain address remains supported;
- an unlinked Person may return to NULL email;
- Directus-linked identity protection remains in force; and
- the UI no longer contains the Build email control or save-time generation path.

## Disposable Production-Clone Acceptance

The governed disposable wrapper completed:

```text
PEOPLE MANAGER DISPOSABLE ACCEPTANCE: PASS
PEOPLE MANAGER DISPOSABLE WRAPPER: PASS
Exit status: 0
```

The disposable clone applied People migrations 001-004 and validated the nullable-email lifecycle.

Production was accessed only for dump/read validation.

Production fingerprint proof:

```text
Before: 39fb12d9598bc319dee8bb7347bebc5b
After:  39fb12d9598bc319dee8bb7347bebc5b
PASS: production ref.person fingerprint unchanged
```

## Acceptance Meaning

This acceptance proves the database/application contract on a disposable current-Production clone.

It does not yet authorize Production deployment.

Because the browser presentation also changed, a governed pre-Production browser review is required before the Production deployment gate.
