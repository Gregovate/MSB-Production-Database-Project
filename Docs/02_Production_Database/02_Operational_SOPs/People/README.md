# People Manager Operational SOPs

These procedures are for Managers and Administrators using the **People Manager** browser to maintain durable volunteer/contact information, capabilities, qualifications, and Setup/Takedown eligibility.

## What Do You Need To Do?

| I want to... | Go to |
|---|---|
| Find an existing person before adding someone new | [People Manager Operator Procedure](People_Manager_Operator_Procedure.md#find-a-person) |
| Add a new volunteer or contact | [People Manager Operator Procedure](People_Manager_Operator_Procedure.md#add-a-person) |
| Update contact information or active/inactive status | [People Manager Operator Procedure](People_Manager_Operator_Procedure.md#edit-a-person) |
| Add or maintain a person's capabilities | [People Manager Operator Procedure](People_Manager_Operator_Procedure.md#manage-capabilities) |
| Add or maintain formal qualifications, dates, certificate, or evidence information | [People Manager Operator Procedure](People_Manager_Operator_Procedure.md#manage-qualifications) |
| Mark Setup/Takedown participation or Captain/Advisor eligibility | [People Manager Operator Procedure](People_Manager_Operator_Procedure.md#manage-setup--takedown-roles) |
| See which reusable Setup tasks list the person as Captain, Alternate, or Advisor | [People Manager Operator Procedure](People_Manager_Operator_Procedure.md#review-reusable-task-leadership) |
| Understand protected identity information or duplicate warnings | [People Manager Operator Procedure](People_Manager_Operator_Procedure.md#protected-system-state-and-duplicate-safety) |

## Access

People Manager is an authenticated MSB application. Cloudflare Access identifies the signed-in user and current Directus role/policy information controls whether People maintenance is available.

The accepted People Manager maintenance workflow is for **Manager / Administrator context**. If People Manager reports that the account is not authorized, do not work around the application through Directus tables or direct PostgreSQL edits.

## Important Boundaries

- `ref.person` is the durable person identity.
- A person may exist without a Google Workspace account, Directus user, or PostgreSQL login.
- A reserved `@sheboyganlights.org` email in People Manager does **not** prove that Google Workspace has created the mailbox.
- Google Workspace remains the authority for whether the account/mailbox actually exists.
- Directus remains the role/policy authorization authority.
- Capabilities are reusable knowledge/skill and are not the same thing as formal qualifications.
- Setup/Takedown eligibility does not create a Captain assignment.
- Captain/Alternate/Advisor assignments shown in People Manager come from Setup reusable-task authority and are read-only here.
- There is no normal person delete or merge action in the current People Manager.

For engineering ownership and database behavior, use [People and Identity](../../01_System_Architecture/03_People_and_Identity/README.md).
