# People Manager Operator Procedure

| Document Control | Value |
|---|---|
| Document Type | Operational SOP |
| System | Production Database — People and Identity |
| Audience | Managers and Administrators |
| Status | CURRENT — PRODUCTION LIVE |
| Last Reviewed | 2026-09-09 |
| Production URL | `https://my.sheboyganlights.org/people/` |
| Engineering Authority | [People and Identity](../../01_System_Architecture/03_People_and_Identity/README.md) |

[↑ People Manager Operational SOPs](README.md)

## Purpose

Use People Manager to maintain the durable MSB person/contact record and the reusable People metadata that other systems can consume.

People Manager is the normal browser workflow for:

- finding an existing person before creating a new record;
- maintaining contact information and active/inactive state;
- recording reusable capabilities;
- recording formal qualifications and their dates/evidence;
- recording Setup/Takedown participation and leadership eligibility; and
- reviewing existing reusable-task Captain/Alternate/Advisor assignments.

Do not edit these People relationships directly in PostgreSQL as an ordinary operator workflow.

## Open People Manager

Open:

```text
https://my.sheboyganlights.org/people/
```

The Production intranet/index will also link to this application after Backbone integration is completed.

Cloudflare Access identifies the signed-in user. People Manager then checks the current Directus authorization context. The application is limited to current **Manager / Administrator** or equivalent accepted `admin_access` authority. If the application says the account is not authorized, do not bypass the missing access through Directus table editing or direct database commands.

## Important Rules Before Making Changes

- Search for the person before adding a new record.
- A person's `person_id` is the durable database identity. It is not a membership number and should not be recreated merely because someone returns after being inactive.
- If someone stops participating, normally mark the person **inactive** rather than creating a replacement person later.
- If that same person returns, reactivate the existing person record.
- The Sheboygan Lights email stored in People Manager is a **reserved system identity**. It does not create a Google Workspace mailbox.
- Google Workspace remains the authority for whether the MSB email account actually exists and is deliverable.
- A Directus-linked Sheboygan Lights email is protected from ordinary People contact editing.
- Capabilities describe reusable skill, experience, or MSB-specific knowledge.
- Qualifications describe formal training, certification, authorization, or credentials and may have dates/evidence.
- Setup/Takedown roles describe participation or eligibility. They do not create Captain assignments.
- Reusable-task Captain/Alternate/Advisor assignments are shown from Setup and are not edited in People Manager.
- There is no normal **Delete Person** or **Merge Person** action in the current application.

## Find a Person

1. Use the search box in the left People panel.
2. Search by any useful part of the person's name, Person ID, MSB email, personal email, or phone number.
3. Check **Include inactive** when the person may have stopped participating in a previous season.
4. Select the person from the list.
5. Review the name and contact information before making changes.

Always search before choosing **Add person**. Two real people may share a name, and family members may share a personal email address or phone number, so search results are evidence to review rather than a guarantee of identity.

## Add a Person

Use **Add person** only after searching and confirming that the person does not already have a durable People record.

1. Select **Add person**.
2. Enter **First name** and **Last name**.
3. Enter **Preferred name** when useful.
4. Enter **Cell phone** and **Personal email** when known.
5. Select **Build email** to build the normal Sheboygan Lights email reservation.
6. Review the proposed address before saving.
7. Leave **Active person** checked for a person who is currently participating with MSB.
8. Select **Check duplicates** when you want to review possible matches before saving. The save workflow also performs duplicate checks.
9. If a possible duplicate is shown, review the matching records carefully. If this is intentionally a different person, check the acknowledgement only after that review.
10. If the standard MSB email is already reserved, review the additional-first-name-character alternatives shown by People Manager. Approve a non-standard alternative only when it is the correct separate identity.
11. Select **Save person**.
12. Confirm the saved person remains selected and the metadata panels become available.

The reserved `@sheboyganlights.org` address does not create the Google Workspace account. Account creation remains a separate Google Admin / Workspace task.

## Edit a Person

1. Find and select the person.
2. Update only contact information you know is correct.
3. If **Sheboygan Lights email** is disabled, the person is Directus-linked and that system identity is protected from ordinary contact editing.
4. Use **Active person** to maintain the person's current MSB participation state.
5. Review any duplicate warning if name/contact information now overlaps another person.
6. Select **Save person**.
7. Confirm the saved values remain after the record reloads.

### Mark a person inactive

Use inactive status when a person is no longer participating but the identity/history must remain.

1. Find the existing person.
2. Clear **Active person**.
3. Select **Save person**.

Do not create a second person merely because the original person is inactive.

### Reactivate a returning person

1. Check **Include inactive**.
2. Find the existing person.
3. Check **Active person**.
4. Review contact information for anything that actually changed.
5. Select **Save person**.

The same `person_id` remains the durable identity.

## Manage Capabilities

Capabilities are reusable skills, experience, or MSB-specific practical knowledge. Examples may include trade, technical, display/build knowledge, or equipment knowledge.

### Assign an existing capability

1. Select the person.
2. In **Capabilities**, choose a capability from the list.
3. Add an optional person-specific note when useful.
4. Select **Add / reactivate**.
5. Confirm the capability appears in the person's capability list.

