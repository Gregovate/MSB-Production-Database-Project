# People Manager Browser Review Findings — 2026-09-09

| Item | Value |
|---|---|
| Status | **CHANGES REQUIRED — CORRECTED FOR RE-REVIEW** |
| Browser-reviewed candidate with defect | `7cd4c02420f564c1fe563d0c12052480c6ce6f6b` |
| Corrected browser-review candidate | `0d099437ceddb6c9019eca7353e65d84a310c633` |
| Production database mutation | NONE |
| Browser writes | disposable current-Production clone only |

## Operator finding

During the governed disposable browser review, changing an existing inactive person to active failed with:

```text
Person changed after this form was loaded; reload before saving
```

The same stale-record message was then observed while exercising a newly added clone-only person.

## Root cause

The database optimistic-lock contract is intentionally exact: `ref.update_person_from_people_manager(...)` compares the submitted `p_expected_updated_at` with the current `ref.person.updated_at` value and rejects a stale form.

The browser backend was returning PostgreSQL `datetime` values directly through Flask `jsonify`. Flask's default datetime JSON serialization uses an HTTP-date representation that does not preserve PostgreSQL fractional-second precision. The browser therefore stored a rounded/truncated `updated_at` token and submitted that altered timestamp as `expected_updated_at`. Even when the row had not actually changed, PostgreSQL correctly rejected the unequal timestamp.

This was a browser serialization defect, not a defect in the database concurrency guard.

## Correction

`People/Application/backend.py` now serializes database datetime values explicitly with Python `datetime.isoformat()` before passing them to `jsonify`. This preserves PostgreSQL fractional-second precision in the browser's optimistic-lock token.

The correction is covered by the People application contract test and bumps the People backend version to `V0.1.1`.

No People database migration changed. The previously accepted least-privilege/update command contract remains intact.

## Re-review requirement

The browser review must be restarted against corrected candidate:

```text
0d099437ceddb6c9019eca7353e65d84a310c633
```

The next review must specifically re-test:

1. activate an existing inactive person and save;
2. create a clone-only person, reopen/edit it, and save;
3. deactivate then reactivate the same clone-only `person_id`;
4. confirm the real stale-record guard still rejects an actually stale update if that condition is deliberately exercised.

The running preview that exposed the defect remains invalid for Production approval and should be ended through the normal browser-review ENTER/cleanup path before starting the corrected review.
