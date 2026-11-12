# People Manager Metadata Acceptance Pending — 2026-09-09

| Item | Value |
|---|---|
| Status | **ENGINEERING COMPLETE FOR DISPOSABLE TEST — NOT ACCEPTED** |
| Issue | #130 |
| Application/database candidate | `deaa9157282e59e8acd6a7da2a82fc9296e44f20` |
| Production mutation | NONE |

## Scope added after browser finding

The browser finding that returned the prior candidate to engineering has been implemented on the feature branch.

The candidate now contains:

- `People/Database/003_create_people_metadata_contract.sql`;
- controlled capability catalog + person capability relationships;
- controlled qualification catalog + dated/evidenced person qualifications;
- Setup/Takedown participation and Captain/Advisor eligibility roles;
- read-only visibility of existing reusable-task Captain/Alternate/Advisor assignments;
- People V0.2.0 API/UI support for those relationships; and
- contract tests covering the metadata separation and least-privilege boundary.

The application/database candidate SHA is pinned at the final commit that changes `People/Application` or `People/Database`:

```text
deaa9157282e59e8acd6a7da2a82fc9296e44f20
```

Subsequent commits are acceptance/documentation only.

## Next gate

The previous disposable acceptance does not cover this candidate. The required next command is:

```powershell
.\People\Acceptance\run_people_manager_disposable_acceptance.ps1
```

The updated disposable runner applies migrations `001 + 002 + 003` to a fresh current-Production clone and exercises the new metadata relationships while Production remains `SELECT + pg_dump` only.

Do not start a new browser review until this disposable gate passes. After PASS, the browser harness must be pinned to the exact accepted candidate before review resumes.
