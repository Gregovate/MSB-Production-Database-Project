# Review and Correct the 2025 Setup History

| Document Control | Value |
|---|---|
| Document Type | Operator Procedure |
| System | Production Database — Setup and Deployment |
| Task | Review and correct the 2025 Setup history |
| Audience | Authorized Setup reviewers and managers |
| Status | CURRENT — live 2025 review/training workflow; UI/workflow evaluation remains open |
| Owner | MSB Setup administrator |
| Last Reviewed | 2026-09-07 |
| Keywords | Setup, 2025, historical review, training, reusable task, resources, verification |

## Purpose

Use the real 2025 Setup Session to reconstruct what happened during the 2025 Setup season, improve reusable Setup knowledge, and learn the Setup application before the 2026 Setup Session is created.

This is both a historical review area and a training area. Changes are real Production changes. The application itself is also still under live evaluation, so questions, suggestions, confusing screens, missing controls, and workflow problems should be reported rather than silently worked around.

## Open the Setup Application

Use:

```text
https://my.sheboyganlights.org/setup/
```

Sign in through the normal MSB Google/Cloudflare Access login when prompted.

## Confirm You Are Working in 2025

At the top of the Setup application, confirm the selected session is:

```text
2025 — Historical Verification
```

For this session:

```text
allowed operational dates = 2025 only
```

The browser limits operational dates to 2025 and the database independently enforces the same rule. A correction recorded during 2026 may still have a 2025 operational date; its audit/update timestamp remains the real 2026 recording time.

## Understand the Two Kinds of Changes

### 2025 annual history

These changes describe what happened or was planned in 2025. Examples include:

- verification state;
- actual crew count or duration when known;
- actual start/completion information when known;
- annual notes;
- 2025-specific planned order; and
- 2025 work-day/scheduling information when useful for reconstruction.

These changes belong to 2025 and do not become 2026 history.

### Reusable Task knowledge

These changes describe how MSB normally performs Setup work. Examples include:

- task name and active state;
- Park Infrastructure / Stage / Scene scope;
- normal local sequence/order;
- normal crew size and expected duration;
- prerequisites;
- equipment/resources and quantities;
- completion point;
- readiness/weather notes; and
- other reusable instructions that should carry forward.

Reusable Task changes are permanent Setup knowledge and may become part of the starting point for future seasons.

Before changing reusable information, ask:

> Is this a general Setup rule we want to carry forward, or is this only something that happened in 2025?

If it happened only in 2025, record it in the annual history instead.

## Review a Task

1. Open the 2025 Historical Verification session.
2. Select a task from the review list.
3. Read the reusable task information and the 2025 annual information separately.
4. Compare the record with what you know, current procedures, and other reliable 2025 evidence.
5. Correct only fields you can support.
6. Add useful annual notes when the information is specific to 2025.
7. Set the verification state only after the record has actually been reviewed.

Normal verification states are:

```text
UNVERIFIED
VERIFIED
NEEDS CORRECTION
```

Do not mark a task VERIFIED merely because it exists.

## Add Missing Tasks

If a real Setup activity is missing, Managers may add a reusable task when the work should exist as a normal Setup task beyond just one historical occurrence.

Before adding it, decide the appropriate scope:

```text
Park Infrastructure / no LOR Stage
Stage-level / General
Scene
```

Use **Add Task Here** in the appropriate scope. Use **Copy** when a new reusable task is substantially similar to an existing one, then review the copied definition carefully.

Do not create a task for every ordinary action. A task is useful when it can realistically be missed, affects planning/readiness/resources, needs progress/completion tracking, or preserves historical learning worth carrying forward.

## Review Resources and Prerequisites

For reusable tasks, check whether the practical requirements are represented correctly.

Examples include:

- lifts;
- vehicles;
- trailers;
- tools;
- powered stake pounders;
- other recurring equipment/resources; and
- predecessor tasks that must complete first.

Use structured resources and prerequisites where they represent repeatable Setup knowledge. Do not invent quantities or dependencies just to fill fields.

## Procedures and Instructions

Where a Setup task has a current published Setup procedure, the application may show that procedure and, for authorized Managers, the editable source used to maintain it.

If an editable procedure is corrected, the current published PDF must also be updated before the instruction is treated as current.

Detailed document-publishing instructions are owned by the Google Drive / Display Folder workflow. Do not reorganize folders merely to make the Setup review screen look cleaner.

## Ask Questions and Make Suggestions

The application is intentionally being evaluated through real use. During the review period, report things such as:

- information that is hard to understand;
- fields that appear unnecessary;
- missing information you need to make a Setup decision;
- awkward or repetitive steps;
- task organization that does not match how crews actually work;
- resources or prerequisites that are difficult to represent;
- confusing wording;
- missing search/filter/navigation behavior; and
- ideas that would make the 2026 Setup process easier.

A useful finding does not have to be a software bug. Workflow and data-model suggestions are part of this review.

## What Reviewers Cannot Do

Normal reviewers/managers cannot:

- create the 2026 Setup Session; or
- use **Use Current Order as Future Baseline** unless they have Administrator authority.

Those controls are intentionally restricted so training/review work in the 2025 session cannot accidentally create or promote future-season state.

Pick List generation and Container/Display movement/scanning writes are not part of the current live-review workflow.

## What Successful Review Looks Like

A useful 2025 review leaves:

- 2025 annual facts corrected where evidence exists;
- uncertain information left UNVERIFIED or marked NEEDS CORRECTION;
- missing reusable tasks added where appropriate;
- reusable task scope, resources, prerequisites, order, and normal expectations improved where the change should carry forward;
- no 2026 operational dates in the 2025 session;
- no fake records created only for testing; and
- questions, suggestions, and UI/workflow issues captured for follow-up before final subsystem acceptance.

## Related Documents

- [Setup operator procedures](README.md)
- [Detailed Manager Review Guide](../../../02_Operational_SOPs/Setup/Setup_Session_Manager_Review_Guide.md)
- [Setup engineering handoff](../engineering/README.md)