Use a person-specific note for useful context about that person's knowledge. Do not create a new capability type just to store a one-person note.

### Deactivate or reactivate a person's capability

Use the controls on the person's existing capability row to change its active state. Deactivation preserves the relationship/history rather than pretending it never existed.

### Add a capability to the controlled catalog

Only add a new catalog value when it is genuinely reusable for more than one person or future workflow.

1. Expand **Add capability to controlled catalog**.
2. Enter the capability name.
3. Choose the most appropriate category: Trade, Technical, Display / build knowledge, Equipment, or Other.
4. Add catalog notes when the meaning needs clarification.
5. Select **Create capability type**.
6. Then assign that capability to the appropriate person or people.

Do not invent skill levels such as beginner/intermediate/expert unless a later accepted People design adds those concepts.

## Manage Qualifications

Qualifications are formal training, certification, authorization, or credentials. They remain separate from capabilities.

### Add a qualification type to the catalog

If the qualification does not already exist:

1. Expand **Add qualification to controlled catalog**.
2. Enter the qualification name.
3. Add catalog notes when needed.
4. Select **Create qualification type**.

### Add a person's qualification

1. Select the person.
2. Choose the qualification.
3. Enter **Qualification role** when the credential has a meaningful role/level.
4. Enter **Completed on** when known from the authoritative record.
5. Enter **Valid from** when applicable.
6. Enter **Expires on** only from authoritative documentation. Do not calculate an expiration merely from conversational shorthand.
7. Enter **Certificate number** when one exists.
8. Enter **Evidence reference** for the document, certificate, file, or other authoritative evidence.
9. Add notes when useful.
10. Leave **Active qualification record** checked when the qualification is currently valid/active for MSB use.
11. Select **Add qualification**.

### Edit a person's qualification

Select the qualification's edit action, update the known information, and save it. Use inactive state to retain an expired, superseded, or no-longer-current record when the history still matters.

## Manage Setup / Takedown Roles

The current People Manager roles are:

- **Setup Volunteer**;
- **Takedown Volunteer**;
- **Captain Candidate**; and
- **Advisor Candidate**.

These are participation/eligibility facts only.

1. Select the person.
2. Check or clear the appropriate role choices.
3. Add a role-specific note when useful.
4. Select **Save roles**.
5. Reopen the person if needed and confirm the state persisted.

Do not use **Captain Candidate** or **Advisor Candidate** to mean that the person is actually assigned to a reusable task.

## Review Reusable-Task Leadership

The **Reusable-task leadership** panel shows current Setup relationships where the person is recorded as:

- Captain;
- Alternate; or
- Advisor.

This panel is intentionally read-only in People Manager. Actual reusable-task leadership is maintained by the Setup application/authority.

Use this panel to answer questions such as "What Setup knowledge responsibility does this person currently own?" without creating a second competing leadership record.

## Protected System State and Duplicate Safety

At the bottom of the person detail, expand **Protected system state** when you need to see current system linkage such as:

- Directus linked;
- PostgreSQL login linked;
- Manager flag;
- Team flag; or
- Available for Work Orders.

These values are visible for context but remain governed by their owning workflows. Do not expect ordinary People contact editing to change them.

Expand **Current database relationships** when duplicate/reconciliation work requires awareness of other records that currently reference this person.

People Manager intentionally exposes no normal person delete action. Relationship visibility exists so an inactive or duplicate-looking person is not casually removed while other Production records depend on that identity.

## If Something Is Wrong

- **The person cannot be found:** clear the search, check **Include inactive**, and search by name, Person ID, email, and phone before adding a new record.
- **A possible duplicate appears:** review the existing person before acknowledging a separate identity. Shared family contact information is a warning, not proof of duplication.
- **The MSB email is already used:** use the collision alternatives provided by People Manager; do not add a silent number or reuse another person's address.
- **Build email created an address but there is no mailbox:** that is expected until Google Workspace provisioning is completed. People Manager reserves identity; Google creates the account.
- **MSB email cannot be edited:** the person may already be Directus-linked. Do not bypass the protection.
- **Save reports that the person changed after the form was loaded:** reload/reopen the person and review the current data before saving again. This protects against overwriting another change.
- **A capability or qualification is missing from the catalog:** add a controlled catalog value only when the term is actually appropriate and reusable.
- **A Captain/Advisor assignment looks wrong:** correct it in the Setup leadership workflow, not in People Manager.
- **A management action is unavailable:** verify Manager/Administrator authorization. Do not work around role/policy controls through direct table edits.

## What Not To Do

Do not:

- create a second person because an existing person is inactive;
- assume a reserved MSB email proves the Google account/mailbox exists;
- edit Directus-linked identity fields through ordinary contact maintenance;
- treat capability as a formal qualification;
- infer expiration dates without authoritative evidence;
- infer Captain assignments from capability, qualification, or Setup eligibility;
- create free-text Captain identities;
- hard-delete people as normal cleanup; or
- send person-specific audit information to Google Analytics. GA4 is aggregate application usage only.

## Expected Result

After using People Manager, MSB should have one durable person identity with current contact information, appropriate active/inactive state, reusable capabilities, formal qualification evidence, and Setup/Takedown eligibility while preserving authentication, Setup leadership, and audit ownership boundaries.
