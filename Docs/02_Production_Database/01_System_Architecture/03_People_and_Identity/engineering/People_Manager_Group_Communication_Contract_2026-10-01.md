# People Manager Group Communication Contract — 2026-10-01

| Document Control | Value |
|---|---|
| Document Type | Engineering / Operator Workflow Contract |
| System | People and Identity / People Manager / Setup & Takedown communication |
| Status | PROPOSED — dependent on MSB email cleanup |
| Owner | Production Database / People and Identity |
| Related | Issue #130; Setup Issue #122 |

## Purpose

Define a simple People Manager workflow for sending operational email to dynamic MSB participation groups such as the Setup team without requiring a separate manually-maintained mailing list.

The People system already owns participation facts such as:

```text
SETUP_VOLUNTEER
TAKEDOWN_VOLUNTEER
CAPTAIN_CANDIDATE
ADVISOR_CANDIDATE
```

The communication workflow should consume those existing People relationships rather than create a second independent group-membership source.

## Primary Email Rule

After historical generated/bogus Sheboygan Lights email values are reconciled, the preferred contact email for a Person is:

```text
if ref.person.email contains the person's real Sheboygan Lights Google Workspace account
    -> use ref.person.email

else
    -> use ref.person.personal_email
```

A Person with neither usable address is excluded from the send target and reported to the operator for follow-up.

The communication resolver must not infer that every historical non-null `ref.person.email` is deliverable until the current cleanup is complete.

## Setup Team Recipient Rule

The Setup communication cohort is:

```text
ref.person.active_flag = true
AND active ref.person_setup_role = SETUP_VOLUNTEER
AND at least one usable contact email exists
```

The Takedown cohort uses the same rule with `TAKEDOWN_VOLUNTEER`.

Participation in Setup or Takedown does not require a Google Workspace or Directus account.

## Operator Workflow

People Manager should expose group communication controls, for example:

```text
Setup / Takedown participation & eligibility

[ Email Setup Team ]
[ Email Takedown Team ]
```

The application must not send mail automatically.

Selecting **Email Setup Team** should:

1. resolve the current active Setup recipient list;
2. choose each Person's preferred email using the primary-email rule;
3. de-duplicate addresses;
4. place recipients in BCC, not To/CC;
5. open a compose window in the operator's mail client / Gmail;
6. leave subject/body editable by the operator before sending; and
7. report any active Setup people who have no usable email.

A secondary **Copy BCC list** action is useful as a fallback when browser/mail-client integration does not open correctly.

## Privacy Rule

Volunteer/contact addresses must not be exposed to the entire group.

Group compose therefore uses:

```text
To: operator or blank, depending on client behavior
BCC: resolved Setup recipients
```

Do not populate the Setup team in To or CC.

## Separation From Google Groups

This feature does not require or imply a Google Group named Setup.

The recipient list is generated from current People metadata at the moment the operator launches the message.

That keeps the communication list aligned with the same durable Person/participation records used by Setup.

A future Google Group may exist for another purpose, but it must not silently replace the People participation authority.

## Access Boundary

Only current People Manager-authorized Managers/Administrators may launch the group communication helper from People Manager.

Launching a message does not grant Directus/database access to any recipient.

## Acceptance Requirements

Before deployment, prove at least:

1. active SETUP_VOLUNTEER people are included;
2. inactive people are excluded;
3. active people without SETUP_VOLUNTEER are excluded;
4. real Sheboygan Lights email is preferred over personal email;
5. personal email is used when no real Sheboygan Lights account exists;
6. duplicate email addresses are de-duplicated;
7. missing-email people are reported;
8. recipient addresses are placed in BCC;
9. no email is sent until the operator explicitly sends from the mail client/Gmail; and
10. no contact address is sent to GA4 or other analytics.
