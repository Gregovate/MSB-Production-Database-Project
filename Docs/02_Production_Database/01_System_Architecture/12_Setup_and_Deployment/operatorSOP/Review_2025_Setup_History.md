# Review and Correct the 2025 Setup History

| Document Control | Value |
|---|---|
| Document Type | Operator Procedure |
| System | Production Database — Setup and Deployment |
| Task | Review and correct the 2025 Setup history |
| Audience | Authorized Setup reviewers and managers |
| Status | DRAFT — permanent `/setup/` route deployment in progress |
| Owner | MSB Setup administrator |
| Last Reviewed | 2026-09-07 |
| Keywords | Setup, 2025, historical review, training, reusable task, annual history |

## Purpose

Use the real 2025 Setup Session to reconstruct what happened during the 2025 Setup season and improve the reusable Setup plan before the 2026 Setup Session is created.

This is both a historical review area and a training area. Changes are real Production changes, so review what you are changing before saving.

## Open the Setup Application

After the permanent route is accepted, use:

```text
https://my.sheboyganlights.org/setup/
```

Sign in through the normal MSB Google/Cloudflare Access login when prompted.

## Confirm You Are Working in 2025

At the top of the Setup application, confirm the selected session is:

```text
2025 — Historical Verification
```

The system limits operational dates to the selected Setup Session year.

For the 2025 session:

```text
allowed operational dates = 2025 only
```

A 2026 date should be rejected rather than saved into the 2025 record.

## Understand the Two Kinds of Changes

### 2025 annual history

These changes describe what happened in 2025. Examples include:

- actual crew count;
- actual duration;
- actual start/completion information;
- annual notes;
- verification state; and
- 2025-specific planned order or scheduling information when that workflow is enabled.

These changes belong to 2025 and do not become 2026 history.

### Reusable Task knowledge

These changes describe how MSB normally performs the Setup work. Examples include:

- task name;
- normal crew size;
- prerequisite tasks;
- required equipment/resources;
- normal Stage or Scene scope;
- reusable completion/readiness notes; and
- reusable planning order.

Reusable Task changes are permanent Setup knowledge. They may legitimately become the starting point for future Setup Sessions.

Before changing a Reusable Task, ask:

> Is this a general Setup rule we want to carry forward, or is this only something that happened in 2025?

If it happened only in 2025, put the information in the 2025 annual history instead of changing the reusable definition.

## Review a Task

1. Open the 2025 Historical Verification session.
2. Select a task from the review list.
3. Read the current reusable task information and the 2025 annual information separately.
4. Compare the record with what you know, current Setup procedures, and other reliable 2025 evidence.
5. Correct only the fields you can support.
6. Use annual notes to preserve useful 2025-specific detail.
7. Set the verification state only after the record has been reviewed.

Normal verification states are:

```text
UNVERIFIED
VERIFIED
NEEDS CORRECTION
```

Do not mark a task VERIFIED merely because the task exists. Verification means the 2025 information has actually been reviewed.

## Procedures and Instructions

Where a Setup task has a current published Setup procedure, the application may show that procedure and, for authorized Managers, the editable source used to maintain it.

If an editable procedure is corrected, the current published PDF must also be updated before the instruction is treated as current.

Detailed document-publishing instructions are owned by the Google Drive / Display Folder workflow. Do not reorganize folders merely to make the Setup review screen look cleaner.

## What Reviewers Cannot Do

Normal reviewers/managers cannot:

- create the 2026 Setup Session; or
- use **Use Current Order as Future Baseline** unless they have Administrator authority.

Those controls are intentionally restricted so training/review work in the 2025 session cannot accidentally create or promote future-season state.

## What Successful Review Looks Like

A useful 2025 review leaves:

- 2025 annual facts corrected where evidence exists;
- uncertain information clearly left UNVERIFIED or marked NEEDS CORRECTION;
- reusable task knowledge corrected only when the change should carry forward;
- no 2026 operational dates in the 2025 session; and
- better reusable Setup knowledge for building the 2026 Setup Session.

## If Something Looks Wrong

Do not guess merely to clear an UNVERIFIED task.

Leave the item UNVERIFIED or mark it NEEDS CORRECTION and add a useful note describing what still needs to be checked.

If the application rejects a date because it is outside 2025, verify that you are editing the correct Setup Session rather than trying to force the date through.

## Related Documents

- [Setup operator procedures](README.md)
- [Setup engineering handoff](../engineering/README.md)
